import 'package:flutter/widgets.dart';

/// Controls how the broken glass is *painted*: the cracks, the lit edges of
/// each shard and the specular sheen that sells the material.
@immutable
class GlassStyle {
  const GlassStyle({
    this.crackColor = const Color(0xCC0B1622),
    this.crackWidth = 1.6,
    this.edgeColor = const Color(0xFFFFFFFF),
    this.edgeWidth = 0.9,
    this.edgeOpacity = 0.55,
    this.glare = 0.22,
    this.tint = const Color(0x0F9FD8FF),
    this.shadows = true,
    this.shadowElevation = 8.0,
    this.impactFlash = true,
  });

  /// Colour of the fracture lines while the pieces are still together.
  final Color crackColor;

  /// Stroke width of the fracture lines, in logical pixels.
  final double crackWidth;

  /// Colour of the lit bevel along every shard edge.
  final Color edgeColor;

  /// Stroke width of the lit bevel.
  final double edgeWidth;

  /// Peak opacity of the lit bevel.
  final double edgeOpacity;

  /// Strength of the per-shard specular sheen, `0` to disable.
  final double glare;

  /// A faint colour wash over every shard, giving the glass its own hue.
  /// Use a fully transparent colour for perfectly clear glass.
  final Color tint;

  /// Whether flying shards cast a shadow onto whatever is behind them.
  final bool shadows;

  /// Peak elevation used for those shadows.
  final double shadowElevation;

  /// Whether to flash a bright bloom at the point of impact.
  final bool impactFlash;

  /// Clear, brightly lit window glass.
  static const GlassStyle window = GlassStyle();

  /// A cracked phone screen: dark fractures, minimal sheen.
  static const GlassStyle screen = GlassStyle(
    crackColor: Color(0xE6060A10),
    crackWidth: 2.0,
    edgeOpacity: 0.35,
    glare: 0.12,
    tint: Color(0x00000000),
    shadowElevation: 4,
  );

  /// Thick, cold, obviously-glass shards.
  static const GlassStyle frost = GlassStyle(
    crackColor: Color(0xB3123449),
    edgeOpacity: 0.8,
    glare: 0.38,
    tint: Color(0x1FBFE9FF),
    shadowElevation: 12,
  );

  GlassStyle copyWith({
    Color? crackColor,
    double? crackWidth,
    Color? edgeColor,
    double? edgeWidth,
    double? edgeOpacity,
    double? glare,
    Color? tint,
    bool? shadows,
    double? shadowElevation,
    bool? impactFlash,
  }) {
    return GlassStyle(
      crackColor: crackColor ?? this.crackColor,
      crackWidth: crackWidth ?? this.crackWidth,
      edgeColor: edgeColor ?? this.edgeColor,
      edgeWidth: edgeWidth ?? this.edgeWidth,
      edgeOpacity: edgeOpacity ?? this.edgeOpacity,
      glare: glare ?? this.glare,
      tint: tint ?? this.tint,
      shadows: shadows ?? this.shadows,
      shadowElevation: shadowElevation ?? this.shadowElevation,
      impactFlash: impactFlash ?? this.impactFlash,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GlassStyle &&
          other.crackColor == crackColor &&
          other.crackWidth == crackWidth &&
          other.edgeColor == edgeColor &&
          other.edgeWidth == edgeWidth &&
          other.edgeOpacity == edgeOpacity &&
          other.glare == glare &&
          other.tint == tint &&
          other.shadows == shadows &&
          other.shadowElevation == shadowElevation &&
          other.impactFlash == impactFlash;

  @override
  int get hashCode => Object.hash(crackColor, crackWidth, edgeColor, edgeWidth,
      edgeOpacity, glare, tint, shadows, shadowElevation, impactFlash);
}
