import 'package:flutter/material.dart';

/// Couleurs d'usage i-fret. L'application n'a qu'un thème clair.
@immutable
class IfretColors extends ThemeExtension<IfretColors> {
  const IfretColors({
    required this.bg,
    required this.surface,
    required this.fill,
    required this.fillSoft,
    required this.track,
    required this.line,
    required this.lineStrong,
    required this.ink,
    required this.muted,
    required this.primary,
    required this.onPrimary,
    required this.primarySoft,
    required this.inverse,
    required this.onInverse,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.shadow,
  });

  /// Fond d'écran.
  final Color bg;

  /// Feuilles, barre de navigation, éléments flottants.
  final Color surface;

  /// Champs, boutons carrés, pastilles neutres.
  final Color fill;

  /// Cartes grises.
  final Color fillSoft;

  /// Rails de progression.
  final Color track;

  /// Bordure au repos des cartes.
  final Color line;

  /// Bordure des champs et boutons en contour : douce, pour un rendu sobre.
  final Color lineStrong;
  final Color ink;
  final Color muted;
  final Color primary;

  /// Texte posé sur le jaune : toujours l'encre, jamais de blanc.
  final Color onPrimary;
  final Color primarySoft;

  /// Noir d'accent, réservé aux aplats (bouton sombre, pastille choisie), jamais aux bordures.
  final Color inverse;
  final Color onInverse;
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color shadow;

  static const light = IfretColors(
    bg: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    fill: Color(0xFFF4F2EC),
    fillSoft: Color(0xFFF6F4EF),
    track: Color(0xFFECE9E1),
    line: Color(0xFFE9E4D9),
    lineStrong: Color(0xFFCFC8B8),
    ink: Color(0xFF333029),
    muted: Color(0xFF6B655A),
    primary: Color(0xFFFFCC00),
    onPrimary: Color(0xFF333029),
    primarySoft: Color(0xFFFFF6DC),
    inverse: Color(0xFF1E1E1E),
    onInverse: Color(0xFFFFFDF9),
    success: Color(0xFF17733F),
    successSoft: Color(0xFFE7F5EC),
    warning: Color(0xFF8A4A00),
    warningSoft: Color(0xFFFFF0E5),
    danger: Color(0xFFB42318),
    shadow: Color(0x1A333029),
  );

  @override
  IfretColors copyWith() => this;

  @override
  IfretColors lerp(IfretColors? other, double t) => this;
}

extension IfretContext on BuildContext {
  IfretColors get c => IfretColors.light;

  /// Vrai sur tablette paysage, bureau et web large : deux colonnes.
  bool get isWide => MediaQuery.sizeOf(this).width >= 840;

  bool get reduceMotion => MediaQuery.disableAnimationsOf(this);
}

/// Styles de texte de la maquette. La couleur vient du thème, sauf mention.
abstract final class Ts {
  static const h1 = TextStyle(fontSize: 24, height: 30 / 24, fontWeight: FontWeight.w700, letterSpacing: -.48);
  static const h2 = TextStyle(fontSize: 17, height: 24 / 17, fontWeight: FontWeight.w700, letterSpacing: -.17);
  static const b = TextStyle(fontWeight: FontWeight.w600);
  static const lab = TextStyle(fontSize: 12, height: 16 / 12);
  static const small = TextStyle(fontSize: 13, height: 18 / 13);

  /// Montants et chiffres : gras, chiffres à chasse fixe.
  static TextStyle num([double size = 14]) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: -.02 * size,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}

/// Largeur maximale du contenu sur grand écran.
const double kContentMax = 600;

/// Arrondi unique de l'application : boutons, cartes, champs, pastilles, feuilles.
const double kRadius = 10;

/// Courbe et durée communes des animations d'interface.
const kEase = Cubic(.2, 0, 0, 1);
const kFast = Duration(milliseconds: 180);
const kMedium = Duration(milliseconds: 320);

ThemeData ifretTheme() {
  const c = IfretColors.light;
  final body = TextStyle(fontSize: 14, height: 20 / 14, letterSpacing: 0, color: c.ink);
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'WorkSans',
    scaffoldBackgroundColor: c.bg,
    colorScheme: ColorScheme.fromSeed(seedColor: c.primary).copyWith(
      primary: c.primary,
      onPrimary: c.onPrimary,
      surface: c.bg,
      onSurface: c.ink,
      error: c.danger,
    ),
    textTheme: TextTheme(bodyLarge: body.copyWith(fontSize: 15, height: 22 / 15), bodyMedium: body),
    iconTheme: IconThemeData(color: c.ink, size: 20),
    textSelectionTheme: TextSelectionThemeData(cursorColor: c.ink, selectionColor: c.primarySoft, selectionHandleColor: c.ink),
    // Même transition douce sur toutes les plateformes : fondu et léger glissement.
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {for (final p in TargetPlatform.values) p: const _SoftTransitions()},
    ),
    splashFactory: InkSparkle.splashFactory,
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.inverse,
      contentTextStyle: TextStyle(fontFamily: 'WorkSans', fontSize: 14, color: c.onInverse),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(kRadius))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
    ),
    extensions: const [c],
  );
}

class _SoftTransitions extends PageTransitionsBuilder {
  const _SoftTransitions();

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    if (context.reduceMotion) return child;
    final enter = CurvedAnimation(parent: animation, curve: kEase, reverseCurve: Curves.easeIn);
    // L'écran quitté recule très légèrement pendant que le nouveau arrive.
    final leave = CurvedAnimation(parent: secondaryAnimation, curve: kEase);
    return FadeTransition(
      opacity: enter,
      child: SlideTransition(
        position: Tween(begin: const Offset(.06, 0), end: Offset.zero).animate(enter),
        child: SlideTransition(position: Tween(begin: Offset.zero, end: const Offset(-.03, 0)).animate(leave), child: child),
      ),
    );
  }
}
