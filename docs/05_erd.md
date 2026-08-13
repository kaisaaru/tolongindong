# ERD Draft dan Catatan Skema

Status dokumen: `REVIEW` v0.1. Perlu ditinjau Backend Developer sebelum dibekukan. Setelah dibekukan, perubahan lewat decision log.

## 1. Diagram

```mermaid
erDiagram
    USER ||--o| HELPER_PROFILE : "boleh punya"
    USER ||--|| WALLET : memiliki
    USER ||--o{ ADDRESS : menyimpan
    USER ||--o{ ORDER : "membuat sebagai client"
    HELPER_PROFILE ||--o{ ORDER : "mengerjakan sebagai helper"
    HELPER_PROFILE }o--o{ SERVICE_CATEGORY : menguasai
    SERVICE_CATEGORY ||--o{ ORDER : mengkategorikan
    ORDER ||--o{ ORDER_STATUS_HISTORY : mencatat
    ORDER ||--o{ ORDER_OFFER : menawarkan
    ORDER ||--o| PRICE_ADJUSTMENT : "boleh punya"
    ORDER ||--o{ WALLET_TRANSACTION : memicu
    ORDER ||--o{ RATING : menghasilkan
    ORDER ||--|| CHAT_ROOM : memiliki
    ORDER ||--o| DISPUTE : "boleh punya"
    WALLET ||--o{ WALLET_TRANSACTION : mencatat
    CHAT_ROOM ||--o{ CHAT_MESSAGE : berisi
    USER ||--o{ NOTIFICATION : menerima
    USER ||--o{ USER_VOUCHER : memiliki
    VOUCHER ||--o{ USER_VOUCHER : diterbitkan
    USER ||--o{ VERIFICATION_REQUEST : mengajukan

    USER {
        bigint id PK
        varchar full_name
        varchar phone_number UK
        varchar email UK
        varchar password_hash
        varchar photo_url
        enum id_verification_status
        timestamp created_at
    }

    HELPER_PROFILE {
        bigint id PK
        bigint user_id FK
        decimal hourly_rate
        boolean is_available
        decimal rating_average
        int rating_count
        int completed_order_count
        int cancelled_order_count
        decimal max_advance_limit
        timestamp approved_at
    }

    SERVICE_CATEGORY {
        bigint id PK
        varchar code
        varchar name
        decimal base_fee
        boolean requires_advance
        boolean requires_proof_photo
    }

    ADDRESS {
        bigint id PK
        bigint user_id FK
        varchar label
        text full_address
        decimal latitude
        decimal longitude
        varchar landmark_note
        boolean is_primary
    }

    ORDER {
        bigint id PK
        varchar order_number UK
        bigint client_id FK
        bigint helper_id FK
        bigint category_id FK
        enum status
        text task_description
        bigint pickup_address_id FK
        bigint destination_address_id FK
        decimal base_fee
        decimal distance_fee
        decimal service_fee
        decimal advance_limit
        decimal advance_actual
        decimal voucher_discount
        decimal total_amount
        decimal platform_commission
        decimal helper_payout
        timestamp scheduled_at
        timestamp accepted_at
        timestamp completed_at
    }

    ORDER_OFFER {
        bigint id PK
        bigint order_id FK
        bigint helper_id FK
        enum offer_status
        timestamp offered_at
        timestamp expires_at
        timestamp responded_at
    }

    ORDER_STATUS_HISTORY {
        bigint id PK
        bigint order_id FK
        enum from_status
        enum to_status
        bigint actor_user_id FK
        varchar actor_type
        text reason
        timestamp created_at
    }

    PRICE_ADJUSTMENT {
        bigint id PK
        bigint order_id FK
        decimal requested_amount
        varchar receipt_photo_url
        enum approval_status
        timestamp requested_at
        timestamp responded_at
    }

    WALLET {
        bigint id PK
        bigint user_id FK
        bigint available_balance
        bigint held_balance
        varchar currency
        timestamp updated_at
    }

    WALLET_TRANSACTION {
        bigint id PK
        bigint wallet_id FK
        bigint order_id FK
        enum transaction_type
        bigint amount
        bigint balance_after
        varchar idempotency_key UK
        text description
        timestamp created_at
    }

    RATING {
        bigint id PK
        bigint order_id FK
        bigint rater_user_id FK
        bigint rated_user_id FK
        varchar rater_role
        int score
        text review
        boolean is_revealed
        timestamp created_at
    }

    CHAT_ROOM {
        bigint id PK
        bigint order_id FK
        boolean is_read_only
        timestamp closed_at
    }

    CHAT_MESSAGE {
        bigint id PK
        bigint chat_room_id FK
        bigint sender_user_id FK
        text content
        varchar attachment_url
        timestamp read_at
        timestamp created_at
    }

    DISPUTE {
        bigint id PK
        bigint order_id FK
        bigint raised_by_user_id FK
        text reason
        enum resolution
        text admin_note
        timestamp resolved_at
    }

    VERIFICATION_REQUEST {
        bigint id PK
        bigint user_id FK
        varchar id_card_url
        varchar selfie_url
        enum review_status
        text rejection_reason
        timestamp reviewed_at
    }

    VOUCHER {
        bigint id PK
        varchar code UK
        enum discount_type
        bigint discount_value
        bigint min_order_amount
        timestamp valid_until
    }

    USER_VOUCHER {
        bigint id PK
        bigint user_id FK
        bigint voucher_id FK
        bigint used_order_id FK
        timestamp used_at
    }

    NOTIFICATION {
        bigint id PK
        bigint user_id FK
        varchar type
        varchar title
        text body
        bigint reference_order_id FK
        timestamp read_at
        timestamp created_at
    }
```

