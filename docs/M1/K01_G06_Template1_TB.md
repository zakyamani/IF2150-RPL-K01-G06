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

Perangkat lunak yang diusulkan adalah marketplace penyelamatan surplus makanan berbasis jarak dan waktu yang mempertemukan merchant kuliner dengan konsumen. Ketika merchant telah mengetahui adanya makanan tidak terjual yang masih layak konsumsi, merchant membuat penawaran dalam bentuk **paket kejutan** (*surprise package*), yaitu istilah formal untuk konsep “gacha” pada Bab 1. Sebelum membeli, konsumen hanya melihat kategori paket, kuota, harga, jarak perkiraan, dan jendela pengambilan. Foto, nama, serta alamat merchant tidak ditampilkan agar sistem tidak berubah menjadi sarana berburu makanan murah langsung ke restoran. Setelah pembayaran berhasil, sistem baru membuka identitas dan alamat pickup. Pemenuhan hanya dilakukan dengan pengambilan mandiri agar tidak ada margin serta kompleksitas pengantaran.

Solusi ini relevan dengan kondisi Indonesia yang menghadapi masalah akses pangan dan pemborosan pangan secara bersamaan. Pada 2024, prevalensi ketidakcukupan konsumsi pangan Indonesia masih sebesar 8,27%, sedangkan 4,02% penduduk mengalami kerawanan pangan sedang atau berat. FAO juga memperkirakan bahwa 43,5% penduduk Indonesia belum mampu membeli diet sehat [1]. Di sisi lain, kajian Bappenas terhadap periode 2000–2019 memperkirakan timbulan susut dan sisa pangan sebesar 23–48 juta ton per tahun, dengan kehilangan energi yang secara teoretis setara porsi makan 61–125 juta orang per tahun [2]. Angka tersebut merupakan estimasi historis dari seluruh rantai pasok dan tidak berarti semua makanan yang terbuang masih dapat dikonsumsi. Oleh karena itu, perangkat lunak ini hanya menyasar bagian surplus pada tingkat retail dan jasa makanan yang masih aman, dapat dilacak, serta dapat dialihkan dalam waktu singkat.

Kontribusi solusi terhadap SDG 2 bersifat terbatas tetapi nyata, yaitu memperluas akses terhadap makanan dengan harga lebih rendah dan memperbaiki pencocokan antara surplus lokal dengan permintaan lokal. Pengurangan sampah makanannya sendiri lebih langsung mendukung target SDG 12.3. Perangkat lunak ini bukan pengganti bantuan sosial, food bank, intervensi gizi, ataupun perbaikan sistem produksi dan distribusi pangan nasional.

### 2.1.1 Cara Kerja dari Sudut Pandang Pengguna

Alur utama perangkat lunak adalah sebagai berikut.

1. **Merchant membuat penawaran setelah surplus tersedia.** Merchant memilih kategori, menentukan jumlah paket atau kuota, estimasi nilai normal, harga diskon, serta jendela pickup. Merchant juga menyatakan bahwa makanan masih layak konsumsi sampai akhir jendela tersebut. Sistem tidak terhubung dengan inventori merchant dan tidak memantau stok secara *real-time*; penawaran hanya dibuat secara manual ketika surplus benar-benar ada.
2. **Konsumen memilih penawaran anonim.** Sebelum transaksi, sistem menampilkan kategori, kuota tersisa, harga, jarak perkiraan dari posisi konsumen, dan jendela pickup. Foto, nama merchant, dan alamat tepat disembunyikan. Jarak dihitung oleh sistem tanpa mengirimkan koordinat merchant ke antarmuka konsumen.
3. **Konsumen membayar.** Konsumen menerima ketidakpastian isi serta lokasi sebelum membayar melalui QRIS atau metode digital lain. Dana diproses melalui penyedia pembayaran berizin dan belum diteruskan kepada merchant. Setelah pembayaran berhasil, kuota berkurang satu, detail merchant serta alamat pickup dibuka, dan aplikasi menghasilkan QR pickup sekali pakai.
4. **Konsumen mengambil paket.** Konsumen datang sendiri pada jendela waktu yang ditentukan. Merchant menunjukkan atau menyerahkan paket, lalu memindai QR pickup pada ponsel konsumen. Pemindaian menjadi bukti serah-terima dan memicu penjadwalan dana kepada merchant setelah dikurangi biaya layanan platform.
5. **Transaksi diselesaikan.** Sistem menandai paket sebagai berhasil diserahkan hanya setelah QR dipindai. Konsumen dapat memberi penilaian, sedangkan merchant melihat nilai bersih yang akan diterima. Pengembalian dana dilakukan sesuai skenario pembatalan dan sengketa yang ditetapkan platform.

