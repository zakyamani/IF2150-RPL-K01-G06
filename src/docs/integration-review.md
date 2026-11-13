# Review integrasi source akademik

Tanggal:13 November2026. Base akademik:80438ca. Referensi:sarirasa@418b728. Issue:[#15](https://github.com/zakyamani/IF2150-RPL-K01-G06/issues/15), PR:[#16](https://github.com/zakyamani/IF2150-RPL-K01-G06/pull/16).

## Backend

- File UC01/UC02 Devina dipertahankan. Pada tujuh file backend offers/catalog yang berbeda, pemeriksaan memperlihatkan perbedaan whitespace/format import; logika sesuai referensi. Validasi diskon, kuota, batas waktu, anonimitas, row lock dan filter diuji melalui PostgreSQL.
- Backend notifikasi Atan serta pickup/pengaduan Jaki dipertahankan. Dua file test semula berada di `backend/test/`, tetapi menggunakan import relatif untuk `test/integration/`. File dipindahkan dengan isi identik sehingga fixture/import dapat ditemukan; Git mencatat rename100%.
- Melengkapi dependensi auth/crypto, orders/payments/payouts, repository pickup, media/merchant, reviews/metrics, jobs, startup, migrasi dan test runner. Source UC03 dimasukkan Nabil dengan persetujuannya dan asalnya dicatat, tidak dibuat commit atas nama Bintang.
- Backend lolos typecheck serta47test, termasuk race/idempotensi, kepemilikan, refund, ulasan dan backup/restore. Tidak ditemukan perbedaan aturan bisnis baru pada kode teman-teman yang diperiksa; temuan utama sebelumnya adalah kelengkapan dependensi dan lokasi tests.

## Android

- Lima file buyer/model tidak memiliki newline akhir. CI formatter menemukannya; penambahan newline diuji dengan perbandingan seluruh teks dan tidak mengubah logika. Layar/controller teman-teman dipertahankan.
- Menambahkan auth, sesi/API/storage, tema/widget/font, konfigurasi Android, entry point dan screen checkout/OTP/history/review yang belum tersedia.
- Native runner menyiapkan Gradle wrapper melalui Flutter dan menerima TEST_API_BASE untuk memastikan pengujian diarahkan ke API akademik, bukan backend referensi yang masih hidup pada port lain.
- Flutter analyze,63unit/widget dan6skenario native Android lulus. Tidak mengklaim pengujian dua HP atau kamera fisik.

## Dokumentasi dan review PR

- README dan prosedur test/start/seed kini tersedia di repo akademik; profiler dapat dijalankan ulang.
- B.2 merujuk PR/issue yang sesuai. Komentar review terlihat pada PR7 serta PR12–14; PR2/5/9 belum memiliki record review GitHub saat pemeriksaan. PR16 tetap membutuhkan review anggota lain.
- C01–C11 dipetakan ke source aktual. Implementasi C08/C09 tetap dikreditkan pada PR Jaki, C02/C03 pada Devina, dan fondasi/UC04 pada Atan.
- B.4 mengikuti pembagian tugas lima anggota tanpa persentase sesuai instruksi Nabil. Label dokumen pada form asistensi diperbaiki dari M3 ke M9; hari/tanggal kegiatan tetap perlu diisi tim sesuai kegiatan sebenarnya. AI usage dan logbook mencatat integrasi ini dengan tanggal sebenarnya.

Integrasi tidak mengubah file milestone M1–M8, tidak membuat tag pengumpulan mundur, dan tidak mengubah identitas/waktu commit anggota lain. Semua commit baru memakai identitas Git yang sedang terkonfigurasi. [Hasil tes](verification.md).
