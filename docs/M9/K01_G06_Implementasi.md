<h1>
IF2150 REKAYASA PERANGKAT LUNAK
<br>
TUGAS 9
<br>
IMPLEMENTASI PERANGKAT LUNAK
</h1>
<br>

## *SisaRasa*
<p align="center">
  <img alt="Penerapan Arsitektur Client-Server dan Layered pada SisaRasa" src="./assets/sisarasa-logo.png" width="50%">
</p>

### Untuk: *Amanda Aurellia Salsabilla*

Dipersiapkan oleh:
| Informasi | Keterangan |
| --------- | ---------- |
| Kelas     | K1         |
| Kelompok  | 6          |

| NIM      | Nama                         |
| -------- | ---------------------------- |
| 13525067 | Fathar Atandra Denaya        |
| 13525040 | Muhammad Zaky Amani          |
| 13525139 | Josephine Bintang N.L        |
| 13525070 | Devina Athalia Putri Kusumah |
| 13525004 | Nabil Rabbani                |
---

> **Petunjuk pengerjaan:** *[Silahkan hapus bagian ini setelah selesai mengerjakan]*
>
> Dokumen ini adalah **spesifikasi sekaligus template laporan singkat** Tugas 9. Bagian **Ketentuan Implementasi** (Bagian A) adalah aturan yang harus kalian ikuti, boleh dihapus dari laporan akhir. Bagian **Laporan Implementasi** (Bagian B) adalah yang **wajib kalian isi**. Gunakan nama, ID, kebutuhan, use case, dan kelas yang konsisten dengan SKPL, APL, dan DPPL.

---

**Deadline:** Rabu, 11 November 2026, 21.50 WIB
**Asistensi akbar:** Senin, 2 November 2026, 19.00 WIB

---

# BAGIAN A: Ketentuan Implementasi

## A.1 Deskripsi Tugas

Pada tugas ini, kalian mengimplementasikan perangkat lunak yang telah dirancang pada tugas-tugas sebelumnya (SKPL, APL, DPPL) menjadi aplikasi yang **dapat dijalankan**. Platform bebas (web, desktop, atau mobile) selama aplikasi dapat dijalankan ulang oleh asisten mengikuti petunjuk kalian.

Ketentuan umum:
- Setiap anggota bertanggung jawab atas **minimal satu fitur atau modul** dan harus terlihat jelas di riwayat commit/PR.
- Implementasi harus **mengacu pada DPPL**. Jika ada yang berubah (kelas, layar, basis data, dsb.), catat di Bagian B.1. Perubahan itu wajar, tetapi harus tercatat dan beralasan.
- Implementasi **tidak harus berupa kelas** (misalnya fungsi, komponen, *route/handler*, *stored procedure*, atau skrip). Namun, setiap kelas perancangan pada DPPL **wajib dapat ditelusuri** ke implementasinya, dan penelusuran ini dicatat di Bagian B.5.
- Seluruh use case pada SKPL **diprioritaskan** untuk diimplementasikan. Status tiap use case akan dilaporkan pada HIUPL (Tugas 10).
- Seluruh mahasiswa **wajib** mengikuti asistensi akbar.

## A.2 Platform, Bahasa, dan Teknologi

Kalian **bebas** memilih bahasa, framework, library, dan basis data, dengan syarat:

1. **Dapat dijalankan ulang** oleh asisten pada mesin biasa dengan mengikuti README. Versi bahasa/runtime dan seluruh dependensi harus tertulis jelas.
2. **Dependensi dikelola lewat file standar**, misalnya `package.json` + lockfile, `requirements.txt`/`pyproject.toml`, `pom.xml`/`build.gradle`, `composer.json`, `pubspec.yaml`, dan sejenisnya. Jangan meng-commit folder hasil instalasi (`node_modules/`, `venv/`, `build/`, dll.).
3. **Jika memakai layanan eksternal** (basis data cloud, API pihak ketiga, auth, dll.), sediakan cara menjalankan tanpa akun pribadi kalian, atau sediakan data/akun uji pada README. Basis data **sangat disarankan** dapat dijalankan lokal (SQLite, atau Docker Compose untuk PostgreSQL/MySQL/MongoDB).
4. **Arsitektur sesuai DPPL.** Pola arsitektur yang kalian pilih di APL/DPPL (MVC, layered, client-server, dll.) harus terlihat pada struktur kode.

Ketentuan tambahan per platform:

| Platform | Ketentuan |
| :--- | :--- |
| **Web** | Berjalan lokal lewat satu-dua perintah yang terdokumentasi. Boleh juga di-*deploy*; jika ya, cantumkan URL, tetapi **tetap wajib bisa dijalankan lokal** (URL deploy bisa mati). |
| **Desktop** | Berjalan dari source lewat perintah yang terdokumentasi. Build/installer opsional. |
| **Mobile** | Berjalan di emulator/simulator atau perangkat. Sertakan langkah menjalankan, dan **sangat disarankan** melampirkan APK/build di Release. |

