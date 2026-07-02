import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/device.dart';
import '../../services/discovery.dart';
import '../../state/device_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';
import '../device/device_home.dart';
import 'add_device_sheet.dart';
import 'device_login_screen.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final _discovered = <String>{};
  StreamSubscription? _scanSub;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScan());
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    super.dispose();
  }

  void _startScan() {
    if (_scanning) return;
    setState(() {
      _scanning = true;
      _discovered.clear();
    });
    _scanSub?.cancel();
    _scanSub = DiscoveryService().scan().listen(
      (host) {
        if (mounted) setState(() => _discovered.add(host));
      },
      onDone: () {
        if (mounted) setState(() => _scanning = false);
      },
      onError: (_) {
        if (mounted) setState(() => _scanning = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DeviceStore>();
    final newHosts = _discovered.where((h) => !store.hasHost(h)).toList()..sort();
    final hasContent = store.devices.isNotEmpty || newHosts.isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _startScan(),
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                titleSpacing: 16,
                title: Align(
                  alignment: Alignment.centerLeft,
                  child: Image.asset('assets/images/banner.png', height: 30),
                ),
                actions: [
                  _scanAction(),
                  IconButton(
                    tooltip: 'Add by IP',
                    onPressed: () => _addManual(context),
                    icon: const Icon(Icons.add),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
              if (!store.loaded)
                const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()))
              else if (!hasContent)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.videogame_asset_outlined,
                    title: _scanning ? 'Searching your network…' : 'No machines yet',
                    subtitle: _scanning
                        ? 'Looking for Arcader machines on your Wi-Fi.'
                        : 'Nothing found automatically. Add a machine by its IP address.',
                    action: _scanning
                        ? null
                        : FilledButton.icon(
                            onPressed: () => _addManual(context),
                            icon: const Icon(Icons.add),
                            label: const Text('Add by IP'),
                          ),
                  ),
                )
              else ...[
                if (store.devices.isNotEmpty)
                  const _SliverSectionHeader('My machines'),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  sliver: SliverList.separated(
                    itemCount: store.devices.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => DeviceCard(device: store.devices[i]),
                  ),
                ),
                if (newHosts.isNotEmpty) ...[
                  _SliverSectionHeader('Discovered on network • ${newHosts.length}'),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList.separated(
                      itemCount: newHosts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) => DiscoveredCard(
                        host: newHosts[i],
                        onPaired: _startScan,
                      ),
                    ),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _scanAction() {
    if (_scanning) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14),
        child: Center(
          child: SizedBox(
              width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    return IconButton(
      tooltip: 'Rescan network',
      onPressed: _startScan,
      icon: const Icon(Icons.radar_outlined),
    );
  }

  Future<void> _addManual(BuildContext context) async {
    final store = context.read<DeviceStore>();
    final device = await showAddDeviceSheet(context);
    if (device != null && !store.hasHost(device.host)) {
      await store.add(device);
    }
  }
}

class _SliverSectionHeader extends StatelessWidget {
  final String text;
  const _SliverSectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 10),
      sliver: SliverToBoxAdapter(child: SectionLabel(text)),
    );
  }
}

Future<void> openDevice(BuildContext context, Device device) async {
  final store = context.read<DeviceStore>();
  Device target = device;
  if (!target.isAuthenticated) {
    final token = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => DeviceLoginScreen(device: target)),
    );
    if (token == null || !context.mounted) return;
    target = target.copyWith(token: token);
    if (store.byId(target.id) != null) {
      await store.update(target);
    } else {
      await store.add(target);
    }
  }
  if (!context.mounted) return;
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => DeviceHome(device: store.byId(target.id) ?? target)),
  );
}

class DeviceCard extends StatelessWidget {
  final Device device;
  const DeviceCard({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    return _MachineCard(
      onTap: () => openDevice(context, device),
      title: device.name,
      subtitle: device.host,
      trailing: _menu(context),
    );
  }

  Widget _menu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (v) async {
        final store = context.read<DeviceStore>();
        switch (v) {
          case 'rename':
            final name = await promptDialog(context,
                title: 'Rename machine', initialValue: device.name, label: 'Name');
            if (name != null && name.isNotEmpty) {
              await store.update(device.copyWith(name: name));
            }
            break;
          case 'remove':
            if (context.mounted &&
                await confirmDialog(context,
                    title: 'Remove machine',
                    message: 'Remove "${device.name}" from this app?',
                    confirmLabel: 'Remove')) {
              await store.remove(device.id);
            }
            break;
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'rename', child: Text('Rename')),
        PopupMenuItem(value: 'remove', child: Text('Remove')),
      ],
    );
  }
}

class DiscoveredCard extends StatelessWidget {
  final String host;
  final VoidCallback onPaired;
  const DiscoveredCard({super.key, required this.host, required this.onPaired});

  @override
  Widget build(BuildContext context) {
    return _MachineCard(
      onTap: () => _connect(context),
      title: 'Arcader',
      subtitle: host,
      pill: StatusPill('Tap to pair',
          color: context.colors.primary, icon: Icons.link),
      trailing: Icon(Icons.add_circle_outline, color: context.colors.primary),
    );
  }

  Future<void> _connect(BuildContext context) async {
    final name = await promptDialog(context,
        title: 'Name this machine', initialValue: 'Arcader', label: 'Display name');
    if (name == null || !context.mounted) return;
    final device = Device(
      id: newDeviceId(),
      name: name.isEmpty ? 'Arcader' : name,
      host: host,
    );
    await openDevice(context, device);
    onPaired();
  }
}

class _MachineCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? pill;
  final Widget? trailing;
  final VoidCallback onTap;

  const _MachineCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.pill,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 58,
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: context.colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Image.asset('assets/images/arcade-machine.png',
                    fit: BoxFit.contain),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: context.text.bodyMedium
                            ?.copyWith(color: context.colors.onSurfaceVariant)),
                    if (pill != null) ...[
                      const SizedBox(height: 8),
                      pill!,
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}
