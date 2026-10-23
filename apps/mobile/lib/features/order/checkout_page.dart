import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../core/format/rupiah.dart';
import '../../models/service_category.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/primary_button.dart';
import '../address/address_repository.dart';
import '../chat/chat_store.dart';
import '../wallet/wallet_check.dart';
import 'order_detail_page.dart';
import 'order_models.dart';
import 'order_repository.dart';
import 'order_store.dart';
import 'order_style.dart';
import 'order_success_page.dart';
import 'widgets/order_widgets.dart';

/// Ringkasan pesanan Personal sebelum dibuat: detail tugas, pembayaran
/// TD-Wallet, rincian. "Pesan Sekarang" mengirim `POST /orders` (direct
/// booking) ke helper ini; voucher belum diterima backend.
class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key, required this.helper, required this.category});

  final HelperListing helper;

  /// Kategori Personal di server (`category_id`).
  final ServiceCategory category;

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  late final _store = context.read<OrderStore>();
  final _task = TextEditingController();
  String? _taskError;
  bool _placing = false;

  int get _total => widget.helper.price;

  @override
  void initState() {
    super.initState();
    // Saldo di baris metode pembayaran.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => refreshWalletBalance(context),
    );
  }

  @override
  void dispose() {
    _task.dispose();
    super.dispose();
  }

  /// Alamat utama untuk lokasi pengerjaan, kalau ada. Tidak wajib.
  Future<int?> _primaryAddressId() async {
    try {
      final addresses = await context.read<AddressRepository>().list();
      return addresses.firstOrNull?.id;
    } on ApiException {
      return null;
    }
  }

  Future<void> _submit() async {
    final task = _task.text.trim();
    if (task.length < 5) {
      setState(() => _taskError = 'Ceritakan tugasnya, minimal 5 karakter');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    if (!await ensureWalletBalance(context, _total) || !mounted) return;

    final helper = widget.helper;
    final chats = context.read<ChatStore>();
    setState(() => _placing = true);
    try {
      final order = await _store.place(
        categoryId: widget.category.id,
        helperId: helper.id,
        description: OrderDescription.compose('Personal - ${helper.name}', [
          ('Tugas', task),
          ('Tarif', '${rupiah(helper.price)}/${helper.unit ?? 'pesanan'}'),
        ]),
        price: _total,
        destinationAddressId: await _primaryAddressId(),
      );
      // Pesanan Personal dikerjakan sambil mengobrol: ruangnya disiapkan
      // di tab Obrolan. Gagal dibuat tidak menggagalkan pesanan.
      unawaited(
        chats
            .openWithHelper(
              helperId: helper.id,
              name: helper.name,
              photoUrl: helper.photoUrl,
            )
            .then<void>((_) {}, onError: (Object _) {}),
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => OrderSuccessPage(
            info: OrderSuccessInfo(
              service: 'Personal',
              message:
                  'Menunggu ${helper.name} menerima pesananmu. Kirim detail '
                  'tugas lewat chat.',
              payment: 'TD-Wallet',
              total: _total,
            ),
            orderPage: (_) => OrderDetailPage(orderId: order.id),
          ),
        ),
        // Sisakan beranda di bawahnya supaya halaman sukses bisa kembali ke
        // sana.
        (route) => route.isFirst,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final helper = widget.helper;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.light,
        body: SafeArea(
          bottom: false,
          // Jarak diukur dari desain: tiap bagian (judul + pilihan) 87 dp,
          // baris rincian berjarak 32 dp.
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              const SquareTitleBar(null, shadow: true),
              const SizedBox(height: 21),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: PersonalOrderSummary(
                  helper: helper,
                  details: _TaskField(
                    controller: _task,
                    errorText: _taskError,
                    onChanged: (_) {
                      if (_taskError != null) setState(() => _taskError = null);
                    },
                  ),
                  voucherLabel: 'Voucher belum bisa dipakai',
                  paymentLabel: walletPaymentLabel(context),
                  price: _total,
                  discount: 0,
                  onPayment: () => openWallet(context),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: OrderBottomBar(
          caption: 'Total',
          amount: rupiah(_total),
          button: PrimaryButton(
            label: 'Pesan Sekarang',
            isLoading: _placing,
            onPressed: _submit,
          ),
        ),
      ),
    );
  }
}

/// Helper, voucher, metode pembayaran, dan rincian pembayaran pesanan
/// Personal. Dipakai Checkout (bisa diubah) dan halaman pesanan berjalan
/// (frame 202, hanya dibaca: [onVoucher] dan [onPayment] null).
class PersonalOrderSummary extends StatelessWidget {
  const PersonalOrderSummary({
    super.key,
    required this.helper,
    required this.voucherLabel,
    required this.paymentLabel,
    required this.price,
    required this.discount,
    this.details,
    this.onVoucher,
    this.onPayment,
  });

  final HelperListing helper;

  /// Di bawah baris helper, misal isian detail tugas.
  final Widget? details;
  final String voucherLabel;
  final String paymentLabel;
  final int price;
  final int discount;
  final VoidCallback? onVoucher;
  final VoidCallback? onPayment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            HelperAvatar(
              name: helper.name,
              photoUrl: helper.photoUrl,
              size: 68,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    helper.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.style(
                      size: 18,
                      weight: AppTypography.semiBold,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: HelperStats(
                      rating: helper.rating,
                      completedCount: helper.completedCount,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (details case final details?) ...[
          const SizedBox(height: 24),
          details,
        ],
        const SizedBox(height: 34),
        const Divider(height: 1),
        _OptionRow(
          title: 'Masukkan vocher',
          icon: OrderStyle.iconVoucher,
          value: voucherLabel,
          onTap: onVoucher,
        ),
        const Divider(height: 1),
        _OptionRow(
          title: 'Metode Pembayaran',
          icon: OrderStyle.iconPaymentCard,
          value: paymentLabel,
          onTap: onPayment,
        ),
        const Divider(height: 1),
        const SizedBox(height: 21),
        Text(
          'Rincian Pembayaran',
          style: AppTypography.style(size: 14, weight: AppTypography.semiBold),
        ),
        const SizedBox(height: 26),
        _PriceRow(label: 'Jasa', value: rupiah(price, spaced: false)),
        if (discount > 0) ...[
          const SizedBox(height: 20),
          _PriceRow(
            label: 'Vocher',
            value: rupiah(-discount, spaced: false),
            valueColor: AppColors.primary,
          ),
        ],
        const SizedBox(height: 20),
        _PriceRow(
          label: 'Total',
          value: rupiah(price - discount, spaced: false),
          bold: true,
        ),
      ],
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.title,
    required this.icon,
    required this.value,
    required this.onTap,
  });

  final String title;
  final String icon;
  final String value;

  /// Null: hanya dibaca, tanpa panah.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.style(
                      size: 14,
                      weight: AppTypography.semiBold,
                    ),
                  ),
                  const SizedBox(height: 19),
                  Row(
                    children: [
                      OrderIcon(icon, size: 14, color: AppColors.textPrimary),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.style(
                            size: 12,
                            weight: AppTypography.regular,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
          ],
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.value,
    this.valueColor = AppColors.textPrimary,
    this.bold = false,
  });

  final String label;
  final String value;
  final Color valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final weight = bold ? AppTypography.semiBold : AppTypography.regular;

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTypography.style(size: 12, weight: weight),
          ),
        ),
        Text(
          value,
          style: AppTypography.style(
            size: 12,
            weight: weight,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

/// Isian "Detail tugas": backend mewajibkan deskripsi pesanan.
class _TaskField extends StatelessWidget {
  const _TaskField({
    required this.controller,
    required this.errorText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String? errorText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: color),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Detail tugas',
          style: AppTypography.style(size: 14, weight: AppTypography.semiBold),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          onChanged: onChanged,
          minLines: 3,
          maxLines: 6,
          maxLength: 2000,
          textCapitalization: TextCapitalization.sentences,
          style: AppTypography.style(
            size: 12,
            weight: AppTypography.regular,
            height: 1.5,
          ),
          decoration: InputDecoration(
            hintText:
                'Ceritakan yang perlu dikerjakan, misal: desain logo usaha '
                'kopi, 3 pilihan, selesai Jumat.',
            errorText: errorText,
            filled: true,
            fillColor: AppColors.light,
            contentPadding: const EdgeInsets.all(12),
            enabledBorder: border(const Color(0xFFDDDDDD)),
            focusedBorder: border(AppColors.primary),
            errorBorder: border(AppColors.error),
            focusedErrorBorder: border(AppColors.error),
          ),
        ),
      ],
    );
  }
}
