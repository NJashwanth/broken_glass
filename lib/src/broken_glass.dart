import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'broken_glass_controller.dart';
import 'glass_shard.dart';
import 'glass_style.dart';
import 'shard_painter.dart';
import 'shatter_pattern.dart';

/// Makes any widget look like a pane of glass, and breaks it on demand.
///
/// When the glass breaks, [BrokenGlass] takes a snapshot of [child], carves it
/// into shards along a radial fracture pattern, and animates the pieces away
/// from the point of impact. Because every shard clips the same snapshot, the
/// artwork stays continuous across the cracks — it is the widget itself that
/// breaks, not a decoration on top of it.
///
/// ```dart
/// BrokenGlass(
///   broken: _isBroken,
///   impact: Alignment.center,
///   child: Image.asset('assets/photo.jpg'),
/// )
/// ```
///
/// Set [scatter] to `false` to stop at cracked glass without the pieces
/// falling away, use [breakOnTap] to break wherever the user touches, or drive
/// it imperatively with a [BrokenGlassController].
///
/// The [child] is fully interactive until it breaks; afterwards it is a frozen
/// image, so pause videos or animations underneath if you keep it broken for
/// long. Snapshotting requires the Impeller or CanvasKit renderer — it is not
/// available on Flutter web's HTML renderer.
class BrokenGlass extends StatefulWidget {
  const BrokenGlass({
    super.key,
    required this.child,
    this.broken = false,
    this.controller,
    this.impact = Alignment.center,
    this.pattern = const ShatterPattern(),
    this.style = const GlassStyle(),
    this.duration = const Duration(milliseconds: 1500),
    this.reverseDuration,
    this.curve = Curves.linear,
    this.spread = 90,
    this.gravity = 320,
    this.rotation = 0.9,
    this.fade = true,
    this.scatter = true,
    this.breakOnTap = false,
    this.seed,
    this.onShattered,
    this.onRestored,
  });

  /// The widget to break.
  final Widget child;

  /// Whether the glass should be broken.
  ///
  /// Ignored when a [controller] is supplied.
  final bool broken;

  /// Imperative alternative to [broken]. Takes precedence when non-null.
  final BrokenGlassController? controller;

  /// Where the break starts, when no explicit point is given.
  final Alignment impact;

  /// How the glass fractures — how many cracks, how irregular, how fine.
  final ShatterPattern pattern;

  /// How the cracks, edges and sheen are painted.
  final GlassStyle style;

  /// Duration of the break.
  final Duration duration;

  /// Duration of [BrokenGlassController.restore]. Defaults to 70% of
  /// [duration].
  final Duration? reverseDuration;

  /// Easing applied to the whole timeline. The shard motion already eases
  /// itself, so the default is linear.
  final Curve curve;

  /// How far, in logical pixels, the fastest shards travel outward.
  final double spread;

  /// How far the shards fall by the end of the animation.
  final double gravity;

  /// Maximum tumble of a shard, in radians.
  final double rotation;

  /// Whether shards fade out as they fly.
  final bool fade;

  /// Whether the pieces separate at all. With `false` the glass simply cracks
  /// and stays put — useful as a "damaged screen" overlay.
  final bool scatter;

  /// Break on tap, at the point touched; tap again to reassemble.
  ///
  /// Widgets inside [child] that handle taps themselves win the gesture, so
  /// use a controller for interactive children.
  final bool breakOnTap;

  /// Fixes the fracture pattern. Leave `null` to break differently every time.
  final int? seed;

  /// Called once the glass has finished breaking.
  final VoidCallback? onShattered;

  /// Called once the glass has finished reassembling.
  final VoidCallback? onRestored;

  @override
  State<BrokenGlass> createState() => _BrokenGlassState();
}

