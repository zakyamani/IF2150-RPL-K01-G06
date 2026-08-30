<h1>
IF2150 REKAYASA PERANGKAT LUNAK
<br>
TUGAS 1
<br>
TOPIC BRAINSTORMING
</h1>
<br>

## *Nama Perangkat Lunak*

### Untuk: *[Amanda Aurellia Salsabilla]*

Dipersiapkan oleh:
| Informasi | Keterangan |
| --- | --- |
| Kelas | *\[K1\]* |
| Kelompok | *\[6\]*  |

| NIM | Nama |
|---|---|
| *[13525067]* | *[Fathar Atandra Denaya]* |
| *[13525040]* | *[Muhammad Zaky Amani]* |
| *[13525139]* | *[Josephine Bintang N.L]* |
| *[13525070]* | *[Devina Athalia Putri Kusumah]* |
| *[13525004]* | *[Nabil Rabbani]* |
---

<br>
<br>

# BAB 1: Analisis Permasalahan

## 1.1 Latar Belakang Masalah
Indonesia menghadapi ancaman ganda yang kontradiktif antara kerawanan pangan dan tingginya volume makanan terbuang. Di satu sisi, masalah kerawanan pangan dan gizi masih menjadi tantangan mendasar. Di sisi lain, potensi bahan pangan bernilai tinggi terbuang setiap hari di perkotaan, khususnya dari industri kuliner retail seperti toko roti, kafe, dan restoran. Pelaku usaha kerap mengalami overproduction atau sisa stok harian yang masih sangat layak konsumsi namun harus dibuang pada akhir jam operasional untuk menjaga standar kesegaran brand.Kondisi ini berkaitan erat dengan indikator SDG 2, yang memandatkan penghentian kelaparan, pencapaian ketahanan pangan, dan perbaikan gizi. Berdasarkan studi Kementerian PPN/Bappenas, Indonesia menghasilkan sampah makanan sebesar 23 hingga 48 juta ton per tahun. Volume sampah makanan ini setara dengan 115-184 kg per kapita per tahun dan menimbulkan kerugian ekonomi mencapai Rp213 hingga Rp551 triliun per tahun. Dari sisi gizi, Bappenas mencatat bahwa timbulan food waste tersebut secara matematis mampu memberi makan sekitar 61 hingga 125 juta orang-atau nyaris separuh populasi Indonesia. Urgensi penyelesaian masalah ini terletak pada belum optimalnya saluran distribusi pangan terjangkau yang memanfaatkan surplus food secara cepat. Tanpa adanya intervensi teknologi berbasis rantai pasok pintar, makanan berlebih dari gerai retail akan berakhir di Tempat Pemrosesan Akhir (TPA) sebagai pemicu gas metana penyebab perubahan iklim, sementara masyarakat berpenghasilan rendah tetap kesulitan mengakses makanan berkualitas dengan harga terjangkau. Perangkat lunak penyelamat makanan ini hadir sebagai solusi urgen untuk memotong rantai pemborosan sekaligus mengakselerasi pencapaian target SDG 2 di Indonesia.


## 1.2 Analisis Kondisi Saat Ini
Saat ini, penanganan sisa makanan pada industri kuliner retail masih mengandalkan saluran konvensional seperti layanan pesan-antar reguler (GoFood, GrabFood, ShopeeFood), pemusnahan mandiri, atau donasi manual. Layanan pesan-antar berbasis a la carte tidak dirancang untuk menangani surplus food karena merchant tidak dapat memprediksi varian produk yang tersisa di akhir hari, sehingga berisiko tinggi menyebabkan pembatalan pesanan akibat stok habis. Di sisi lain, pembuangan sisa makanan menimbulkan kerugian finansial total bagi merchant, sedangkan donasi manual terkendala tingginya biaya logistik dan terbatasnya umur simpan produk basah. Sementara itu, opsi pengobralan langsung di resto fisik sering kali dihindari karena berpotensi merusak standar harga pasar dan citra merk merchant.

Kondisi tersebut menyisakan celah besar belum adanya mekanisme distribusi pangan berlebih yang cepat, fleksibel, dan bernilai ekonomi. Aplikasi berbasis sistem gacha hadir untuk menyelesaikan kesenjangan ini dengan menghilangkan kerumitan pengelolaan inventory harian. Merchant cukup memasukkan kuota paket tanpa perlu mendaftarkan varian menu satu per satu, sehingga operasional toko tetap efisien. Konsep gacha ini juga melindungi nilai merek merchant sekaligus memungkinkan pemotongan harga secara signifikan (50%-70%), sehingga masyarakat dapat mengakses makanan berkualitas dengan harga terjangkau secara real-time sebelum jam operasional toko berakhir.

source : https://www.liputan6.com/bisnis/read/5634939/miris-indonesia-buang-buang-48-juta-ton-makanan-per-tahun-setara-kebutuhan-pangan-125-juta-orang
---

