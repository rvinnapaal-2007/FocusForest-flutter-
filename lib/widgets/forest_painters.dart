import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../models/forest_tree.dart';

// ============================================================
//  Focus Forest Engine
//  Everything here is drawn with CustomPainter (no image assets)
// ============================================================

/// Owns a ticker and exposes elapsed seconds as a ValueListenable.
class _TimeBuilder extends StatefulWidget {
  final Widget Function(BuildContext, ValueListenable<double>) builder;
  const _TimeBuilder({required this.builder});

  @override
  State<_TimeBuilder> createState() => _TimeBuilderState();
}

class _TimeBuilderState extends State<_TimeBuilder>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _time = ValueNotifier<double>(0);
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((d) => _time.value = d.inMicroseconds / 1e6)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _time);
}

// ------------------------------------------------------------
//  PUBLIC WIDGETS
// ------------------------------------------------------------

/// Full-screen animated night forest (stars, moon, hills, pines, fireflies).
class ForestBackdrop extends StatelessWidget {
  final Widget? child;
  const ForestBackdrop({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    return _TimeBuilder(
      builder: (context, time) => SizedBox.expand(
        child: CustomPaint(
          painter: _ScenePainter(time),
          child: child,
        ),
      ),
    );
  }
}

/// A single tree that can grow from seed to full size.
/// If [progress] is null it loops a growth animation on its own (login page).
class GrowingTree extends StatelessWidget {
  final TreeSpecies species;
  final double? progress;
  final bool withered;
  final double height;

  const GrowingTree({
    super.key,
    required this.species,
    this.progress,
    this.withered = false,
    this.height = 280,
  });

  @override
  Widget build(BuildContext context) {
    return _TimeBuilder(
      builder: (context, time) => SizedBox(
        width: height * 1.1,
        height: height,
        child: CustomPaint(
          painter: _SingleTreePainter(time, species, progress, withered),
        ),
      ),
    );
  }
}

/// Panorama of every tree the user has planted.
class ForestGardenScene extends StatelessWidget {
  final List<ForestTree> trees;
  final double height;
  final Widget? overlay;

  const ForestGardenScene({
    super.key,
    required this.trees,
    this.height = 240,
    this.overlay,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: _TimeBuilder(
        builder: (context, time) => SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _GardenPainter(time, trees),
            child: overlay,
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
//  PAINTERS
// ------------------------------------------------------------

class _ScenePainter extends CustomPainter {
  final ValueListenable<double> time;
  _ScenePainter(this.time) : super(repaint: time);

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final w = size.width, h = size.height;
    final rect = Rect.fromLTWH(0, 0, w, h);

    // Sky
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF020B0A), Color(0xFF07251F), Color(0xFF0C3B2B)],
          stops: [0.0, 0.55, 1.0],
        ).createShader(rect),
    );

    _stars(canvas, size, t);
    _moon(canvas, Offset(w * 0.82, h * 0.13), math.min(w, h) * 0.06);
    _hills(canvas, size, h * 0.52, h * 0.06, const Color(0xFF0A2A23), 1.0, 0.004);
    _hills(canvas, size, h * 0.62, h * 0.07, const Color(0xFF08201B), 2.3, 0.006);
    _pineRow(canvas, size, h * 0.70, const Color(0xFF06231B), 0.55, t, 3);
    _hills(canvas, size, h * 0.78, h * 0.05, const Color(0xFF061A15), 4.1, 0.008);
    _pineRow(canvas, size, h * 0.90, const Color(0xFF041510), 0.95, t, 9);

    // Ground fog
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.72, w, h * 0.28),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            const Color(0xFF34D399).withValues(alpha: 0.07),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, h * 0.72, w, h * 0.28)),
    );

    _fireflies(canvas, size, t, 26);
  }

  @override
  bool shouldRepaint(covariant _ScenePainter old) => false;
}

class _SingleTreePainter extends CustomPainter {
  final ValueListenable<double> time;
  final TreeSpecies species;
  final double? progress;
  final bool withered;

  _SingleTreePainter(this.time, this.species, this.progress, this.withered)
      : super(repaint: time);

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final w = size.width, h = size.height;

