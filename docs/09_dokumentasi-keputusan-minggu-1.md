# Dokumentasi Keputusan Minggu 1 dan Dampaknya

Status dokumen: `REVIEW` v0.1, tanggal 19 Agustus 2026. Dokumen ini mencatat lima keputusan dari sesi sinkronisasi seluruh divisi, menjelaskan dampaknya ke artefak lain yang sudah dibuat, dan menandai bagian mana yang sudah saya perbarui langsung serta bagian mana yang masih menunggu jawaban lanjutan dari tim.

## 1. Ringkasan lima keputusan

| No | Keputusan tim | Status di decision log |
| --- | --- | --- |
| 1 | Saldo simulasi dulu, integrasi payment sungguhan jadi arah pengembangan lanjutan | `DEC-04`, disetujui |
| 2 | Komisi harus terhitung jelas untuk tim, stakeholder, dan pengguna, angka belum ditetapkan | `DEC-08`, usulan menunggu persetujuan |
| 3 | Model tawar harga dua arah, client kasih estimasi, helper kasih tawaran beragam, client pilih | `DEC-05`, disetujui |
| 4 | Pelacakan pakai perubahan status dulu, bukan GPS langsung | `DEC-06`, disetujui |
| 5 | Mentor lab berperan sebagai admin/stakeholder untuk verifikasi dan sengketa | `DEC-07`, disetujui sebagian |

## 2. Keputusan 1, dompet simulasi

Ini yang paling sederhana dampaknya. Saya sudah menambahkan catatan lingkup eksplisit di awal bagian modul WLT pada `02_requirement-master-list.md`, menyatakan bahwa seluruh transaksi berjalan sebagai saldo simulasi dan integrasi payment gateway sungguhan seperti Midtrans atau Xendit dicatat sebagai arah pengembangan lanjutan di luar lingkup lab. Catatan yang sama perlu masuk ke bagian Batasan Desain dan Implementasi pada SRS supaya penguji atau asisten lab tidak salah ekspektasi mengira aplikasi memproses uang sungguhan.

Tidak ada perubahan struktur data karena dari awal saya sudah merancang kolom saldo sebagai bilangan bulat internal, bukan terintegrasi ke gateway manapun.

## 3. Keputusan 2, komisi platform

Ini yang belum tuntas, dan saya perlu jujur soal itu. Tim menyepakati prinsipnya, komisi harus terhitung jelas untuk tiga kepentingan berbeda, tapi belum menyepakati angkanya. Saya coba uraikan tiga kepentingan itu dulu supaya rekomendasi angka saya punya alasan yang bisa diperdebatkan, bukan sekadar tebakan.

Untuk kepentingan tim, komisi ini fungsinya menunjukkan bahwa sistem punya model bisnis yang masuk akal, bukan sekadar aplikasi tanpa pendapatan. Untuk lab, ini penting sebagai bukti pemikiran end to end, bukan untuk pendapatan sungguhan karena dompetnya simulasi.

Untuk kepentingan stakeholder, dalam hal ini termasuk mentor sebagai admin, komisi perlu terlihat jelas di level agregat, bukan cuma di level transaksi satu per satu. Ini menyiratkan mungkin dibutuhkan semacam ringkasan total komisi yang terkumpul, bukan cuma rincian per pesanan yang sudah ada di `FR-WLT-004`. Saya belum menambahkan requirement untuk ringkasan ini karena tergantung jawaban keputusan 5 di bawah, apakah ada panel admin sungguhan atau tidak.

Untuk kepentingan pengguna, khususnya helper, komisi harus terasa wajar dan transparan supaya sejalan dengan tema SDG 8 yang kita angkat. Ini yang jadi pertimbangan utama saya menentukan angka.

Rekomendasi saya, komisi 10 persen, dipotong dari nominal yang diterima helper, bukan ditambahkan ke tagihan client. Tiga alasan angka ini. Pertama, dibandingkan platform ojek daring yang komisinya bisa 20 sampai 25 persen, angka 10 persen membuat cerita "pekerjaan layak" kita lebih kuat, karena helper menerima porsi lebih besar dari hasil kerjanya. Kedua, dipotong dari sisi helper bukan ditambahkan ke client membuat rumus harga di sisi client tetap sederhana, apa yang client lihat sebagai total tawaran itu yang dia bayar, tidak ada biaya tersembunyi tambahan. Ketiga, angka bulat 10 persen gampang dijelaskan saat presentasi ke asisten lab dibanding angka pecahan yang terlihat sok presisi padahal cuma tebakan.

