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

Tabel 2.1. Identifikasi Komponen/Modul/Subsistem

| Nama Komponen/Modul/Subsistem | Jenis                 | Penjelasan                                                                                                           |
| :---------------------------- | :-------------------- | :------------------------------------------------------------------------------------------------------------------- |
| *KatalogView*                 | *View*                | *Menampilkan daftar produk dan meneruskan aksi pelanggan (misalnya "Tambah ke Keranjang") ke KatalogController.*     |
| *KeranjangView*               | *View*                | *Menampilkan isi keranjang pelanggan beserta tombol checkout.*                                                       |
| *CheckoutView*                | *View*                | *Menampilkan ringkasan pesanan dan pilihan metode pembayaran kepada pelanggan.*                                      |
| *RiwayatPesananView*          | *View*                | *Menampilkan daftar pesanan yang pernah dibuat pelanggan beserta statusnya.*                                         |
| *KatalogController*           | *Controller*          | *Memproses permintaan daftar produk dan penambahan produk ke keranjang.*                                             |
| *KeranjangController*         | *Controller*          | *Memproses perubahan isi keranjang dan membuat pesanan baru saat checkout.*                                          |
| *PembayaranController*        | *Controller*          | *Memproses pemilihan metode pembayaran dan meneruskan permintaan otorisasi ke PaymentGatewayAdapter.*                |
| *PesananController*           | *Controller*          | *Memproses permintaan riwayat pesanan milik pelanggan.*                                                              |
| *Produk*                      | *Model*               | *Merepresentasikan data produk beserta stoknya serta metode untuk mengakses dan mengubahnya.*                        |
| *Keranjang*                   | *Model*               | *Merepresentasikan item yang dipilih pelanggan sebelum checkout serta metode untuk mengakses dan mengubahnya.*       |
| *Pesanan*                     | *Model*               | *Merepresentasikan data pesanan beserta status pembayarannya serta metode untuk mengakses dan mengubahnya.*          |
| *Pelanggan*                   | *Model*               | *Merepresentasikan data akun pelanggan serta metode untuk mengakses dan mengubahnya.*                                |
| *Validasi*                    | *Pendukung*           | *Memvalidasi input pelanggan sebelum diproses oleh controller.*                                                      |
| *PaymentGatewayAdapter*       | *Integrasi Eksternal* | *Mengirim permintaan otorisasi ke payment gateway (dummy) dan meneruskan status pembayaran ke PembayaranController.* |
| *Database*                    | *Penyimpanan Data*    | *Menyimpan seluruh data model secara persisten, baik lokal (misalnya SQLite) maupun terpusat (misalnya Supabase).*   |
| *...*                         | *...*                 | *...*                                                                                                                |

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

## 3.1 XXX View

Tuliskan secara singkat mengenai model arsitektur perangkat lunak yang Anda pilih dan sertakan alasan mengapa model arsitektur tersebut cocok untuk aplikasi Anda.

<p align="center">
<img alt="Contoh Logical View pada P/L E-Commerce" src="./assets/diagram/contoh-logical-view.webp" width="100%">
</p>
<p align="center">
<i>Gambar 2. Contoh Logical View pada P/L E-Commerce</i>
</p>

Gambar 2 adalah contoh *Logical View* dalam bentuk *block diagram*. Seluruh komponen pada Tabel 2.1 digambarkan dan dikelompokkan sesuai pola MVC (*View*, *Controller*, *Model*), ditambah komponen pendukung dan basis data. Sistem di luar P/L, seperti *Payment Gateway (dummy)*, digambarkan dengan garis putus-putus dan tidak perlu dimasukkan ke Tabel 2.1. Setiap garis diberi label: "Memanggil" untuk *View* yang memanggil *Controller*, "akses" untuk *Controller* yang mengakses *Model*, serta agregasi dan komposisi untuk hubungan antar-*Model*.

<sub><b><i>Catatan</i></b>: <i>Ganti XXX dengan nama view yang dibuat, misalnya Logical View. Gambar 2 hanya contoh untuk P/L e-commerce, ganti dengan view milik kelompok Anda yang memuat seluruh komponen pada Tabel 2.1. Jenis view dan notasinya boleh berbeda dari contoh. Jika membuat view tambahan, lanjutkan pola 3.x ini (3.2, 3.3, dan seterusnya).</i></sub>

---

# Referensi

- Sommerville, I. (2016). *Software Engineering* (10th ed.). Pearson. Chapter 6: *Architectural Design*: [https://software-engineering-book.com/slides/](https://software-engineering-book.com/slides/)
- Diagram arsitektur: [https://www.drawio.com/](https://www.drawio.com/), [https://staruml.io/](https://staruml.io/)
