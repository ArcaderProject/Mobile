import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/game.dart';
import '../../models/game_list.dart';
import '../../services/api_client.dart';
import '../../state/device_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/ui.dart';

class ListManageGames extends StatefulWidget {
  final GameList list;
  const ListManageGames({super.key, required this.list});

  @override
  State<ListManageGames> createState() => _ListManageGamesState();
}

class _ListManageGamesState extends State<ListManageGames> {
  List<Game>? _games;
  final Set<String> _selected = {};
  String _query = '';
  bool _saving = false;
  String? _error;

  ApiClient get _api => context.read<DeviceController>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final games = await _api.getGames();
      final ids = await _api.getListGameIds(widget.list.id);
      if (!mounted) return;
      setState(() {
        _games = games;
        _selected
          ..clear()
          ..addAll(ids);
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await runGuarded(
      context,
      () => _api.setListGames(widget.list.id, _selected.toList()),
      success: 'List updated',
    );
    if (mounted) setState(() => _saving = false);
    if (ok && mounted) Navigator.pop(context);
  }

  List<Game> get _filtered {
    final all = _games ?? [];
    if (_query.isEmpty) return all;
    final q = _query.toLowerCase();
    return all.where((g) => g.name.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final accent =
        widget.list.isInclude ? context.semantic.success : context.colors.error;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.list.name,
                style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
            Text('${widget.list.isInclude ? 'Include' : 'Exclude'} • ${_selected.length} selected',
                style: context.text.labelSmall?.copyWith(color: accent)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
      body: _body(accent),
    );
  }

  Widget _body(Color accent) {
    if (_error != null) {
      return EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load',
          subtitle: _error,
          action: OutlinedButton(onPressed: _load, child: const Text('RETRY')));
    }
    if (_games == null) return const Center(child: CircularProgressIndicator());
    final games = _filtered;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(
                hintText: 'Search games…', prefixIcon: Icon(Icons.search), isDense: true),
          ),
        ),
        Expanded(
          child: games.isEmpty
              ? const EmptyState(icon: Icons.videogame_asset_outlined, title: 'No games')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                  itemCount: games.length,
                  itemBuilder: (_, i) {
                    final g = games[i];
                    final on = _selected.contains(g.id);
                    return CheckboxListTile(
                      value: on,
                      activeColor: accent,
                      controlAffinity: ListTileControlAffinity.trailing,
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _selected.add(g.id);
                        } else {
                          _selected.remove(g.id);
                        }
                      }),
                      secondary: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: CoverImage(
                            api: _api, gameId: g.id, hasCover: g.hasCover, width: 36, height: 48),
                      ),
                      title: Text(g.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: g.console.isNotEmpty
                          ? Text(g.console,
                              style: TextStyle(color: context.colors.onSurfaceVariant))
                          : null,
                    );
                  },
                ),
        ),
      ],
    );
  }
}