    double growth;
    if (progress != null) {
      growth = progress!;
    } else {
      // looping demo growth: 6s growing, then rest
      final cycle = t % 9.0;
      growth = (cycle / 6.0).clamp(0.0, 1.0);
    }

    final glowColor = _speciesGlow(species);
    final center = Offset(w / 2, h * 0.52);

    // Aura
    canvas.drawCircle(
      center,
      w * 0.48,
      Paint()
        ..shader = RadialGradient(
          colors: [
            glowColor.withValues(alpha: 0.10 + 0.22 * growth),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: w * 0.48)),
    );

    // Ground mound
    final base = Offset(w / 2, h * 0.88);
    final mound = Rect.fromCenter(center: base.translate(0, h * 0.02), width: w * 0.8, height: h * 0.16);
    canvas.drawOval(
      mound,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1F6B3A), Color(0xFF0B2E1B)],
        ).createShader(mound),
    );
    // grass tufts
    final grass = Paint()
      ..color = const Color(0xFF4ADE80).withValues(alpha: 0.7)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 14; i++) {
      final gx = w * (0.18 + 0.64 * ((i * 0.618) % 1.0));
      final gy = base.dy + h * 0.015 + ((i * 7) % 5) * 1.5;
      final sway = math.sin(t * 1.4 + i) * 2;
      canvas.drawLine(Offset(gx, gy), Offset(gx + sway, gy - 9), grass);
      canvas.drawLine(Offset(gx + 3, gy), Offset(gx + 3 + sway, gy - 6), grass);
    }

    paintTree(canvas, species, base, h * 0.82, growth, t, withered: withered);

    // Fireflies around the tree
    _fireflies(canvas, size, t, 10);
  }

  @override
  bool shouldRepaint(covariant _SingleTreePainter old) =>
      old.progress != progress ||
      old.species != species ||
      old.withered != withered;
}

class _GardenPainter extends CustomPainter {
  final ValueListenable<double> time;
  final List<ForestTree> trees;
  _GardenPainter(this.time, this.trees) : super(repaint: time);

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final w = size.width, h = size.height;
    final rect = Rect.fromLTWH(0, 0, w, h);

    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF031512), Color(0xFF0E4B3A), Color(0xFF1B6B3F)],
          stops: [0.0, 0.5, 1.0],
        ).createShader(rect),
    );
    _stars(canvas, size, t, count: 30, maxY: 0.4);
    _moon(canvas, Offset(w * 0.9, h * 0.16), math.min(w, h) * 0.07);
    _hills(canvas, size, h * 0.42, h * 0.07, const Color(0xFF0B3B2E), 1.7, 0.007);
    _hills(canvas, size, h * 0.55, h * 0.06, const Color(0xFF0F5A3A), 3.2, 0.009);

    // Meadow
    final meadow = Rect.fromLTWH(0, h * 0.58, w, h * 0.42);
    canvas.drawRect(
      meadow,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF166534), Color(0xFF052E16)],
        ).createShader(meadow),
    );

    // Trees (most recent 40), painter's algorithm back-to-front
    final shown = trees.length > 40 ? trees.sublist(trees.length - 40) : trees;
    final items = <_Placed>[];
    for (var i = 0; i < shown.length; i++) {
      final u = (i * 0.61803398875) % 1.0;
      final v = (i * 0.75487766625) % 1.0;
      items.add(_Placed(shown[i], w * (0.05 + 0.9 * u), h * (0.66 + 0.30 * v), v, i));
    }
    items.sort((a, b) => a.y.compareTo(b.y));
    for (final p in items) {
      final dur = (p.tree.durationMinutes / 60.0).clamp(0.0, 1.0);
      final u = h * (0.30 + 0.24 * p.depth) * (0.8 + 0.2 * dur);
      paintTree(canvas, p.tree.species, Offset(p.x, p.y), u, 1.0, t,
          withered: p.tree.isWithered, seed: p.index.toDouble());
    }

    if (shown.isEmpty) {
      final tp = TextPainter(
        text: const TextSpan(
          text: 'Your forest is empty - plant your first tree',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: w - 24);
      tp.paint(canvas, Offset((w - tp.width) / 2, h * 0.72));
    }

    _fireflies(canvas, size, t, 14);
  }

  @override
  bool shouldRepaint(covariant _GardenPainter old) => old.trees != trees;
}

