# Acceptance Criteria untuk QA

Status dokumen: `REVIEW` v0.1. Ditulis dalam format Given When Then supaya bisa diturunkan langsung menjadi test case. Setiap skenario menyebut kode FR yang diuji agar keterlacakan terjaga.

## 1. Registrasi dan verifikasi

```gherkin
Fitur: Registrasi akun
  Latar: Pengguna belum memiliki akun

  Skenario: Registrasi berhasil dengan data valid
    # FR-AUTH-001, FR-AUTH-002
    Diberikan pengguna berada pada layar registrasi
    Ketika pengguna mengisi nama, nomor telepon, email, dan kata sandi yang valid
    Dan menekan tombol daftar
    Dan memasukkan kode OTP yang benar sebelum 300 detik
    Maka sistem membuat akun dengan status verifikasi identitas belum terverifikasi
    Dan sistem membuat dompet dengan saldo nol untuk akun tersebut
    Dan pengguna diarahkan ke beranda

  Skenario: Registrasi ditolak karena nomor sudah terdaftar
    # FR-AUTH-003
    Diberikan nomor 081234567890 sudah terdaftar
    Ketika pengguna mendaftar dengan nomor yang sama
    Maka sistem menolak dengan pesan bahwa nomor sudah digunakan
    Dan sistem tidak mengirim kode OTP

  Skenario: Kode OTP kedaluwarsa
    # FR-AUTH-002
    Diberikan pengguna menerima kode OTP
    Ketika pengguna memasukkan kode setelah lewat 300 detik
    Maka sistem menolak kode tersebut
    Dan menyediakan tombol kirim ulang kode
```

```gherkin
Fitur: Menjadi helper
  Skenario: Akun belum terverifikasi tidak bisa menerima pesanan
    # FR-VER-004
    Diberikan pengguna sudah mendaftar sebagai helper tetapi status verifikasinya sedang ditinjau
    Ketika sistem mencari helper untuk sebuah pesanan baru di area yang sama
    Maka pengguna tersebut tidak menerima tawaran pesanan
```

## 2. Pembuatan pesanan dan penahanan dana

```gherkin
Fitur: Membuat pesanan
  Skenario: Estimasi biaya tampil sebelum konfirmasi
    # FR-ORD-002
    Diberikan client memilih kategori Food run dan mengisi alamat
    Ketika client membuka ringkasan pesanan
    Maka sistem menampilkan tarif dasar, biaya jarak, biaya layanan, batas talangan, potongan voucher, dan total
    Dan total yang ditampilkan sama dengan jumlah yang akan ditahan

  Skenario: Pesanan ditolak karena saldo tidak cukup
    # FR-WLT-002, FR-WLT-008
    Diberikan saldo tersedia client adalah Rp 21.500
    Dan total penahanan yang dibutuhkan adalah Rp 105.000
    Ketika client menekan konfirmasi pesanan
    Maka sistem menolak dengan kode WALLET_INSUFFICIENT_BALANCE
    Dan menampilkan kekurangan saldo sebesar Rp 83.500
    Dan menawarkan tombol isi saldo
    Dan tidak ada baris mutasi dompet yang tercipta

  Skenario: Tidak ada helper yang menerima
    # FR-ORD-005
    Diberikan pesanan berstatus searching
    Ketika 300 detik berlalu tanpa ada helper yang menerima
    Maka status pesanan menjadi expired
    Dan saldo tersedia client kembali seperti sebelum pesanan dibuat
    Dan client menerima notifikasi bahwa tidak ada helper tersedia
```

