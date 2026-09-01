import 'dart:math' as math;
import 'dart:ui';

/// A single polygonal piece of glass produced by a shatter pattern.
///
/// Geometry ([points], [path], [centroid]) is expressed in the local
/// coordinate space of the widget that was shattered. The motion fields
/// ([direction], [distance], [velocity], [spin], [delay], [tilt]) are baked in
/// at generation time so that every frame of the animation is deterministic
/// for a given seed.
class GlassShard {
  GlassShard({
    required this.points,
    required this.direction,
    required this.distance,
    required this.velocity,
    required this.spin,
    required this.delay,
    required this.tilt,
  })  : path = _buildPath(points),
        centroid = _centroid(points),
        area = _area(points).abs();

  /// Polygon outline, in widget-local coordinates.
  final List<Offset> points;

  /// [points] as a closed [Path], ready to clip or stroke.
  final Path path;

  /// Area-weighted center of the polygon; the pivot for rotation and scaling.
  final Offset centroid;

  /// Surface area in logical pixels squared.
  final double area;

  /// Unit vector pointing away from the impact point.
  final Offset direction;

  /// Normalized distance from the impact point, `0` at the impact and `1` at
  /// the farthest corner.
  final double distance;

  /// Per-shard multiplier on the outward travel distance.
  final double velocity;

  /// Signed rotation multiplier, in `[-1, 1]`.
  final double spin;

  /// Fraction of the timeline this shard waits before it starts moving. Shards
  /// closer to the impact leave first, which reads as a shockwave.
  final double delay;

  /// Stable random value in `[0, 1]` used to vary the specular highlight so no
  /// two facets catch the light the same way.
  final double tilt;

  /// Cached bounding box of [path].
  late final Rect bounds = path.getBounds();

  static Path _buildPath(List<Offset> pts) {
    final path = Path()..addPolygon(pts, true);
    return path;
  }

  static double _area(List<Offset> pts) {
    var sum = 0.0;
    for (var i = 0; i < pts.length; i++) {
      final a = pts[i];
      final b = pts[(i + 1) % pts.length];
      sum += a.dx * b.dy - b.dx * a.dy;
    }
    return sum / 2;
  }

  static Offset _centroid(List<Offset> pts) {
    final a = _area(pts);
    if (a.abs() < 1e-6) {
      // Degenerate polygon: fall back to the average of the vertices.
      var sx = 0.0;
      var sy = 0.0;
      for (final p in pts) {
        sx += p.dx;
        sy += p.dy;
      }
      return Offset(sx / pts.length, sy / pts.length);
    }
    var cx = 0.0;
    var cy = 0.0;
    for (var i = 0; i < pts.length; i++) {
      final p = pts[i];
      final q = pts[(i + 1) % pts.length];
      final cross = p.dx * q.dy - q.dx * p.dy;
      cx += (p.dx + q.dx) * cross;
      cy += (p.dy + q.dy) * cross;
    }
    return Offset(cx / (6 * a), cy / (6 * a));
  }
}

/// Clips [polygon] against [rect] using the Sutherland-Hodgman algorithm.
///
/// Returns an empty list when the polygon lies entirely outside [rect].
List<Offset> clipPolygonToRect(List<Offset> polygon, Rect rect) {
  var output = polygon;
  for (var edge = 0; edge < 4; edge++) {
    if (output.isEmpty) return const [];
    final input = output;
    output = <Offset>[];
    for (var i = 0; i < input.length; i++) {
      final current = input[i];
      final previous = input[(i - 1 + input.length) % input.length];
      final currentIn = _inside(current, edge, rect);
      final previousIn = _inside(previous, edge, rect);
      if (currentIn) {
        if (!previousIn) output.add(_intersect(previous, current, edge, rect));
        output.add(current);
      } else if (previousIn) {
        output.add(_intersect(previous, current, edge, rect));
      }
    }
  }
  return output;
}

bool _inside(Offset p, int edge, Rect r) => switch (edge) {
      0 => p.dx >= r.left,
      1 => p.dx <= r.right,
      2 => p.dy >= r.top,
      _ => p.dy <= r.bottom,
    };

Offset _intersect(Offset a, Offset b, int edge, Rect r) {
  final dx = b.dx - a.dx;
  final dy = b.dy - a.dy;
  switch (edge) {
    case 0:
      return Offset(
          r.left, a.dy + dy * (r.left - a.dx) / (dx == 0 ? 1e-9 : dx));
    case 1:
      return Offset(
          r.right, a.dy + dy * (r.right - a.dx) / (dx == 0 ? 1e-9 : dx));
    case 2:
      return Offset(a.dx + dx * (r.top - a.dy) / (dy == 0 ? 1e-9 : dy), r.top);
    default:
      return Offset(
          a.dx + dx * (r.bottom - a.dy) / (dy == 0 ? 1e-9 : dy), r.bottom);
  }
}

/// Normalizes [o], returning a unit vector pointing in the same direction.
Offset normalizeOffset(Offset o, math.Random rnd) {
  final d = o.distance;
  if (d < 1e-6) {
    final a = rnd.nextDouble() * math.pi * 2;
    return Offset(math.cos(a), math.sin(a));
  }
  return o / d;
}
