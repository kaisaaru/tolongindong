# Analisis Dua Peran dan Validasi Transaksi Dua Arah

Status dokumen: `REVIEW` v0.1. Dokumen ini menjawab pertanyaan yang diangkat tim tentang dua peran dan validasi transaksi. Isinya usulan SA yang perlu disetujui sebelum BE mulai membuat skema.

## 1. Rumusan masalah

Aplikasi ini bukan aplikasi satu arah seperti toko daring biasa. Ada dua orang yang sama sama punya kepentingan uang di satu transaksi, dan keduanya bisa dirugikan oleh pihak lain.

Dari sisi client, risikonya membayar tetapi pekerjaan tidak dikerjakan, dikerjakan asal asalan, atau helper menghilang setelah menerima pesanan. Dari sisi helper, risikonya sudah menempuh perjalanan atau sudah menalangi pembelian tetapi client membatalkan, tidak mengonfirmasi selesai, atau menghilang. Kalau desainnya keliru, salah satu pihak selalu menanggung risiko lebih besar dan aplikasi kehilangan kepercayaan.

Ada dua pertanyaan desain yang harus dijawab sebelum apa pun dibangun. Pertama, bagaimana satu orang bisa menjadi client dan helper tanpa membuat data identitas dan saldo menjadi kacau. Kedua, kapan tepatnya uang berpindah dan siapa yang memegangnya di antara waktu pesanan dibuat dan pekerjaan selesai.

## 2. Arsitektur akun untuk dua peran

Tiga opsi yang saya pertimbangkan.

| Opsi | Cara kerja | Kelebihan | Kekurangan |
| --- | --- | --- | --- |
| A. Dua akun terpisah | Satu orang mendaftar dua kali dengan email berbeda untuk jadi client dan helper | Pemisahan tegas, otorisasi sederhana | Identitas dan saldo terpecah, verifikasi identitas ganda, rekonsiliasi uang menyulitkan, pengalaman pengguna buruk |
| B. Satu akun satu peran aktif | Satu akun punya kolom peran yang nilainya client atau helper, diganti lewat pengaturan | Skema paling sederhana | Riwayat pesanan sebagai client hilang saat berganti peran, saldo ambigu milik peran mana, tidak sesuai prototipe yang menampilkan menu jadi helper di dalam profil client |
| C. Satu akun dua kapabilitas | Satu entitas `user` selalu punya kapabilitas client, ditambah `helper_profile` opsional yang aktif setelah verifikasi. Antarmuka menyediakan pertukaran konteks tampilan | Identitas dan dompet tunggal, riwayat utuh, sesuai prototipe, verifikasi cukup sekali | Butuh aturan otorisasi per aksi dan aturan pencegahan konflik kepentingan |

Rekomendasi saya opsi C, tercatat sebagai `DEC-01`. Alasannya bukan sekadar kerapian data. Dompet tunggal membuat pendapatan sebagai helper bisa langsung dipakai memesan sebagai client, dan itu justru inti cerita SDG 8 yang mau kita angkat, yaitu perputaran ekonomi di dalam komunitas.

Konsekuensi teknis yang harus dipatuhi.

Peran ditentukan per pesanan, bukan per akun. Setiap baris pesanan menyimpan `client_id` dan `helper_id`, dan otorisasi sebuah aksi diperiksa terhadap posisi pengguna pada pesanan itu, bukan terhadap kolom peran global. Pertanyaan yang dijawab sistem selalu berbentuk apakah pengguna ini adalah client dari pesanan ini, bukan apakah pengguna ini seorang client.

Pertukaran konteks tampilan hanya mengubah tampilan, bukan hak akses. Kalau helper sedang melihat mode client, dia tetap wajib menerima notifikasi pesanan aktif miliknya sebagai helper. Kehilangan notifikasi karena salah mode adalah bug yang mahal.

Larangan konflik kepentingan wajib ditegakkan di sisi server. Sistem menolak `helper_id` yang sama dengan `client_id` pada satu pesanan, ini `FR-ORD-016`. Selain itu, satu helper tidak boleh memegang lebih dari satu pesanan aktif, ini `FR-ORD-017`, dan seorang pengguna tidak boleh menjadi helper untuk pesanan yang dibuatnya lewat akun lain yang terdeteksi memakai nomor telepon atau perangkat yang sama.

## 3. Kapan uang berpindah

Bagian ini direvisi 19 Agustus 2026 mengikuti `DEC-05`, model tawar harga dua arah yang disepakati tim. Kesimpulan intinya berubah dari versi draf pertama, jadi baca ulang bagian ini meskipun sudah pernah baca sebelumnya.

