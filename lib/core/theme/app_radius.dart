import 'package:flutter/material.dart';

abstract final class AppRadius {
  static const double smallValue = 8;
  static const double mediumValue = 12;
  static const double largeValue = 16;

  static const BorderRadius small = BorderRadius.all(
    Radius.circular(smallValue),
  );
  static const BorderRadius medium = BorderRadius.all(
    Radius.circular(mediumValue),
  );
  static const BorderRadius card = BorderRadius.all(
    Radius.circular(largeValue),
  );
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));
}