class _Placed {
  final ForestTree tree;
  final double x, y, depth;
  final int index;
  _Placed(this.tree, this.x, this.y, this.depth, this.index);
}

// ------------------------------------------------------------
//  SCENE HELPERS
// ------------------------------------------------------------

void _stars(Canvas canvas, Size size, double t, {int count = 70, double maxY = 0.5}) {
  final rnd = math.Random(7);
  final paint = Paint();
  for (var i = 0; i < count; i++) {
    final x = rnd.nextDouble() * size.width;
    final y = rnd.nextDouble() * size.height * maxY;
    final tw = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(t * 1.8 + i * 1.7));
    paint.color = Colors.white.withValues(alpha: tw * 0.8);
    canvas.drawCircle(Offset(x, y), 0.5 + rnd.nextDouble() * 1.1, paint);
  }
}

void _moon(Canvas canvas, Offset c, double r) {
  canvas.drawCircle(
    c,
    r * 3.2,
    Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFFFDE68A).withValues(alpha: 0.28), Colors.transparent],
      ).createShader(Rect.fromCircle(center: c, radius: r * 3.2)),
  );
  canvas.drawCircle(c, r, Paint()..color = const Color(0xFFFEF3C7));
  canvas.drawCircle(c.translate(r * 0.35, -r * 0.1), r * 0.9,
      Paint()..color = const Color(0xFF07251F).withValues(alpha: 0.18));
}

void _hills(Canvas canvas, Size size, double baseY, double amp, Color color,
    double seed, double freq) {
  final path = Path()..moveTo(0, size.height);
  for (double x = 0; x <= size.width + 8; x += 8) {
    final y = baseY +
        amp * math.sin(x * freq * 3 + seed) +
        amp * 0.5 * math.sin(x * freq * 7.3 + seed * 2);
    path.lineTo(x, y);
  }
  path.lineTo(size.width, size.height);
  path.close();
  canvas.drawPath(path, Paint()..color = color);
}

void _pineRow(Canvas canvas, Size size, double baseY, Color color,
    double scale, double t, double seed) {
  final spacing = 34.0 * scale + 14;
  final count = (size.width / spacing).ceil() + 1;
  final paint = Paint()..color = color;
  for (var i = 0; i < count; i++) {
    final jitter = math.sin(i * 12.9898 + seed) * 10;
    final x = i * spacing + jitter;
    final hgt = (70 + 40 * (0.5 + 0.5 * math.sin(i * 4.1 + seed))) * scale * (size.height / 700).clamp(0.6, 1.5);
    final sway = math.sin(t * 0.9 + i * 0.7 + seed) * 2.2 * scale;
    for (var k = 0; k < 4; k++) {
      final bottom = baseY - k * hgt * 0.2;
      final top = bottom - hgt * 0.42;
      final half = hgt * (0.26 - k * 0.04);
      final p = Path()
        ..moveTo(x - half, bottom)
        ..lineTo(x + sway * (k + 1) * 0.35, top)
        ..lineTo(x + half, bottom)
        ..close();
      canvas.drawPath(p, paint);
    }
    canvas.drawRect(Rect.fromLTWH(x - 2.5 * scale, baseY, 5 * scale, hgt * 0.14), paint);
  }
}