Pada model tawar harga, tidak ada momen tunggal "helper menekan terima" di awal, karena yang terjadi lebih dulu adalah beberapa helper mengajukan angka masing masing tanpa komitmen apa pun. Titik yang tepat untuk penahanan dana bergeser menjadi **saat client memilih satu tawaran, dan helper yang dipilih mengonfirmasi masih tersedia**. Dua syarat itu harus terpenuhi bersamaan, bukan salah satu saja, karena kalau dana ditahan begitu client memilih tanpa menunggu konfirmasi helper, ada risiko dana tertahan untuk helper yang ternyata sudah mengambil pesanan lain di saat bersamaan.

Konsekuensinya, ada jeda antara pesanan dibuat dan dana ditahan, dan selama jeda itu client belum kehilangan akses ke saldonya sama sekali. Ini justru sejalan dengan alasan awal kenapa saya tidak mau menahan dana sejak pesanan dibuat, dana tetap bebas dipakai client sampai ada kepastian ganda, yaitu satu harga pasti dan satu helper pasti yang sudah mengonfirmasi.

```mermaid
sequenceDiagram
    participant C as Client
    participant S as Sistem
    participant H1 as Helper A
    participant H2 as Helper B
    participant W as TD-Wallet

    C->>S: Buat pesanan, harga estimasi Rp 40.000
    S->>H1: Siarkan pesanan
    S->>H2: Siarkan pesanan
    H1->>S: Ajukan tawaran Rp 43.000
    H2->>S: Ajukan tawaran Rp 38.000
    S-->>C: Tampilkan daftar tawaran dengan profil dan rating
    C->>S: Pilih tawaran Helper B, Rp 38.000
    S->>H2: Minta konfirmasi ketersediaan, batas 60 detik
    H2->>S: Konfirmasi tersedia
    S->>W: Cek saldo tersedia client
    W-->>S: Saldo cukup
    S->>W: Tahan Rp 38.000 dari saldo client
    W-->>S: Dana tertahan, id transaksi HOLD-002
    S-->>H1: Tawaran ditutup, tidak terpilih
    S-->>C: Status diterima, saldo tersedia berkurang
    S-->>H2: Boleh berangkat, dana sudah dijamin
    H2->>S: Tandai pekerjaan selesai
    S-->>C: Minta konfirmasi, batas waktu 24 jam
    C->>S: Konfirmasi selesai
    S->>W: Lepas dana ke helper dikurangi potongan platform 10 persen
    W-->>H2: Saldo bertambah Rp 34.200
    S->>S: Minta client memberi penilaian untuk helper
```

Kalau client diam sampai batas 24 jam, sistem yang mengonfirmasi, ini `FR-ORD-012`. Tanpa aturan ini, helper bisa disandera oleh client yang sekadar malas menekan tombol.

Satu catatan yang perlu diwaspadai bersama Backend dan Mobile. Karena sekarang ada tahap "helper dipilih tapi belum konfirmasi", ada window pendek di mana status pesanan bukan lagi searching tapi juga belum diterima. Status baru ini perlu punya nama sendiri di state machine, saya sebut `pending_confirmation` pada diagram di bagian empat, supaya Mobile tahu harus menampilkan apa selama helper terpilih belum merespons.

## 4. State machine pesanan

Semua pihak harus sepakat pada satu daftar status. Tanpa ini, BE, Mobile, dan QA akan memakai kosakata berbeda dan integrasi akan berantakan.

