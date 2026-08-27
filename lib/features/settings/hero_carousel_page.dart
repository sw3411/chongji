import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'dart:io' as io;

import '../../app/image_store.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../domain/models/pet.dart';
import '../../shared/widgets/common.dart';

/// 首页轮播图管理：网格预览、添加（≤30 张）、删除。
/// 保存即生效——首页顶图立即开始轮播。
class HeroCarouselPage extends ConsumerStatefulWidget {
  const HeroCarouselPage({super.key, required this.pet});

  final Pet pet;

  @override
  ConsumerState<HeroCarouselPage> createState() => _HeroCarouselPageState();
}

class _HeroCarouselPageState extends ConsumerState<HeroCarouselPage> {
  bool _adding = false;

  List<String> get _images =>
      ref.watch(heroCarouselProvider)[widget.pet.id] ?? const <String>[];

  Future<void> _add() async {
    if (_adding) return;
    final remain = kHeroCarouselMax - _images.length;
    if (remain <= 0) {
      showAutoToast(context, '最多 $kHeroCarouselMax 张 🖼️');
      return;
    }
    setState(() => _adding = true);
    try {
      final picked = await ImageStore.pickFromGallery(maxCount: remain);
      if (!mounted) return;
      await ref
          .read(heroCarouselProvider.notifier)
          .addFor(widget.pet.id, picked);
      if (mounted && picked.isNotEmpty) {
        showAutoToast(context, '已添加 ${picked.length} 张 🐾');
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _remove(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这张轮播图？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      HapticFeedback.mediumImpact();
      await ref.read(heroCarouselProvider.notifier).removeAt(
            widget.pet.id,
            index,
          );
      if (mounted) showAutoToast(context, '已删除 🗑️');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final full = _images.length >= kHeroCarouselMax;
    return PageScaffold(
      title: '首页轮播图',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // 头像说明卡：第一张恒为头像，不可移除。
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: p.surfaceAlt.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            ),
            child: Row(
              children: [
                Icon(PhosphorIconsDuotone.info,
                    size: 22, color: p.accentText),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '第一张固定为「${widget.pet.name}」的头像；添加的图片会自动轮播，每 8 秒切换一次。',
                    style: AppTheme.subhead(p.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: AppTheme.label(p.textTertiary) is Widget
                    ? Text('轮播图 ${_images.length}/$kHeroCarouselMax',
                        style: AppTheme.label(p.textTertiary))
                    : const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _images.length + 1,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              if (index < _images.length) {
                final path = _images[index];
                return Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(AppTheme.cardRadius - 6),
                        child: Image.file(io.File(path), fit: BoxFit.cover),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _remove(index),
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded,
                              size: 15, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              }
              // 添加格
              return InkWell(
                onTap: full ? null : _add,
                borderRadius:
                    BorderRadius.circular(AppTheme.cardRadius - 6),
                child: Container(
                  decoration: BoxDecoration(
                    color: p.accentSoft.withValues(alpha: 0.30),
                    borderRadius:
                        BorderRadius.circular(AppTheme.cardRadius - 6),
                    border: Border.all(
                      color: full
                          ? p.divider
                          : p.accentText.withValues(alpha: 0.35),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_adding)
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: p.accentText),
                        )
                      else
                        Icon(
                          PhosphorIconsDuotone.plusCircle,
                          size: 26,
                          color: full ? p.textTertiary : p.accentText,
                        ),
                      const SizedBox(height: 6),
                      Text(full ? '已满' : '添加',
                          style: TextStyle(
                            fontSize: 12,
                            color: full ? p.textTertiary : p.accentText,
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