# BAB 2: Analisis Solusi

## 2.1 Deskripsi Perangkat Lunak
Abstraksikan solusi perangkat lunak yang diusulkan dari sudut pandang pengguna. Jelaskan target platform yang akan digunakan (misalnya: desktop application) beserta alasan pemilihannya. Deskripsikan juga nilai unik (inovasi inti) dari perangkat lunak kalian dan apa yang membedakannya dari solusi yang sudah ada.

## 2.2 Asumsi dan Batasan
Definisikan secara tegas asumsi (baik teknis maupun dari sisi pengguna) yang menjadi dasar pengembangan. Tuliskan batasan seperti regulasi/hukum, keterbatasan sumber daya, dan ruang lingkup solusi.

---

# BAB 3: Spesifikasi Kebutuhan dan Proses Bisnis

## 3.1 Identifikasi Aktor
Daftar seluruh aktor (pengguna) yang akan berinteraksi langsung dengan sistem solusi yang dikembangkan. Berisi penjelasan singkat mengenai peran dan karakteristik dari masing-masing aktor.

| Aktor | Deskripsi |
| :--- | :--- |
| *Penjual* | *Pengguna ini bertindak sebagai pihak yang menjual makanan dan minuman yang sudah melewati hari penjualan namun masih layak untuk dikonsumsi.* |
| *Pembeli* | *Pengguna ini bertindak sebagai pihak yang membeli makanan dan minuman dengan tujuan dapat mengonsumsi makanan yang layak dengan harga yang murah.* |
| *Driver* | *Pengguna ini bertindak sebagai pengantar makanan dan minuman dari penjual ke pembeli.* |


## 3.2 Kebutuhan Pengguna Awal
Mendefinisikan apa yang ingin dicapai oleh pengguna saat menggunakan sistem ini dalam format *User Story* (Sebagai [Aktor], saya ingin [Aktivitas/Kebutuhan], sehingga [Tujuan/Nilai]). Berfokus pada "apa yang ingin dilakukan pengguna".

| ID | Aktor | Kebutuhan / Aktivitas | Tujuan / Nilai |
| :--- | :--- | :--- | :--- |
| US-01 | *Penjual * |  *Mengunggah makanan/minuman yang sudah melewati hari penjualan beserta harga diskon* | *Produk dapat terjual sebelum terbuang* |
| US-02 | *Penjual* | *Mengatur stok dan status ketersediaan produk yang sudah diunggah* | *Informasi yang dilihat pembeli selalu akurat dan tidak menjual produk yang sudah habis* |
| US-03 | *Penjual * |  *Melihat daftar pesanan yang masuk beserta detail pembeli* | *Dapat menyiapkan pesanan dengan benar dan tepat waktu* |
| US-04 | *Pembeli* | *Mencari makanan/minuman diskon sesuai lokasi terdekat* | *Menemukan makanan layak konsumsi dengan harga murah tanpa perlu mencari manual* |
| US-05 | *Pembeli* | *Melihat detail produk (foto, tanggal produksi/kedaluwarsa, harga diskon)* | *Dapat memastikan produk masih layak dikonsumsi sebelum membeli* |
| US-06 | *Pembeli * |  *Memesan dan membayar produk langsung melalui aplikasi* | *Proses transaksi yang cepat, praktis, dan aman* |
| US-07 | *Pembeli* | *Melacak status pesanan secara real-time* | *Mengetahui kapan pesanan akan sampai* |
| US-08 | *Driver * |  *Menerima notifikasi pesanan baru yang perlu diantar* | *Dapat segera mengambil dan mengantarkan pesanan tanpa menunggu* |
| US-09 | *Driver* | *Melihat lokasi penjual dan pembeli dalam satu tampilan/rute* | *Mengantar pesanan dengan efisien dan tidak salah alamat* |
| US-10 | *Driver* | *Memperbarui status pengantaran (diambil, dalam perjalanan, terkirim)* | *Penjual dan pembeli mendapat informasi terkini tentang pesanan* |

## 3.3 Model Proses Bisnis
Buatlah *Activity Diagram* atau *Swimlane Diagram* yang menunjukkan alur kerja proses bisnis dari sistem solusi. Diagram ini harus memvisualisasikan bagaimana alur operasional di dunia nyata berjalan lebih efisien dengan adanya interaksi antara aktor (yang didefinisikan pada poin 3.1) dan sistem perangkat lunak. Perhatikan notasi yang digunakan dalam pembuatannya.
<br>

<p align="center">
<img alt="Contoh Activity Diagram" src="./assets/diagram/diagram-act-1.avif" width="70%">
</p>
<p align="center">
<i>Gambar 1. Contoh Activity Diagram</i>
</p>

<br>

# Referensi
- Diagram UML: https://www.drawio.com/, https://staruml.io/
