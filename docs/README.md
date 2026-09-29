# Workspace: TolonginDong

Workspace artefak untuk proyek aplikasi mobile marketplace jasa harian (SDG 8: Decent Work and Economic Growth). Dokumen ini adalah pintu masuk. Semua orang di tim yang butuh tahu "artefak SA yang mana yang jadi acuan" harus mulai dari sini.

## 1. Prinsip kerja

Pertama, satu sumber kebenaran per topik. Kalau ada dua tempat yang menyebut daftar Functional Requirement, salah satunya harus dihapus, bukan disinkronkan manual. File `02_requirement-master-list.md` adalah satu-satunya tempat FR dan NFR hidup. SRS versi Word menyalin dari sana saat mau dikumpulkan, bukan sebaliknya.

Kedua, setiap artefak punya ID yang bisa dilacak. Requirement menunjuk ke use case, use case menunjuk ke layar dan endpoint, endpoint menunjuk ke test case. Kalau satu FR berubah, kita bisa tahu dalam hitungan detik siapa yang kena dampak.

Ketiga, asumsi ditulis sebagai asumsi. Selama belum divalidasi ke Mentor, statusnya `ASSUMED`, bukan `CONFIRMED`. Ini yang membedakan dokumen analis dari dokumen karangan.

## 2. Struktur folder

```
tolongindong-docs/
├── README.md                                 <- kamu di sini
├── 01_stakeholder-register-glossary.md       <- siapa yang terlibat, istilah apa yang dipakai
├── 02_requirement-master-list.md             <- FR + NFR + matriks keterlacakan
├── 03_use-case-inventory.md                  <- aktor, use case, inventaris layar, gap prototipe
├── 04_dual-role-transaction-analysis.md      <- analisis dua peran dan validasi transaksi
├── 05_erd-draft.md                           <- ERD dan catatan skema untuk BE
├── 06_api-contract-draft.md                  <- kontrak API untuk BE dan Mobile
├── 07_acceptance-criteria-gherkin.md         <- kriteria penerimaan untuk QA
├── 08_alur-kerja-dan-pemetaan-divisi.md       <- alur kerja SA dan siapa kasih input ke siapa, untuk disebar ke tim
└── 09_dokumentasi-keputusan-minggu-1.md       <- catatan lima keputusan hasil sesi 19 Agustus dan dampaknya
```

Struktur penyimpanan tim di Google Drive:

```
/00-Admin            berita acara, notulen, jadwal
/01-SA               isi workspace ini, plus SRS dan SDD versi Word
/02-UIUX             file Figma, export flow, design system
/03-BE               skema database, koleksi Postman, dokumentasi API final
/04-Mobile           dokumen teknis mobile
/05-QA               test plan, test case, laporan bug
/99-Archive          versi lama yang sudah tidak dipakai
```

## 3. Konvensi penamaan

Nama file dokumen resmi mengikuti pola `<JENIS>_<NamaProyek>_v<major>.<minor>.<ekstensi>`, contohnya `SRS_TolonginDong_v1.0.docx` dan `SDD_TolonginDong_v0.3.docx`. Tanggal tidak perlu masuk nama file karena sudah tercatat di version history di dalam dokumen.

Aturan versi: `v0.x` berarti draf yang masih boleh berubah tanpa pemberitahuan, `v1.0` berarti sudah menjadi baseline, kenaikan minor untuk perbaikan redaksi atau penambahan detail, kenaikan major untuk perubahan yang mengubah lingkup atau memaksa divisi lain mengerjakan ulang.

## 4. Konvensi ID artefak

| Jenis artefak | Pola | Contoh |
| --- | --- | --- |
| Functional Requirement | `FR-<MODUL>-<NNN>` | `FR-ORD-004` |
| Non-Functional Requirement | `NFR-<KATEGORI>-<NN>` | `NFR-PERF-02` |
| Use Case | `UC-<MODUL>-<NN>` | `UC-ORD-03` |
| Aktor | `ACT-<NN>` | `ACT-02` |
| Entitas basis data | `snake_case` tunggal | `order_item` |
| Endpoint API | `API-<MODUL>-<NN>` | `API-WLT-05` |
| Test Case | `TC-<KODE FR>-<NN>` | `TC-FR-ORD-004-01` |
| Keputusan desain | `DEC-<NN>` | `DEC-01` |
| Risiko | `RSK-<NN>` | `RSK-03` |

