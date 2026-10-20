# 📋 Handover Context: TolonginDong Backend API Engine

**Dokumen Rangkuman Kerja & Panduan Sesi Lanjutan**
*Disusun untuk AI Agent atau Developer berikutnya agar langsung memahami konteks proyek secara utuh.*

---

## 1. Status Terkini Repositori & Git Branches

Proyek ini telah mengimplementasikan **100% fungsionalitas backend dan aturan bisnis** sesuai spesifikasi System Analyst (`tolongindong-docs` v0.3).

### Pohon Cabang (Git Branches) & Pull Requests:
1. **`main`**: Branch produksi dasar.
2. **`dev`**: Branch integrasi pengembangan utama.
3. **`feat/backend-auth`**:
   - Telah di-push ke remote.
   - **PR #5** (Open): `feat(auth,admin): align authentication, admin authorization, and schema with SRS v0.3` (3 commit: auth admin, skema enum/log, dan test).
4. **`feat/user-addresses`**:
   - Telah di-push ke remote.
   - Memuat 2 commit:
     - `03ca145` (`feat(address)`: modul alamat, batas 10 alamat, primary address management).
     - `9a35631` (`feat(wallet)`: buku besar `wallet_transactions`, constraint non-negatif, top-up atomik & idempotency).
5. **`feat/order-lifecycle`**:
   - Telah di-push ke remote.
   - Memuat 6 commit:
     - `5912d0d` (`feat(helper)`: pencarian helper Haversine 10 km, toggle profile ketersediaan).
     - `1a2170f` (`feat(schema)`: migrasi 7 tabel order, offers, attachments, history, price adjustments, disputes, ratings).
     - `895247c` (`feat(models)`: enums dan model domain order, offers, attachments, disputes, ratings).
     - `00f0401` (`feat(services)`: `SettlementCalculator` POPO, `OrderStateMachine`, `EscrowService`).
     - `587b286` (`feat(order)`: `OrderRepository`, `OrderController`, `Admin\DisputeController`, routes).
     - `47a26a4` (`test(api)`: `OrderLifecycleTest` dan `OrderAdvancedFeaturesTest`).
6. **`feat/platform-extensions` (BRANCH AKTIF SAAT INI)**:
   - Cabang ujung yang memuat seluruh commit dari branch-branch sebelumnya.
   - **PR #6** (Open ke `dev`): `feat(core): implement complete transaction lifecycle, platform extensions, and unified api documentation` (8.715 additions, 8 deletions).
   - Memuat 5 commit bertahap:
     - `0ab01e8` (`feat(admin)`: suspend bebas order aktif, reactivate, admin emergency cancel order, commission summary).
     - `0b0d365` (`feat(voucher)`: skema voucher, validasi keras 10x & 10% `DEC-23`, klaim voucher).
     - `63ed9a6` (`feat(chat,notification)`: chat room terikat order accepted, pesan, pusat notifikasi).
     - `61b39b9` (`test(api)`: test suite admin operations, vouchers, chat & notifikasi).
     - `5a8fa58` (`docs(api)`: dokumentasi terpadu `dokumentasi-api.md`).
   - *Catatan File Uncommitted di Branch Ini*: File `dokumentasi-api.md` (revisi rumus bebas LaTeX KaTeX) dalam status modified menunggu commit final.

---

## 2. Arsitektur & Prinsip Desain yang Diterapkan

- **Stack**: Laravel 11, PHP 8.5+, PostgreSQL Supabase, Cloudflare R2, Laravel Sanctum (access token 60 menit, `FR-AUTH-007`).
- **Routing Direct**: Seluruh rute flat tanpa prefix `/api/` (misal: `/register`, `/helpers`, `/orders`, `/wallet`).
- **Pola Arsitektur**: *Controller -> Repository & Domain Services -> Eloquent Models*.
  - Controller langsing (*Skinny Controller*) murni menerima input HTTP dan mengembalikan `ApiResponse`.
  - Logika transaksi database, row-locking atomik, dan kalkulasi uang terisolasi di Repository dan Services.
- **Integritas ID**: Menggunakan **UUID v4** (`HasUuids`) pada entitas utama (`users`, `helper_profiles`, `verification_requests`).
- **Invarian Keuangan**:
  - Saldo tidak boleh negatif (`wallets` check constraint: `available_balance >= 0 AND held_balance >= 0`).
  - Row-locking atomik `SELECT ... FOR UPDATE` (`INV-02`) saat penahanan (`HOLD`), pelepasan (`RELEASE`), dan pengembalian (`REFUND`).
  - Proteksi request ganda melalui `X-Idempotency-Key` unik (`INV-04`, `FR-WLT-009`).

---

## 3. Rangkuman Seluruh Modul yang Telah Selesai (100% Complete)

