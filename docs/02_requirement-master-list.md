# Requirement Master List

Status dokumen: `REVIEW` v0.1. Ini satu satunya tempat FR dan NFR hidup. Tabel di SRS Word menyalin dari sini.

Keterangan kolom sumber: `PROTO` berarti terlihat langsung di prototipe UI, `TURUNAN` berarti konsekuensi logis dari fitur yang terlihat, `ASUMSI` berarti belum ada buktinya dan wajib divalidasi ke tim atau Mentor sebelum naik ke `CONFIRMED`.

Prioritas memakai MoSCoW. Untuk durasi lab, target realistis adalah menyelesaikan seluruh `Must Have` dan sebagian `Should Have`.

## 1. Modul AUTH, akun dan autentikasi

| Kode | Functional Requirement | Prioritas | Sumber | Status |
| --- | --- | --- | --- | --- |
| FR-AUTH-001 | Sistem harus menampilkan form registrasi berisi nama lengkap, nomor telepon, email, dan kata sandi | Must | TURUNAN | DRAFT |
| FR-AUTH-002 | Sistem harus memverifikasi nomor telepon melalui kode OTP enam digit yang kedaluwarsa dalam 300 detik | Must | ASUMSI | DRAFT |
| FR-AUTH-003 | Sistem harus menolak registrasi jika nomor telepon atau email sudah terdaftar dan menampilkan pesan yang membedakan keduanya | Must | TURUNAN | DRAFT |
| FR-AUTH-004 | Sistem harus menerima login dengan kombinasi nomor telepon atau email dan kata sandi | Must | TURUNAN | DRAFT |
| FR-AUTH-005 | Sistem harus mengunci percobaan login selama 900 detik setelah lima kegagalan berturut turut dari satu akun | Should | ASUMSI | DRAFT |
| FR-AUTH-006 | Sistem harus menyediakan pemulihan kata sandi melalui OTP ke nomor telepon terdaftar | Should | ASUMSI | DRAFT |
| FR-AUTH-007 | Sistem harus menjaga sesi login dengan access token berumur 60 menit dan refresh token berumur 30 hari | Must | TURUNAN | DRAFT |
| FR-AUTH-008 | Sistem harus menampilkan tiga layar onboarding pengenalan sebelum registrasi dengan opsi lewati di setiap layar | Must | PROTO | DRAFT |

## 2. Modul VER, verifikasi identitas

| Kode | Functional Requirement | Prioritas | Sumber | Status |
| --- | --- | --- | --- | --- |
| FR-VER-001 | Sistem harus menampilkan lencana ID verified pada profil pengguna yang identitasnya sudah lolos verifikasi | Must | PROTO | DRAFT |
| FR-VER-002 | Sistem harus meminta unggahan foto kartu identitas dan swafoto pemegang kartu saat pengguna mendaftar menjadi helper | Must | TURUNAN | DRAFT |
| FR-VER-003 | Sistem harus menyimpan status verifikasi dengan nilai belum diajukan, sedang ditinjau, disetujui, atau ditolak beserta alasan penolakan | Must | TURUNAN | DRAFT |
| FR-VER-004 | Sistem harus melarang akun yang belum berstatus disetujui untuk menerima pesanan apa pun | Must | TURUNAN | DRAFT |
| FR-VER-005 | Sistem harus menampilkan lencana helper terverifikasi pada kartu helper di daftar pencarian | Must | PROTO | DRAFT |
| FR-VER-006 | Sistem harus menahan pengajuan ulang verifikasi selama 2 menit setelah pengajuan sebelumnya ditolak | Must | TURUNAN, BARU 6 Sep 2026 hasil sesi BE. **Catatan SA**: durasi 2 menit perlu dikonfirmasi ulang, terasa sangat pendek untuk siklus peninjauan manual admin, kemungkinan yang dimaksud satuan waktu lain | DRAFT |

## 3. Modul PRF, profil dan alamat

