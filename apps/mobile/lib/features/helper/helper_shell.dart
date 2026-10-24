import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../chat/chat_list_view.dart';
import '../home/home_assets.dart';
import '../home/home_metrics.dart';
import '../home/widgets/home_bottom_nav.dart' show NavSvgIcon;
import 'helper_dashboard_view.dart';
import 'helper_job_page.dart';
import 'helper_jobs_view.dart';
import 'helper_profile_view.dart';
import 'helper_store.dart';
import 'job_chat.dart';
import 'widgets/helper_widgets.dart';

enum HelperTab { beranda, pesanan, chat, profil }

/// Mode Helper: Beranda, Pesanan, Chat, dan Profil (desain Helper).
///
/// Selama terbuka, daftar pekerjaan diperiksa ulang berkala supaya
/// permintaan baru dan keputusan Client ikut terlihat.
class HelperShell extends StatefulWidget {
  const HelperShell({super.key, this.initialTab = HelperTab.beranda});

  final HelperTab initialTab;

  @override
  State<HelperShell> createState() => _HelperShellState();
}

class _HelperShellState extends State<HelperShell> {
  late final _store = context.read<HelperStore>();
  late HelperTab _tab = widget.initialTab;

  @override
  void initState() {
    super.initState();
    _store.addListener(_showNews);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _store.refresh();
      _store.startPolling();
    });
  }

  @override
  void dispose() {
    _store.removeListener(_showNews);
    _store.stopPolling();
    super.dispose();
  }

  /// Pengganti notifikasi: kabar dari pemeriksaan berkala tampil sebagai
  /// snackbar di halaman mana pun yang sedang terbuka.
  void _showNews() {
    final news = _store.takeNews();
    if (news.isEmpty || !mounted) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    for (final (:kind, :job) in news) {
      final client = job.client?.name ?? 'Client';
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          // Bawaannya snackbar beraksi tidak pernah hilang sendiri, jadi
          // kabar berikutnya tertahan di antrean.
          persist: false,
          content: Text(switch (kind) {
            HelperNewsKind.request =>
              'Permintaan baru dari $client: ${job.title}',
            HelperNewsKind.approved =>
              '$client menyetujui penawaranmu. Kamu bisa mulai perjalanan.',
          }),
          action: SnackBarAction(
            label: 'Lihat',
            onPressed: () => navigator.push(
              MaterialPageRoute<void>(
                builder: (_) => HelperJobPage(orderId: job.id),
              ),
            ),
          ),
        ),
      );
    }
  }

  void _goTo(HelperTab tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) {
    // Kembali di tab lain membawa ke Beranda, seperti mode Client.
    return PopScope(
      canPop: _tab == HelperTab.beranda,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goTo(HelperTab.beranda);
      },
      child: Scaffold(
        backgroundColor: HelperStyle.background,
        body: switch (_tab) {
          HelperTab.beranda => HelperDashboardView(
            onOpenJobs: () => _goTo(HelperTab.pesanan),
          ),
          HelperTab.pesanan => const HelperJobsView(),
          HelperTab.chat => const _HelperChatView(),
          HelperTab.profil => const HelperProfileView(),
        },
        bottomNavigationBar: HelperBottomNav(current: _tab, onSelected: _goTo),
      ),
    );
  }
}

class _HelperChatView extends StatelessWidget {
  const _HelperChatView();

  @override
  Widget build(BuildContext context) {
    final store = context.read<HelperStore>();
    return Column(
      children: [
        const HelperHeader(
          title: 'Chat',
          subtitle: 'Koordinasi langsung dengan Client',
          back: false,
        ),
        Expanded(
          child: ChatListView(
            forHelper: true,
            roomPage: (room) => helperChatRoom(room, switch (room.orderId) {
              final id? => store.byId(id),
              null => null,
            }),
          ),
        ),
      ],
    );
  }
}

/// Bilah bawah mode Helper: tab aktif merah dengan latar pink di belakang
/// ikonnya.
class HelperBottomNav extends StatelessWidget {
  const HelperBottomNav({
    super.key,
    required this.current,
    required this.onSelected,
  });

  final HelperTab current;
  final ValueChanged<HelperTab> onSelected;

  static const _tabs = [
    (HelperTab.beranda, 'Beranda', HomeAssets.navHome, 25.0),
    (HelperTab.pesanan, 'Pesanan', HomeAssets.navActivity, 26.0),
    (HelperTab.chat, 'Chat', HomeAssets.navChat, 29.0),
    (HelperTab.profil, 'Profil', HomeAssets.navProfile, 30.0),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.light,
        border: Border(top: BorderSide(color: HelperStyle.cardBorder)),
      ),
      child: SafeArea(
        top: false,
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: SizedBox(
            height: HomeMetrics.navHeight,
            child: Row(
              children: [
                for (final (tab, label, asset, height) in _tabs)
                  Expanded(
                    child: _NavItem(
                      label: label,
                      asset: asset,
                      height: height,
                      active: tab == current,
                      onTap: () => onSelected(tab),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.asset,
    required this.height,
    required this.active,
    required this.onTap,
  });

  final String label;
  final String asset;
  final double height;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.textPrimary;
    return Semantics(
      button: true,
      selected: active,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 32,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              decoration: BoxDecoration(
                color: active ? HelperStyle.softRed : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: SizedBox.square(
                dimension: HomeMetrics.navIconSize,
                child: Center(child: NavSvgIcon(asset, height, color)),
              ),
            ),
            const SizedBox(height: HomeMetrics.navLabelGap),
            Text(
              label,
              style: AppTypography.style(
                size: HomeMetrics.navLabelSize,
                weight: AppTypography.semiBold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pesan gagal memuat mode Helper, dipakai di beberapa tab.
String helperErrorText(ApiException? error) =>
    error?.message ?? 'Coba lagi sebentar lagi.';