## A.3 Keamanan Repository

Repo fork kelompok bersifat **public**, sehingga:

- **Dilarang** meng-commit password, API key, token, `.env` asli, sertifikat/private key, atau data pribadi. Hal ini dapat mengurangi nilai.
- Sediakan `.env.example` berisi nama variabel tanpa nilai rahasia, dan masukkan `.env` ke `.gitignore`.
- Jika sudah terlanjur ter-commit, **cabut/ganti** kredensial tersebut. Menghapus commit saja tidak cukup.
- Data uji/seed harus berupa data fiktif.

## A.4 Struktur Folder

Seluruh kode ditempatkan di `src/` pada repo fork. Jangan mengubah folder milestone lama.

```
src/                              # SELURUH kode implementasi
	README.md                     # dokumentasi utama aplikasi (lihat A.5)
	.env.example                  # jika memakai environment variable
	<struktur kode kalian>        # bebas, mengikuti pola arsitektur DPPL
	tests/                        # test case (jika ada)
docs/
	M9/
		KXX_GYY_Implementasi.md   # laporan ini (Bagian B)
		KXX_GYY_Form-Asistensi.md
```

Catatan:
- `README.md` aplikasi diletakkan di **`src/README.md`**, bukan di root repo.
- Jika kerangka kerja kalian mewajibkan struktur tertentu (misalnya Maven `src/main/java`, Flutter `lib/`, monorepo `frontend/` dan `backend/`), letakkan semuanya **di dalam `src/`**.
- Nama file dan folder pada `docs/M9/` mengikuti aturan penamaan milestone sebelumnya (`KXX_GYY_...`).

## A.5 Isi Minimal `src/README.md`

README harus cukup bagi orang yang belum pernah melihat proyek kalian untuk menjalankan aplikasi dari nol. Minimal berisi:

1. **Deskripsi singkat** aplikasi.
2. **Teknologi yang digunakan** beserta versi (bahasa, framework, basis data).
3. **Prasyarat dan instalasi** (software yang harus ada, perintah instalasi dependensi).
4. **Konfigurasi** (environment variable, setup basis data, migrasi/seed) dan langkah demi langkah menjalankannya.
5. **Cara menjalankan aplikasi** (dan cara menjalankan test, jika ada).
6. **Akun/data uji** untuk mencoba tiap peran pengguna (jika ada login).
7. **Daftar modul/fitur yang diimplementasi** beserta pembagian anggota.
8. **Daftar tabel/koleksi basis data** beserta atributnya (atau tautan ke skema/ERD).

## A.6 Best Practices

Kalian dianjurkan menerapkan praktik berikut. Bukti penerapannya dirangkum pada Bagian B.2.

### 1. Branching
Sesuai aturan umum di README repository, `main` fork kelompok dijaga agar tetap bisa menerima sync dari asisten. Pada tugas ini **sangat disarankan** memakai branch per fitur dengan format `<tipe>/<nama-fitur>` (contoh: `feat/login-page`, `fix/null-cart`), lalu digabungkan ke `main` melalui Pull Request. Skema Gitflow penuh (dengan `develop`) boleh dipakai, tetapi tidak diwajibkan.

### 2. Semantic Commit
Gunakan format `<tipe>(<scope>): <deskripsi>`, misalnya `feat(auth): tambah validasi email`.

| Tipe | Kegunaan |
| :--- | :--- |
| `feat` | Menambahkan fitur baru |
| `fix` | Memperbaiki bug |
| `docs` | Mengubah dokumentasi |
| `style` | Perubahan format/spasi, tanpa mengubah logika |
| `refactor` | Perubahan kode yang tidak menambah fitur atau memperbaiki bug |
| `test` | Menambah/memperbaiki pengujian |
| `chore` | Tugas rutin (build, dependensi, konfigurasi) |

### 3. Track Tasks
Gunakan **GitHub Issues** (dan opsional GitHub Projects) untuk membagi tugas dan melacak progres.
- Pecah fitur besar menjadi issue yang lebih kecil dan tetapkan penanggung jawabnya.
- Hubungkan PR dengan issue (`Closes #12`) dan tutup issue ketika selesai.

### 4. Pull Request dan Code Review
- Setiap PR berisi penjelasan deskriptif tentang apa yang dikerjakan, beserta bukti (tangkapan layar/rekaman/hasil test).
- Setiap PR di-*review* minimal **1 anggota lain**, dengan komentar konstruktif atau approval.