| Kode | Functional Requirement | Prioritas | Sumber | Status |
| --- | --- | --- | --- | --- |
| FR-PRF-001 | Sistem harus menampilkan halaman profil berisi nama, kota, tanggal bergabung, dan status verifikasi | Must | PROTO | DRAFT |
| FR-PRF-002 | Sistem harus mengizinkan pengguna menyimpan maksimal sepuluh alamat dengan label, koordinat, dan catatan patokan | Must | TURUNAN, direvisi dari PROTO 6 Sep 2026, usulan SA meratifikasi angka ini sebagai keputusan UX yang disengaja, bukan kebetulan mengikuti prototipe, menunggu konfirmasi tim | DRAFT |
| FR-PRF-003 | Sistem harus menandai satu alamat sebagai alamat utama yang terpilih otomatis saat membuat pesanan | Should | TURUNAN | DRAFT |
| FR-PRF-004 | Sistem harus menampilkan lokasi aktif pengguna pada bagian atas beranda | Must | PROTO | DRAFT |
| FR-PRF-005 | Sistem harus menyediakan menu ubah profil untuk nama, foto, dan nomor telepon dengan verifikasi OTP ulang saat nomor diubah | Should | TURUNAN | DRAFT |

## 4. Modul HLP, pencarian dan pendaftaran helper

| Kode | Functional Requirement | Prioritas | Sumber | Status |
| --- | --- | --- | --- | --- |
| FR-HLP-001 | Sistem harus menampilkan enam kategori layanan pada beranda yaitu Food run, Delivery, Moving, Personal, Household, dan Laundry | Must | PROTO | DRAFT |
| FR-HLP-002 | Sistem harus menampilkan daftar helper yang tersedia beserta nama, rating rata rata, jumlah ulasan, jarak dalam kilometer, tarif per jam, dan tag keahlian | Must | PROTO | DRAFT |
| FR-HLP-003 | Sistem harus menyediakan penyaringan daftar helper berdasarkan kategori layanan | Must | PROTO | DRAFT |
| FR-HLP-004 | Sistem harus menyediakan pengurutan daftar helper berdasarkan jarak terdekat, rating tertinggi, dan tarif terendah | Must | PROTO | DRAFT |
| FR-HLP-005 | Sistem harus membatasi daftar helper pada radius maksimal 10 kilometer dari lokasi pesanan | Should | ASUMSI | DRAFT |
| FR-HLP-006 | Sistem harus menampilkan jumlah helper yang tersedia di sekitar lokasi pengguna | Must | PROTO | DRAFT |
| FR-HLP-007 | Sistem harus menyediakan menu daftar menjadi helper pada halaman profil | Must | PROTO | DRAFT |
| FR-HLP-008 | Sistem harus meminta calon helper memilih minimal satu dan maksimal enam kategori layanan yang dikuasai | Must | TURUNAN | DRAFT |
| FR-HLP-009 | Sistem harus menyediakan sakelar ketersediaan bagi helper untuk berhenti menerima tawaran pesanan | Must | TURUNAN | DRAFT |
| FR-HLP-010 | Sistem harus menampilkan halaman detail helper berisi profil, ulasan, dan riwayat jumlah pekerjaan selesai | Should | TURUNAN | DRAFT |

## 5. Modul ORD, siklus hidup pesanan

Modul ini adalah inti sistem. Detail transisi status ada di `04_dual-role-transaction-analysis.md`.