```mermaid
stateDiagram-v2
    [*] --> DRAFT
    DRAFT --> SEARCHING: client konfirmasi pesanan, disiarkan ke helper
    SEARCHING --> SEARCHING: helper lain mengajukan tawaran
    SEARCHING --> PENDING_CONFIRMATION: client memilih satu tawaran
    SEARCHING --> EXPIRED: jendela 300 detik habis tanpa tawaran masuk
    SEARCHING --> CANCELLED_BY_CLIENT: client batal sebelum memilih tawaran

    PENDING_CONFIRMATION --> ACCEPTED: helper terpilih konfirmasi, dana ditahan
    PENDING_CONFIRMATION --> SEARCHING: helper terpilih tidak merespons 60 detik, atau sudah ambil pesanan lain

    ACCEPTED --> ON_THE_WAY: helper berangkat
    ON_THE_WAY --> ARRIVED: helper tiba di lokasi
    ARRIVED --> IN_PROGRESS: pekerjaan dimulai
    IN_PROGRESS --> PRICE_ADJUSTMENT: helper ajukan penyesuaian talangan
    PRICE_ADJUSTMENT --> IN_PROGRESS: client setujui, dana tambahan ditahan
    PRICE_ADJUSTMENT --> DISPUTED: client tolak penyesuaian
    IN_PROGRESS --> AWAITING_CONFIRMATION: helper tandai selesai

    AWAITING_CONFIRMATION --> COMPLETED: client konfirmasi
    AWAITING_CONFIRMATION --> COMPLETED: batas 24 jam lewat
    AWAITING_CONFIRMATION --> DISPUTED: client ajukan keberatan

    ACCEPTED --> CANCELLED_BY_CLIENT: client batal, kena biaya batal
    ON_THE_WAY --> CANCELLED_BY_CLIENT: client batal, kompensasi ke helper
    ACCEPTED --> CANCELLED_BY_HELPER: helper batal, dana dikembalikan penuh
    ON_THE_WAY --> CANCELLED_BY_HELPER: helper batal, dana dikembalikan penuh

    DISPUTED --> COMPLETED: admin putuskan berpihak pada helper
    DISPUTED --> REFUNDED: admin putuskan berpihak pada client

    EXPIRED --> [*]
    COMPLETED --> [*]
    REFUNDED --> [*]
    CANCELLED_BY_CLIENT --> [*]
    CANCELLED_BY_HELPER --> [*]
```

Aturan yang mengikat untuk BE dan Mobile: transisi hanya sah kalau tergambar pada diagram ini, setiap transisi wajib dicatat di tabel `order_status_history` beserta pelaku dan waktu, dan tidak ada status yang boleh dilewati. Mobile tidak boleh menebak status berikutnya, harus selalu mengikuti status dari server.

Catatan revisi 28 Agustus 2026, `DEC-10`. Transisi `AWAITING_CONFIRMATION --> DISPUTED` hanya berlaku untuk pesanan berkategori Delivery, sesuai FR-ORD-018 yang sudah direvisi. Untuk kategori lain, `AWAITING_CONFIRMATION` hanya punya dua jalan keluar, `COMPLETED` lewat konfirmasi client atau lewat batas waktu, tidak ada jalur sengketa. Ini konsekuensi yang perlu disadari tim, client pada kategori selain Delivery kehilangan jalur keberatan formal kalau merasa pekerjaan tidak beres, satu satunya opsi mereka menahan diri tidak menekan konfirmasi dan membiarkan sistem yang mengonfirmasi otomatis setelah 24 jam, yang berarti dana tetap cair ke helper.

**Pertanyaan terbuka yang belum terjawab**, transisi `PRICE_ADJUSTMENT --> DISPUTED` pada bagian ini awalnya dirancang khusus untuk kategori Food run, dipicu saat client menolak pengajuan penyesuaian nilai talangan (lihat bagian enam). Kalau kanal sengketa sekarang dibatasi hanya Delivery, jalur ini jadi tidak konsisten, Food run tetap punya cara masuk ke status `DISPUTED` padahal bukan kategori yang disepakati. Tim perlu memutuskan salah satu, apakah kanal sengketa sebenarnya dimaksudkan untuk Delivery dan Food run sekaligus karena sama sama melibatkan barang fisik, atau penolakan penyesuaian talangan pada Food run perlu jalur penyelesaian lain yang bukan `DISPUTED`, misalnya otomatis dibatalkan sebagian. Sampai ada jawaban, saya biarkan transisi ini apa adanya dan menandainya sebagai inkonsistensi yang diketahui, bukan diam diam saya putuskan sendiri.

## 5. Aturan pembatalan dan kompensasi

Ini bagian yang paling sering diperdebatkan, jadi angkanya saya usulkan eksplisit supaya bisa didebat dengan jelas dan bukan mengambang.