Dalam sistem ini, **paket** adalah satu unit transaksi berisi kumpulan makanan surplus dari satu merchant, bukan satu menu atau SKU tertentu. Merchant tidak harus menyebutkan isi persis, tetapi harus memilih kategori umum agar konsumen memahami bentuk manfaat yang akan diterima. Kategori awal dapat dibatasi menjadi: (1) makanan berat; (2) roti dan kudapan; (3) buah dan sayur; dan (4) paket campuran. **Kuota** adalah jumlah paket yang benar-benar telah disiapkan untuk satu penawaran. Sebagai contoh, apabila merchant memiliki 12 roti surplus dan membaginya menjadi empat paket, merchant membuat penawaran kategori “roti dan kudapan” dengan kuota empat. Setiap pembayaran berhasil mengurangi kuota satu hingga penawaran habis.

Paket kejutan menjawab masalah layanan *à la carte* yang diidentifikasi pada Bab 1. Merchant tidak harus membuat katalog setiap sisa menu dan konsumen tidak dapat menggunakan aplikasi sebagai katalog untuk datang langsung membeli murah. Penyembunyian identitas dan lokasi sebelum pembayaran juga memisahkan kanal surplus dari penjualan reguler agar persepsi harga serta citra merek merchant tetap terjaga.

### 2.1.2 Target Platform

Target awal pengembangan adalah **aplikasi web responsif dengan kemampuan Progressive Web App (PWA)**. Platform ini dapat digunakan melalui peramban pada ponsel, tablet, maupun komputer dan dapat dipasang pada layar utama perangkat tanpa memerlukan pengembangan aplikasi Android, iOS, serta web secara terpisah. Pilihan tersebut sesuai untuk ruang lingkup proyek akademik karena satu basis kode dapat melayani merchant dan konsumen sekaligus menekan waktu serta sumber daya pengembangan.

PWA juga mendukung kebutuhan utama sistem berupa perhitungan jarak, pembayaran, notifikasi, serta kamera merchant untuk memindai QR pickup. Pemilihan platform berbasis web cukup relevan dengan tingkat akses internet Indonesia yang mencapai 72,78% serta kepemilikan telepon seluler sebesar 68,65% pada 2024 [3]. Walaupun demikian, angka tersebut juga menunjukkan adanya kesenjangan digital; karena itu produk tidak boleh diklaim dapat menjangkau seluruh kelompok rawan pangan hanya melalui aplikasi.

### 2.1.3 Benchmark Too Good To Go

Too Good To Go digunakan sebagai benchmark utama karena telah memvalidasi mekanisme marketplace surplus lintas negara. Aplikasinya memungkinkan konsumen memesan *Surprise Bag* dengan harga sekitar sepertiga nilai retail dan mengambilnya pada waktu yang ditetapkan merchant [4]. Menurut laporan perusahaan, pada akhir 2025 Too Good To Go memiliki lebih dari 120 juta pengguna terdaftar, lebih dari 200.000 mitra aktif, menyelamatkan 156.984.983 paket makanan selama 2025, dan melampaui 600 juta paket secara kumulatif [5]. Angka tersebut merupakan pelaporan perusahaan dan menunjukkan skala adopsi, bukan bukti bahwa model yang sama otomatis berhasil di Indonesia.

Pelajaran utama dari Too Good To Go adalah bahwa isi yang tidak pasti dapat menjadi penyederhanaan operasional: merchant cukup menetapkan jumlah, nilai, lokasi, dan waktu, lalu mengisi paket dengan surplus aktual. Fitur pencarian berbasis lokasi, reservasi dan pembayaran, notifikasi, favorit, rating, kode pengambilan, serta dashboard merchant menjadi benchmark fungsi dasar [4]. Model ini juga memperlihatkan risiko yang harus ditangani, seperti pembatalan ketika surplus riil lebih sedikit, informasi alergen yang terlambat, pengalaman paket yang tidak konsisten, *no-show*, potensi produksi surplus secara sengaja, dan konflik antara monetisasi surplus dengan donasi [5][6].

