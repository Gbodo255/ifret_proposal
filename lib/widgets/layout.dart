import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/tokens.dart';
import 'brand.dart';
import 'extras.dart';
import 'map.dart';
import 'ui.dart';

/// Barre haute : retour, titre centré, action éventuelle.
class TopBar extends StatelessWidget {
  const TopBar(this.title, {super.key, this.close = false, this.trailing, this.back = true});
  final String title;

  /// Croix à la place de la flèche (écrans qu'on abandonne).
  final bool close;
  final Widget? trailing;
  final bool back;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 56,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            spacing: 10,
            children: [
              if (back)
                IconBtn(close ? LucideIcons.x : LucideIcons.arrowLeft, label: close ? 'Fermer' : 'Retour', onTap: () => Navigator.maybePop(context))
              else
                const SizedBox(width: 40),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(title, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, height: 22 / 16, fontWeight: FontWeight.w600)),
                ),
              ),
              trailing ?? const SizedBox(width: 40),
            ],
          ),
        ),
      );
}

/// En-tête d'un onglet principal : grand titre à gauche, action à droite.
class TabHeader extends StatelessWidget {
  const TabHeader(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 60,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            spacing: 10,
            children: [
              Expanded(
                child: Semantics(header: true, child: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700))),
              ),
              ?trailing,
            ],
          ),
        ),
      );
}

/// Progression d'un parcours : « Étape 2 sur 5 · Marchandise ».
class StepHeader extends StatelessWidget {
  const StepHeader(this.step, this.total, this.name, {super.key, this.padding = const EdgeInsets.fromLTRB(16, 4, 16, 0)});
  final int step;
  final int total;
  final String name;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      label: 'Étape $step sur $total, $name',
      child: ExcludeSemantics(
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Row(
                spacing: 4,
                children: [
                  for (var i = 0; i < total; i++)
                    Expanded(
                      child: Container(height: 4, decoration: BoxDecoration(color: i < step ? c.inverse : c.track, borderRadius: BorderRadius.circular(kRadius))),
                    ),
                ],
              ),
              Lab('Étape $step sur $total · $name'),
            ],
          ),
        ),
      ),
    );
  }
}

/// Corps d'écran : en-tête fixe, contenu défilant, actions fixées en bas.
/// Le contenu est centré et borné en largeur sur grand écran.
class ScreenBody extends StatelessWidget {
  const ScreenBody({super.key, this.top, this.steps, required this.children, this.foot, this.gap = 14, this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 16), this.bottom});
  final Widget? top;
  final Widget? steps;
  final List<Widget> children;
  final List<Widget>? foot;
  final double gap;
  final EdgeInsets padding;

  /// Élément collé en bas sur toute la largeur (saisie du chat).
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    // Dans une coque à onglets, la barre de navigation recouvre le bas du contenu.
    final under = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kContentMax),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ?top,
              ?steps,
              Expanded(
                child: SingleChildScrollView(
                  padding: padding.copyWith(bottom: padding.bottom + (foot == null && bottom == null ? under : 0)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: gap, children: [for (final (i, child) in children.indexed) Appear(index: i, child: child)]),
                ),
              ),
              if (foot != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + under),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 8, children: foot!),
                ),
              if (bottom != null) Padding(padding: EdgeInsets.only(bottom: under), child: bottom),
            ],
          ),
        ),
      ),
    );
  }
}

/// Écran complet hors coque à onglets.
class Screen extends StatelessWidget {
  const Screen({super.key, this.top, this.steps, required this.children, this.foot, this.gap = 14, this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 16), this.bottom});
  final Widget? top;
  final Widget? steps;
  final List<Widget> children;
  final List<Widget>? foot;
  final double gap;
  final EdgeInsets padding;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: ScreenBody(top: top, steps: steps, foot: foot, gap: gap, padding: padding, bottom: bottom, children: children),
      );
}

/// Carte en haut, feuille en bas sur téléphone ; carte à gauche et panneau
/// à droite sur grand écran.
class MapSheetScreen extends StatelessWidget {
  const MapSheetScreen({super.key, required this.mapFraction, this.pickup, this.dropoff, this.progress, required this.overlay, required this.children, this.foot, this.gap = 14});

  /// Part de la hauteur occupée par la carte sur téléphone.
  final double mapFraction;
  final Place? pickup;
  final Place? dropoff;

  /// Avancement du transporteur sur le trajet. Nul : pas de camion sur la carte.
  final double? progress;

