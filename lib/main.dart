import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import 'app/app.dart';
import 'core/background/notification_polling_task.dart';
import 'core/config/supabase_config.dart';
import 'core/foreground/foreground_notification_service.dart';
import 'core/services/local_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isAndroid) {
    ForegroundNotificationService.initialize();
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
    await LocalNotificationService.initialize();
  }

  await Supabase.initialize(
    url: SupabaseConfig.initializationUrl,
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(const ProviderScope(child: DigitalAcademyApp()));
}
