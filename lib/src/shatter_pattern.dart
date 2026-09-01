import 'dart:math' as math;
import 'dart:ui';

import 'glass_shard.dart';

/// Describes *how* the glass breaks.
///
/// The pattern is a radial web: [rays] cracks run outward from the impact
/// point and [rings] concentric fracture lines cross them, which is how real
/// tempered glass fails. Cells of that web become shards; neighbouring cells
/// are randomly fused together ([mergeChance]) so the pieces come out in
/// believably different sizes.
class ShatterPattern {
  const ShatterPattern({
    this.rays = 13,
    this.rings = 5,
    this.angleJitter = 0.5,
    this.radiusJitter = 0.32,
    this.density = 1.75,
    this.mergeChance = 0.28,
    this.minShardArea = 6.0,
  })  : assert(rays >= 3, 'A shatter needs at least 3 rays'),
        assert(rings >= 1, 'A shatter needs at least 1 ring');

  /// Number of cracks radiating out from the impact point.
  final int rays;

  /// Number of concentric fracture rings crossing the rays.
  final int rings;

  /// How far each ray may swing off its evenly spaced angle, as a fraction of
  /// the spacing between rays. `0` gives a perfectly regular star.
  final double angleJitter;

  /// How far each vertex may slide along its ray, as a fraction of the ring
  /// radius.
  final double radiusJitter;

  /// Exponent controlling ring spacing. Values above `1` bunch the rings near
  /// the impact, leaving small fragments at the point of contact and large
  /// panes at the edges.
  final double density;

  /// Probability that a cell is fused with a neighbour into a bigger shard.
  final double mergeChance;

  /// Cells smaller than this (in logical pixels squared) are dropped.
  final double minShardArea;

  /// Lots of small fragments, as if hit hard by something sharp.
  static const ShatterPattern fine =
      ShatterPattern(rays: 22, rings: 8, density: 1.9, mergeChance: 0.18);

  /// A few large panes, as if a big pane cracked and fell apart.
  static const ShatterPattern chunky = ShatterPattern(
      rays: 8, rings: 3, density: 1.4, mergeChance: 0.4, radiusJitter: 0.4);

  /// A tight, regular web with long radial cracks.
  static const ShatterPattern spiderWeb = ShatterPattern(
      rays: 18,
      rings: 7,
      angleJitter: 0.15,
      radiusJitter: 0.16,
      density: 2.2,
      mergeChance: 0.06);

  ShatterPattern copyWith({
    int? rays,
    int? rings,
    double? angleJitter,
    double? radiusJitter,
    double? density,
    double? mergeChance,
    double? minShardArea,
  }) {
    return ShatterPattern(
      rays: rays ?? this.rays,
      rings: rings ?? this.rings,
      angleJitter: angleJitter ?? this.angleJitter,
      radiusJitter: radiusJitter ?? this.radiusJitter,
      density: density ?? this.density,
      mergeChance: mergeChance ?? this.mergeChance,
      minShardArea: minShardArea ?? this.minShardArea,
    );
  }

