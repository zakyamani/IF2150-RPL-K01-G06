# Perbandingan source dan dependensi

Diperiksa pada 13 November 2026: integrasi akademik `57f23d8` dibandingkan dengan `aniceswan/sarirasa@418b728`. Branch integrasi sudah memuat perubahan dokumentasi teman dari `main@4661a91`. PR #16 belum memiliki approval saat pemeriksaan; pengujian ini dilakukan pada branch PR, belum pada hasil merge ke `main`.

## Source aplikasi

| Bagian | Hasil |
| --- | --- |
| Backend `src/` | 62 dari 69 file identik; tujuh file katalog/penawaran hanya berbeda spasi import |
| Migrasi database | Dua file identik |
| Flutter `lib/` | Semua 72 file identik |
| Project Android native | Semua 25 file identik |
| File runtime yang belum masuk | Tidak ada |

Perbedaan lain ada pada dokumentasi, bukti pengujian, nama project/image Compose untuk isolasi, port database test yang dapat diatur, serta penerusan `TEST_API_BASE` ke pengujian Flutter/Gradle. Berkas desain FigCraft dan gambar dokumentasi referensi tidak disalin sebagai bagian runtime. Pemetaan kelas akademik berada pada laporan M9.

## Versi dependensi

`package.json`, `package-lock.json`, `pubspec.yaml`, `pubspec.lock`, Dockerfile backend, konfigurasi Android/Gradle dan wrapper identik dengan referensi. Seluruh versi paket runtime backend yang terpasang sesuai lockfile; versi paket pada container API akademik dan referensi lokal juga sama. `flutter pub get --enforce-lockfile` berhasil.

| Komponen | Versi |
| --- | --- |
| Express / pg / ws | 4.22.3 / 8.23.1 / 8.22.0 |
| bcrypt / jsonwebtoken | 6.0.0 / 9.0.3 |
| TypeScript | 7.0.2 |
| Flutter / Dart saat pengujian | 3.47.2 / 3.13.2 |
| dio / flutter_secure_storage | 5.11.1 / 11.2.0 |
| mobile_scanner / qr_flutter | 7.4.2 / 4.1.0 |
| geolocator / flutter_foreground_task | 14.1.1 / 11.0.3 |
| Gradle / Android Gradle Plugin / Kotlin | 9.3.1 / 9.1.0 / 2.4.0 |
| Minimum / target Android | API 29 / 36 |
| PostgreSQL container lokal, kedua project | 15.19 |
| Node container akademik / referensi lokal | 22.23.5 / 22.23.4 |
| Caddy pada konfigurasi VPS, kedua repo | 2.11.7-alpine |

Perbedaan patch Node berasal dari image yang sudah dibangun pada waktu berbeda: kedua Dockerfile memakai `node:22-bookworm-slim`. Tag Node tersebut dan `postgres:15-alpine` belum dikunci ke digest sehingga build baru dapat memperoleh patch berbeda. Lockfile npm/Flutter tetap identik. Versi VM yang sedang hidup belum dapat diverifikasi; angka container di atas berasal dari Docker lokal, bukan VM.

## Pengujian ulang

- Build backend berhasil; 47 backend tests lulus, 0 gagal, memakai PostgreSQL disposable pada port 55436.
- Flutter analyze bersih; 63 unit/widget tests lulus, 0 gagal.
- Enam skenario Android native lulus pada emulator API 35: marketplace, pemulihan proses, penolakan izin notifikasi, timeout background, navigasi notifikasi, dan tiket offline.
- Native test memakai API akademik `http://10.0.2.2:3101`, bukan API referensi pada port 3100. API, worker dan database akademik sehat.
- APK debug aplikasi normal dari `lib/main.dart` berhasil dibangun untuk ARM64/x86_64, dipasang dan dibuka pada emulator. Layar login tampil tanpa fatal error pada log startup.
- Signing guard lulus. Build release bertanda tangan dan pengujian HP fisik tidak dilakukan pada pemeriksaan ini.

Lihat [bukti perbandingan dan checksum](evidence/source-comparison.json) serta [verifikasi integrasi](verification.md). Hasil ini tidak mengubah deployment VM dan tidak membuktikan bahwa commit atau versi runtime VM sama dengan checkout lokal.
