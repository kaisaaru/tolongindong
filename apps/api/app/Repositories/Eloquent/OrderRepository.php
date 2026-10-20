<?php

namespace App\Repositories\Eloquent;

use App\Enums\BookingType;
use App\Enums\OrderOfferStatus;
use App\Enums\AdminActionType;
use App\Enums\AttachmentType;
use App\Enums\DisputeResolution;
use App\Enums\PriceAdjustmentStatus;
use App\Models\AdminActionLog;
use App\Models\Dispute;
use App\Models\OrderAttachment;
use App\Models\PriceAdjustment;
use App\Models\Rating;
use App\Enums\OrderStatus;
use App\Models\Address;
use App\Models\HelperProfile;
use App\Models\Order;
use App\Models\OrderOffer;
use App\Models\OrderStatusHistory;
use App\Models\ServiceCategory;
use App\Models\User;
use App\Repositories\Contracts\OrderRepositoryInterface;
use App\Services\EscrowService;
use App\Services\OrderStateMachine;
use App\Services\SettlementCalculator;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class OrderRepository implements OrderRepositoryInterface
{
    public function __construct(
        protected EscrowService $escrowService,
        protected SettlementCalculator $calculator,
        protected OrderStateMachine $stateMachine
    ) {}

    /**
     * Generate nomor pesanan unik: ORD-YYYYMMDD-XXXX.
     */
    private function generateOrderNumber(): string
    {
        return 'ORD-' . now()->format('Ymd') . '-' . strtoupper(Str::random(4));
    }

    /**
     * Hitung jarak Haversine (km).
     */
    private function calculateDistance(float $lat1, float $lon1, float $lat2, float $lon2): float
    {
        $earthRadius = 6371;
        $dLat = deg2rad($lat2 - $lat1);
        $dLon = deg2rad($lon2 - $lon1);

        $a = sin($dLat / 2) * sin($dLat / 2) +
             cos(deg2rad($lat1)) * cos(deg2rad($lat2)) *
             sin($dLon / 2) * sin($dLon / 2);

        $c = 2 * atan2(sqrt($a), sqrt(1 - $a));

        return round($earthRadius * $c, 2);
    }

    /**
     * Hitung rentang harga acuan sebelum membuat pesanan (API-ORD-01, FR-ORD-002, DEC-14 no 4).
     */
    public function calculateEstimate(array $data): array
    {
        $category = ServiceCategory::findOrFail($data['category_id']);
        $baseFee = (int) $category->base_fee;

        $distanceKm = 0.0;
        if (!empty($data['pickup_address_id']) && !empty($data['destination_address_id'])) {
            $pickup = Address::find($data['pickup_address_id']);
            $dest = Address::find($data['destination_address_id']);

            if ($pickup && $dest) {
                $distanceKm = $this->calculateDistance(
                    (float) $pickup->latitude,
                    (float) $pickup->longitude,
                    (float) $dest->latitude,
                    (float) $dest->longitude
                );
            }
        } elseif (isset($data['distance_km'])) {
            $distanceKm = (float) $data['distance_km'];
        }

        // Biaya jarak: Rp 2.500 per km
        $distanceFee = (int) round($distanceKm * 2500);

        // DEC-14 nomor 4: Biaya layanan bernilai flat sama dengan tarif dasar kategori
        $serviceFee = $baseFee;

        $minEstimate = $baseFee + $distanceFee;
        $maxEstimate = (int) round(($baseFee + $distanceFee + $serviceFee) * 1.3);

        return [
            'success' => true,
            'data' => [
                'category_id' => $category->id,
                'category_code' => $category->code,
                'category_name' => $category->name,
                'distance_km' => $distanceKm,
                'base_fee' => $baseFee,
                'distance_fee' => $distanceFee,
                'service_fee' => $serviceFee,
                'estimated_price_range' => [
                    'min' => $minEstimate,
                    'max' => $maxEstimate,
                ],
            ],
        ];
    }

    /**
     * Buat pesanan baru (API-ORD-02, FR-ORD-001).
     */
    public function createOrder(User $client, array $data): array
    {
        $category = ServiceCategory::findOrFail($data['category_id']);
        $bookingType = BookingType::from($data['booking_type'] ?? 'broadcast');

        // Validasi kebutuhan talangan (Food Run & Laundry)
        $advanceLimit = 0;
        if ($category->requires_advance) {
            $advanceLimit = (int) ($data['advance_limit'] ?? 0);
            if ($advanceLimit <= 0) {
                return [
                    'success' => false,
                    'error_code' => 'ADVANCE_LIMIT_REQUIRED',
                    'message' => "Kategori {$category->name} membutuhkan penentuan batas talangan belanja awal.",
                    'status_code' => 422,
                ];
            }
        }

        // Direct Booking Validations (DEC-17, DEC-21, FR-ORD-003D)
        $targetHelper = null;
        if ($bookingType === BookingType::DIRECT) {
            if (empty($data['helper_id'])) {
                return [
                    'success' => false,
                    'error_code' => 'HELPER_REQUIRED_FOR_DIRECT',
                    'message' => 'Pemesanan langsung wajib menentukan ID Helper tujuan.',
                    'status_code' => 422,
                ];
            }

            $targetHelper = HelperProfile::find($data['helper_id']);
            if (!$targetHelper || !$targetHelper->isApproved() || !$targetHelper->isAvailable()) {
                return [
                    'success' => false,
                    'error_code' => 'HELPER_UNAVAILABLE',
                    'message' => 'Helper yang dituju sedang tidak tersedia atau belum terverifikasi.',
                    'status_code' => 422,
                ];
            }

            // DEC-17 / FR-ORD-020: Helper max_advance_limit harus cukup
            if ($category->requires_advance && !$targetHelper->coversAdvanceLimit($advanceLimit)) {
                return [
                    'success' => false,
                    'error_code' => 'INSUFFICIENT_HELPER_ADVANCE_LIMIT',
                    'message' => 'Batas talangan helper yang dipilih lebih kecil dari batas talangan yang Anda tentukan.',
                    'status_code' => 422,
                ];
            }

            // FR-ORD-016: Tidak boleh pesan ke diri sendiri
            if ($targetHelper->user_id === $client->id) {
                return [
                    'success' => false,
                    'error_code' => 'CANNOT_ORDER_SELF',
                    'message' => 'Anda tidak dapat membuat pesanan ke diri Anda sendiri.',
                    'status_code' => 422,
                ];
            }
        }

        // Hitung komponen biaya acuan
        $estimate = $this->calculateEstimate([
            'category_id' => $category->id,
            'pickup_address_id' => $data['pickup_address_id'] ?? null,
            'destination_address_id' => $data['destination_address_id'] ?? null,
        ]);

        $initialStatus = $bookingType === BookingType::DIRECT
            ? OrderStatus::AWAITING_QUOTE
            : OrderStatus::SEARCHING;

        return DB::transaction(function () use ($client, $category, $bookingType, $data, $advanceLimit, $targetHelper, $estimate, $initialStatus) {
            $order = Order::create([
                'order_number' => $this->generateOrderNumber(),
                'client_id' => $client->id,
                'helper_id' => $targetHelper?->id,
                'category_id' => $category->id,
                'booking_type' => $bookingType,
                'status' => $initialStatus,
                'task_description' => $data['task_description'],
                'pickup_address_id' => $data['pickup_address_id'] ?? null,
                'destination_address_id' => $data['destination_address_id'] ?? null,
                'client_estimated_price' => (int) ($data['client_estimated_price'] ?? $estimate['data']['estimated_price_range']['min']),
                'base_fee' => $estimate['data']['base_fee'],
                'distance_fee' => $estimate['data']['distance_fee'],
                'service_fee' => $estimate['data']['service_fee'],
                'advance_limit' => $advanceLimit,
                'offer_window_expires_at' => now()->addSeconds(300), // Jendela 300 detik
            ]);

            OrderStatusHistory::create([
                'order_id' => $order->id,
                'from_status' => null,
                'to_status' => $initialStatus,
                'changed_by_user_id' => $client->id,
                'note' => $bookingType === BookingType::DIRECT ? 'Pesanan direct booking dibuat, menunggu quote helper' : 'Pesanan broadcast dibuat, mencari tawaran helper',
            ]);

            $order->load(['serviceCategory', 'pickupAddress', 'destinationAddress']);

            return [
                'success' => true,
                'data' => $order,
                'status_code' => 201,
            ];
        });
    }

    /**
     * Dapatkan detail satu pesanan (API-ORD-03, FR-ORD-008).
     */
    public function getOrderDetails(User $user, int $orderId): array
    {
        $order = Order::with([
            'client',
            'helper.user',
            'serviceCategory',
            'pickupAddress',
            'destinationAddress',
            'offers.helper.user',
            'statusHistories',
            'attachments',
        ])->find($orderId);

        if (!$order) {
            return [
                'success' => false,
                'error_code' => 'NOT_FOUND',
                'message' => 'Pesanan tidak ditemukan.',
                'status_code' => 404,
            ];
        }

        // Otorisasi: Pemesan, Helper yang dituju, atau Admin
        $isClient = $order->client_id === $user->id;
        $isHelper = $order->helper && $order->helper->user_id === $user->id;
        $isAdmin = (bool) $user->is_admin;

        // Pada status searching broadcast, helper terverifikasi lain boleh melihat pesanan untuk menawar
        $isAvailableHelper = $order->status === OrderStatus::SEARCHING && $user->isVerifiedHelper();

        if (!$isClient && !$isHelper && !$isAdmin && !$isAvailableHelper) {
            return [
                'success' => false,
                'error_code' => 'FORBIDDEN',
                'message' => 'Anda tidak memiliki hak akses untuk melihat pesanan ini.',
                'status_code' => 403,
            ];
        }

        return [
            'success' => true,
            'data' => [
                'order' => $order,
                'allowed_next_statuses' => $this->stateMachine->getAllowedTransitions($order->status),
            ],
        ];
    }

    /**
     * Dapatkan daftar pesanan pengguna (sebagai Client atau Helper).
     */
    public function listOrders(User $user, array $filters = []): array
    {
        $query = Order::with(['serviceCategory', 'helper.user']);

        $role = $filters['role'] ?? 'client';

        if ($role === 'helper' && $user->helperProfile) {
            $query->where('helper_id', $user->helperProfile->id);
        } else {
            $query->where('client_id', $user->id);
        }

        if (!empty($filters['status'])) {
            $query->where('status', $filters['status']);
        }

        $orders = $query->latest('created_at')->paginate($filters['per_page'] ?? 15);

        return [
            'success' => true,
            'data' => $orders,
        ];
    }

    /**
     * Helper mengajukan penawaran harga (broadcast) atau quote (direct) (API-ORD-04A, DEC-05, DEC-21).
     */
    public function submitOffer(User $helperUser, int $orderId, int $proposedPrice, ?string $message = null): array
    {
        if (!$helperUser->isVerifiedHelper()) {
            return [
                'success' => false,
                'error_code' => 'FORBIDDEN',
                'message' => 'Hanya Helper terverifikasi yang dapat mengajukan tawaran.',
                'status_code' => 403,
            ];
        }

        $order = Order::find($orderId);
        if (!$order) {
            return [
                'success' => false,
                'error_code' => 'NOT_FOUND',
                'message' => 'Pesanan tidak ditemukan.',
                'status_code' => 404,
            ];
        }

        // FR-ORD-016: Larang helper membid pesanan buatannya sendiri
        if ($order->client_id === $helperUser->id) {
            return [
                'success' => false,
                'error_code' => 'CANNOT_BID_OWN_ORDER',
                'message' => 'Anda tidak dapat mengajukan tawaran pada pesanan yang Anda buat sendiri.',
                'status_code' => 422,
            ];
        }

        // Validasi status penerimaan tawaran
        if ($order->booking_type === BookingType::BROADCAST && $order->status !== OrderStatus::SEARCHING) {
            return [
                'success' => false,
                'error_code' => 'OFFER_WINDOW_CLOSED',
                'message' => 'Jendela penawaran untuk pesanan ini sudah ditutup.',
                'status_code' => 422,
            ];
        }

        if ($order->booking_type === BookingType::DIRECT && $order->status !== OrderStatus::AWAITING_QUOTE) {
            return [
                'success' => false,
                'error_code' => 'QUOTE_WINDOW_CLOSED',
                'message' => 'Permintaan quote direct booking sudah tidak aktif.',
                'status_code' => 422,
            ];
        }

        $helperProfile = $helperUser->helperProfile;

        // DEC-17 / FR-ORD-020: Helper max_advance_limit harus cukup
        if ($order->advance_limit > 0 && !$helperProfile->coversAdvanceLimit($order->advance_limit)) {
            return [
                'success' => false,
                'error_code' => 'INSUFFICIENT_ADVANCE_LIMIT',
                'message' => 'Batas talangan maksimal Anda tidak mencukupi untuk pesanan ini.',
                'status_code' => 422,
            ];
        }

        $validUntil = $order->booking_type === BookingType::DIRECT ? now()->addSeconds(300) : null;

        $offer = OrderOffer::updateOrCreate(
            ['order_id' => $order->id, 'helper_id' => $helperProfile->id],
            [
                'proposed_price' => $proposedPrice,
                'message' => $message,
                'offer_status' => OrderOfferStatus::SUBMITTED,
                'valid_until' => $validUntil,
            ]
        );

        return [
            'success' => true,
            'data' => $offer->load('helper.user'),
            'message' => 'Tawaran harga berhasil dikirim.',
            'status_code' => 201,
        ];
    }

    /**
     * Client memilih salah satu tawaran yang masuk (API-ORD-04C, DEC-05, DEC-21).
     */
    public function selectOffer(User $client, int $orderId, int $offerId): array
    {
        $order = Order::find($orderId);
        if (!$order || $order->client_id !== $client->id) {
            return [
                'success' => false,
                'error_code' => 'NOT_FOUND',
                'message' => 'Pesanan tidak ditemukan atau bukan milik Anda.',
                'status_code' => 404,
            ];
        }

        $offer = OrderOffer::where('order_id', $order->id)->where('id', $offerId)->first();
        if (!$offer || $offer->offer_status !== OrderOfferStatus::SUBMITTED) {
            return [
                'success' => false,
                'error_code' => 'INVALID_OFFER',
                'message' => 'Tawaran tidak valid atau sudah diproses.',
                'status_code' => 422,
            ];
        }

        return DB::transaction(function () use ($client, $order, $offer) {
            $holdCalc = $this->calculator->calculateHold($offer->proposed_price, $order->advance_limit, 0);

            if ($order->booking_type === BookingType::BROADCAST) {
                // Broadcast: Status menjadi pending_confirmation, helper terpilih diberi 60 detik (DEC-21)
                $order->update([
                    'helper_id' => $offer->helper_id,
                    'status' => OrderStatus::PENDING_CONFIRMATION,
                    'total_amount' => $holdCalc['total_amount'],
                    'voucher_discount' => $holdCalc['voucher_discount'],
                    'service_client_charge' => $holdCalc['service_client_charge'],
                    'held_amount' => $holdCalc['held_amount'],
                ]);

                $offer->update([
                    'offer_status' => OrderOfferStatus::SELECTED,
                    'confirmation_expires_at' => now()->addSeconds(60),
                ]);

                // Tolak tawaran lain secara otomatis
                OrderOffer::where('order_id', $order->id)
                    ->where('id', '!=', $offer->id)
                    ->update(['offer_status' => OrderOfferStatus::NOT_SELECTED]);

                OrderStatusHistory::create([
                    'order_id' => $order->id,
                    'from_status' => OrderStatus::SEARCHING,
                    'to_status' => OrderStatus::PENDING_CONFIRMATION,
                    'changed_by_user_id' => $client->id,
                    'note' => 'Client memilih tawaran helper, menunggu konfirmasi kesiapan 60 detik',
                ]);

                return [
                    'success' => true,
                    'data' => [
                        'order' => $order->fresh(),
                        'selected_offer' => $offer->fresh(),
                    ],
                    'message' => 'Tawaran terpilih. Menunggu konfirmasi akhir helper dalam 60 detik.',
                ];
            } else {
                // Direct Booking: Langsung menahan dana dan status langsung ACCEPTED (FR-ORD-003D)
                $order->update([
                    'status' => OrderStatus::ACCEPTED,
                    'total_amount' => $holdCalc['total_amount'],
                    'voucher_discount' => $holdCalc['voucher_discount'],
                    'service_client_charge' => $holdCalc['service_client_charge'],
                    'held_amount' => $holdCalc['held_amount'],
                ]);

                $offer->update(['offer_status' => OrderOfferStatus::CONFIRMED]);

                $holdRes = $this->escrowService->holdFunds($client, $order, $holdCalc['held_amount']);
                if (!$holdRes['success']) {
                    throw new \Exception($holdRes['message']);
                }

                OrderStatusHistory::create([
                    'order_id' => $order->id,
                    'from_status' => OrderStatus::AWAITING_QUOTE,
                    'to_status' => OrderStatus::ACCEPTED,
                    'changed_by_user_id' => $client->id,
                    'note' => 'Client menyetujui quote direct booking, dana escrow ditahan, pesanan diterima',
                ]);

                return [
                    'success' => true,
                    'data' => [
                        'order' => $order->fresh(),
                        'offer' => $offer->fresh(),
                    ],
                    'message' => 'Quote disetujui. Dana berhasil ditahan dan pesanan aktif.',
                ];
            }
        });
    }

    /**
     * Helper mengonfirmasi kesiapan dalam 60 detik (khusus broadcast) (API-ORD-04D, DEC-21).
     */
    public function confirmOffer(User $helperUser, int $orderId, int $offerId): array
    {
        $order = Order::find($orderId);
        if (!$order || $order->status !== OrderStatus::PENDING_CONFIRMATION) {
            return [
                'success' => false,
                'error_code' => 'INVALID_ORDER_STATE',
                'message' => 'Pesanan tidak dalam status menunggu konfirmasi.',
                'status_code' => 422,
            ];
        }

        $offer = OrderOffer::where('order_id', $order->id)->where('id', $offerId)->first();
        if (!$offer || $offer->offer_status !== OrderOfferStatus::SELECTED) {
            return [
                'success' => false,
                'error_code' => 'INVALID_OFFER',
                'message' => 'Tawaran ini tidak sedang berstatus dipilih.',
                'status_code' => 422,
            ];
        }

        if ($offer->helper->user_id !== $helperUser->id) {
            return [
                'success' => false,
                'error_code' => 'FORBIDDEN',
                'message' => 'Anda bukan helper terpilih pada pesanan ini.',
                'status_code' => 403,
            ];
        }

        return DB::transaction(function () use ($order, $offer, $helperUser) {
            // Tahan dana pemesan via EscrowService
            $holdRes = $this->escrowService->holdFunds($order->client, $order, $order->held_amount);
            if (!$holdRes['success']) {
                return $holdRes;
            }

            $order->update(['status' => OrderStatus::ACCEPTED]);
            $offer->update(['offer_status' => OrderOfferStatus::CONFIRMED]);

            OrderStatusHistory::create([
                'order_id' => $order->id,
                'from_status' => OrderStatus::PENDING_CONFIRMATION,
                'to_status' => OrderStatus::ACCEPTED,
                'changed_by_user_id' => $helperUser->id,
                'note' => 'Helper mengonfirmasi kesiapan, dana escrow ditahan, pesanan resmi berjalan',
            ]);

            return [
                'success' => true,
                'data' => [
                    'order' => $order->fresh(),
                    'offer' => $offer->fresh(),
                ],
                'message' => 'Pesanan berhasil dikonfirmasi dan mulai berjalan.',
            ];
        });
    }

    /**
     * Helper menerima pesanan marketplace langsung (Direct Booking Acceptance).
     */
    public function acceptOrder(User $helperUser, int $orderId): array
    {
        $order = Order::with(['client', 'helper.user'])->find($orderId);

        if (!$order) {
            return [
                'success' => false,
                'error_code' => 'NOT_FOUND',
                'message' => 'Pesanan tidak ditemukan.',
                'status_code' => 404,
            ];
        }

        if (!$order->helper || $order->helper->user_id !== $helperUser->id) {
            return [
                'success' => false,
                'error_code' => 'FORBIDDEN',
                'message' => 'Anda bukan helper yang dituju untuk pesanan ini.',
                'status_code' => 403,
            ];
        }

        if (!in_array($order->status, [OrderStatus::AWAITING_QUOTE, OrderStatus::PENDING_CONFIRMATION, OrderStatus::SEARCHING])) {
            return [
                'success' => false,
                'error_code' => 'INVALID_ORDER_STATE',
                'message' => 'Pesanan ini tidak dalam status menunggu penerimaan helper.',
                'status_code' => 422,
            ];
        }

        $price = $order->total_amount > 0 ? $order->total_amount : ($order->client_estimated_price ?: $order->base_fee);
        $holdCalc = $this->calculator->calculateHold($price, 0, $order->voucher_discount ?? 0);

        return DB::transaction(function () use ($order, $helperUser, $holdCalc, $price) {
            // Tahan dana pemesan via EscrowService
            $holdRes = $this->escrowService->holdFunds($order->client, $order, $holdCalc['held_amount']);
            if (!$holdRes['success']) {
                return $holdRes;
            }

            $fromStatus = $order->status;
            $order->update([
                'status' => OrderStatus::ACCEPTED,
                'accepted_at' => now(),
                'total_amount' => $price,
                'held_amount' => $holdCalc['held_amount'],
                'service_client_charge' => $holdCalc['service_client_charge'],
                'platform_commission' => $holdCalc['gross_commission'],
                'helper_payout' => $price - $holdCalc['gross_commission'],
            ]);

            OrderStatusHistory::create([
                'order_id' => $order->id,
                'from_status' => $fromStatus,
                'to_status' => OrderStatus::ACCEPTED,
                'changed_by_user_id' => $helperUser->id,
                'note' => 'Helper menerima pesanan marketplace, dana escrow ditahan',
            ]);

            return [
                'success' => true,
                'data' => $order->fresh(['client', 'helper.user', 'serviceCategory']),
                'message' => 'Pesanan berhasil diterima dan mulai berjalan.',
            ];
        });
    }

    /**
     * Helper menolak pesanan marketplace langsung (Direct Booking Rejection).
     */
    public function rejectOrder(User $helperUser, int $orderId, ?string $reason = null): array
    {
        $order = Order::with(['client', 'helper.user'])->find($orderId);

        if (!$order) {
            return [
                'success' => false,
                'error_code' => 'NOT_FOUND',
                'message' => 'Pesanan tidak ditemukan.',
                'status_code' => 404,
            ];
        }

        if (!$order->helper || $order->helper->user_id !== $helperUser->id) {
            return [
                'success' => false,
                'error_code' => 'FORBIDDEN',
                'message' => 'Anda bukan helper yang dituju untuk pesanan ini.',
                'status_code' => 403,
            ];
        }

        if (!in_array($order->status, [OrderStatus::AWAITING_QUOTE, OrderStatus::PENDING_CONFIRMATION, OrderStatus::SEARCHING])) {
            return [
                'success' => false,
                'error_code' => 'INVALID_ORDER_STATE',
                'message' => 'Pesanan ini tidak dalam status menunggu respon helper.',
                'status_code' => 422,
            ];
        }

        return DB::transaction(function () use ($order, $helperUser, $reason) {
            $fromStatus = $order->status;
            $order->update(['status' => OrderStatus::CANCELLED_BY_HELPER]);

            OrderStatusHistory::create([
                'order_id' => $order->id,
                'from_status' => $fromStatus,
                'to_status' => OrderStatus::CANCELLED_BY_HELPER,
                'changed_by_user_id' => $helperUser->id,
                'note' => $reason ?: 'Helper menolak pesanan marketplace.',
            ]);

            return [
                'success' => true,
                'data' => $order->fresh(),
                'message' => 'Pesanan telah ditolak oleh helper.',
            ];
        });
    }

    /**
     * Helper memajukan status tahapan pesanan (API-ORD-05, FR-ORD-009).
     */
    public function updateStatus(User $user, int $orderId, OrderStatus $targetStatus): array
    {
        $order = Order::find($orderId);
        if (!$order) {
            return [
                'success' => false,
                'error_code' => 'NOT_FOUND',
                'message' => 'Pesanan tidak ditemukan.',
                'status_code' => 404,
            ];
        }

        if (!$order->helper || $order->helper->user_id !== $user->id) {
            return [
                'success' => false,
                'error_code' => 'FORBIDDEN',
                'message' => 'Hanya Helper yang ditugaskan yang dapat memperbarui tahapan progres pekerjaan.',
                'status_code' => 403,
            ];
        }

        if (!$this->stateMachine->canTransition($order->status, $targetStatus)) {
            return [
                'success' => false,
                'error_code' => 'INVALID_TRANSITION',
                'message' => "Transisi status dari {$order->status->value} ke {$targetStatus->value} tidak diizinkan.",
                'status_code' => 422,
            ];
        }

        return DB::transaction(function () use ($order, $targetStatus, $user) {
            $fromStatus = $order->status;
            $updateData = ['status' => $targetStatus];

            if ($targetStatus === OrderStatus::AWAITING_CONFIRMATION) {
                $updateData['helper_finished_at'] = now();
            }

            $order->update($updateData);

            OrderStatusHistory::create([
                'order_id' => $order->id,
                'from_status' => $fromStatus,
                'to_status' => $targetStatus,
                'changed_by_user_id' => $user->id,
                'note' => "Status pekerjaan diperbarui menjadi {$targetStatus->label()}",
            ]);

            return [
                'success' => true,
                'data' => $order->fresh(),
                'message' => "Status pesanan berhasil diubah menjadi {$targetStatus->label()}.",
            ];
        });
    }

    /**
     * Client mengonfirmasi pekerjaan selesai & settlement dana (API-ORD-08, FR-ORD-010).
     */
    public function confirmCompletion(User $client, int $orderId): array
    {
        $order = Order::find($orderId);
        if (!$order || $order->client_id !== $client->id) {
            return [
                'success' => false,
                'error_code' => 'NOT_FOUND',
                'message' => 'Pesanan tidak ditemukan atau bukan milik Anda.',
                'status_code' => 404,
            ];
        }

        if ($order->status !== OrderStatus::AWAITING_CONFIRMATION && $order->status !== OrderStatus::IN_PROGRESS) {
            return [
                'success' => false,
                'error_code' => 'ORDER_NOT_READY_TO_COMPLETE',
                'message' => 'Pesanan belum dapat diselesaikan pada status saat ini.',
                'status_code' => 422,
            ];
        }

        return DB::transaction(function () use ($order, $client) {
            $settlement = $this->calculator->calculateCompletion(
                $order->total_amount,
                $order->held_amount,
                $order->advance_actual,
                $order->voucher_discount
            );

            $order->update([
                'status' => OrderStatus::COMPLETED,
                'helper_payout' => $settlement['helper_payout'],
                'platform_commission' => $settlement['platform_commission'],
            ]);

            // Lepas dana escrow ke helper dan kembalikan sisa ke client
            $this->escrowService->releaseFunds($order, $settlement);

            // Tambahkan hitungan pesanan selesai helper
            $order->helper->increment('completed_order_count');

            OrderStatusHistory::create([
                'order_id' => $order->id,
                'from_status' => $order->status,
                'to_status' => OrderStatus::COMPLETED,
                'changed_by_user_id' => $client->id,
                'note' => 'Client mengonfirmasi pesanan selesai. Dana escrow telah dicairkan.',
            ]);

            return [
                'success' => true,
                'data' => [
                    'order' => $order->fresh(),
                    'settlement' => $settlement,
                ],
                'message' => 'Pesanan selesai. Pembayaran telah dilepas ke Helper.',
            ];
        });
    }

    /**
     * Membatalkan pesanan dengan aturan denda/kompensasi (API-ORD-09, FR-ORD-011, DEC-19).
     */
    public function cancelOrder(User $user, int $orderId, ?string $reason = null): array
    {
        $order = Order::find($orderId);
        if (!$order) {
            return [
                'success' => false,
                'error_code' => 'NOT_FOUND',
                'message' => 'Pesanan tidak ditemukan.',
                'status_code' => 404,
            ];
        }

        $isClient = $order->client_id === $user->id;
        $isHelper = $order->helper && $order->helper->user_id === $user->id;

        if (!$isClient && !$isHelper && !$user->is_admin) {
            return [
                'success' => false,
                'error_code' => 'FORBIDDEN',
                'message' => 'Anda tidak memiliki hak untuk membatalkan pesanan ini.',
                'status_code' => 403,
            ];
        }

        if ($order->isTerminal()) {
            return [
                'success' => false,
                'error_code' => 'ORDER_ALREADY_TERMINAL',
                'message' => 'Pesanan sudah berstatus selesai atau dibatalkan sebelumnya.',
                'status_code' => 422,
            ];
        }

        return DB::transaction(function () use ($order, $user, $isClient, $isHelper, $reason) {
            $cancellationFee = 0;
            $targetStatus = $isClient ? OrderStatus::CANCELLED_BY_CLIENT : OrderStatus::CANCELLED_BY_HELPER;

            if ($isClient && $order->held_amount > 0) {
                $acceptedSeconds = 0;
                $acceptedLog = $order->statusHistories()->where('to_status', OrderStatus::ACCEPTED)->latest()->first();
                if ($acceptedLog) {
                    $acceptedSeconds = now()->diffInSeconds($acceptedLog->created_at);
                }

                $cancellationFee = $this->calculator->calculateCancellationFee(
                    $order->status,
                    $acceptedSeconds,
                    $order->total_amount,
                    $order->service_client_charge
                );
            }

            $cancellation = $this->calculator->calculateCancellation(
                $order->held_amount,
                $order->advance_actual,
                $cancellationFee
            );

            $order->update([
                'status' => $targetStatus,
                'cancellation_fee' => $cancellationFee,
            ]);

            if ($order->held_amount > 0) {
                $this->escrowService->refundCancellation($order, $cancellation);
            }

            if ($isHelper) {
                $order->helper->increment('cancelled_order_count');
            }

            OrderStatusHistory::create([
                'order_id' => $order->id,
                'from_status' => $order->status,
                'to_status' => $targetStatus,
                'changed_by_user_id' => $user->id,
                'note' => 'Pesanan dibatalkan: ' . ($reason ?? 'Tanpa alasan khusus'),
            ]);

            return [
                'success' => true,
                'data' => [
                    'order' => $order->fresh(),
                    'cancellation' => $cancellation,
                ],
                'message' => 'Pesanan berhasil dibatalkan.',
            ];
        });
    }

    /**
     * Helper mengunggah struk talangan belanja (API-ORD-06, FR-ORD-014, FR-ORD-019).
     */
    public function uploadPriceAdjustment(User $helperUser, int $orderId, int $requestedAmount, ?string $receiptUrl = null): array
    {
        $order = Order::find($orderId);
        if (!$order) {
            return [
                'success' => false,
                'error_code' => 'NOT_FOUND',
                'message' => 'Pesanan tidak ditemukan.',
                'status_code' => 404,
            ];
        }

        if (!$order->helper || $order->helper->user_id !== $helperUser->id) {
            return [
                'success' => false,
                'error_code' => 'FORBIDDEN',
                'message' => 'Hanya Helper yang ditugaskan yang dapat mengunggah struk belanja.',
                'status_code' => 403,
            ];
        }

        if (!$order->serviceCategory->requires_advance) {
            return [
                'success' => false,
                'error_code' => 'ADVANCE_NOT_ALLOWED',
                'message' => 'Kategori pesanan ini tidak mendukung talangan belanja.',
                'status_code' => 422,
            ];
        }

        if ($order->status !== OrderStatus::IN_PROGRESS) {
            return [
                'success' => false,
                'error_code' => 'INVALID_ORDER_STATE',
                'message' => 'Struk belanja hanya dapat diunggah saat pesanan berstatus in_progress.',
                'status_code' => 422,
            ];
        }

        // DEC-14 nomor 2 / FR-ORD-019: Tolak struk baru selama masih ada penyesuaian berstatus pending
        $hasPending = $order->priceAdjustments()->where('approval_status', PriceAdjustmentStatus::PENDING)->exists();
        if ($hasPending) {
            return [
                'success' => false,
                'error_code' => 'PRICE_ADJUSTMENT_PENDING_EXISTS',
                'message' => 'Masih ada struk belanja yang menunggu persetujuan Client.',
                'status_code' => 422,
            ];
        }

        return DB::transaction(function () use ($order, $helperUser, $requestedAmount, $receiptUrl) {
            $attachmentId = null;
            if ($receiptUrl) {
                $attachment = OrderAttachment::create([
                    'order_id' => $order->id,
                    'uploader_user_id' => $helperUser->id,
                    'attachment_type' => AttachmentType::RECEIPT,
                    'file_url' => $receiptUrl,
                ]);
                $attachmentId = $attachment->id;
            }

            // Evaluasi apakah struk masih dalam batas talangan (05_erd-draft.md Bagian 2.3)
            if ($order->advance_actual + $requestedAmount <= $order->advance_limit) {
                // Auto approved!
                $adj = PriceAdjustment::create([
                    'order_id' => $order->id,
                    'receipt_attachment_id' => $attachmentId,
                    'requested_amount' => $requestedAmount,
                    'recognized_amount' => $requestedAmount,
                    'additional_hold_amount' => 0,
                    'approval_status' => PriceAdjustmentStatus::AUTO_APPROVED,
                ]);

                $order->increment('advance_actual', $requestedAmount);

                return [
                    'success' => true,
                    'data' => [
                        'order' => $order->fresh(),
                        'adjustment' => $adj,
                    ],
                    'message' => 'Struk belanja berada dalam batas talangan dan disetujui otomatis.',
                    'status_code' => 201,
                ];
            } else {
                // Melewati batas, butuh persetujuan client
                $adj = PriceAdjustment::create([
                    'order_id' => $order->id,
                    'receipt_attachment_id' => $attachmentId,
                    'requested_amount' => $requestedAmount,
                    'recognized_amount' => 0,
                    'additional_hold_amount' => 0,
                    'approval_status' => PriceAdjustmentStatus::PENDING,
                ]);

                $order->update(['status' => OrderStatus::PRICE_ADJUSTMENT]);

                OrderStatusHistory::create([
                    'order_id' => $order->id,
                    'from_status' => OrderStatus::IN_PROGRESS,
                    'to_status' => OrderStatus::PRICE_ADJUSTMENT,
                    'changed_by_user_id' => $helperUser->id,
                    'note' => 'Helper mengunggah struk melebihi batas talangan. Menunggu respons client.',
                ]);

                return [
                    'success' => true,
                    'data' => [
                        'order' => $order->fresh(),
                        'adjustment' => $adj,
                    ],
                    'message' => 'Struk belanja melebihi batas talangan. Menunggu persetujuan client.',
                    'status_code' => 201,
                ];
            }
        });
    }

    /**
     * Client menyetujui atau menolak penyesuaian belanja (API-ORD-07, FR-ORD-014, DEC-20).
     */
    public function respondPriceAdjustment(User $client, int $orderId, int $adjustmentId, string $action): array
    {
        $order = Order::find($orderId);
        if (!$order || $order->client_id !== $client->id) {
            return [
                'success' => false,
                'error_code' => 'NOT_FOUND',
                'message' => 'Pesanan tidak ditemukan atau bukan milik Anda.',
                'status_code' => 404,
            ];
        }

        $adj = PriceAdjustment::where('order_id', $order->id)->where('id', $adjustmentId)->first();
        if (!$adj || $adj->approval_status !== PriceAdjustmentStatus::PENDING) {
            return [
                'success' => false,
                'error_code' => 'INVALID_ADJUSTMENT',
                'message' => 'Penyesuaian belanja tidak ditemukan atau sudah diproses.',
                'status_code' => 422,
            ];
        }

        return DB::transaction(function () use ($order, $adj, $action, $client) {
            if ($action === 'approved') {
                // Hitung kelebihan di atas batas (05_erd-draft.md Bagian 2.3)
                $excessAmount = max(0, ($order->advance_actual + $adj->requested_amount) - $order->advance_limit);

                if ($excessAmount > 0) {
                    $holdRes = $this->escrowService->holdFunds($client, $order, $excessAmount);
                    if (!$holdRes['success']) {
                        return $holdRes;
                    }
                    $order->held_amount += $excessAmount;
                }

                $adj->update([
                    'approval_status' => PriceAdjustmentStatus::APPROVED,
                    'recognized_amount' => $adj->requested_amount,
                    'additional_hold_amount' => $excessAmount,
                ]);

                $order->advance_actual += $adj->requested_amount;
                $order->status = OrderStatus::IN_PROGRESS;
                $order->save();

                $note = 'Client menyetujui penyesuaian belanja. Saldo tambahan ditahan escrow.';
            } else {
                // Client menolak: diakui hanya sisa batas lama (DEC-20)
                $remainingLimit = max(0, $order->advance_limit - $order->advance_actual);

                $adj->update([
                    'approval_status' => PriceAdjustmentStatus::REJECTED,
                    'recognized_amount' => $remainingLimit,
                    'additional_hold_amount' => 0,
                ]);

                $order->advance_actual += $remainingLimit;
                $order->status = OrderStatus::IN_PROGRESS;
                $order->save();

                $note = 'Client menolak penyesuaian belanja. Pembayaran dibatasi pada sisa limit awal.';
            }

            OrderStatusHistory::create([
                'order_id' => $order->id,
                'from_status' => OrderStatus::PRICE_ADJUSTMENT,
                'to_status' => OrderStatus::IN_PROGRESS,
                'changed_by_user_id' => $client->id,
                'note' => $note,
            ]);

            return [
                'success' => true,
                'data' => [
                    'order' => $order->fresh(),
                    'adjustment' => $adj->fresh(),
                ],
                'message' => $note,
            ];
        });
    }

    /**
     * Mengajukan sengketa pesanan Delivery (API-ORD-12, FR-ORD-018, DEC-10, DEC-20).
     */
    public function raiseDispute(User $user, int $orderId, string $reason): array
    {
        $order = Order::find($orderId);
        if (!$order) {
            return [
                'success' => false,
                'error_code' => 'NOT_FOUND',
                'message' => 'Pesanan tidak ditemukan.',
                'status_code' => 404,
            ];
        }

        $isClient = $order->client_id === $user->id;
        $isHelper = $order->helper && $order->helper->user_id === $user->id;

        if (!$isClient && !$isHelper) {
            return [
                'success' => false,
                'error_code' => 'FORBIDDEN',
                'message' => 'Anda tidak terlibat dalam pesanan ini.',
                'status_code' => 403,
            ];
        }

        // DEC-10 / DEC-20: Sengketa hanya untuk pesanan Delivery
        if (!$order->serviceCategory->is_dispute_eligible) {
            return [
                'success' => false,
                'error_code' => 'DISPUTE_NOT_ELIGIBLE',
                'message' => 'Kategori pesanan ini tidak memiliki jalur sengketa formal platform.',
                'status_code' => 422,
            ];
        }

        return DB::transaction(function () use ($order, $user, $reason) {
            $dispute = Dispute::create([
                'order_id' => $order->id,
                'raised_by_user_id' => $user->id,
                'reason' => $reason,
                'resolution' => DisputeResolution::PENDING,
            ]);

            $fromStatus = $order->status;
            $order->update(['status' => OrderStatus::DISPUTED]);

            OrderStatusHistory::create([
                'order_id' => $order->id,
                'from_status' => $fromStatus,
                'to_status' => OrderStatus::DISPUTED,
                'changed_by_user_id' => $user->id,
                'note' => 'Sengketa diajukan ke admin operasional: ' . $reason,
            ]);

            return [
                'success' => true,
                'data' => [
                    'dispute' => $dispute,
                    'order' => $order->fresh(),
                ],
                'message' => 'Sengketa berhasil diajukan dan sedang menunggu peninjauan admin.',
                'status_code' => 201,
            ];
        });
    }

    /**
     * Admin memutuskan sengketa Delivery (API-ADM-06, FR-ADM-006, Turunan SA #4 & #8).
     */
    public function resolveDispute(User $admin, int $disputeId, string $resolution, ?string $adminNote = null): array
    {
        $dispute = Dispute::find($disputeId);
        if (!$dispute || $dispute->resolution !== DisputeResolution::PENDING) {
            return [
                'success' => false,
                'error_code' => 'INVALID_DISPUTE',
                'message' => 'Tiket sengketa tidak ditemukan atau sudah diputuskan.',
                'status_code' => 422,
            ];
        }

        $order = $dispute->order;
        $resEnum = DisputeResolution::from($resolution);

        return DB::transaction(function () use ($admin, $dispute, $order, $resEnum, $adminNote) {
            $clientRefund = 0;
            $helperRelease = 0;
            $finalStatus = OrderStatus::COMPLETED;

            if ($resEnum === DisputeResolution::FAVOR_CLIENT) {
                // Favor client: seluruh dana tertahan kembali ke client (FR-ADM-006)
                $clientRefund = $order->held_amount;
                $helperRelease = 0;
                $finalStatus = OrderStatus::REFUNDED;

                $this->escrowService->refundCancellation($order, [
                    'client_refund' => $clientRefund,
                    'helper_release' => 0,
                    'cancellation_fee' => 0,
                ]);
            } elseif ($resEnum === DisputeResolution::FAVOR_HELPER) {
                // Favor helper: settlement normal (FR-ADM-006)
                $settlement = $this->calculator->calculateCompletion(
                    $order->total_amount,
                    $order->held_amount,
                    $order->advance_actual,
                    $order->voucher_discount
                );
                $clientRefund = $settlement['client_refund'];
                $helperRelease = $settlement['helper_release'];
                $finalStatus = OrderStatus::COMPLETED;

                $this->escrowService->releaseFunds($order, $settlement);
                $order->helper->increment('completed_order_count');
            } elseif ($resEnum === DisputeResolution::SPLIT) {
                // Split 50:50 tanpa komisi (Turunan SA #4 & #8)
                $split = $this->calculator->calculateSplit($order->held_amount);
                $clientRefund = $split['client_refund'];
                $helperRelease = $split['helper_release'];
                $finalStatus = OrderStatus::PARTIALLY_REFUNDED;

                $this->escrowService->refundCancellation($order, [
                    'client_refund' => $clientRefund,
                    'helper_release' => $helperRelease,
                    'cancellation_fee' => $helperRelease,
                ]);
            }

            $dispute->update([
                'resolution' => $resEnum,
                'client_refund_amount' => $clientRefund,
                'helper_release_amount' => $helperRelease,
                'admin_note' => $adminNote,
                'resolved_by_admin_id' => $admin->id,
                'resolved_at' => now(),
            ]);

            $order->update(['status' => $finalStatus]);

            AdminActionLog::create([
                'admin_user_id' => $admin->id,
                'action_type' => AdminActionType::RESOLVE_DISPUTE,
                'target_entity' => 'disputes',
                'target_id' => (string) $dispute->id,
                'note' => "Sengketa diputuskan {$resEnum->value}: {$adminNote}",
            ]);

            OrderStatusHistory::create([
                'order_id' => $order->id,
                'from_status' => OrderStatus::DISPUTED,
                'to_status' => $finalStatus,
                'changed_by_user_id' => $admin->id,
                'note' => "Sengketa diselesaikan oleh admin: {$resEnum->value}",
            ]);

            return [
                'success' => true,
                'data' => [
                    'dispute' => $dispute->fresh(),
                    'order' => $order->fresh(),
                ],
                'message' => 'Sengketa berhasil diputuskan.',
            ];
        });
    }

    /**
     * Client memberikan penilaian satu arah ke Helper (FR-RTG-001, DEC-09, INV-08).
     */
    public function submitRating(User $client, int $orderId, int $score, ?string $review = null): array
    {
        $order = Order::find($orderId);
        if (!$order || $order->client_id !== $client->id) {
            return [
                'success' => false,
                'error_code' => 'NOT_FOUND',
                'message' => 'Pesanan tidak ditemukan atau bukan milik Anda.',
                'status_code' => 404,
            ];
        }

        // FR-RTG-004: Larang rating pada pesanan yang batal
        if ($order->status !== OrderStatus::COMPLETED) {
            return [
                'success' => false,
                'error_code' => 'ORDER_NOT_COMPLETED',
                'message' => 'Penilaian hanya dapat diberikan pada pesanan yang telah selesai.',
                'status_code' => 422,
            ];
        }

        // INV-08: Satu pesanan hanya boleh satu rating
        if ($order->rating()->exists()) {
            return [
                'success' => false,
                'error_code' => 'ALREADY_RATED',
                'message' => 'Pesanan ini sudah Anda berikan penilaian sebelumnya.',
                'status_code' => 422,
            ];
        }

        return DB::transaction(function () use ($order, $client, $score, $review) {
            $rating = Rating::create([
                'order_id' => $order->id,
                'client_id' => $client->id,
                'helper_id' => $order->helper_id,
                'score' => $score,
                'review' => $review,
            ]);

            // Recalculate average rating helper (12_class-diagram.md)
            $order->helper->recalculateRating();

            return [
                'success' => true,
                'data' => $rating,
                'message' => 'Terima kasih, penilaian Anda berhasil disimpan.',
                'status_code' => 201,
            ];
        });
    }
}
