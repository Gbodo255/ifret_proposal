import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

export '../data/models.dart';
import '../theme/tokens.dart';

/// Brique de base : fond, arrondi, bordure, ombre et zone tactile.
/// Le texte qu'elle contient repart du style de corps du thème.
class Box extends StatelessWidget {
  const Box({
    super.key,
    this.color,
    this.radius = 0,
    this.border,
    this.shadow = false,
    this.padding,
    this.onTap,
    this.width,
    this.height,
    this.label,
    this.selected,
    this.child,
  });

  final Color? color;
  final double radius;
  final BorderSide? border;
  final bool shadow;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final String? label;
  final bool? selected;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    Widget inner = child ?? const SizedBox.shrink();
    if (padding != null) inner = Padding(padding: padding!, child: inner);
    Widget w = Material(
      color: color ?? Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: r, side: border ?? BorderSide.none),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? inner : InkWell(onTap: onTap, child: inner),
    );
    if (shadow) {
      w = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: r,
          boxShadow: [BoxShadow(color: context.c.shadow, blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: w,
      );
    }
    if (width != null || height != null) w = SizedBox(width: width, height: height, child: w);
    if (onTap != null) w = _Press(child: w);
    if (label == null && selected == null) return w;
    return Semantics(label: label, button: onTap != null, selected: selected, child: w);
  }
}

/// Retour tactile : l'élément s'enfonce très légèrement sous le doigt.
class _Press extends StatefulWidget {
  const _Press({required this.child});
  final Widget child;

  @override
  State<_Press> createState() => _PressState();
}

class _PressState extends State<_Press> {
  bool _down = false;

  void _set(bool down) {
    if (down != _down && mounted) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: (_) => _set(true),
        onPointerUp: (_) => _set(false),
        onPointerCancel: (_) => _set(false),
        child: AnimatedScale(scale: _down && !context.reduceMotion ? .97 : 1, duration: const Duration(milliseconds: 110), curve: Curves.easeOut, child: widget.child),
      );
}

// ───────────────────────── Texte ─────────────────────────

class Lab extends StatelessWidget {
  const Lab(this.text, {super.key, this.align, this.maxLines});
  final String text;
  final TextAlign? align;
  final int? maxLines;

  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: align,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
        style: Ts.lab.copyWith(color: context.c.muted),
      );
}

class Sub extends StatelessWidget {
  const Sub(this.text, {super.key, this.align});
  final String text;
  final TextAlign? align;

  @override
  Widget build(BuildContext context) => Text(text, textAlign: align, style: TextStyle(color: context.c.muted));
}

/// Titre d'écran avec sa phrase d'accompagnement.
class Heading extends StatelessWidget {
  const Heading(this.title, {super.key, this.sub});
  final String title;
  final String? sub;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          Semantics(header: true, child: Text(title, style: Ts.h1)),
          if (sub != null) Sub(sub!),
        ],
      );
}

/// Titre de section avec son action à droite. Le titre passe à la ligne si la place manque.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, required this.trailing});
  final String title;
  final Widget trailing;

  @override
  Widget build(BuildContext context) => Row(
        spacing: 12,
        children: [
          Expanded(child: Semantics(header: true, child: Text(title, style: Ts.h2))),
          trailing,
        ],
      );
}

class Hr extends StatelessWidget {
  const Hr({super.key});

  @override
  Widget build(BuildContext context) => Container(height: 1, color: context.c.line);
}

/// Groupe précédé de son petit intitulé.
class Labeled extends StatelessWidget {
  const Labeled(this.label, {super.key, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
            child: Semantics(
              header: true,
              child: Text(label, style: Ts.lab.copyWith(fontWeight: FontWeight.w600, color: context.c.muted)),
            ),
          ),
          child,
        ],
      );
}

/// Ligne d'information : petite icône et texte secondaire.
class InfoRow extends StatelessWidget {
  const InfoRow(this.icon, this.text, {super.key, this.iconSize = 16, this.center = false});
  final IconData icon;
  final String text;
  final double iconSize;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final label = Lab(text);
    return Row(
      mainAxisAlignment: center ? MainAxisAlignment.center : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Icon(icon, size: iconSize, color: context.c.muted),
        center ? Flexible(child: label) : Expanded(child: label),
      ],
    );
  }
}


