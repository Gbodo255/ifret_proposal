import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/store.dart';
import '../services/device.dart';
import '../theme/tokens.dart';
import 'ui.dart';

// Mouvement, chargement, réseau, photos et petites fenêtres de choix.

void toast(BuildContext context, String message) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(message)));

// ───────────── Mouvement ─────────────

/// Entrée d'un élément : il monte de quelques pixels en apparaissant.
/// [index] décale les éléments d'une même liste pour un effet de cascade.
class Appear extends StatelessWidget {
  const Appear({super.key, this.index = 0, required this.child});
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (context.reduceMotion) return child;
    // Cascade courte : au-delà du sixième élément, tout arrive ensemble pour ne pas faire attendre.
    final delay = (index.clamp(0, 6)) * 35;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + delay),
      curve: Interval(delay / (280 + delay), 1, curve: kEase),
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: child),
      ),
    );
  }
}

// ───────────── Chargement ─────────────

/// Bloc gris animé affiché à la place d'un contenu en cours de chargement.
class Skeleton extends StatelessWidget {
  const Skeleton({super.key, this.width, this.height = 16});
  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) => Loop(
        duration: const Duration(milliseconds: 1200),
        builder: (context, t, _) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Color.lerp(context.c.fill, context.c.track, 1 - (2 * t - 1).abs()),
            borderRadius: BorderRadius.circular(kRadius),
          ),
        ),
      );
}

/// Liste factice pendant le premier chargement d'un écran de données.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.rows = 4});
  final int rows;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Chargement',
        child: Column(
          spacing: 14,
          children: [
            const Skeleton(height: 112),
            for (var i = 0; i < rows; i++)
              const Row(
                spacing: 12,
                children: [
                  Skeleton(width: 40, height: 40),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 6, children: [Skeleton(width: 160, height: 14), Skeleton(width: 220, height: 12)]),
                  ),
                ],
              ),
          ],
        ),
      );
}

/// Affiche [SkeletonList] un court instant à la première ouverture, puis le contenu en fondu.
// shortcut: délai fixe de démonstration, à remplacer par l'attente réelle de la réponse du serveur.
class Loaded extends StatefulWidget {
  const Loaded({super.key, required this.builder});
  final WidgetBuilder builder;

  @override
  State<Loaded> createState() => _LoadedState();
}

class _LoadedState extends State<Loaded> {
  bool _ready = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 420), () => setState(() => _ready = true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: kMedium,
        switchInCurve: kEase,
        layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
        child: _ready ? KeyedSubtree(key: const ValueKey('content'), child: widget.builder(context)) : const SkeletonList(),
      );
}

/// Bouton dont l'action passe par le serveur : il montre l'attente et bloque le double appui.
class AsyncCta extends StatefulWidget {
  const AsyncCta(this.text, {super.key, required this.action, this.tone = CtaTone.primary, this.icon, this.enabled = true, this.validate});

  /// Vérifie le formulaire avant l'envoi. Faux : rien n'est envoyé, les erreurs restent affichées.
  final bool Function()? validate;
  final String text;
  final FutureOr<void> Function() action;
  final CtaTone tone;
  final IconData? icon;
  final bool enabled;

  @override
  State<AsyncCta> createState() => _AsyncCtaState();
}

class _AsyncCtaState extends State<AsyncCta> {
  bool _busy = false;

  Future<void> _run() async {
    if (widget.validate?.call() == false) return;
    setState(() => _busy = true);
    await Future<void>.delayed(kServerDelay);
    if (!mounted) return;
    setState(() => _busy = false);
    await widget.action();
  }

  @override
  Widget build(BuildContext context) => Cta(widget.text, tone: widget.tone, icon: widget.icon, busy: _busy, onTap: widget.enabled ? _run : null);
}

// ───────────── Réseau ─────────────

