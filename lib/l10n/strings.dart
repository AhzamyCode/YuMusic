/// Teks antarmuka dalam bahasa Indonesia dan Inggris.
class S {
  const S(this.isId);
  final bool isId;

  String _(String id, String en) => isId ? id : en;

  // Navigasi
  String get home => _('Home', 'Home');
  String get search => _('Cari', 'Search');

  // Home
  String greeting(int hour) => switch (hour) {
        < 4 => _('Selamat malam', 'Good night'),
        < 11 => _('Selamat pagi', 'Good morning'),
        < 15 => _('Selamat siang', 'Good afternoon'),
        < 19 => _('Selamat sore', 'Good evening'),
        _ => _('Selamat malam', 'Good evening'),
      };
  String get mixesForYou => _('Mix untuk kamu', 'Mixes for you');
  String mixOf(String artist) => _('Mix $artist', '$artist mix');
  String basedOn(String title) => _('Seperti $title', 'Like $title');
  String get recommendedPlaylists =>
      _('Playlist rekomendasi', 'Recommended playlists');
  String get browse => _('Jelajahi', 'Browse');
  String get songsTitle => _('Lagu', 'Songs');
  String get albums => _('Album', 'Albums');

  // Statistik
  String get songOfTheWeek => _('Lagu minggu ini', 'Song of the week');
  String playedTimes(int n) => _('Diputar $n kali', 'Played $n×');
  String timesShort(int n) => '$n×';
  String get mostPlayed => _('Paling sering diputar', 'Most played');
  String get seeAll => _('Lihat semua', 'See all');
  String get yourStats => _('Statistik kamu', 'Your stats');
  String get periodWeek => _('7 hari', '7 days');
  String get periodMonth => _('30 hari', '30 days');
  String get periodAll => _('Semua', 'All time');
  String get plays => _('Kali diputar', 'Plays');
  String get minutes => _('Menit', 'Minutes');
  String get artists => _('Artis', 'Artists');
  String get topSongs => _('Lagu teratas', 'Top songs');
  String get topArtists => _('Artis teratas', 'Top artists');
  String get noStats => _(
        'Belum ada data. Lagu dihitung setelah didengar 30 detik.',
        'No data yet. A song counts after 30 seconds of listening.',
      );

  // Sleep timer
  String get sleepTimer => _('Sleep timer', 'Sleep timer');
  String sleepMinutes(int n) => _('$n menit', '$n minutes');
  String get sleepHour => _('1 jam', '1 hour');
  String get sleepEndOfTrack => _('Akhir lagu ini', 'End of this song');
  String get sleepOff => _('Matikan timer', 'Turn off timer');
  String sleepIn(String time) => _('Berhenti dalam $time', 'Stops in $time');
  String get sleepAtEnd => _('Berhenti di akhir lagu', 'Stops after this song');
  String get sleepHint => _(
        'Volume dikecilkan perlahan di 30 detik terakhir.',
        'Volume fades out over the last 30 seconds.',
      );
  String get loadFailed => _(
        'Gagal memuat. Periksa koneksi.',
        'Couldn\'t load. Check your connection.',
      );
  String get saveToLibrary => _('Simpan ke Library', 'Save to Library');
  String savedToLibrary(String name) =>
      _('"$name" disimpan ke Library', '"$name" saved to Library');
  String get library => _('Library', 'Library');
  String get settings => _('Pengaturan', 'Settings');

  // Pencarian
  String get searchHint => _('Cari lagu atau artis', 'Search songs or artists');
  String get recentlyPlayed => _('Baru diputar', 'Recently played');
  String get emptyHome => _(
        'Cari lagu untuk mulai mendengarkan.',
        'Search for a song to start listening.',
      );
  String get noResults => _('Tidak ada hasil.', 'No results.');
  String get searchFailed => _(
        'Pencarian gagal. Periksa koneksi lalu coba lagi.',
        'Search failed. Check your connection and try again.',
      );
  String get retry => _('Coba lagi', 'Retry');