/// Montant en grand, suivi de la devise en petit.
class Amount extends StatelessWidget {
  const Amount(this.value, {super.key, this.size = 32, this.unitSize = 14});
  final String value;
  final double size;
  final double unitSize;

  @override
  Widget build(BuildContext context) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: Text.rich(
          TextSpan(text: '$value ', children: [TextSpan(text: 'FCFA', style: TextStyle(fontSize: unitSize))]),
          style: Ts.num(size).copyWith(height: 1.22),
        ),
      );
}

/// Trait pointillé horizontal entre deux prix.
class DashLine extends StatelessWidget {
  const DashLine({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(height: 2, child: CustomPaint(painter: _DashLinePainter()));
}

class _DashLinePainter extends CustomPainter {
  const _DashLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x801E1E1E)
      ..strokeWidth = 2;
    for (double x = 0; x < size.width; x += 10) {
      canvas.drawLine(Offset(x, 1), Offset((x + 6).clamp(0, size.width), 1), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Ligne « libellé … montant » des reçus et récapitulatifs.
class Kv extends StatelessWidget {
  const Kv(this.label, this.value, {super.key, this.sub, this.total = false, this.badge, this.muted = true});
  final String label;
  final String value;
  final String? sub;
  final bool total;
  final Widget? badge;
  final bool muted;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: sub == null ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(label, style: total ? Ts.b : TextStyle(color: muted ? context.c.muted : null)),
                    ?badge,
                  ],
                ),
                if (sub != null) Lab(sub!),
              ],
            ),
          ),
          Text(value, style: Ts.num(total ? 17 : 14)),
        ],
      );
}

// ───────────────────────── Pastilles et boutons ─────────────────────────

enum Tone { primary, neutral, dark, success, warning, outline, floating }

class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.tone = Tone.primary, this.icon, this.trailing, this.led = false, this.height = 26, this.onTap, this.shadow = false});
  final String text;
  final Tone tone;
  final IconData? icon;
  final IconData? trailing;
  final bool led;
  final double height;
  final VoidCallback? onTap;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (bg, fg) = switch (tone) {
      Tone.primary => (c.primary, c.onPrimary),
      Tone.neutral => (c.fill, c.ink),
      Tone.dark => (c.inverse, c.onInverse),
      Tone.success => (c.successSoft, c.success),
      Tone.warning => (c.warningSoft, c.warning),
      Tone.outline => (Colors.transparent, c.ink),
      Tone.floating => (c.surface, c.ink),
    };
    final iconSize = height >= 32 ? 16.0 : 14.0;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: 1,
      heightFactor: 1,
      child: Box(
        color: bg,
        radius: kRadius,
        height: height,
        border: tone == Tone.outline ? BorderSide(color: c.line, width: 1.5) : null,
        shadow: shadow || tone == Tone.floating,
        onTap: onTap,
        padding: EdgeInsets.symmetric(horizontal: height >= 32 ? 12 : (height <= 20 ? 7 : 10)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            if (led) Container(width: 8, height: 8, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
            if (icon != null) Icon(icon, size: iconSize, color: fg),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w600, color: fg),
              ),
            ),
            if (trailing != null) Icon(trailing, size: iconSize, color: fg),
          ],
        ),
      ),
    );
  }
}

