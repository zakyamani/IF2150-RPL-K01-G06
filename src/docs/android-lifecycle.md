# Siklus hidup Android

Verifikasi 13 November 2026 menggunakan Android15/API35 x86_64, target SDK36 dan AndroidJUnitRunner pada AVD kosong khusus pengujian (`emulator-5582`), API repo akademik3101 dan TEST_API_BASE yang diteruskan ke Gradle. Keenam file integration_test dijalankan ulang terhadap source terbaru; hasil dirangkum di [verification.md](verification.md).

- Marketplace menguji secure storage, registrasi lewat API/PostgreSQL, QR berbayar, OTP manual dengan konfirmasi, ulasan dan payout demo.
- Process recovery memakai APK/proses terpisah sesudah force-stop, socket jaringan diblokir, tiket terenkripsi tetap tampil offline, dan logout menghapus tiket aktor.
- Offline ticket menguji restore secure storage serta peringatan setelah jadwal berakhir.
- Permission denial menguji POST_NOTIFICATIONS yang benar-benar ditolak pada Android; perubahan flags dipulihkan oleh runner.
- Notification navigation menguji plugin foreground native, opt-in, penghentian saat logout dan penolakan tap milik akun sebelumnya.
- Timeout mengaktifkan foreground service, HOME dan screen-off, mempercepat batas dataSync menjadi5000ms, lalu memeriksa callback/pemulihan. Pengaturan asli dikembalikan dan layar dibangunkan.

Service memakai dataSync opt-in, tidak auto-boot/auto-restart dan memiliki watchdog90detik untuk acknowledgement proses utama. Service tidak menyimpan JWT/refresh token. Inbox server tetap persisten dan catch-up saat aplikasi dibuka. Pembatasan waktu Android tetap berlaku; ini bukan layanan push yang dijanjikan hidup selamanya.

Widget/controller tests melengkapi bukti reconnect WebSocket, ticket refresh, catch-up cursor, deduplikasi event dan actor/epoch guard. Belum ada bukti kamera dua HP, sensor lokasi, perangkat API29 fisik, pembatasan baterai OEM, jaringan3G/10Mbps camera-to-status atau soak panjang. Jangan menyamakan hasil emulator dengan seluruh kondisi produksi.
