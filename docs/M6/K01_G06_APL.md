<h1>
IF2150 REKAYASA PERANGKAT LUNAK
<br>
TUGAS 6
<br>
ARSITEKTUR PERANGKAT LUNAK (APL)
</h1>
<br>

## *SisaRasa*

### Untuk: *Amanda Aurellia Salsabilla*

Dipersiapkan oleh:

| Informasi | Keterangan |
| --- | --- |
| Kelas | K1 |
| Kelompok | 6 |

| NIM | Nama |
|---|---|
| 13525067 | Fathar Atandra Denaya |
| 13525040 | Muhammad Zaky Amani |
| 13525139 | Josephine Bintang N.L |
| 13525070 | Devina Athalia Putri Kusumah |
| 13525004 | Nabil Rabbani |

---

<br>
<br>

# BAB 1: Style/Pattern Arsitektur Acuan

## 1.1 Architectural Pattern yang Dipilih dan Peran Bagiannya
Dalam perancangan arsitektur perangkat lunak SisaRasa, *architectural pattern* utama yang dipilih adallah **Client-Server Architecture** yang dipadukan dengan **Layered Architecture (MVC)** di masing-masing sisi. Pola ini memisahkan secara tegas antarmuka pengguna pada perangkat seluler (*Client*) dengan pusat pengolahan data dan logika bisnis pada infrastruktur belakang (*Server*) melalui protokol komunikasi REST API (HTTP/HTTPS) dan WebSocket.

<p align="center">
  <img alt="Penerapan Arsitektur Client-Server dan Layered pada SisaRasa" src="./assets/diagram/arsitektur-acuan-sisarasa.png" width="85%">
</p>
<p align="center">
  <i>Gambar 1.1. Penerapan Arsitektur Client-Server pada Aplikasi SisaRasa</i>
</p>

Pembagian peran dan tanggung jawab tiap komponen dalam arsitektur ini meliputi:

1. **Client Side (Android Flutter Application):**
   * **View (UI Layer):** Bertanggung jawab menyajikan antarmuka bagi Pembeli (katalog anonim, *checkout*, filter alergen, tampilan QR *pickup*) dan Penjual (*dashboard* pesanan, formulir penawaran, pemindai QR kamera).
   * **State Controller / Client Logic:** Mengelola keadaan lokal (*state*), menangani *user events*, menyimpan token autentikasi/QR secara *cached*, serta mempertahankan koneksi *WebSocket Background Service* untuk menerima notifikasi pesanan masuk.

2. **Server Side (Node.js Express Backend):**
   * **API Controller Layer:** Menangani *endpoint* REST API, memvalidasi *payload* JSON masukan dari klien, serta mengelola lalu lintas koneksi WebSocket (`/ws`).
   * **Business Service Layer:** Mengeksekusi aturan bisnis inti (*business rules*), seperti validasi jendela terbit penawaran (maksimal 2 jam), perhitungan jarak relatif berbasis geolokasi di *server*, pembuatan token QR dinamis & *fallback* OTP 6-digit, serta penanganan sengketa/pembatalan.
   * **Data Access / Repository Layer:** Berinteraksi langsung dengan basis data terpusat (PostgreSQL) dan penyimpanan berkas lokal server (`uploads/`) untuk operasi CRUD data entitas.

3. **Modul Eksternal / Subsistem Terintegrasi:**
   * **Dummy Payment Gateway Module:** Modul simulasi transaksi pembayaran digital (QRIS & *E-Wallet*) yang berjalan di dalam *server* untuk mengelola penahanan kuota, waktu kedaluwarsa tagihan, dan pengiriman *webhook callback*.

---

## 1.2 Alasan Pemilihan Pattern
Pemilihan pola *Client-Server Architecture* terintegrasi *Layered MVC* didasarkan pada karakteristik fungsional (KF) dan non-fungsional (KNF) pada dokumen SKPL SisaRasa:

1. **Pemisahan Peran Pengguna Lintas Perangkat (Multi-User Role & Centralized State):**
   SisaRasa melibatkan dua aktor manusia (Pembeli `A01` dan Penjual `A02`) yang berada pada lokasi fisik terpisah. Pola *Client-Server* memungkinkan seluruh keadaan transaksi, kuota paket surplus, dan penandatanganan status pesanan tersinkronisasi secara terpusat di server.