/// Pastille translucide posée sur une carte jaune.
class Chip2 extends StatelessWidget {
  const Chip2(this.text, {super.key, this.icon});
  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Box(
        color: Colors.white.withValues(alpha: .6),
        radius: kRadius,
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            if (icon != null) Icon(icon, size: 14),
            Text(text, style: const TextStyle(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

enum IbTone { fill, outline, primary, floating, dark, ghost }

class IconBtn extends StatelessWidget {
  const IconBtn(this.icon, {super.key, required this.label, this.tone = IbTone.fill, this.size = 40, this.iconSize = 20, this.onTap, this.dot = false});
  final IconData icon;
  final String label;
  final IbTone tone;
  final double size;
  final double iconSize;
  final VoidCallback? onTap;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (bg, fg) = switch (tone) {
      IbTone.fill => (c.fill, c.ink),
      IbTone.outline || IbTone.ghost => (Colors.transparent, c.ink),
      IbTone.primary => (c.primary, c.onPrimary),
      IbTone.floating => (c.surface, c.ink),
      IbTone.dark => (c.inverse, c.onInverse),
    };
    return Box(
      width: size,
      height: size,
      radius: kRadius,
      color: bg,
      border: tone == IbTone.outline ? BorderSide(color: c.line, width: 1.5) : null,
      shadow: tone == IbTone.floating,
      onTap: onTap,
      label: label,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(icon, size: iconSize, color: fg),
          if (dot)
            Positioned(
              top: 9,
              right: 10,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFFD9480F),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: c.bg, spreadRadius: 2)],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

enum CtaTone { primary, dark, outline, white }

/// Bouton principal, pleine largeur.
class Cta extends StatelessWidget {
  const Cta(this.text, {super.key, this.onTap, this.tone = CtaTone.primary, this.icon, this.trailing, this.height = 52, this.fontSize = 16, this.busy = false});

  /// Action en cours : le libellé laisse place à un indicateur, le bouton ne répond plus.
  final bool busy;
  final String text;
  final VoidCallback? onTap;
  final CtaTone tone;
  final IconData? icon;
  final IconData? trailing;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (bg, fg) = switch (tone) {
      CtaTone.primary => (c.primary, c.onPrimary),
      CtaTone.dark => (c.inverse, c.onInverse),
      CtaTone.outline => (Colors.transparent, c.ink),
      CtaTone.white => (Colors.white, IfretColors.light.ink),
    };
    // Sans action, le bouton est désactivé : estompé et annoncé comme tel.
    return AnimatedOpacity(
      opacity: onTap == null && !busy ? .48 : 1,
      duration: kFast,
      child: Semantics(
        enabled: onTap != null && !busy,
        button: true,
        label: busy ? '$text, en cours' : null,
        child: _body(c, bg, fg),
      ),
    );
  }

  Widget _body(IfretColors c, Color bg, Color fg) {
    return Box(
      width: double.infinity,
      height: height,
      radius: kRadius,
      color: bg,
      border: tone == CtaTone.outline ? BorderSide(color: c.lineStrong, width: 1.5) : null,
      onTap: busy ? null : onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: busy
          ? Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: fg)))
          : Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 8,
        children: [
          if (icon != null) Icon(icon, size: fontSize + 2, color: fg),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: fontSize, height: 22 / 16, fontWeight: FontWeight.w600, color: fg),
            ),
          ),
          if (trailing != null) Icon(trailing, size: 20, color: fg),
        ],
      ),
    );
  }
}

/// Action secondaire en texte seul.
class LinkBtn extends StatelessWidget {
  const LinkBtn(this.text, {super.key, this.onTap, this.icon, this.color});
  final String text;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? context.c.ink;
    return Box(
      height: 44,
      radius: kRadius,
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 8,
        children: [
          if (icon != null) Icon(icon, size: 18, color: fg),
          Text(text, style: TextStyle(fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }
}

/// Lien souligné dans une ligne.
class TextLink extends StatelessWidget {
  const TextLink(this.text, {super.key, this.onTap, this.color});
  final String text;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          child: Text(
            text,
            style: TextStyle(fontWeight: FontWeight.w600, color: color, decoration: color == null ? TextDecoration.underline : null),
          ),
        ),
      );
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.selected = false, this.onTap, this.height = 36, this.expand = false});
  final String text;
  final bool selected;
  final VoidCallback? onTap;
  final double height;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final label = Text(
      text,
      maxLines: 1,
      style: TextStyle(
        fontSize: height < 36 ? 13 : 14,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        color: selected ? c.onInverse : c.ink,
      ),
    );
    return Box(
      color: selected ? c.inverse : c.fill,
      radius: kRadius,
      height: height,
      onTap: onTap,
      selected: selected,
      padding: EdgeInsets.symmetric(horizontal: expand ? 2 : 14),
      child: expand ? Center(child: FittedBox(fit: BoxFit.scaleDown, child: label)) : Center(widthFactor: 1, child: label),
    );
  }
}