### 5. Pengujian dan Optimasi Performa
- Tulis pengujian untuk logika inti (unit test dan/atau pengujian alur utama). Cakupan penuh tidak diwajibkan, tetapi pengujian pada logika utama dinilai.
- Lakukan **profiling** pada setidaknya satu fitur yang berat (query besar, proses pengolahan data, render list panjang, dsb.), lalu catat temuan dan perbaikannya. Contoh alat:

| Platform | Contoh alat |
| :--- | :--- |
| Web (frontend) | Chrome DevTools (Performance/Network), Lighthouse |
| Web (backend) | Profiler bawaan bahasa, `EXPLAIN` pada query basis data, logging waktu respons |
| Python | `cProfile`, `PyInstrument` |
| Java | VisualVM, JProfiler |
| Mobile | Android Studio Profiler, Flutter DevTools, Xcode Instruments |

### 6. Penggunaan AI
Penggunaan AI **tetap harus dicatat** pada `docs/KXX_GYY_AI-Usage.md` sesuai ketentuan yang sudah berlaku.

## A.7 Pengumpulan

Pengumpulan dinilai dari **tag release**, bukan commit terakhir.

1. Pastikan seluruh pekerjaan sudah di-*commit* dan di-*push* ke `main` fork kelompok.
2. Buat release dengan tag **`v9.0`** (revisi berikutnya `v9.1`, `v9.2`, dst.) dengan target branch `main`.
3. Yang dinilai adalah **tag terakhir yang dibuat sebelum deadline**.

## A.8 Aturan Tanya Jawab

Agar semua kelompok mendapat jawaban yang sama, pertanyaan dibagi menjadi dua jalur:

| Jenis Pertanyaan | Jalur |
| :--- | :--- |
| **Ketentuan tugas**, misalnya teknologi yang diperbolehkan, struktur folder, format pengumpulan, dan penilaian | **Sheets QnA:** *[tautan sheets QnA]* |
| **Kendala teknis kelompok sendiri**, misalnya error, setup, dan penggunaan git | Grup kelompok bersama asisten masing-masing |

Ketentuan:
1. Pertanyaan tentang ketentuan tugas **wajib** diajukan melalui Sheets QnA. Periksa terlebih dahulu apakah pertanyaan serupa sudah dijawab.
2. Jika pertanyaan tentang ketentuan tugas tetap diajukan langsung kepada asisten kelompok, asisten **berhak menolak menjawab** dan meminta kelompok memasukkan pertanyaannya ke Sheets QnA.
3. Jika pertanyaan di Sheets QnA **belum dijawab dalam 24 jam**, kelompok boleh menghubungi asisten kelompok masing-masing. Cantumkan pertanyaan yang sudah diajukan di sheets tersebut.
4. Jawaban pada Sheets QnA berlaku untuk **seluruh kelompok** dan menjadi acuan jika terjadi perbedaan pemahaman.

---

# BAGIAN B: Laporan Implementasi

## B.1 Perubahan dari DPPL

Perbedaan antara perancangan (DPPL) dan implementasi akhir dicatat pada tabel berikut.

Tabel B.1. Perubahan dari DPPL

