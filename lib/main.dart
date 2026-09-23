import 'package:flutter/material.dart';

import 'main_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const ThanuSmartApp());
}

class ThanuSmartApp extends StatelessWidget {
  const ThanuSmartApp({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'Thanu Smart',

      theme: ThemeData(
        useMaterial3: true,

        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
        ),

        scaffoldBackgroundColor:
            const Color(0xFFF8FAFC),
      ),

      home: const MainPage(),
    );
  }
}