void _fireflies(Canvas canvas, Size size, double t, int count) {
  final rnd = math.Random(21);
  for (var i = 0; i < count; i++) {
    final bx = rnd.nextDouble() * size.width;
    final by = size.height * (0.4 + 0.55 * rnd.nextDouble());
    final x = bx + math.sin(t * 0.5 + i * 1.3) * 22;
    final y = by + math.cos(t * 0.7 + i * 2.1) * 14;
    final pulse = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(t * 2.2 + i * 1.9));
    canvas.drawCircle(
      Offset(x, y),
      7,
      Paint()
        ..color = const Color(0xFFFDE047).withValues(alpha: 0.35 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(Offset(x, y), 1.6, Paint()..color = const Color(0xFFFEF9C3).withValues(alpha: pulse));
  }
}

Color _speciesGlow(TreeSpecies s) {
  switch (s) {
    case TreeSpecies.oak:
      return const Color(0xFF4ADE80);
    case TreeSpecies.sakura:
      return const Color(0xFFF9A8D4);
    case TreeSpecies.pine:
      return const Color(0xFF34D399);
    case TreeSpecies.binaryTree:
      return const Color(0xFF38BDF8);
    case TreeSpecies.goldenBaobab:
      return const Color(0xFFFBBF24);
  }
}

// ------------------------------------------------------------
//  TREE DRAWING  (u = full tree height in pixels, growth 0..1)
// ------------------------------------------------------------

void paintTree(Canvas canvas, TreeSpecies species, Offset base, double u,
    double growth, double t,
    {bool withered = false, double seed = 0}) {
  final g = growth.clamp(0.0, 1.0);
  final sway = math.sin(t * 1.1 + seed);

  // soft ground shadow
  canvas.drawOval(
    Rect.fromCenter(
        center: base.translate(0, u * 0.01),
        width: u * 0.6 * (0.3 + 0.7 * g),
        height: u * 0.07),
    Paint()..color = Colors.black.withValues(alpha: 0.35),
  );

  if (withered) {
    _dead(canvas, base, u, seed);
    return;
  }
  if (g < 0.1) {
    _sprout(canvas, base, u, g / 0.1, sway);
    return;
  }

  final k = ((g - 0.1) / 0.9).clamp(0.0, 1.0);
  final s = Curves.easeOutCubic.transform(k);

  switch (species) {
    case TreeSpecies.pine:
      _pine(canvas, base, u, s, sway);
      break;
    case TreeSpecies.oak:
      _round(canvas, base, u, s, sway, t, seed,
          dark: const Color(0xFF166534), light: const Color(0xFF4ADE80), sakura: false);
      break;
    case TreeSpecies.sakura:
      _round(canvas, base, u, s, sway, t, seed,
          dark: const Color(0xFFDB2777), light: const Color(0xFFFBCFE8), sakura: true);
      break;
    case TreeSpecies.binaryTree:
      _binary(canvas, base, u, s, t);
      break;
    case TreeSpecies.goldenBaobab:
      _baobab(canvas, base, u, s, sway, t);
      break;
  }
}

void _sprout(Canvas c, Offset b, double u, double p, double sway) {
  // seed
  c.drawOval(Rect.fromCenter(center: b.translate(0, -u * 0.005), width: u * 0.07, height: u * 0.04),
      Paint()..color = const Color(0xFF7C4A21));
  if (p <= 0.05) return;
  final stemH = u * 0.13 * p;
  final top = Offset(b.dx + sway * u * 0.004, b.dy - stemH);
  c.drawLine(
    b,
    top,
    Paint()
      ..color = const Color(0xFF65A30D)
      ..strokeWidth = math.max(2, u * 0.018)
      ..strokeCap = StrokeCap.round,
  );
  final leaf = Paint()..color = const Color(0xFF86EFAC);
  for (final dir in [-1.0, 1.0]) {
    c.save();
    c.translate(top.dx, top.dy);
    c.rotate(dir * 0.7);
    c.drawOval(Rect.fromCenter(center: Offset(dir * u * 0.035 * p, -u * 0.01), width: u * 0.08 * p, height: u * 0.035 * p), leaf);
    c.restore();
  }
}

void _blob(Canvas c, Offset center, double r, Color dark, Color light) {
  c.drawCircle(
    center,
    r,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.45),
        colors: [light, dark],
      ).createShader(Rect.fromCircle(center: center, radius: r)),
  );
}

void _pine(Canvas c, Offset b, double u, double s, double sway) {
  final trunkH = u * 0.16 * s;
  c.drawRRect(
    RRect.fromRectAndRadius(
        Rect.fromLTWH(b.dx - u * 0.035, b.dy - trunkH, u * 0.07, trunkH),
        Radius.circular(u * 0.01)),
    Paint()..color = const Color(0xFF5B3A29),
  );
  for (var i = 0; i < 4; i++) {
    final bottom = b.dy - trunkH * 0.6 - i * u * 0.19 * s;
    final top = bottom - u * 0.30 * s;
    final half = u * (0.30 - i * 0.055) * s;
    final dx = sway * u * 0.012 * (i + 1) * s;
    final path = Path()
      ..moveTo(b.dx - half, bottom)
      ..lineTo(b.dx + dx, top)
      ..lineTo(b.dx + half, bottom)
      ..close();
    c.drawPath(path, Paint()..color = Color.lerp(const Color(0xFF14532D), const Color(0xFF22C55E), i / 3)!);
    final hl = Path()
      ..moveTo(b.dx + dx, top)
      ..lineTo(b.dx + half, bottom)
      ..lineTo(b.dx + half * 0.2, bottom)
      ..close();
    c.drawPath(hl, Paint()..color = Colors.white.withValues(alpha: 0.08));
  }
}