| No | Bagian DPPL | Rancangan Awal | Implementasi Akhir | Alasan |
|:---|:------------|:---------------|:-------------------|:-------|
| 1 | Tabel 2.3: `KatalogAnonimView, FormPenawaranView, FilterAlergenView, PenawaranController` | Satu `PenawaranController` melayani pencarian katalog dan pengelolaan penawaran | Dipisah menurut peran. `CatalogController` melayani pencarian Pembeli (kategori, lokasi, paginasi). `OfferFormController` melayani validasi dan penyimpanan form Penjual. `SellerController` melayani daftar dan penutupan penawaran. View menjadi `CatalogScreen, AllergenScreen, OfferFormScreen, OffersScreen,` dan `OfferDetailScreen` | Pembeli dan Penjual memakai state yang berbeda (kursor dan lokasi untuk katalog, validasi form untuk penawaran) |
| 2 | Kelas C03 `Penawaran`, atribut kuota (KF03) | Kuota paket disimpan sebagai atribut kuota pada kelas `Penawaran` | Kuota disimpan pada empat kolom: `quota_total, quota_available, quota_held,` dan `quota_sold,` dengan constraint `quota_total = quota_available + quota_held + quota_sold`. Checkout memindahkan satu paket dari tersedia ke ditahan, dan pembayaran berhasil memindahkannya dari ditahan ke terjual | Stok harus tertahan selama pembayaran berlangsung tanpa dihitung terjual, sehingga checkout bersamaan tidak menjual melebihi stok (KNF01) |
| 3 | Kelas C03 `Penawaran`, penguncian penawaran (R10) | Penawaran yang paketnya sudah dibayar terkunci dan tidak dapat diubah | Penawaran terkunci jika ada kuota yang ditahan, sudah terjual, atau pernah dibayar. Ubah dan tutup berjalan dalam satu transaksi dengan `SELECT ... FOR UPDATE`. Pada aplikasi, tombol "Ubah" dan "Tutup" nonaktif jika `SellerOffer.editable` bernilai salah | Mencegah perubahan harga atau penutupan penawaran ketika Pembeli sedang di tengah pembayaran |
| 4 | UC01 skenario alternatif 1–2 (harga di luar rentang, kuota tidak valid), KF03 | Diskon 50–70% dari harga normal, kuota tidak kosong atau nol, dan jendela pickup yang valid | Aturan yang sama dijalankan di tiga lapis: `OfferFormController.validate()` pada aplikasi, `validateOffer()` pada server, dan `CHECK` pada tabel `offers`. Harga berupa integer rupiah, dan rentang diskon dicek dengan perbandingan integer (`discount_price × 100` berada di antara `normal_price × 30` dan `normal_price × 50`). Ditambahkan kuota maksimal 500, mulai pickup paling lama dua jam dari sekarang, batas konsumsi tidak sebelum akhir pickup, dan konfirmasi kelayakan paket yang wajib dicentang | Validasi di aplikasi memberi umpan balik cepat, sedangkan server dan basis data menjadi sumber kebenaran. Aritmetika integer menghindari galat pembulatan desimal pada batas 50% dan 70% |
| 5 | Kelas C08 `QRPickup`, Tabel 4.1 dan Bab 5.8 | `QRPickup` menyimpan token QR dan OTP sebagai atribut, operasi `generateToken()` dan `validasiToken()` berada pada kelas tersebut. | Penerbitan serta validasi kredensial ditangani layanan server `PickupService`. Token disimpan dalam bentuk hash dan data kredensial dienkripsi, validasi mendukung QR satu kali pakai dan OTP enam digit dengan pembatasan percobaan. Aplikasi klien mengelola pemindaian melalui `ScanController`, sementara tiket tersimpan menggunakan cache. | Kredensial pickup dan aturan validasinya dipusatkan di server agar rahasia tidak menjadi sumber kebenaran di klien, serta untuk mendukung validasi satu kali pakai dan pembatasan percobaan OTP. |
| 6 | Kelas C09 `Pengaduan`, Tabel 4.1 dan Bab 5.9 | Pengaduan dirancang dengan atribut `fotoBukti` dan operasi `ajukanPengaduan()` serta `prosesPengaduan()`. | Bukti foto direpresentasikan sebagai ID media dan relasi lampiran, dengan batas maksimal dua foto. Proses pengajuan dan keputusan dibagi antara model/controller klien dan layanan server. Server juga mengelola status, respons, batas waktu tertentu, penahanan payout, dan refund simulasi. | Relasi media memungkinkan pengaturan kepemilikan dan akses bukti. Aturan status dan konsekuensi transaksi dijalankan di server agar konsisten dan dapat diproses secara transaksional. |
| 7 | AuthView, C01/C02 | Autentikasi merupakan dependensi use case | Ditambahkan registrasi/login, JWT, refresh berotasi, otorisasi peran, sesi perangkat dan logout | Melengkapi identitas untuk modul anggota lain; integrasi Nabil pada PR16 |
| 8 | UC03, C04–C07 | Checkout dan gateway QRIS/e-wallet pada DPPL | Source orders/payments/payouts serta checkout/payment screen dari sarirasa diintegrasikan; seluruh transaksi keuangan simulasi | UC03 belum tersedia di repo akademik; dimasukkan Nabil atas persetujuannya, tanpa atribusi commit pada Bintang |
| 9 | UC07, C10/C11 | Riwayat dan pemberian ulasan | HistoryScreen dan ReviewScreen terhubung ke repository; server membatasi ulasan pada pesanan selesai dan satu ulasan per order | Menyelesaikan bagian UC07 serta menjaga aturan transaksi |
| 10 | Startup dan dependensi bersama | Fondasi per fitur telah masuk bertahap | Entry point, Android/font/widget, migrasi/seed/runner dan repository yang belum ada dilengkapi; dua test dipindahkan ke integration dengan isi identik | Menghilangkan61target import yang tidak tersedia dan memungkinkan BE/app diuji bersama |

## B.2 Bukti Penerapan Best Practices

