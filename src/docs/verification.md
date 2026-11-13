# Verifikasi integrasi — 13 November 2026

Source repo akademik menggabungkan modul anggota dari base80438ca dan dependensi yang belum tersedia dari sarirasa@418b728. Pengujian dijalankan pada working copy integrasi ini, bukan sekadar memakai laporan referensi.

| Pemeriksaan | Hasil |
| --- | --- |
| Typecheck TypeScript | Lulus |
| Backend/PostgreSQL | 47 lulus, 0 gagal, termasuk auth, kontrak, concurrency, transaksi, pickup, ulasan, worker dan backup/restore |
| Flutter analyze | Bersih |
| Flutter unit/widget | 63 lulus, 0 gagal |
| Dart formatter | 103 file bersih setelah menambahkan newline akhir pada5file lama; tidak ada perubahan logika |
| Signing guard | 1 lulus; release menolak konfigurasi signing yang hilang |
| Android marketplace | 1 lulus: registrasi, pembayaran, QR, OTP, ulasan dan payout simulasi |
| Android process recovery | 1 lulus: APK/proses terpisah, jaringan diblokir, tiket offline dan logout |
| Android notification denial | 1 lulus: izin ditolak tanpa kehilangan akun |
| Android timeout | 1 lulus: HOME/screen-off, batas dataSync dipercepat dan pemulihan |
| Android notification navigation | 1 lulus: foreground service opt-in dan guard akun lama |
| Android offline ticket | 1 lulus: secure storage dan peringatan jadwal berakhir |
| Audit import internal | 61 target yang sebelumnya hilang menjadi0 |

API/worker/database akademik menggunakan project `sisarasa-academic`, API3101 dan DB55437 saat verifikasi. PostgreSQL test terpisah pada55436. Native memakai emulator kosong5582 dan `TEST_API_BASE=http://10.0.2.2:3101`; nilai ini diteruskan ke Flutter dan Gradle instrumentation. Backend referensi pada3100 tidak dipakai oleh pengujian native ini.

SDK: Node22.18, Flutter3.47.2/Dart3.13.2, AndroidAPI35/target36. Kamera dua HP, GPS fisik, API29 hardware, kebijakan baterai OEM, jaringan3G dan soak panjang belum diuji. Timeout dipercepat menguji callback, bukan monitoring enam jam.

Profiling baru: 30 request pickup HTTP lokal, 0 gagal. Hasil lengkap ada di [benchmark.json](evidence/benchmark.json), ringkasan test pada [test-summary.json](evidence/test-summary.json). Pengukuran tidak mencakup latensi kamera, internet atau kapasitas VPS. Reproduksi: [README](../README.md).

## Pengujian ulang setelah sinkronisasi main

Branch integrasi `57f23d8` memuat dokumentasi terbaru teman dari `main@4661a91`. Build backend, 47 backend tests, 63 Flutter tests, analyze, signing guard dan keenam skenario native dijalankan ulang dan lulus. APK debug aplikasi normal juga dibangun untuk ARM64/x86_64 dan berhasil dibuka sampai layar login. Perbandingan source, lockfile dan versi container lokal dicatat pada [perbandingan source](source-comparison.md). PR belum di-merge saat pengujian ini karena belum ada approval.
