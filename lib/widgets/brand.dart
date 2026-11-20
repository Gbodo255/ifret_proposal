import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/models.dart';
import '../theme/tokens.dart';

export '../data/models.dart' show Vehicle;

/// Logo i-fret de la charte, en encre ou en blanc.
class Logo extends StatelessWidget {
  const Logo({super.key, this.height = 32, this.white = false});
  final double height;
  final bool white;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(white ? 'assets/brand/logo_white.svg' : 'assets/brand/logo.svg', height: height, semanticsLabel: 'i-fret');
  }
}

/// Photo de véhicule. Les visuels sont détourés sur blanc : le cadre reste blanc.
class VehicleImg extends StatelessWidget {
  const VehicleImg(this.vehicle, {super.key, this.width = 96, this.height = 72, this.imageWidth});
  final Vehicle vehicle;
  final double? width;
  final double height;
  final double? imageWidth;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(kRadius)),
        child: Image.asset(vehicle.asset, width: imageWidth, fit: BoxFit.contain, excludeFromSemantics: true),
      );
}

class Avatar extends StatelessWidget {
  const Avatar(this.name, {super.key, this.size = 48, this.verified = false});
  final String name;

  /// 32, 48 ou 72.
  final double size;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final initials = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2).map((p) => p[0].toUpperCase()).join();
    final badge = size <= 32 ? 16.0 : 22.0;
    return Semantics(
      label: verified ? '$name · transporteur vérifié' : name,
      child: ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.primarySoft, shape: BoxShape.circle),
                child: Text(initials, style: TextStyle(fontSize: size >= 72 ? 21 : 14, fontWeight: FontWeight.w700, color: c.ink)),
              ),
              if (verified)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: badge,
                    height: badge,
                    decoration: BoxDecoration(
                      color: IfretColors.light.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.bg, width: size <= 32 ? 1.5 : 2),
                    ),
                    child: Icon(LucideIcons.check, size: size >= 72 ? 16 : (size <= 32 ? 10 : 12), color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Carte de démonstration : tracé, marqueurs et position du camion.
/// En production, le fond vient du SDK cartographique ; seuls le tracé et
/// les marqueurs suivent le design system.
class MapView extends StatelessWidget {
  const MapView({super.key, this.progress = .45, this.showCarrier = true});
  final double progress;
  final bool showCarrier;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      label: 'Carte du trajet',
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, box) {
            final size = box.biggest;
            Offset at(double x, double y) => Offset(size.width * x / 600, size.height * y);
            final p0 = at(72, .34), p1 = at(280, .8), p2 = at(530, .2);
            final t = progress, u = 1 - t;
            final truck = p0 * (u * u) + p1 * (2 * u * t) + p2 * (t * t);
            return ColoredBox(
              color: c.fillSoft,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(child: CustomPaint(painter: _MapPainter(p0, p1, p2, road: c.bg, route: c.ink))),
                  _pin(p0, c, dropoff: false),
                  _pin(p2, c, dropoff: true),
                  if (showCarrier)
                    Positioned(
                      left: truck.dx - 26,
                      top: truck.dy - 26,
                      child: Container(
                        width: 52,
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: c.primarySoft, shape: BoxShape.circle, boxShadow: [BoxShadow(color: c.shadow, blurRadius: 12, offset: const Offset(0, 4))]),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle, border: Border.all(color: IfretColors.light.ink, width: 3)),
                          child: Icon(LucideIcons.truck, size: 18, color: c.onPrimary),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _pin(Offset p, IfretColors c, {required bool dropoff}) {
    final line = dropoff ? c.onPrimary : c.ink;
    return Positioned(
      left: p.dx - 14,
      top: p.dy - 38,
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: dropoff ? c.primary : c.surface,
              shape: BoxShape.circle,
              border: Border.all(color: line, width: dropoff ? 2 : 6),
              boxShadow: [BoxShadow(color: c.shadow, blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: dropoff ? Icon(LucideIcons.flag, size: 14, color: c.onPrimary) : null,
          ),
          Container(width: 3, height: 10, color: line),
        ],
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  const _MapPainter(this.p0, this.p1, this.p2, {required this.road, required this.route});
  final Offset p0, p1, p2;
  final Color road, route;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    Paint stroke(Color color, double width) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, h * .3), Offset(w, h * .18), stroke(road, 14));
    canvas.drawLine(Offset(w * .2, 0), Offset(w * .3, h), stroke(road, 14));
    canvas.drawLine(Offset(0, h * .75), Offset(w, h * .62), stroke(road, 6));
    canvas.drawLine(Offset(w * .7, 0), Offset(w * .633, h), stroke(road, 6));
    final path = Path()
      ..moveTo(p0.dx, p0.dy)
      ..quadraticBezierTo(p1.dx, p1.dy, p2.dx, p2.dy);
    canvas.drawPath(path, stroke(road, 9));
    canvas.drawPath(path, stroke(route, 5));
  }

  @override
  bool shouldRepaint(_MapPainter old) => old.p0 != p0 || old.p1 != p1 || old.p2 != p2 || old.road != road || old.route != route;
}
