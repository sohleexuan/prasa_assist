import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'prasa_assist_home_page.dart';

class PrasaAssistApp extends StatelessWidget {
  const PrasaAssistApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PrasaAssist',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const PrasaAssistHomePage(),
    );
  }
}