### 2.1.4 Nilai Unik dan Adaptasi untuk Indonesia

Konsep paket kejutan bukan inovasi yang sepenuhnya baru karena telah digunakan oleh Too Good To Go. Nilai unik perangkat lunak yang diusulkan terletak pada lokalisasi mekanisme tersebut untuk kebutuhan Indonesia, yaitu:

1. **Penawaran anonim sebelum transaksi.** Foto, nama, dan alamat merchant disembunyikan. Konsumen hanya memperoleh kategori, harga, kuota, jarak perkiraan, dan waktu pickup sampai pembayaran berhasil. Mekanisme ini mengurangi risiko aplikasi menjadi katalog *cheap food hunting* langsung ke merchant.
2. **Pickup-only.** Tidak ada driver atau biaya pengantaran. Konsumen mengambil sendiri makanan agar biaya layanan dapat ditekan dan harga akhir tetap serendah mungkin.
3. **Pembayaran lokal dengan pelepasan dana setelah serah-terima.** Konsumen membayar melalui QRIS atau metode digital lain. Merchant baru memperoleh hak atas dana setelah memindai QR pickup konsumen; platform memotong fee sebelum payout.
4. **Dukungan merchant skala kecil.** Merchant membuat penawaran hanya ketika surplus sudah ada, lalu menentukan kategori dan kuota tanpa mengelola setiap SKU atau mengintegrasikan inventori toko.
5. **Tanggung jawab kelayakan pada merchant.** Merchant menyatakan makanan masih layak konsumsi sampai akhir jendela pickup. Platform mencatat deklarasi dan waktu transaksi, tetapi tidak melakukan pemeriksaan fisik atau menetapkan batas aman makanan.
6. **Metrik yang sederhana dan tidak berlebihan.** MVP hanya menghitung paket yang benar-benar diserahkan berdasarkan QR pickup. Angka ini disebut “paket berhasil diserahkan”, bukan otomatis “orang terbebas dari kelaparan” atau “makanan pasti dikonsumsi”.

Donasi otomatis tidak termasuk dalam rancangan ini. Secara konsep, fitur tersebut akan mengalihkan paket yang tidak terjual setelah waktu tertentu kepada food bank atau organisasi sosial. Walaupun tujuannya baik, fitur itu memerlukan organisasi penerima, verifikasi, penjadwalan pickup, kontrol keamanan, dan penentuan siapa yang menanggung biaya. Karena aktor serta proses tersebut belum ada pada proyek, donasi otomatis ditempatkan di luar ruang lingkup.

### 2.1.5 Mekanisme Pembayaran, Payout, dan Refund

Terdapat dua QR yang fungsinya berbeda. **QRIS** digunakan konsumen untuk membayar saat checkout. **QR pickup** adalah token transaksi sekali pakai yang muncul di aplikasi konsumen dan dipindai merchant ketika paket telah ditunjukkan atau diserahkan. QR pickup tidak memindahkan uang secara langsung; pemindaiannya mengubah status transaksi sehingga penyedia pembayaran dapat menjadwalkan payout kepada merchant setelah fee platform dipotong.

Platform tidak disarankan menyimpan uang konsumen secara mandiri seperti rekening biasa. Implementasi nyata perlu memakai penyedia pembayaran berizin yang mendukung pemisahan dana, settlement tertunda, refund, dan payout marketplace. Payout juga sebaiknya tidak benar-benar instan setelah pemindaian, melainkan masuk jadwal settlement singkat agar transaksi bermasalah masih dapat dibekukan dan diperiksa.

Mekanisme refund yang disarankan adalah:

| Kejadian | Status dana yang disarankan | Alasan |
|---|---|---|
| Merchant membatalkan atau paket ternyata tidak tersedia | Refund penuh otomatis kepada konsumen | Kegagalan berasal dari merchant. |
| Paket tidak sesuai kategori atau dinilai tidak layak sebelum QR dipindai | QR tidak dipindai; konsumen mengajukan refund penuh dengan konfirmasi merchant atau proses sengketa | Dana belum boleh dilepas karena serah-terima tidak diterima. |
| Konsumen berubah pikiran setelah pembayaran dan lokasi dibuka | Secara default tidak dapat refund | Lokasi merchant sudah terungkap dan paket telah ditahan; refund bebas dapat dipakai untuk membuka lokasi dan merugikan merchant. |
| Konsumen tidak hadir sampai jendela pickup berakhir | Tidak ada refund; payout kepada merchant diproses melalui prosedur *no-show* | Merchant telah menahan paket sehingga kehilangan kesempatan menjualnya kepada orang lain. Prosedur ini memerlukan kontrol antifraud karena tidak ada QR konsumen yang dipindai. |
| Konsumen dan merchant sepakat membatalkan sebelum pickup | Refund penuh atau dikurangi biaya pembayaran sesuai kebijakan yang ditampilkan sejak awal | Memberi ruang penyelesaian ketika kedua pihak sepakat. |
| Keluhan muncul setelah QR dipindai | Payout dapat dibekukan selama masa pemeriksaan singkat; refund manual berdasarkan bukti | QR membuktikan penyerahan, tetapi tidak selalu membuktikan kualitas makanan. |

Bagian yang paling belum pasti adalah *no-show*. Jika aturan tetap mewajibkan QR untuk seluruh payout, merchant tidak menerima dana meskipun telah menahan paket. Sebaliknya, payout otomatis tanpa QR dapat disalahgunakan merchant. Karena itu, rancangan awal memerlukan jalur khusus *no-show*, batas waktu pelaporan, pemantauan pola klaim, dan mekanisme sengketa. Keputusan final mengenai biaya pembatalan serta bukti *no-show* perlu divalidasi bersama calon merchant dan penyedia pembayaran.

## 2.2 Asumsi dan Batasan

### 2.2.1 Asumsi

Asumsi yang menjadi dasar perancangan adalah sebagai berikut.

| Kategori | Asumsi |
|---|---|
| Pengguna | Konsumen dan merchant memiliki perangkat yang dapat mengakses web, koneksi internet, nomor kontak aktif, serta kemampuan dasar menggunakan layanan digital. |
| Lokasi pilot | Implementasi awal dilakukan pada satu kawasan perkotaan yang memiliki kepadatan merchant dan konsumen memadai agar jarak pemenuhan pendek dan efek jejaring dapat terbentuk. |
| Merchant | Merchant adalah usaha yang dapat diverifikasi dan bertanggung jawab atas keamanan, mutu, legalitas, penyimpanan, pengemasan, kebenaran kuota, serta kelayakan makanan sampai akhir jendela pickup. |
| Sifat surplus | Paket hanya berisi makanan yang benar-benar tidak terjual atau berlebih, bukan produk yang sengaja dibuat untuk dijual melalui kanal diskon. Makanan masih berada dalam batas aman konsumsi pada saat diserahkan. |
| Paket kejutan | Konsumen memahami bahwa aplikasi tidak menampilkan foto atau menu persis. Konsumen menerima variasi isi selama paket masih sesuai kategori dan nilai minimum yang ditawarkan. |
| Harga | Sesuai konsep pada Bab 1, paket ditargetkan memiliki diskon sekitar 50–70% dari estimasi nilai retail yang wajar. Harga dan nilai pembanding dinyatakan merchant secara jujur; sistem dapat memberi rekomendasi dan menandai nilai tidak wajar, tetapi tidak menjamin keuntungan merchant. |
| Pembayaran | Penyedia pembayaran berizin mendukung QRIS, menahan settlement merchant sampai transaksi dikonfirmasi, memproses refund, dan menyalurkan payout setelah dipotong fee. Platform tidak menyimpan kredensial pembayaran sensitif secara langsung. |
| Lokasi | Pengguna memberi izin lokasi untuk menghitung jarak. Sebelum pembayaran, alamat dan koordinat merchant tidak dikirim ke antarmuka konsumen; setelah pembayaran, alamat pickup dibuka. |
| Pemenuhan | Seluruh pesanan diambil langsung oleh konsumen. Konsumen sanggup datang dalam jendela pickup yang ditampilkan sebelum pembayaran. |
| Dampak | Transaksi dihitung sebagai paket berhasil diserahkan hanya setelah QR pickup dipindai. Sistem tidak menyimpulkan bahwa paket pasti dimakan atau bahwa satu paket sama dengan satu orang yang terlepas dari kelaparan. |

### 2.2.2 Batasan Ruang Lingkup