/// Choix multiples ou uniques sous forme de pastilles qui passent à la ligne.
class PillWrap extends StatelessWidget {
  const PillWrap({super.key, required this.options, required this.isOn, required this.onPick});
  final List<String> options;
  final bool Function(String) isOn;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [for (final o in options) Pill(o, selected: isOn(o), onTap: () => onPick(o))],
      );
}

/// Sélecteur à deux ou trois segments.
class Seg extends StatelessWidget {
  const Seg({super.key, required this.options, required this.value, required this.onChanged});
  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: c.fill, borderRadius: BorderRadius.circular(kRadius)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final o in options)
            Box(
              height: 30,
              radius: kRadius,
              color: o == value ? c.surface : null,
              shadow: o == value,
              selected: o == value,
              onTap: () => onChanged(o),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Center(
                widthFactor: 1,
                child: Text(
                  o,
                  style: TextStyle(fontSize: 13, fontWeight: o == value ? FontWeight.w600 : FontWeight.w500, color: o == value ? c.ink : c.muted),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ───────────────────────── Cartes et conteneurs ─────────────────────────

enum CardTone { outline, yellow, soft }

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.tone = CardTone.outline, this.padding = const EdgeInsets.all(16), this.onTap, this.label});
  final Widget child;
  final CardTone tone;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    if (tone == CardTone.yellow) {
      return Box(
        color: IfretColors.light.primary,
        radius: kRadius,
        onTap: onTap,
        label: label,
        child: Stack(
          children: [
            const Positioned.fill(child: CustomPaint(painter: _DecoPainter())),
            Padding(padding: padding, child: child),
          ],
        ),
      );
    }
    final c = context.c;
    return Box(
      color: tone == CardTone.soft ? c.fillSoft : null,
      radius: kRadius,
      border: tone == CardTone.outline ? BorderSide(color: c.line, width: 1.5) : null,
      padding: padding,
      onTap: onTap,
      label: label,
      child: child,
    );
  }
}

/// Relief des cartes jaunes : trois cercles concentriques dans l'angle.
class _DecoPainter extends CustomPainter {
  const _DecoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width - 19, 19);
    for (final (r, a) in const [(147.0, .07), (109.0, .035), (75.0, .045)]) {
      canvas.drawCircle(center, r, Paint()..color = Colors.white.withValues(alpha: a));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Champ factice ou zone de saisie remplie (recherche, adresse).
class FieldBox extends StatelessWidget {
  const FieldBox({super.key, required this.children, this.height = 48, this.onTap, this.muted = true});
  final List<Widget> children;
  final double height;
  final VoidCallback? onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Box(
      color: c.fill,
      radius: kRadius,
      height: height,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: IconTheme.merge(
        data: IconThemeData(color: muted ? c.muted : c.ink),
        child: DefaultTextStyle.merge(
          style: TextStyle(fontSize: muted ? 15 : 14, color: muted ? c.muted : c.ink),
          child: Row(spacing: 10, children: children),
        ),
      ),
    );
  }
}

/// Icône dans un rond.
class Ic extends StatelessWidget {
  const Ic(this.icon, {super.key, this.size = 44, this.iconSize = 22, this.bg});
  final IconData icon;
  final double size;
  final double iconSize;
  final Color? bg;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bg ?? context.c.fill, shape: BoxShape.circle),
        child: Icon(icon, size: iconSize, color: bg == null ? context.c.ink : IfretColors.light.ink),
      );
}

/// Option sélectionnable (véhicule, date, type de problème).
class Opt extends StatelessWidget {
  const Opt({super.key, required this.selected, required this.onTap, required this.child, this.padding = const EdgeInsets.fromLTRB(10, 10, 14, 10), this.height});
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Box(
      radius: kRadius,
      height: height,
      color: selected ? c.primarySoft : null,
      border: selected ? BorderSide(color: c.ink, width: 1.5) : BorderSide(color: c.line, width: 1.5),
      padding: padding,
      onTap: onTap,
      selected: selected,
      child: child,
    );
  }
}

class Rad extends StatelessWidget {
  const Rad(this.selected, {super.key});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? c.primary : c.surface,
        border: Border.all(color: selected ? c.ink : c.lineStrong, width: 1.5),
      ),
      alignment: Alignment.center,
      child: AnimatedScale(
        scale: selected ? 1 : 0,
        duration: kFast,
        curve: kEase,
        child: Container(width: 8, height: 8, decoration: BoxDecoration(color: c.ink, shape: BoxShape.circle)),
      ),
    );
  }
}