  // Menu lagu
  String get playNext => _('Putar berikutnya', 'Play next');
  String get addToQueue => _('Tambah ke antrean', 'Add to queue');
  String get addToPlaylist => _('Tambah ke playlist', 'Add to playlist');
  String get like => _('Suka', 'Like');
  String get unlike => _('Batal suka', 'Remove like');
  String get download => _('Download', 'Download');
  String get removeDownload => _('Hapus download', 'Remove download');
  String get removeFromPlaylist =>
      _('Hapus dari playlist', 'Remove from playlist');
  String get addedToQueue => _('Ditambahkan ke antrean', 'Added to queue');
  String get willPlayNext => _('Akan diputar berikutnya', 'Will play next');
  String addedTo(String name) => _('Ditambahkan ke $name', 'Added to $name');
  String alreadyIn(String name) => _('Sudah ada di $name', 'Already in $name');
  String get downloaded => _('Download selesai', 'Download finished');
  String get downloadFailed => _('Download gagal', 'Download failed');
  String get wifiRequired => _(
        'Download hanya di Wi-Fi. Ubah di Pengaturan bila perlu.',
        'Downloads are Wi-Fi only. Change this in Settings if needed.',
      );

  // Library
  String get liked => _('Disukai', 'Liked');
  String get history => _('Riwayat', 'History');
  String get downloads => _('Download', 'Downloads');
  String get playlists => _('Playlist', 'Playlists');
  String get newPlaylist => _('Playlist baru', 'New playlist');
  String get importFromYoutube =>
      _('Import dari link playlist', 'Import from playlist link');
  String get playlistName => _('Nama playlist', 'Playlist name');
  String get playlistLink => _('Link playlist publik', 'Public playlist link');
  String get importing => _('Mengimpor playlist…', 'Importing playlist…');
  String imported(int n, String name) =>
      _('$n lagu diimpor ke $name', '$n songs imported to $name');
  String get importFailed => _(
        'Import gagal. Pastikan link benar dan playlist-nya publik.',
        'Import failed. Make sure the link is right and the playlist is public.',
      );
  String get noPlaylists => _(
        'Belum ada playlist. Buat satu atau import dari link.',
        'No playlists yet. Create one or import from a link.',
      );
  String songs(int n) => _('$n lagu', n == 1 ? '1 song' : '$n songs');
  String get playAll => _('Putar semua', 'Play all');
  String get shuffle => _('Acak', 'Shuffle');
  String get rename => _('Ganti nama', 'Rename');
  String get delete => _('Hapus', 'Delete');
  String deletePlaylistQ(String name) =>
      _('Hapus playlist "$name"?', 'Delete playlist "$name"?');
  String get clearHistory => _('Hapus riwayat', 'Clear history');
  String get emptyList => _('Belum ada lagu di sini.', 'No songs here yet.');
  String get cancel => _('Batal', 'Cancel');
  String get save => _('Simpan', 'Save');
  String get create => _('Buat', 'Create');
  String get import => _('Import', 'Import');

  // Player
  String get queue => _('Antrean', 'Queue');
  String get lyrics => _('Lirik', 'Lyrics');
  String get noLyrics =>
      _('Lirik tidak ditemukan.', 'No lyrics found for this song.');
  String get nothingPlaying => _('Belum ada yang diputar', 'Nothing playing');
  String streamFailed(String title) => _(
        'Gagal memuat "$title". Lanjut ke lagu berikutnya.',
        'Couldn\'t load "$title". Skipping to the next song.',
      );
  String playbackStopped(String title) => _(
        'Gagal memuat "$title". Pemutaran dihentikan; periksa koneksi.',
        'Couldn\'t load "$title". Playback stopped; check your connection.',
      );
  String get radioFailed => _(
        'Gagal mengambil lagu terkait.',
        'Couldn\'t fetch related songs.',
      );

