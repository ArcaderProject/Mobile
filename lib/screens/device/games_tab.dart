import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/game.dart';
import '../../services/api_client.dart';
import '../../state/device_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/ui.dart';
import 'game_actions.dart';

class GamesTab extends StatefulWidget {
  const GamesTab({super.key});

  @override
  State<GamesTab> createState() => _GamesTabState();
}

class _GamesTabState extends State<GamesTab> {
  List<Game>? _games;
  String? _error;
  String _query = '';
  bool _uploading = false;

  ApiClient get _api => context.read<DeviceController>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final games = await _api.getGames();
      if (!mounted) return;
      setState(() {
        _games = games;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  List<Game> get _filtered {
    final all = _games ?? [];
    if (_query.isEmpty) return all;
    final q = _query.toLowerCase();
    return all
        .where((g) => g.name.toLowerCase().contains(q) || g.console.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _upload() async {
    final result = await FilePicker.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (!mounted) return;
    if (file.bytes == null) {
      showToast(context, 'Could not read file', error: true);
      return;
    }
    setState(() => _uploading = true);
    final ok = await runGuarded(
      context,
      () => _api.uploadGame(file.bytes!, file.name),
      success: 'Uploaded ${file.name}',
    );
    if (mounted) setState(() => _uploading = false);
    if (ok) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: _uploading ? null : _upload,
        child: _uploading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: context.colors.onPrimaryContainer))
            : const Icon(Icons.file_upload_outlined),
      ),
      body: Column(
        children: [
          _searchBar(),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        onChanged: (v) => setState(() => _query = v),
        decoration: const InputDecoration(
          hintText: 'Search games…',
          prefixIcon: Icon(Icons.search),
          isDense: true,
        ),
      ),
    );
  }

  Widget _body() {
    if (_error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load games',
        subtitle: _error,
        action: OutlinedButton(onPressed: _load, child: const Text('RETRY')),
      );
    }
    if (_games == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final games = _filtered;
    if (games.isEmpty) {
      return EmptyState(
        icon: Icons.videogame_asset_outlined,
        title: _query.isEmpty ? 'No games installed' : 'No matches',
        subtitle: _query.isEmpty ? 'Upload a ROM to get started.' : null,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 180,
          childAspectRatio: 0.62,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: games.length,
        itemBuilder: (_, i) => _GameCard(
          game: games[i],
          api: _api,
          onChanged: _load,
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final Game game;
  final ApiClient api;
  final VoidCallback onChanged;
  const _GameCard({required this.game, required this.api, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final controller = context.read<DeviceController>();
    return GestureDetector(
      onTap: () => showGameActions(context, controller, game, onChanged),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CoverImage(api: api, gameId: game.id, hasCover: game.hasCover),
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => showGameActions(context, controller, game, onChanged),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.more_vert, size: 18, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: Material(
                      color: context.colors.primary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => runGuarded(context, () => controller.startGame(game.id),
                            success: 'Launching ${game.name}'),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(Icons.play_arrow,
                              size: 20, color: context.colors.onPrimary),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(game.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          if (game.console.isNotEmpty)
            Text(game.console,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodySmall
                    ?.copyWith(color: context.colors.onSurfaceVariant)),
        ],
      ),
    );
  }
}