// ───────────────────────── Listes ─────────────────────────

class Li extends StatelessWidget {
  const Li({super.key, this.icon, this.iconBg, required this.title, this.subtitle, this.trailing, this.onTap, this.padding = const EdgeInsets.symmetric(vertical: 9)});
  final IconData? icon;
  final Color? iconBg;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: padding,
      child: Row(
        spacing: 12,
        children: [
          if (icon != null) Ic(icon!, size: 40, iconSize: 20, bg: iconBg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ts.b),
                if (subtitle != null) Lab(subtitle!, maxLines: 1),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
    return onTap == null ? row : InkWell(onTap: onTap, borderRadius: BorderRadius.circular(kRadius), child: row);
  }
}

/// Montant et état, alignés à droite d'une ligne de liste.
class AmountState extends StatelessWidget {
  const AmountState(this.amount, this.state, {super.key, this.tone = Tone.neutral});
  final String amount;
  final String state;
  final Tone tone;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: 4,
        children: [Text(amount, style: Ts.num()), Tag(state, tone: tone, height: 22)],
      );
}

/// Groupe de lignes de réglage dans un cadre arrondi.
class Grp extends StatelessWidget {
  const Grp(this.children, {super.key});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Box(
        radius: kRadius,
        border: BorderSide(color: context.c.line, width: 1.5),
        child: Column(
          children: [
            for (final (i, w) in children.indexed) ...[if (i > 0) const Hr(), w],
          ],
        ),
      );
}

class SetRow extends StatelessWidget {
  const SetRow({
    super.key,
    this.icon,
    this.iconBg,
    this.leading,
    required this.title,
    this.subtitle,
    this.subtitle2,
    this.value,
    this.trailing,
    this.chevron = false,
    this.onTap,
    this.roomy = false,
    this.light = false,
    this.badge,
  });

  /// Pastille accolée au titre (« Par défaut »).
  final Widget? badge;
  final IconData? icon;
  final Color? iconBg;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final String? subtitle2;
  final String? value;
  final Widget? trailing;
  final bool chevron;
  final VoidCallback? onTap;

  /// Ligne plus haute, alignée en haut (notifications, conversations).
  final bool roomy;

  /// Titre en graisse moyenne (questions fréquentes).
  final bool light;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: roomy ? 12 : 8),
        child: Row(
          crossAxisAlignment: roomy && leading == null ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          spacing: 12,
          children: [
            if (leading != null) leading! else if (icon != null) Ic(icon!, size: 36, iconSize: 18, bg: iconBg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [Text(title, style: TextStyle(fontWeight: light ? FontWeight.w500 : FontWeight.w600)), ?badge],
                  ),
                  if (subtitle != null) Lab(subtitle!, maxLines: roomy && leading == null ? null : 1),
                  if (subtitle2 != null) Lab(subtitle2!, maxLines: 1),
                ],
              ),
            ),
            if (value != null) Text(value!, style: TextStyle(fontSize: 13, color: c.muted)),
            ?trailing,
            if (chevron) Icon(LucideIcons.chevronRight, size: 18, color: c.ink),
          ],
        ),
      ),
    );
    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }
}

/// Heure et point « non lu » à droite d'une notification.
class TimeDot extends StatelessWidget {
  const TimeDot(this.time, {super.key, this.unread = false, this.count});
  final String time;
  final bool unread;
  final int? count;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: 6,
        children: [
          Lab(time),
          if (count != null) Tag('$count', height: 20),
          if (unread)
            Semantics(
              label: 'Non lu',
              child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFD9480F), shape: BoxShape.circle)),
            ),
        ],
      );
}

class Sw extends StatelessWidget {
  const Sw({super.key, required this.value, required this.onChanged, required this.label});
  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      label: label,
      toggled: value,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 44,
            height: 26,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: value ? c.inverse : const Color(0xFFD9D5CB), borderRadius: BorderRadius.circular(kRadius)),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 150),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: value ? c.primary : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: const [BoxShadow(color: Color(0x401E1E1E), blurRadius: 3, offset: Offset(0, 1))],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Trois chiffres clés côte à côte.
