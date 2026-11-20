import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/store.dart';
import '../../routes.dart';
import '../../theme/tokens.dart';
import '../../widgets/brand.dart';
import '../../widgets/extras.dart';
import '../../widgets/layout.dart';
import '../../widgets/ui.dart';
import '../shared.dart';

/// Écran de la mission en cours, selon son avancement.
String missionRoute(MissionStep step) => switch (step) {
      MissionStep.loading => R.tChargement,
      MissionStep.arrived => R.tArrivee,
      MissionStep.paid => R.tLivraison,
      _ => R.tMission,
    };

bool _inProgress(MissionStep step) => step == MissionStep.loading || step == MissionStep.arrived || step == MissionStep.paid;

/// Coque du transporteur : Accueil, Missions, bouton de disponibilité, Gains, Profil.
class TransporteurShell extends StatefulWidget {
  const TransporteurShell({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<TransporteurShell> createState() => _TransporteurShellState();
}

class _TransporteurShellState extends State<TransporteurShell> {
  late int _tab = widget.initialTab;

  void _go(int tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) {
    final store = context.store..role = Role.transporteur;
    void toggle() {
      store.update(() => store.online = !store.online);
      toast(context, store.online ? 'Tu es en ligne : les missions proches arrivent ici.' : 'Tu es hors ligne : tu ne reçois plus de mission.');
    }

    return RoleShell(
      index: _tab,
      onIndex: _go,
      items: const [(LucideIcons.house, 'Accueil'), (LucideIcons.truck, 'Missions'), (LucideIcons.wallet, 'Gains'), (LucideIcons.user, 'Profil')],
      centerIcon: LucideIcons.power,
      centerLabel: store.online ? 'Disponibilité : en ligne' : 'Disponibilité : hors ligne',
      centerOn: store.online,
      onCenter: toggle,
      pages: [
        _Accueil(onToggle: toggle, onTab: _go),
        const _Missions(),
        _Gains(onSeeAll: () => _go(1)),
        const ProfilTab(Role.transporteur),
      ],
    );
  }
}

/// Carte jaune de la mission en cours.
class _ActiveMission extends StatelessWidget {
  const _ActiveMission();

  @override
  Widget build(BuildContext context) {
    final step = context.store.mission;
    final arrived = step != MissionStep.loading;
    return AppCard(
      tone: CardTone.yellow,
      onTap: () => context.go(missionRoute(step)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Tag(switch (step) { MissionStep.loading => 'Chargement', MissionStep.arrived => 'En attente du solde', _ => 'À livrer' }, tone: Tone.dark),
              const Text('IFR-2611-0042', style: Ts.small),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mission en cours', style: Ts.small),
                    Text('Cotonou → Parakou', style: TextStyle(fontSize: 20, height: 26 / 20, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [const Text('Rémunération', style: Ts.lab), Text('96 000', style: Ts.num(18))]),
            ],
          ),
          Track(arrived ? 1 : .08),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            children: [
              const Text('Matériaux · 8,6 t · 120 colis', style: Ts.small),
              Text(arrived ? 'Arrivé à 16:38' : 'Départ du port', style: Ts.small.merge(Ts.b)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Accueil extends StatelessWidget {
  const _Accueil({required this.onToggle, required this.onTab});
  final VoidCallback onToggle;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final online = store.online;
    final step = store.mission;
    final unread = store.unreadNotifs(Role.transporteur);
    final week = step == MissionStep.delivered ? 310000 : 214000;
    return ScreenBody(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      top: SizedBox(
        height: 60,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            spacing: 10,
            children: [
              Avatar(store.transporteur.name, size: 32, verified: true),
              Expanded(child: Text(store.transporteur.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
              Semantics(
                toggled: online,
                child: Tag(online ? 'En ligne' : 'Hors ligne', tone: online ? Tone.success : Tone.neutral, led: true, height: 36, onTap: onToggle),
              ),
              IconBtn(LucideIcons.bell, label: unread > 0 ? 'Notifications, $unread nouvelles' : 'Notifications', tone: IbTone.outline, dot: unread > 0, onTap: () => context.go(R.tNotifications)),
            ],
          ),
        ),
      ),
      children: [
        AppCard(
          tone: CardTone.yellow,
          onTap: () => onTab(2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 6,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Gagné cette semaine', style: Ts.small),
                  ExcludeSemantics(child: IconBtn(LucideIcons.arrowRight, label: '', tone: IbTone.dark, size: 36, iconSize: 18)),
                ],
              ),
              Amount(formatNumber(week), size: 34),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Chip2(step == MissionStep.delivered ? '4 courses' : '3 courses', icon: LucideIcons.truck),
                    const Chip2('4,8 sur 5', icon: LucideIcons.star),
                    Chip2(step == MissionStep.delivered ? '1 655 km' : '1 240 km', icon: LucideIcons.route),
                  ],
                ),
              ),
            ],
          ),
        ),
        QuickActions([
          (LucideIcons.route, 'Missions', () => onTab(1)),
          (LucideIcons.coins, 'Gains', () => onTab(2)),
          (LucideIcons.fileText, 'Dossier', () => context.go(R.tDossier, args: true)),
          (LucideIcons.headset, 'Aide', () => context.go(R.tAide)),
        ]),
        if (_inProgress(step))
          const _ActiveMission()
        else if (!online)
          const EmptyCard(LucideIcons.power, 'Tu es hors ligne', 'Passe en ligne pour recevoir des missions près de toi.')
        else if (step != MissionStep.offered)
          const EmptyCard(LucideIcons.route, 'Aucune mission pour l’instant', 'On te prévient dès qu’une mission arrive près de toi.')
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: [
              const SectionHeader('Nouvelle mission', trailing: Tag('Expire dans 0:45', tone: Tone.warning, icon: LucideIcons.timer)),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 14,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [const Lab('Ta rémunération'), Text('88 000 FCFA', style: Ts.num(24).copyWith(height: 30 / 24))],
                          ),
                        ),
                        const Tag('À 3,2 km', tone: Tone.neutral),
                      ],
                    ),
                    const RoutePoints(
                      fromLabel: 'Chargement · aujourd’hui, 09:00',
                      from: 'Port autonome de Cotonou',
                      toLabel: 'Livraison · 415 km · matériaux, 8 t',
                      to: 'Marché Arzèkè, Parakou',
                    ),
                    Row(
                      spacing: 8,
                      children: [
                        Expanded(child: Cta('Refuser', tone: CtaTone.outline, height: 46, onTap: () => store.update(() => store.mission = MissionStep.declined))),
                        Expanded(flex: 2, child: Cta('Voir la mission', height: 46, onTap: () => context.go(R.tMission))),
                      ],
                    ),
                  ],
                ),
              ),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Lab('Le premier transporteur qui accepte prend la mission.')),
            ],
          ),
      ],
    );
  }
}