1. Versi awal hanya menangani surplus pada tingkat retail dan jasa makanan, seperti toko roti, kafe, restoran, hotel, katering, dan toko bahan pangan. Sistem tidak menangani kehilangan pada tahap produksi pertanian, pascapanen, atau penyimpanan skala besar.
2. Sistem bukan produsen, pemilik, penguji laboratorium, ataupun penjamin mutlak isi paket. Platform menyediakan aturan, verifikasi, pencatatan, dan mekanisme penanganan insiden, sedangkan merchant tetap menjadi pihak yang menyiapkan dan menyerahkan makanan.
3. Makanan kedaluwarsa, rusak, tercemar, telah berada di luar kendali suhu yang dipersyaratkan, atau tidak memiliki informasi minimum dilarang ditawarkan. Istilah “surplus” tidak boleh ditafsirkan sebagai makanan yang sudah tidak aman.
4. Isi rinci paket tidak dijamin karena bergantung pada surplus aktual. Sistem hanya menjamin kategori, nilai minimum, kuota, jarak perkiraan, harga, dan jendela pickup yang dinyatakan dalam penawaran.
5. Platform tidak mengumpulkan informasi alergen per paket. Konsumen dengan alergi berat atau kebutuhan diet khusus diperingatkan bahwa paket kejutan mungkin tidak sesuai. Merchant tetap wajib menyampaikan informasi yang diwajibkan hukum; apabila paket tidak aman bagi konsumen dan QR belum dipindai, transaksi dapat diajukan untuk refund.
6. Pickup hanya dapat dilakukan pada jendela yang ditetapkan merchant. Tidak tersedia delivery atau aktor driver. Keterlambatan konsumen, *no-show*, kemacetan, cuaca, dan gangguan operasional menjadi risiko konsumen.
7. MVP tidak mencakup stok *real-time*, integrasi POS/ERP, prediksi surplus berbasis AI, *dynamic pricing*, pengelolaan kedaluwarsa per SKU, delivery, pelacakan GPS, cold chain khusus, serta donasi otomatis ke organisasi sosial.
8. Produk tidak menargetkan penerima bantuan berdasarkan status ekonomi dan tidak dapat mengklaim menyelesaikan kelaparan, stunting, wasting, atau ketidakcukupan gizi. Kualitas nutrisi paket juga tidak selalu seimbang karena mengikuti surplus yang tersedia.
9. Cakupan awal terbatas pada wilayah pilot; layanan tidak menjamin ketersediaan merchant atau paket yang merata di seluruh daerah. Efektivitas marketplace bergantung pada tercapainya kepadatan penawaran dan permintaan lokal.
10. Pengembangan dilakukan dengan sumber daya tim, waktu, dan infrastruktur proyek akademik. Ketersediaan tinggi, audit keamanan penuh, sertifikasi sistem, operasi customer service 24 jam, serta ekspansi produksi berskala nasional berada di luar ruang lingkup awal.

### 2.2.3 Batasan Regulasi, Keamanan, dan Privasi

Perangkat lunak harus tunduk pada peraturan Indonesia yang berlaku. UU Nomor 18 Tahun 2012 menempatkan pangan sebagai kebutuhan dasar dan menuntut ketersediaan pangan yang aman, bermutu, dan bergizi [7]. Penyelenggaraan keamanan pangan di sepanjang rantai pangan diatur oleh PP Nomor 86 Tahun 2019 yang telah diubah melalui PP Nomor 1 Tahun 2026 [8][9]. Untuk pangan olahan siap saji, Permenkes Nomor 2 Tahun 2023 mewajibkan penyedia memastikan persyaratan higiene dan sanitasi, termasuk perlindungan dari kontaminasi serta penyimpanan, pengangkutan, dan penyajian yang memenuhi prinsip kesehatan [10]. Konsekuensinya, fitur diskon atau status surplus tidak mengurangi kewajiban keamanan pangan merchant.

Informasi harga, kondisi, kategori, batas waktu, pembatalan, pengembalian dana, dan tanggung jawab para pihak harus disampaikan secara jujur dan tidak menyesatkan sesuai prinsip perlindungan konsumen dalam UU Nomor 8 Tahun 1999 [11]. Pembagian tanggung jawab antara platform, merchant, konsumen, dan penyedia pembayaran harus dituangkan dalam syarat layanan serta tidak boleh sekadar menyalin ketentuan Too Good To Go karena hukum dan praktik setiap negara berbeda. Platform juga tidak boleh menahan serta memindahkan dana sendiri tanpa struktur yang sesuai; alur pembayaran, settlement tertunda, refund, dan payout harus dijalankan melalui penyedia jasa pembayaran berizin.

