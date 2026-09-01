import 'package:broken_glass/broken_glass.dart';
import 'package:flutter/material.dart';

void main() => runApp(const BrokenGlassDemo());

class BrokenGlassDemo extends StatelessWidget {
  const BrokenGlassDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Broken Glass',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3DDCFF),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0B0F17),
      ),
      home: const DemoPage(),
    );
  }
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  final BrokenGlassController _glass = BrokenGlassController();

  final _patterns = const {
    'Default': ShatterPattern(),
    'Fine': ShatterPattern.fine,
    'Chunky': ShatterPattern.chunky,
    'Spider web': ShatterPattern.spiderWeb,
  };
  final _styles = const {
    'Window': GlassStyle.window,
    'Screen': GlassStyle.screen,
    'Frost': GlassStyle.frost,
  };

  String _pattern = 'Default';
  String _style = 'Window';
  bool _scatter = true;
  double _spread = 90;
  double _gravity = 320;

  @override
  void dispose() {
    _glass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BrokenGlass'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Reassemble',
            onPressed: _glass.restore,
            icon: const Icon(Icons.restore),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 820;
            final stage = _Stage(
              glass: _glass,
              pattern: _patterns[_pattern]!,
              style: _styles[_style]!,
              scatter: _scatter,
              spread: _spread,
              gravity: _gravity,
            );
            final controls = _controls();
            return wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: stage),
                      SizedBox(width: 320, child: controls),
                    ],
                  )
                : ListView(
                    children: [
                      SizedBox(height: 420, child: stage),
                      controls,
                    ],
                  );
          },
        ),
      ),
    );
  }

  Widget _controls() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Tap the card to break it where you touch.',
            style: TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 20),
          _Section('Pattern'),
          _Choices(
            options: _patterns.keys.toList(),
            selected: _pattern,
            onSelected: (v) => setState(() => _pattern = v),
          ),
          const SizedBox(height: 16),
          _Section('Style'),
          _Choices(
            options: _styles.keys.toList(),
            selected: _style,
            onSelected: (v) => setState(() => _style = v),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Scatter the pieces'),
            subtitle: const Text('Off: crack in place'),
            value: _scatter,
            onChanged: (v) => setState(() => _scatter = v),
          ),
          _Slider(
            label: 'Spread',
            value: _spread,
            max: 300,
            onChanged: (v) => setState(() => _spread = v),
          ),
          _Slider(
            label: 'Gravity',
            value: _gravity,
            max: 900,
            onChanged: (v) => setState(() => _gravity = v),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _glass.shatter(alignment: Alignment.topCenter),
            icon: const Icon(Icons.bolt),
            label: const Text('Break from the top'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _glass.restore,
            icon: const Icon(Icons.restore),
            label: const Text('Reassemble'),
          ),
        ],
      ),
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage({
    required this.glass,
    required this.pattern,
    required this.style,
    required this.scatter,
    required this.spread,
    required this.gravity,
  });

  final BrokenGlassController glass;
  final ShatterPattern pattern;
  final GlassStyle style;
  final bool scatter;
  final double spread;
  final double gravity;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380, maxHeight: 460),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: BrokenGlass(
              controller: glass,
              breakOnTap: true,
              pattern: pattern,
              style: style,
              scatter: scatter,
              spread: spread,
              gravity: gravity,
              duration: const Duration(milliseconds: 1600),
              child: const _Card(),
            ),
          ),
        ),
      ),
    );
  }
}

/// Any widget works — this one is just something worth breaking.
class _Card extends StatelessWidget {
  const _Card();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6D5BFF), Color(0xFF3DDCFF), Color(0xFFFF9F6B)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.ac_unit, size: 48, color: Colors.white),
            const Spacer(),
            const Text(
              'Handle\nwith\ncare',
              style: TextStyle(
                fontSize: 46,
                height: 1.05,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -1.5,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'tap to break',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        letterSpacing: 1.4,
        color: Colors.white38,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _Choices extends StatelessWidget {
  const _Choices({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          ChoiceChip(
            label: Text(option),
            selected: option == selected,
            onSelected: (_) => onSelected(option),
          ),
      ],
    );
  }
}

class _Slider extends StatelessWidget {
  const _Slider({
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label  ${value.round()}',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        Slider(value: value, max: max, onChanged: onChanged),
      ],
    );
  }
}