class StatRow extends StatelessWidget {
  const StatRow(this.items, {super.key});
  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) => Row(
        spacing: 8,
        children: [
          for (final (value, label) in items)
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                decoration: BoxDecoration(color: context.c.fillSoft, borderRadius: BorderRadius.circular(kRadius)),
                child: Column(
                  children: [
                    Text(value, style: const TextStyle(fontSize: 18, height: 24 / 18, fontWeight: FontWeight.w700)),
                    Lab(label, align: TextAlign.center),
                  ],
                ),
              ),
            ),
        ],
      );
}

/// Grille de quatre raccourcis.
class QuickActions extends StatelessWidget {
  const QuickActions(this.items, {super.key});
  final List<(IconData, String, VoidCallback)> items;

  @override
  Widget build(BuildContext context) => Row(
        spacing: 8,
        children: [
          for (final (icon, label, onTap) in items)
            Expanded(
              child: Box(
                height: 72,
                radius: kRadius,
                border: BorderSide(color: context.c.line, width: 1.5),
                onTap: onTap,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 6,
                  children: [
                    Icon(icon, size: 22),
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
        ],
      );
}

// ───────────────────────── Progression et trajet ─────────────────────────

class ProgressBar extends StatelessWidget {
  const ProgressBar(this.value, {super.key, this.onYellow = false});
  final double value;
  final bool onYellow;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ClipRRect(
      borderRadius: BorderRadius.circular(kRadius),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 6,
        backgroundColor: onYellow ? const Color(0x2E1E1E1E) : c.track,
        color: c.inverse,
        borderRadius: BorderRadius.circular(kRadius),
      ),
    );
  }
}

/// Rail de suivi avec le camion, sur carte jaune.
class Track extends StatelessWidget {
  const Track(this.value, {super.key});
  final double value;

  @override
  Widget build(BuildContext context) {
    const black = Color(0xFF1E1E1E);
    return SizedBox(
      height: 28,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth - 6;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(left: 0, top: 12, width: w, height: 4, child: const DecoratedBox(decoration: BoxDecoration(color: Color(0x331E1E1E), borderRadius: BorderRadius.all(Radius.circular(kRadius))))),
              Positioned(left: 0, top: 12, width: w * value, height: 4, child: const DecoratedBox(decoration: BoxDecoration(color: black, borderRadius: BorderRadius.all(Radius.circular(kRadius))))),
              Positioned(
                left: w - 8,
                top: 7,
                child: Container(width: 14, height: 14, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: black, width: 3))),
              ),
              Positioned(
                left: w * value - 14,
                top: 0,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(color: black, shape: BoxShape.circle),
                  child: Icon(LucideIcons.truck, size: 16, color: IfretColors.light.primary),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class RouteDot extends StatelessWidget {
  const RouteDot({super.key, this.dropoff = false});
  final bool dropoff;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: 16,
      height: 16,
      decoration: dropoff
          ? BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(5), border: Border.all(color: c.ink, width: 1))
          : BoxDecoration(color: c.surface, shape: BoxShape.circle, border: Border.all(color: c.ink, width: 3)),
    );
  }
}

/// Chargement puis livraison, reliés par un pointillé.
class RoutePoints extends StatelessWidget {
  const RoutePoints({super.key, required this.fromLabel, required this.from, required this.toLabel, required this.to});
  final String fromLabel;
  final String from;
  final String toLabel;
  final String to;

  @override
  Widget build(BuildContext context) {
    Widget stop(bool dropoff, String label, String place) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Padding(padding: const EdgeInsets.only(top: 3), child: RouteDot(dropoff: dropoff)),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Lab(label), Text(place, style: Ts.b)]),
            ),
          ],
        );
    return Stack(
      children: [
        Positioned(left: 7, top: 22, bottom: 24, child: CustomPaint(painter: _DotsPainter(context.c.lineStrong))),
        Column(spacing: 14, children: [stop(false, fromLabel, from), stop(true, toLabel, to)]),
      ],
    );
  }
}

class _DotsPainter extends CustomPainter {
  const _DotsPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (double y = 1; y < size.height; y += 5) {
      canvas.drawCircle(Offset(1, y), 1, paint);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter oldDelegate) => oldDelegate.color != color;
}

