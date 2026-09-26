import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/services.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: NeonTheme.bgBottom,
  ));
  await Services.init();
  runApp(const NeonFlowApp());
  // Audio, ads and billing start after the first frame so launch is instant.
  unawaited(Services.initBackground());
}

class NeonFlowApp extends StatelessWidget {
  const NeonFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Neon Flow',
      debugShowCheckedModeBanner: false,
      theme: NeonTheme.data,
      home: const HomeScreen(),
    );
  }
}
