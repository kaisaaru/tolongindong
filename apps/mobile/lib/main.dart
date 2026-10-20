import 'package:flutter/material.dart';

import 'features/splash/splash_page.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tolongin Dong',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // Penentuan halaman awal ada di SplashPage, bukan di sini.
      home: const SplashPage(),
    );
  }
}