  // Pengaturan
  String get appearance => _('Tampilan', 'Appearance');
  String get theme => _('Tema', 'Theme');
  String get themeSystem => _('Ikuti sistem', 'System');
  String get themeLight => _('Terang', 'Light');
  String get themeDark => _('Gelap', 'Dark');
  String get dynamicColor => _(
        'Warna cover di layar Now Playing',
        'Cover colors on Now Playing',
      );
  String get language => _('Bahasa', 'Language');
  String get playback => _('Pemutaran', 'Playback');
  String get qualityWifi => _('Kualitas di Wi-Fi', 'Quality on Wi-Fi');
  String get qualityMobile =>
      _('Kualitas di data seluler', 'Quality on mobile data');
  String get qualityLow => _('Rendah', 'Low');
  String get qualityMedium => _('Sedang', 'Medium');
  String get qualityHigh => _('Tinggi', 'High');
  String get autoRadio => _('Lanjutkan otomatis', 'Keep playing');
  String get autoRadioDesc => _(
        'Putar lagu terkait saat antrean habis',
        'Play related songs when the queue ends',
      );
  String get songsOnly => _('Hanya tampilkan lagu', 'Show songs only');
  String get songsOnlyDesc => _(
        'Cari di katalog lagu YouTube Music; matikan untuk mencari video musik',
        'Search the YouTube Music song catalog; turn off to search music videos',
      );
  String get wifiOnly => _('Download hanya di Wi-Fi', 'Download on Wi-Fi only');
  String get data => _('Data', 'Data');
  String get exportBackup => _('Export backup', 'Export backup');
  String get exportDesc => _(
        'Playlist, suka, dan riwayat ke satu file JSON',
        'Playlists, likes, and history to one JSON file',
      );
  String get importBackup => _('Import backup', 'Import backup');
  String get importDesc => _(
        'Digabung dengan data yang sudah ada',
        'Merged with your existing data',
      );
  String get backupSaved => _('Backup disimpan', 'Backup saved');
  String get backupRestored => _('Backup dipulihkan', 'Backup restored');
  String get backupFailed => _(
        'File tidak bisa dibaca sebagai backup Yumusic.',
        'That file can\'t be read as a Yumusic backup.',
      );
  String get battery => _('Musik berhenti sendiri?', 'Music stops by itself?');
  String get batteryDesc => _(
        'Cara mematikan optimasi baterai',
        'How to turn off battery optimization',
      );
  String get batteryGuide => _(
        'Beberapa HP (Xiaomi, Oppo, Vivo, Realme, Samsung) mematikan app di '
            'background untuk menghemat baterai.\n\n'
            '1. Buka Pengaturan HP > Aplikasi > Yumusic.\n'
            '2. Pilih Baterai.\n'
            '3. Pilih "Tidak dibatasi" atau "Tanpa batasan".\n'
            '4. Di Xiaomi/Oppo/Vivo, aktifkan juga "Mulai otomatis" '
            '(Autostart).',
        'Some phones (Xiaomi, Oppo, Vivo, Realme, Samsung) stop background '
            'apps to save battery.\n\n'
            '1. Open phone Settings > Apps > Yumusic.\n'
            '2. Choose Battery.\n'
            '3. Choose "Unrestricted" or "No restrictions".\n'
            '4. On Xiaomi/Oppo/Vivo, also turn on "Autostart".',
      );
  String get ok => _('OK', 'OK');
  String get diagnostics => _('Diagnosa pemutaran', 'Playback diagnostics');
  String get diagnosticsDesc => _(
        'Uji tiap tahap dan lihat error lengkapnya',
        'Test each step and see the full error',
      );
  String get diagnosticsHelp => _(
        'Menguji database, pencarian, URL stream, pengambilan audio, dan '
            'pemutar satu per satu. Butuh sekitar setengah menit. Salin '
            'hasilnya dengan tombol di kanan atas.',
        'Tests the database, search, stream URL, audio fetch, and player one '
            'by one. Takes about half a minute. Copy the result with the '
            'button at the top right.',
      );
  String get runDiagnostics => _('Jalankan', 'Run');
  String get copy => _('Salin', 'Copy');
  String get copied => _('Disalin', 'Copied');
  String get about => _('Tentang', 'About');
  String get aboutDesc => _(
        'Pemutar musik gratis dan open source. Tanpa iklan, akun, atau tracking.',
        'Free and open source music player. No ads, accounts, or tracking.',
      );
}