2. **Kebutuhan Komunikasi Real-Time (KF05 & KNF04):**
   Penjual membutuhkan notifikasi instan saat ada pembayaran lunas dari Pembeli tanpa perlu melakukan *refresh* manual. Integrasi *Client-Server* via saluran *WebSocket persistent* yang dijaga *foreground service* Android memastikan pesan notfikasi terkirim tepat waktu.
3. **Keamanan dan Kerahasiaan Data (KF06, KF08, & KNF05):**
   Sistem mewajibkan katalog disajikan secara anonim dan perhitungan jarak relatif dilakukan di server tanpa mengekspos koordinat GPS presisi *merchant* sebelum pembayaran terverifikasi. Pola *Client-Server* menjamin logika peka privasi ini dieksekusi secara aman di sisi server.
4. **Portabilitas & Kemudahan Pemeliharaan (KNF04):**
   Pengorganisasian kode secara *Layered MVC* memudahkan pengembang untuk memperbarui antarmuka aplikasi Android  atau mengubah modul internal (seperti *Payment Gateway dummy*) tanpa merusak struktur basis data inti.

---

## 1.3 Lingkungan Operasi Perangkat Lunak
Lingkungan operasi yang dibutuhkan agar aplikasi SisaRasa dapat berjalan dengan optimal ditunjukkan pada Tabel 1.1 berikut:

Tabel 1.1. Lingkungan Operasi Perangkat Lunak

| Komponen | Spesifikasi |
| :--- | :--- |
| **Server aplikasi** | Node.js 18 atau lebih baru dengan Express 4. API mendengarkan pada port 3000, termasuk jalur WebSocket `/ws` untuk pemberitahuan pesanan baru. |
| **DBMS** | PostgreSQL 15. Pada pengembangan, basis data dijalankan dengan Docker dan dipetakan ke port 5433. |
| **Penyimpanan berkas** | Foto gerai disimpan di direktori server (`uploads/`). Berkas hanya dapat diunduh lewat API setelah pengguna login dan identitas toko memang boleh dibuka. |
| **Payment Gateway** | Modul dummy di dalam server yang sama. Mendukung simulasi QRIS dan e-wallet, penahanan kuota, kedaluwarsa tagihan, serta konfirmasi pembayaran. Bukan QRIS bank sungguhan. |
| **Client** | Aplikasi Android yang dibangun dengan Flutter. Dipasang sebagai berkas APK. Satu aplikasi memuat peran Pembeli dan Penjual. |
| **OS klien** | Android. Membutuhkan izin internet, lokasi (opsional, untuk urutan jarak), kamera (pemindaian QR Penjual), galeri (foto toko), dan notifikasi. |
| **OS server** | Linux pada VPS untuk operasi. Pengembangan dapat dilakukan di Linux, Windows, atau macOS selama Node.js, Docker, dan Flutter tersedia. |
| **Jaringan** | HP dan server harus saling terjangkau. Contohnya Wi-Fi yang sama saat server masih di laptop, atau IP/domain VPS saat server dipindah. HTTPS dapat dipakai. HTTP tetap didukung untuk demo. |
| **Pemberitahuan Penjual** | Koneksi WebSocket yang dijaga oleh layanan latar depan Android. Tidak memakai Firebase. Selama layanan itu hidup, pesanan baru memunculkan notifikasi meski aplikasi tidak sedang dibuka. |

### Kaitan Teknologi dengan Style/Pattern Arsitektur
Spesifikasi teknologi pada Tabel 1.1 mendukung penuh penerapan arsitektur *Client-Server* dan *Layered MVC*:
* **Flutter (Dart) pada Sisi Klien:** Menyediakan arsitektur berbasis komponen UI (*Widget-View*) dan *State Management* yang terpisah dari logika pemanggilan API, mewujudkan prinsip *Presentation Layer*.
* **Node.js Express 4 pada Sisi Server:** Mengadopsi struktur *routing/controller* yang menangani permintaan HTTP REST API serta mengarahkan pemrosesan logika bisnis ke modul *services* dan *repository* basis data (PostgreSQL 15 via ORM/Driver).
* **Modul Native Android & WebSocket:** Koneksi WebSocket `/ws` dan *Foreground Service* Android menghubungkan *Client* dan *Server* secara independen, memastikan peristiwa *real-time* dapat diterima tanpa mengganggu pemrosesan data utama.

