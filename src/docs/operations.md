# Operasi lokal

Dari folder `src/`, jalankan `scripts/setup.sh`, `scripts/start.sh` dan `scripts/health.sh`. Lihat [README](../README.md) untuk prasyarat. Setup menghasilkan secret acak, migrasi memakai checksum/advisory lock dan data tidak direset saat startup. Seed harus dijalankan eksplisit; akun fiktif tersimpan privat di `.secrets/demo-access.txt`.

API bind localhost3100 dan PostgreSQL localhost55432 secara default. API/worker non-root dengan APP_UID/APP_GID yang mengikuti operator lokal (atau1000 saat setup oleh root), root filesystem read-only, resource/log limit dan health check. Database memakai volume Docker, media di `uploads/`. `scripts/stop.sh` tidak menghapus data. Jangan menjalankan `docker compose down -v` pada data yang ingin dipertahankan.

## HTTPS dan akses dari perangkat

Untuk endpoint tetap gunakan [VPS dan Caddy](vps-deployment.md). Operator menetapkan origin saat build melalui `scripts/build-apk.sh https://HOST`. Aplikasi pengguna tidak menyediakan konfigurasi IP/server.

Tunnel opsional untuk demo lokal:

```bash
./scripts/install-cloudflared.sh
./scripts/tunnel.sh
./scripts/build-apk.sh https://HOST_SEMENTARA
```

Tunnel hanya hidup selama proses/laptop hidup. Jika hostname berubah, buat build dengan origin baru; jangan meminta pengguna mengatur jaringan. Quick Tunnel adalah [layanan development/testing Cloudflare](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/do-more-with-tunnels/trycloudflare/), bukan jaminan uptime. Mode pengembang khusus dapat mengaktifkan pengaturan server lewat `DEVELOPER_SETTINGS=true`, bukan untuk distribusi pengguna.

## Backup dan pemulihan

```bash
./scripts/backup.sh ./backups
./scripts/restore.sh ./backups/sisarasa-TIMESTAMP --test
./scripts/test-backup.sh
```

Backup menghentikan writer API/worker secara graceful, mengambil dump database dan media, lalu memulihkan hanya layanan yang sebelumnya hidup walaupun backup gagal. DB tetap hidup. Jangan menulis langsung lewat alat lain pada saat backup. Operator lock mencegah setup/start/backup bersamaan pada project yang sama.

Folder backup berisi `manifest.json`, SHA-256, `database.dump`, `media.tar.gz`, dan `recovery.env`. Hak folder0700/file0600; retensi satu backup valid terakhir per hari untuk tujuh hari UTC. Backup gagal dibersihkan. `recovery.env` mengandung kunci dekripsi tiket dan password: salin lengkap ke penyimpanan privat terpisah, idealnya terenkripsi. Backup pada disk yang sama tidak melindungi kerusakan host.

Restore hanya mendukung mode uji ke database/direktori terpisah: validasi checksum, restore dengan exit-on-error, verifikasi media dan dekripsi tiket, lalu pembersihan lingkungan uji. Untuk pemulihan nyata, siapkan deployment baru, uji backup, hentikan writer lama, pulihkan dump/media/recovery.env bersama, jalankan migrasi dan validasi login/tiket sebelum cutover. Jangan menimpa volume aktif atau mengganti PICKUP_KEY saat tiket lama masih diperlukan.

Tes operasi memakai project/container/media terpisah; database test tidak bind port tetap, API test3311. Hanya volume project test yang dibuang. Simpan keystore/password APK secara privat agar update aplikasi memakai signing identity yang sama.

## Diagnosis

Gunakan `docker compose ps`, `docker compose logs --tail 100 api worker`, dan `scripts/health.sh`. Jangan menyalin `.env`, token, OTP atau berkas bukti pengguna ke issue publik. Periksa `/health/ready` lewat HTTPS dari jaringan perangkat selain memeriksa localhost. Pemantauan Android tunduk pada izin/batas waktu sistem; inbox dapat disinkronkan saat aplikasi dibuka kembali.
