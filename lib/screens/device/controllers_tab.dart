import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/controller_profile.dart';
import '../../services/api_client.dart';
import '../../state/device_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';
import 'profile_manage_games.dart';

class ControllersTab extends StatefulWidget {
  const ControllersTab({super.key});

  @override
  State<ControllersTab> createState() => _ControllersTabState();
}

class _ControllersTabState extends State<ControllersTab> {
  List<ControllerProfile>? _profiles;
  String? _error;

  ApiClient get _api => context.read<DeviceController>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profiles = await _api.getControllerProfiles();
      if (!mounted) return;
      setState(() {
        _profiles = profiles;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _create() async {
    final name = await promptDialog(context,
        title: 'New controller profile',
        label: 'Name',
        confirmLabel: 'Create');
    if (name != null && name.isNotEmpty && mounted) {
      if (await runGuarded(context, () => _api.createControllerProfile(name),
          success: 'Profile created')) {
        _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'controllers-fab',
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('New profile'),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_error != null) {
      return EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load profiles',
          subtitle: _error,
          action: OutlinedButton(onPressed: _load, child: const Text('RETRY')));
    }
    if (_profiles == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_profiles!.isEmpty) {
      return const EmptyState(
          icon: Icons.videogame_asset,
          title: 'No profiles',
          subtitle:
              'Create a profile to map your joysticks & buttons, then assign it to games.');
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        itemCount: _profiles!.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _ProfileCard(
          profile: _profiles![i],
          onChanged: _load,
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final ControllerProfile profile;
  final VoidCallback onChanged;
  const _ProfileCard({required this.profile, required this.onChanged});

  Future<void> _configure(BuildContext context, ApiClient api) async {
    await runGuarded(
      context,
      () => api.configureControllerProfile(profile.id),
      success:
          'Configuration started on the arcade machine. Follow the on-screen prompts.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<DeviceController>().api;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(profile.isDefault ? Icons.star : Icons.videogame_asset,
                    color: profile.isDefault
                        ? context.semantic.warning
                        : context.colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                if (!profile.isDefault)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (v) async {
                      if (v == 'rename') {
                        final name = await promptDialog(context,
                            title: 'Rename profile',
                            initialValue: profile.name,
                            label: 'Name');
                        if (name != null && name.isNotEmpty && context.mounted) {
                          if (await runGuarded(context,
                              () => api.renameControllerProfile(profile.id, name),
                              success: 'Renamed')) {
                            onChanged();
                          }
                        }
                      } else if (v == 'delete') {
                        if (await confirmDialog(context,
                            title: 'Delete profile',
                            message:
                                'Delete "${profile.name}"? Games using it will fall back to the default profile.',
                            confirmLabel: 'DELETE')) {
                          if (context.mounted &&
                              await runGuarded(context,
                                  () => api.deleteControllerProfile(profile.id),
                                  success: 'Deleted')) {
                            onChanged();
                          }
                        }
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'rename', child: Text('Rename')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (profile.isDefault)
                  StatusPill('All other games', color: context.colors.primary)
                else
                  Text('${profile.itemCount} games',
                      style: context.text.bodyMedium
                          ?.copyWith(color: context.colors.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 6),
            Text(profile.bindingsSummary,
                style: context.text.bodySmall
                    ?.copyWith(color: context.colors.onSurfaceVariant)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _configure(context, api),
                    icon: const Icon(Icons.tune, size: 18),
                    label: const Text('Configure layout'),
                  ),
                ),
                if (!profile.isDefault) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final controller = context.read<DeviceController>();
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChangeNotifierProvider.value(
                              value: controller,
                              child: ProfileManageGames(profile: profile),
                            ),
                          ),
                        );
                        onChanged();
                      },
                      icon: const Icon(Icons.playlist_add_check, size: 18),
                      label: const Text('Games'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