---

# BAB 2: Identifikasi Komponen / Modul / Subsistem

Pada bagian ini, lakukan identifikasi terhadap komponen, modul, atau subsistem yang menyusun aplikasi berdasarkan *pattern* arsitektur yang telah ditetapkan sebelumnya. Setiap komponen memiliki tanggung jawab tertentu dalam mendukung fungsionalitas sistem.

Setiap komponen memiliki tanggung jawab tertentu dalam mendukung fungsionalitas sistem secara keseluruhan. Komponen dapat dikelompokkan berdasarkan lapisan arsitektur (misalnya *Model*, *View*, dan *Controller* pada pattern MVC), atau berdasarkan fungsi atau peran komponen di dalam sistem (misalnya modul autentikasi, manajemen data, dan integrasi eksternal).

Tabel 2.1. Identifikasi Komponen Subsistem Modul Pembeli

| Nama Komponen/Modul/Subsistem | Jenis                 | Penjelasan                                                                                                           |
| :---------------------------- | :-------------------- | :------------------------------------------------------------------------------------------------------------------- |
| *Modul Pembeli*                 | *Subsistem*                | *Mewadahi seluruh view, controller, dan lokal yang digunakan peran Pembeli di aplikasi.*     |
| *KatalogAnonimView*               | *View*                | *Menampilkan daftar penawaran paket surplus secara anonim beserta kontrol filter alergen dan pengurutan jarak (meneruskan aksi pencarian/filter ke PenawaranController).*                                                       |
| *DetailPenawaranView*                | *View*                | *Menampilkan rincian satu penawaran (kategori, info alergen, harga normal/diskon, jendela pickup) sebelum Pembeli melanjutkan ke checkout.*                                      |
| *CheckoutView*          | *View*                | *Menampilkan ringkasan pesanan dan pilihan metode pembayaran (QRIS/E-Wallet), meneruskan konfirmasi ke CheckoutController.*                                         |
| *KatalogController*           | *View*          | *Memproses permintaan daftar produk dan penambahan produk ke keranjang.*                                             |
| *TiketPickupView*         | *View*          | *Menampilkan kode QR pickup beserta nama dan alamat merchant yang baru terbuka setelah pembayaran terverifikasi.*                                          |
| *RiwayatPesananPembeliView*        | *View*          | *Memproses pemilihan metode pembayaran dan meneruskan permintaan otorisasi ke PaymentGatewayAdapter.*                |
| *PesananController*           | *Controller*          | *Menampilkan daftar pesanan milik Pembeli beserta status (menunggu bayar, menunggu pickup, selesai, gagal diambil) dan akses ke form ulasan.*                                                              |
| *UlasanFormView*                      | *View*               | *Menampilkan form rating bintang dan komentar untuk pesanan berstatus "Selesai".*                        |
| *PenawaranController*                   | *Controller*               | *Memproses permintaan daftar penawaran dari KatalogAnonimView, meneruskan parameter filter alergen/lokasi ke HttpApiClient.*       |
| *CheckoutController*                     | *Controller*               | *Memproses pemilihan metode pembayaran dan mengirimkan permintaan checkout/otorisasi pembayaran ke server melalui HttpApiClient.*          |
| *PesananPembeliController*                   | *Controller*               | *Mengambil status dan detail pesanan Pembeli (termasuk token QR pickup) secara berkala dari server.*                                |
| *UlasanController*                    | *Controller*           | *Memvalidasi input ulasan melalui ValidasiFormInput, lalu mengirimkan data rating/komentar ke server.*                                                      |
| *Penawaran*       | *Model* | *Representasi lokal data satu paket penawaran (kategori, harga, kuota, jendela pickup) yang diterima dari server, dipakai oleh KatalogAnonimView dan DetailPenawaranView.* |
| *Pesanan*                    | *Model*    | *Representasi lokal data satu pesanan beserta status alurnya, dipakai bersama oleh Modul Pembeli dan Modul Penjual.*   |
| *QRPickup*       | *Model* | *Representasi lokal token QR pickup dan masa berlakunya, ditampilkan oleh TiketPickupView.* |
| *Ulasan*                    | *Model*    | *Representasi lokal rating dan komentar yang akan dikirim lewat UlasanController.*   |

