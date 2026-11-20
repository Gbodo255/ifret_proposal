import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/store.dart';
import '../../routes.dart';
import '../../theme/tokens.dart';
import '../../widgets/brand.dart';
import '../../widgets/extras.dart';
import '../../widgets/layout.dart';
import '../../widgets/ui.dart';
import '../chat.dart';
import '../shared.dart';

/// Ouvre une nouvelle demande, éventuellement avec un véhicule déjà choisi.
void startRequest(BuildContext context, {Vehicle? vehicle}) {
  final store = context.store..newDraft();
  if (vehicle != null) store.update(() => store.draft.vehicle = vehicle);
  context.go(R.cTrajet);
}

/// Ouvre l'écran qui correspond à l'état d'une course.
void openCourse(BuildContext context, Course course) => context.go(
      switch (course.status) {
        CourseStatus.searching => R.cRecherche,
        CourseStatus.enRoute => R.cSuivi,
        CourseStatus.arrived => R.cSolde,
        _ => R.cRecu,
      },
      args: course.ref,
    );

/// Part du trajet parcourue, pour les barres de progression.
double courseProgress(Course c) => switch (c.status) { CourseStatus.searching => 0, CourseStatus.enRoute => .49, _ => 1 };

Tone statusTone(CourseStatus s) => switch (s) { CourseStatus.delivered => Tone.neutral, CourseStatus.cancelled => Tone.warning, _ => Tone.primary };

/// Coque du chargeur : Accueil, Courses, bouton « nouvelle demande », Messages, Profil.
class ChargeurShell extends StatefulWidget {
  const ChargeurShell({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<ChargeurShell> createState() => _ChargeurShellState();
}

class _ChargeurShellState extends State<ChargeurShell> {
  late int _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    context.store.role = Role.chargeur;
    return RoleShell(
      index: _tab,
      onIndex: (i) => setState(() => _tab = i),
      items: const [(LucideIcons.house, 'Accueil'), (LucideIcons.listOrdered, 'Courses'), (LucideIcons.messageCircle, 'Messages'), (LucideIcons.user, 'Profil')],
      centerIcon: LucideIcons.plus,
      centerLabel: 'Nouvelle demande',
      onCenter: () => startRequest(context),
      pages: [
        _Accueil(onSeeAll: () => setState(() => _tab = 1)),
        const _Courses(),
        const _Messages(),
        const ProfilTab(Role.chargeur),
      ],
    );
  }
}

/// Carte jaune d'une course en cours, avec sa progression.
class ActiveCourseCard extends StatelessWidget {
  const ActiveCourseCard(this.course, {super.key});
  final Course course;