/// Détail d'une mission terminée, en feuille basse.
void _showPayout(BuildContext context, Payout p) => showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              Text(p.route, style: Ts.h2),
              Kv('Mission', p.detail),
              Kv('Rémunération', money(p.amount)),
              Kv('Versement', p.state),
              const Hr(),
              const Lab('Les versements arrivent sur ton compte Mobile Money sous 24 h après la livraison.'),
              Cta('Fermer', tone: CtaTone.dark, height: 46, onTap: () => Navigator.pop(context)),
            ],
          ),
        ),
      ),
    );

class _Missions extends StatefulWidget {
  const _Missions();

  @override
  State<_Missions> createState() => _MissionsState();
}

class _MissionsState extends State<_Missions> {
  int _filter = 0;
  bool _byAmount = false;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final active = _inProgress(store.mission);
    final done = [...store.payouts, const Payout('Sèmè → Cotonou', '5 nov. · annulée par le chargeur', 5000, 'Dédommagé')];
    if (_byAmount) done.sort((a, b) => b.amount.compareTo(a.amount));
    // 38 missions plus anciennes ne sont pas détaillées dans la démonstration.
    final labels = ['Toutes · ${done.length + 38 + (active ? 1 : 0)}', 'En cours · ${active ? 1 : 0}', 'Terminées · ${done.length + 38}'];
    return ScreenBody(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      top: TabHeader(
        'Mes missions',
        trailing: IconBtn(
          LucideIcons.slidersHorizontal,
          label: 'Trier',
          tone: IbTone.outline,
          onTap: () async {
            final choice = await pickOption(context, title: 'Trier les missions terminées', options: const {false: 'Les plus récentes d’abord', true: 'Les mieux payées d’abord'}, selected: _byAmount);
            if (choice != null) setState(() => _byAmount = choice);
          },
        ),
      ),
      children: [
        PillWrap(options: labels, isOn: (l) => labels.indexOf(l) == _filter, onPick: (l) => setState(() => _filter = labels.indexOf(l))),
        Loaded(
          builder: (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14,
            children: [
              if (_filter != 2 && active) const _ActiveMission(),
              if (_filter == 1 && !active) const EmptyCard(LucideIcons.truck, 'Aucune mission en cours', 'Accepte une mission depuis l’accueil pour la voir ici.'),
              if (_filter != 1)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(padding: const EdgeInsets.only(bottom: 2), child: Semantics(header: true, child: const Text('Terminées', style: Ts.h2))),
                    for (final p in done)
                      Li(
                        icon: LucideIcons.truck,
                        title: p.route,
                        subtitle: p.detail,
                        trailing: AmountState(formatNumber(p.amount), p.state, tone: switch (p.state) { 'Versé' => Tone.success, 'En cours' => Tone.primary, _ => Tone.neutral }),
                        onTap: () => _showPayout(context, p),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Gains extends StatefulWidget {
  const _Gains({required this.onSeeAll});
  final VoidCallback onSeeAll;

  @override
  State<_Gains> createState() => _GainsState();
}

class _GainsState extends State<_Gains> {
  DateTimeRange? _range;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final delivered = store.mission == MissionStep.delivered;
    final l10n = MaterialLocalizations.of(context);
    // Gains par jour de la semaine, en milliers de francs. Le dimanche est celui de la mission du jour.
    final week = [('L', 30), ('M', 62), ('M', 0), ('J', 38), ('V', 0), ('S', 84), ('D', delivered ? 96 : 0)];
    return ScreenBody(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      top: TabHeader(
        'Mes gains',
        trailing: Tag(
          _range == null ? '10 – 16 nov.' : '${l10n.formatShortMonthDay(_range!.start)} – ${l10n.formatShortMonthDay(_range!.end)}',
          tone: Tone.outline,
          icon: LucideIcons.calendar,
          height: 36,
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDateRangePicker(context: context, firstDate: DateTime(now.year - 1), lastDate: now, initialDateRange: _range, helpText: 'Période des gains');
            if (picked != null) setState(() => _range = picked);
          },
        ),
      ),
      children: [
        AppCard(
          tone: CardTone.yellow,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Text(_range == null ? 'Gagné cette semaine' : 'Gagné sur la période', style: Ts.small),
              Amount(formatNumber(delivered ? 310000 : 214000)),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Semantics(
                  label: 'Gains par jour, du lundi au dimanche',
                  child: ExcludeSemantics(
                    child: SizedBox(
                      height: 76,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        spacing: 8,
                        children: [
                          for (final (i, (day, height)) in week.indexed)
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                spacing: 4,
                                children: [
                                  // Les barres montent à l'ouverture de l'écran.
                                  TweenAnimationBuilder<double>(
                                    tween: Tween(begin: context.reduceMotion ? 1 : 0, end: 1),
                                    duration: Duration(milliseconds: 420 + i * 50),
                                    curve: kEase,
                                    builder: (context, t, _) => Container(
                                      width: 28,
                                      height: height < 8 ? 4 : height * .5 * t + 4 * (1 - t),
                                      decoration: BoxDecoration(color: i == 6 ? const Color(0xFF1E1E1E) : const Color(0x381E1E1E), borderRadius: BorderRadius.circular(6)),
                                    ),
                                  ),
                                  Text(day, style: const TextStyle(fontSize: 11, height: 14 / 11, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (delivered)
          AppCard(
            tone: CardTone.soft,
            child: Row(
              spacing: 12,
              children: [
                const Ck.done(),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Text('Course terminée', style: Ts.b), Lab('Cotonou → Parakou · 88 000 + 8 000 de surpoids')],
                  ),
                ),
                Text('+ 96 000', style: Ts.num(17)),
              ],
            ),
          ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader('Versements', trailing: Tag('Tout voir', tone: Tone.outline, trailing: LucideIcons.chevronRight, onTap: widget.onSeeAll)),
            for (final p in store.payouts.take(4))
              Li(
                icon: LucideIcons.banknote,
                title: p.route,
                subtitle: p.detail,
                trailing: AmountState(formatNumber(p.amount), p.state, tone: p.state == 'Versé' ? Tone.success : Tone.primary),
                onTap: () => _showPayout(context, p),
              ),
          ],
        ),
      ],
    );
  }
}