Tabel 2.2. Identifikasi Komponen Subsistem Modul Penjual

| Nama Komponen/Modul/Subsistem | Jenis                 | Penjelasan                                                                                                           |
| :---------------------------- | :-------------------- | :------------------------------------------------------------------------------------------------------------------- |
| *Modul Penjual*                 | *Subsistem*                | *Mewadahi seluruh view, controller, dan lokal yang digunakan peran Penjual di aplikasi.*     |
| *DashboardPenawaranView*               | *View*                | *Menampilkan daftar penawaran aktif milik Penjual beserta sisa kuota, dan aksi edit/tutup penawaran.*                                                       |
| *FormPenawaranView*                | *View*                | *Formulir untuk membuat atau mengubah penawaran (kategori, nilai normal, harga diskon, kuota, jendela pickup), dengan validasi lokal rentang diskon 50–70%.*                                      |
| *DaftarPesananMasukView*          | *View*                | *Menampilkan pesanan yang sudah dibayar dan perlu disiapkan, lengkap jadwal pickup-nya.*                                         |
| *PindaiQRView*           | *View*          | *Antarmuka/Interface kamera untuk memindai kode QR pickup Pembeli sebagai bukti serah-terima.*                                             |
| *RiwayatTransaksiPenjualView*         | *View*          | *Menampilkan riwayat transaksi milik Penjual.*                                          |
| *PenawaranManajemenController*        | *Controller*          | *Memproses pembuatan, perubahan, dan penutupan penawaran dari FormPenawaranView/DashboardPenawaranView, memanggil ValidasiFormInput sebelum mengirim ke server.*                |
| *PesananMasukController*           | *Controller*          | *Mengambil daftar pesanan masuk dari server dan memperbarui tampilan DaftarPesananMasukView saat ada notifikasi baru dari WebSocketListener.*                                                              |
| *PemindaianController*                      | *Controller*               | *Menerima hasil pemindaian dari KameraScannerAdapter, lalu mengirimkan token QR ke server untuk divalidasi*                        |
| *PengaduanController*                   | *Controller*               | *Memproses konfirmasi/penolakan Penjual atas pengajuan sengketa/refund dari Pembeli.*       |


Ketentuan pengisian Tabel 2.1:
1. Kolom **Jenis** mengikuti pengelompokan pada *style/pattern* di BAB 1. Untuk MVC, jenisnya adalah *Model*, *View*, dan *Controller*. Jenis lain boleh ditambahkan, misalnya *Pendukung* untuk komponen bantu yang dipakai bersama, atau *Integrasi Eksternal* untuk penghubung ke sistem di luar P/L yang disebutkan pada subbab 2.2 dokumen SKPL. Kolom ini juga boleh diisi dengan *Subsistem*, *Modul*, atau *Komponen* apabila komponen dikelompokkan berdasarkan fungsinya. Tuliskan subsistem terlebih dahulu, lalu komponen penyusunnya di baris-baris berikutnya.
2. Komponen **tidak sama dengan** kelas. Satu komponen boleh mewadahi beberapa kelas dari diagram kelas pada dokumen SKPL. Pastikan seluruh kelas tercakup oleh setidaknya satu komponen.
3. Pastikan seluruh use case pada dokumen SKPL dapat dijalankan oleh komponen-komponen yang didaftarkan di tabel ini. Jangan menambahkan komponen untuk fitur yang tidak ada di SKPL.

<sub><b><i>Catatan</i></b>: <i>Nama komponen pada Tabel 2.1 harus dipakai sama persis pada gambar di BAB 1 dan setiap view di BAB 3. Jika saat membuat view ternyata dibutuhkan komponen baru, tambahkan komponen tersebut ke Tabel 2.1 terlebih dahulu.</i></sub>

---

# BAB 3: Model Arsitektur Perangkat Lunak