| Status saat dibatalkan | Pihak pembatal | Dana client | Kompensasi helper | Catatan |
| --- | --- | --- | --- | --- |
| SEARCHING | Client | Kembali penuh | Tidak ada | Belum ada helper yang dirugikan |
| ACCEPTED, kurang dari 120 detik sejak diterima | Client | Kembali penuh | Tidak ada | Masa tenggang niat baik |
| ACCEPTED, lebih dari 120 detik | Client | Kembali dikurangi biaya batal Rp 5.000 | Rp 5.000 | Helper sudah menolak tawaran lain |
| ON_THE_WAY | Client | Kembali dikurangi 30 persen dari tarif dasar | 30 persen tarif dasar | Helper sudah menempuh jarak |
| IN_PROGRESS | Client | Tidak bisa dibatalkan, harus lewat sengketa (khusus Delivery, lihat catatan bagian 4) | Ditentukan admin | Mencegah penyalahgunaan. Untuk kategori selain Delivery, jalur ini belum punya jawaban karena kanal sengketa dibatasi DEC-10, masuk daftar pertanyaan terbuka bagian empat |
| ACCEPTED atau ON_THE_WAY | Helper | Kembali penuh | Tidak ada, dan tercatat sebagai pembatalan helper | Tingkat pembatalan tinggi menurunkan prioritas helper di antrean tawaran |
| ON_THE_WAY, kategori Food run setelah barang dibeli | Helper | Kembali penuh dikurangi nilai talangan yang sudah terbukti | Nilai talangan | Butuh bukti struk |

Angka pada tabel ini berstatus `ASUMSI`. Tugas kita minggu depan adalah menyepakatinya di rapat tim, lalu menaikkan statusnya menjadi `CONFIRMED` dan menurunkannya ke `FR-ORD-011`.

## 6. Kasus khusus talangan pada Food run

Kategori Food run membuat arah uang menjadi benar benar dua arah, dan ini yang membedakan aplikasi ini dari aplikasi jasa biasa. Helper mengeluarkan uang sendiri untuk membeli barang, lalu uang itu harus kembali padanya bersama upah jasa.

Masalahnya, harga sesungguhnya sering berbeda dari estimasi. Mie ayam yang diperkirakan Rp 20.000 bisa jadi Rp 23.000. Kalau selisih ini tidak diatur, helper menanggung kerugian atau client merasa ditipu.

Usulan mekanisme. Client menetapkan batas talangan maksimal saat membuat pesanan, misalnya Rp 100.000. Sistem menahan dana sebesar upah jasa ditambah batas talangan tersebut, bukan hanya estimasi. Helper membeli, mengunggah foto struk, dan mengajukan nominal sesungguhnya. Kalau nominalnya di bawah atau sama dengan batas, sistem langsung menyesuaikan dan kelebihan penahanan dikembalikan tanpa perlu persetujuan client. Kalau melebihi batas, pesanan masuk ke status `PRICE_ADJUSTMENT` dan client harus menyetujui secara eksplisit sebelum helper melanjutkan.

Batas talangan maksimal juga sebaiknya dikaitkan dengan tingkat kepercayaan helper. Helper baru dengan kurang dari sepuluh pesanan selesai dibatasi Rp 50.000, sementara helper dengan rating di atas 4,5 dan lebih dari lima puluh pesanan selesai boleh sampai Rp 300.000. Ini melindungi client dari helper yang belum terbukti sekaligus memberi jalur naik kelas yang jelas bagi helper, sekali lagi sejalan dengan tema pekerjaan layak.

## 7. Daftar invarian sistem

Invarian adalah pernyataan yang harus selalu benar. Kalau salah satunya pernah salah, ada bug serius. Daftar ini saya serahkan ke BE sebagai bahan pengujian dan ke QA sebagai bahan skenario negatif.

| ID | Invarian |
| --- | --- |
| INV-01 | Saldo tersedia pengguna tidak pernah bernilai negatif |
| INV-02 | Jumlah saldo tersedia ditambah saldo tertahan selalu sama dengan hasil penjumlahan seluruh mutasi ledger pengguna tersebut |
| INV-03 | Satu pesanan hanya boleh punya satu penahanan dana yang aktif |
| INV-04 | Dana yang sudah dilepas ke helper tidak bisa dilepas ulang meskipun permintaan dikirim berkali kali |
| INV-05 | `client_id` dan `helper_id` pada satu pesanan tidak boleh sama |
| INV-06 | Satu helper hanya boleh punya satu pesanan berstatus antara ACCEPTED sampai AWAITING_CONFIRMATION |
| INV-07 | Setiap perubahan status pesanan menghasilkan tepat satu baris riwayat status |
| INV-08 | Penilaian hanya boleh dibuat untuk pesanan berstatus COMPLETED dan maksimal satu penilaian per pesanan, dari client ke helper (direvisi 28 Agu 2026, sebelumnya "per pihak" karena masih dua arah, sekarang satu arah saja sesuai DEC-09) |
| INV-09 | Total dana yang dilepas ke helper ditambah potongan platform selalu sama dengan dana yang ditahan untuk pesanan itu |
| INV-10 | Tidak ada pesanan berstatus ACCEPTED atau setelahnya tanpa catatan penahanan dana yang bersesuaian |