### Modul 1: Autentikasi, Profil & Keamanan Admin
- **File**: `AuthController.php`, `Admin\AuthController.php`, `AuthRepository.php`, `EnsureUserIsAdmin.php`.
- **Fitur**:
  - Registrasi akun (nama, email, no HP, sandi).
  - OTP 6-digit verifikasi nomor HP (TTL 300 detik) + auto-provisioning dompet TD-Wallet saldo nol.
  - Login manual dengan proteksi brute force (kunci 900 detik setelah 5 kegagalan).
  - Login Google OAuth (asli atau mock simulator).
  - Pemulihan sandi via OTP (`/password/forgot`, `/password/reset`).
  - Login terpisah khusus admin (`POST /admin/auth/login`, API-ADM-01).
  - Middleware `EnsureUserIsAdmin` (`admin`) melindungi seluruh route `/admin/*` (`FR-ADM-002`).

### Modul 2: Helper KYC & Verifikasi Identitas
- **File**: `HelperController.php`, `HelperRepository.php`, `Admin\VerificationController.php`, `VerificationRepository.php`.
- **Fitur**:
  - Pendaftaran helper: upload KTP & selfie ke folder privat Cloudflare R2 (`verifications/{uuid}/`).
  - Pilih 1–6 kategori layanan (`FR-HLP-008`).
  - Partial unique index: maksimal 1 tiket KYC `pending` per user. Jika ditolak, boleh daftar ulang instan tanpa cooldown (`FR-VER-007`).
  - Admin approval/rejection (wajib alasan penolakan, mencatat riwayat ke `admin_action_logs`).
  - Penyelarasan ketersediaan helper ke Backed Enum `HelperAvailability` (`available` / `unavailable`, `DEC-16`).

### Modul 3: Alamat Pengguna (Addresses)
- **File**: `AddressController.php`, `AddressRepository.php`, `Address.php`.
- **Fitur**:
  - CRUD alamat pengguna lengkap.
  - Batas maksimal 10 alamat per pengguna (`FR-PRF-002`, `DEC-14 no 9`).
  - Alamat pertama otomatis menjadi alamat utama (`is_primary = true`, `FR-PRF-003`).
  - Endpoint manual set primary (`POST /addresses/{id}/primary`).
  - Jika alamat utama dihapus, alamat terbaru berikutnya otomatis dipromosikan jadi utama.

### Modul 4: Dompet TD-Wallet & Buku Besar Mutasi
- **File**: `WalletController.php`, `WalletRepository.php`, `Wallet.php`, `WalletTransaction.php`, `TransactionType.php`.
- **Fitur**:
  - Informasi saldo tersedia dan tertahan (`GET /wallet`, API-WLT-01).
  - Riwayat mutasi transaksi terpaginasi (*append-only ledger*, `GET /wallet/transactions`, API-WLT-02).
  - Simulasi isi saldo (`POST /wallet/topup`, API-WLT-03) minimal Rp 10.000 dengan row locking dan proteksi idempotency key.

### Modul 5: Kategori Layanan & Pencarian Helper
- **File**: `ServiceCategoryController.php`, `HelperController.php`, `HelperRepository.php`, `ServiceCategory.php`.
- **Fitur**:
  - Daftar 6 kategori layanan resmi dengan flag `requires_advance`, `requires_pickup_photo`, `is_dispute_eligible`, dan `location_label` dinamis ("Lokasi pengerjaan" untuk Personal/Household).
  - Pencarian helper terdekat (`GET /helpers`, API-HLP-01): formula Haversine lurus, batas radius maksimal 10 km (`FR-HLP-005`), filter kategori, sortir jarak/rating/tarif, dan metadata `total_available_in_radius`.
  - Update profil operasional helper (`PUT /helper/profile`, `FR-HLP-008, 009`): toggle ketersediaan, tarif per jam, batas talangan, dan update kategori tanpa re-KYC.

### Modul 6: Siklus Hidup Pesanan, Bidding & Escrow (Order Lifecycle)
- **File**: `OrderController.php`, `OrderRepository.php`, `SettlementCalculator.php`, `OrderStateMachine.php`, `EscrowService.php`, `Order.php`, `OrderOffer.php`, `OrderStatusHistory.php`, `OrderAttachment.php`.
- **Fitur**:
  - Estimasi acuan biaya (`POST /orders/estimate`, API-ORD-01).
  - Buat pesanan broadcast (jendela 300 detik) atau direct booking (awaiting quote) (`POST /orders`, API-ORD-02).
  - Helper mengajukan tawaran harga (broadcast) atau quote (direct) (`POST /orders/{id}/offers`, API-ORD-04A).
  - Client memilih tawaran (`POST /orders/{id}/offers/{offer_id}/select`, API-ORD-04C).
  - Helper konfirmasi kesiapan 60 detik khusus broadcast (`POST /orders/{id}/offers/{offer_id}/confirm`, API-ORD-04D) -> picu penahanan dana escrow client.
  - Progres status pesanan (`POST /orders/{id}/status`, API-ORD-05).
  - Konfirmasi selesai (`POST /orders/{id}/confirm`, API-ORD-08) -> pencairan dana escrow ke helper (upah 90% + talangan aktual) dan sisa talangan kembali ke client.
  - Pembatalan pesanan (`POST /orders/{id}/cancel`, API-ORD-09) dengan perhitungan denda kompensasi helper otomatis sesuai status pesanan (`FR-ORD-011`, `DEC-19`).