Sistem memproses nama, kontak, lokasi, dan riwayat transaksi. Pengumpulan serta penggunaannya dibatasi pada tujuan layanan yang sah, transparan, dan minimum sesuai UU Nomor 27 Tahun 2022 tentang Pelindungan Data Pribadi [12]. Koordinat merchant tidak dikirimkan kepada konsumen sebelum pembayaran, sedangkan merchant hanya memperoleh data konsumen yang diperlukan untuk serah-terima. Persetujuan untuk fungsi layanan dipisahkan dari persetujuan promosi, sementara penghapusan akun, pembatasan akses berbasis peran, jadwal retensi, audit log, dan prosedur insiden perlu disediakan. Keandalan dan keamanan transaksi elektronik juga harus mempertimbangkan PP Nomor 71 Tahun 2019 [13].

Ketentuan hukum yang dicantumkan merupakan batas perancangan awal, bukan pendapat hukum. Sebelum penerapan pada pengguna nyata, tim perlu meminta validasi dari pihak yang memahami perizinan usaha pangan, higiene sanitasi, perlindungan konsumen, pajak, transaksi elektronik, dan pelindungan data.

---

# BAB 3: Spesifikasi Kebutuhan dan Proses Bisnis

## 3.1 Identifikasi Aktor
Daftar seluruh aktor (pengguna) yang akan berinteraksi langsung dengan sistem solusi yang dikembangkan. Berisi penjelasan singkat mengenai peran dan karakteristik dari masing-masing aktor.

| Aktor | Deskripsi |
| :--- | :--- |
| *Penjual* | *Merchant terverifikasi yang membuat penawaran paket ketika memiliki makanan surplus yang tidak habis terjual pada periode reguler, tetapi masih layak dikonsumsi sampai akhir jendela pickup.* |
| *Pembeli* | *Konsumen yang membeli paket kejutan berharga murah melalui aplikasi dan mengambilnya sendiri pada lokasi serta waktu yang dibuka setelah pembayaran.* |


## 3.2 Kebutuhan Pengguna Awal
Mendefinisikan apa yang ingin dicapai oleh pengguna saat menggunakan sistem ini dalam format *User Story* (Sebagai [Aktor], saya ingin [Aktivitas/Kebutuhan], sehingga [Tujuan/Nilai]). Berfokus pada "apa yang ingin dilakukan pengguna".

