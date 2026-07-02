import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/save_folder.dart';
import '../../services/api_client.dart';
import '../../state/device_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/ui.dart';

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB'];
  double size = bytes / 1024;
  int unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  return '${size.toStringAsFixed(size >= 10 ? 0 : 1)} ${units[unit]}';
}

class SaveFolderDetail extends StatefulWidget {
  final SaveFolder folder;
  const SaveFolderDetail({super.key, required this.folder});

  @override
  State<SaveFolderDetail> createState() => _SaveFolderDetailState();
}

class _SaveFolderDetailState extends State<SaveFolderDetail> {
  List<GameSave>? _saves;
  String? _error;

  ApiClient get _api => context.read<DeviceController>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final saves = await _api.getSaveFolderGames(widget.folder.uuid);
      if (!mounted) return;
      setState(() {
        _saves = saves;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.folder.name,
                style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
            Text('Save profile',
                style: context.text.labelSmall
                    ?.copyWith(color: context.colors.onSurfaceVariant)),
          ],
        ),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_error != null) {
      return EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load',
          subtitle: _error,
          action: OutlinedButton(onPressed: _load, child: const Text('RETRY')));
    }
    if (_saves == null) return const Center(child: CircularProgressIndicator());
    if (_saves!.isEmpty) {
      return const EmptyState(
          icon: Icons.save_outlined, title: 'No saves yet', subtitle: 'Games with save states will appear here.');
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _saves!.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final s = _saves![i];
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CoverImage(
                    api: _api, gameId: s.game.id, hasCover: s.game.hasCover, width: 40, height: 54),
              ),
              title: Text(s.game.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${s.fileCount} file${s.fileCount == 1 ? '' : 's'} • ${formatBytes(s.totalSize)}',
                  style: TextStyle(color: context.colors.onSurfaceVariant)),
              trailing: widget.folder.isLocked
                  ? Icon(Icons.lock, color: context.semantic.warning, size: 18)
                  : IconButton(
                      icon: Icon(Icons.delete_outline, color: context.colors.error),
                      onPressed: () => _delete(s),
                    ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _delete(GameSave s) async {
    if (await confirmDialog(context,
        title: 'Delete saves',
        message: 'Delete ${s.fileCount} save file(s) (${formatBytes(s.totalSize)}) for "${s.game.name}"?',
        confirmLabel: 'DELETE')) {
      if (mounted &&
          await runGuarded(context, () => _api.deleteGameSaves(widget.folder.uuid, s.game.id),
              success: 'Saves deleted')) {
        _load();
      }
    }
  }
}
