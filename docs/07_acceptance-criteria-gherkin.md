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
Fitur: Penahanan dana saat helper menerima
  Skenario: Dana berpindah dari saldo tersedia ke saldo tertahan
    # FR-WLT-002
    Diberikan saldo tersedia client adalah Rp 200.000 dan saldo tertahan Rp 0
    Dan ada pesanan senilai Rp 105.000 berstatus searching
    Ketika helper menerima pesanan tersebut
    Maka saldo tersedia client menjadi Rp 95.000
    Dan saldo tertahan client menjadi Rp 105.000
    Dan jumlah keduanya tetap Rp 200.000
    Dan tercipta satu baris mutasi bertipe hold

  Skenario: Dua helper menerima hampir bersamaan
    # FR-ORD-004, INV-03
    Diberikan pesanan ditawarkan ke helper A dan helper B
    Ketika keduanya menekan terima dalam selisih waktu di bawah satu detik
    Maka tepat satu helper mendapat respons berhasil
    Dan helper lainnya mendapat kode ORDER_ALREADY_TAKEN
    Dan hanya ada satu baris penahanan dana untuk pesanan itu

  Skenario: Pengguna tidak bisa menerima pesanannya sendiri
    # FR-ORD-016, INV-05
    Diberikan seorang pengguna yang berstatus helper terverifikasi membuat pesanan sebagai client
    Ketika pengguna tersebut mencoba menerima pesanannya sendiri
    Maka sistem menolak dengan kode SELF_ORDER_NOT_ALLOWED
    Dan pesanan tetap berstatus searching

  Skenario: Permintaan terima dikirim ulang karena jaringan buruk
    # FR-WLT-009, INV-04
    Diberikan helper menekan terima dan permintaan gagal karena waktu habis di sisi jaringan
    Ketika aplikasi mengirim ulang permintaan dengan idempotency key yang sama
    Maka sistem mengembalikan hasil penerimaan yang pertama
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

  Skenario: Pesanan yang sedang dikerjakan tidak bisa dibatalkan sepihak
    # FR-ORD-011
    Diberikan pesanan berstatus in_progress
    Ketika client menekan batalkan
    Maka sistem menolak pembatalan langsung
    Dan mengarahkan client ke pengajuan sengketa
```

## 6. Penilaian dua arah

```gherkin
Fitur: Penilaian dua arah
  Skenario: Penilaian disembunyikan sampai keduanya mengisi
    # FR-RTG-002
    Diberikan pesanan berstatus completed
    Dan client sudah memberi penilaian tiga bintang
    Ketika helper membuka halaman ulasan sebelum ia sendiri menilai
    Maka helper tidak dapat melihat isi penilaian client

  Skenario: Penilaian terbuka setelah tenggat
    # FR-RTG-002
    Diberikan hanya client yang memberi penilaian
    Ketika 72 jam berlalu sejak pesanan selesai
    Maka penilaian client menjadi terlihat
    Dan rating rata rata helper diperbarui

  Skenario: Pesanan batal tidak bisa dinilai
    # FR-RTG-004
    Diberikan pesanan berstatus cancelled_by_helper
    Ketika client mencoba memberi penilaian
    Maka sistem menolak permintaan tersebut
```

## 7. Catatan pengujian tambahan untuk QA

Data uji minimum yang perlu disiapkan mencakup satu akun client bersaldo besar, satu akun client bersaldo nol, satu akun helper terverifikasi, satu akun helper yang masih menunggu peninjauan, satu akun yang memegang dua peran sekaligus untuk menguji `INV-05`, dan satu pesanan pada setiap status untuk menguji transisi yang tidak sah.

Pengujian dompet sebaiknya selalu diakhiri dengan pemeriksaan rekonsiliasi, yaitu memastikan jumlah saldo tersedia ditambah saldo tertahan sama dengan hasil penjumlahan seluruh mutasi. Kalau angkanya meleset satu rupiah pun, ada cacat pada logika transaksi meskipun antarmuka terlihat normal.

Pengujian waktu seperti tawaran hangus 60 detik dan konfirmasi otomatis 24 jam sebaiknya dilakukan dengan kemampuan memajukan waktu server di lingkungan pengujian, bukan dengan menunggu sungguhan. Ini perlu diminta ke BE sejak awal supaya tidak menjadi hambatan menjelang UAT.
