import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/device.dart';
import '../../state/device_controller.dart';
import '../../state/device_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';
import 'console_tab.dart';
import 'games_tab.dart';
import 'lists_tab.dart';
import 'settings_tab.dart';
import 'storage_tab.dart';

class DeviceHome extends StatelessWidget {
  final Device device;
  const DeviceHome({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    final store = context.read<DeviceStore>();
    return ChangeNotifierProvider(
      create: (_) => DeviceController(device, store)..startPolling(),
      child: const _DeviceScaffold(),
    );
  }
}

class _DeviceScaffold extends StatefulWidget {
  const _DeviceScaffold();

  @override
  State<_DeviceScaffold> createState() => _DeviceScaffoldState();
}

class _DeviceScaffoldState extends State<_DeviceScaffold> {
  int _index = 0;

  static const _titles = ['Games', 'Lists', 'Storage', 'Console', 'Settings'];

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DeviceController>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(controller.device.name,
                style: context.text.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600)),
            Text(_titles[_index],
                style: context.text.labelSmall
                    ?.copyWith(color: context.colors.onSurfaceVariant)),
          ],
        ),
        actions: [
          if (controller.nowPlaying.playing)
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: context.colors.error),
              onPressed: () async {
                if (await confirmDialog(context,
                    title: 'Stop game',
                    message:
                        'Stop "${controller.nowPlaying.name ?? 'the game'}" on the machine?',
                    confirmLabel: 'STOP')) {
                  if (context.mounted) {
                    await runGuarded(context, controller.stopGame, success: 'Game stopped');
                  }
                }
              },
              icon: const Icon(Icons.stop, size: 18),
              label: const Text('Stop'),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: const [
          GamesTab(),
          ListsTab(),
          StorageTab(),
          ConsoleTab(),
          SettingsTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.videogame_asset_outlined),
              selectedIcon: Icon(Icons.videogame_asset),
              label: 'Games'),
          NavigationDestination(
              icon: Icon(Icons.playlist_play_outlined),
              selectedIcon: Icon(Icons.playlist_play),
              label: 'Lists'),
          NavigationDestination(
              icon: Icon(Icons.save_outlined),
              selectedIcon: Icon(Icons.save),
              label: 'Storage'),
          NavigationDestination(
              icon: Icon(Icons.terminal_outlined),
              selectedIcon: Icon(Icons.terminal),
              label: 'Console'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings'),
        ],
      ),
    );
  }
}