class _BrokenGlassState extends State<BrokenGlass>
    with SingleTickerProviderStateMixin {
  final GlobalKey _boundaryKey = GlobalKey();
  final math.Random _random = math.Random();

  late final AnimationController _animation;

  ui.Image? _snapshot;
  List<GlassShard>? _shards;
  Offset _impactPoint = Offset.zero;

  bool get _wantsBroken => widget.controller?.isBroken ?? widget.broken;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: widget.duration,
      reverseDuration: widget.reverseDuration ?? widget.duration * 0.7,
    )..addStatusListener(_onStatus);
    widget.controller?.addListener(_onControllerChanged);
    if (_wantsBroken) {
      // Nothing has been laid out yet, so break after the first frame and
      // jump straight to the end state rather than animating on arrival.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _wantsBroken) _shatter(animate: false);
      });
    }
  }

  @override
  void didUpdateWidget(BrokenGlass oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onControllerChanged);
      widget.controller?.addListener(_onControllerChanged);
    }
    _animation.duration = widget.duration;
    _animation.reverseDuration =
        widget.reverseDuration ?? widget.duration * 0.7;

    if (widget.controller == null && widget.broken != oldWidget.broken) {
      if (widget.broken) {
        _shatter();
      } else {
        _restore();
      }
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerChanged);
    _animation.dispose();
    _snapshot?.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    final controller = widget.controller!;
    if (controller.isBroken) {
      _shatter(
        at: controller.impactOffset,
        alignment: controller.impactAlignment,
        seed: controller.seed,
      );
    } else {
      _restore();
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.onShattered?.call();
    } else if (status == AnimationStatus.dismissed && _snapshot != null) {
      // Fully reassembled: drop the snapshot and hand the child back its
      // pixels (and its hit testing).
      setState(() {
        _snapshot?.dispose();
        _snapshot = null;
        _shards = null;
      });
      widget.onRestored?.call();
    }
  }

  void _shatter({
    Offset? at,
    Alignment? alignment,
    int? seed,
    bool animate = true,
    bool retry = true,
  }) {
    final object = _boundaryKey.currentContext?.findRenderObject();
    if (object is! RenderRepaintBoundary || object.size.isEmpty) return;

    final image = _capture(object);
    if (image == null) {
      // The boundary had not painted yet; try again next frame.
      if (retry) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _wantsBroken) {
            _shatter(
                at: at,
                alignment: alignment,
                seed: seed,
                animate: animate,
                retry: false);
          }
        });
      }
      return;
    }

    final size = object.size;
    _impactPoint = at ?? (alignment ?? widget.impact).alongSize(size);
    final shards = widget.pattern.generate(
      size: size,
      impact: _impactPoint,
      seed: seed ?? widget.seed ?? _random.nextInt(1 << 31),
    );

    setState(() {
      _snapshot?.dispose();
      _snapshot = image;
      _shards = shards;
    });

    if (animate) {
      _animation.forward(from: 0);
    } else {
      _animation.value = 1;
      widget.onShattered?.call();
    }
  }

  void _restore() {
    if (_snapshot == null) return;
    _animation.reverse();
  }

  ui.Image? _capture(RenderRepaintBoundary boundary) {
    if (boundary.debugNeedsPaint) return null;
    // Cap the ratio: a 3x snapshot of a full screen is already a big texture.
    final ratio =
        math.min(MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0, 3.0);
    try {
      return boundary.toImageSync(pixelRatio: ratio);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content = RepaintBoundary(key: _boundaryKey, child: widget.child);

    final snapshot = _snapshot;
    final shards = _shards;
    if (snapshot != null && shards != null) {
      content = Stack(
        fit: StackFit.passthrough,
        children: [
          // Keeps the child's size and state without painting it.
          Visibility(
            visible: false,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: content,
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, _) => CustomPaint(
                    painter: ShardPainter(
                      shards: shards,
                      image: snapshot,
                      impact: _impactPoint,
                      progress: widget.curve
                          .transform(_animation.value.clamp(0.0, 1.0)),
                      style: widget.style,
                      spread: widget.spread,
                      gravity: widget.gravity,
                      rotation: widget.rotation,
                      fade: widget.fade,
                      scatter: widget.scatter,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (widget.breakOnTap) {
      content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) {
          if (_snapshot != null) {
            if (widget.controller != null) {
              widget.controller!.restore();
            } else {
              _restore();
            }
          } else {
            if (widget.controller != null) {
              widget.controller!.shatter(at: details.localPosition);
            } else {
              _shatter(at: details.localPosition);
            }
          }
        },
        child: content,
      );
    }

    return content;
  }
}
