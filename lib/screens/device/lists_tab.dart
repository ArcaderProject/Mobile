import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/game_list.dart';
import '../../services/api_client.dart';
import '../../state/device_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';
import 'list_manage_games.dart';

class ListsTab extends StatefulWidget {
  const ListsTab({super.key});

  @override
  State<ListsTab> createState() => _ListsTabState();
}

class _ListsTabState extends State<ListsTab> {
  List<GameList>? _lists;
  String? _selectedId;
  String? _error;

  ApiClient get _api => context.read<DeviceController>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final lists = await _api.getLists();
      final selected = await _api.getSelectedList();
      if (!mounted) return;
      setState(() {
        _lists = lists;
        _selectedId = selected?.id;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _create() async {
    final result = await showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CreateListSheet(),
    );
    if (result != null && mounted) {
      if (await runGuarded(context, () => _api.createList(result.$1, result.$2),
          success: 'List created')) {
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
        label: const Text('New list'),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_error != null) {
      return EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load lists',
          subtitle: _error,
          action: OutlinedButton(onPressed: _load, child: const Text('RETRY')));
    }
    if (_lists == null) return const Center(child: CircularProgressIndicator());
    if (_lists!.isEmpty) {
      return const EmptyState(
          icon: Icons.playlist_play, title: 'No lists', subtitle: 'Create a list to curate what shows on the machine.');
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        itemCount: _lists!.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _ListCard(
          list: _lists![i],
          active: _lists![i].id == _selectedId,
          onChanged: _load,
        ),
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  final GameList list;
  final bool active;
  final VoidCallback onChanged;
  const _ListCard({required this.list, required this.active, required this.onChanged});

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
                Icon(list.isDefault ? Icons.star : Icons.playlist_play,
                    color: list.isDefault
                        ? context.semantic.warning
                        : context.colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(list.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                if (!list.isDefault)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (v) async {
                      if (v == 'rename') {
                        final name = await promptDialog(context,
                            title: 'Rename list', initialValue: list.name, label: 'Name');
                        if (name != null && name.isNotEmpty && context.mounted) {
                          if (await runGuarded(context, () => api.renameList(list.id, name),
                              success: 'Renamed')) {
                            onChanged();
                          }
                        }
                      } else if (v == 'delete') {
                        if (await confirmDialog(context,
                            title: 'Delete list',
                            message: 'Delete "${list.name}"?',
                            confirmLabel: 'DELETE')) {
                          if (context.mounted &&
                              await runGuarded(context, () => api.deleteList(list.id),
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
                StatusPill(list.isInclude ? 'Include' : 'Exclude',
                    color: list.isInclude
                        ? context.semantic.success
                        : context.colors.error),
                const SizedBox(width: 8),
                Text('${list.itemCount} games',
                    style: context.text.bodyMedium
                        ?.copyWith(color: context.colors.onSurfaceVariant)),
                const Spacer(),
                if (active)
                  StatusPill('Active', color: context.colors.primary, icon: Icons.bolt),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (!active)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => runGuarded(context, () => api.setSelectedList(list.id),
                          success: '"${list.name}" activated').then((ok) {
                        if (ok) onChanged();
                      }),
                      child: const Text('Activate'),
                    ),
                  ),
                if (!active && !list.isDefault) const SizedBox(width: 10),
                if (!list.isDefault)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        final controller = context.read<DeviceController>();
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChangeNotifierProvider.value(
                              value: controller,
                              child: ListManageGames(list: list),
                            ),
                          ),
                        );
                        onChanged();
                      },
                      icon: const Icon(Icons.tune, size: 18),
                      label: const Text('Manage'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateListSheet extends StatefulWidget {
  const _CreateListSheet();

  @override
  State<_CreateListSheet> createState() => _CreateListSheetState();
}

class _CreateListSheetState extends State<_CreateListSheet> {
  final _name = TextEditingController();
  String _type = 'include';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('New list', style: context.text.titleLarge),
          const SizedBox(height: 20),
          TextField(
            controller: _name,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'List name'),
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'include', label: Text('Include'), icon: Icon(Icons.check)),
              ButtonSegment(value: 'exclude', label: Text('Exclude'), icon: Icon(Icons.block)),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                if (_name.text.trim().isEmpty) return;
                Navigator.pop(context, (_name.text.trim(), _type));
              },
              child: const Text('Create'),
            ),
          ),
        ],
      ),
    );
  }
}