```gherkin
Fitur: Tawar harga dan pemilihan helper
  # Direvisi 19 Agustus 2026 mengikuti DEC-05, model tawar harga dua arah

  Skenario: Beberapa helper mengajukan tawaran berbeda
    # FR-ORD-003, FR-ORD-003B
    Diberikan pesanan berstatus searching dengan harga estimasi client Rp 40.000
    Ketika helper A mengajukan tawaran Rp 43.000
    Dan helper B mengajukan tawaran Rp 38.000
    Maka client melihat dua tawaran dengan nominal dan profil masing masing
    Dan belum ada dana yang tertahan pada tahap ini

  Skenario: Memilih tawaran belum menahan dana, konfirmasi helper yang menahan
    # FR-ORD-003C, FR-ORD-006B, FR-WLT-002
    Diberikan client memilih tawaran helper B senilai Rp 38.000
    Ketika status pesanan berubah menjadi pending_confirmation
    Maka saldo tersedia client belum berkurang
    Dan ketika helper B mengonfirmasi ketersediaan dalam 60 detik
    Maka saldo tersedia client berkurang Rp 38.000 dan saldo tertahan bertambah Rp 38.000
    Dan status pesanan berubah menjadi accepted

  Skenario: Helper terpilih tidak merespons konfirmasi
    # FR-ORD-006B
    Diberikan client memilih tawaran helper B
    Ketika 60 detik berlalu tanpa konfirmasi dari helper B
    Maka status pesanan kembali menjadi searching
    Dan client dapat memilih tawaran lain yang masih berlaku
    Dan tidak ada dana yang tertahan

  Skenario: Helper terpilih ternyata sudah mengambil pesanan lain
    # INV-06
    Diberikan client memilih tawaran helper B
    Dan pada saat bersamaan helper B baru saja dikonfirmasi pada pesanan lain
    Ketika sistem memeriksa ketersediaan helper B untuk pesanan ini
    Maka permintaan konfirmasi ditolak dengan kode HELPER_HAS_ACTIVE_ORDER
    Dan status pesanan kembali menjadi searching

  Skenario: Pengguna tidak bisa mengajukan tawaran pada pesanannya sendiri
    # FR-ORD-016, INV-05
    Diberikan seorang pengguna yang berstatus helper terverifikasi membuat pesanan sebagai client
    Ketika pengguna tersebut mencoba mengajukan tawaran pada pesanannya sendiri
    Maka sistem menolak dengan kode SELF_ORDER_NOT_ALLOWED

  Skenario: Permintaan konfirmasi dikirim ulang karena jaringan buruk
    # FR-WLT-009, INV-04
    Diberikan helper menekan konfirmasi dan permintaan gagal karena waktu habis di sisi jaringan
    Ketika aplikasi mengirim ulang permintaan dengan idempotency key yang sama
    Maka sistem mengembalikan hasil konfirmasi yang pertama
    Dan tidak tercipta baris penahanan dana kedua
```

## 3. Penyesuaian harga talangan

```gherkin
Fitur: Penyesuaian nilai talangan pada Food run
  Skenario: Nilai sesungguhnya di bawah batas talangan
    # FR-ORD-014
    Diberikan batas talangan pesanan adalah Rp 100.000
    Ketika helper mengunggah struk senilai Rp 46.000
    Maka sistem menerima nilai tersebut tanpa persetujuan client
    Dan status pesanan tetap in_progress

  Skenario: Nilai sesungguhnya melebihi batas talangan
    # FR-ORD-014
    Diberikan batas talangan pesanan adalah Rp 100.000
    Ketika helper mengajukan nilai Rp 118.000 dengan foto struk
    Maka status pesanan menjadi price_adjustment
    Dan client menerima notifikasi permintaan persetujuan
    Dan helper tidak bisa memajukan status sebelum client merespons

  Skenario: Client menolak penyesuaian
    # FR-ORD-014, FR-ORD-018
    Diberikan pesanan berstatus price_adjustment
    Ketika client menolak pengajuan
    Maka status pesanan menjadi disputed
    Dan dana tetap tertahan sampai keputusan admin
```

## 4. Penyelesaian dan pelepasan dana