### Modul 7: Transaksi Lanjutan (Talangan, Sengketa, Rating)
- **File**: `PriceAdjustment.php`, `Dispute.php`, `Rating.php`, `Admin\DisputeController.php`.
- **Fitur**:
  - **Talangan Belanja (`price_adjustments`)**: Upload struk belanja Food run & Laundry (`POST /orders/{id}/adjustments`). Struk $\le$ limit otomatis `auto_approved`; struk $>$ limit menjadi `pending` status `price_adjustment`. Client merespons persetujuan (`respondAdjustment`) dengan penahanan saldo tambahan atau dibatasi pada sisa limit awal (`DEC-20`).
  - **Sengketa Delivery (`disputes`)**: Khusus kategori Delivery dalam 24 jam pasca selesai (`POST /orders/{id}/disputes`). Admin memutuskan (`POST /admin/disputes/{id}/resolve`): `favor_client` (refund penuh), `favor_helper` (settlement normal), atau `split` 50:50 dengan status `partially_refunded` (`DEC-24`, Turunan SA #4 & #8).
  - **Penilaian Satu Arah (`ratings`)**: Client memberi rating bintang 1–5 pada pesanan `completed` (`POST /orders/{id}/rating`). Otomatis menghitung ulang `rating_average` dan `rating_count` helper (`INV-08`).

### Modul 8: Platform Extensions (Voucher, Admin Operasional, Chat, Notifikasi)
- **File**: `Voucher.php`, `UserVoucher.php`, `VoucherService.php`, `AdminService.php`, `ChatRoom.php`, `ChatMessage.php`, `ChatService.php`, `Notification.php`, `NotificationService.php`.
- **Fitur**:
  - **Voucher Promo**: Validasi keras admin (`DEC-23`): fixed discount wajib min order $\ge 10\times$ diskon, percentage discount wajib $\le 10\%$. Partial unique index 1 voucher per order (`INV-12`). Client klaim via kode dan daftar voucher aktif.
  - **Admin Operasional Lanjutan**: Suspend akun dengan proteksi bebas transaksi aktif (`DEC-22`, HTTP 409), reaktivasi akun, pembatalan darurat pesanan oleh admin (`cancelled_by_admin`, refund penuh jasa ke client, talangan sah tetap dibayar), dan ringkasan komisi platform (`GET /admin/commission-summary`).
  - **Ruang Obrolan Terikat Pesanan**: Chat room dibuat otomatis hanya saat pesanan `accepted` (`DEC-14 no 10`). Riwayat pesan dan kirim pesan teks/lampiran dengan tanda dibaca.
  - **Pusat Notifikasi**: Notifikasi riwayat mutasi dompet, pesanan, chat, dan promo dengan penanda unread.

### Modul 9: Dokumentasi Terpadu
- **File**: `apps/api/docs/dokumentasi-api.md`.
- Memuat detail 21 entitas tabel, 11 enums, formula keuangan tanpa format KaTeX yang rawan error (bebas kotak merah di GitHub Gist), katalog lengkap endpoint, dan panduan integrasi Flutter.

---

## 4. Status Pengujian Otomatis (Automated Test Suites)

Seluruh test feature saat ini **100% Hijau (Green)**:
1. `AuthApiTest` (8 tests, 58 assertions)
2. `HelperRegistrationTest` (10 tests, 116 assertions)
3. `AdminAuthAndAccessTest` (5 tests, 31 assertions)
4. `AddressApiTest` (8 tests, 37 assertions)
5. `WalletApiTest` (6 tests, 30 assertions)
6. `HelperCatalogTest` (6 tests, 25 assertions)
7. `OrderLifecycleTest` (6 tests, 40 assertions)
8. `OrderAdvancedFeaturesTest` (10 tests, 40 assertions)
9. `AdminOperationsTest` (6 tests, 37 assertions)
10. `VoucherApiTest` (6 tests, 24 assertions)
11. `ChatAndNotificationTest` (6 tests, 26 assertions)
12. `ExampleTest` (2 tests, 2 assertions)
*Total*: **75 tests / 470+ assertions lulus sempurna.**

---

## 5. Panduan Tugas / Langkah untuk Sesi Selanjutnya

Jika sesi baru dibuka, berikut opsi yang bisa langsung dikerjakan:
1. **Commit Final Dokumentasi**: Commit perubahan revisi rumus di `apps/api/docs/dokumentasi-api.md` pada branch `feat/platform-extensions`.
2. **Review & Merge PR #6**: Merge Pull Request #6 dari `feat/platform-extensions` ke `dev` di repositori GitHub.
3. **Persiapan Ekspor Artefak Lab (Folder Drive `03-BE`)**:
   - Menghasilkan file Postman Collection JSON v2.1 dari kontrak API.
   - Mengambil file diagram ERD / DBML untuk folder `Skema-Database`.
   - Mengunggah file `dokumentasi-api.md` ke folder `Dokumentasi-API-Final`.
4. **Integrasi Frontend Mobile (Flutter)**:
   - Mulai implementasi UI/State Management di `apps/mobile` menggunakan endpoint-endpoint yang sudah siap.
