# SisaRasa

Aplikasi Android pemesanan paket surplus makanan. Source terdiri dari **backend** (`backend/`) dan **aplikasi Android** (`android-app/`). Keduanya diintegrasikan dalam monorepo ini.

## Teknologi

| Komponen | Versi pengujian |
| --- | --- |
| Flutter / Dart | 3.47.2 / 3.13.2 |
| Node.js / TypeScript / Express | 22.18 / 7.0.2 / 4.22 |
| Database | PostgreSQL 15 |
| Android | min SDK29, compile/target SDK36; emulator pengujian API35 |
| Build dan operasi | JDK21, Docker Compose, Python3.12 |

Dependensi dikunci melalui `backend/package-lock.json` dan `android-app/pubspec.lock`.

## Struktur dan arsitektur

```text
src/
  android-app/
    lib/main.dart          Startup aplikasi
    lib/app.dart           Navigasi pembeli dan mitra
    lib/core/              Model, API, sesi, secure storage, tema dan widget
    lib/features/          Auth, katalog, penawaran, checkout, pickup, riwayat, ulasan
    test/                  Unit/controller/widget
    integration_test/      Pengujian Android native
    android/               Manifest, Gradle dan konfigurasi perangkat
  backend/
    src/index.ts           Startup HTTP
    src/app.ts             Middleware, route dan WebSocket
    src/worker.ts          Job/outbox background
    src/core/              Database, autentikasi, crypto dan efek transaksi
    src/modules/           Route → service → repository per fitur
    migrations/            Skema, constraint dan index SQL
    scripts/               Migrasi, seed dan test runner
    test/                  Unit, PostgreSQL, e2e, operasi dan profiling
    openapi.yaml           Kontrak API
  scripts/                 Setup, operasi, pengujian dan build APK
  compose*.yaml            Runtime lokal, PostgreSQL test dan profil VPS
  deploy/                  Caddy dan backup timer opsional
  docs/                    Panduan operasi, hasil test dan review integrasi
```

Flutter berkomunikasi dengan API melalui HTTP pada debug lokal atau HTTPS pada release. API menegakkan otorisasi, validasi, reservasi kuota dan aturan status di dalam transaksi PostgreSQL. Worker memakai database yang sama untuk expiry, no-show, refund, payout simulasi dan outbox. WebSocket mengirim pembaruan; inbox persisten menyimpan event saat aplikasi tidak tersambung.

Tiket paid disimpan pada secure storage per akun. Pembeli dapat membukanya offline, tetapi validasi QR/OTP oleh mitra tetap online. API, worker dan database dijalankan terpisah oleh Compose; tidak membutuhkan akun cloud untuk pengujian lokal.

## Instalasi dan menjalankan lokal

Prasyarat Linux: Git, Docker Engine dengan plugin Compose, Python3.12+, Node22/npm. Untuk aplikasi pasang Flutter3.47.2, JDK21, Android SDK36/build tools36, lalu jalankan `flutter doctor` dan terima lisensi Android.

Dari root repo:

```bash
cd src
./scripts/setup.sh
./scripts/start.sh
./scripts/health.sh
./scripts/seed.sh
```

Setup membuat `.env` privat dengan secret acak, membangun image, menyiapkan database dan menjalankan migrasi. Project Compose `sisarasa-academic` terpisah dari repo referensi `sarirasa`. API default `127.0.0.1:3100`, PostgreSQL `127.0.0.1:55432`.

Jika port sudah terpakai, pilih port saat setup pertama:

```bash
API_HOST_PORT=3101 DB_HOST_PORT=55437 ./scripts/setup.sh
./scripts/start.sh
```

Jangan mengubah secret/database deployment yang sudah berisi tiket hanya untuk mengganti port. Seluruh nama variabel ada di [.env.example](.env.example); `APP_UID`/`APP_GID` mengikuti operator Linux agar media privat dapat dibaca proses backup tanpa membuka izin publik.

Untuk emulator Android, dari folder `src/android-app`:

```bash
flutter pub get --enforce-lockfile
flutter run --dart-define=API_BASE=http://10.0.2.2:3100
```

Sesuaikan3100 dengan port backend. `10.0.2.2` mengarah ke host emulator. HP fisik memerlukan endpoint HTTPS yang dapat dijangkau; lihat [operasi](docs/operations.md) dan [VPS](docs/vps-deployment.md). Pengaturan server tersembunyi dari UI normal; build operator khusus dapat mengaktifkan `DEVELOPER_SETTINGS=true`.

## Akun dan data uji

`seed.sh` dijalankan eksplisit, menghasilkan akun pembeli dan mitra **fiktif**. Kredensial tersedia lokal pada `.secrets/demo-access.txt` (privat dan tidak masuk Git). Seed tidak mereset akun lama; penawaran contoh berakhir dua jam setelah seed. Registrasi kedua peran juga tersedia melalui aplikasi.

Alur uji: mitra melengkapi profil dan membuat penawaran → pembeli checkout/pembayaran → pembeli menunjukkan QR/OTP → mitra memvalidasi dalam jadwal → pembeli memberi ulasan. Gunakan dua emulator/perangkat atau ganti akun; logout menghapus cache tiket akun tersebut. Untuk pengaduan gunakan order paid yang belum diselesaikan.

