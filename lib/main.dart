import 'package:flutter/material.dart';

import 'app.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = AppStorage();
  await storage.init();
  runApp(AiBossApp(storage: storage));
}
