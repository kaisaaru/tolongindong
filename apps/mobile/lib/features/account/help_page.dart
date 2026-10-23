import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../home/widgets/tips_section.dart';
import 'widgets/account_menu.dart';

/// Pusat Bantuan & Kebijakan: tips memakai app (sama dengan di beranda) dan
/// informasi aplikasi beserta lisensinya.
class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.light,
        body: SafeArea(
          child: Column(
            children: [
              const AccountTitleBar('Pusat Bantuan'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AccountStyle.side,
                    20,
                    AccountStyle.side,
                    24,
                  ),
                  children: [
                    const AccountSectionTitle('Tips memakai TolonginDong'),
                    AccountMenuCard(
                      children: [
                        for (final tip in AppTip.all)
                          AccountMenuRow(
                            icon: tip.icon,
                            tint: const Color(0xFFF0F9FF),
                            label: tip.title,
                            onTap: () => showTipSheet(context, tip),
                          ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    const AccountSectionTitle('Kebijakan'),
                    AccountMenuCard(
                      children: [
                        AccountMenuRow(
                          icon: Icons.info_outline_rounded,
                          tint: const Color(0xFFF1F5F9),
                          label: 'Tentang TolonginDong',
                          onTap: () => showAboutDialog(
                            context: context,
                            applicationName: 'TolonginDong',
                            applicationVersion: '1.0.0',
                            applicationLegalese:
                                'Bantuan helper terverifikasi untuk tugas '
                                'harianmu.',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