*Architectural View* adalah bagaimana cara kita melihat/mendeskripsikan arsitektur sebuah sistem dari sudut pandang tertentu. Dalam perancangan arsitektur aplikasi, dibutuhkan *Architectural View* yang dapat mempermudah pemahaman dari proses aplikasi yang akan dikembangkan. Tujuan dari *Architectural View* adalah menjadi bahan komunikasi, pemisahan masalah, mempermudah analisis, dan pemandu saat eksekusi pengembangan sistem tersebut.

Buatlah model arsitektur dari aplikasi yang akan dirancang dalam bentuk *view*. Model arsitektur ini berfungsi untuk memperlihatkan bagaimana setiap komponen, modul, dan subsistem saling berinteraksi serta berkolaborasi dalam menjalankan fungsi utama sistem secara keseluruhan. Anda dapat membuat satu atau lebih *view* tergantung kebutuhan dalam bentuk gambar. Pilihlah notasi yang sesuai. Contoh *view* yang dapat digunakan antara lain ***Logical View***, ***Process View***, ***Development View***, serta ***Physical View***.

Ketentuan pengisian BAB 3:
1. Setiap view menggambarkan **keseluruhan sistem**, bukan satu use case atau satu fitur saja.
2. Buat **minimal satu view**. Setiap view dituliskan dalam subbab tersendiri (3.1, 3.2, dan seterusnya). Tidak perlu membuat keempat view, pilih yang paling membantu menjelaskan P/L Anda, lalu jelaskan alasan pemilihannya.
3. Setiap view harus **konsisten dengan BAB 2**. Seluruh komponen pada Tabel 2.1 harus muncul dengan nama yang sama, dan tidak boleh ada komponen pada view yang tidak terdaftar di Tabel 2.1.
4. Setiap view harus **mencerminkan style/pattern pada BAB 1**. Misalnya, jika memilih MVC, pembagian *Model*, *View*, dan *Controller* harus terlihat jelas pada diagram.
5. Jika membuat lebih dari satu view, setiap view harus menggambarkan sistem yang sama dari sudut pandang berbeda. View tambahan melengkapi view pertama, bukan mengulanginya.
6. Beri label pada setiap garis atau panah yang menghubungkan komponen agar hubungan antarkomponen dapat dipahami tanpa penjelasan tambahan.
7. Jika membuat *Physical View*, gambarkan lingkungan operasi pada Tabel 1.1.

## 3.1 Logical View

### 3.1.1 Deksripsi Logical View
Logical View mendeskripsikan abstraksi utama sistem dan hubungannya untuk mendukung kebutuhan fungsional perangkat lunak. Fokus utama dari view ini adalah memetakan layanan dan fitur yang disediakan sistem agar pembagian fungsi dan hubungan layanan yang memenuhi kebutuhan bisnis SisaRasa dapat lebih mudah dipahami.

Logical View ini menstrukturkan komponen-komponen sistem ke dalam pola Model-View-Controller (MVC). Pola MVC secara tegas memisahkan pengelolaan data dan perilaku domain pada lapisan Model, penyajian informasi pada lapisan View, serta koordinasi interaksi pengguna pada lapisan Controller. Pembagian ini menjamin modularitas tinggi antara Modul Pembeli dan Modul Penjual, meskipun keduanya berinteraksi dengan entitas domain sentral yang sama.

<p align="center">
<img alt="Contoh Logical View pada P/L E-Commerce" src="./assets/diagram/diagram-logical-view.jpg" width="100%">
</p>
<p align="center">
<i>Gambar 2. Diagram Logical View SisaRasa</i>
</p>

### 3.1.2 Relasi dan Interaksi Antarkomponen
Diagram keseluruhan sistem di atas mendeskripsikan abstraksi relasi fungsional. Hubungan antarkomponen diatur berdasarkan prinsip arsitektur MVC:
1. View --> Controller (User Events): Komponen View bertanggung jawab menyajikan antarmuka dan menangkap interaksi pengguna (seperti menekan tombol checkout atau menyimpan penawaran). Interaksi ini diteruskan ke Controller dalam bentuk User events. 
2. Controller --> Model (Update Request): Controller memetakan aksi pengguna menjadi pembaruan pada entitas data. Controller mengirimkan Update request ke komponen Model untuk mengubah status, memotong kuota, atau memvalidasi logika bisnis.
3. Model --> Model (Agregasi & Komposisi): Entitas data pada Model saling berelasi. Pesanan memiliki relasi agregasi dengan Penawaran (karena penawaran tetap ada meskipun pesanan dibatalkan). Sebaliknya, Pesanan memiliki relasi komposisi dengan QRPickup dan Ulasan (karena QR dan Ulasan tidak dapat berdiri sendiri tanpa adanya pesanan).
4. Controller --> Eksternal: CheckoutController mendelegasikan proses penahanan kuota dan pemrosesan dana ke sistem eksternal Payment Gateway Dummy melalui koneksi terpisah.