Saya sudah menerapkan angka ini di seluruh contoh perhitungan yang saya perbarui, termasuk sequence diagram dan contoh respons API. Tapi ini masih berstatus usulan, `DEC-08` belum naik ke disetujui. Kalau tim mau angka lain, beri tahu saya dan saya sapukan perubahannya ke seluruh dokumen sekaligus, karena angka ini muncul di banyak tempat dan tidak boleh berbeda beda antar file.

## 4. Keputusan 3, model tawar harga dua arah

Ini keputusan dengan dampak paling besar, jadi saya uraikan agak panjang. Rancangan saya sebelumnya menyebut "gabungkan broadcast dan direct" sebagai jawaban pertanyaan model pencocokan, tapi yang tim putuskan ternyata bukan itu. Yang dimaksud adalah mekanisme tawar menawar sungguhan, mirip pola di platform freelance seperti Upwork, bukan sekadar dua metode pemesanan yang berjalan sendiri sendiri.

Bedanya penting. Rancangan lama saya, "broadcast", tetap punya satu momen di mana helper pertama yang menekan terima langsung dapat pesanan dengan harga yang sudah ditentukan client. Rancangan baru dari tim menambahkan lapisan negosiasi, semua helper yang berminat mengajukan angka masing masing, dan client yang punya kendali penuh memilih siapa dengan harga berapa. Ini pergeseran filosofi dari "siapa cepat dia dapat" menjadi "client yang menyeleksi", dan itu konsekuensinya menyentuh titik paling sensitif dalam desain saya, yaitu kapan dana ditahan.

Saya sudah memperbarui lima artefak untuk mencerminkan model ini secara konsisten.

Di `02_requirement-master-list.md`, FR-ORD-003 sekarang menjelaskan siar pesanan dengan tawaran terbuka, ditambah FR-ORD-003B untuk menampilkan daftar tawaran, FR-ORD-003C untuk pemilihan oleh client, dan FR-ORD-006B untuk konfirmasi ulang helper yang terpilih. Saya sengaja menambah langkah konfirmasi ulang ini, karena tanpanya ada risiko client memilih helper yang ternyata di detik yang sama sudah diambil pesanan lain.

Di `03_use-case-inventory.md`, use case UC-ORD-02 yang tadinya "menerima atau menolak tawaran" sekarang terpecah jadi UC-ORD-02 mengajukan tawaran, UC-ORD-02B memilih tawaran, dan UC-ORD-02C konfirmasi ketersediaan. Skenario lengkap Given When Then setara untuk ketiganya sudah saya tulis ulang di bagian enam file itu.

Di `04_dual-role-transaction-analysis.md`, bagian tiga soal kapan uang berpindah saya tulis ulang total. Titik penahanan dana sekarang adalah saat client memilih tawaran dan helper terpilih mengonfirmasi, bukan saat helper menekan terima seperti versi lama. State machine di bagian empat juga saya tambah satu status baru, `pending_confirmation`, yang mewakili jeda antara client memilih dan helper mengonfirmasi.

Di `05_erd-draft.md`, tabel `order_offer` sekarang punya kolom `proposed_price`, karena setiap helper boleh mengajukan angka berbeda. Kolom `order.total_amount` juga saya catat berubah sumbernya, sekarang dihitung dari tawaran yang terkonfirmasi, bukan dari harga estimasi awal client.

Di `06_api-contract-draft.md`, endpoint `POST /orders/{id}/accept` yang lama saya ganti jadi empat endpoint baru, mengajukan tawaran, melihat daftar tawaran, memilih tawaran, dan konfirmasi oleh helper terpilih.

Di `07_acceptance-criteria-gherkin.md`, skenario pengujian untuk penerimaan pesanan saya tulis ulang mengikuti alur baru, termasuk skenario helper terpilih yang tidak merespons dan skenario helper terpilih yang ternyata sudah dapat pesanan lain di saat bersamaan.

Yang belum saya sentuh dan perlu jadi perhatian bersama, aturan pembatalan pada bagian lima `04_dual-role-transaction-analysis.md` masih ditulis dengan asumsi harga sudah ditetapkan client sejak awal. Sekarang harga baru pasti setelah tawaran dikonfirmasi, jadi tabel kompensasi pembatalan itu masih berlaku secara struktur tapi contoh nominalnya perlu ditinjau ulang setelah komisi di keputusan 2 final.