## 8. Edge case yang harus punya jawaban

| Kasus | Perilaku yang diharapkan |
| --- | --- |
| Dua helper menekan terima pada detik yang hampir bersamaan | Penguncian tingkat basis data pada baris pesanan, helper kedua menerima kode konflik dan pesan pesanan sudah diambil |
| Client menekan bayar dua kali karena jaringan lambat | Idempotency key sama menghasilkan satu transaksi, permintaan kedua mengembalikan hasil yang pertama |
| Saldo client habis dipakai pesanan lain di antara pengecekan dan penahanan | Penahanan dilakukan dalam satu transaksi basis data dengan pengecekan saldo, bukan dua langkah terpisah |
| Aplikasi helper mati saat status ON_THE_WAY | Status tetap di server, dipulihkan saat aplikasi dibuka lagi, tidak ada perubahan status otomatis dari sisi klien |
| Helper menandai selesai padahal belum mengerjakan | Client menolak konfirmasi dan mengajukan sengketa, dana tetap tertahan sampai keputusan admin |
| Client tidak pernah membuka aplikasi lagi setelah pekerjaan selesai | Konfirmasi otomatis setelah 24 jam, helper tetap dibayar |
| Helper membatalkan setelah membeli barang pada Food run | Dana talangan yang terbukti struk tetap dibayarkan, upah jasa tidak dibayarkan, tingkat pembatalan helper naik |
| Pengguna menghapus akun sementara masih ada pesanan berjalan | Penghapusan ditolak sampai seluruh pesanan mencapai status akhir dan saldo tertahan nol |
| Client mengisi saldo saat pesanan sedang menunggu karena saldo kurang | Sistem mencoba ulang penahanan dana secara otomatis satu kali setelah saldo masuk |
| Jam pada perangkat pengguna dimundurkan untuk mengakali batas waktu | Seluruh perhitungan waktu memakai waktu server, perangkat hanya menampilkan |

## 9. Status pertanyaan terbuka setelah sesi 19 Agustus 2026

Update 28 Agustus 2026: seluruh lima pertanyaan di bagian ini sekarang tuntas terjawab. Status masing masing berikut.

Pertama, soal dompet simulasi atau gerbang pembayaran sungguhan, sudah diputuskan, `DEC-04`. Dompet berjalan simulasi, integrasi sungguhan dicatat sebagai arah pengembangan lanjutan di luar lingkup lab.

Kedua, soal besar potongan platform, **sudah dikonfirmasi 28 Agustus 2026**. Komisi platform tetap 10 persen ditanggung helper, `DEC-08` naik status jadi Disetujui. Penjelasan lengkap alasannya ada di `09_dokumentasi-keputusan-minggu-1.md`.

Ketiga, soal mode pencocokan pesanan, sudah diputuskan dan ternyata bukan sekadar gabungan broadcast dan direct seperti opsi yang saya tawarkan sebelumnya. Tim memilih model tawar harga dua arah, `DEC-05`, di mana client mengajukan harga estimasi dan beberapa helper mengajukan tawaran masing masing untuk dipilih. Ini mengubah titik penahanan dana, lihat bagian tiga yang sudah direvisi, dan mengubah state machine di bagian empat.

Keempat, soal pelacakan lokasi sungguhan atau simulasi status, sudah diputuskan, `DEC-06`, dan **dikonfirmasi ulang 28 Agustus 2026 lewat UI/UX, tidak ada perubahan**. Untuk saat ini memakai perubahan status, bukan lokasi GPS langsung. Layar pelacakan pada prototipe yang menampilkan peta dengan pergerakan langsung tetap perlu digambar ulang sebagai visualisasi tahapan status, ini sudah dikonfirmasi jadi pekerjaan UI/UX, belum ada laporan hasil gambarnya masuk ke workspace.

Kelima, soal siapa admin operasional dan mekanisme aksesnya, **sudah tuntas 28 Agustus 2026**. Mentor lab berperan sebagai admin, dan mengakses lewat panel admin sungguhan di dalam sistem, bukan proses manual. `DEC-07` naik status jadi Disetujui penuh. Konsekuensinya, modul ADM baru sudah ditambahkan ke `02_requirement-master-list.md`, mencakup login admin terpisah, peninjauan verifikasi, keputusan sengketa, dan ringkasan komisi. Ini pekerjaan baru yang perlu masuk perhitungan waktu BE, bukan modul kecil, karena butuh jalur autentikasi terpisah dari Client dan Helper.
