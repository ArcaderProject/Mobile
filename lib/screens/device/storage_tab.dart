import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/save_folder.dart';
import '../../services/api_client.dart';
import '../../state/device_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';
import 'save_folder_detail.dart';

class StorageTab extends StatefulWidget {
  const StorageTab({super.key});

  @override
  State<StorageTab> createState() => _StorageTabState();
}

class _StorageTabState extends State<StorageTab> {
  List<SaveFolder>? _folders;
  String? _error;

  ApiClient get _api => context.read<DeviceController>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final folders = await _api.getSaveFolders();
      if (!mounted) return;
      setState(() {
        _folders = folders;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _create() async {
    final name = await promptDialog(context,
        title: 'New storage profile', label: 'Profile name', confirmLabel: 'CREATE');
    if (name != null && name.isNotEmpty && mounted) {
      if (await runGuarded(context, () => _api.createSaveFolder(name), success: 'Profile created')) {
        _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
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
          title: 'Could not load storage',
          subtitle: _error,
          action: OutlinedButton(onPressed: _load, child: const Text('RETRY')));
    }
    if (_folders == null) return const Center(child: CircularProgressIndicator());
    if (_folders!.isEmpty) {
      return const EmptyState(icon: Icons.save_outlined, title: 'No save profiles');
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        itemCount: _folders!.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _FolderCard(folder: _folders![i], onChanged: _load),
      ),
    );
  }
}

class _FolderCard extends StatelessWidget {
  final SaveFolder folder;
  final VoidCallback onChanged;
  const _FolderCard({required this.folder, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final api = context.read<DeviceController>().api;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          final controller = context.read<DeviceController>();
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider.value(
                value: controller,
                child: SaveFolderDetail(folder: folder),
              ),
            ),
          );
          onChanged();
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(folder.isDefault ? Icons.public : Icons.save,
                      color: folder.isDefault
                          ? context.semantic.warning
                          : context.colors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(folder.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  _menu(context, api),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (folder.isActive)
                    StatusPill('Active', color: context.colors.primary, icon: Icons.bolt),
                  if (folder.isLocked)
                    StatusPill('Locked', color: context.semantic.warning, icon: Icons.lock),
                  if (folder.isDefault)
                    StatusPill('Global', color: context.colors.onSurfaceVariant),
                ],
              ),
              if (!folder.isActive) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => runGuarded(context, () => api.activateSaveFolder(folder.uuid),
                        success: '"${folder.name}" activated').then((ok) {
                      if (ok) onChanged();
                    }),
                    child: const Text('Activate'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _menu(BuildContext context, ApiClient api) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (v) async {
        switch (v) {
          case 'rename':
            final name = await promptDialog(context,
                title: 'Rename profile', initialValue: folder.name, label: 'Name');
            if (name != null && name.isNotEmpty && context.mounted) {
              if (await runGuarded(context, () => api.renameSaveFolder(folder.uuid, name),
                  success: 'Renamed')) {
                onChanged();
              }
            }
            break;
          case 'lock':
            if (await runGuarded(context, () => api.lockSaveFolder(folder.uuid),
                success: 'Locked')) {
              onChanged();
            }
            break;
          case 'unlock':
            if (await runGuarded(context, () => api.unlockSaveFolder(folder.uuid),
                success: 'Unlocked')) {
              onChanged();
            }
            break;
          case 'clear':
            if (await confirmDialog(context,
                title: 'Clear saves',
                message: 'Delete all save states in "${folder.name}"?',
                confirmLabel: 'CLEAR')) {
              if (context.mounted &&
                  await runGuarded(context, () => api.clearSaveFolder(folder.uuid),
                      success: 'Cleared')) {
                onChanged();
              }
            }
            break;
          case 'delete':
            if (await confirmDialog(context,
                title: 'Delete profile',
                message: 'Delete "${folder.name}" and all its saves?',
                confirmLabel: 'DELETE')) {
              if (context.mounted &&
                  await runGuarded(context, () => api.deleteSaveFolder(folder.uuid),
                      success: 'Deleted')) {
                onChanged();
              }
            }
            break;
        }
      },
      itemBuilder: (_) => [
        if (!folder.isDefault) const PopupMenuItem(value: 'rename', child: Text('Rename')),
        if (folder.isLocked)
          const PopupMenuItem(value: 'unlock', child: Text('Unlock'))
        else
          const PopupMenuItem(value: 'lock', child: Text('Lock')),
        if (!folder.isLocked) const PopupMenuItem(value: 'clear', child: Text('Clear saves')),
        if (!folder.isDefault) const PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );
  }
}