  /// Boutons flottants posés sur la carte, de gauche à droite.
  final List<Widget> overlay;
  final List<Widget> children;
  final List<Widget>? foot;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final map = Stack(
      children: [
        Positioned.fill(child: IfMap(pickup: pickup, dropoff: dropoff, progress: progress)),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: overlay),
          ),
        ),
      ],
    );
    final sheet = SafeArea(
      top: context.isWide,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: gap, children: [for (final (i, child) in children.indexed) Appear(index: i, child: child)]),
            ),
          ),
          if (foot != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 4, children: foot!),
            ),
        ],
      ),
    );
    if (context.isWide) {
      return Scaffold(
        body: Row(
          // Sans « stretch », la carte ne prend que la hauteur de ses boutons flottants.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: map),
            Container(
              width: 440,
              decoration: BoxDecoration(color: c.surface, boxShadow: [BoxShadow(color: c.shadow, blurRadius: 24, offset: const Offset(-8, 0))]),
              child: sheet,
            ),
          ],
        ),
      );
    }
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, box) {
          final mapHeight = box.maxHeight * mapFraction;
          return Stack(
            children: [
              Positioned(left: 0, right: 0, top: 0, height: mapHeight, child: map),
              Positioned(
                left: 0,
                right: 0,
                top: mapHeight - 44,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(kRadius)),
                    boxShadow: const [BoxShadow(color: Color(0x1A1E1E1E), blurRadius: 24, offset: Offset(0, -8))],
                  ),
                  child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: kContentMax), child: sheet)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

typedef NavItem = (IconData icon, String label);

/// Coque à onglets : barre basse avec bouton central sur téléphone,
/// rail latéral sur grand écran.
class RoleShell extends StatelessWidget {
  const RoleShell({super.key, required this.index, required this.onIndex, required this.items, required this.centerIcon, required this.centerLabel, required this.onCenter, this.centerOn = true, required this.pages});
  final int index;
  final ValueChanged<int> onIndex;

  /// Quatre entrées : deux à gauche du bouton central, deux à droite.
  final List<NavItem> items;
  final IconData centerIcon;
  final String centerLabel;
  final VoidCallback onCenter;

  /// Bouton central actif (jaune) ou éteint (gris).
  final bool centerOn;
  final List<Widget> pages;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    // Changement d'onglet : le nouveau contenu arrive en fondu, sans perdre l'état des autres.
    final stack = IndexedStack(
      index: index,
      children: [
        for (final (i, page) in pages.indexed)
          AnimatedOpacity(opacity: i == index ? 1 : 0, duration: context.reduceMotion ? Duration.zero : kMedium, curve: kEase, child: page),
      ],
    );
    if (context.isWide) {
      return Scaffold(
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 248,
              decoration: BoxDecoration(color: c.surface, border: Border(right: BorderSide(color: c.line))),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 4,
                    children: [
                      const Padding(padding: EdgeInsets.fromLTRB(8, 4, 8, 20), child: Align(alignment: Alignment.centerLeft, child: Logo(height: 36))),
                      for (final (i, (icon, label)) in items.indexed)
                        Box(
                          height: 48,
                          radius: kRadius,
                          color: i == index ? c.fill : null,
                          selected: i == index,
                          onTap: () => onIndex(i),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            spacing: 12,
                            children: [
                              Icon(icon, size: 22, color: i == index ? c.ink : c.muted),
                              Text(label, style: TextStyle(fontSize: 15, fontWeight: i == index ? FontWeight.w700 : FontWeight.w500, color: i == index ? c.ink : c.muted)),
                            ],
                          ),
                        ),
                      const Spacer(),
                      Cta(centerLabel, icon: centerIcon, tone: centerOn ? CtaTone.primary : CtaTone.outline, onTap: onCenter),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(child: stack),
          ],
        ),
      );
    }
    Widget entry(int i) {
      final (icon, label) = items[i];
      final on = i == index;
      return Expanded(
        child: Semantics(
          selected: on,
          button: true,
          child: InkWell(
            onTap: () => onIndex(i),
            borderRadius: BorderRadius.circular(kRadius),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 4,
              children: [
                Icon(icon, size: 22, color: on ? c.ink : c.muted),
                Text(label, maxLines: 1, style: TextStyle(fontSize: 11, height: 14 / 11, fontWeight: on ? FontWeight.w700 : FontWeight.w500, color: on ? c.ink : c.muted)),
              ],
            ),
          ),
        ),
      );
    }

    const bar = 68.0, lift = 26.0;
    return Scaffold(
      extendBody: true,
      body: stack,
      bottomNavigationBar: SizedBox(
        height: bar + lift + MediaQuery.viewPaddingOf(context).bottom,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Positioned.fill(
              top: lift,
              child: Container(
                padding: EdgeInsets.fromLTRB(8, 0, 8, MediaQuery.viewPaddingOf(context).bottom),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(kRadius)),
                  boxShadow: const [BoxShadow(color: Color(0x171E1E1E), blurRadius: 24, offset: Offset(0, -6))],
                ),
                child: Row(children: [entry(0), entry(1), const Expanded(child: SizedBox()), entry(2), entry(3)]),
              ),
            ),
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(kRadius + 5),
                boxShadow: const [BoxShadow(color: Color(0x2E1E1E1E), blurRadius: 18, offset: Offset(0, 10))],
              ),
              child: Box(
                width: 52,
                height: 52,
                radius: kRadius,
                color: centerOn ? c.primary : c.fill,
                label: centerLabel,
                onTap: onCenter,
                child: Icon(centerIcon, size: 24, color: centerOn ? c.onPrimary : c.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