| Kode | Functional Requirement | Prioritas | Sumber | Status |
| --- | --- | --- | --- | --- |
| FR-ORD-001 | Sistem harus menyediakan form pembuatan pesanan berisi kategori, deskripsi tugas, alamat penjemputan, alamat tujuan, waktu pelaksanaan, dan harga estimasi yang diajukan client | Must | TURUNAN | DRAFT |
| FR-ORD-002 | Sistem harus menghitung rentang biaya acuan sebelum pesanan dikirim, terdiri atas tarif dasar, biaya jarak, biaya layanan, dan potongan voucher, sebagai panduan bagi client menentukan harga estimasi dan bagi helper menyusun tawaran. Usulan SA 6 Sep 2026, `service_fee` dihitung flat sama dengan `SERVICE_CATEGORY.base_fee`, tidak dikalikan durasi, karena angka ini cuma panduan, harga final tetap dari tawaran bebas helper (DEC-05). Menunggu konfirmasi tim | Must | TURUNAN | DRAFT |
| FR-ORD-003 | Sistem harus menyiarkan pesanan ke helper yang memenuhi syarat kategori dan radius, dan mengizinkan setiap helper yang berminat mengajukan tawaran harga masing masing berbeda dari harga estimasi client | Must | TURUNAN, DIREVISI 19 Agu 2026 (DEC-05) | DRAFT |
| FR-ORD-003B | Sistem harus menampilkan seluruh tawaran harga yang masuk kepada client, masing masing beserta profil helper, rating, dan nominal yang diajukan, agar client dapat membandingkan sebelum memilih | Must | TURUNAN, BARU (DEC-05) | DRAFT |
| FR-ORD-003C | Sistem harus mengizinkan client memilih satu tawaran dari daftar yang masuk, dan pilihan ini yang memicu penahanan dana serta penolakan otomatis terhadap tawaran lain | Must | TURUNAN, BARU (DEC-05) | DRAFT |
| FR-ORD-003D | Sistem harus mendukung jalur pemesanan langsung ke satu helper tertentu tanpa melalui tahap tawaran, ketika client memilih helper langsung dari halaman cari helper | Should | TURUNAN | DRAFT |
| FR-ORD-004 | Sistem harus menutup jendela penawaran 300 detik setelah pesanan disiarkan, dan mengizinkan client memilih dari tawaran yang sudah masuk meskipun jendela belum ditutup penuh jika sudah ada minimal satu tawaran | Must | ASUMSI, DIVALIDASI 28 Agu 2026 oleh UI/UX, nilai 300 detik tidak berubah | REVIEW |
| FR-ORD-005 | Sistem harus membatalkan pesanan secara otomatis jika tidak ada satu pun tawaran masuk sampai jendela penawaran berakhir, dan mengembalikan dana tertahan secara penuh jika ada | Must | ASUMSI | DRAFT |
| FR-ORD-006 | Sistem harus menampilkan kepada helper nominal bersih yang akan diterima berdasarkan harga yang mereka ajukan sendiri, dihitung sebelum tawaran dikirim | Must | TURUNAN, DIREVISI 19 Agu 2026 (DEC-05) | DRAFT |
| FR-ORD-006B | Sistem harus meminta konfirmasi ulang dari helper terpilih dalam 60 detik setelah client memilih tawarannya, sebelum dana benar benar ditahan, untuk mengantisipasi helper yang sudah tidak tersedia lagi | Must | TURUNAN, BARU (DEC-05) | DRAFT |
| FR-ORD-007 | Sistem harus menampilkan status pesanan berjalan pada beranda client dalam bentuk kartu ringkas berisi nama helper, aktivitas, estimasi waktu, dan nomor pesanan | Must | PROTO | DRAFT |
| FR-ORD-008 | Sistem harus menampilkan halaman pelacakan berisi peta, posisi helper, estimasi waktu tiba, tahapan progres, identitas helper, nomor pesanan, dan total biaya | Must | PROTO | DRAFT |
| FR-ORD-009 | Sistem harus menampilkan tahapan progres pesanan minimal empat tahap yaitu diterima, menuju lokasi, sedang dikerjakan, dan selesai | Must | PROTO | DRAFT |
| FR-ORD-010 | Sistem harus menyediakan tombol selesaikan pesanan bagi client sebagai konfirmasi pekerjaan diterima | Must | PROTO | DRAFT |
| FR-ORD-011 | Sistem harus menyediakan pembatalan pesanan dengan aturan biaya pembatalan yang berbeda menurut status pesanan saat dibatalkan | Must | PROTO | DRAFT |
| FR-ORD-012 | Sistem harus mengonfirmasi pesanan selesai secara otomatis dalam 24 jam setelah helper menandai pekerjaan selesai jika client tidak merespons | Must | ASUMSI | DRAFT |
| FR-ORD-013 | Sistem harus meminta helper mengunggah foto bukti penyelesaian untuk kategori Food run, Delivery, dan Laundry | Should | TURUNAN | DRAFT |
| FR-ORD-014 | Sistem harus menyediakan pengajuan penyesuaian harga oleh helper untuk kategori Food run berdasarkan struk pembelian, yang wajib disetujui client sebelum berlaku | Must | TURUNAN | DRAFT |
| FR-ORD-015 | Sistem harus menyimpan riwayat pesanan client dan helper beserta status akhir dan rincian biaya | Must | PROTO | DRAFT |
| FR-ORD-016 | Sistem harus melarang seorang pengguna menerima pesanan yang dibuat oleh dirinya sendiri | Must | TURUNAN | DRAFT |
| FR-ORD-017 | Sistem harus membatasi jumlah pesanan berstatus aktif menjadi maksimal satu untuk setiap helper pada satu waktu | Should | ASUMSI | DRAFT |
| FR-ORD-018 | Sistem harus menyediakan kanal sengketa bagi client dan helper dalam 24 jam setelah pesanan ditandai selesai, khusus untuk pesanan berkategori Delivery. Kategori lain tidak memiliki jalur sengketa formal pada versi ini | Should | TURUNAN, DIREVISI 28 Agu 2026 (DEC-10) | DRAFT |