/// Bandeau en haut de l'application quand la connexion est faible ou absente.
class NetBanner extends StatelessWidget {
  const NetBanner({super.key, required this.net, required this.child});
  final NetMonitor net;
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
        valueListenable: net,
        child: child,
        builder: (context, state, child) {
          final c = context.c;
          final offline = state == NetState.offline;
          return Column(
            children: [
              AnimatedSize(
                duration: kMedium,
                curve: kEase,
                alignment: Alignment.topCenter,
                child: state == NetState.online
                    ? const SizedBox(width: double.infinity)
                    : Material(
                        color: offline ? c.inverse : c.warningSoft,
                        child: SafeArea(
                          bottom: false,
                          child: Semantics(
                            liveRegion: true,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Row(
                                spacing: 10,
                                children: [
                                  Icon(offline ? LucideIcons.wifiOff : LucideIcons.signalLow, size: 18, color: offline ? c.onInverse : c.warning),
                                  Expanded(
                                    child: Text(
                                      offline ? 'Hors connexion. Tes données s’enverront au retour du réseau.' : 'Connexion faible. Le chargement peut être plus lent.',
                                      style: Ts.small.copyWith(fontWeight: FontWeight.w600, color: offline ? c.onInverse : c.warning),
                                    ),
                                  ),
                                  if (offline)
                                    TextButton(
                                      onPressed: net.check,
                                      style: TextButton.styleFrom(foregroundColor: c.primary, minimumSize: const Size(48, 36), padding: const EdgeInsets.symmetric(horizontal: 8)),
                                      child: const Text('Réessayer'),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
              // Le bandeau occupe déjà la zone de l'encoche : l'écran dessous n'a plus à la réserver.
              Expanded(child: state == NetState.online ? child! : MediaQuery.removePadding(context: context, removeTop: true, child: child!)),
            ],
          );
        },
      );
}

// ───────────── Photos ─────────────

/// Photos prises et bouton d'ajout. Appui sur une photo : agrandissement et suppression.
class PhotoStrip extends StatelessWidget {
  const PhotoStrip(this.photos, {super.key, this.max = 6, this.onChanged});
  final List<String> photos;
  final int max;

  /// Appelé après un ajout ou une suppression. Nul : photos en lecture seule.
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (i, path) in photos.indexed)
          Box(
            width: 64,
            height: 64,
            radius: kRadius,
            color: c.fill,
            label: 'Photo ${i + 1}',
            onTap: () => _open(context, i),
            child: photoImage(path),
          ),
        if (onChanged != null && photos.length < max)
          Box(
            width: 64,
            height: 64,
            radius: kRadius,
            border: BorderSide(color: c.lineStrong, width: 1.5),
            label: 'Ajouter une photo',
            onTap: () async {
              final path = await pickPhoto(context);
              if (path == null) return;
              photos.add(path);
              onChanged!();
            },
            child: const Icon(LucideIcons.camera),
          ),
      ],
    );
  }

  void _open(BuildContext context, int index) => showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(aspectRatio: 1, child: ColoredBox(color: context.c.fill, child: photoImage(photos[index], fit: BoxFit.contain))),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  spacing: 8,
                  children: [
                    if (onChanged != null)
                      Expanded(
                        child: Cta(
                          'Supprimer',
                          tone: CtaTone.outline,
                          icon: LucideIcons.trash2,
                          height: 44,
                          fontSize: 14,
                          onTap: () {
                            photos.removeAt(index);
                            onChanged!();
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    Expanded(child: Cta('Fermer', tone: CtaTone.dark, height: 44, fontSize: 14, onTap: () => Navigator.pop(context))),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

// ───────────── Choix et confirmations ─────────────

/// Feuille basse à choix unique. Renvoie l'option choisie, ou nul si la feuille est fermée.
Future<T?> pickOption<T>(BuildContext context, {required String title, required Map<T, String> options, T? selected, String? note}) => showModalBottomSheet<T>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(title, style: Ts.h2)),
              for (final MapEntry(key: value, value: label) in options.entries)
                Opt(
                  selected: value == selected,
                  onTap: () => Navigator.pop(context, value),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(children: [Expanded(child: Text(label, style: Ts.b)), Rad(value == selected)]),
                ),
              if (note != null) Padding(padding: const EdgeInsets.only(top: 4), child: Lab(note)),
            ],
          ),
        ),
      ),
    );

/// Demande de confirmation avant une action qu'on ne peut pas défaire.
Future<bool> confirm(BuildContext context, {required String title, required String text, required String action, bool danger = false}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title, style: Ts.h2),
      content: Text(text),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Row(
          spacing: 8,
          children: [
            Expanded(child: Cta('Annuler', tone: CtaTone.outline, height: 46, fontSize: 14, onTap: () => Navigator.pop(context, false))),
            Expanded(child: Cta(action, tone: danger ? CtaTone.dark : CtaTone.primary, height: 46, fontSize: 14, onTap: () => Navigator.pop(context, true))),
          ],
        ),
      ],
    ),
  );
  return ok ?? false;
}

// ───────────── Recherche et états vides ─────────────

/// Champ de recherche gris : filtre la liste affichée dessous à chaque frappe.
class SearchBox extends StatelessWidget {
  const SearchBox(this.hint, {super.key, required this.onChanged});
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: c.fill, borderRadius: BorderRadius.circular(kRadius)),
      child: Row(
        spacing: 10,
        children: [
          Icon(LucideIcons.search, color: c.muted),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: TextStyle(fontSize: 15, color: c.ink),
              decoration: InputDecoration.collapsed(hintText: hint, hintStyle: TextStyle(color: c.muted)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Message affiché quand une liste n'a rien à montrer.
class EmptyCard extends StatelessWidget {
  const EmptyCard(this.icon, this.title, this.text, {super.key});
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => AppCard(
        tone: CardTone.soft,
        child: Row(
          spacing: 12,
          children: [
            Ic(icon, bg: Colors.white),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Ts.b), Lab(text)])),
          ],
        ),
      );
}
