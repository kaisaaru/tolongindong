import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Tombol "Login dengan Google". Gayanya dari `outlinedButtonTheme` di
/// `AppTheme`.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset('assets/icons/google.svg', width: 22, height: 22),
          const SizedBox(width: 12),
          const Flexible(child: Text('Login dengan Google')),
        ],
      ),
    );
  }
}
