/// Break any widget like a pane of glass.
///
/// Wrap a widget in [BrokenGlass] and toggle `broken`: the widget is
/// snapshotted, carved into shards along a radial fracture pattern, and the
/// pieces tumble away from the point of impact.
library;

export 'src/broken_glass.dart' show BrokenGlass;
export 'src/broken_glass_controller.dart' show BrokenGlassController;
export 'src/glass_shard.dart' show GlassShard;
export 'src/glass_style.dart' show GlassStyle;
export 'src/shard_painter.dart' show ShardPainter;
export 'src/shatter_pattern.dart' show ShatterPattern;
