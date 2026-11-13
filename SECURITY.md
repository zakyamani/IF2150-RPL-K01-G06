# Keamanan

Jangan melaporkan kredensial atau data pengguna lewat issue publik. Jika menemukan kebocoran, hentikan pemakaian kredensial terkait, rotasi lewat operator, dan koordinasikan secara privat dengan pemilik repo.

Konfigurasi runtime dibuat oleh `src/scripts/setup.sh`; `.env`, key signing, backup dan upload tidak masuk Git. Endpoint/IP disetel pada build aplikasi, tidak ditampilkan pada antarmuka normal. Pengaturan pengembang hanya tersedia jika sengaja dibuild dengan `DEVELOPER_SETTINGS=true`.

Pembayaran dan pencairan adalah simulasi. Jangan memasukkan rekening nyata. Data seed/fixture harus fiktif. HTTPS dan signature release wajib untuk distribusi pengguna; HTTP hanya untuk pengembangan/emulator.
