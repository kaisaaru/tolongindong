import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../core/media/photo_picker.dart';
import '../../theme/app_typography.dart';
import '../household/household_models.dart';
import '../order/order_repository.dart';
import 'helper_store.dart';
import 'widgets/helper_widgets.dart';

/// Bukti penyelesaian, lalu "Tandai Selesai" (`awaiting_confirmation`).
///
/// Backend belum punya tempat menyimpan foto pesanan, jadi foto hanya
/// tampil di sini dan tidak wajib (keputusan tim, 23 Okt 2026). Setelah
/// endpoint unggah ada, kirim foto sebelum menandai selesai.
class ProofPage extends StatefulWidget {
  const ProofPage({super.key, required this.job});

  final ServerOrder job;

  @override
  State<ProofPage> createState() => _ProofPageState();
}

class _ProofPageState extends State<ProofPage> {
  late final _store = context.read<HelperStore>();
  PickedPhoto? _photo;
  DateTime? _takenAt;
  bool _sending = false;

  Future<void> _pick({required bool camera}) async {
    final picked = await context.read<PhotoPicker>().pick(camera: camera);
    if (picked == null || !mounted) return;
    setState(() {
      _photo = picked;
      _takenAt = _store.now;
    });
  }

  Future<void> _finish() async {
    final client = widget.job.client?.name ?? 'Client';
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tandai pekerjaan selesai?'),
        content: Text(
          'Pendapatan menunggu konfirmasi $client. Pastikan pekerjaan sudah '
          'benar-benar beres.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ya, tandai selesai'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;

    setState(() => _sending = true);
    try {
      await _store.advance(widget.job.id, OrderStatus.awaitingConfirmation);
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
    final photo = _photo;
    final takenAt = _takenAt;
    final address = job.destination ?? job.pickup;
    final caption = AppTypography.style(
      size: 10,
      weight: AppTypography.regular,
      color: HelperStyle.muted,
      height: 1.5,
    );

    return Scaffold(
      backgroundColor: HelperStyle.background,
      body: Column(
        children: [
          HelperHeader(
            title: 'Bukti penyelesaian',
            subtitle:
                '${HelperStyle.categoryName(job.categoryCode)} · #${job.number}',
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                Text(
                  job.title,
                  style: AppTypography.style(
                    size: 14,
                    weight: AppTypography.semiBold,
                    color: HelperStyle.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${job.client?.name ?? 'Client'} · '
                  '${dateLabel(job.createdAt)} ${clockLabel(job.createdAt)}',
                  style: caption,
                ),
                if (address != null) Text(address.fullAddress, style: caption),
                const SizedBox(height: 14),
                HelperCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            photo == null
                                ? Icons.photo_camera_outlined
                                : Icons.check_circle_outline_rounded,
                            size: 16,
                            color: photo == null
                                ? HelperStyle.muted
                                : HelperStyle.green,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            photo == null
                                ? 'Foto bukti · opsional'
                                : 'Foto bukti terlampir',
                            style: AppTypography.style(
                              size: 11,
                              weight: AppTypography.semiBold,
                              color: HelperStyle.ink,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: AspectRatio(
                          aspectRatio: 16 / 7,
                          child: photo == null
                              ? const _PhotoPlaceholder()
                              : Image.file(
                                  File(photo.path),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      const _PhotoPlaceholder(),
                                ),
                        ),
                      ),
                      if (photo != null && takenAt != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${photo.name} · ${clockLabel(takenAt)}',
                          style: caption,
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: HelperButton(
                              label: 'Ambil foto',
                              soft: true,
                              onPressed: () => _pick(camera: true),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: HelperButton(
                              label: photo == null
                                  ? 'Pilih galeri'
                                  : 'Ubah foto',
                              soft: true,
                              onPressed: () => _pick(camera: false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Pastikan foto menunjukkan hasil pekerjaan atau bukti '
                        'penerimaan.',
                        style: caption,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const HelperBanner(
                  tone: BannerTone.gray,
                  title: 'Foto belum terkirim ke Client',
                  message:
                      'Unggah foto bukti menyusul. Simpan fotonya sebagai '
                      'cadangan kalau Client menanyakan.',
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: HelperBottomBar(
        children: [
          HelperButton(
            label: 'Tandai Selesai',
            isLoading: _sending,
            onPressed: _finish,
          ),
        ],
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFF3ECEC),
      child: Center(
        child: Icon(Icons.image_outlined, size: 36, color: HelperStyle.muted),
      ),
    );
  }
}
