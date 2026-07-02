import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../models/game.dart';
import '../../state/device_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/ui.dart';

void showGameActions(
  BuildContext context,
  DeviceController controller,
  Game game,
  VoidCallback onChanged,
) {
  showModalBottomSheet(
    context: context,
    builder: (ctx) => _GameActionsSheet(controller: controller, game: game, onChanged: onChanged),
  );
}

class _GameActionsSheet extends StatelessWidget {
  final DeviceController controller;
  final Game game;
  final VoidCallback onChanged;
  const _GameActionsSheet({
    required this.controller,
    required this.game,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final api = controller.api;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CoverImage(
                      api: api, gameId: game.id, hasCover: game.hasCover, width: 48, height: 64),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(game.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      if (game.console.isNotEmpty)
                        Text(game.console,
                            style: context.text.bodyMedium
                                ?.copyWith(color: context.colors.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          _tile(context, Icons.play_arrow, 'Launch on machine', color: context.colors.primary,
              onTap: () async {
            Navigator.pop(context);
            await runGuarded(context, () => controller.startGame(game.id),
                success: 'Launching ${game.name}');
          }),
          _tile(context, Icons.edit_outlined, 'Rename', onTap: () async {
            Navigator.pop(context);
            final name = await promptDialog(context,
                title: 'Rename game', initialValue: game.name, label: 'Name');
            if (name != null && name.isNotEmpty && context.mounted) {
              if (await runGuarded(context, () => api.renameGame(game.id, name),
                  success: 'Renamed')) {
                onChanged();
              }
            }
          }),
          _tile(context, Icons.image_outlined, 'Upload cover', onTap: () async {
            Navigator.pop(context);
            final res = await FilePicker.pickFiles(type: FileType.image, withData: true);
            if (res == null || res.files.first.bytes == null) return;
            final f = res.files.first;
            if (context.mounted &&
                await runGuarded(context, () => api.uploadCover(game.id, f.bytes!, f.name),
                    success: 'Cover updated')) {
              onChanged();
            }
          }),
          _tile(context, Icons.link, 'Cover from URL', onTap: () async {
            Navigator.pop(context);
            final url = await promptDialog(context,
                title: 'Cover from URL', label: 'Image URL', keyboardType: TextInputType.url);
            if (url != null && url.isNotEmpty && context.mounted) {
              if (await runGuarded(context, () => api.setCoverFromUrl(game.id, url),
                  success: 'Cover updated')) {
                onChanged();
              }
            }
          }),
          _tile(context, Icons.search, 'Lookup cover (SteamGridDB)', onTap: () async {
            Navigator.pop(context);
            await _lookupCovers(context);
          }),
          _tile(context, Icons.memory, 'Change core', subtitle: game.core, onTap: () async {
            Navigator.pop(context);
            await _changeCore(context);
          }),
          _tile(context, Icons.delete_outline, 'Delete', color: context.colors.error,
              onTap: () async {
            Navigator.pop(context);
            if (await confirmDialog(context,
                title: 'Delete game',
                message: 'Permanently delete "${game.name}"? This cannot be undone.',
                confirmLabel: 'DELETE')) {
              if (context.mounted &&
                  await runGuarded(context, () => api.deleteGame(game.id), success: 'Deleted')) {
                onChanged();
              }
            }
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String label,
      {String? subtitle, Color? color, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: color ?? context.colors.onSurface),
      title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      subtitle: subtitle != null && subtitle.isNotEmpty
          ? Text(subtitle,
              style: TextStyle(color: context.colors.onSurfaceVariant))
          : null,
      onTap: onTap,
    );
  }

  Future<void> _changeCore(BuildContext context) async {
    final api = controller.api;
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CoreSelector(future: api.getGameCores(game.id), current: game.core),
    );
    if (selected != null && selected != game.core && context.mounted) {
      if (await runGuarded(context, () => api.setGameCore(game.id, selected),
          success: 'Core updated')) {
        onChanged();
      }
    }
  }

  Future<void> _lookupCovers(BuildContext context) async {
    final api = controller.api;
    final chosen = await showModalBottomSheet<CoverCandidate>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CoverLookup(future: api.lookupCovers(game.id)),
    );
    if (chosen != null && context.mounted) {
      if (await runGuarded(context, () => api.setCoverFromUrl(game.id, chosen.url),
          success: 'Cover updated')) {
        onChanged();
      }
    }
  }
}

class _CoreSelector extends StatelessWidget {
  final Future<List<GameCore>> future;
  final String current;
  const _CoreSelector({required this.future, required this.current});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Select core', style: context.text.titleLarge),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<GameCore>>(
              future: future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return EmptyState(icon: Icons.error_outline, title: 'Failed to load cores', subtitle: '${snap.error}');
                }
                final cores = snap.data ?? [];
                if (cores.isEmpty) {
                  return const EmptyState(icon: Icons.memory, title: 'No compatible cores');
                }
                return ListView.builder(
                  controller: scroll,
                  itemCount: cores.length,
                  itemBuilder: (_, i) {
                    final c = cores[i];
                    final active = c.core == current;
                    return ListTile(
                      leading: Icon(active ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: active
                              ? context.colors.primary
                              : context.colors.onSurfaceVariant),
                      title: Text(c.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(c.core,
                          style: TextStyle(color: context.colors.onSurfaceVariant)),
                      onTap: () => Navigator.pop(context, c.core),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverLookup extends StatelessWidget {
  final Future<List<CoverCandidate>> future;
  const _CoverLookup({required this.future});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('SteamGridDB covers', style: context.text.titleLarge),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<CoverCandidate>>(
              future: future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text('Searching…',
                            style: TextStyle(color: context.colors.onSurfaceVariant)),
                      ],
                    ),
                  );
                }
                if (snap.hasError) {
                  return EmptyState(
                      icon: Icons.error_outline, title: 'Lookup failed', subtitle: '${snap.error}');
                }
                final covers = snap.data ?? [];
                if (covers.isEmpty) {
                  return const EmptyState(icon: Icons.image_not_supported_outlined, title: 'No covers found');
                }
                return GridView.builder(
                  controller: scroll,
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 130,
                    childAspectRatio: 0.66,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: covers.length,
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => Navigator.pop(context, covers[i]),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(covers[i].thumb, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                                color: context.colors.surfaceContainerHighest,
                                child: const Icon(Icons.broken_image_outlined),
                              )),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
