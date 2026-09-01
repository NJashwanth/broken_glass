import 'package:flutter/widgets.dart';

/// Imperative handle for a [BrokenGlass] widget.
///
/// ```dart
/// final glass = BrokenGlassController();
/// ...
/// glass.shatter(alignment: Alignment.topLeft);
/// glass.restore();
/// ```
///
/// One controller drives one [BrokenGlass]. Dispose it with the [State] that
/// owns it.
class BrokenGlassController extends ChangeNotifier {
  BrokenGlassController({bool broken = false}) : _broken = broken;

  bool _broken;
  Offset? _impactOffset;
  Alignment? _impactAlignment;
  int? _seed;
  int _revision = 0;

  /// Whether the glass is currently broken (or on its way there).
  bool get isBroken => _broken;

  /// Impact point in the widget's local coordinates, if one was given.
  ///
  /// Read by [BrokenGlass]; you normally don't need this.
  Offset? get impactOffset => _impactOffset;

  /// Impact point as an alignment, if one was given.
  Alignment? get impactAlignment => _impactAlignment;

  /// Seed for the next break, or `null` to break differently every time.
  int? get seed => _seed;

  /// Bumped on every command so a repeated [shatter] re-breaks the glass.
  int get revision => _revision;

  /// Breaks the glass.
  ///
  /// Provide either [at] (local pixel coordinates, e.g. from a tap) or
  /// [alignment] to choose the point of impact; the widget's own
  /// `impact` is used when both are omitted. Passing a [seed] makes the
  /// fracture pattern reproducible.
  void shatter({Offset? at, Alignment? alignment, int? seed}) {
    _impactOffset = at;
    _impactAlignment = alignment;
    _seed = seed;
    _broken = true;
    _revision++;
    notifyListeners();
  }

  /// Reassembles the glass, playing the break backwards.
  void restore() {
    if (!_broken) return;
    _broken = false;
    _revision++;
    notifyListeners();
  }

  /// [shatter] if intact, [restore] if broken.
  void toggle({Offset? at, Alignment? alignment, int? seed}) {
    if (_broken) {
      restore();
    } else {
      shatter(at: at, alignment: alignment, seed: seed);
    }
  }
}
