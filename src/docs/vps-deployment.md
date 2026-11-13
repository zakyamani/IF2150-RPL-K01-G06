# Deployment VPS

Panduan untuk operator Linux dengan Docker/Compose dan hostname publik. Instalasi source baru tidak otomatis mengubah deployment yang sudah hidup. Simpan backup konsisten dan recovery keys sebelum migrasi atau penggantian source.

Contoh layout: `/opt/sarirasa/src`. Dari folder tersebut:

```bash
./scripts/setup.sh
# Tambahkan PUBLIC_HOST=api.domain-anda.example ke .env privat.
docker compose --env-file .env -f compose.yaml -f compose.vps.yaml up -d --wait api worker proxy
./scripts/health.sh
```

Hostname harus menunjuk ke VPS dan port80/443 dapat dijangkau. API/DB tetap localhost; hanya Caddy yang menerima HTTPS publik. `deploy/Caddyfile` memakai PUBLIC_HOST dan API_HOST_PORT. Caddy menyimpan sertifikat di volume persisten dan mengelola pembaruan HTTPS. Jangan menghapus volume database/media/Caddy saat update.

Runtime secrets disediakan operator; jangan menyalin `.env` ke Git. Setup tidak menimpa secret yang sudah ada. Akses SSH mengikuti pengelolaan operator, bukan kredensial yang dimasukkan ke aplikasi. Untuk distribusi Android, build dengan `./scripts/build-apk.sh https://HOST_API`. Endpoint tidak ditampilkan di UI pengguna.

## Backup harian

`deploy/sisarasa-backup.service` dan `.timer` adalah contoh untuk layout `/opt/sarirasa/src`; sesuaikan path jika berbeda. Pasang ke systemd hanya sesudah menguji backup/restore secara manual. Timer berjalan19:00UTC/02:00WIB dengan persistent catch-up. Backup menghentikan writer sebentar; permintaan dapat gagal selama jeda itu.

```bash
./scripts/backup.sh ./backups
./scripts/restore.sh ./backups/sisarasa-TIMESTAMP --test
sudo cp deploy/sisarasa-backup.service deploy/sisarasa-backup.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now sisarasa-backup.timer
```

Salin backup lengkap ke penyimpanan privat di luar VPS; timer ini tidak melakukan replikasi offsite. Latih pemulihan pada deployment baru sebelum cutover. Panduan [operasi](operations.md) menjelaskan format, retensi dan perlindungan recovery keys.

## Verifikasi setelah deployment

Periksa HTTPS `/health/ready`, login, katalog anonim, checkout retry, pembayaran demo, reveal gerai, inbox dan pickup. Jalankan ulang native Android terhadap origin tersebut sebelum menyatakan deployment baru terverifikasi. Hasil pengujian lokal di repo ini bukan pengukuran kapasitas VPS, jaringan3G atau kamera HP. Paket VM2CPU/RAM2GB/disk30GB tetap perlu pemantauan disk, backup dan beban nyata.
