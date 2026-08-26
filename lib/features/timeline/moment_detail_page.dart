import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/image_store.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/moment.dart';
import '../../domain/models/pet.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/photo_viewer.dart';

/// 时刻详情：全屏图文流，上下滑切换上一条/下一条，编辑收进按钮。
class MomentDetailPage extends ConsumerStatefulWidget {
  const MomentDetailPage({super.key, required this.momentId});

  final String momentId;

  @override
  ConsumerState<MomentDetailPage> createState() => _MomentDetailPageState();
}

class _MomentDetailPageState extends ConsumerState<MomentDetailPage> {
  PageController? _controller;
  int _current = 0;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final moments =
        ref.watch(allMomentsProvider).valueOrNull ?? const <Moment>[];
    final pets = ref.watch(petsProvider).valueOrNull ?? const <Pet>[];
    final sorted = [...moments]..sort((a, b) => b.date.compareTo(a.date));

    var initialIndex = sorted.indexWhere((m) => m.id == widget.momentId);
    if (initialIndex < 0) {
      return Scaffold(
        appBar: AppBar(title: const Text('时刻详情')),
        body: EmptyView(
          icon: Icons.photo_camera_back_outlined,
          title: '这条时刻不存在',
          subtitle: '可能已被删除',
        ),
      );
    }
    _controller ??= PageController(initialPage: initialIndex);
    if (_current == 0) _current = initialIndex;

    String petName(String id) {
      for (final p in pets) {
        if (p.id == id) return p.name;
      }
      return '';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('时刻详情'),
        actions: [
          // 编辑入口收进按钮，浏览不再误触编辑。
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: '编辑这条时刻',
            onPressed: _current >= 0 && _current < sorted.length
                ? () =>
                    context.push('/moment/${sorted[_current].id}/edit')
                : null,
          ),
        ],
      ),
      body: PageView.builder(
        controller: _controller,
        scrollDirection: Axis.vertical,
        onPageChanged: (i) => setState(() => _current = i),
        itemCount: sorted.length,
        itemBuilder: (context, index) =>
            _DetailPage(moment: sorted[index], petName: petName(sorted[index].petId)),
      ),
    );
  }
}

/// 单条时刻的全屏页。
class _DetailPage extends StatelessWidget {
  const _DetailPage({required this.moment, required this.petName});

  final Moment moment;
  final String petName;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = momentTypeColor(moment.type);
    final photos = moment.imagePaths;

    return Column(
      children: [
        // 大图区（多图横向滑动 + 页码指示）。
        Expanded(
          flex: 5,
          child: photos.isEmpty
              ? Container(
                  width: double.infinity,
                  color: color.withValues(alpha: 0.12),
                  child: Icon(_iconOfPage(moment.type),
                      size: 72, color: color.withValues(alpha: 0.6)),
                )
              : photos.length == 1
                  ? GestureDetector(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => PhotoViewer(paths: photos),
                      )),
                      child: Hero(
                        tag: 'moment-cover-${moment.id}',
                        child: _BigImage(path: photos.first),
                      ),
                    )
                  : PageView.builder(
                      itemCount: photos.length,
                      itemBuilder: (context, i) => GestureDetector(
                        onTap: () => Navigator.of(context)
                            .push(MaterialPageRoute(
                          builder: (_) => PhotoViewer(
                              paths: photos, initialIndex: i),
                        )),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: i == 0
                              ? Hero(
                                  tag: 'moment-cover-${moment.id}',
                                  child: _BigImage(path: photos[i]),
                                )
                              : _BigImage(path: photos[i]),
                        ),
                      ),
                    ),
        ),
        // 文字区。
        Expanded(
          flex: 4,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    TypeChip(moment.type.label,
                        icon: _iconOfPage(moment.type), color: color),
                    const SizedBox(width: 8),
                    DatePill(
                      '${moment.date.year}/${moment.date.month}/${moment.date.day}',
                      color: color,
                      compact: true,
                    ),
                    const Spacer(),
                    if (petName.isNotEmpty)
                      Row(
                        children: [
                          Icon(Icons.pets_outlined,
                              size: 13, color: cs.onSurfaceVariant),
                          const SizedBox(width: 3),
                          Text(petName,
                              style: AppTheme.footnote(cs.onSurfaceVariant)),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(moment.title, style: AppTheme.title(cs.onSurface)),
                if (moment.location != null &&
                    moment.location!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.place_outlined,
                          size: 15, color: cs.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(moment.location!,
                          style: AppTheme.subhead(cs.onSurfaceVariant)),
                    ],
                  ),
                ],
                if (moment.notes != null && moment.notes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    moment.notes!,
                    style: AppTheme.body(cs.onSurface).copyWith(height: 1.7),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.keyboard_arrow_up_rounded,
                        size: 16, color: cs.outline),
                    Text('上滑看更早 · 下滑看更新',
                        style: AppTheme.captionSm(cs.outline)),
                    Icon(Icons.keyboard_arrow_down_rounded,
                        size: 16, color: cs.outline),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static IconData _iconOfPage(MomentType type) => switch (type) {
        MomentType.birthday => Icons.cake,
        MomentType.outing => Icons.park,
        MomentType.grooming => Icons.content_cut,
        MomentType.adoption => Icons.home,
        MomentType.anniversary => Icons.favorite,
        MomentType.custom => Icons.pets,
      };
}

/// 大图：填满区域，按屏宽解码。
class _BigImage extends StatelessWidget {
  const _BigImage({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    if (!ImageStore.exists(path)) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(child: Icon(Icons.image_outlined, size: 40)),
      );
    }
    return SizedBox.expand(
      child: Image.file(
        File(path),
        fit: BoxFit.cover,
        cacheWidth: (MediaQuery.sizeOf(context).width *
                MediaQuery.devicePixelRatioOf(context))
            .round()
            .clamp(64, 1600),
        errorBuilder: (_, __, ___) => Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Center(child: Icon(Icons.image_outlined, size: 40)),
        ),
      ),
    );
  }
}
