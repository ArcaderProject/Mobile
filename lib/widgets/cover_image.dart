import 'package:flutter/material.dart';

import '../services/api_client.dart';

class CoverImage extends StatelessWidget {
  final ApiClient api;
  final String gameId;
  final bool hasCover;
  final double? width;
  final double? height;
  final BoxFit fit;

  const CoverImage({
    super.key,
    required this.api,
    required this.gameId,
    required this.hasCover,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasCover) return _placeholder(context);
    return Image.network(
      api.coverUrl(gameId),
      headers: api.authImageHeaders,
      width: width,
      height: height,
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => _placeholder(context),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return _placeholder(context, loading: true);
      },
    );
  }

  Widget _placeholder(BuildContext context, {bool loading = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              Icons.videogame_asset_outlined,
              size: 40,
              color: scheme.onSurfaceVariant,
            ),
    );
  }
}