## 6. Modul WLT, dompet dan pembayaran

Catatan lingkup, hasil keputusan tim 19 Agustus 2026, `DEC-04`. Seluruh transaksi pada modul ini berjalan sebagai saldo simulasi, tidak ada uang sungguhan yang berpindah. Integrasi payment gateway sungguhan seperti Midtrans atau Xendit dicatat sebagai arah pengembangan lanjutan, tidak masuk lingkup pengerjaan lab saat ini, dan disebutkan eksplisit di bagian batasan SRS supaya tidak jadi ekspektasi keliru saat presentasi.

Catatan komisi, `DEC-08`, dikonfirmasi 28 Agustus 2026, komisi platform ditetapkan 10 persen, dipotong dari nominal yang diterima helper, bukan ditambahkan ke tagihan client. Penjelasan lengkap alasan angka ini ada di `09_dokumentasi-keputusan-minggu-1.md`.

| Kode | Functional Requirement | Prioritas | Sumber | Status |
| --- | --- | --- | --- | --- |
| FR-WLT-001 | Sistem harus menampilkan saldo TD-Wallet pada halaman profil beserta tombol isi saldo dan riwayat | Must | PROTO | DRAFT |
| FR-WLT-002 | Sistem harus menahan dana sebesar total biaya pesanan saat helper menerima pesanan dan menolak pesanan jika saldo client tidak mencukupi | Must | TURUNAN | DRAFT |
| FR-WLT-003 | Sistem harus melepas dana tertahan menjadi saldo helper paling lambat lima detik setelah pesanan berstatus selesai | Must | TURUNAN | DRAFT |
| FR-WLT-004 | Sistem harus menampilkan rincian potongan platform pada setiap transaksi helper | Must | TURUNAN | DRAFT |
| FR-WLT-005 | Sistem harus menampilkan riwayat mutasi saldo berisi tanggal, jenis transaksi, nominal, nomor pesanan terkait, dan saldo akhir | Must | PROTO | DRAFT |
| FR-WLT-006 | Sistem harus menyediakan pengisian saldo dengan nominal minimal sepuluh ribu rupiah | Must | PROTO | DRAFT |
| FR-WLT-007 | Sistem harus menyediakan penarikan saldo helper dengan jadwal pencairan mingguan | Should | PROTO | DRAFT |
| FR-WLT-008 | Sistem harus mencegah saldo bernilai negatif pada kondisi apa pun | Must | TURUNAN | DRAFT |
| FR-WLT-009 | Sistem harus menolak permintaan transaksi berulang dengan idempotency key yang sama dan mengembalikan hasil transaksi pertama | Must | TURUNAN | DRAFT |
| FR-WLT-010 | Sistem harus menampilkan voucher yang dimiliki pengguna beserta syarat dan tanggal kedaluwarsa | Should | PROTO | DRAFT |
| FR-WLT-011 | Sistem harus menerapkan voucher potongan pada perhitungan biaya sebelum dana ditahan | Should | PROTO | DRAFT |

## 7. Modul CHT, percakapan

