package app.yumusic.yumusic

import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import okhttp3.ConnectionPool
import okhttp3.OkHttpClient
import okhttp3.RequestBody.Companion.toRequestBody
import org.schabi.newpipe.extractor.InfoItem
import org.schabi.newpipe.extractor.NewPipe
import org.schabi.newpipe.extractor.Page
import org.schabi.newpipe.extractor.ServiceList.YouTube
import org.schabi.newpipe.extractor.downloader.Downloader
import org.schabi.newpipe.extractor.downloader.Request
import org.schabi.newpipe.extractor.downloader.Response
import org.schabi.newpipe.extractor.exceptions.ContentNotAvailableException
import org.schabi.newpipe.extractor.exceptions.ReCaptchaException
import org.schabi.newpipe.extractor.localization.Localization
import org.schabi.newpipe.extractor.playlist.PlaylistInfo
import org.schabi.newpipe.extractor.playlist.PlaylistInfoItem
import org.schabi.newpipe.extractor.services.youtube.linkHandler.YoutubeSearchQueryHandlerFactory
import org.schabi.newpipe.extractor.services.youtube.linkHandler.YoutubeStreamLinkHandlerFactory
import org.schabi.newpipe.extractor.stream.StreamInfo
import org.schabi.newpipe.extractor.stream.StreamInfoItem
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/** Sama dengan user-agent yang dipakai pemutar saat mengambil audio. */
const val USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; rv:128.0) Gecko/20100101 Firefox/128.0"

/** Lagu paling panjang 20 menit; di atas itu biasanya kompilasi atau mix. */
private const val MAX_SECONDS = 1200L

/** Downloader NewPipeExtractor di atas OkHttp. */
private class OkHttpDownloader(private val client: OkHttpClient) : Downloader() {
    override fun execute(request: Request): Response {
        val builder = okhttp3.Request.Builder()
            .method(request.httpMethod(), request.dataToSend()?.toRequestBody())
            .url(request.url())
            .addHeader("User-Agent", USER_AGENT)
        request.headers().forEach { (name, values) ->
            builder.removeHeader(name)
            values.forEach { builder.addHeader(name, it) }
        }
        client.newCall(builder.build()).execute().use { r ->
            if (r.code == 429) throw ReCaptchaException("Rate limited", request.url())
            return Response(
                r.code,
                r.message,
                r.headers.toMultimap(),
                r.body?.string().orEmpty(),
                r.request.url.toString(),
            )
        }
    }
}

/**
 * Jembatan Dart <-> NewPipeExtractor. Semua panggilan jalan di thread
 * latar; hasil dikirim balik di thread utama.
 */
object NewPipeBridge : MethodChannel.MethodCallHandler {
    const val CHANNEL = "app.yumusic/newpipe"
    private const val TAG = "YuNewPipe"

    private val executor = Executors.newFixedThreadPool(4)
    private val main = Handler(Looper.getMainLooper())

    init {
        // Koneksi menganggur dilepas setelah 10 detik: jaringan seluler diam-diam
        // memutusnya, dan memakai ulang koneksi mati berarti menunggu timeout.
        val client = OkHttpClient.Builder()
            .connectionPool(ConnectionPool(5, 10, TimeUnit.SECONDS))
            .build()
        NewPipe.init(OkHttpDownloader(client), Localization("en", "US"))
    }

    private val watchdog = Executors.newSingleThreadScheduledExecutor()

    /** Panggilan yang lama: catat sedang di mana thread-nya, supaya macet bisa dilacak. */
    private fun watch(method: String, worker: Thread) = listOf(10L, 30L).map { seconds ->
        watchdog.schedule({
            val stack = worker.stackTrace.take(40).joinToString("\n    at ")
            Log.w(TAG, "$method masih jalan setelah $seconds detik\n    at $stack")
        }, seconds, TimeUnit.SECONDS)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        executor.execute {
            val started = System.currentTimeMillis()
            val pending = watch(call.method, Thread.currentThread())
            try {
                val value: Any = when (call.method) {
                    "search" -> search(
                        call.argument<String>("query")!!,
                        call.argument<Boolean>("songsOnly") ?: true,
                    )
                    "resolve" -> resolve(
                        call.argument<String>("id")!!,
                        call.argument<String>("quality") ?: "high",
                    )
                    "related" -> related(call.argument<String>("id")!!)
                    "searchPlaylists" -> searchLists(
                        call.argument<String>("query")!!,
                        YoutubeSearchQueryHandlerFactory.MUSIC_PLAYLISTS,
                    )
                    "searchAlbums" -> searchLists(
                        call.argument<String>("query")!!,
                        YoutubeSearchQueryHandlerFactory.MUSIC_ALBUMS,
                    )
                    "playlist" -> playlist(call.argument<String>("url")!!)
                    else -> {
                        main.post { result.notImplemented() }
                        return@execute
                    }
                }
                main.post { result.success(value) }
            } catch (e: ContentNotAvailableException) {
                // Lagunya ada tapi tidak bisa diputar (dihapus, diblokir, dibatasi
                // umur): tidak ada gunanya dicoba ulang.
                main.post { result.error("NO_AUDIO", e.message.orEmpty(), null) }
            } catch (e: Throwable) {
                Log.w(TAG, "${call.method} gagal", e)
                val message = e.message ?: e.cause?.message ?: ""
                main.post { result.error(e.javaClass.simpleName, message, null) }
            } finally {
                pending.forEach { it.cancel(false) }
                Log.i(TAG, "${call.method} selesai dalam ${System.currentTimeMillis() - started} ms")
            }
        }
    }

