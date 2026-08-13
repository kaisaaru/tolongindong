# API Contract Draft

Status dokumen: `REVIEW` v0.1. Cakupan versi ini adalah alur inti pesanan dan dompet. Modul percakapan, notifikasi, dan verifikasi menyusul setelah alur inti disepakati BE.

Base URL pengembangan `https://api.tolongindong.dev/v1`. Seluruh permintaan memakai `Content-Type: application/json`.

## 1. Konvensi umum

Setiap permintaan terautentikasi membawa header `Authorization: Bearer <access_token>`. Setiap permintaan yang mengubah uang atau status pesanan wajib membawa header `X-Idempotency-Key` berisi UUID yang dibuat aplikasi. Server menyimpan kunci itu selama 24 jam dan mengembalikan hasil yang sama untuk kunci yang sama.

Semua respons memakai pembungkus yang seragam supaya Mobile bisa menulis satu penangan saja.

```json
{
  "success": true,
  "message": "Pesanan berhasil dibuat",
  "data": {},
  "meta": { "request_id": "req_9f2c1a", "server_time": "2026-08-12T09:41:00+07:00" }
}
```

Respons gagal memakai bentuk yang sama dengan `success` bernilai salah dan objek galat yang bisa dipetakan ke pesan pengguna.

```json
{
  "success": false,
  "message": "Saldo TD-Wallet kamu tidak mencukupi",
  "error": {
    "code": "WALLET_INSUFFICIENT_BALANCE",
    "detail": { "required": 43000, "available": 21500, "shortage": 21500 }
  },
  "meta": { "request_id": "req_9f2c1b", "server_time": "2026-08-12T09:41:00+07:00" }
}
```

Aturan pemakaian kode status. `200` untuk operasi berhasil, `201` untuk sumber daya baru, `400` untuk kesalahan validasi masukan, `401` untuk token hilang atau kedaluwarsa, `403` untuk pengguna terautentikasi tetapi tidak berhak atas sumber daya itu, `404` untuk sumber daya tidak ditemukan, `409` untuk konflik status seperti pesanan sudah diambil helper lain, `422` untuk aturan bisnis yang dilanggar seperti saldo tidak cukup, `429` untuk permintaan berlebih, dan `500` untuk kesalahan server.

Waktu selalu dikirim dalam format ISO 8601 dengan zona waktu. Mobile tidak boleh memakai jam perangkat untuk menghitung sisa waktu, harus memakai selisih terhadap `meta.server_time`.

## 2. Daftar endpoint alur inti

| ID | Method dan path | Peran yang berhak | Keterangan |
| --- | --- | --- | --- |
| API-ORD-01 | `POST /orders/estimate` | Client | Menghitung estimasi biaya sebelum pesanan dibuat |
| API-ORD-02 | `POST /orders` | Client | Membuat pesanan dan memulai pencarian helper |
| API-ORD-03 | `GET /orders/{id}` | Client dan helper pada pesanan itu | Detail pesanan dan status terkini |
| API-ORD-04 | `POST /orders/{id}/accept` | Helper yang ditawari | Menerima tawaran dan memicu penahanan dana |
| API-ORD-05 | `POST /orders/{id}/status` | Helper pada pesanan itu | Memajukan status pekerjaan |
| API-ORD-06 | `POST /orders/{id}/adjustment` | Helper pada pesanan itu | Mengajukan penyesuaian nilai talangan |
| API-ORD-07 | `POST /orders/{id}/adjustment/respond` | Client pada pesanan itu | Menyetujui atau menolak penyesuaian |
| API-ORD-08 | `POST /orders/{id}/confirm` | Client pada pesanan itu | Mengonfirmasi selesai dan memicu pelepasan dana |
| API-ORD-09 | `POST /orders/{id}/cancel` | Client atau helper pada pesanan itu | Membatalkan dengan aturan biaya menurut status |
| API-HLP-01 | `GET /helpers` | Client | Daftar helper dengan penyaringan dan pengurutan |
| API-WLT-01 | `GET /wallet` | Pemilik dompet | Saldo tersedia dan saldo tertahan |
| API-WLT-02 | `GET /wallet/transactions` | Pemilik dompet | Riwayat mutasi dengan penomoran halaman |
| API-WLT-03 | `POST /wallet/topup` | Pemilik dompet | Pengisian saldo |

## 3. Rincian endpoint kritis

### API-ORD-02 membuat pesanan

`POST /orders`

```json
{
  "category_code": "FOOD_RUN",
  "task_description": "Beli Mie Ayam Tumini 2 porsi, tanpa sambal",
  "pickup_address_id": 12,
  "destination_address_id": 7,
  "scheduled_at": null,
  "advance_limit": 100000,
  "voucher_code": "WELCOME20",
  "assignment_mode": "broadcast",
  "preferred_helper_id": null
}
```

Nilai `assignment_mode` boleh `broadcast` untuk penawaran serentak atau `direct` untuk pemesanan langsung. Kalau bernilai `direct`, `preferred_helper_id` wajib diisi.

Respons `201`.