Satu hal lagi yang perlu didiskusikan tim, bukan cuma saya putuskan sendiri. Model tawar harga ini menambah satu langkah interaksi dibanding rancangan lama, client sekarang harus aktif membandingkan dan memilih, bukan cuma menunggu. Ini bagus untuk transparansi tapi berpotensi memperlambat waktu dari pesan sampai dapat helper, terutama kalau tawaran yang masuk sedikit atau lambat. Saya sarankan sesi user flow dengan UI/UX minggu ini juga membahas berapa lama sebaiknya jendela tawaran dibuka, karena 300 detik yang saya tulis di FR-ORD-004 itu masih asumsi lama dan mungkin perlu disesuaikan sekarang ada langkah tambahan bandingkan lalu pilih.

## 5. Keputusan 4, pelacakan berbasis status

Dampaknya lebih sempit dari keputusan 3, tapi tetap penting disampaikan ke UI/UX secepatnya, karena prototipe yang sudah ada menunjukkan peta dengan pergerakan penanda secara langsung. Kalau tracking sekarang berbasis perubahan status, bukan lokasi GPS sungguhan, layar itu perlu digambar ulang sebagai visualisasi tahapan, contohnya garis progres dengan titik titik status seperti diterima, menuju lokasi, tiba, dan selesai, bukan peta yang bergerak real time.

Saya sudah menandai keputusan ini selesai di bagian pertanyaan terbuka `04_dual-role-transaction-analysis.md`. Belum ada perubahan pada FR terkait karena FR-ORD-008 dan FR-ORD-009 memang sudah ditulis netral soal cara pelacakannya, tidak menjanjikan GPS sungguhan secara eksplisit. Yang perlu berubah adalah ekspektasi visual di sesi UI/UX besok.

## 6. Keputusan 5, mentor sebagai admin

Ini keputusan yang menjawab sebagian pertanyaan tapi memunculkan pertanyaan baru. Yang terjawab adalah siapa orangnya, mentor lab. Yang belum terjawab adalah bagaimana dia mengaksesnya.

Ada dua kemungkinan dengan beban kerja sangat berbeda. Kemungkinan pertama, dibangun panel admin sungguhan di dalam sistem, mentor login dengan akun khusus, melihat daftar pengajuan verifikasi dan sengketa, lalu memutuskan langsung di aplikasi. Ini menambah modul baru yang belum ada di lingkup manapun sekarang, perlu FR baru, kemungkinan perlu web admin terpisah karena tidak lazim panel admin dibangun sebagai bagian dari aplikasi mobile yang sama dengan yang dipakai client dan helper.

Kemungkinan kedua, prosesnya tetap manual di luar sistem. Pengajuan verifikasi dan sengketa yang masuk cukup diteruskan tim lewat cara sederhana, misalnya spreadsheet atau grup komunikasi, mentor meninjau di situ, dan tim yang menginput hasil keputusannya kembali ke sistem lewat akses developer langsung ke database untuk keperluan lab. Ini jauh lebih ringan tapi kurang representatif sebagai sistem produksi sungguhan.

Saya belum memilih salah satu karena ini keputusan yang sebaiknya datang dari diskusi singkat dengan mentor sendiri, bukan diasumsikan tim. Pertanyaan konkret yang bisa diajukan ke mentor, apakah beliau berharap bisa login dan menyetujui sendiri lewat aplikasi, atau cukup diberi tahu lewat laporan dan keputusannya disampaikan balik ke tim untuk diinput. Begitu jawabannya ada, saya bisa langsung menambah modul ADM kalau memang dibutuhkan, atau menegaskan di SRS bahwa admin adalah proses manual di luar sistem sebagai bagian dari batasan implementasi.

## 7. Yang masih terbuka untuk tindak lanjut

Tiga hal ini perlu jawaban sebelum saya bisa mengunci ERD dan kontrak API sepenuhnya di sesi Backend.

Angka komisi final dari keputusan 2, karena angka ini muncul di banyak contoh perhitungan dan sebaiknya cuma disapukan sekali setelah pasti, bukan berkali kali tiap kali tim ganti pikiran.

Durasi jendela tawaran yang mungkin perlu disesuaikan karena model tawar harga menambah satu langkah dibanding rancangan lama, ini dibahas di sesi UI/UX.

Mekanisme akses admin dari keputusan 5, karena ini menentukan apakah ada modul ADM baru yang perlu masuk requirement master list dan ERD, atau cukup dicatat sebagai batasan implementasi di SRS.
