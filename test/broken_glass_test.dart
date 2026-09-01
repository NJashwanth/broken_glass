import 'package:broken_glass/broken_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShatterPattern', () {
    const size = Size(300, 200);
    const impact = Offset(150, 100);

    test('tiles the whole surface with no gaps or overlap', () {
      final shards = const ShatterPattern()
          .generate(size: size, impact: impact, seed: 7);
      final covered = shards.fold<double>(0, (sum, s) => sum + s.area);
      // Shards partition the rect, so their areas must add up to it.
      expect(covered, closeTo(size.width * size.height, 1.0));
    });

    test('keeps every shard inside the widget bounds', () {
      final shards = ShatterPattern.fine
          .generate(size: size, impact: const Offset(10, 190), seed: 3);
      final rect = (Offset.zero & size).inflate(0.01);
      for (final shard in shards) {
        expect(rect.contains(shard.bounds.topLeft), isTrue);
        expect(rect.contains(shard.bounds.bottomRight), isTrue);
      }
    });

    test('is deterministic for a given seed', () {
      const pattern = ShatterPattern();
      final a = pattern.generate(size: size, impact: impact, seed: 42);
      final b = pattern.generate(size: size, impact: impact, seed: 42);
      final c = pattern.generate(size: size, impact: impact, seed: 43);
      expect(a.length, b.length);
      expect(a.first.centroid, b.first.centroid);
      expect(a.map((s) => s.centroid), isNot(equals(c.map((s) => s.centroid))));
    });

    test('breaks finest at the point of impact', () {
      final shards = const ShatterPattern()
          .generate(size: size, impact: impact, seed: 11);
      final near = shards.where((s) => s.distance < 0.25);
      final far = shards.where((s) => s.distance > 0.6);
      double avgArea(Iterable<GlassShard> s) =>
          s.fold<double>(0, (t, e) => t + e.area) / s.length;
      expect(avgArea(near), lessThan(avgArea(far)));
    });

    test('handles an impact outside the widget', () {
      final shards = const ShatterPattern()
          .generate(size: size, impact: const Offset(-400, -300), seed: 1);
      final covered = shards.fold<double>(0, (sum, s) => sum + s.area);
      expect(covered, closeTo(size.width * size.height, 1.0));
    });
  });

  group('BrokenGlass', () {
    Widget wrap(Widget child) => MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(width: 200, height: 200, child: child),
            ),
          ),
        );

    testWidgets('renders and lays out its child while intact', (tester) async {
      await tester.pumpWidget(wrap(
        const BrokenGlass(child: Text('hello', textDirection: TextDirection.ltr)),
      ));
      expect(find.text('hello'), findsOneWidget);
      expect(tester.getSize(find.byType(BrokenGlass)), const Size(200, 200));
    });

    testWidgets('keeps its size and reports completion when broken',
        (tester) async {
      var shattered = false;
      final controller = BrokenGlassController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(wrap(BrokenGlass(
        controller: controller,
        duration: const Duration(milliseconds: 300),
        onShattered: () => shattered = true,
        child: Container(color: const Color(0xFF2196F3)),
      )));

      controller.shatter(at: const Offset(40, 40));
      await tester.pump();
      expect(tester.getSize(find.byType(BrokenGlass)), const Size(200, 200));

      await tester.pumpAndSettle();
      expect(shattered, isTrue);
      expect(controller.isBroken, isTrue);
    });

    testWidgets('restores the child after reassembling', (tester) async {
      var restored = false;
      final controller = BrokenGlassController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(wrap(BrokenGlass(
        controller: controller,
        duration: const Duration(milliseconds: 300),
        onRestored: () => restored = true,
        child: Container(color: const Color(0xFF2196F3)),
      )));

      controller.shatter();
      await tester.pumpAndSettle();
      controller.restore();
      await tester.pumpAndSettle();

      expect(restored, isTrue);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(controller.isBroken, isFalse);
    });

    testWidgets('breaks where the user taps', (tester) async {
      await tester.pumpWidget(wrap(BrokenGlass(
        breakOnTap: true,
        duration: const Duration(milliseconds: 200),
        child: Container(color: const Color(0xFF000000)),
      )));

      await tester.tapAt(tester.getTopLeft(find.byType(BrokenGlass)) +
          const Offset(20, 20));
      await tester.pumpAndSettle();

      final painter = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<ShardPainter>()
          .single;
      expect(painter.impact, const Offset(20, 20));
      expect(painter.shards, isNotEmpty);
    });
  });
}
