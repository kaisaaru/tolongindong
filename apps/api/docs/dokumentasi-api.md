# 📘 Dokumentasi Teknis Backend Engine — TolonginDong API

Dokumen ini disusun sebagai panduan arsitektur, basis data, aturan bisnis, dan kontrak endpoint resmi bagi seluruh anggota tim (**System Analyst / SA**, **Quality Assurance / QA**, dan **Frontend Mobile / Flutter Developer**).

---

## DAFTAR ISI

1. [Arsitektur & Konvensi Platform](#1-arsitektur--konvensi-platform)
2. [Standar Struktur Respons JSON](#2-standar-struktur-respons-json)
3. [Kamus Basis Data & Model Eloquent (19 Entitas)](#3-kamus-basis-data--model-eloquent-19-entitas)
4. [Daftar Backed Enum PHP](#4-daftar-backed-enum-php)
5. [Rumus Finansial & Invarian Kritis (Untuk SA & QA)](#5-rumus-finansial--invarian-kritis-untuk-sa--qa)
6. [Katalog Endpoint API Lengkap](#6-katalog-endpoint-api-lengkap)
   - [6.1 Autentikasi & Akun Pengguna](#61-autentikasi--akun-pengguna)
   - [6.2 Alamat Pengguna (Addresses)](#62-alamat-pengguna-addresses)
   - [6.3 Dompet TD-Wallet & Ledger](#63-dompet-td-wallet--ledger)
   - [6.4 Kategori Layanan & Pencarian Helper](#64-kategori-layanan--pencarian-helper)
   - [6.5 Siklus Hidup Pesanan & Bidding (Order Lifecycle)](#65-siklus-hidup-pesanan--bidding-order-lifecycle)
   - [6.6 Talangan Belanja (Price Adjustments)](#66-talangan-belanja-price-adjustments)
   - [6.7 Sengketa Pengiriman (Disputes)](#67-sengketa-pengiriman-disputes)
   - [6.8 Penilaian Satu Arah (Ratings)](#68-penilaian-satu-arah-ratings)
   - [6.9 Voucher Promo Platform](#69-voucher-promo-platform)
   - [6.10 Ruang Obrolan Terikat Pesanan (Chat)](#610-ruang-obrolan-terikat-pesanan-chat)
   - [6.11 Pusat Notifikasi Akun](#611-pusat-notifikasi-akun)
   - [6.12 Portal Administrator](#612-portal-administrator)
7. [Panduan Khusus Frontend Mobile (Flutter)](#7-panduan-khusus-frontend-mobile-flutter)

---

## 1. Arsitektur & Konvensi Platform

- **Framework**: Laravel 11 (PHP 8.5+).
- **Database Engine**: PostgreSQL (Supabase) dengan strict integrity constraints.
- **Autentikasi**: Laravel Sanctum (Bearer Token) dengan masa aktif access token **60 menit** (`FR-AUTH-007`).
- **Penyimpanan Berkas Privat (KYC)**: Cloudflare R2 (S3 API compatible) diisolasi per subfolder `verifications/{uuid}/`.
- **Konvensi Routing**: Direct / flat route tanpa prefix `/api/` atau `/v1/` (contoh: `POST /login`, `GET /helpers`, `POST /orders`).
- **Pola Desain**: *Controller-Repository-Service Pattern*. Controller murni bertindak sebagai traffic request & response formatter, sementara mutasi database dibungkus dalam Repository & Domain Services (`SettlementCalculator`, `EscrowService`, `OrderStateMachine`).

---

## 2. Standar Struktur Respons JSON

Seluruh endpoint mematuhi format seragam trait `ApiResponse`:

### A. Respons Berhasil (200 OK / 201 Created)

```json
{
  "success": true,
  "message": "Operasi berhasil",
  "data": { ... },
  "meta": {
    "request_id": "req_a1b2c3d4e5",
    "server_time": "2026-10-01T12:00:00+07:00"
  }
}
```

### B. Respons Gagal (400, 401, 403, 404, 409, 422)

```json
{
  "success": false,
  "message": "Pesan kesalahan yang mudah dipahami manusia",
  "error": {
    "code": "STRING_ERROR_CODE",
    "detail": { ... }
  },
  "meta": {
    "request_id": "req_a1b2c3d4e5",
    "server_time": "2026-10-01T12:00:00+07:00"
  }
}
```

---

## 3. Kamus Basis Data & Model Eloquent (19 Entitas)


| No  | Tabel Database                     | Primary Key | Foreign Key Penting                                               | Keterangan & Invarian Teknis                                                                            |
| :---: | :---------------------------------- | :-----------: | :----------------------------------------------------------------- | :----------------------------------------------------------------------------------------------------------- |
| 1   | `users`                            | UUID v4     | -                                                                 | Menyimpan akun Client, Helper, & Admin. Memuat `is_admin`, `is_suspended`, `verification_status`.       |
| 2   | `wallets`                          | Bigint      | `user_id` (UUID)                                                  | Dompet TD-Wallet. Constraint `chk_wallet_nonneg`: `available_balance >= 0 AND held_balance >= 0`.           |
| 3   | `wallet_transactions`              | Bigint      | `wallet_id`, `order_id` (nullable)                                | Buku besar mutasi atomik (*append-only*). Membawa `idempotency_key UK` (`INV-04`).                          |
| 4   | `otps`                             | Bigint      | -                                                                 | Penyimpanan kode OTP verifikasi HP 6-digit (TTL 300 detik) untuk registrasi & reset sandi.              |
| 5   | `service_categories`               | Bigint      | -                                                                 | 6 Kategori resmi platform. Memuat flag `requires_advance`, `requires_pickup_photo`, `is_dispute_eligible`.  |
| 6   | `helper_profiles`                  | UUID v4     | `user_id` (UUID)                                                  | Profil operasional helper. Memuat `hourly_rate`, `is_available` (`available`/`unavailable`), `approved_at`. |
| 7   | `helper_service_category`          | Composite   | `helper_profile_id`, `service_category_id`                        | Pivot many-to-many keahlian helper (1 sampai 6 kategori, `FR-HLP-008`).                                     |
| 8   | `verification_requests`            | UUID v4     | `user_id`, `reviewed_by_admin_id`                                 | Tiket KYC identitas (KTP + selfie). Partial unique index: maksimal 1 tiket `pending` per user.              |
| 9   | `addresses`                        | Bigint      | `user_id` (UUID)                                                  | Alamat client (max 10 alamat, `DEC-14 no 9`). Koordinat lat/lon, landmark, dan `is_primary`.                |
| 10  | `orders`                           | Bigint      | `client_id`, `helper_id`, `category_id`, `pickup/dest_address_id` | Entitas transaksi inti. Memuat 4 konsep uang (`DEC-15`), `order_number UK`, 17 status lifecycle.            |
| 11  | `order_offers`                     | Bigint      | `order_id`, `helper_id`                                           | Penawaran harga / quote. Unique `(order_id, helper_id)`, batas quote 300s & konfirmasi 60s.             |
| 12  | `order_status_history`             | Bigint      | `order_id`, `changed_by_user_id`                                  | Audit trail perubahan status tahapan pesanan (*append-only*).                                               |
| 13  | `order_attachments`                | Bigint      | `order_id`, `uploader_user_id`                                    | Berkas foto penjemputan (`pickup_proof`), penyelesaian (`completion_proof`), dan struk (`receipt`).         |
| 14  | `price_adjustments`                | Bigint      | `order_id`, `receipt_attachment_id`                               | Verifikasi struk talangan belanja Food Run & Laundry. Partial unique index: 1 pending per order.        |
| 15  | `disputes`                         | Bigint      | `order_id`, `raised_by_user_id`, `resolved_by_admin_id`           | Kanal sengketa resmi khusus kategori Delivery dalam 24 jam pasca selesai (`DEC-10`).                        |
| 16  | `ratings`                          | Bigint      | `order_id`, `client_id`, `helper_id`                              | Penilaian satu arah client ke helper (skor 1–5). Unique index: 1 rating per order (`INV-08`).               |
| 17  | `vouchers`                         | Bigint      | `category_id` (nullable)                                          | Voucher promo platform. Validasi keras komisi 10x dan 10% (`DEC-23`).                                       |
| 18  | `user_vouchers`                    | Bigint      | `user_id`, `voucher_id`, `used_order_id` (nullable)               | Kepemilikan voucher. Partial unique index: maksimal 1 voucher per pesanan (`INV-12`).                       |
| 19  | `chat_rooms` & `chat_messages` | Bigint      | `order_id`, `chat_room_id`, `sender_user_id`                      | Obrolan terikat pesanan. Chat room dibuat otomatis saat pesanan `accepted` (`DEC-14 no 10`).                |
| 20  | `notifications`                    | Bigint      | `user_id`, `reference_order_id` (nullable)                        | Pusat notifikasi aktivitas, mutasi saldo, tawaran masuk, dan promo.                                         |
| 21  | `admin_action_logs`                | Bigint      | `admin_user_id` (UUID)                                            | Buku besar audit seluruh aksi administrator operasional (`FR-ADM-008`).                                     |


---

## 4. Daftar Backed Enum PHP


| Nama Enum                   | Lokasi File                           | Nilai String yang Sah                                                                                                                                                                                                                                                                                     |
| :--------------------------- | :------------------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`OrderStatus`**           | `app/Enums/OrderStatus.php`           | `draft`, `searching`, `awaiting_quote`, `pending_confirmation`, `accepted`, `on_the_way`, `arrived`, `in_progress`, `price_adjustment`, `awaiting_confirmation`, `completed`, `cancelled_by_client`, `cancelled_by_helper`, `cancelled_by_admin`, `expired`, `disputed`, `refunded`, `partially_refunded` |
| **`BookingType`**           | `app/Enums/BookingType.php`           | `broadcast`, `direct`                                                                                                                                                                                                                                                                                     |
| **`OrderOfferStatus`**      | `app/Enums/OrderOfferStatus.php`      | `submitted`, `selected`, `confirmed`, `not_selected`, `withdrawn`, `expired`, `declined`                                                                                                                                                                                                                  |
| **`HelperAvailability`**    | `app/Enums/HelperAvailability.php`    | `available`, `unavailable`                                                                                                                                                                                                                                                                                |
| **`TransactionType`**       | `app/Enums/TransactionType.php`       | `topup`, `hold`, `release`, `advance_reimbursement`, `refund`, `payout`, `cancellation_fee`                                                                                                                                                                                                               |
| **`PriceAdjustmentStatus`** | `app/Enums/PriceAdjustmentStatus.php` | `pending`, `approved`, `rejected`, `auto_approved`                                                                                                                                                                                                                                                        |
| **`DisputeResolution`**     | `app/Enums/DisputeResolution.php`     | `pending`, `favor_client`, `favor_helper`, `split`                                                                                                                                                                                                                                                        |
| **`DiscountType`**          | `app/Enums/DiscountType.php`          | `fixed`, `percentage`                                                                                                                                                                                                                                                                                     |
| **`NotificationType`**      | `app/Enums/NotificationType.php`      | `order_offer`, `order_status_change`, `chat_message`, `dispute_update`, `wallet_mutation`, `promo`                                                                                                                                                                                                        |
| **`AttachmentType`**        | `app/Enums/AttachmentType.php`        | `pickup_proof`, `completion_proof`, `dispute_evidence`, `receipt`                                                                                                                                                                                                                                         |
| **`AdminActionType`**       | `app/Enums/AdminActionType.php`       | `approve_verification`, `reject_verification`, `resolve_dispute`, `suspend_account`, `reactivate_account`, `cancel_order`, `create_voucher`, `update_voucher`, `deactivate_voucher`                                                                                                                       |


---

## 5. Rumus Finansial & Invarian Kritis (Untuk SA & QA)

Dikelola secara deterministik oleh kelas murni `App\Services\SettlementCalculator`:

### A. Alokasi Saat Dana Ditahan (Escrow Hold)
- `gross_commission` = floor(total_amount * 10%)
- `voucher_discount` = min(nilai_voucher, gross_commission)
- `service_client_charge` = total_amount - voucher_discount
- `held_amount` = service_client_charge + advance_limit

### B. Alokasi Saat Pesanan Selesai (Completed / Favor Helper)
- `helper_payout` = total_amount - gross_commission (upah jasa bersih 90%)
- `platform_commission` = max(0, gross_commission - voucher_discount)
- `helper_release` = helper_payout + advance_actual
- `client_refund` = held_amount - helper_release - platform_commission

### C. Alokasi Putusan Sengketa Dibagi Dua (Split 50:50 — Turunan SA #8)
- `helper_release` = floor(held_amount / 2) (selisih Rp1 menjadi milik client)
- `client_refund` = held_amount - helper_release
- `platform_commission` = 0

### D. Invarian Konservasi Dana Mutlak
- `helper_release + platform_commission + client_refund == held_amount`

### E. Aturan Denda Pembatalan Pesanan (FR-ORD-011, DEC-19)
- Status `searching`, `awaiting_quote`, `pending_confirmation`: Rp 0 (Gratis)
- Status `accepted` durasi kurang dari 120 detik: Rp 0 (Gratis)
- Status `accepted` durasi 120 detik atau lebih: Rp 5.000
- Status `on_the_way` dan `arrived`: 25% dari total_amount
- Status `in_progress`: Tidak dapat dibatalkan sepihak oleh client
- Batas Maksimal Denda (Turunan SA #7): Denda dibatasi maksimal tidak boleh melebihi `service_client_charge`

---

## 6. Katalog Endpoint API Lengkap

### 6.1 Autentikasi & Akun Pengguna

#### 1. Registrasi Akun Manual

- **Route**: `POST /register`
- **Akses**: Publik
- **Body**:
  ```json
  {
    "full_name": "Rian Pratama",
    "email": "rian@example.com",
    "phone_number": "081234567890",
    "password": "Password123!"
  }
  ```
- **Respons (201)**: Mengirimkan info OTP 6-digit kedaluwarsa 300 detik.

#### 2. Verifikasi OTP Registrasi

- **Route**: `POST /verify-otp`
- **Akses**: Publik
- **Body**:
  ```json
  {
    "phone_number": "081234567890",
    "otp_code": "123456"
  }
  ```
- **Respons (200)**: Token Sanctum + auto-provisioning dompet TD-Wallet saldo 0.

#### 3. Login Pengguna

- **Route**: `POST /login`
- **Akses**: Publik
- **Body**:
  ```json
  {
    "identifier": "081234567890", // Bisa nomor HP atau email
    "password": "Password123!"
  }
  ```
- **Respons (200)**: Token Sanctum + profil user + info dompet.
- **Proteksi**: Lockout 900 detik (15 menit) setelah 5 kali gagal (`FR-AUTH-005`).

#### 4. Login Google OAuth

- **Route**: `POST /google`
- **Akses**: Publik
- **Body**: `{ "id_token": "google_jwt_token_or_mock" }`

#### 5. Pemulihan Sandi (Lupa Password)

- **Route**: `POST /password/forgot`
- **Body**: `{ "phone_number": "081234567890" }`

#### 6. Reset Sandi Baru

- **Route**: `POST /password/reset`
- **Body**: `{ "phone_number": "081234567890", "otp_code": "123456", "password": "NewPassword123!" }`

#### 7. Profil User Aktif

- **Route**: `GET /me`
- **Akses**: Bearer Token
- **Respons (200)**: Mengembalikan data akun, wallet, status verifikasi, dan status helper.

---

### 6.2 Alamat Pengguna (Addresses)

Semua endpoint membutuhkan header `Authorization: Bearer <token>`.

- **`GET /addresses`**: Daftar semua alamat pengguna (alamat utama `is_primary = true` selalu di urutan teratas).
- **`POST /addresses`**: Tambah alamat baru (maksimal 10 alamat per user `FR-PRF-002`, alamat pertama otomatis `is_primary = true`).
  ```json
  {
    "label": "Rumah",
    "full_address": "Jl. Kaliurang KM 5, Gang Pandega Marta No. 12",
    "latitude": -7.75543210,
    "longitude": 110.37891234,
    "landmark_note": "Pagar hitam seberang warung",
    "is_primary": true
  }
  ```
- **`GET /addresses/{id}`**: Detail satu alamat.
- **`PUT /addresses/{id}`**: Ubah data alamat.
- **`DELETE /addresses/{id}`**: Hapus alamat (jika alamat utama dihapus, alamat berikutnya otomatis dipromosikan jadi utama).
- **`POST /addresses/{id}/primary`**: Setel alamat tersebut sebagai alamat utama.

---

### 6.3 Dompet TD-Wallet & Ledger

- **`GET /wallet`** (`API-WLT-01`):
  ```json
  {
    "available_balance": 150000,
    "held_balance": 50000,
    "total_balance": 200000,
    "currency": "IDR"
  }
  ```
- **`GET /wallet/transactions?per_page=15`** (`API-WLT-02`): Riwayat mutasi terpaginasi (*append-only*).
- **`POST /wallet/topup`** (`API-WLT-03`):
  - **Header Opsional**: `X-Idempotency-Key: uuid-string`
  - **Body**:
    ```json
    {
      "amount": 50000, // Minimal Rp 10.000 (FR-WLT-006)
      "description": "Pengisian saldo via bank transfer simulasi"
    }
    ```

---

### 6.4 Kategori Layanan & Pencarian Helper

#### 1. Daftar 6 Kategori Layanan

- **Route**: `GET /service-categories`
- **Akses**: Publik
- **Fitur Respons**: Mengembalikan flag `requires_advance`, `requires_pickup_photo`, `is_dispute_eligible`, dan `location_label` ("Lokasi pengerjaan" untuk Personal/Household, "Alamat tujuan" untuk lainnya).

#### 2. Cari Helper Terdekat (Radius 10 km)

- **Route**: `GET /helpers` (`API-HLP-01`)
- **Akses**: Bearer Token
- **Query Params**:
  - `latitude`: float (opsional, fallback ke alamat utama client)
  - `longitude`: float (opsional)
  - `category_id`: int (opsional, filter keahlian)
  - `sort_by`: `distance` (terdekat), `rating` (tertinggi), `rate` (termurah)
- **Respons (200)**:
  ```json
  {
    "data": {
      "helpers": [
        {
          "id": "uuid-helper-profile",
          "user_id": "uuid-user",
          "full_name": "Budi Santoso",
          "photo_url": "https://...",
          "rating_average": 4.9,
          "rating_count": 25,
          "hourly_rate": 20000,
          "max_advance_limit": 100000,
          "is_available": "available",
          "distance_km": 1.82,
          "categories": [{ "id": 1, "code": "food_run", "name": "Food Run" }]
        }
      ],
      "total_available_in_radius": 1
    }
  }
  ```

#### 3. Update Profil Operasional Helper

- **Route**: `PUT /helper/profile` (`FR-HLP-008, 009`)
- **Akses**: Helper Terverifikasi
- **Body**:
  ```json
  {
    "is_available": "available", // atau "unavailable" untuk libur
    "hourly_rate": 25000,
    "max_advance_limit": 150000,
    "category_ids": [1, 2] // 1 sampai 6 kategori tanpa re-KYC KTP
  }
  ```

---

### 6.5 Siklus Hidup Pesanan & Bidding (Order Lifecycle)

#### 1. Estimasi Acuan Biaya

- **Route**: `POST /orders/estimate` (`API-ORD-01`)
- **Body**:
  ```json
  {
    "category_id": 1,
    "pickup_address_id": 1,
    "destination_address_id": 2
  }
  ```

#### 2. Buat Pesanan

- **Route**: `POST /orders` (`API-ORD-02`)
- **Body (Broadcast)**:
  ```json
  {
    "category_id": 1,
    "booking_type": "broadcast",
    "task_description": "Tolong belikan nasi goreng di jl kaliurang km 5",
    "pickup_address_id": 1,
    "destination_address_id": 2,
    "client_estimated_price": 20000,
    "advance_limit": 50000 // Wajib jika category.requires_advance = true
  }
  ```
- **Body (Direct Booking)**:
  ```json
  {
    "category_id": 3,
    "booking_type": "direct",
    "helper_id": "uuid-helper-profile",
    "task_description": "Bantu angkat lemari kamar kos"
  }
  ```

#### 3. Helper Mengajukan Tawaran / Quote

- **Route**: `POST /orders/{id}/offers` (`API-ORD-04A`)
- **Akses**: Helper Terverifikasi
- **Body**: `{ "proposed_price": 22000, "message": "Siap meluncur sekarang" }`

#### 4. Client Memilih Tawaran

- **Route**: `POST /orders/{id}/offers/{offer_id}/select` (`API-ORD-04C`)
- **Alur**:
  - Broadcast: Status pesanan menjadi `pending_confirmation`, memberi helper terpilih 60 detik.
  - Direct Booking: Langsung menahan saldo escrow client dan pesanan berstatus `accepted`.

#### 5. Helper Konfirmasi Kesiapan (Khusus Broadcast)

- **Route**: `POST /orders/{id}/offers/{offer_id}/confirm` (`API-ORD-04D`)
- **Efek**: Menahan saldo escrow client (`HOLD`), pesanan menjadi `accepted`, chat room aktif.

#### 6. Helper Memajukan Tahapan Progres

- **Route**: `POST /orders/{id}/status` (`API-ORD-05`)
- **Body**: `{ "status": "on_the_way" }` (Urutan: `on_the_way` -> `arrived` -> `in_progress` -> `awaiting_confirmation`).

#### 7. Client Konfirmasi Selesai & Settlement

- **Route**: `POST /orders/{id}/confirm` (`API-ORD-08`)
- **Efek**: Melepas hak upah bersih 90% ke dompet helper, mencatat komisi platform 10%, dan mengembalikan sisa talangan ke client.

#### 8. Pembatalan Pesanan

- **Route**: `POST /orders/{id}/cancel` (`API-ORD-09`)
- **Body**: `{ "reason": "Ada urusan mendadak" }`
- **Efek**: Menghitung denda kompensasi helper otomatis sesuai status pesanan (`FR-ORD-011`).

---

### 6.6 Talangan Belanja (Price Adjustments)

Khusus pesanan bertalangan (**Food Run** dan **Laundry**):

- **`POST /orders/{id}/adjustments`** (`API-ORD-06`): Helper mengunggah nominal struk (`requested_amount`) dan URL struk (`receipt_url`).
  - Jika <= advance_limit: Otomatis `auto_approved`, pesanan tetap `in_progress`.
  - Jika > advance_limit: Berstatus `pending`, status pesanan beralih ke `price_adjustment`.
- **`POST /orders/{id}/adjustments/{adj_id}/respond`** (`API-ORD-07`): Client merespons kelebihan belanja:
  - `{ "action": "approved" }`: Menahan tambahan saldo dari client, struk diakui penuh, pesanan kembali ke `in_progress`.
  - `{ "action": "rejected" }`: Diakui sebatas sisa limit awal (`DEC-20`), selisih lebih jadi risiko helper, pesanan kembali ke `in_progress`.

---

### 6.7 Sengketa Pengiriman (Disputes)

Khusus pesanan kategori **Delivery** dalam 24 jam pasca selesai:

- **`POST /orders/{id}/disputes`** (`API-ORD-12`): Client atau helper mengajukan sengketa barang rusak/hilang (`reason`). Status pesanan menjadi `disputed`.
- **`GET /admin/disputes?status=pending`** (`API-ADM-05`): Admin melihat antrean sengketa.
- **`POST /admin/disputes/{id}/resolve`** (`API-ADM-06`): Putusan admin:
  - `{ "resolution": "favor_client", "admin_note": "..." }`: Refund 100% saldo ke client (`refunded`).
  - `{ "resolution": "favor_helper", "admin_note": "..." }`: Settlement normal ke helper (`completed`).
  - `{ "resolution": "split", "admin_note": "..." }`: Dana dibagi 50:50 tanpa komisi (`partially_refunded`).

---

### 6.8 Penilaian Satu Arah (Ratings)

- **`POST /orders/{id}/rating`** (`FR-RTG-001`, `DEC-09`):
  - **Akses**: Client pada pesanan berstatus `completed`.
  - **Body**:
    ```json
    {
      "score": 5, // 1 sampai 5 bintang
      "review": "Kerja cepat dan barang diantar dengan selamat."
    }
    ```
  - **Efek**: Otomatis memperbarui `rating_average` dan `rating_count` pada profil helper.

---

### 6.9 Voucher Promo Platform

- **`POST /admin/vouchers`** (`API-ADM-12`, `FR-ADM-012`):
  - Admin membuat voucher. Validasi keras (`DEC-23`):
    - Tipe `fixed`: Wajib `min_order_amount >= discount_value * 10`.
    - Tipe `percentage`: Wajib `discount_value <= 10` (maksimal 10%).
- **`GET /admin/vouchers`** (`API-ADM-11`): Daftar seluruh voucher dan kuota terpakai.
- **`PATCH /admin/vouchers/{id}`** (`API-ADM-13`): Menonaktifkan voucher (`{ "is_active": false }`).
- **`GET /vouchers`** (`FR-WLT-010`): Client melihat voucher aktif yang belum dipakai.
- **`POST /vouchers/claim`**: Client klaim voucher menggunakan kode promo (`{ "code": "HEMAT5K" }`).

---

### 6.10 Ruang Obrolan Terikat Pesanan (Chat)

- **`GET /orders/{id}/messages`** (`FR-CHT-002`): Riwayat obrolan (hanya aktif jika pesanan sudah `accepted`, otomatis menandai pesan lawan bicara sebagai dibaca).
- **`POST /orders/{id}/messages`** (`FR-CHT-001`): Kirim pesan teks dan lampiran URL opsional:
  ```json
  {
    "content": "Halo, saya sudah sampai di depan gang ya kak.",
    "attachment_url": null
  }
  ```

---

### 6.11 Pusat Notifikasi Akun

- **`GET /notifications`** (`FR-NOT-001`): Daftar notifikasi dengan angka `unread_count`.
- **`POST /notifications/{id}/read`**: Tandai 1 notifikasi telah dibaca.
- **`POST /notifications/read-all`**: Tandai seluruh notifikasi telah dibaca.

---

### 6.12 Portal Administrator

Semua rute admin berada di bawah prefix `/admin/*` dan dilindungi middleware `['auth:sanctum', 'admin']`.

- **`POST /admin/auth/login`** (`API-ADM-01`): Jalur login terpisah khusus akun bertanda `is_admin = true`.
- **`GET /admin/dashboard`**: Ringkasan total pengguna, helper terverifikasi, dan tiket pending.
- **`GET /admin/verifications?status=pending`**: Antrean tiket KYC helper.
- **`POST /admin/verifications/{id}/approve`**: Persetujuan helper (`is_available` aktif menjadi `available`).
- **`POST /admin/verifications/{id}/reject`**: Penolakan KYC wajib menyertakan alasan (`rejection_reason`).
- **`POST /admin/users/{id}/suspend`** (`API-ADM-08`): Membekukan akun (ditolak jika memiliki pesanan aktif berjalan).
- **`POST /admin/users/{id}/reactivate`** (`API-ADM-09`): Mengaktifkan kembali akun.
- **`POST /admin/orders/{id}/cancel`** (`API-ADM-10`): Pembatalan pesanan darurat oleh admin (dana kembali penuh ke client, status `cancelled_by_admin`).
- **`GET /admin/commission-summary`** (`API-ADM-07`): Agregat pendapatan komisi platform 10% dengan rincian per kategori dan filter tanggal.

---

## 7. Panduan Khusus Frontend Mobile (Flutter)

1. **Format Header Global**:
   - Seluruh request terautentikasi wajib menyertakan:
    `Authorization: Bearer <access_token>`
    `Accept: application/json`
2. **Idempotency Key Transaksi Dompet**:
   - Untuk mencegah saldo terpotong ganda saat sinyal seluler tidak stabil, selalu sertakan header:
    `X-Idempotency-Key: <uuid_v4>` pada `POST /wallet/topup`.
3. **Penanganan Error Code (`error.code`)**:
   - Jangan melakukan *hardcoded string matching* pada field `message`. Gunakan nilai pasti pada `error.code`, contohnya:
     - `INSUFFICIENT_BALANCE`: Arahkan client ke layar top-up dompet.
     - `ACTIVE_ORDERS_EXIST`: Peringatkan admin bahwa akun masih memiliki transaksi berjalan.
     - `VOUCHER_EXCEEDS_COMMISSION`: Beri tahu admin bahwa diskon melebihi batas subsidi.
4. **Visualisasi Pelacakan Status Tanpa Live GPS**:
   - Sesuai keputusan `DEC-06`, antarmuka pelacakan tidak membutuhkan map streaming bergerak. Renderlah menggunakan **Status Stepper UI** yang merefleksikan nilai string pada `order.status`.
5. **Perhitungan Waktu**:
   - Seluruh timestamp dipertukarkan dalam format standar **ISO 8601** UTC (`YYYY-MM-DDTHH:mm:ssZ`).