## 2. Keputusan skema yang perlu dipahami tim

Nominal uang disimpan sebagai bilangan bulat dalam satuan rupiah, bukan bilangan pecahan. Tipe `float` atau `double` untuk uang selalu berujung pada selisih pembulatan yang tidak bisa dijelaskan saat rekonsiliasi. Kalau BE lebih nyaman memakai `decimal`, tetapkan presisi 15 dengan skala 2 dan konsisten di seluruh kolom.

Dompet dipecah menjadi dua kolom saldo. `available_balance` adalah uang yang bisa dipakai, `held_balance` adalah uang yang sedang tertahan untuk pesanan berjalan. Pemisahan ini yang membuat penahanan dana bisa diaudit dan membuat invarian `INV-02` bisa diperiksa otomatis.

Tabel `wallet_transaction` bersifat tambah saja. Tidak ada operasi ubah atau hapus pada tabel ini. Koreksi dilakukan dengan menambah baris lawan, bukan mengubah baris lama. Kolom `balance_after` disimpan supaya riwayat mutasi bisa ditampilkan tanpa menghitung ulang seluruh baris.

Kolom `idempotency_key` bersifat unik dan menjadi pertahanan utama terhadap transaksi ganda. Setiap permintaan dari aplikasi yang menyentuh uang wajib membawa kunci ini.

Relasi `ORDER` ke `USER` terjadi dua kali, sebagai `client_id` dan sebagai `helper_id`. Perhatikan bahwa `helper_id` di sini menunjuk ke `helper_profile`, bukan langsung ke `user`, supaya tarif dan status ketersediaan pada saat pesanan dibuat bisa ditelusuri. BE perlu memutuskan apakah menyimpan salinan tarif pada baris pesanan, dan saya sarankan menyimpannya karena tarif helper bisa berubah setelah pesanan lama selesai.

Tabel `order_offer` ada supaya penawaran serentak bisa dilacak. Tanpa tabel ini, kita tidak bisa menjawab pertanyaan siapa saja yang ditawari dan siapa yang melewatkan, padahal itu data penting untuk memperbaiki algoritma pencocokan.

Kolom `is_revealed` pada `rating` melaksanakan aturan penilaian tertutup. Penilaian dibuat lebih dulu tetapi baru terlihat setelah kedua pihak mengisi atau tenggat lewat.

## 3. Nilai enumerasi

| Kolom | Nilai yang diperbolehkan |
| --- | --- |
| `user.id_verification_status` | `unverified`, `pending`, `verified`, `rejected` |
| `order.status` | `draft`, `searching`, `accepted`, `on_the_way`, `arrived`, `in_progress`, `price_adjustment`, `awaiting_confirmation`, `completed`, `cancelled_by_client`, `cancelled_by_helper`, `expired`, `disputed`, `refunded` |
| `order_offer.offer_status` | `sent`, `accepted`, `skipped`, `expired` |
| `wallet_transaction.transaction_type` | `topup`, `hold`, `release`, `refund`, `payout`, `commission`, `adjustment`, `cancellation_fee` |
| `price_adjustment.approval_status` | `pending`, `approved`, `rejected` |
| `dispute.resolution` | `pending`, `favor_client`, `favor_helper`, `split` |
| `rating.rater_role` | `client`, `helper` |

## 4. Indeks yang disarankan

BE perlu menambahkan indeks pada `order(client_id, status)` dan `order(helper_id, status)` karena dua kueri paling sering adalah daftar pesanan saya sebagai client dan pesanan aktif saya sebagai helper. Tambahkan juga indeks pada `order_offer(helper_id, offer_status)` untuk pencarian tawaran yang belum direspons, dan indeks unik gabungan pada `rating(order_id, rater_role)` untuk menegakkan invarian `INV-08` di tingkat basis data, bukan hanya di kode.
