# Alur Kerja SA dan Pemetaan Siapa Memberi Input ke Siapa

Dokumen ini melengkapi pembahasan meet kemarin yang sempat terlewat oleh SA, yaitu alur kerja mingguan dan pemetaan menurut alur SA. Tujuannya supaya setiap orang tahu kapan gilirannya menunggu, kapan gilirannya bekerja, dan dari siapa dia harus menunggu input sebelum bisa mulai.

## 1. Kenapa urutan ini penting

Proyek ini tidak bisa dikerjakan lima divisi sekaligus dari hari pertama. Ada urutan ketergantungan yang kalau dilanggar, hasilnya kerja ulang. UI/UX tidak bisa menggambar layar kalau logika bisnis di baliknya belum jelas. Backend tidak bisa membangun skema database kalau requirement masih berubah ubah. Mobile tidak bisa mengonsumsi API yang kontraknya belum disepakati. QA tidak bisa menulis test case untuk fitur yang belum punya kriteria penerimaan.

SA berada di ujung paling depan rantai ini. Bukan karena SA paling penting, tapi karena SA yang menerjemahkan ide kasar jadi sesuatu yang bisa dikerjakan divisi lain. Begitu SA menyampaikan requirement yang salah, kesalahan itu menjalar ke seluruh rantai di belakangnya.

## 2. Sembilan langkah alur kerja SA

Ini alur kerja standar yang dipakai, dipetakan ke konteks proyek kita.

Langkah satu, kick-off dan identifikasi stakeholder. Ini tahap menentukan siapa saja yang punya kepentingan di proyek, apa yang mereka butuhkan, dan istilah apa yang akan dipakai konsisten. Sudah selesai, hasilnya ada di dokumen stakeholder register.

Langkah dua, requirement elicitation. Menggali kebutuhan dari sumber yang ada, dalam kasus kita dari video prototipe UI/UX dan diskusi tim. SA menonton ulang prototipe frame demi frame, mencatat setiap elemen yang terlihat, lalu menyimpulkan requirement yang tersirat di baliknya.

Langkah tiga, analysis dan validation. Requirement mentah diperiksa konsistensinya, terutama untuk area berisiko seperti dua peran dan transaksi dua arah. Di sinilah muncul pertanyaan pertanyaan yang perlu diputuskan bersama, bukan diputuskan sendirian oleh SA.

Langkah empat, requirement documentation. Requirement yang sudah dianalisis dituliskan formal dengan kode, prioritas, dan sumber yang jelas.

Langkah lima, verifikasi ke stakeholder. Ini yang kita lakukan kemarin lewat meet, mengonfirmasi requirement dan keputusan lingkup ke seluruh tim.

Langkah enam, modelling. Requirement yang sudah dikonfirmasi diterjemahkan jadi diagram, ERD, use case, dan flow, yang kemudian jadi bahasa bersama antar divisi.

Langkah tujuh, handover ke Design dan Dev. SA menyerahkan hasil modelling ke UI/UX untuk digambar jadi tampilan, dan ke Backend untuk dibangun jadi sistem.

Langkah delapan, monitoring development. Selama development berjalan, SA memantau apakah implementasi masih sesuai requirement, dan mencatat kalau ada requirement yang berubah di tengah jalan.

Langkah sembilan, support UAT. Menjelang pengujian penerimaan pengguna, SA memastikan kriteria penerimaan sudah dipahami QA dan siap dipakai menguji hasil akhir.

Minggu ini kita berada di antara langkah lima dan enam. Verifikasi sudah jalan lewat meet, sekarang masuk ke modelling bersama UI/UX dan BE.

## 3. Siapa menunggu siapa

Ini bagian yang paling sering bikin bingung kalau tidak ditulis eksplisit. Setiap divisi punya dua peran, sebagai penerima input dan sebagai pemberi input balik. Berikut petanya.