### 3.1.3 Audit Konsistensi Arsitektur Logis
Audit ini memastikan bahwa rancangan *Logical View* telah mencakup seluruh komponen, kelas, dan subsistem yang diidentifikasi pada Bab 2, serta mendukung seluruh *use case* yang ditetapkan pada SKPL.

| Aspek Arsitektur | Kriteria Acuan (Bab 1, Bab 2 & SKPL) | Implementasi pada Logical View | Status Evaluasi |
| :--- | :--- | :--- | :---: |
| **Kepatuhan Pola (Pattern)** | Memisahkan data, penyajian, dan koordinasi interaksi pada pola MVC. | Diagram dikelompokkan secara hierarkis menjadi tiga lapisan utama: *View*, *Controller*, dan *Model*. | **Valid** |
| **Kelengkapan Subsistem Pembeli** | Mencakup seluruh kelas *View* dan *Controller* Modul Pembeli (Tabel 2.1). | `KatalogAnonimView`, `CheckoutView`, `KatalogController`, dll., seluruhnya terpetakan di zona Pembeli. | **Valid** |
| **Kelengkapan Subsistem Penjual** | Mencakup seluruh kelas *View* dan *Controller* Modul Penjual (Tabel 2.2). | `FormPenawaranView`, `PindaiQRView`, `PesananMasukController`, dll., terpetakan di zona Penjual. | **Valid** |
| **Sentralisasi Domain (Model)** | Berisi entitas data: `Penawaran`, `Pesanan`, `QRPickup`, `Ulasan` (Bab 2). | Dikelompokkan pada *Domain Layer* yang diakses oleh *Controller* dari kedua aktor (Pembeli & Penjual). | **Valid** |
| **Dukungan Kebutuhan Eksternal** | Mendukung integrasi dengan *Payment Gateway dummy* sesuai alur bisnis. | `CheckoutController` memiliki relasi *Permintaan Otorisasi* terhadap modul `Payment Gateway Dummy`. | **Valid** |

## 3.2 Deployment View (Physical View) & Audit Konsistensi

### 3.2.1 Deskripsi Deployment View
Deployment View (Physical View) menggambarkan pemetaan fisik antara modul dan artefak perangkat lunak SisaRasa ke dalam simpul komputasi (*nodes*), lingkungan eksekusi (*runtime*), serta media komunikasi fisik yang menghubungkannya. Seluruh pemetaan pada *view* ini diturunkan secara langsung dari spesifikasi lingkungan operasi pada Tabel 1.1 dokumen ini (serta subbab 2.5 dokumen SKPL).

<p align="center">
  <img alt="Deployment Diagram Sistem SisaRasa" src="./assets/diagram/deployment-diagram.webp" width="95%">
</p>
<p align="center">
  <i>Gambar 3. Deployment Diagram (Physical View) Sistem SisaRasa</i>
</p>

