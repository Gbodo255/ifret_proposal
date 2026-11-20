import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../routes.dart';
import '../theme/tokens.dart';
import '../widgets/ui.dart';

const _night = Color(0xFF1E1E1E);
const _cream = Color(0xFFFFFDF9);

typedef _Slide = ({String image, String alt, double focusX, String line1, String line2, String text, String step});

/// Photos de l'onboarding, préchargées pendant l'animation d'entrée.
const onboardingImages = ['assets/images/onboarding_1.jpg', 'assets/images/onboarding_2.jpg', 'assets/images/onboarding_3.jpg'];

const _slides = <_Slide>[
  (
    image: 'assets/images/onboarding_1.jpg',
    alt: 'Camion jaune sur une rue pavée',
    focusX: -.08,
    line1: 'Le bon camion,',
    line2: 'tout de suite.',
    text: 'Décris ta marchandise : i-fret alerte les transporteurs autour de toi, le premier disponible la prend.',
    step: 'Trouver un transporteur',
  ),
  (
    image: 'assets/images/onboarding_2.jpg',
    alt: 'Camion porte-conteneur à l’arrêt',
    focusX: .04,
    line1: 'Un prix clair',
    line2: 'avant de payer.',
    text: 'Tu vois la fourchette avant de confirmer, puis tu règles par Mobile Money.',
    step: 'Prix et paiement',
  ),
  (
    image: 'assets/images/onboarding_3.jpg',
    alt: 'Camion chargé en route',
    focusX: -.06,
    line1: 'Ta marchandise,',
    line2: 'suivie en direct.',
    text: 'Position sur la carte, chat avec le transporteur et code à quatre chiffres à la remise.',
    step: 'Suivi en direct',
  ),
];

/// Onboarding animé : trois photos plein écran qui défilent seules,
/// zoom lent sur l'image active, texte qui monte en fondu.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  Timer? _autoplay;
  int _slide = 0;

  @override
  void initState() {
    super.initState();
    _autoplay = Timer.periodic(const Duration(milliseconds: 5200), (_) {
      _slide < _slides.length - 1 ? _show(_slide + 1) : _autoplay?.cancel();
    });
  }

  @override
  void dispose() {
    _autoplay?.cancel();
    _pages.dispose();
    super.dispose();
  }

  void _show(int i) {
    if (context.reduceMotion) {
      _pages.jumpToPage(i);
    } else {
      _pages.animateToPage(i, duration: const Duration(milliseconds: 600), curve: const Cubic(.3, 0, 0, 1));
    }
  }

  /// Dès que la personne prend la main, le défilement automatique s'arrête.
  void _pick(int i) {
    _autoplay?.cancel();
    _show(i);
  }

  @override
  Widget build(BuildContext context) {
    final last = _slide == _slides.length - 1;
    return Scaffold(
      backgroundColor: _night,
      body: Stack(
        children: [
          // Fond sombre : icônes de la barre d'état en clair.
          const Positioned.fill(child: AnnotatedRegion<SystemUiOverlayStyle>(value: SystemUiOverlayStyle.light, child: SizedBox.expand())),
          Listener(
            onPointerDown: (_) => _autoplay?.cancel(),
            child: PageView(
              controller: _pages,
              onPageChanged: (i) => setState(() => _slide = i),
              children: [for (final (i, s) in _slides.indexed) _SlideView(s, active: i == _slide)],
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: kContentMax),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => context.go(R.compte),
                            style: TextButton.styleFrom(foregroundColor: _cream, minimumSize: const Size(48, 44), padding: const EdgeInsets.symmetric(horizontal: 14)),
                            child: const Text('Passer', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        spacing: 20,
                        children: [
                          Row(
                            spacing: 6,
                            children: [
                              for (final (i, s) in _slides.indexed) _Dot(label: s.step, on: i == _slide, onTap: () => _pick(i)),
                              const Spacer(),
                              Text('0${_slide + 1} / 0${_slides.length}', style: Ts.num(15).copyWith(color: _cream)),
                            ],
                          ),
                          Cta(
                            last ? 'Commencer' : 'Continuer',
                            trailing: LucideIcons.arrowRight,
                            onTap: last ? () => context.go(R.compte) : () => _pick(_slide + 1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView(this.slide, {required this.active});
  final _Slide slide;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final still = context.reduceMotion;
    return Stack(
      fit: StackFit.expand,
      children: [
        FractionallySizedBox(
          heightFactor: .77,
          alignment: Alignment.topCenter,
          child: ClipRect(
            child: AnimatedScale(
              scale: active && !still ? 1.06 : 1,
              duration: still ? Duration.zero : const Duration(seconds: 6),
              curve: Curves.easeOut,
              alignment: const Alignment(0, -.2),
              child: Image.asset(slide.image, fit: BoxFit.cover, alignment: Alignment(slide.focusX, 0), semanticLabel: slide.alt),
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x991E1E1E), Color(0x001E1E1E), Color(0x001E1E1E), Color(0xC71E1E1E), _night],
              stops: [0, .154, .427, .64, .77],
            ),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kContentMax),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 160),
                child: AnimatedSlide(
                  offset: active || still ? Offset.zero : const Offset(0, .1),
                  duration: const Duration(milliseconds: 650),
                  curve: const Interval(.3, 1, curve: Cubic(.2, 0, 0, 1)),
                  child: AnimatedOpacity(
                    opacity: active ? 1 : 0,
                    duration: still ? Duration.zero : const Duration(milliseconds: 650),
                    curve: const Interval(.3, 1),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 14,
                      children: [
                        Semantics(
                          header: true,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text.rich(
                              TextSpan(
                                text: '${slide.line1.toUpperCase()}\n',
                                children: [TextSpan(text: slide.line2.toUpperCase(), style: TextStyle(color: IfretColors.light.primary))],
                              ),
                              style: const TextStyle(fontSize: 35, height: 36 / 35, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, letterSpacing: -.7, color: _cream),
                            ),
                          ),
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: Text(slide.text, style: const TextStyle(fontSize: 16, height: 24 / 16, color: Color(0xFFE9E4D8))),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Repère d'étape incliné, comme les barres du logo.
class _Dot extends StatelessWidget {
  const _Dot({required this.label, required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        label: label,
        selected: on,
        button: true,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Transform(
              transform: Matrix4.skewX(-.42),
              alignment: Alignment.center,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: on ? 44 : 16,
                height: 8,
                decoration: BoxDecoration(color: on ? IfretColors.light.primary : const Color(0x73FFFDF9), borderRadius: BorderRadius.circular(2)),
              ),
            ),
          ),
        ),
      );
}