## Modul dan pembagian tugas

| Anggota | Pembagian |
| --- | --- |
| Atan | Fondasi Express/Flutter, UC04 pesanan real-time; README, B.2.1 dan B.3 |
| Devina | UC01/UC02 katalog, alergen dan penawaran; B.1/B.5 C02–C03 dan bukti B.2 |
| Bintang | UC03 checkout, tiket dan gateway pembayaran; B.1/B.5 C04–C07 dan bukti B.2 |
| Jaki | UC05/UC06 scan, OTP, cache offline dan pengaduan/refund; B.1/B.5 C08–C09 |
| Nabil | Auth, UC07 riwayat/ulasan dan integrasi akhir; B.1/B.5 C10–C11, B.4 dan pemeriksaan tautan B.2 |

UC03 pada hasil integrasi ini dimasukkan Nabil dari source referensi atas persetujuannya, karena belum masuk melalui PR Bintang. Riwayat commit tidak dibuat atas nama Bintang. Catatan source/perubahan teman-teman: [review integrasi](docs/integration-review.md).

## Database

Atribut, tipe, foreign key dan constraint lengkap: [001_initial.sql](backend/migrations/001_initial.sql), [002_background_indexes.sql](backend/migrations/002_background_indexes.sql).

| Kelompok | Tabel |
| --- | --- |
| Akun dan gerai | `users`, `sessions`, `merchant_profiles` |
| Marketplace | `offers`, `orders`, `checkout_reservations` |
| Pembayaran/pickup | `payment_intents`, `payment_events`, `pickup_credentials`, `refunds` |
| Pengaduan/media | `complaints`, `complaint_media`, `media_assets` |
| Keuangan | `payout_entitlements`, `payout_events`, `ledger_entries` |
| Ulasan/audit | `reviews`, `audit_logs` |
| Background/notifikasi | `notifications`, `outbox`, `jobs` |
| Pengamanan request | `idempotency_keys`, `rate_buckets`, `ws_tickets` |

Database menggunakan volume Docker; media ada di `uploads/`; cache perangkat berada di secure storage. `stop.sh` tidak menghapus database/media. Jangan memakai `docker compose down -v` pada data yang perlu dipertahankan.

## Pengujian

Dari `src/`:

```bash
./scripts/test.sh
python3 scripts/test/signing_test.py
./scripts/benchmark.sh
```

`test.sh` menyiapkan PostgreSQL disposable port55433, menginstal dependensi, menjalankan typecheck/backend tests, Flutter analyze dan widget/unit tests. Benchmark mereset database test yang sama: jalankan berurutan. API/database marketplace tidak dipakai oleh fixture test.

Port test alternatif:

```bash
TEST_DB_HOST_PORT=55436 ./scripts/test.sh
TEST_DATABASE_URL=postgres://sisarasa_test:disposable-test-only@127.0.0.1:55436/sisarasa_test ./scripts/benchmark.sh
```

Native E2E membutuhkan API/worker hidup serta emulator Android15 x86_64 khusus pengujian:

```bash
ANDROID_SERIAL=emulator-5580 ./scripts/e2e.sh
# Jika API lokal memakai3101:
ANDROID_SERIAL=emulator-5582 TEST_API_BASE=http://10.0.2.2:3101 ./scripts/e2e.sh
```

Runner menginstal APK debug/instrumentation, menghentikan proses aplikasi dan menyesuaikan sementara izin/timeout Android. Gunakan AVD kosong khusus test, bukan HP berisi data pengguna. Jalankan marketplace sebelum process recovery karena keduanya menguji tiket lintas proses. [Hasil verifikasi](docs/verification.md) membedakan bukti lokal, native dan batas perangkat fisik.

## Build dan operasi

```bash
./scripts/setup-signing.sh
./scripts/build-apk.sh https://HOST_API_ANDA
./scripts/backup.sh ./backups
./scripts/restore.sh ./backups/sisarasa-TIMESTAMP --test
./scripts/stop.sh
```

Release membutuhkan signing privat; tidak memakai debug signature. Hasil APK/checksum ada di `artifacts/`, tidak masuk Git. Keystore, `.env`, media, backup dan hasil instalasi/build juga diabaikan Git. Simpan APK pada asset Release bila tim membuat rilis.

Backup memuat database, media dan recovery key. Restore uji memakai lingkungan terpisah; salin backup privat ke luar host. Panduan [operasi](docs/operations.md) menjelaskan format, retensi dan pemulihan layanan.

## Catatan

1. Pembayaran, rekening, fee, refund dan payout menggunakan simulasi; tidak ada transfer bank nyata.
2. Alergen dan batas konsumsi diisi mitra. Filter tidak menjamin bebas kontaminasi silang.
3. Pengujian kamera dua HP, OEM, perangkat fisik API29, jaringan3G dan pemantauan panjang perlu dilakukan terpisah.
4. Source referensi awal: [sarirasa, commit418b728](https://github.com/aniceswan/sarirasa/tree/418b728). Perubahan integrasi dan hasil pemeriksaan dicatat pada PR, logbook dan deklarasi AI.