| Kode | Functional Requirement | Prioritas | Sumber | Status |
| --- | --- | --- | --- | --- |
| FR-CHT-001 | Sistem harus menyediakan ruang percakapan antara client dan helper yang terikat pada satu pesanan | Must | PROTO | DRAFT |
| FR-CHT-002 | Sistem harus menampilkan daftar percakapan berisi nama lawan bicara, cuplikan pesan terakhir, waktu, dan penanda pesan belum dibaca | Must | PROTO | DRAFT |
| FR-CHT-003 | Sistem harus menyediakan balasan cepat berupa frasa siap pakai untuk mempercepat komunikasi | Should | PROTO | DRAFT |
| FR-CHT-004 | Sistem harus menutup ruang percakapan tujuh hari setelah pesanan selesai dan menjadikannya hanya bisa dibaca | Could | ASUMSI | DRAFT |
| FR-CHT-005 | Sistem harus menyediakan tombol panggilan telepon ke helper pada halaman pelacakan | Should | PROTO | DRAFT |

## 8. Modul RTG, penilaian satu arah

Catatan revisi 28 Agustus 2026, `DEC-09`. Modul ini semula bernama "penilaian dua arah". Hasil diskusi dengan UI/UX, penilaian balik dari Helper ke Client dihapus dari lingkup, bukan sekadar digabung ke layar lain. Penilaian sekarang satu arah, hanya Client menilai Helper, dan langsung terlihat tanpa mekanisme tunda atau sembunyikan.

| Kode | Functional Requirement | Prioritas | Sumber | Status |
| --- | --- | --- | --- | --- |
| FR-RTG-001 | Sistem harus meminta client memberi penilaian satu sampai lima bintang dan ulasan opsional setelah pesanan selesai | Must | TURUNAN | DRAFT |
| FR-RTG-002 | ~~Sistem harus meminta helper memberi penilaian terhadap client dan menyembunyikan kedua penilaian sampai keduanya mengisi atau sampai lewat 72 jam~~ | Must | TURUNAN | DEPRECATED, dihapus 28 Agu 2026 (DEC-09). Digantikan oleh model satu arah, tidak ada requirement pengganti karena memang tidak ada lagi penilaian dari sisi Helper |
| FR-RTG-003 | Sistem harus menghitung rating rata rata helper dari seluruh penilaian client dan menampilkannya dengan satu angka desimal, ditampilkan langsung tanpa masa tunda | Must | PROTO, DIREVISI 28 Agu 2026 (DEC-09) | DRAFT |
| FR-RTG-004 | Sistem harus menolak penilaian pada pesanan yang berstatus batal | Must | TURUNAN | DRAFT |

## 9. Modul NOT, notifikasi

| Kode | Functional Requirement | Prioritas | Sumber | Status |
| --- | --- | --- | --- | --- |
| FR-NOT-001 | Sistem harus menampilkan lonceng notifikasi dengan penanda jika ada notifikasi belum dibaca | Must | PROTO | DRAFT |
| FR-NOT-002 | Sistem harus mengirim notifikasi pada setiap perubahan status pesanan kepada pihak yang berkepentingan | Must | TURUNAN | DRAFT |
| FR-NOT-003 | Sistem harus mengirim notifikasi tawaran pesanan baru kepada helper yang memenuhi syarat | Must | TURUNAN | DRAFT |
| FR-NOT-004 | Sistem harus mengirim notifikasi mutasi saldo untuk setiap penahanan, pelepasan, dan pengembalian dana | Should | TURUNAN | DRAFT |
| FR-NOT-005 | Sistem harus menyediakan halaman daftar notifikasi dengan penyimpanan riwayat 30 hari terakhir | Should | PROTO | DRAFT |

## 9B. Modul ADM, panel admin

Modul baru, ditambahkan 28 Agustus 2026 mengikuti `DEC-07` yang sudah final, Mentor mengakses lewat panel admin sungguhan di dalam sistem, bukan proses manual. Ini menambah lingkup baru yang sebelumnya tidak ada di manapun pada workspace, jadi seluruh isi modul ini berstatus `DRAFT` dan `ASUMSI` sampai ditinjau ulang bersama BE, karena rancangannya baru pertama kali ditulis di sini.

Cakupan modul ini mencakup verifikasi identitas Helper, penyelesaian sengketa, ringkasan agregat komisi platform, dan sejak 6 September 2026 juga suspend akun Client atau Helper secara umum, dikonfirmasi lewat sesi BE (`FR-ADM-009`, `FR-ADM-010`). Ini menjawab celah yang tadinya sengaja saya kosongkan karena belum dibahas eksplisit dengan tim.