**SA ke UI/UX.** SA memberi daftar layar yang dibutuhkan, aturan bisnis di setiap layar, kondisi kosong dan kondisi error yang harus ada, serta aturan validasi form. UI/UX tidak perlu menebak nebak logika bisnis sendiri, itu tugas SA menyediakannya lebih dulu. Baliknya, UI/UX memberi konfirmasi ke SA bahwa setiap use case yang didaftarkan sudah punya layar penghasilnya, dan kalau ada requirement yang menurut mereka janggal saat digambar, itu dilaporkan balik ke SA untuk didiskusikan ulang, bukan diam diam disesuaikan sendiri oleh desainer.

**SA ke Backend.** SA memberi ERD, kamus data, kontrak API, dan daftar aturan invarian seperti saldo tidak boleh negatif atau satu pesanan hanya boleh punya satu penahanan dana aktif. Backend tidak perlu menebak struktur data dari requirement mentah. Baliknya, Backend memberi konfirmasi kelayakan teknis, termasuk kalau ada bagian skema yang menurut mereka terlalu rumit untuk waktu yang tersedia, dan itu jadi bahan SA menyesuaikan lingkup.

**SA ke Mobile.** SA memberi alur navigasi, state machine pesanan lengkap dengan semua status yang mungkin, dan daftar kode error beserta pesan yang harus ditampilkan ke pengguna. Mobile tidak perlu menyimpan logika status sendiri di aplikasi, semua mengikuti apa yang dikirim server. Baliknya, Mobile memberi konfirmasi bahwa semua transisi status pada state machine memang bisa dipicu dari tombol atau aksi yang ada di desain UI/UX, karena kalau ada status yang tidak punya cara dipicu dari antarmuka, itu berarti ada yang bolong di antara SA dan UI/UX.

**SA ke QA.** SA memberi kriteria penerimaan dalam format Gherkin dan daftar edge case yang harus diuji. QA tidak perlu menyusun skenario uji dari nol. Baliknya, QA memberi daftar skenario yang menurut mereka belum tercakup, karena QA sering menemukan celah yang tidak kepikiran saat requirement ditulis.

**Backend ke Mobile.** Setelah kontrak API disepakati bersama SA, Backend membangun endpoint sungguhan, dan Mobile mengonsumsinya. Kalau ada perbedaan antara dokumentasi dan implementasi sungguhan, itu dilaporkan ke SA supaya dokumen kontrak API diperbarui, bukan dibiarkan dokumen dan kode berbeda diam diam.

**Semua divisi ke SA.** Kalau siapa pun menemukan kondisi yang belum ada requirement-nya saat sedang bekerja, itu dilaporkan balik ke SA, bukan diputuskan sendiri di tempat. Ini supaya requirement tetap satu sumber kebenaran dan tidak ada requirement siluman yang cuma ada di kepala satu orang.

## 4. Tabel ringkas

| Dari | Ke | Yang diberikan | Yang ditunggu balik |
| --- | --- | --- | --- |
| SA | UI/UX | Daftar layar, aturan bisnis per layar, kondisi error dan kosong | Konfirmasi semua use case punya layar, laporan requirement yang janggal |
| SA | Backend | ERD, kamus data, kontrak API, daftar invarian | Konfirmasi kelayakan teknis, penyesuaian skema |
| SA | Mobile | Alur navigasi, state machine, kode dan pesan error | Konfirmasi semua transisi status bisa dipicu dari UI |
| SA | QA | Kriteria penerimaan Gherkin, daftar edge case | Daftar skenario yang belum tercakup |
| Backend | Mobile | Endpoint API sungguhan sesuai kontrak | Laporan ketidaksesuaian dokumentasi dan implementasi |
| Semua divisi | SA | Laporan kondisi yang belum ada requirement-nya | Requirement baru atau revisi yang terdokumentasi |

## 5. Kenapa urutan minggu ini begitu

Sesi UI/UX dijadwalkan sebelum sesi Backend karena user flow perlu ada dulu supaya diskusi ERD dengan Backend punya konteks visual, bukan sekadar tabel abstrak. Sesi Mobile dan QA digabung dan ditaruh belakangan karena keduanya sama sama butuh state machine pesanan yang sudah difinalkan, dan state machine baru bisa difinalkan setelah keputusan soal model pemesanan dari sesi sinkronisasi turun ke dokumen.