| Praktik | Bukti | Keterangan |
| --- | --- | --- |
| Branching | [Atan/fondasi](https://github.com/zakyamani/IF2150-RPL-K01-G06/pull/2), [UC04 backend](https://github.com/zakyamani/IF2150-RPL-K01-G06/pull/5), [UC04 Flutter](https://github.com/zakyamani/IF2150-RPL-K01-G06/pull/7), [Devina UC01/02](https://github.com/zakyamani/IF2150-RPL-K01-G06/pull/9), [Jaki UC05/06](https://github.com/zakyamani/IF2150-RPL-K01-G06/pull/14), [Branch UC05/UC06 (C08/C09)](https://github.com/zakyamani/IF2150-RPL-K01-G06/tree/feat/uc05-uc06-scanner-and-refund), [Nabil/integrasi](https://github.com/zakyamani/IF2150-RPL-K01-G06/pull/16) | Branch per fitur; source digabung melalui PR |
| Semantic commit | [Commit fondasi](https://github.com/zakyamani/IF2150-RPL-K01-G06/commit/b40a09631fcd0a057916833087250231d2d9a1e3), [Commit backend UC04](https://github.com/zakyamani/IF2150-RPL-K01-G06/commit/5e6cfbcda80bde760308b22b2dfb50619c8d45a5), [Commit Flutter UC04](https://github.com/zakyamani/IF2150-RPL-K01-G06/commit/78b32c5b8eabf04c0df56ccab2ea8c1d0120ab21), [Commit dokumentasi](https://github.com/zakyamani/IF2150-RPL-K01-G06/commit/c3d59d1520a54ca3ebccc0450d5ef937d1b29b0f), [Commit QRPickup C08](https://github.com/zakyamani/IF2150-RPL-K01-G06/commit/fb53f2f3d9c59ac7665252fb0ae490f260f9ca43), [Commit Pengaduan C09](https://github.com/zakyamani/IF2150-RPL-K01-G06/commit/80438caea524f0a7ce1b97e0acb5c06d94dcf1f0), [Riwayat branch integrasi](https://github.com/zakyamani/IF2150-RPL-K01-G06/commits/feat/uc07-auth-history-final-integration) | Commit auth backend, UC03, UC07, Android, test/tooling dan dokumen dipisah; timestamp aktual tanpa backdate |
| Issue tracking | [#3 fondasi](https://github.com/zakyamani/IF2150-RPL-K01-G06/issues/3), [#4 WS](https://github.com/zakyamani/IF2150-RPL-K01-G06/issues/4), [#6 Flutter](https://github.com/zakyamani/IF2150-RPL-K01-G06/issues/6), [#8 katalog](https://github.com/zakyamani/IF2150-RPL-K01-G06/issues/8), [#10 pengaduan](https://github.com/zakyamani/IF2150-RPL-K01-G06/issues/10), [#11 QR](https://github.com/zakyamani/IF2150-RPL-K01-G06/issues/11), [#15 integrasi](https://github.com/zakyamani/IF2150-RPL-K01-G06/issues/15) | Issue15 ditautkan pada PR16 |
| PR dan review | [Review UC04](https://github.com/zakyamani/IF2150-RPL-K01-G06/pull/7#issuecomment-6782988661), [temuan harga pickup](https://github.com/zakyamani/IF2150-RPL-K01-G06/pull/12#issuecomment-6793302950), [perbaikan](https://github.com/zakyamani/IF2150-RPL-K01-G06/pull/13), [PR pengaduan C09](https://github.com/zakyamani/IF2150-RPL-K01-G06/pull/14) | Review berupa komentar terlihat pada PR7 dan PR12–14. Bukti review PR2/5/9 belum tercatat di GitHub saat audit; PR16 menunggu review anggota lain |
| Pengujian | [backend tests](../../src/backend/test), [Flutter tests](../../src/android-app/test), [native tests](../../src/android-app/integration_test), [verifikasi](../../src/docs/verification.md) | 47 backend,63Flutter,6native serta signing guard lulus pada integrasi13November; konfigurasi CI ditambahkan |

### B.2.1 Profiling dan Optimasi

| Informasi | Keterangan |
| :--- | :--- |
| Fitur / proses yang diprofil | Endpoint dan proses pendukung notifikasi pesanan masuk pada UC04, serta query katalog yang digunakan sebagai pembanding beban query PostgreSQL. |
| Alat | `src/scripts/benchmark.sh`, PostgreSQL `EXPLAIN (ANALYZE, BUFFERS)`, dan pengukuran waktu respons HTTP. |
| Temuan (sebelum) | Profiling dilakukan pada database disposable yang berisi 1.000 user, 300 merchant, dan 5.000 penawaran fiktif. Dataset yang digunakan belum menunjukkan bottleneck signifikan pada proses yang diuji. |
| Perbaikan | Sistem menggunakan inbox dan outbox persisten, cursor untuk catch-up, PostgreSQL `LISTEN/NOTIFY`, WebSocket ticket sekali pakai, reconnect, serta pengiriman event secara idempotent. Query dan constraint transaksi tetap menggunakan struktur database yang telah disediakan. |
| Hasil (sesudah) | Dari 30 request validasi pickup HTTP lokal, p50 sebesar **4,47 ms**, p95 **5,67 ms**, maksimum **14,46 ms**, dan **0 request gagal**. p95 waktu proses server sebesar **4,39 ms**. Query katalog dengan `LIMIT 20` memiliki waktu **0,729 ms**, penggunaan top-N heapsort **27 kB**, dan shared-buffer hit **97**. |

Hasil profiling menunjukkan bahwa sistem masih memadai pada ukuran dataset uji tersebut sehingga belum diperlukan optimasi indeks tambahan untuk query yang diukur. Planner PostgreSQL memilih sequential scan karena sebagian besar data masih aktif dan ukuran dataset pilot relatif kecil. Profiling ini tidak mengukur beban serentak, kamera, UI perangkat, jaringan 3G, DNS, atau kapasitas deployment VPS.

Reproduksi integrasi13 November2026: `src/scripts/benchmark.sh` kini tersedia;30request pickup HTTP lokal,0gagal, p504.5ms, p958.11ms, maksimum14.66ms. Ini pengukuran pickup/query, bukan latensi WebSocket end-to-end. [Dataset dan EXPLAIN](../../src/docs/evidence/benchmark.json). Angka referensi di atas tetap dicatat sebagai baseline sebelumnya; variasi pengukuran tidak diklaim sebagai optimasi baru.

## B.3 Kendala dan Catatan Penting

Implementasi UC04 menggunakan inbox notifikasi persisten sebagai sumber data utama dan WebSocket sebagai jalur pengiriman real-time. Apabila koneksi WebSocket terputus, aplikasi melakukan reconnect dan mengambil event yang terlewat melalui mekanisme cursor catch-up sehingga penggunaan aplikasi tetap dapat dilanjutkan.

Pemantauan notifikasi pada Android bersifat opt-in dan membutuhkan izin notifikasi serta foreground service. Sistem operasi Android atau kebijakan baterai perangkat dapat menghentikan foreground service, sehingga aplikasi tidak menjamin notifikasi real-time selalu diterima ketika aplikasi tidak aktif dalam waktu lama. Inbox tetap dapat disinkronkan ketika pengguna membuka aplikasi kembali.

Pengujian dilakukan pada lingkungan lokal dan belum membuktikan performa pada jaringan 3G, dua perangkat fisik secara bersamaan, perangkat Android minimum API 29, kamera fisik, kebijakan baterai seluruh produsen perangkat, atau deployment VPS dengan beban produksi. Hasil profiling juga tidak dapat dianggap sebagai ukuran kapasitas produksi.

Transaksi pembayaran, refund, payout, dan integrasi gateway pada aplikasi merupakan simulasi. Data seed yang digunakan hanya berupa data fiktif. File `.env`, token, password, database, hasil build, dan kredensial tidak disertakan dalam repository.

## B.4 Kontribusi Anggota

Pembagian tugas mengikuti kesepakatan lima anggota. Persentase tidak dicantumkan sesuai instruksi Nabil. Rincian aktivitas yang tercatat dapat ditelusuri melalui B.2.

| NIM | Nama | Kode | Dokumentasi |
| --- | --- | --- | --- |
| 13525067 | Fathar Atandra Denaya (Atan) | Fondasi Express/Flutter dan UC04 pesanan real-time/WebSocket | README, B.2.1 profiling dan B.3 kendala |
| 13525070 | Devina Athalia Putri Kusumah | UC01 penawaran dan UC02 katalog anonim/filter alergen | B.1/B.5 C02–C03 serta tautan PR/commit B.2 |
| 13525139 | Josephine Bintang N.L | UC03 checkout, tiket dan gateway simulasi QRIS/e-wallet sesuai pembagian awal | B.1/B.5 C04–C07 dan bukti B.2 |
| 13525040 | Muhammad Zaky Amani (Jaki) | UC05 scan/OTP/cache offline dan UC06 pengaduan/refund | B.1/B.5 C08–C09 dan bukti B.2 |
| 13525004 | Nabil Rabbani | Auth, UC07 riwayat/ulasan dan integrasi akhir BE–Android | B.1/B.5 C10–C11, rekap B.4, pemeriksaan tautan/review B.2 dan kelengkapan integrasi |

Catatan integrasi: UC03 belum masuk melalui PR Bintang saat pengerjaan ini; Nabil menyetujui pengambilan modul tersebut dari source referensi dan akan mengabari Bintang. Commit integrasi UC03 serta pelengkapan README/pemetaan dibuat oleh pelaksana integrasi, tanpa mengatasnamakan anggota lain. Tabel ini mencatat pembagian tugas, bukan membuat bukti kontribusi individual yang belum ada.

## B.5 Traceability Kelas Perancangan ke Implementasi

Pemetaan dari **setiap kelas perancangan** pada DPPL (Tabel 4.1) ke wujud implementasinya. Bentuk implementasi bebas (kelas, fungsi, komponen, *route/handler*, *stored procedure*, skrip, dsb.), tetapi tiap kelas perancangan harus muncul pada tabel ini. Jika implementasi berupa kelas dengan nama yang sama, tetap dicantumkan.

Tabel B.5. Traceability Kelas Perancangan ke Implementasi

| ID Kelas | Nama Kelas Perancangan | Bentuk Implementasi | Lokasi (File dan Nama) | Keterangan |
| :--- | :--- | :--- | :--- | :--- |
| C01 | Penjual | Model/tabel, profil dan otorisasi peran | `src/backend/src/modules/merchants/{service,repository,schema}.ts`, tabel `users`/`merchant_profiles`; `src/android-app/lib/features/seller/profile_screen.dart` | Dependensi profil gerai dilengkapi saat integrasi; C01 belum tercakup pada pembagian dokumentasi awal |
| C02 | Pembeli | Baris tabel `users`, endpoint preferensi alergen, model Dart, dan layar filter alergen | **Tabel:** `src/backend/migrations/001_initial.sql` (`users`, kolom `role` dan `allergen_filters`).<br>**Server:** `src/backend/src/modules/auth/routes.ts` (`PATCH /api/v1/auth/allergens`), `schema.ts` (`allergenSchema`), `service.ts` (`AuthService.allergens`), `repository.ts` (`UserRecord`, `userView`); daftar alergen pada `src/backend/src/core/labels.ts` (`allergens`); penerapan filter pada `src/backend/src/modules/catalog/repository.ts` (`CatalogRepository.read`).<br>**Flutter:** `src/android-app/lib/core/models/user.dart` (`User`, `Role`, `SessionBundle.withUser`), `src/android-app/lib/features/buyer/allergen_screen.dart` (`AllergenScreen`), `src/android-app/lib/core/storage/session_store.dart` (`SessionStore`). | Atribut preferensi alergen menjadi `users.allergen_filters` (array). Operasi memperbarui preferensi dijalankan tombol "Simpan filter" pada `AllergenScreen`, yang memanggil `PATCH /api/v1/auth/allergens`; server menyimpan lalu mengembalikan data pengguna terbaru, dan aplikasi menyimpannya ke sesi lokal lewat `SessionBundle.withUser`. Filter diterapkan di server pada kueri katalog (`NOT(o.allergens && u.allergen_filters)`), sehingga paket yang mengandung alergen terpilih tidak dikirim ke perangkat. Pilihan terbatas pada delapan alergen unik: gluten, telur, susu, kacang, kedelai, ikan, kerang, wijen. Registrasi, login, dan token (JWT) Pembeli berada pada modul `auth` yang dikerjakan anggota lain. |
| C03 | Penawaran | Tabel basis data, modul backend (route, service, repository, skema validasi), model Dart, controller, dan layar Flutter | **Tabel:** `src/backend/migrations/001_initial.sql` (`offers`).<br>**Penjual (UC01), server:** `src/backend/src/modules/offers/routes.ts` (`offerRoutes`), `service.ts` (`OfferService`), `repository.ts` (`OfferRepository`, `OfferRecord`), `schema.ts` (`offerSchema`, `validateOffer`).<br>**Pembeli (UC02), server:** `src/backend/src/modules/catalog/routes.ts` (`catalogRoutes`, `catalogQuerySchema`), `service.ts` (`CatalogService`), `repository.ts` (`CatalogRepository`).<br>**Model Flutter:** `src/android-app/lib/core/models/offer.dart` (`Offer`, `SellerOffer`).<br>**Layar Penjual:** `src/android-app/lib/features/seller/offer_form_screen.dart` (`OfferFormScreen`), `offer_form_controller.dart` (`OfferFormController`), `offers_screen.dart` (`OffersScreen`); daftar dan tutup lewat `seller_controller.dart` (`SellerController`) dan `seller_repository.dart` (`SellerRepository`).<br>**Layar Pembeli:** `src/android-app/lib/features/buyer/catalog_screen.dart` (`CatalogScreen`), `catalog_controller.dart` (`CatalogController`), `offer_detail_screen.dart` (`OfferDetailScreen`). | Atribut menjadi kolom `offers`: kategori `category`, alergen `allergens` (array), kuota `quota_total/available/held/sold`, harga `normal_price` dan `discount_price` (integer rupiah), jendela pickup `pickup_start` dan `pickup_end`, batas konsumsi `safe_eat_until`, serta status `active` atau `closed`. Operasi buat, ubah, dan tutup dijalankan `OfferService.create`, `update`, dan `close` (khusus peran Penjual dengan profil gerai lengkap, dan tercatat di `audit_logs`). Katalog hanya memuat penawaran aktif yang belum lewat jam pickup dan masih bersisa kuota. Respons katalog dibatasi pada field penawaran saja tanpa identitas, alamat, foto, atau koordinat gerai. Jarak dihitung server dengan rumus Haversine dan dibulatkan 0,1 km jika koordinat Pembeli dikirim. |
| C04 | Pesanan | Tabel, service/repository, model dan controller | `src/backend/src/modules/orders/{service,repository,schema,routes}.ts`; `src/android-app/lib/core/models/order.dart`, `features/orders/order_controller.dart` | Snapshot order/reservasi/status/audit; UC03 diintegrasikan dari source referensi oleh Nabil |
| C05 | MetodePembayaran | Intent/event dan adapter demo | `src/backend/src/modules/payments/{service,repository,demo-gateway}.ts`; `src/android-app/lib/core/models/payment.dart`, `features/orders/payment_screen.dart` | Invoice, retry, callback terverifikasi, sukses/gagal/expiry; simulasi |
| C06 | QRIS | Adapter QR invoice dan view | `src/backend/src/modules/payments/demo-gateway.ts`; `src/android-app/lib/features/orders/payment_screen.dart` | QR pembayaran simulasi, tidak dipakai membayar ke bank |
| C07 | EWallet | Pilihan metode dan adapter demo | `src/backend/src/modules/payments/demo-gateway.ts`; `src/android-app/lib/features/orders/checkout_screen.dart` | Tidak mengirim tagihan e-wallet nyata; pemisahan gateway dipertahankan melalui adapter |
| C08 | `QRPickup` | Layanan penerbitan dan validasi kredensial di backend; controller pemindaian dan cache tiket di klien | Backend: `src/backend/src/modules/pickup/service.ts`, `src/backend/src/modules/pickup/routes.ts`. Klien: `src/android-app/lib/features/seller/scan_controller.dart`, `src/android-app/lib/features/orders/tickets_screen.dart` | Backend menerbitkan QR dan OTP, memvalidasi status pesanan dan jadwal pickup, serta membatasi percobaan OTP agar satu kali validasi dan aman. QR/token bersifat sekali pakai; tiket klien disimpan agar pengguna masih bisa mengakses data saat offline, namun validasi final tetap di server. Repository pickup, layar OTP dan dependensi dilengkapi saat integrasi Nabil. |
| C09 | `Pengaduan` | Model Dart, controller/repository, dan layar klien. layanan, route, serta skema validasi di backend | Klien: `src/android-app/lib/core/models/complaint.dart`, `src/android-app/lib/features/orders/complaint_controller.dart`, `src/android-app/lib/features/orders/complaint_form_screen.dart`, `src/android-app/lib/features/orders/complaint_detail_screen.dart`. Backend: `src/backend/src/modules/complaints/service.ts`, `src/backend/src/modules/complaints/routes.ts`, `src/backend/src/modules/complaints/schema.ts` | Pengajuan pengaduan menyimpan alasan, deskripsi, dan ID bukti media. keputusan penjual akan mengubah status pengaduan serta memicu refund simulasi atau penolakan. Server memastikan kelayakan pengaduan, kepemilikan bukti, dan konsistensi status transaksi. Dependensi refund/worker dihubungkan saat integrasi Nabil. |
| C10 | Ulasan | Model, repository/service dan form | `src/backend/src/modules/reviews/{service,repository,schema,routes}.ts`; `src/android-app/lib/core/models/review.dart`, `features/orders/{review_controller,review_screen,merchant_reviews_screen}.dart` | Bagian Nabil; completed-only, satu ulasan per order dan akses gerai sesuai hak |
| C11 | RiwayatTransaksi | Query order/history dan layar riwayat | `src/backend/src/modules/orders/repository.ts`; `src/android-app/lib/features/orders/history_screen.dart`, `order_repository.dart`, `src/backend/src/modules/metrics/` | Bagian Nabil; filter/paginasi/status, metrik completed dan audit |

Catatan:
- Satu kelas perancangan boleh diwujudkan oleh beberapa file/unit, dan satu file/unit boleh mewujudkan beberapa kelas perancangan. Tuliskan semuanya.
- Kelas perancangan yang **tidak diimplementasikan** atau **digabung/dipecah** tetap dicantumkan, dan alasannya dicatat di Bagian B.1.
