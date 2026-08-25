import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/image_store.dart';
import '../../app/theme.dart';

/// 全屏大图查看器（左右切换 + 双指缩放）。
class PhotoViewer extends StatefulWidget {
  const PhotoViewer({
    super.key,
    required this.paths,
    this.initialIndex = 0,
  });

  final List<String> paths;
  final int initialIndex;

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late int _page;

  @override
  void initState() {
    super.initState();
    _page = widget.initialIndex.clamp(0, widget.paths.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            onPageChanged: (i) => setState(() => _page = i),
            itemCount: widget.paths.length,
            itemBuilder: (context, index) {
              final path = widget.paths[index];
              if (!ImageStore.exists(path)) {
                return Center(
                  child: Icon(Icons.image_not_supported_outlined,
                      size: 64, color: cs.outline),
                );
              }
              return InteractiveViewer(
                maxScale: 4,
                child: Center(
                  child: Image.file(
                    File(path),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.image_not_supported_outlined,
                      size: 64,
                      color: cs.outline,
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            right: 8,
            child: IconButton.filledTonal(
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.close),
              onPressed: () => context.pop(),
            ),
          ),
          Positioned(
            bottom: MediaQuery.paddingOf(context).bottom + 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_page + 1} / ${widget.paths.length}',
                  style: AppTheme.caption(Colors.white70),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