| Kode | Functional Requirement | Prioritas | Sumber | Status |
| --- | --- | --- | --- | --- |
| FR-ADM-001 | Sistem harus menyediakan login terpisah untuk akun admin, tidak memakai jalur registrasi dan login yang sama dengan Client dan Helper | Must | ASUMSI | DRAFT |
| FR-ADM-002 | Sistem harus menolak akses ke seluruh endpoint dan halaman admin bagi akun yang tidak bertanda admin, termasuk akun Client dan Helper yang mencoba mengakses langsung lewat URL | Must | TURUNAN | DRAFT |
| FR-ADM-003 | Sistem harus menampilkan daftar pengajuan verifikasi identitas Helper yang berstatus menunggu peninjauan, beserta foto KTP dan swafoto yang diunggah | Must | TURUNAN | DRAFT |
| FR-ADM-004 | Sistem harus mengizinkan admin menyetujui atau menolak pengajuan verifikasi, dan mewajibkan alasan penolakan diisi jika ditolak | Must | TURUNAN | DRAFT |
| FR-ADM-005 | Sistem harus menampilkan daftar sengketa yang masuk beserta detail pesanan dan bukti terkait, dibatasi hanya pesanan berkategori Delivery sesuai FR-ORD-018 | Must | TURUNAN | DRAFT |
| FR-ADM-006 | Sistem harus mengizinkan admin memutuskan hasil sengketa dengan tiga pilihan, berpihak client, berpihak helper, atau dibagi, dan mewajibkan catatan keputusan diisi | Must | TURUNAN | DRAFT |
| FR-ADM-007 | Sistem harus menampilkan ringkasan agregat komisi platform yang terkumpul kepada admin, dapat disaring berdasarkan rentang tanggal | Should | TURUNAN | DRAFT |
| FR-ADM-008 | Sistem harus mencatat setiap tindakan admin (persetujuan verifikasi, penolakan, keputusan sengketa) beserta identitas admin yang melakukan dan waktu tindakan | Must | TURUNAN | DRAFT |
| FR-ADM-009 | Sistem harus mengizinkan admin menonaktifkan (suspend) akun Client atau Helper, dengan alasan wajib diisi, dan mencegah akun yang di-suspend melakukan aksi apa pun sampai diaktifkan kembali | Must | TURUNAN, BARU 6 Sep 2026 hasil sesi BE | DRAFT |
| FR-ADM-010 | Sistem harus mengizinkan admin mengaktifkan kembali akun yang di-suspend | Must | TURUNAN, BARU 6 Sep 2026 hasil sesi BE | DRAFT |

## 10. Non-Functional Requirement

Kategori mengacu pada ISO 25010. Setiap NFR ditulis dengan angka supaya QA bisa mengujinya.

