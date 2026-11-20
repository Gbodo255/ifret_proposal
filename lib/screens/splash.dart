import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/store.dart';
import '../routes.dart';
import '../services/device.dart';
import '../theme/tokens.dart';
import 'location_gate.dart';
import 'onboarding.dart';

const _night = Color(0xFF1E1E1E);
const _yellow = Color(0xFFFFCC00);

// Le logo complet tient dans un cadre de 352,96 × 207,14 ; le globe (le point du « i ») y est centré ici.
const _logoRatio = 352.96 / 207.14;
const _globeAt = Alignment(36.785 / 352.96 * 2 - 1, 27.155 / 207.14 * 2 - 1);
const _globeShare = 49.2 / 352.96;

/// Animation d'entrée, en quatre temps sur 4,6 s :
/// 1. le motif à barres de la charte se dessine en filigrane ;
/// 2. une vague de barres pleines traverse l'écran en diagonale ;
/// 3. le motif s'efface, le globe apparaît seul, en grand ;
/// 4. le globe rétrécit et vient se poser en point du « i » pendant que le nom apparaît.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 4600));
  late final Future<(LocationStatus, Place?)> _location = locate();
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Les photos de l'onboarding se chargent pendant l'animation : aucun temps mort ensuite.
    for (final image in onboardingImages) {
      precacheImage(AssetImage(image), context);
    }
    // Moins d'animations demandé : le logo reste posé un instant, sans mouvement.
    if (context.reduceMotion) _controller.duration = const Duration(milliseconds: 900);
    _controller.forward().whenComplete(_leave);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Vers l'onboarding si la localisation est déjà autorisée, sinon vers l'écran qui la demande.
  Future<void> _leave() async {
    final (status, here) = await _location;
    if (!mounted) return;
    final store = context.store;
    if (here != null) store.update(() => store.here = here);
    final granted = status == LocationStatus.granted;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        settings: RouteSettings(name: granted ? R.onboarding : R.gate),
        transitionDuration: Duration(milliseconds: context.reduceMotion ? 0 : 500),
        pageBuilder: (_, _, _) => granted ? const OnboardingScreen() : const LocationGateScreen(),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final still = context.reduceMotion;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _night,
        body: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            // Temps en secondes. Sans animation : état final, logo complet posé.
            final s = still ? 3.6 : _controller.value * 3.6;
            double phase(double from, double to, [Curve curve = Curves.linear]) => curve.transform(((s - from) / (to - from)).clamp(0.0, 1.0));

            final size = MediaQuery.sizeOf(context);
            final logoWidth = math.min(240.0, size.width * .58);
            final globe = logoWidth * _globeShare;
            // Taille du globe quand il est seul à l'écran, avant de rejoindre le nom.
            final big = math.min(120.0, size.width * .3) / globe;

            final pop = phase(2.1, 2.5, Curves.easeOutBack);
            final settle = phase(2.6, 3.2, kEase);
            final name = phase(2.95, 3.4, Curves.easeOut);
            // Écart entre le centre de l'écran et la place du globe dans le logo posé.
            final home = Offset(_globeAt.x * logoWidth / 2, _globeAt.y * logoWidth / _logoRatio / 2);

            return Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(
                  child: CustomPaint(painter: _PatternPainter(lines: phase(0, 1.1), wave: phase(.9, 2.1), fade: phase(1.9, 2.4))),
                ),
                Center(
                  child: SizedBox(
                    width: logoWidth,
                    height: logoWidth / _logoRatio,
                    child: Stack(
                      fit: StackFit.expand,
                      clipBehavior: Clip.none,
                      children: [
                        Opacity(
                          opacity: name,
                          child: Transform.translate(
                            offset: Offset(14 * (1 - name), 0),
                            child: SvgPicture.asset('assets/brand/wordmark_white.svg', excludeFromSemantics: true),
                          ),
                        ),
                        Opacity(
                          opacity: pop.clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: -home * (1 - settle),
                            child: Transform.scale(
                              scale: (big + (1 - big) * settle) * (.6 + .4 * pop),
                              alignment: _globeAt,
                              child: SvgPicture.asset('assets/brand/globe.svg', semanticsLabel: 'i-fret'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Motif à barres inclinées de la charte : d'abord en filigrane, puis traversé par une vague de barres pleines.
class _PatternPainter extends CustomPainter {
  const _PatternPainter({required this.lines, required this.wave, required this.fade});

  /// Avancement du tracé du filigrane, de la vague pleine, puis de l'effacement.
  final double lines;
  final double wave;
  final double fade;

  static const _fills = [_yellow, Color(0xFFD0A600), Color(0xFFFFEFD3)];

  @override
  void paint(Canvas canvas, Size size) {
    if (fade >= 1) return;
    const cell = Size(92, 46), gap = 10.0, skew = 13.0;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final fill = Paint();
    final rows = (size.height / cell.height).ceil() + 1;
    final cols = (size.width / cell.width).ceil() + 2;
    for (var row = 0; row < rows; row++) {
      final y = row * cell.height;
      for (var col = -1; col < cols; col++) {
        final x = col * cell.width + (row.isOdd ? cell.width / 2 : 0);
        // Position de la barre sur la diagonale de l'écran, de 0 (haut gauche) à 1 (bas droite).
        final d = ((x + y) / (size.width + size.height)).clamp(0.0, 1.0);
        final bar = Path()
          ..moveTo(x + skew, y)
          ..lineTo(x + cell.width - gap + skew, y)
          ..lineTo(x + cell.width - gap - skew, y + cell.height - gap)
          ..lineTo(x - skew, y + cell.height - gap)
          ..close();
        final outline = ((lines * 1.5 - d) * 5).clamp(0.0, 1.0) * (1 - fade);
        if (outline > 0) canvas.drawPath(bar, stroke..color = Colors.white.withValues(alpha: .11 * outline));
        // La vague balaie tout l'écran en diagonale.
        final p = ((wave * 1.7 - d - .12) / .5).clamp(0.0, 1.0);
        final alpha = math.sin(p * math.pi) * (1 - fade);
        if (alpha > .01) canvas.drawPath(bar, fill..color = _fills[(col * 2 + row) % 3].withValues(alpha: alpha * ((col + row).isEven ? 1 : .55)));
      }
    }
  }

  @override
  bool shouldRepaint(_PatternPainter old) => old.lines != lines || old.wave != wave || old.fade != fade;
}
