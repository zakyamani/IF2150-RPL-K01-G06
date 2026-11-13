# Kontribusi

Panduan menjalankan aplikasi ada di [src/README.md](src/README.md). Mulai dari issue dengan lingkup dan kriteria selesai, lalu buat branch fitur dari `main` terbaru. Gunakan commit semantik dan PR yang mencantumkan issue, perubahan serta hasil pengujian. Minta minimal satu anggota lain memberi review sebelum merge.

Pembagian modul mengikuti laporan M9 B.4. Jika mengintegrasikan source yang telah disiapkan, jelaskan asalnya dan penyesuaiannya; gunakan identitas Git sendiri. Commit mewakili perubahan nyata, tanpa mengubah tanggal atau membuat atribusi atas nama anggota lain.

Jalankan `cd src && ./scripts/test.sh`. Perubahan native Android juga memerlukan emulator dan `./scripts/e2e.sh`. Database benchmark/test disposable dan tidak boleh digunakan paralel oleh dua test runner. Jangan commit `.env`, signing key, database/media atau output build. Perubahan schema memakai migrasi baru; perubahan API memperbarui OpenAPI, model dan tests terkait.

Source berada di `src/`, laporan di `docs/M9/`. Dokumen milestone lama tetap dipertahankan. Release/tag pengumpulan dibuat sesuai ketentuan dan waktu sebenarnya; tidak dibuat otomatis oleh proses integrasi ini.
