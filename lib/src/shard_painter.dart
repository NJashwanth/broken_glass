import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'glass_shard.dart';
import 'glass_style.dart';

/// Paints a snapshot of a widget as a field of glass shards.
///
/// Every shard clips the *same* snapshot image, so each piece keeps showing
/// the part of the widget it used to cover — that continuity is what makes the
/// break read as the widget itself breaking rather than an overlay.
class ShardPainter extends CustomPainter {
  ShardPainter({
    required this.shards,
    required this.image,
    required this.impact,
    required this.progress,
    required this.style,
    required this.spread,
    required this.gravity,
    required this.rotation,
    required this.fade,
    required this.scatter,
  });

  /// The pieces to draw, in widget-local coordinates.
  final List<GlassShard> shards;

  /// Snapshot of the widget taken the moment it broke.
  final ui.Image image;

  /// Where the break started, in widget-local coordinates.
  final Offset impact;

  /// Animation position, `0` intact through `1` fully scattered.
  final double progress;

  final GlassStyle style;
  final double spread;
  final double gravity;
  final double rotation;
  final bool fade;
  final bool scatter;

  /// Fraction of the timeline spent drawing the cracks before anything moves.
  static const double _crackWindow = 0.14;

  @override
  void paint(Canvas canvas, Size size) {
    if (shards.isEmpty) return;

    final crackIn = (progress / _crackWindow).clamp(0.0, 1.0);
    final src =
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dst = Offset.zero & size;
    final imagePaint = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.low;

    for (final shard in shards) {
      final t = _shardProgress(shard);
      final opacity = fade ? (1 - Curves.easeInCubic.transform(t)) : 1.0;
      if (opacity <= 0.01) continue;

      canvas.save();

      if (t > 0) {
        // Outward burst that decelerates, plus a constant downward pull.
        final ease = 1 - math.pow(1 - t, 2.2).toDouble();
        final travel = spread * shard.velocity * ease;
        canvas.translate(
          shard.direction.dx * travel,
          shard.direction.dy * travel + gravity * t * t,
        );
        // Tumble around the shard's own center of mass.
        canvas.translate(shard.centroid.dx, shard.centroid.dy);
        canvas.rotate(shard.spin * rotation * t);
        final scale = 1 - 0.16 * t;
        canvas.scale(scale, scale);
        canvas.translate(-shard.centroid.dx, -shard.centroid.dy);

        if (style.shadows && t > 0.02) {
          canvas.drawShadow(
            shard.path,
            const Color(0xFF000000).withValues(alpha: 0.45 * opacity),
            style.shadowElevation * t,
            false,
          );
        }
      }

      canvas.save();
      canvas.clipPath(shard.path);
      imagePaint.color =
          const Color(0xFFFFFFFF).withValues(alpha: opacity.clamp(0.0, 1.0));
      canvas.drawImageRect(image, src, dst, imagePaint);

      if (style.tint.a > 0) {
        canvas.drawRect(
          dst,
          Paint()..color = style.tint.withValues(alpha: style.tint.a * opacity),
        );
      }
      canvas.restore();

      _paintGlare(canvas, shard, t, opacity);
      _paintEdges(canvas, shard, t, crackIn, opacity);

      canvas.restore();
    }

    if (style.impactFlash) _paintFlash(canvas, size, crackIn);
  }

  double _shardProgress(GlassShard shard) {
    if (!scatter) return 0;
    final start = _crackWindow * 0.7 + shard.delay;
    if (progress <= start) return 0;
    return ((progress - start) / (1 - start)).clamp(0.0, 1.0);
  }

  /// A directional sheen, unique per facet, that flares as the shard tumbles.
  void _paintGlare(Canvas canvas, GlassShard shard, double t, double opacity) {
    if (style.glare <= 0) return;
    final bounds = shard.bounds;
    if (bounds.isEmpty) return;

    final angle = shard.tilt * math.pi * 2;
    final dir = Offset(math.cos(angle), math.sin(angle));
    final flicker = 0.55 +
        0.45 * math.sin((t * (1.4 + shard.tilt) + shard.tilt) * math.pi * 2);
    final strength =
        (style.glare * (0.35 + 1.15 * t) * flicker * opacity).clamp(0.0, 1.0);
    if (strength < 0.01) return;

    final shader = LinearGradient(
      begin: Alignment(-dir.dx, -dir.dy),
      end: Alignment(dir.dx, dir.dy),
      colors: [
        style.edgeColor.withValues(alpha: strength),
        style.edgeColor.withValues(alpha: strength * 0.06),
        style.edgeColor.withValues(alpha: strength * 0.45),
      ],
      stops: const [0.0, 0.55, 1.0],
    ).createShader(bounds);

    canvas.drawPath(
      shard.path,
      Paint()
        ..shader = shader
        ..blendMode = BlendMode.plus
        ..isAntiAlias = true,
    );
  }

  /// The fracture line while the pieces touch, becoming a lit bevel once they
  /// separate.
  void _paintEdges(Canvas canvas, GlassShard shard, double t, double crackIn,
      double opacity) {
    final together = (1 - t).clamp(0.0, 1.0);

    if (style.crackWidth > 0) {
      final crackAlpha = style.crackColor.a * crackIn * together * opacity;
      if (crackAlpha > 0.01) {
        canvas.drawPath(
          shard.path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = style.crackWidth
            ..strokeJoin = StrokeJoin.round
            ..color = style.crackColor.withValues(alpha: crackAlpha)
            ..isAntiAlias = true,
        );
      }
    }

    if (style.edgeWidth > 0) {
      // The bevel is faint while the crack is fresh and brightest once the
      // shard is airborne and catching light on its cut edge.
      final edgeAlpha =
          (style.edgeOpacity * (0.35 + 0.65 * t) * crackIn * opacity)
              .clamp(0.0, 1.0);
      if (edgeAlpha > 0.01) {
        canvas.drawPath(
          shard.path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = style.edgeWidth
            ..color = style.edgeColor.withValues(alpha: edgeAlpha)
            ..isAntiAlias = true,
        );
      }
    }
  }

  void _paintFlash(Canvas canvas, Size size, double crackIn) {
    final alpha = (crackIn * (1 - progress * 2.2)).clamp(0.0, 1.0);
    if (alpha < 0.01) return;
    final radius = math.max(size.width, size.height) * 0.16;
    canvas.drawCircle(
      impact,
      radius,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [
            style.edgeColor.withValues(alpha: 0.75 * alpha),
            style.edgeColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: impact, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(ShardPainter old) =>
      old.progress != progress ||
      old.shards != shards ||
      old.image != image ||
      old.style != style ||
      old.spread != spread ||
      old.gravity != gravity ||
      old.rotation != rotation ||
      old.fade != fade ||
      old.scatter != scatter;
}
