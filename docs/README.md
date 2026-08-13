# Workspace: TolonginDong

Workspace artefak System Analyst untuk proyek aplikasi mobile marketplace jasa harian (SDG 8: Decent Work and Economic Growth). Dokumen ini adalah pintu masuk. Semua orang di tim yang butuh tahu "artefak SA yang mana yang jadi acuan" harus mulai dari sini.

Nama produk `TolonginDong` diambil dari prototipe yang terdapat digrup WA sewaktu weekly report pertama (terlihat pada splash, penamaan `TD-Wallet`, dan prefix order `#TD-XXXX`). Nama ini masih berstatus tentatif.

## 1. Prinsip kerja

Pertama, satu sumber kebenaran per topik. Kalau ada dua tempat yang menyebut daftar Functional Requirement, salah satunya harus dihapus, bukan disinkronkan manual. File `02_requirement-master-list.md` adalah satu-satunya tempat FR dan NFR hidup. SRS, SDD versi Word menyalin dari sana, bukan sebaliknya.

Kedua, setiap artefak punya ID yang bisa dilacak. Requirement menunjuk ke use case, use case menunjuk ke layar dan endpoint, endpoint menunjuk ke test case. Kalau satu FR berubah, kita bisa tahu dalam hitungan detik siapa yang kena dampak.

Ketiga, asumsi ditulis sebagai asumsi. Selama belum divalidasi oleh tim atau stakeholder, statusnya `ASSUMED`, bukan `CONFIRMED`. Ini yang membedakan dokumen analis dari dokumen karangan.

## 2. Struktur folder

```
tolongindong-docs/
├── README.md                                 
├── 01_stakeholder-register-glossary.md       <- siapa yang terlibat, istilah apa yang dipakai
├── 02_requirement-master-list.md             <- FR + NFR + matriks keterlacakan
├── 03_use-case-inventory.md                  <- aktor, use case, inventaris layar, gap prototipe
├── 04_dual-role-transaction-analysis.md      <- analisis dua peran dan validasi transaksi
├── 05_erd-draft.md                           <- ERD dan catatan skema untuk BE
├── 06_api-contract-draft.md                  <- kontrak API untuk BE dan Mobile
└── 07_acceptance-criteria-gherkin.md         <- kriteria penerimaan untuk QA
```

## 3. Konvensi penamaan

Nama file dokumen resmi mengikuti pola `<JENIS>_<NamaProyek>_v<major>.<minor>.<ekstensi>`, contohnya `SRS_TolonginDong_v1.0.docx` dan `SDD_TolonginDong_v0.3.docx`. Tanggal tidak perlu masuk nama file karena sudah tercatat di version history di dalam dokumen.

Aturan versi: `v0.x` berarti draf yang masih boleh berubah tanpa pemberitahuan, `v1.0` berarti sudah disetujui tim dan menjadi baseline, kenaikan minor untuk perbaikan redaksi atau penambahan detail, kenaikan major untuk perubahan yang mengubah lingkup atau memaksa divisi lain mengerjakan ulang.

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

`DRAFT` baru ditulis SA, belum dibaca siapa pun. `REVIEW` sudah dikirim ke divisi terkait dan menunggu tanggapan. `CONFIRMED` sudah disetujui pihak yang berwenang. `BUILT` sudah diimplementasikan dan masuk build. `DEPRECATED` sudah tidak berlaku tetapi sengaja disimpan sebagai jejak.

Sumber setiap requirement juga ditulis, apakah berasal dari prototipe UI, dari diskusi tim, dari kebutuhan lab, atau dari asumsi SA yang belum divalidasi.

## 6. Definition of Done per artefak

Sebuah artefak SA baru boleh dinyatakan selesai kalau memenuhi semua poin berikut.

Untuk daftar requirement, setiap baris terukur dan bebas kata sifat kabur seperti cepat, mudah, atau ramah pengguna. Kalau menyangkut waktu, harus ada angka dan kondisi jaringannya. Setiap FR punya minimal satu use case dan satu kriteria penerimaan.

Untuk use case scenario, ada pra kondisi, pasca kondisi, skenario utama, dan minimal dua skenario alternatif atau eksepsi. Skenario yang hanya berisi happy path dianggap belum selesai.

Untuk ERD, semua entitas punya kunci primer, semua relasi punya kardinalitas eksplisit, dan setiap kolom uang punya tipe data serta satuan yang jelas. Tidak ada kolom bertipe `float` untuk nominal rupiah.

Untuk kontrak API, ada method, path, header, contoh request, contoh response sukses, dan minimal tiga contoh response gagal dengan kode status yang berbeda.

## 7. Alur kerja mingguan dan pemetaan ke alur SA

Alur kerja SA sembilan langkah dari materi lab (Study Group Pertama SA) dipetakan ke rencana eksekusi seperti berikut.

| Langkah | Aktivitas | Output workspace | Target |
| --- | --- | --- | --- |
| 1 | Kick-off dan identifikasi stakeholder | `01_stakeholder-register-glossary.md` | when yah |
| 2 | Requirement elicitation | catatan diskusi tim | when yah |
| 3 | Analysis dan validation | `04_dual-role-transaction-analysis.md` | when yah |
| 4 | Requirement documentation | `02_requirement-master-list.md`, SRS bab 1 sampai 3 | when yah |
| 5 | Verifikasi ke stakeholder | sesi review bersama Mentor dan lintas divisi (BE, QA, dll) | when yah |
| 6 | Modelling | `03_use-case-inventory.md`, `05_erd.md`, activity dan class diagram | when yah |
| 7 | Handover ke Design dan Dev | `06_api-contract.md`, SDD bab 1 sampai 3 | Setelah modelling stabil |
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
| DEC-01 | Satu akun dengan dua kapabilitas, bukan dua akun terpisah | Usulan Davi (SA), menunggu persetujuan tim | Menghindari duplikasi identitas dan mempermudah rekonsiliasi saldo. Detail di `04_dual-role-transaction-analysis.md` | 12 Agu 2026 |
| DEC-02 | Uang ditahan sistem (escrow) sejak helper menerima pesanan sampai pesanan dikonfirmasi selesai | Usulan Davi (SA), menunggu persetujuan tim | Ini jawaban atas risiko transaksi dua arah | 12 Agu 2026 |
| DEC-03 | Penilaian dua arah bersifat tertutup sampai kedua pihak mengisi atau tenggat lewat | Usulan Davi (SA), menunggu persetujuan tim | Mencegah penilaian balas dendam | 12 Agu 2026 |

## 10. Risiko yang sedang dipantau

| ID | Risiko | Dampak | Mitigasi |
| --- | --- | --- | --- |
| RSK-0x | Lorep Ipsum | Tinggi | (Cth: Tetapkan MoSCoW sejak awal, jadikan pelacakan peta sebagai simulasi status, bukan GPS penuh) |