```gherkin
Fitur: Menyelesaikan pesanan
  Skenario: Client mengonfirmasi selesai
    # FR-ORD-010, FR-WLT-003, INV-09
    Diberikan pesanan berstatus awaiting_confirmation dengan dana tertahan Rp 105.000
    Dan nilai sesungguhnya adalah Rp 43.000 dengan komisi platform Rp 4.300
    Ketika client menekan tombol selesaikan pesanan
    Maka helper menerima Rp 38.700 pada saldo tersedianya
    Dan client menerima pengembalian Rp 62.000 pada saldo tersedianya
    Dan saldo tertahan pesanan itu menjadi nol
    Dan penjumlahan pembayaran helper, komisi, dan pengembalian sama dengan Rp 105.000
    Dan status pesanan menjadi completed dalam waktu tidak lebih dari 5 detik

  Skenario: Client tidak merespons sampai batas waktu
    # FR-ORD-012
    Diberikan pesanan berstatus awaiting_confirmation selama 24 jam
    Ketika batas waktu terlampaui
    Maka sistem mengonfirmasi pesanan secara otomatis
    Dan helper tetap menerima pembayaran
    Dan riwayat status mencatat pelaku sebagai sistem

  Skenario: Pelepasan dana tidak boleh berulang
    # INV-04
    Diberikan pesanan sudah berstatus completed
    Ketika permintaan konfirmasi dikirim ulang
    Maka sistem mengembalikan hasil yang sama dengan konfirmasi pertama
    Dan saldo helper tidak bertambah untuk kedua kalinya
```

## 5. Pembatalan

```gherkin
Fitur: Pembatalan pesanan
  Skenario: Client membatalkan dalam masa tenggang
    # FR-ORD-011
    Diberikan pesanan baru diterima helper 60 detik yang lalu
    Ketika client membatalkan pesanan
    Maka seluruh dana tertahan kembali ke saldo tersedia client
    Dan helper tidak menerima kompensasi
    Dan status pesanan menjadi cancelled_by_client

  Skenario: Client membatalkan setelah helper berangkat
    # FR-ORD-011
    Diberikan pesanan berstatus on_the_way dengan tarif dasar Rp 15.000
    Ketika client membatalkan pesanan
    Maka helper menerima kompensasi Rp 4.500
    Dan sisa dana tertahan kembali ke client
    Dan client melihat rincian potongan sebelum menekan konfirmasi batal

  Skenario: Helper membatalkan setelah menerima
    # FR-ORD-011
    Diberikan pesanan berstatus accepted
    Ketika helper membatalkan pesanan
    Maka seluruh dana kembali ke saldo tersedia client
    Dan jumlah pembatalan helper bertambah satu
    Dan client menerima notifikasi beserta tawaran mencari helper lain

  Skenario: Pesanan yang sedang dikerjakan tidak bisa dibatalkan sepihak, kategori Delivery
    # FR-ORD-011, DEC-10
    Diberikan pesanan berkategori Delivery berstatus in_progress
    Ketika client menekan batalkan
    Maka sistem menolak pembatalan langsung
    Dan mengarahkan client ke pengajuan sengketa

  Skenario: Sengketa ditolak untuk kategori selain Delivery
    # FR-ORD-018, DEC-10
    Diberikan pesanan berkategori Household berstatus awaiting_confirmation
    Ketika client mencoba mengajukan sengketa
    Maka sistem menolak dengan pesan bahwa kanal sengketa hanya tersedia untuk kategori Delivery
    Dan client hanya memiliki opsi konfirmasi selesai atau membiarkan batas waktu 24 jam berlalu
```

## 6. Penilaian satu arah

Direvisi 28 Agustus 2026 mengikuti DEC-09. Dua skenario lama soal penilaian tersembunyi dan terbuka setelah tenggat dihapus karena mekanisme dua arah sudah tidak berlaku, digantikan satu skenario penilaian langsung terlihat.

