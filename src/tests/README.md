# Lokasi pengujian

Test berada di lokasi standar tiap toolchain:

- `../backend/test/unit`: aturan penawaran.
- `../backend/test/integration`: PostgreSQL nyata, auth, anonimitas, transaksi, idempotensi, race, media dan worker.
- `../backend/test/e2e`: alur marketplace HTTP penuh.
- `../backend/test/operations`: backup/restore dan pemulihan layanan setelah kegagalan.
- `../android-app/test`: controller, API/cache, UI, aksesibilitas dan antarmuka tanpa pengaturan teknis.
- `../android-app/integration_test`: Android native dengan API lokal, persistensi offline dan izin/background.
- `../scripts/test`: pemeriksaan signing release.

Jalankan `../scripts/test.sh` dari folder ini atau `./scripts/test.sh` dari `src/`. Database test disposable menggunakan port 55433; jangan arahkan TEST_DATABASE_URL ke data pengguna. Benchmark juga mereset database test, jadi jalankan setelah test lain selesai.