| Kode | Quality Requirement | Quality Factor | Cara pengukuran |
| --- | --- | --- | --- |
| NFR-PERF-01 | Waktu respons API untuk operasi baca tidak lebih dari 1500 milidetik pada persentil 95 dengan jaringan 4G | Performance Efficiency | Uji beban dengan 100 pengguna serentak |
| NFR-PERF-02 | Waktu buka dingin aplikasi tidak lebih dari 3 detik pada perangkat Android dengan RAM 4 GB | Performance Efficiency | Pengukuran manual pada perangkat acuan sebanyak sepuluh kali |
| NFR-PERF-03 | Perubahan status pesanan tampil di perangkat lawan bicara dalam waktu tidak lebih dari 5 detik | Performance Efficiency | Uji dua perangkat berdampingan |
| NFR-SEC-01 | Kata sandi disimpan dalam bentuk hash dengan algoritma bcrypt faktor kerja minimal 12 | Security | Inspeksi basis data |
| NFR-SEC-02 | Seluruh komunikasi antara aplikasi dan server memakai HTTPS dengan TLS 1.2 atau lebih baru | Security | Inspeksi konfigurasi server |
| NFR-SEC-03 | Foto kartu identitas disimpan di bucket privat (Cloudflare R2) dan hanya dapat diakses lewat signed URL berumur pendek yang dibuat backend untuk admin operasional, tidak pernah dikembalikan pada endpoint publik | Security | Uji akses tidak sah. Enkripsi at-rest tambahan di luar isolasi bucket masih jadi pertanyaan terbuka untuk sesi BE, lihat `05_erd-draft.md` bagian 3B |
| NFR-SEC-04 | Nomor telepon lawan bicara ditampilkan tersamar kecuali pada pesanan yang sedang berjalan | Security | Uji tampilan |
| NFR-REL-01 | Ketersediaan layanan minimal 99 persen dalam periode pengujian | Reliability | Pemantauan uptime |
| NFR-REL-02 | Tidak boleh ada selisih antara total saldo pengguna dan total mutasi ledger pada rekonsiliasi harian | Reliability | Skrip rekonsiliasi otomatis |
| NFR-REL-03 | Tingkat sesi bebas gagal aplikasi minimal 99 persen | Reliability | Laporan crash reporting |
| NFR-USE-01 | Pembuatan pesanan dari beranda sampai konfirmasi dapat diselesaikan dalam maksimal lima ketukan | Usability | Penelusuran alur bersama UI/UX |
| NFR-USE-02 | Setiap pesan kesalahan menyebutkan penyebab dan tindakan yang bisa dilakukan pengguna, bukan kode teknis | Usability | Peninjauan seluruh pesan kesalahan |
| NFR-USE-03 | Seluruh teks antarmuka memakai bahasa Indonesia yang konsisten dengan glosarium | Usability | Peninjauan salinan teks |
| NFR-COMP-01 | Aplikasi berjalan pada Android 9 ke atas dan iOS 14 ke atas | Compatibility | Uji perangkat |
| NFR-MNT-01 | Kode mengikuti satu panduan gaya yang disepakati dan lolos pemeriksaan linter tanpa galat | Maintainability | Pemeriksaan otomatis pada integrasi |
| NFR-PORT-01 | Konfigurasi lingkungan dipisahkan dari kode sehingga aplikasi dapat dipindah antar lingkungan tanpa mengubah kode | Portability | Peninjauan konfigurasi |

## 11. Matriks keterlacakan

Kolom diisi bertahap seiring artefak lain jadi. Kolom kosong adalah pengingat pekerjaan yang belum selesai, bukan kelalaian.

| Kode FR | Use Case | Layar | Endpoint | Test Case |
| --- | --- | --- | --- | --- |
| FR-AUTH-001 | UC-AUTH-01 | Registrasi | `POST /auth/register` | TC-FR-AUTH-001-01 |
| FR-ORD-001 | UC-ORD-01 | Buat pesanan | `POST /orders` | TC-FR-ORD-001-01 |
| FR-ORD-003 | UC-ORD-01, UC-ORD-02 | Buat pesanan, Cari helper | `POST /orders` | TC-FR-ORD-003-01 |
| FR-ORD-008 | UC-ORD-04 | Pelacakan | `GET /orders/{id}` | TC-FR-ORD-008-01 |
| FR-ORD-010 | UC-ORD-05 | Pelacakan | `POST /orders/{id}/confirm` | TC-FR-ORD-010-01 |
| FR-ORD-014 | UC-ORD-06 | Pelacakan, Persetujuan harga | `POST /orders/{id}/adjustment` | TC-FR-ORD-014-01 |
| FR-WLT-002 | UC-WLT-01 | Proses otomatis | `POST /orders/{id}/accept` | TC-FR-WLT-002-01 |
| FR-WLT-003 | UC-WLT-02 | Proses otomatis | `POST /orders/{id}/confirm` | TC-FR-WLT-003-01 |
| FR-HLP-002 | UC-HLP-01 | Cari helper | `GET /helpers` | TC-FR-HLP-002-01 |
| FR-RTG-001 | UC-RTG-01 | Penilaian | `POST /orders/{id}/rating` | TC-FR-RTG-001-01 |
| FR-ADM-004 | UC-ADM-01 | Panel admin, verifikasi | `POST /admin/verifications/{id}/approve` | TC-FR-ADM-004-01 |
| FR-ADM-006 | UC-ADM-02 | Panel admin, sengketa | `POST /admin/disputes/{id}/resolve` | TC-FR-ADM-006-01 |
