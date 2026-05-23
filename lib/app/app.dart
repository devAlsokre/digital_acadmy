import 'package:flutter/material.dart';

import 'router.dart';
import 'theme.dart';

class DigitalAcademyApp extends StatelessWidget {
  const DigitalAcademyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Digital Academy',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
    );
  }
}