  /// Builds the shards covering `Offset.zero & size`, fracturing from [impact].
  ///
  /// The same [seed] always produces the same break.
  List<GlassShard> generate({
    required Size size,
    required Offset impact,
    int seed = 0,
  }) {
    final rnd = math.Random(seed);
    final rect = Offset.zero & size;

    // The outermost ring has to enclose the whole rect, otherwise the corners
    // would be left unbroken.
    var maxR = 0.0;
    for (final corner in [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ]) {
      maxR = math.max(maxR, (corner - impact).distance);
    }
    if (maxR < 1) return const [];
    final coreR = math.max(maxR * 0.035, 2.0);

    final angles = List<double>.generate(rays, (i) {
      final step = math.pi * 2 / rays;
      return i * step + (rnd.nextDouble() - 0.5) * step * angleJitter;
    });

    // grid[ring][ray] — vertices shared by adjacent cells, so shards tile the
    // surface with no seams.
    final grid = List<List<Offset>>.generate(rings, (i) {
      final t = (i + 1) / rings;
      final base = coreR + (maxR - coreR) * math.pow(t, density);
      final outermost = i == rings - 1;
      return List<Offset>.generate(rays, (j) {
        // The outer ring only ever grows, so it always stays outside the rect.
        final jitter = outermost
            ? 1 + rnd.nextDouble() * radiusJitter
            : 1 + (rnd.nextDouble() - 0.5) * 2 * radiusJitter;
        final r = (outermost ? base * 1.25 : base) * jitter;
        return impact + Offset(math.cos(angles[j]), math.sin(angles[j])) * r;
      });
    });

    Offset inner(int ring, int ray) =>
        ring == 0 ? impact : grid[ring - 1][ray % rays];
    Offset outer(int ring, int ray) => grid[ring][ray % rays];

    final used = List<List<bool>>.generate(rings, (_) => List.filled(rays, false));
    final shards = <GlassShard>[];

    for (var i = 0; i < rings; i++) {
      for (var j = 0; j < rays; j++) {
        if (used[i][j]) continue;
        used[i][j] = true;

        List<Offset> poly;
        final canMergeSide = rays > 3 && !used[i][(j + 1) % rays];
        final canMergeOut = i + 1 < rings && !used[i + 1][j];
        final roll = rnd.nextDouble();

        if (canMergeSide && roll < mergeChance) {
          // Fuse with the neighbouring cell on the same ring.
          used[i][(j + 1) % rays] = true;
          poly = [
            inner(i, j),
            inner(i, j + 1),
            inner(i, j + 2),
            outer(i, j + 2),
            outer(i, j + 1),
            outer(i, j),
          ];
        } else if (canMergeOut && roll < mergeChance * 2) {
          // Fuse with the cell one ring further out.
          used[i + 1][j] = true;
          poly = [
            inner(i, j),
            inner(i, j + 1),
            outer(i, j + 1),
            outer(i + 1, j + 1),
            outer(i + 1, j),
            outer(i, j),
          ];
        } else {
          poly = [inner(i, j), inner(i, j + 1), outer(i, j + 1), outer(i, j)];
        }

        // The innermost band collapses onto the impact point, so drop the
        // duplicated vertex and let those cells be triangles.
        poly = _dedupe(poly);
        if (poly.length < 3) continue;

        final clipped = clipPolygonToRect(poly, rect);
        if (clipped.length < 3) continue;

        final shard = _makeShard(clipped, impact, maxR, rnd);
        if (shard != null && shard.area >= minShardArea) shards.add(shard);
      }
    }
    return shards;
  }

  GlassShard? _makeShard(
      List<Offset> poly, Offset impact, double maxR, math.Random rnd) {
    final probe = GlassShard(
      points: poly,
      direction: Offset.zero,
      distance: 0,
      velocity: 1,
      spin: 0,
      delay: 0,
      tilt: 0,
    );
    if (probe.area < 1e-3) return null;

    final away = probe.centroid - impact;
    final distance = (away.distance / maxR).clamp(0.0, 1.0);
    return GlassShard(
      points: poly,
      direction: normalizeOffset(away, rnd),
      distance: distance,
      // Pieces near the impact take most of the energy.
      velocity: (1.15 - distance * 0.7) * (0.7 + rnd.nextDouble() * 0.6),
      spin: rnd.nextDouble() * 2 - 1,
      delay: distance * 0.32,
      tilt: rnd.nextDouble(),
    );
  }

  static List<Offset> _dedupe(List<Offset> pts) {
    final out = <Offset>[];
    for (final p in pts) {
      if (out.isEmpty || (out.last - p).distanceSquared > 1e-6) out.add(p);
    }
    if (out.length > 1 && (out.first - out.last).distanceSquared < 1e-6) {
      out.removeLast();
    }
    return out;
  }
}