```json
{
  "success": true,
  "message": "Mencari helper di sekitarmu",
  "data": {
    "order_id": 2942,
    "order_number": "TD-2942",
    "status": "searching",
    "pricing": {
      "base_fee": 15000,
      "distance_fee": 8000,
      "service_fee": 2000,
      "advance_limit": 100000,
      "voucher_discount": 20000,
      "total_hold_amount": 105000
    },
    "search_expires_at": "2026-08-12T09:46:00+07:00"
  }
}
```

Perhatikan bahwa `total_hold_amount` mencakup batas talangan, bukan hanya upah jasa. Ini konsekuensi langsung dari aturan talangan pada dokumen analisis.

Galat yang mungkin muncul: `422 ADDRESS_OUT_OF_SERVICE_AREA` kalau alamat di luar radius layanan, `422 VOUCHER_NOT_ELIGIBLE` kalau voucher tidak memenuhi syarat, `422 WALLET_INSUFFICIENT_BALANCE` kalau saldo tidak cukup untuk penahanan yang direncanakan, dan `409 ACTIVE_ORDER_LIMIT_REACHED` kalau client sudah punya pesanan aktif melebihi batas.

### API-ORD-04 menerima tawaran

`POST /orders/{id}/accept`

Header wajib `X-Idempotency-Key`. Badan permintaan kosong. Server melakukan pengecekan berurutan dalam satu transaksi basis data yaitu memastikan tawaran masih berlaku, memastikan helper bukan pembuat pesanan, memastikan helper tidak sedang memegang pesanan aktif, lalu memindahkan dana client dari saldo tersedia ke saldo tertahan.

Respons `200`.

```json
{
  "success": true,
  "message": "Pesanan diterima, dana client sudah dijamin",
  "data": {
    "order_id": 2942,
    "status": "accepted",
    "client": { "name": "Adi P.", "phone_masked": "0812xxxx9012" },
    "earning_estimate": { "gross": 25000, "platform_commission": 2500, "net": 22500 },
    "hold_reference": "HOLD-2942-01"
  }
}
```

Galat yang mungkin muncul: `409 ORDER_ALREADY_TAKEN` kalau helper lain lebih cepat, `409 OFFER_EXPIRED` kalau hitung mundur habis, `403 SELF_ORDER_NOT_ALLOWED` untuk pelanggaran `INV-05`, `409 HELPER_HAS_ACTIVE_ORDER` untuk pelanggaran `INV-06`, dan `422 CLIENT_INSUFFICIENT_BALANCE` kalau saldo client berubah sejak pesanan dibuat.

### API-ORD-05 memajukan status

`POST /orders/{id}/status`

```json
{
  "to_status": "in_progress",
  "proof_photo_url": null,
  "note": null
}
```

Server menolak transisi yang tidak ada pada state machine dengan `409 INVALID_STATUS_TRANSITION` beserta detail berisi status saat ini dan daftar status berikutnya yang sah. Mobile memakai daftar itu untuk menentukan tombol mana yang ditampilkan, sehingga tidak perlu menyalin aturan transisi ke dalam kode aplikasi.

### API-ORD-08 konfirmasi selesai

`POST /orders/{id}/confirm`

Header wajib `X-Idempotency-Key`. Server melepas dana tertahan, memotong komisi platform, menambah saldo helper, menutup pesanan, dan membuka jendela penilaian. Respons memuat rincian pelepasan supaya bisa langsung ditampilkan.

```json
{
  "success": true,
  "message": "Pesanan selesai",
  "data": {
    "order_id": 2942,
    "status": "completed",
    "settlement": {
      "held_amount": 105000,
      "actual_amount": 43000,
      "refunded_to_client": 62000,
      "platform_commission": 4300,
      "helper_payout": 38700
    },
    "rating_prompt": { "required": true, "expires_at": "2026-08-15T09:41:00+07:00" }
  }
}
```

Angka pada contoh ini menunjukkan bahwa sisa penahanan talangan yang tidak terpakai dikembalikan ke client pada saat penyelesaian, bukan mengendap.

## 4. Catatan untuk Mobile Developer

Tiga hal yang menghemat waktu debug nanti.

Pertama, jangan pernah menyimpan status pesanan sebagai sumber kebenaran di sisi aplikasi. Aplikasi hanya menampilkan status dari server. Kalau butuh pembaruan cepat, pakai polling setiap lima detik pada halaman pelacakan atau sambungan real time kalau BE menyediakannya.

Kedua, buat idempotency key sekali per niat pengguna, bukan sekali per percobaan kirim. Kalau pengguna menekan bayar lalu koneksi gagal dan aplikasi mengulang otomatis, kunci yang dikirim harus tetap sama. Kunci baru hanya dibuat kalau pengguna kembali ke layar dan menekan tombol lagi dari awal.

Ketiga, seluruh pesan galat yang ditampilkan diambil dari peta kode galat lokal, bukan dari `message` server secara langsung. Field `message` berguna untuk pencatatan, tetapi teks yang dilihat pengguna harus dikendalikan tim supaya konsisten dengan `NFR-USE-02`.