Kode modul yang dipakai: `AUTH` autentikasi dan akun, `VER` verifikasi identitas, `PRF` profil dan alamat, `HLP` pencarian serta pendaftaran helper, `ORD` siklus hidup pesanan, `WLT` dompet dan pembayaran, `CHT` percakapan, `RTG` penilaian dua arah, `NOT` notifikasi, `DSP` sengketa.

Nomor urut tidak pernah dipakai ulang. Kalau satu FR dihapus, nomornya dipensiunkan dan ditandai `DEPRECATED`, tidak diberikan ke requirement baru. Ini mencegah kekacauan waktu QA membuka test case lama.

## 5. Status artefak

Setiap baris requirement dan setiap dokumen punya kolom status dengan nilai yang terbatas pada lima ini.

`DRAFT` baru ditulis SA, belum dibaca siapa pun. `REVIEW` sudah dikirim ke divisi terkait dan menunggu tanggapan. `CONFIRMED` sudah disetujui pihak yang berwenang, biasanya Mentor untuk lingkup dan BE untuk kelayakan teknis. `BUILT` sudah diimplementasikan dan masuk build. `DEPRECATED` sudah tidak berlaku tetapi sengaja disimpan sebagai jejak.

Sumber setiap requirement juga ditulis, apakah berasal dari prototipe UI, dari diskusi tim, dari kebutuhan lab, atau dari asumsi SA yang belum divalidasi.

## 6. Definition of Done per artefak

Sebuah artefak SA baru boleh dinyatakan selesai kalau memenuhi semua poin berikut.

Untuk daftar requirement, setiap baris terukur dan bebas kata sifat kabur seperti cepat, mudah, atau ramah pengguna. Kalau menyangkut waktu, harus ada angka dan kondisi jaringannya. Setiap FR punya minimal satu use case dan satu kriteria penerimaan.

Untuk use case scenario, ada pra kondisi, pasca kondisi, skenario utama, dan minimal dua skenario alternatif atau eksepsi. Skenario yang hanya berisi happy path dianggap belum selesai.

Untuk ERD, semua entitas punya kunci primer, semua relasi punya kardinalitas eksplisit, dan setiap kolom uang punya tipe data serta satuan yang jelas. Tidak ada kolom bertipe `float` untuk nominal rupiah.

Untuk kontrak API, ada method, path, header, contoh request, contoh response sukses, dan minimal tiga contoh response gagal dengan kode status yang berbeda.

## 7. Alur kerja mingguan dan pemetaan ke alur SA

Alur kerja SA sembilan langkah dari materi lab dipetakan ke rencana eksekusi seperti berikut.

| Langkah | Aktivitas | Output workspace | Target |
| --- | --- | --- | --- |
| 1 | Kick-off dan identifikasi stakeholder | `01_stakeholder-register-glossary.md` | Selesai |
| 2 | Requirement elicitation | catatan diskusi tim, hasil review prototipe | Selesai |
| 3 | Analysis dan validation | `04_dual-role-transaction-analysis.md` | Selesai |
| 4 | Requirement documentation | `02_requirement-master-list.md`, SRS bab 1 sampai 3 | Minggu ini sampai minggu depan |
| 5 | Verifikasi ke stakeholder | sesi review bersama Mentor dan lintas divisi | Belum ditargetkan |
| 6 | Modelling | `03_use-case-inventory.md`, `05_erd-draft.md`, activity dan class diagram | Minggu ini atau depan |
| 7 | Handover ke Design dan Dev | `06_api-contract-draft.md`, SDD bab 1 sampai 3 | Setelah modelling stabil |
| 8 | Monitoring development | log perubahan requirement dan dampaknya | Berjalan |
| 9 | Support UAT | `07_acceptance-criteria-gherkin.md` | Menjelang UAT |