```gherkin
Fitur: Penilaian satu arah
  Skenario: Client memberi penilaian dan langsung terlihat
    # FR-RTG-001, FR-RTG-003
    Diberikan pesanan berstatus completed
    Ketika client memberi penilaian empat bintang dengan ulasan
    Maka penilaian langsung tercatat dan terlihat pada profil helper
    Dan rating rata rata helper diperbarui tanpa masa tunda

  Skenario: Helper tidak memiliki jalur memberi penilaian
    # DEC-09
    Diberikan pesanan berstatus completed
    Ketika helper membuka aplikasi
    Maka tidak ada menu atau tombol untuk menilai client di mana pun pada aplikasi

  Skenario: Pesanan batal tidak bisa dinilai
    # FR-RTG-004
    Diberikan pesanan berstatus cancelled_by_helper
    Ketika client mencoba memberi penilaian
    Maka sistem menolak permintaan tersebut
```

## 6B. Panel admin

Baru ditambahkan 28 Agustus 2026 mengikuti DEC-07. Modul ini belum pernah ditinjau BE, skenario di bawah kemungkinan masih berubah setelah sesi BE.

```gherkin
Fitur: Panel admin
  Skenario: Akun biasa tidak bisa akses panel admin
    # FR-ADM-002
    Diberikan akun Client atau Helper yang tidak bertanda admin
    Ketika akun tersebut mencoba mengakses endpoint atau halaman admin
    Maka sistem menolak dengan kode 403

  Skenario: Admin menyetujui verifikasi
    # FR-ADM-003, FR-ADM-004, FR-ADM-008
    Diberikan pengajuan verifikasi Helper berstatus pending
    Ketika admin menyetujui pengajuan tersebut
    Maka status verifikasi Helper menjadi verified
    Dan Helper tersebut dapat mulai menerima tawaran pesanan
    Dan tercatat satu baris baru di admin_action_log

  Skenario: Admin menolak verifikasi wajib mengisi alasan
    # FR-ADM-004
    Diberikan pengajuan verifikasi Helper berstatus pending
    Ketika admin menolak tanpa mengisi alasan penolakan
    Maka sistem menolak permintaan tersebut

  Skenario: Admin memutuskan sengketa hanya untuk kategori Delivery
    # FR-ADM-005, FR-ADM-006, DEC-10
    Diberikan sengketa masuk untuk pesanan berkategori Delivery
    Ketika admin memutuskan resolusi berpihak pada helper
    Maka dana tertahan dilepas ke helper
    Dan status pesanan menjadi completed

  Skenario: Sengketa untuk kategori selain Delivery tidak pernah muncul di panel admin
    # FR-ADM-005, DEC-10
    Diberikan tidak ada pesanan kategori Delivery yang bersengketa
    Ketika admin membuka daftar sengketa
    Maka daftar tersebut kosong meskipun ada pesanan kategori lain yang bermasalah
```

## 7. Catatan pengujian tambahan untuk QA

Data uji minimum yang perlu disiapkan mencakup satu akun client bersaldo besar, satu akun client bersaldo nol, satu akun helper terverifikasi, satu akun helper yang masih menunggu peninjauan, satu akun yang memegang dua peran sekaligus untuk menguji `INV-05`, dan satu pesanan pada setiap status untuk menguji transisi yang tidak sah.

Pengujian dompet sebaiknya selalu diakhiri dengan pemeriksaan rekonsiliasi, yaitu memastikan jumlah saldo tersedia ditambah saldo tertahan sama dengan hasil penjumlahan seluruh mutasi. Kalau angkanya meleset satu rupiah pun, ada cacat pada logika transaksi meskipun antarmuka terlihat normal.

Pengujian waktu seperti tawaran hangus 60 detik dan konfirmasi otomatis 24 jam sebaiknya dilakukan dengan kemampuan memajukan waktu server di lingkungan pengujian, bukan dengan menunggu sungguhan. Ini perlu diminta ke BE sejak awal supaya tidak menjadi hambatan menjelang UAT.
