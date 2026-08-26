import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';

import '../../app/image_store.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/moment.dart';
import '../../domain/models/pet.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/sync_button.dart';

/// 时刻：单列瀑布流（大图流）+ 粘性月份头 + 无限下滑分页 + 下拉同步。
class TimelinePage extends ConsumerStatefulWidget {
  const TimelinePage({super.key});

  @override
  ConsumerState<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends ConsumerState<TimelinePage> {
  static const _pageSize = 20;

  final _scrollController = ScrollController();
  int _limit = _pageSize;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// 滚动接近底部 600px 时自动加载下一页。
  void _onScroll() {
    if (_loadingMore || !_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 600) {
      _loadMore();
    }
  }

  void _loadMore() {
    final moments =
        ref.read(allMomentsProvider).valueOrNull ?? const <Moment>[];
    if (_limit >= moments.length) return;
    setState(() => _loadingMore = true);
    // 延迟一帧展示加载态，避免闪烁。
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) {
        setState(() {
          _limit += _pageSize;
          _loadingMore = false;
        });
      }
    });
  }

  /// 按月分组（倒序），供粘性月份头使用。
  List<(String, List<Moment>)> _groupMonths(List<Moment> items) {
    final groups = <String, List<Moment>>{};
    for (final m in items) {
      groups.putIfAbsent('${m.date.year}年${m.date.month}月', () => []).add(m);
    }
    return [for (final e in groups.entries) (e.key, e.value)];
  }

  @override
  Widget build(BuildContext context) {
    final moments =
        ref.watch(allMomentsProvider).valueOrNull ?? const <Moment>[];
    final pets = ref.watch(petsProvider).valueOrNull ?? const <Pet>[];
    final sorted = [...moments]..sort((a, b) => b.date.compareTo(a.date));
    final visible = sorted.take(_limit).toList();
    final hasMore = _limit < sorted.length;
    final groups = _groupMonths(visible);

    String petName(String id) {
      for (final p in pets) {
        if (p.id == id) return p.name;
      }
      return '';
    }

    return PageScaffold(
      title: '时刻',
      actions: const [SyncButton()],
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/moment/new'),
        tooltip: '记录时刻',
        child: const Icon(Icons.add),
      ),
      body: sorted.isEmpty
          ? EmptyView(
              icon: Icons.photo_camera_back_outlined,
              title: '还没有时刻',
              subtitle: '生日、游玩、美容、纪念日…\n用照片记录值得纪念的日子',
              action: FilledButton(
                onPressed: () => context.push('/moment/new'),
                child: const Text('记录第一个时刻'),
              ),
            )
          : RefreshIndicator.adaptive(
              onRefresh: () => manualSyncCurrentPet(ref, context),
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  for (final (label, items) in groups) ...[
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _MonthHeaderDelegate(label),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
                      sliver: SliverMasonryGrid.count(
                        crossAxisCount: 1,
                        mainAxisSpacing: 12,
                        childCount: items.length,
                        itemBuilder: (context, i) => _MomentCell(
                          moment: items[i],
                          petName: petName(items[i].petId),
                        ),
                      ),
                    ),
                  ],
                  if (hasMore || _loadingMore)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      sliver: SliverToBoxAdapter(
                        child: _LoadMoreCell(
                          loading: _loadingMore,
                          onTap: _loadMore,
                        ),
                      ),
                    ),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 96)),
                ],
              ),
            ),
    );
  }
}

/// 粘性月份头：悬浮时用画布色遮住下方滚动内容。
class _MonthHeaderDelegate extends SliverPersistentHeaderDelegate {
  _MonthHeaderDelegate(this.text);

  final String text;

  @override
  double get minExtent => 34;

  @override
  double get maxExtent => 34;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: dark ? AppTheme.darkBg : AppTheme.lightBg,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
          color: dark ? Colors.white30 : AppTheme.inkTertiary,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_MonthHeaderDelegate oldDelegate) =>
      oldDelegate.text != text;
}

/// 加载更多占位格。
class _LoadMoreCell extends StatelessWidget {
  const _LoadMoreCell({required this.loading, this.onTap});

  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('加载更多', style: AppTheme.footnote(cs.onSurfaceVariant)),
        ),
      ),
    );
  }
}

/// 瀑布流单卡：封面图随内容自然高度（单列大图流）。
class _MomentCell extends StatelessWidget {
  const _MomentCell({required this.moment, required this.petName});

  final Moment moment;
  final String petName;

  static IconData _iconOf(MomentType type) => switch (type) {
        MomentType.birthday => Icons.cake,
        MomentType.outing => Icons.park,
        MomentType.grooming => Icons.content_cut,
        MomentType.adoption => Icons.home,
        MomentType.anniversary => Icons.favorite,
        MomentType.custom => Icons.pets,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = momentTypeColor(moment.type);
    final photos = moment.imagePaths;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: GestureDetector(
        onTap: () => context.push('/moment/${moment.id}/detail'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面：照片自然高度；无照片用类型色块。Hero 飞入详情页。
            if (photos.isNotEmpty)
              Stack(
                children: [
                  Hero(
                    tag: 'moment-cover-${moment.id}',
                    child: _CoverImage(path: photos.first),
                  ),
                  if (photos.length > 1)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.photo_library_outlined,
                                size: 11, color: Colors.white),
                            const SizedBox(width: 3),
                            Text('${photos.length}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                ],
              )
            else
              Container(
                height: 88,
                width: double.infinity,
                color: color.withValues(alpha: 0.14),
                child: Icon(_iconOf(moment.type),
                    size: 34, color: color.withValues(alpha: 0.7)),
              ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    moment.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        AppTheme.cardTitle(cs.onSurface).copyWith(fontSize: 15),
                  ),
                  if (moment.notes != null && moment.notes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      moment.notes!,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.caption(cs.onSurfaceVariant),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(_iconOf(moment.type), size: 12, color: color),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          '${moment.type.label}'
                          '${moment.location != null && moment.location!.isNotEmpty ? " · ${moment.location}" : ""}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.captionSm(color),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      DatePill('${moment.date.month}/${moment.date.day}',
                          color: color, compact: true),
                      const Spacer(),
                      if (petName.isNotEmpty)
                        Text(petName,
                            style: AppTheme.captionSm(cs.onSurfaceVariant)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 封面图：按宽度撑满、高度随图片比例自然伸展（瀑布流关键）。
class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      height: 160,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.image_outlined),
    );
    if (!ImageStore.exists(path)) return placeholder;
    // 单列大图：按屏宽解码，高度随比例但封顶 1.6 倍屏宽，避免长图刷屏。
    return ClipRRect(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).width * 1.6,
        ),
        child: Image.file(
          File(path),
          width: double.infinity,
          fit: BoxFit.cover,
          cacheWidth: (MediaQuery.sizeOf(context).width *
                  MediaQuery.devicePixelRatioOf(context))
              .round()
              .clamp(64, 1200),
          errorBuilder: (_, __, ___) => placeholder,
        ),
      ),
    );
  }
}