  @override
  Widget build(BuildContext context) {
    final searching = course.status == CourseStatus.searching;
    return AppCard(
      tone: CardTone.yellow,
      onTap: () => openCourse(context, course),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Tag(course.status.label, tone: Tone.dark), Text(course.ref, style: Ts.small)]),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(searching ? 'Recherche d’un transporteur' : 'Course en cours', style: Ts.small),
                    Text(course.route, style: const TextStyle(fontSize: 20, height: 26 / 20, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const ExcludeSemantics(child: IconBtn(LucideIcons.arrowRight, label: '', tone: IbTone.dark, size: 36, iconSize: 18)),
            ],
          ),
          Track(courseProgress(course)),
          // Wrap : sur petit téléphone, la seconde information passe à la ligne au lieu de déborder.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            children: [
              Text(searching ? '${course.km} km à parcourir' : '${(course.km * courseProgress(course)).round()} km parcourus', style: Ts.small),
              Text.rich(
                TextSpan(
                  text: switch (course.status) { CourseStatus.searching => 'Acompte payé · ', CourseStatus.arrived => 'Solde à payer · ', _ => 'Arrivée prévue à ' },
                  children: [
                    TextSpan(
                      text: switch (course.status) { CourseStatus.searching => money(course.deposit), CourseStatus.arrived => money(course.balance), _ => '16:40' },
                      style: Ts.b,
                    ),
                  ],
                ),
                style: Ts.small,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Accueil extends StatelessWidget {
  const _Accueil({required this.onSeeAll});
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final store = context.store;
    final active = store.activeCourse;
    final unread = store.unreadNotifs(Role.chargeur);
    return ScreenBody(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      top: SizedBox(
        height: 60,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            spacing: 10,
            children: [
              Avatar(store.chargeur.name, size: 32),
              Expanded(
                child: Text('Bonjour, ${store.chargeur.firstName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              IconBtn(LucideIcons.receipt, label: 'Dernier reçu', tone: IbTone.outline, onTap: () => context.go(R.cRecu)),
              IconBtn(
                LucideIcons.bell,
                label: unread > 0 ? 'Notifications, $unread nouvelles' : 'Notifications',
                tone: IbTone.outline,
                dot: unread > 0,
                onTap: () => context.go(R.cNotifications),
              ),
            ],
          ),
        ),
      ),
      children: [
        FieldBox(
          onTap: () => startRequest(context),
          children: const [Icon(LucideIcons.search), Expanded(child: Text('Où livrer ta marchandise ?')), Icon(LucideIcons.mapPinned)],
        ),
        if (active != null)
          ActiveCourseCard(active)
        else
          AppCard(
            tone: CardTone.yellow,
            onTap: () => startRequest(context),
            child: const Row(
              spacing: 12,
              children: [
                Ic(LucideIcons.package, bg: Colors.white),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Text('Aucune course en cours', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)), Text('Décris ta marchandise pour trouver un transporteur.', style: Ts.small)],
                  ),
                ),
                Icon(LucideIcons.arrowRight),
              ],
            ),
          ),
        QuickActions([
          (LucideIcons.coins, 'Prix', () => startRequest(context)),
          (LucideIcons.locateFixed, 'Suivi', () => active == null ? toast(context, 'Aucune course à suivre pour l’instant.') : openCourse(context, active)),
          (LucideIcons.mapPin, 'Adresses', () => context.go(R.cAdresses)),
          (LucideIcons.headset, 'Aide', () => context.go(R.cAide)),
        ]),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 10,
          children: [
            Semantics(header: true, child: const Text('Envoyer avec', style: Ts.h2)),
            Row(
              spacing: 8,
              children: [
                for (final v in Vehicle.values)
                  Expanded(
                    child: InkWell(
                      onTap: () => startRequest(context, vehicle: v),
                      borderRadius: BorderRadius.circular(kRadius),
                      child: Column(
                        spacing: 4,
                        children: [
                          Container(
                            height: 60,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(kRadius), border: Border.all(color: c.line, width: 1.5)),
                            child: Image.asset(v.asset, fit: BoxFit.contain, excludeFromSemantics: true),
                          ),
                          Text(v.short, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader('Dernières courses', trailing: Tag('Tout voir', tone: Tone.outline, trailing: LucideIcons.chevronRight, onTap: onSeeAll)),
            for (final course in store.courses.take(2))
              Li(
                icon: LucideIcons.package,
                title: course.ref,
                subtitle: '${course.route} · ${course.date}',
                trailing: Tag(course.status.label, tone: statusTone(course.status)),
                onTap: () => openCourse(context, course),
              ),
          ],
        ),
      ],
    );
  }
}

class _Courses extends StatefulWidget {
  const _Courses();

  @override
  State<_Courses> createState() => _CoursesState();
}

class _CoursesState extends State<_Courses> {
  /// 0 : toutes, 1 : en cours, 2 : terminées.
  int _filter = 0;
  bool _byAmount = false;

  @override
  Widget build(BuildContext context) {
    final courses = context.store.courses;
    final active = courses.where((c) => c.status.active).toList();
    final done = courses.where((c) => !c.status.active).toList();
    if (_byAmount) done.sort((a, b) => b.total.compareTo(a.total));
    final labels = ['Toutes · ${courses.length}', 'En cours · ${active.length}', 'Terminées · ${done.length}'];
    return ScreenBody(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      top: TabHeader(
        'Mes courses',
        trailing: IconBtn(
          LucideIcons.slidersHorizontal,
          label: 'Trier',
          tone: IbTone.outline,
          onTap: () async {
            final choice = await pickOption(context, title: 'Trier les courses terminées', options: const {false: 'Les plus récentes d’abord', true: 'Les plus chères d’abord'}, selected: _byAmount);
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
              if (_filter != 2) for (final course in active) ActiveCourseCard(course),
              if (_filter == 1 && active.isEmpty) const EmptyCard(LucideIcons.package, 'Aucune course en cours', 'Tes demandes apparaissent ici dès l’acompte payé.'),
              if (_filter != 1 && done.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(padding: const EdgeInsets.only(bottom: 2), child: Semantics(header: true, child: const Text('Terminées', style: Ts.h2))),
                    for (final course in done)
                      Li(
                        icon: LucideIcons.package,
                        title: course.route,
                        subtitle: '${course.ref} · ${course.date}',
                        trailing: AmountState(course.status == CourseStatus.cancelled ? '—' : formatNumber(course.total), course.status.label, tone: statusTone(course.status)),
                        onTap: () => openCourse(context, course),
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

class _Messages extends StatefulWidget {
  const _Messages();

  @override
  State<_Messages> createState() => _MessagesState();
}

class _MessagesState extends State<_Messages> {
  String _query = '';

  @override
  Widget build(BuildContext context) => ScreenBody(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        top: TabHeader('Messages', trailing: IconBtn(LucideIcons.headset, label: 'Assistance ILT', tone: IbTone.outline, onTap: () => context.go(R.cAide))),
        children: [
          SearchBox('Chercher une conversation', onChanged: (q) => setState(() => _query = q)),
          Loaded(builder: (context) => ConversationList(Role.chargeur, query: _query)),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Lab('Une conversation s’ouvre avec le transporteur dès qu’il accepte ta demande.')),
        ],
      );
}