void _round(Canvas c, Offset b, double u, double s, double sway, double t,
    double seed,
    {required Color dark, required Color light, required bool sakura}) {
  final h = u * 0.42 * s;
  final trunk = Path()
    ..moveTo(b.dx - u * 0.055, b.dy)
    ..quadraticBezierTo(b.dx - u * 0.02, b.dy - h * 0.5, b.dx - u * 0.025, b.dy - h)
    ..lineTo(b.dx + u * 0.025, b.dy - h)
    ..quadraticBezierTo(b.dx + u * 0.02, b.dy - h * 0.5, b.dx + u * 0.055, b.dy)
    ..close();
  c.drawPath(trunk, Paint()..color = sakura ? const Color(0xFF6B4A3A) : const Color(0xFF6B4423));
  final limb = Paint()
    ..color = sakura ? const Color(0xFF6B4A3A) : const Color(0xFF6B4423)
    ..strokeWidth = math.max(2, u * 0.022)
    ..strokeCap = StrokeCap.round;
  final topPt = Offset(b.dx, b.dy - h);
  c.drawLine(topPt, topPt.translate(-u * 0.12 * s, -u * 0.1 * s), limb);
  c.drawLine(topPt, topPt.translate(u * 0.12 * s, -u * 0.1 * s), limb);

  final center = Offset(b.dx + sway * u * 0.01, b.dy - u * 0.58 * s);
  final r = u * 0.30 * s;
  const blobs = [
    [0.0, 0.38, 0.72],
    [-0.62, 0.18, 0.72],
    [0.62, 0.18, 0.72],
    [0.0, 0.0, 1.0],
    [-0.34, -0.5, 0.66],
    [0.36, -0.46, 0.70],
  ];
  for (final bl in blobs) {
    _blob(c, center.translate(bl[0] * r, bl[1] * r), r * bl[2], dark, light);
  }

  if (sakura && s > 0.7) {
    final petal = Paint();
    for (var i = 0; i < 12; i++) {
      final phase = (t * 0.18 + i / 12 + seed * 0.1) % 1.0;
      final x = center.dx + (i - 5.5) * u * 0.05 + math.sin(t * 1.3 + i) * u * 0.05;
      final y = center.dy + phase * (b.dy - center.dy);
      petal.color = const Color(0xFFFBCFE8).withValues(alpha: (1 - phase) * 0.9);
      c.save();
      c.translate(x, y);
      c.rotate(t + i);
      c.drawOval(Rect.fromCenter(center: Offset.zero, width: u * 0.03, height: u * 0.016), petal);
      c.restore();
    }
  }
}

void _binary(Canvas c, Offset b, double u, double s, double t) {
  const maxDepth = 6;
  final vis = 1 + s * (maxDepth - 1);

  void branch(Offset p, double angle, double len, int d) {
    final f = (vis - d).clamp(0.0, 1.0);
    if (f <= 0) return;
    final l = len * f;
    final a = angle + math.sin(t * 1.2 + d * 0.7) * 0.025 * d;
    final e = Offset(p.dx + math.sin(a) * l, p.dy - math.cos(a) * l);
    final paint = Paint()
      ..color = Color.lerp(const Color(0xFF8B5E3C), const Color(0xFF34D399), d / (maxDepth - 1))!
      ..strokeWidth = math.max(1.4, u * 0.045 * math.pow(0.68, d))
      ..strokeCap = StrokeCap.round;
    c.drawLine(p, e, paint);
    if (d >= 2) {
      final r = u * (d == maxDepth - 1 ? 0.022 : 0.014) * f;
      final nodeColor = d == maxDepth - 1 ? const Color(0xFFA3E635) : const Color(0xFF38BDF8);
      c.drawCircle(e, r * 2.4, Paint()..color = nodeColor.withValues(alpha: 0.22));
      c.drawCircle(e, r, Paint()..color = nodeColor);
    }
    if (d < maxDepth - 1) {
      branch(e, angle - 0.42, len * 0.74, d + 1);
      branch(e, angle + 0.42, len * 0.74, d + 1);
    }
  }

  branch(b, 0, u * 0.26, 0);
}