## 8. Matriks handover antar divisi

| Penerima | Yang SA berikan | Yang SA butuhkan balik |
| --- | --- | --- |
| UI/UX Designer | daftar layar, aturan bisnis per layar, kondisi kosong dan kondisi error, aturan validasi form | konfirmasi bahwa semua state punya desain, termasuk state gagal |
| Backend Developer | ERD, kamus data, kontrak API, aturan invarian transaksi | konfirmasi kelayakan teknis dan estimasi, penyesuaian nama field |
| Mobile Developer | alur navigasi, state machine pesanan, daftar kode error dan pesan yang harus ditampilkan | konfirmasi bahwa semua transisi state bisa dipicu dari UI yang ada |
| QA | kriteria penerimaan format Gherkin, daftar edge case, data uji | daftar skenario yang belum tercakup |
| Mentor | SRS, SDD, progres mingguan | persetujuan lingkup dan koreksi format |

## 9. Decision log

Keputusan yang mengubah arah desain dicatat di sini supaya tidak diulang perdebatannya.

| ID | Keputusan | Status | Alasan singkat | Tanggal |
| --- | --- | --- | --- | --- |
| DEC-01 | Satu akun dengan dua kapabilitas, bukan dua akun terpisah | Disetujui | Menghindari duplikasi identitas dan mempermudah rekonsiliasi saldo. Detail di `04_dual-role-transaction-analysis.md` | 12 Agu 2026 |
| DEC-02 | Uang ditahan sistem (escrow) sejak helper menerima pesanan sampai pesanan dikonfirmasi selesai | Disetujui | Ini jawaban atas risiko transaksi dua arah | 12 Agu 2026 |
| DEC-03 | Penilaian dua arah bersifat tertutup sampai kedua pihak mengisi atau tenggat lewat | Digantikan oleh DEC-09 | Dibahas ulang bersama UI/UX 28 Agustus, tim memilih menghapus penilaian dari sisi Helper sama sekali alih alih membangun mekanisme tunda dan sembunyikan | 12 Agu 2026 |
| DEC-04 | Dompet berjalan dengan saldo simulasi, integrasi payment gateway sungguhan dicatat sebagai arah pengembangan lanjutan di luar lingkup lab | Disetujui | Hasil sesi sinkronisasi 19 Agustus, menjawab pertanyaan terbuka nomor satu di `04_dual-role-transaction-analysis.md` | 19 Agu 2026 |
| DEC-05 | Pemesanan memakai model tawar harga dua arah, client mengajukan estimasi harga, beberapa helper dapat mengajukan harga masing masing, client memilih satu | Disetujui | Hasil sesi sinkronisasi 19 Agustus, menggantikan model penerimaan tawaran sederhana yang diusulkan sebelumnya. Detail dampak desain di `09_dokumentasi-keputusan-minggu-1.md` | 19 Agu 2026 |
| DEC-06 | Pelacakan pesanan memakai perubahan status, bukan lokasi GPS langsung, untuk saat ini | Disetujui, dikonfirmasi ulang 28 Agustus tanpa perubahan | Hasil sesi sinkronisasi 19 Agustus, menurunkan beban kerja Mobile dan BE. Layar pelacakan tetap perlu digambar ulang oleh UI/UX sebagai visualisasi tahapan status | 19 Agu 2026 |
| DEC-07 | Mentor lab berperan sebagai admin operasional untuk verifikasi identitas helper dan penyelesaian sengketa, mengakses lewat panel admin sungguhan di dalam sistem | Disetujui | Hasil sesi sinkronisasi 19 Agustus, mekanisme akses dikonfirmasi 28 Agustus. Konsekuensi: modul ADM baru ditambahkan ke `02_requirement-master-list.md`, `05_erd-draft.md`, dan `06_api-contract-draft.md` | 19 Agu 2026 |
| DEC-08 | Besaran potongan platform ditetapkan 10 persen dari nominal yang diterima helper | Disetujui | Dikonfirmasi 28 Agustus. Rekomendasi dan alasannya ada di `09_dokumentasi-keputusan-minggu-1.md` | 19 Agu 2026 |
| DEC-09 | Penilaian dihapus dari dua arah menjadi satu arah, hanya Client menilai Helper. FR-RTG-002 dinyatakan DEPRECATED | Disetujui | Hasil diskusi SA dengan UI/UX 28 Agustus. Menggantikan DEC-03. Konsekuensi: argumen SDG 8 soal "perlindungan dari penilaian sepihak" pada `01_stakeholder-register-glossary.md` bagian 5 ikut direvisi karena mekanisme yang mendasarinya sudah tidak ada | 28 Agu 2026 |
| DEC-10 | Kanal sengketa (FR-ORD-018) dibatasi hanya untuk pesanan berkategori Delivery | Disetujui, dengan satu inkonsistensi belum terjawab | Hasil diskusi SA dengan UI/UX 28 Agustus. Belum jelas bagaimana perlakuan terhadap jalur `PRICE_ADJUSTMENT --> DISPUTED` pada kategori Food run yang sudah dirancang lebih dulu, lihat pertanyaan terbuka di `04_dual-role-transaction-analysis.md` bagian empat | 28 Agu 2026 |
| DEC-11 | Teknologi ditetapkan: Backend Laravel (PHP), Mobile Flutter, Database Supabase (lapis PostgreSQL saja, bukan Auth atau REST bawaan), Autentikasi Laravel Sanctum, Storage foto Cloudflare R2 dengan bucket terpisah publik dan privat | Dikonfirmasi (keputusan teknis BE) | Dilaporkan Kai (Backend) lewat `tolongindong-erd-review.md`. Menjawab pertanyaan lama soal stack yang belum ditetapkan | 6 Sep 2026 |
| DEC-12 | Enam dari dua belas pertanyaan terbuka ERD terjawab lewat sesi BE: enkripsi foto KTP tidak perlu (private bucket cukup), enkripsi nomor telepon tidak perlu, voucher dipotong dari komisi platform, voucher boleh ditumpuk, cooldown verifikasi 2 menit, admin butuh fitur suspend akun | Disetujui, satu catatan perlu dicek ulang | Rincian lengkap di `05_erd-draft.md` bagian 3B. Cooldown 2 menit ditandai SA sebagai kemungkinan salah dengar satuan waktu, perlu konfirmasi ulang sebelum dianggap final | 6 Sep 2026 |
| DEC-13 | Enam pertanyaan ERD sisanya (itemisasi order, kardinalitas penyesuaian harga, definisi kategori, rumus tarif jasa, batas alamat, chat sebelum pesanan) belum dibahas tim, SA memberi rekomendasi awal untuk masing masing | Usulan SA, menunggu konfirmasi tim | Rincian dan alasan tiap rekomendasi di `05_erd-draft.md` bagian 3B. Empat di antaranya (itemisasi, kategori, batas alamat, chat) sengaja tidak diputuskan sendiri oleh SA karena berdampak ke lingkup produk, bukan cuma teknis | 6 Sep 2026 |

## 10. Risiko yang sedang dipantau

| ID | Risiko | Dampak | Mitigasi |
| --- | --- | --- | --- |
| RSK-01 | Lingkup terlalu besar untuk durasi lab, terutama fitur peta waktu nyata dan dompet | Tinggi | Tetapkan MoSCoW sejak awal, jadikan pelacakan peta sebagai simulasi status, bukan GPS penuh |
| RSK-02 | Prototipe UI belum punya layar untuk sebagian alur penting seperti pembuatan pesanan dan sengketa | Sedang | Daftar gap sudah disiapkan di `03_use-case-inventory.md` untuk dibahas dengan UI/UX |
| RSK-03 | Uang sungguhan tidak boleh dipakai di lingkungan lab | Sedang | Dompet berjalan dalam mode simulasi dengan saldo dummy, dinyatakan eksplisit di batasan SRS |