Sistem SisaRasa terdistribusi ke dalam 3 simpul fisik (*tier*) utama:
1. **Client Node (Smartphone Android Pengguna):**
   * **Simpul Fisik**: Perangkat bergerak (*smartphone*) pengguna yang menjalankan sistem operasi Android (minimal Android 10 / API level 29 ke atas).
   * **Artefak Perangkat Lunak**: Berkas biner tunggal `SisaRasaApp.apk` yang dibangun menggunakan framework Flutter. Berkas aplikasi ini memuat peran Pembeli dan Penjual sekaligus yang dapat diakses sesuai kredensial saat autentikasi.
   * **Subsistem & Modul Internal**:
     - *Modul Pembeli*: Penelusuran katalog makanan surplus secara anonim, pengaturan preferensi filter alergen, formulir checkout, penampil tiket penjemputan (kode QR dinamis), serta antarmuka pemberian ulasan/rating.
     - *Modul Penjual*: Manajemen formulir penawaran (validasi diskon 50–70% dan kelayakan konsumsi), pemantau jadwal penjemputan, serta antarmuka pemindai kode QR penjemputan.
     - *Layanan Native & Jaringan*: Pustaka kamera `mobile_scanner` untuk validasi serah-terima fisik, plugin geolokasi perangkat (`geolocator`) untuk penghitungan jarak, modul HTTP REST client berbasis JSON (`dio`) dengan penyisipan *Bearer JWT Token*, serta *Android Foreground Service* (`flutter_foreground_task`) yang menjaga koneksi WebSocket tetap hidup di latar belakang agar notifikasi pesanan baru dapat diterima oleh Penjual secara seketika.
2. **Application Server Node (Host Server Aplikasi):**
   * **Simpul Fisik**: Server komputasi fisik atau Virtual Private Server (VPS) berbasis sistem operasi Linux (Ubuntu LTS). Pada fase pengembangan lokal, simpul ini dapat berjalan langsung di komputer pengembang.
   * **Lingkungan Eksekusi**: Runtime Node.js LTS (versi 18 ke atas) yang menjalankan aplikasi web server berbasis Express.js 4 pada port 3000.
   * **Subsistem & Modul Internal**:
     - *Router & Controller API*: Mengelola jalur permintaan REST API (`/api/auth`, `/api/catalog`, `/api/orders`, `/api/scan`, `/api/complaints`, dll.).
     - *WebSocket Server Engine*: Mengelola saluran komunikasi persisten `/ws` untuk menyiarkan pemberitahuan pesanan masuk baru ke HP Penjual secara *real-time*.
     - *Geo-Calculation Engine*: Menghitung perkiraan jarak relatif antara pembeli dan merchant di sisi server menggunakan formula Haversine tanpa mengekspos koordinat GPS presisi toko sebelum pembayaran.
     - *In-Server Payment Gateway Simulator*: Modul dummy terintegrasi di dalam server untuk memproses simulasi pembayaran digital (QRIS dan e-wallet), penahanan kuota, serta pembatalan tagihan kedaluwarsa.
     - *Background Job Worker*: Proses latar belakang terjadwal untuk membatalkan sesi checkout yang melewati batas waktu 15 menit, menonaktifkan kode QR yang kedaluwarsa, dan menjadwalkan pencairan dana (*payout*).
     - *Penyimpanan Berkas Terproteksi*: Direktori disk lokal server (`uploads/`) untuk menyimpan foto gerai toko yang hanya dapat diakses melalui otorisasi API setelah transaksi berhasil.
3. **Database Server Node (Simpul Persistensi Data):**
   * **Simpul Fisik / Kontainer**: Kontainer terisolasi Docker yang menjalankan sistem manajemen basis data relasional PostgreSQL 15.
   * **Basis Data Relasional (`sisarasa_db`)**: Mengelola tabel persisten sistem, meliputi `users`, `merchants`, `offers`, `orders`, `checkout_sessions` (pengendali isolasi ACID kuota), `complaints` (pengaduan refund), `reviews` (ulasan pembeli), serta `audit_logs` dan `platform_metrics`.

### 3.2.2 Protokol Jaringan dan Komunikasi Antar-Simpul
Interaksi antar-simpul fisik diatur dengan ketentuan protokol sebagai berikut:
1. **Client Node ↔ Application Server Node (REST API)**:
   * Menggunakan protokol **HTTPS / HTTP** pada port 443 / 3000 dengan format muatan data pertukaran terstandarisasi **JSON**.
   * Seluruh permintaan yang memerlukan hak akses dilindungi oleh *Authorization Header* berbasis JSON Web Token (JWT).
2. **Client Node ↔ Application Server Node (Notifikasi Real-time)**:
   * Menggunakan protokol **WebSocket (WSS / WS)** pada port 443 / 3000 melalui endpoint `/ws`.
   * Saluran ini beroperasi secara *full-duplex* dan dipertahankan oleh layanan latar depan Android (*Android Foreground Service*) sehingga penjual langsung memperoleh getaran/notifikasi saat ada pesanan masuk meskipun aplikasi tidak sedang aktif dibuka di layar utama.
