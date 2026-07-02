import 'package:flutter/material.dart';

import 'apps_tab.dart';
import 'games_tab.dart';

class LibraryTab extends StatelessWidget {
  const LibraryTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: const [
          TabBar(
            tabs: [
              Tab(text: 'Games'),
              Tab(text: 'Apps'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                GamesTab(),
                AppsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
