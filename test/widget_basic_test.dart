import 'package:chongji/app/theme.dart';
import 'package:chongji/shared/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MetricTile / TypeChip 浅色渲染', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: const Scaffold(
        body: Column(
          children: [
            MetricTile(label: '当前体重', value: '5.2', subValue: 'kg'),
            TypeChip('疫苗', icon: null),
          ],
        ),
      ),
    ));
    expect(find.text('当前体重'), findsOneWidget);
    expect(find.text('5.2'), findsOneWidget);
    expect(find.text('疫苗'), findsOneWidget);
  });

  testWidgets('深色模式渲染', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: const Scaffold(
        body: MetricTile(label: '体型 BCS', value: '5/9', subValue: '理想'),
      ),
    ));
    expect(find.text('5/9'), findsOneWidget);
    expect(find.text('理想'), findsOneWidget);
  });

  testWidgets('EmptyView 带按钮', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: const Scaffold(
        body: EmptyView(
          icon: Icons.pets,
          title: '还没有宠物档案',
          subtitle: '添加第一只宠物',
        ),
      ),
    ));
    expect(find.text('还没有宠物档案'), findsOneWidget);
  });
}