3. **Application Server Node ↔ Database Server Node**:
   * Menggunakan protokol biner bawaan basis data (**PostgreSQL Wire Protocol**) melalui jaringan TCP/IP internal pada port 5432 (atau port 5433 pada pemetaan Docker lokal pengembang) dengan mekanisme *connection pooling* (`pg.Pool`).
4. **Application Server Node ↔ Storage Disk**:
   * Menggunakan panggilan antarmuka I/O berkas lokal sistem operasi (*POSIX Local File System API*) untuk operasi baca/tulis berkas foto gerai.

### 3.2.3 Audit Konsistensi Arsitektur Fisik
Bagian audit ini mengevaluasi keselarasan antara perancangan Deployment View terhadap spesifikasi Lingkungan Operasi pada Tabel 1.1 dokumen APL (serta subbab 2.5 dokumen SKPL) dan pemenuhan Kebutuhan Non-Fungsional (KNF):

| Komponen / Kebutuhan | Spesifikasi Acuan (Tabel 1.1 / SKPL) | Implementasi Fisik pada Deployment View | Status Evaluasi |
| :--- | :--- | :--- | :---: |
| **Klien Mobile** | Aplikasi Android dibangun dengan Flutter (berkas APK) | Simpul `Client Smartphone` memuat artefak `SisaRasaApp.apk` (gabungan peran Pembeli & Penjual) | **Valid (100% Konsisten)** |
| **Server Aplikasi** | Node.js 18+ dengan Express 4 (Port 3000, rute WebSocket `/ws`) | Simpul `Application Server` menjalankan runtime Node.js dan Express 4 API + WebSocket Engine pada port 3000 | **Valid (100% Konsisten)** |
| **DBMS** | PostgreSQL 15 via Docker (port 5433 dev / 5432 VPS) | Simpul `Database Server` menjalankan kontainer Docker PostgreSQL 15 (`sisarasa_db`) | **Valid (100% Konsisten)** |
| **Penyimpanan Berkas**| Foto gerai disimpan di direktori `uploads/` server terproteksi | Direktori lokal `uploads/` pada disk simpul Application Server dengan gerbang otorisasi API | **Valid (100% Konsisten)** |
| **Payment Gateway** | Modul simulasi dummy in-server (QRIS & e-wallet) | Subkomponen simulator terintegrasi di dalam simpul `Application Server` | **Valid (100% Konsisten)** |
| **Pemberitahuan Penjual**| WebSocket via layanan latar depan Android (tanpa Firebase) | Jalur protokol WSS/WS terdedikasi antara HP Penjual dan `/ws` pada server aplikasi | **Valid (100% Konsisten)** |
| **KNF01 (Keandalan ACID)** | Transaksi pembayaran & kuota memenuhi prinsip ACID | Ditangani oleh transaksi terisolasi PostgreSQL 15 (`checkout_sessions` & kuota `offers`) | **Terpenuhi** |
| **KNF02 (Keamanan Data)** | Enkripsi data & perlindungan identitas | Jalur komunikasi HTTPS/TLS, otorisasi token JWT, dan koordinat GPS presisi toko tidak terekspos | **Terpenuhi** |
| **KNF03 (Notifikasi Cepat)** | Pemberitahuan pesanan masuk seketika | Mekanisme *event push* WebSocket seketika ke HP Penjual begitu status pembayaran berhasil | **Terpenuhi** |
| **KNF04 (Efisiensi Biaya)** | Biaya pihak ketiga Rp 0 (Self-hosted open-source) | Seluruh stack berjalan mandiri di VPS/lokal tanpa layanan berbayar pihak ketiga | **Terpenuhi** |

---

# Referensi

- Sommerville, I. (2016). *Software Engineering* (10th ed.). Pearson. Chapter 6: *Architectural Design*: [https://software-engineering-book.com/slides/](https://software-engineering-book.com/slides/)
- Diagram arsitektur: [https://www.drawio.com/](https://www.drawio.com/), [https://staruml.io/](https://staruml.io/)
