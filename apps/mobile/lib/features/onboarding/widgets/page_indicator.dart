import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

/// Titik penanda halaman onboarding. Halaman aktif tampil sebagai pil merah
/// yang lebih lebar, sisanya titik pink muda.
class PageIndicator extends StatelessWidget {
  const PageIndicator({super.key, required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: i == current ? 22 : 9,
            height: 9,
            margin: EdgeInsetsDirectional.only(start: i == 0 ? 0 : 5),
            decoration: BoxDecoration(
              color: i == current ? AppColors.primary : AppColors.primaryLight,
              borderRadius: BorderRadius.circular(4.5),
            ),
          ),
      ],
    );
  }
}