void _baobab(Canvas c, Offset b, double u, double s, double sway, double t) {
  final h = u * 0.45 * s;
  final rect = Rect.fromLTWH(b.dx - u * 0.15, b.dy - h, u * 0.3, h);
  final trunk = Path()
    ..moveTo(b.dx - u * 0.11, b.dy)
    ..cubicTo(b.dx - u * 0.15, b.dy - h * 0.35, b.dx - u * 0.05, b.dy - h * 0.7, b.dx - u * 0.06, b.dy - h)
    ..lineTo(b.dx + u * 0.06, b.dy - h)
    ..cubicTo(b.dx + u * 0.05, b.dy - h * 0.7, b.dx + u * 0.15, b.dy - h * 0.35, b.dx + u * 0.11, b.dy)
    ..close();
  c.drawPath(
    trunk,
    Paint()
      ..shader = const LinearGradient(colors: [Color(0xFF6B3F1D), Color(0xFFB4783A), Color(0xFF6B3F1D)])
          .createShader(rect),
  );
  final limb = Paint()
    ..color = const Color(0xFF6B3F1D)
    ..strokeWidth = math.max(2, u * 0.025)
    ..strokeCap = StrokeCap.round;
  final top = Offset(b.dx, b.dy - h);
  for (var i = -2; i <= 2; i++) {
    c.drawLine(top, Offset(b.dx + i * u * 0.14 * s, b.dy - h - u * 0.16 * s), limb);
  }
  for (var i = -2; i <= 2; i++) {
    final ctr = Offset(b.dx + i * u * 0.15 * s + sway * u * 0.006,
        b.dy - h - u * (0.18 + (i.abs() == 2 ? 0.0 : 0.05)) * s);
    final r = u * 0.14 * s;
    c.save();
    c.translate(ctr.dx, ctr.dy);
    c.scale(1.0, 0.7);
    _blob(c, Offset.zero, r, const Color(0xFF4D7C0F), const Color(0xFFFACC15));
    c.restore();
  }
  // golden sparkles
  if (s > 0.6) {
    for (var i = 0; i < 8; i++) {
      final a = (0.5 + 0.5 * math.sin(t * 2 + i * 1.7));
      final p = Offset(b.dx + math.sin(i * 2.4) * u * 0.3, b.dy - h - u * 0.2 + math.cos(i * 1.9) * u * 0.12);
      c.drawCircle(p, u * 0.008 + a * u * 0.006, Paint()..color = const Color(0xFFFEF08A).withValues(alpha: 0.4 + 0.6 * a));
    }
  }
}

void _dead(Canvas c, Offset b, double u, double seed) {
  final paint = Paint()..strokeCap = StrokeCap.round;
  void branch(Offset p, double angle, double len, int d) {
    final a = angle + math.sin(seed * 3.1 + d * 1.7 + p.dx * 0.05) * 0.18;
    final e = Offset(p.dx + math.sin(a) * len, p.dy - math.cos(a) * len);
    paint
      ..color = Color.lerp(const Color(0xFF5C4B3A), const Color(0xFF8B7B6A), d / 4)!
      ..strokeWidth = math.max(1.2, u * 0.04 * math.pow(0.66, d));
    c.drawLine(p, e, paint);
    if (d < 4) {
      branch(e, a - 0.5, len * 0.72, d + 1);
      if (d != 3) branch(e, a + 0.55, len * 0.7, d + 1);
    }
  }

  branch(b, 0, u * 0.30, 0);
  // fallen brown leaves
  final leaf = Paint()..color = const Color(0xFF92400E).withValues(alpha: 0.8);
  for (var i = 0; i < 5; i++) {
    c.drawOval(
      Rect.fromCenter(
          center: b.translate((i - 2) * u * 0.07, u * 0.015 + (i % 2) * 2),
          width: u * 0.03,
          height: u * 0.015),
      leaf,
    );
  }
}
