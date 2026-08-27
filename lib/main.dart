import 'package:flutter/material.dart';

import 'app/prasa_assist_app.dart';
import 'core/bootstrap/app_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dependencies = await bootstrapApplication();
  runApp(PrasaAssistApp(dependencies: dependencies));
}
