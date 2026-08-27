import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color primary = Color(0xFF0057A8);
  static const Color onPrimary = Colors.white;
  static const Color primaryContainer = Color(0xFFD7E9FF);
  static const Color onPrimaryContainer = Color(0xFF001C38);

  static const Color secondary = Color(0xFF006874);
  static const Color onSecondary = Colors.white;
  static const Color secondaryContainer = Color(0xFF9EEFFD);
  static const Color onSecondaryContainer = Color(0xFF001F24);

  static const Color surface = Color(0xFFF7F9FC);
  static const Color surfaceContainerLowest = Colors.white;
  static const Color surfaceContainerLow = Color(0xFFF0F4F8);
  static const Color surfaceContainer = Color(0xFFE8EEF4);
  static const Color onSurface = Color(0xFF18212B);
  static const Color onSurfaceVariant = Color(0xFF44505C);
  static const Color outline = Color(0xFF75818D);
  static const Color outlineVariant = Color(0xFFC4CBD3);

  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Colors.white;
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF410002);

  static const Color success = Color(0xFF176B3A);
  static const Color successContainer = Color(0xFFD5F5DF);
  static const Color onSuccessContainer = Color(0xFF07391C);

  static const Color warning = Color(0xFF8A4B00);
  static const Color warningContainer = Color(0xFFFFE0B2);
  static const Color onWarningContainer = Color(0xFF402400);

  static const Color information = primary;
  static const Color informationContainer = primaryContainer;
  static const Color onInformationContainer = onPrimaryContainer;

  static const Color neutralContainer = Color(0xFFE4E9EF);
  static const Color onNeutralContainer = Color(0xFF303943);

  static const Color developmentContainer = Color(0xFFFFF4D6);
  static const Color onDevelopmentContainer = Color(0xFF493900);
  static const Color developmentBorder = Color(0xFFE0B84D);
}