| ID | Aktor | Kebutuhan / Aktivitas | Tujuan / Nilai |
| :--- | :--- | :--- | :--- |
| US-01 | *Penjual* | *Membuat penawaran paket surplus dengan memilih kategori, kuota, nilai normal, harga diskon, dan jendela pickup* | *Surplus yang sudah tersedia dapat ditawarkan dengan cepat tanpa mencatat setiap menu* |
| US-02 | *Penjual* | *Mengubah atau menutup penawaran selama belum terjual serta melihat kuota yang tersisa* | *Penawaran tetap sesuai dengan jumlah paket yang benar-benar tersedia* |
| US-03 | *Penjual* | *Melihat daftar pesanan yang telah dibayar dan jadwal pickup* | *Dapat menyiapkan serta menyerahkan paket tepat waktu* |
| US-04 | *Penjual* | *Memindai QR pickup pembeli setelah paket ditunjukkan atau diserahkan* | *Serah-terima tercatat dan payout dapat diproses setelah dipotong fee* |
| US-05 | *Pembeli* | *Melihat penawaran anonim berdasarkan kategori, kuota, harga, jarak perkiraan, dan jendela pickup* | *Dapat memilih makanan terjangkau tanpa membuka identitas merchant sebelum transaksi* |
| US-06 | *Pembeli* | *Membayar paket melalui QRIS atau metode pembayaran digital yang didukung* | *Paket dapat dipesan dan dana diproses dengan aman melalui penyedia pembayaran* |
| US-07 | *Pembeli* | *Melihat nama, alamat merchant, dan QR pickup setelah pembayaran berhasil* | *Dapat mendatangi lokasi yang tepat dan membuktikan hak pengambilan* |
| US-08 | *Pembeli* | *Mengambil paket sendiri dan menunjukkan QR pickup kepada penjual* | *Mendapat makanan tanpa menambah biaya pengantaran* |
| US-09 | *Pembeli* | *Mengajukan refund apabila merchant membatalkan, paket tidak tersedia, atau paket tidak diterima sebelum QR dipindai* | *Dana terlindungi ketika transaksi gagal karena merchant atau paket bermasalah* |
| US-10 | *Pembeli* | *Melihat status pembayaran, pickup, refund, dan riwayat transaksi* | *Dapat memantau penyelesaian setiap transaksi secara transparan* |

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
- [1] Food and Agriculture Organization of the United Nations. (2025, 16 Oktober). *On World Food Day, FAO calls for collective actions to deliver healthy food for all Indonesians*. https://www.fao.org/indonesia/news/detail/on-world-food-day--fao-calls-for-collective-actions-to-deliver-healthy-food-for-all-indonesians/en
- [2] Kementerian PPN/Bappenas. (2021, 9 Juni). *Bappenas jabarkan pentingnya kelola food loss and waste untuk pembangunan rendah karbon dan ekonomi sirkular*. https://greeneconomy.bappenas.go.id/home/bappenas-jabarkan-pentingnya-kelola-food-loss-and-waste-untuk-pembangunan-rendah-karbon-dan-ekonomi-sirkular/
- [3] Badan Pusat Statistik. (2025, 29 Agustus). *Statistik Telekomunikasi Indonesia 2024*. https://www.bps.go.id/id/publication/2025/08/29/beaa2be400eda6ce6c636ef8/telecommunication-statistics-in-indonesia-2024.html
- [4] Too Good To Go. (n.d.). *How does the Too Good To Go app work?* Diakses 31 Agustus 2026. https://www.toogoodtogo.com/en-us/how-does-the-app-work
- [5] Too Good To Go. (2025, 31 Desember). *Impact Report 2025*. https://cdn.sanity.io/files/nqimd3nr/production/9ec572412456974a5d6f54f34268c52d442c8f58.pdf?=dl
- [6] Too Good To Go. (n.d.). *Marketplace Store Terms*. Diakses 31 Agustus 2026. https://www.toogoodtogo.com/en-us/legal/terms-and-conditions-marketplace
- [7] Republik Indonesia. (2012). *Undang-Undang Nomor 18 Tahun 2012 tentang Pangan*. https://peraturan.bpk.go.id/Details/39100/uu-no-18-tahun-2012
- [8] Republik Indonesia. (2019). *Peraturan Pemerintah Nomor 86 Tahun 2019 tentang Keamanan Pangan*. https://peraturan.bpk.go.id/Details/129230/pp-no-86-tahun-
- [9] Republik Indonesia. (2026). *Peraturan Pemerintah Nomor 1 Tahun 2026 tentang Perubahan atas Peraturan Pemerintah Nomor 86 Tahun 2019 tentang Keamanan Pangan*. https://peraturan.bpk.go.id/Details/348700/pp-no-1-tahun-2026
- [10] Kementerian Kesehatan Republik Indonesia. (2023). *Peraturan Menteri Kesehatan Nomor 2 Tahun 2023 tentang Peraturan Pelaksanaan Peraturan Pemerintah Nomor 66 Tahun 2014 tentang Kesehatan Lingkungan*. https://jdih.kemkes.go.id/storage/documents/pdfs/2023permenkes002.pdf
- [11] Republik Indonesia. (1999). *Undang-Undang Nomor 8 Tahun 1999 tentang Perlindungan Konsumen*. https://peraturan.bpk.go.id/Details/45288/uu-no-8-tahun-1999
- [12] Republik Indonesia. (2022). *Undang-Undang Nomor 27 Tahun 2022 tentang Pelindungan Data Pribadi*. https://peraturan.bpk.go.id/Details/229798/uu-no-27-tahun-2022
- [13] Republik Indonesia. (2019). *Peraturan Pemerintah Nomor 71 Tahun 2019 tentang Penyelenggaraan Sistem dan Transaksi Elektronik*. https://peraturan.bpk.go.id/Details/122030/pp-no-71-tahun-2019
- Diagram UML: https://www.drawio.com/, https://staruml.io/
