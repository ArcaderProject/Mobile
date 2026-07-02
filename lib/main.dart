import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/devices/devices_screen.dart';
import 'state/device_store.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ArcaderApp());
}

class ArcaderApp extends StatelessWidget {
  const ArcaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DeviceStore()..load(),
      child: MaterialApp(
        title: 'Arcader',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        home: const DevicesScreen(),
      ),
    );
  }
}