    private fun watchUrl(id: String) = "https://www.youtube.com/watch?v=$id"

    /** Video yang ditemukan sebagai lagu. Siaran langsung (durasi -1) dan yang terlalu panjang dibuang. */
    private fun List<InfoItem>.toSongs(): List<Map<String, Any?>> =
        filterIsInstance<StreamInfoItem>().mapNotNull { item ->
            if (item.duration !in 1..MAX_SECONDS) return@mapNotNull null
            val id = try {
                YoutubeStreamLinkHandlerFactory.getInstance().getId(item.url)
            } catch (e: Exception) {
                return@mapNotNull null
            }
            mapOf(
                "id" to id,
                "title" to item.name,
                "artist" to item.uploaderName.orEmpty(),
                "duration" to item.duration,
                "thumbnail" to item.thumbnails.maxByOrNull { it.height }?.url,
            )
        }

    private fun search(query: String, songsOnly: Boolean): List<Map<String, Any?>> {
        // "Hanya lagu" mencari di katalog lagu YouTube Music.
        val filter = if (songsOnly) {
            YoutubeSearchQueryHandlerFactory.MUSIC_SONGS
        } else {
            YoutubeSearchQueryHandlerFactory.MUSIC_VIDEOS
        }
        val extractor = YouTube.getSearchExtractor(query, listOf(filter), "")
        extractor.fetchPage()
        return extractor.initialPage.items.toSongs()
    }

    private fun resolve(id: String, quality: String): Map<String, Any?> {
        val info = StreamInfo.getInfo(YouTube, watchUrl(id))
        val known = info.audioStreams.filter { it.averageBitrate > 0 }.ifEmpty { info.audioStreams }
        val stream = when (quality) {
            "low" -> known.minByOrNull { it.averageBitrate }
            "medium" -> known.minByOrNull { kotlin.math.abs(it.averageBitrate - 128) }
            else -> known.maxByOrNull { it.averageBitrate }
        } ?: throw ContentNotAvailableException("no audio stream for $id")
        return mapOf(
            "url" to stream.content,
            "mime" to (stream.format?.mimeType ?: "audio/mp4"),
            "bitrate" to stream.averageBitrate,
        )
    }

    /**
     * Mix YouTube Music untuk lagu ini (daftar "RDAMVM"), yang isinya hanya
     * musik. Video terkait biasa juga berisi obrolan dan podcast, jadi hanya
     * dipakai bila mix tidak bisa dimuat.
     */
    private fun related(id: String): List<Map<String, Any?>> {
        val mix = runCatching {
            PlaylistInfo.getInfo(YouTube, "${watchUrl(id)}&list=RDAMVM$id").relatedItems.toSongs()
        }.getOrNull()
        val songs = mix?.takeIf { it.size > 1 }
            ?: StreamInfo.getInfo(YouTube, watchUrl(id)).relatedItems.toSongs()
        return songs.filter { it["id"] != id }
    }

    /** Playlist atau album YouTube Music; keduanya dibuka sebagai playlist. */
    private fun searchLists(query: String, filter: String): List<Map<String, Any?>> {
        val extractor = YouTube.getSearchExtractor(query, listOf(filter), "")
        extractor.fetchPage()
        return extractor.initialPage.items.filterIsInstance<PlaylistInfoItem>().map {
            mapOf(
                "url" to it.url,
                "name" to it.name,
                "by" to it.uploaderName.orEmpty(),
                "thumbnail" to it.thumbnails.maxByOrNull { t -> t.height }?.url,
            )
        }
    }

    private fun playlist(url: String): Map<String, Any?> {
        val info = PlaylistInfo.getInfo(YouTube, url)
        val items = info.relatedItems.toMutableList<InfoItem>()
        var next: Page? = info.nextPage
        // Sampai 10 halaman (sekitar 1000 lagu).
        repeat(9) {
            if (!Page.isValid(next)) return@repeat
            val more = PlaylistInfo.getMoreItems(YouTube, url, next)
            items += more.items
            next = more.nextPage
        }
        return mapOf("title" to info.name, "tracks" to items.toSongs())
    }
}