/// Chiffre d'un code de livraison.
class Dig extends StatelessWidget {
  const Dig(this.char, {super.key, this.large = false, this.active = false});
  final String char;
  final bool large;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: large ? 64 : 40,
      height: large ? 76 : 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: large && !active ? c.fill : c.surface,
        borderRadius: BorderRadius.circular(kRadius),
        border: active ? Border.all(color: c.ink, width: 1.5) : (large ? null : Border.all(color: c.line, width: 1.5)),
      ),
      child: Text(char, style: TextStyle(fontSize: large ? 32 : 20, fontWeight: FontWeight.w700)),
    );
  }
}

enum CkState { done, number, now, todo }

/// Pastille d'étape : faite, numérotée, en cours ou à venir.
class Ck extends StatelessWidget {
  const Ck.done({super.key}) : state = CkState.done, number = null;
  const Ck.n(int this.number, {super.key}) : state = CkState.number;
  const Ck.now({super.key}) : state = CkState.now, number = null;
  const Ck.todo({super.key}) : state = CkState.todo, number = null;

  final CkState state;
  final int? number;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: switch (state) { CkState.done => c.primary, CkState.number => c.fill, _ => null },
        border: switch (state) {
          CkState.now => Border.all(color: c.ink, width: 1.5),
          CkState.todo => Border.all(color: c.lineStrong, width: 1.5),
          _ => null,
        },
      ),
      child: switch (state) {
        CkState.done => Icon(LucideIcons.check, size: 16, color: c.onPrimary),
        CkState.number => Text('$number', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        CkState.now => Loop(
            duration: const Duration(milliseconds: 1600),
            builder: (context, t, child) => Opacity(opacity: 1 - .65 * (1 - (2 * t - 1).abs()), child: child),
            child: Container(width: 10, height: 10, decoration: BoxDecoration(color: c.inverse, shape: BoxShape.circle)),
          ),
        CkState.todo => null,
      },
    );
  }
}

/// Étape d'une liste de vérification : pastille, titre, détail.
class CheckStep extends StatelessWidget {
  const CheckStep(this.mark, this.title, this.detail, {super.key, this.child});
  final Ck mark;
  final String title;
  final String detail;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          mark,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(title, style: Ts.b),
                Lab(detail),
                if (child != null) Padding(padding: const EdgeInsets.only(top: 6), child: child),
              ],
            ),
          ),
        ],
      );
}

// ───────────────────────── Messages ─────────────────────────

class Msg extends StatelessWidget {
  const Msg(this.text, this.meta, {super.key, this.me = false});
  final String text;
  final String meta;
  final bool me;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fg = me ? c.onPrimary : c.ink;
    const big = Radius.circular(kRadius), small = Radius.circular(6);
    return Align(
      alignment: me ? Alignment.centerRight : Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: .78,
        alignment: me ? Alignment.centerRight : Alignment.centerLeft,
        child: Align(
          alignment: me ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: me ? c.primary : c.fill,
              borderRadius: BorderRadius.only(topLeft: big, topRight: big, bottomLeft: me ? big : small, bottomRight: me ? small : big),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              spacing: 2,
              children: [
                Text(text, style: TextStyle(color: fg)),
                Text(meta, style: TextStyle(fontSize: 11, height: 14 / 11, color: fg.withValues(alpha: .75))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Événement de la course affiché au milieu de la conversation.
class Sys extends StatelessWidget {
  const Sys(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(kRadius), border: Border.all(color: context.c.line, width: 1.5)),
          child: Lab(text, align: TextAlign.center),
        ),
      );
}

// ───────────────────────── Mouvement ─────────────────────────

/// Animation en boucle. Figée si l'appareil demande moins d'animations.
class Loop extends StatefulWidget {
  const Loop({super.key, required this.duration, required this.builder, this.phase = 0, this.child});
  final Duration duration;
  final double phase;
  final Widget? child;
  final Widget Function(BuildContext context, double t, Widget? child) builder;

  @override
  State<Loop> createState() => _LoopState();
}

class _LoopState extends State<Loop> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: widget.duration);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    context.reduceMotion ? _controller.stop() : _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) => widget.builder(context, (_controller.value + widget.phase) % 1, child),
      );
}
