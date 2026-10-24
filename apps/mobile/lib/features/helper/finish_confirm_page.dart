import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../core/format/rupiah.dart';
import '../../theme/app_typography.dart';
import '../order/order_repository.dart';
import '../order/widgets/order_widgets.dart';
import 'helper_store.dart';
import 'widgets/helper_widgets.dart';

/// "Konfirmasi penyelesaian" untuk Household dan Personal: periksa sekali
/// lagi, lalu tandai selesai (`awaiting_confirmation`) tanpa foto bukti.
/// Delivery memakai halaman bukti foto.
class FinishConfirmPage extends StatefulWidget {
  const FinishConfirmPage({super.key, required this.job});

  final ServerOrder job;

  @override
  State<FinishConfirmPage> createState() => _FinishConfirmPageState();
}

class _FinishConfirmPageState extends State<FinishConfirmPage> {
  bool _sending = false;

  Future<void> _finish() async {
    setState(() => _sending = true);
    try {
      await context.read<HelperStore>().advance(
        widget.job.id,
        OrderStatus.awaitingConfirmation,
      );
      // Halaman pekerjaan di bawahnya berganti jadi "Pekerjaan selesai".
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final client = job.client?.name ?? 'Client';
    final first = client.trim().split(' ').first;

    return Scaffold(
      backgroundColor: HelperStyle.background,
      body: Column(
        children: [
          const HelperHeader(
            title: 'Konfirmasi penyelesaian',
            subtitle: 'Periksa kembali sebelum menandai selesai',
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              children: [
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: HelperStyle.softRed,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const OrderIcon(HelperStyle.iconHourglass, size: 26),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Pekerjaan sudah selesai?',
                  textAlign: TextAlign.center,
                  style: AppTypography.style(
                    size: 17,
                    weight: AppTypography.semiBold,
                    color: HelperStyle.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Pastikan kebutuhan $first telah dikerjakan sesuai '
                  'kesepakatan.',
                  textAlign: TextAlign.center,
                  style: AppTypography.style(
                    size: 11,
                    weight: AppTypography.regular,
                    color: HelperStyle.muted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                HelperCard(
                  child: Column(
                    children: [
                      JobSummary(order: job, details: false),
                      const Divider(height: 22, color: HelperStyle.cardBorder),
                      HelperRow(
                        'Harga disepakati',
                        rupiah(job.price, spaced: false),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                HelperBanner(
                  title: 'Setelah kamu menandai selesai',
                  message:
                      'Pesanan menunggu konfirmasi $first. Pendapatan bersih '
                      'tetap tertunda sampai dikonfirmasi, atau otomatis '
                      'setelah 24 jam.',
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: HelperBottomBar(
        children: [
          HelperButton(
            label: 'Kembali',
            soft: true,
            onPressed: _sending ? null : () => Navigator.of(context).pop(),
          ),
          HelperButton(
            label: 'Ya, Selesaikan',
            isLoading: _sending,
            onPressed: _finish,
          ),
        ],
      ),
    );
  }
}
