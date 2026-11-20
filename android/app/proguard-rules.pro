# Nama kelas tetap terbaca, supaya pesan error dari build rilis masih masuk akal.
-dontobfuscate

# NewPipe membaca YouTube dengan refleksi dan menjalankan skrip pemutar YouTube
# lewat Rhino; tanpa aturan ini sebagian kodenya terbuang di build rilis.
-keep class org.schabi.newpipe.extractor.** { *; }
-keep class org.mozilla.javascript.** { *; }
-keep class org.mozilla.classfile.ClassFileWriter
-dontwarn org.mozilla.javascript.tools.**
-dontwarn javax.script.**
-dontwarn java.beans.**
-dontwarn org.ietf.jgss.**
-dontwarn jdk.dynalink.**
