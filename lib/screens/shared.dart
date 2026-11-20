import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/store.dart';
import '../routes.dart';
import '../services/device.dart';
import '../theme/tokens.dart';
import '../widgets/brand.dart';
import '../widgets/extras.dart';
import '../widgets/forms.dart';
import '../widgets/layout.dart';
import '../widgets/ui.dart';

// Écrans identiques pour les deux rôles, au contenu près : profil, compte, paramètres,
// notifications, aide, signalement et notation.

extension on Role {
  bool get isChargeur => this == Role.chargeur;
}

/// Onglet Profil.
class ProfilTab extends StatelessWidget {
  const ProfilTab(this.role, {super.key});
  final Role role;

  @override
  Widget build(BuildContext context) {
    final c = role.isChargeur;
    final store = context.store;
    final me = store.profileOf(role);
    final account = store.accountOf(role);
    final wallet = '${mobileMoney[account.operator]} · ${formatPhone(account.phone)}';
    final delivered = store.courses.where((x) => x.status == CourseStatus.delivered).length;
    Widget row(IconData icon, String title, String? subtitle, String route, {Object? args}) =>
        SetRow(icon: icon, title: title, subtitle: subtitle, chevron: true, onTap: () => context.go(route, args: args ?? role));
    return ScreenBody(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      top: TabHeader(
        'Profil',
        trailing: IconBtn(LucideIcons.settings, label: 'Paramètres', tone: IbTone.outline, onTap: () => context.go(c ? R.cParametres : R.tParametres)),
      ),
      children: [
        AppCard(
          tone: CardTone.yellow,
          onTap: () => context.go(R.infos, args: role),
          child: Row(
            spacing: 12,
            children: [
              Avatar(me.name, size: 72, verified: !c),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(me.name, style: const TextStyle(fontSize: 18, height: 24 / 18, fontWeight: FontWeight.w600)),
                    Text('+229 ${formatPhone(me.phone)}', style: Ts.small),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: c ? const Chip2('Compte chargeur') : const Chip2('Vérifié par ILT', icon: LucideIcons.badgeCheck),
                    ),
                  ],
                ),
              ),
              const ExcludeSemantics(child: IconBtn(LucideIcons.pencil, label: '', tone: IbTone.dark, size: 36, iconSize: 16)),
            ],
          ),
        ),
        StatRow(c ? [('${store.courses.length}', 'courses'), ('$delivered', 'livrées'), ('4,9', 'note reçue')] : const [('42', 'courses'), ('4,8', 'note'), ('98 %', 'à l’heure')]),
        Grp(
          c
              ? [
                  row(LucideIcons.user, 'Informations personnelles', 'Nom, téléphone, entreprise', R.infos),
                  row(LucideIcons.mapPin, 'Adresses enregistrées', '${store.addresses.length} adresses', R.cAdresses),
                  row(LucideIcons.smartphone, 'Moyens de paiement', wallet, R.comptes),
                  row(LucideIcons.receipt, 'Reçus et factures', null, R.c, args: 1),
                ]
              : [
                  row(LucideIcons.user, 'Informations personnelles', 'Nom, téléphone', R.infos),
                  row(LucideIcons.truck, 'Mon véhicule', '${store.vehicle.name} · ${store.plate}', R.tVehicule, args: true),
                  row(LucideIcons.fileText, 'Mes documents', '${store.documents.length} pièces sur 5', R.tDossier, args: true),
                  row(LucideIcons.wallet, 'Compte de versement', wallet, R.comptes),
                ],
        ),
        Grp([
          row(LucideIcons.bell, 'Notifications', null, c ? R.cNotifications : R.tNotifications),
          row(LucideIcons.settings, 'Paramètres', null, c ? R.cParametres : R.tParametres),
          row(LucideIcons.headset, 'Aide et assistance ILT', null, c ? R.cAide : R.tAide),
        ]),
        LinkBtn(
          'Se déconnecter',
          icon: LucideIcons.logOut,
          color: context.c.danger,
          onTap: () async {
            if (await confirm(context, title: 'Se déconnecter ?', text: 'Tu devras ressaisir ton numéro pour revenir.', action: 'Me déconnecter') && context.mounted) context.reset(R.compte);
          },
        ),
      ],
    );
  }
}

/// Informations personnelles : nom, téléphone, entreprise, e-mail.
class InfosScreen extends StatefulWidget {
  const InfosScreen(this.role, {super.key});
  final Role role;

  @override
  State<InfosScreen> createState() => _InfosScreenState();
}

class _InfosScreenState extends State<InfosScreen> {
  String? _name, _phone, _company, _email;
  bool _tried = false;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final me = store.profileOf(widget.role);
    final name = _name ?? me.name, phone = _phone ?? me.phone, email = _email ?? me.email;
    final nameError = requiredError(name, 'Indique ton prénom et ton nom.');
    return Screen(
      top: const TopBar('Informations personnelles'),
      gap: 16,
      foot: [
        AsyncCta(
          'Enregistrer',
          validate: () {
            setState(() => _tried = true);
            return nameError == null && phoneError(phone) == null && emailError(email) == null;
          },
          action: () {
            store.update(() {
              me
                ..name = name.trim()
                ..phone = phone
                ..email = email.trim()
                ..company = (_company ?? me.company).trim();
            });
            toast(context, 'Informations enregistrées');
            Navigator.pop(context);
          },
        ),
      ],
      children: [
        Center(child: Avatar(name.trim().isEmpty ? '?' : name, size: 72, verified: !widget.role.isChargeur)),
        IfTextField(label: 'Prénom et nom', initialValue: me.name, icon: LucideIcons.user, autofillHints: const [AutofillHints.name], error: _tried ? nameError : null, onChanged: (v) => setState(() => _name = v)),
        PhoneField(initialValue: me.phone, hint: 'Ce numéro identifie ton compte et reçoit les SMS i-fret.', error: _tried ? phoneError(phone) : null, onChanged: (v) => setState(() => _phone = v)),
        if (widget.role.isChargeur) IfTextField(label: 'Entreprise (facultatif)', initialValue: me.company, icon: LucideIcons.building2, onChanged: (v) => _company = v),
        IfTextField(
          label: 'E-mail (facultatif)',
          initialValue: me.email,
          icon: LucideIcons.mail,
          keyboardType: TextInputType.emailAddress,
          placeholder: 'nom@exemple.com',
          error: _tried ? emailError(email) : null,
          onChanged: (v) => setState(() => _email = v),
        ),
      ],
    );
  }
}

/// Comptes Mobile Money : moyens de paiement du chargeur, compte de versement du transporteur.
class ComptesScreen extends StatelessWidget {
  const ComptesScreen(this.role, {super.key});
  final Role role;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final accounts = store.accountsOf(role);
    final c = role.isChargeur;
    return Screen(
      top: TopBar(c ? 'Moyens de paiement' : 'Compte de versement'),
      foot: [Cta('Ajouter un compte Mobile Money', icon: LucideIcons.plus, onTap: () => _edit(context, null))],
      children: [
        Sub(c ? 'Le compte par défaut est proposé en premier quand tu paies un acompte ou un solde.' : 'Tes rémunérations sont versées sur le compte par défaut, sous 24 h après la livraison.'),
        for (final a in accounts)
          Opt(
            selected: a.isDefault,
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
            onTap: () => store.update(() {
              for (final other in accounts) {
                other.isDefault = other == a;
              }
            }),
            child: Row(
              spacing: 12,
              children: [
                Rad(a.isDefault),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Text(mobileMoney[a.operator]!, style: Ts.b), Lab('+229 ${formatPhone(a.phone)}${a.isDefault ? ' · par défaut' : ''}')],
                  ),
                ),
                IconBtn(LucideIcons.pencil, label: 'Modifier ${mobileMoney[a.operator]}', tone: IbTone.ghost, iconSize: 16, onTap: () => _edit(context, a)),
              ],
            ),
          ),
        const InfoRow(LucideIcons.lock, 'i-fret ne connaît jamais ton code PIN : tu valides chaque paiement sur ton téléphone.'),
      ],
    );
  }

  /// Feuille d'ajout ou de modification d'un compte.
  void _edit(BuildContext context, MoneyAccount? account) {
    final store = context.store;
    final accounts = store.accountsOf(role);
    var operator = account?.operator ?? 'mtn';
    var phone = account?.phone ?? '';
    var tried = false;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          // La feuille remonte au-dessus du clavier.
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 14,
              children: [
                Text(account == null ? 'Nouveau compte Mobile Money' : 'Modifier le compte', style: Ts.h2),
                PillWrap(options: mobileMoney.values.toList(), isOn: (o) => o == mobileMoney[operator], onPick: (o) => setState(() => operator = mobileMoney.keys.firstWhere((k) => mobileMoney[k] == o))),
                PhoneField(label: 'Numéro du compte', initialValue: phone, error: tried ? phoneError(phone) : null, onChanged: (v) => setState(() => phone = v)),
                Cta(
                  'Enregistrer',
                  onTap: () {
                    setState(() => tried = true);
                    if (phoneError(phone) != null) return;
                    store.update(() {
                      if (account == null) {
                        accounts.add(MoneyAccount(operator, phone, isDefault: accounts.isEmpty));
                      } else {
                        account
                          ..operator = operator
                          ..phone = phone;
                      }
                    });
                    Navigator.pop(context);
                  },
                ),
                // Il faut toujours garder au moins un compte.
                if (account != null && accounts.length > 1)
                  LinkBtn(
                    'Supprimer ce compte',
                    icon: LucideIcons.trash2,
                    color: context.c.danger,
                    onTap: () {
                      store.update(() {
                        accounts.remove(account);
                        if (account.isDefault) accounts.first.isDefault = true;
                      });
                      Navigator.pop(context);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Code à quatre chiffres demandé à l'ouverture de l'application.
class CodeAppScreen extends StatefulWidget {
  const CodeAppScreen({super.key});

  @override
  State<CodeAppScreen> createState() => _CodeAppScreenState();
}

class _CodeAppScreenState extends State<CodeAppScreen> {
  final _field = TextEditingController();
  String? _first;
  String? _error;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  /// Deux saisies identiques sont exigées avant d'enregistrer le nouveau code.
  void _next() {
    final code = _field.text;
    if (code.length < 4) return setState(() => _error = 'Saisis les 4 chiffres.');
    if (_first == null) {
      setState(() {
        _first = code;
        _error = null;
        _field.clear();
      });
      return;
    }
    if (code != _first) {
      setState(() {
        _first = null;
        _error = 'Les deux codes ne sont pas identiques. Recommence.';
        _field.clear();
      });
      return;
    }
    final store = context.store;
    store.update(() => store.appCode = code);
    toast(context, 'Code de l’application modifié');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final enabled = store.appCode.isNotEmpty;
    return Screen(
      top: const TopBar('Code de l’application'),
      gap: 16,
      foot: [
        Cta(_first == null ? 'Continuer' : 'Enregistrer le code', onTap: _next),
        if (enabled)
          LinkBtn(
            'Désactiver le code',
            color: context.c.danger,
            onTap: () async {
              if (!await confirm(context, title: 'Désactiver le code ?', text: 'L’application s’ouvrira sans demander de code.', action: 'Désactiver', danger: true) || !context.mounted) return;
              store.update(() => store.appCode = '');
              Navigator.pop(context);
            },
          ),
      ],
      children: [
        Heading(
          _first == null ? (enabled ? 'Choisis un nouveau code' : 'Choisis un code') : 'Saisis-le une seconde fois',
          sub: 'Ce code à quatre chiffres protège l’accès à i-fret sur ce téléphone.',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: OtpInput(length: 4, large: true, controller: _field, label: 'Code de l’application', onChanged: (_) => setState(() => _error = null)),
        ),
        if (_error != null) Semantics(liveRegion: true, child: Text(_error!, textAlign: TextAlign.center, style: Ts.small.copyWith(fontWeight: FontWeight.w600, color: context.c.danger))),
      ],
    );
  }
}

/// Paramètres.
class ParametresScreen extends StatelessWidget {
  const ParametresScreen(this.role, {super.key});
  final Role role;

  @override
  Widget build(BuildContext context) {
    final c = role.isChargeur;
    final store = context.store;
    Widget toggle(String key, IconData icon, String title, [String? subtitle]) => SetRow(
          icon: icon,
          title: title,
          subtitle: subtitle,
          trailing: Sw(value: store.settings[key]!, label: title, onChanged: (v) => store.update(() => store.settings[key] = v)),
        );
    Widget link(IconData icon, String title, {String? subtitle, String? value, VoidCallback? onTap}) =>
        SetRow(icon: icon, title: title, subtitle: subtitle, value: value, chevron: onTap != null, onTap: onTap);
    return Screen(
      top: const TopBar('Paramètres'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        if (!c)
          Labeled(
            'Missions',
            child: Grp([
              link(
                LucideIcons.locateFixed,
                'Rayon de recherche',
                subtitle: 'Distance maximale du point de chargement',
                value: '${store.radiusKm} km',
                onTap: () async {
                  final km = await pickOption(context, title: 'Rayon de recherche', options: const {5: '5 km', 10: '10 km', 25: '25 km', 50: '50 km', 100: '100 km'}, selected: store.radiusKm, note: 'Plus le rayon est grand, plus tu reçois de missions, mais plus loin de toi.');
                  if (km != null) store.update(() => store.radiusKm = km);
                },
              ),
              toggle('son', LucideIcons.bell, 'Alerte sonore', 'Sonnerie à chaque nouvelle mission'),
              toggle('retour', LucideIcons.undo2, 'Missions de retour', 'Me proposer du fret sur le trajet retour'),
            ]),
          ),
        Labeled(
          'Notifications',
          child: Grp([
            toggle('push', LucideIcons.bell, 'Notifications de l’application', c ? 'Suivi, paiements, messages' : 'Missions, paiements, messages'),
            toggle('sms', LucideIcons.messageCircle, 'SMS', 'Si tu n’as pas de connexion'),
            if (c) toggle('promo', LucideIcons.percent, 'Offres et nouveautés'),
          ]),
        ),
        Labeled(
          'Sécurité',
          child: Grp([
            link(LucideIcons.lock, 'Code de l’application', subtitle: 'Demandé à chaque ouverture', value: store.appCode.isEmpty ? 'Désactivé' : 'Activé', onTap: () => context.go(R.codeApp)),
            toggle('bio', LucideIcons.keyRound, 'Empreinte ou visage'),
          ]),
        ),
        Labeled(
          'Application',
          child: Grp([
            link(
              LucideIcons.map,
              'Langue',
              value: 'Français',
              onTap: () => pickOption(context, title: 'Langue', options: const {'fr': 'Français'}, selected: 'fr', note: 'i-fret est disponible en français. D’autres langues seront ajoutées.'),
            ),
            if (c)
              link(LucideIcons.coins, 'Devise', value: 'FCFA')
            else
              link(
                LucideIcons.navigation,
                'Application de navigation',
                value: store.navApp,
                onTap: () async {
                  final app = await pickOption(context, title: 'Application de navigation', options: const {'Google Maps': 'Google Maps', 'Waze': 'Waze'}, selected: store.navApp, note: 'Elle s’ouvre quand tu lances l’itinéraire d’une mission.');
                  if (app != null) store.update(() => store.navApp = app);
                },
              ),
            link(LucideIcons.scrollText, 'Conditions et confidentialité', onTap: () => context.go(R.conditions)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(child: Lab('i-fret 1.0 · un service ILT')),
              InkWell(
                onTap: () async {
                  final ok = await confirm(context, title: 'Supprimer ton compte ?', text: 'Tes courses, tes adresses et tes messages seront effacés. Cette action est définitive.', action: 'Supprimer', danger: true);
                  if (ok && context.mounted) {
                    toast(context, 'Compte supprimé');
                    context.reset(R.compte);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('Supprimer mon compte', style: Ts.lab.copyWith(fontWeight: FontWeight.w600, color: context.c.danger)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Notifications, avec filtre « non lues ».
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen(this.role, {super.key});
  final Role role;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _unreadOnly = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.role.isChargeur;
    final store = context.store;
    final all = store.notifsOf(widget.role);
    final shown = all.where((n) => !_unreadOnly || n.unread).toList();
    final count = store.unreadNotifs(widget.role);
    final unread = 'Non lues · $count';
    return Screen(
      top: TopBar(
        'Notifications',
        trailing: IconBtn(LucideIcons.settings, label: 'Régler les notifications', tone: IbTone.outline, onTap: () => context.go(c ? R.cParametres : R.tParametres)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        Row(
          spacing: 8,
          children: [
            Expanded(child: PillWrap(options: ['Toutes', unread], isOn: (o) => (o == unread) == _unreadOnly, onPick: (o) => setState(() => _unreadOnly = o == unread))),
            if (count > 0)
              TextLink(
                'Tout lire',
                onTap: () => store.update(() {
                  for (final n in all) {
                    n.unread = false;
                  }
                }),
              ),
          ],
        ),
        if (shown.isEmpty) const EmptyCard(LucideIcons.bell, 'Tout est lu', 'Tu n’as aucune notification en attente.'),
        for (final day in shown.map((n) => n.day).toSet())
          Labeled(
            day,
            child: Grp([
              for (final n in shown.where((n) => n.day == day))
                SetRow(
                  icon: n.icon,
                  iconBg: n.unread ? context.c.primary : null,
                  title: n.title,
                  subtitle: n.text,
                  roomy: true,
                  trailing: TimeDot(n.time, unread: n.unread),
                  onTap: () {
                    store.update(() => n.unread = false);
                    // Une notification qui renvoie à l'accueil ferme simplement la liste.
                    n.route == R.t || n.route == R.c ? Navigator.maybePop(context) : context.go(n.route);
                  },
                ),
            ]),
          ),
      ],
    );
  }
}

typedef _Faq = (String topic, String question, String answer);

const _chargeurFaq = <_Faq>[
  ('Paiement', 'Comment le prix est-il calculé ?', 'Le prix dépend de la distance, du véhicule choisi et de la marchandise. Tu vois une fourchette avant de confirmer : le prix final reste dans cette fourchette, sauf frais imprévus validés par ILT.'),
  ('Paiement', 'Quand dois-je payer le solde ?', 'À l’arrivée du camion, avant le déchargement. Le transporteur attend ta confirmation de paiement pour décharger.'),
  ('Course', 'À quoi sert le code de livraison ?', 'Le destinataire reçoit un code à quatre chiffres par SMS. Il le donne au transporteur une fois la marchandise déchargée : c’est la preuve que la livraison a bien eu lieu.'),
  ('Course', 'Que se passe-t-il si j’annule ?', 'Tant qu’aucun transporteur n’a accepté, l’annulation est gratuite et l’acompte est remboursé sous 24 h. Ensuite, 10 % de l’acompte sont retenus si le transporteur est en route, 30 % s’il est déjà sur place.'),
  ('Course', 'Ma marchandise est abîmée, que faire ?', 'Signale-le tout de suite depuis l’aide, avec des photos. ILT compare avec les photos prises au chargement et te recontacte.'),
  ('Compte', 'Comment changer mon numéro ?', 'Dans Profil, puis Informations personnelles. Le nouveau numéro recevra les prochains SMS i-fret.'),
];

const _transporteurFaq = <_Faq>[
  ('Paiement', 'Quand suis-je payé après une livraison ?', 'Ta rémunération est versée sur ton compte Mobile Money sous 24 h après la validation du code de livraison.'),
  ('Mission', 'Comment déclarer un surpoids ou une attente ?', 'Sur l’écran de chargement, déclare l’écart avec une preuve (ticket de pesée, photo). ILT valide avant le paiement du solde et le montant s’ajoute à ta rémunération.'),
  ('Mission', 'Le destinataire n’a pas le code, que faire ?', 'Demande-lui de vérifier ses SMS. Après trois essais ratés, appelle l’assistance ILT, qui peut renvoyer le code.'),
  ('Mission', 'Pourquoi je ne reçois pas de mission ?', 'Vérifie que tu es en ligne et que ton rayon de recherche n’est pas trop petit. Les missions vont d’abord aux transporteurs les plus proches du chargement.'),
  ('Compte', 'Comment mettre à jour mes documents ?', 'Dans Profil, puis Mes documents. ILT vérifie chaque nouvelle pièce avant de la prendre en compte.'),
  ('Paiement', 'Comment changer mon compte de versement ?', 'Dans Profil, puis Compte de versement. Le compte par défaut reçoit tes prochaines rémunérations.'),
];

/// Aide : assistance ILT, sujets et questions fréquentes dont la réponse se déplie.
class AideScreen extends StatefulWidget {
  const AideScreen(this.role, {super.key});
  final Role role;

  @override
  State<AideScreen> createState() => _AideScreenState();
}

class _AideScreenState extends State<AideScreen> {
  String _query = '';
  String? _topic;
  String? _open;

  @override
  Widget build(BuildContext context) {
    final c = widget.role.isChargeur;
    final q = _query.trim().toLowerCase();
    final faq = (c ? _chargeurFaq : _transporteurFaq).where((f) => (_topic == null || f.$1 == _topic) && (q.isEmpty || '${f.$2} ${f.$3}'.toLowerCase().contains(q))).toList();
    void topic(String t) => setState(() => _topic = _topic == t ? null : t);
    return Screen(
      top: const TopBar('Aide'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        AppCard(
          tone: CardTone.yellow,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [
              const Text('Besoin d’aide ?', style: TextStyle(fontSize: 18, height: 24 / 18, fontWeight: FontWeight.w600)),
              const Text('L’équipe ILT répond tous les jours de 7 h à 21 h.', style: Ts.small),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  spacing: 8,
                  children: [
                    Expanded(child: Cta('Appeler', tone: CtaTone.dark, icon: LucideIcons.phone, height: 44, fontSize: 14, onTap: () => callNumber(context, kAssistancePhone))),
                    Expanded(child: Cta('Écrire', tone: CtaTone.white, icon: LucideIcons.messageCircle, height: 44, fontSize: 14, onTap: () => context.go(R.chat, args: c ? 'ilt' : 'ilt-t'))),
                  ],
                ),
              ),
            ],
          ),
        ),
        QuickActions([
          (LucideIcons.triangleAlert, 'Signaler', () => context.go(c ? R.cSignalement : R.tSignalement)),
          (LucideIcons.banknote, 'Paiement', () => topic('Paiement')),
          (LucideIcons.package, c ? 'Course' : 'Mission', () => topic(c ? 'Course' : 'Mission')),
          (LucideIcons.user, 'Compte', () => topic('Compte')),
        ]),
        SearchBox('Chercher dans l’aide', onChanged: (v) => setState(() => _query = v)),
        Labeled(
          _topic == null ? 'Questions fréquentes' : 'Questions · $_topic',
          child: faq.isEmpty
              ? const EmptyCard(LucideIcons.circleQuestionMark, 'Aucune réponse trouvée', 'Écris à l’assistance ILT, on te répond vite.')
              : Grp([
                  for (final (_, question, answer) in faq)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SetRow(
                          title: question,
                          light: true,
                          trailing: AnimatedRotation(turns: _open == question ? .25 : 0, duration: kFast, child: const Icon(LucideIcons.chevronRight, size: 18)),
                          onTap: () => setState(() => _open = _open == question ? null : question),
                        ),
                        // La réponse se déplie sous la question, sans quitter la page.
                        AnimatedSize(
                          duration: kMedium,
                          curve: kEase,
                          alignment: Alignment.topCenter,
                          child: _open == question ? Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14), child: Sub(answer)) : const SizedBox(width: double.infinity),
                        ),
                      ],
                    ),
                ]),
        ),
      ],
    );
  }
}

/// Signalement d'un problème à ILT.
class SignalementScreen extends StatefulWidget {
  const SignalementScreen(this.role, {super.key});
  final Role role;

  @override
  State<SignalementScreen> createState() => _SignalementScreenState();
}

class _SignalementScreenState extends State<SignalementScreen> {
  static const _transporteur = [
    ('Panne du véhicule', LucideIcons.triangleAlert),
    ('Accident', LucideIcons.circleAlert),
    ('Retard sur la route', LucideIcons.clock),
    ('Destinataire absent', LucideIcons.user),
    ('Marchandise refusée', LucideIcons.packageX),
    ('Autre problème', LucideIcons.circleQuestionMark),
  ];
  static const _chargeur = [
    ('Marchandise abîmée', LucideIcons.packageX),
    ('Colis manquant', LucideIcons.package),
    ('Retard important', LucideIcons.clock),
    ('Problème de paiement', LucideIcons.banknote),
    ('Comportement du transporteur', LucideIcons.user),
    ('Autre problème', LucideIcons.circleQuestionMark),
  ];
  int _kind = 2;
  String _text = '';
  bool _tried = false;
  final _photos = <String>[];

  @override
  Widget build(BuildContext context) {
    final kinds = widget.role.isChargeur ? _chargeur : _transporteur;
    final error = _tried ? requiredError(_text, 'Explique ce qui se passe pour qu’ILT puisse t’aider.') : null;
    Widget kind(int i) => Expanded(
          child: Opt(
            selected: i == _kind,
            onTap: () => setState(() => _kind = i),
            padding: const EdgeInsets.all(12),
            child: Row(
              spacing: 10,
              children: [
                Icon(kinds[i].$2),
                Expanded(child: Text(kinds[i].$1, style: const TextStyle(fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w600))),
              ],
            ),
          ),
        );
    return Screen(
      top: const TopBar('Signalement', close: true),
      foot: [
        AsyncCta(
          'Envoyer à ILT',
          validate: () {
            setState(() => _tried = true);
            return _text.trim().isNotEmpty;
          },
          action: () {
            toast(context, 'Signalement envoyé. ILT te recontacte très vite.');
            Navigator.maybePop(context);
          },
        ),
        LinkBtn('Appeler l’assistance', icon: LucideIcons.phone, onTap: () => callNumber(context, kAssistancePhone)),
      ],
      children: [
        Heading('Que se passe-t-il ?', sub: widget.role.isChargeur ? 'ILT est prévenu tout de suite et te recontacte.' : 'Mission IFR-2611-0042 · ILT est prévenu tout de suite, le chargeur aussi.'),
        Column(
          spacing: 10,
          children: [
            for (var i = 0; i < kinds.length; i += 2) IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 10, children: [kind(i), kind(i + 1)])),
          ],
        ),
        IfTextField(
          label: 'Explique en quelques mots',
          filled: true,
          minLines: 3,
          placeholder: 'Où es-tu, que s’est-il passé, de quoi as-tu besoin ?',
          error: error,
          onChanged: (v) => setState(() => _text = v),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [const Text('Photos (facultatif)', style: Ts.b), PhotoStrip(_photos, max: 4, onChanged: () => setState(() {}))],
        ),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: InfoRow(LucideIcons.locateFixed, 'Ta position est jointe au signalement.')),
      ],
    );
  }
}

/// Fin de course : confirmation et note de l'autre partie.
class NotationScreen extends StatefulWidget {
  const NotationScreen(this.role, {super.key, this.courseRef});
  final Role role;
  final String? courseRef;

  @override
  State<NotationScreen> createState() => _NotationScreenState();
}

class _NotationScreenState extends State<NotationScreen> {
  late final _c = widget.role.isChargeur;
  late final _tags = _c ? const ['Ponctuel', 'Soigneux', 'Aimable', 'Bonne communication'] : const ['Marchandise prête', 'Paiement rapide', 'Bon accueil', 'Infos exactes'];
  late final _picked = {..._tags.take(2)};
  int _note = 5;

  /// La note envoyée, retour à l'accueil : onglet Courses ou Gains.
  void _done({required bool rated}) {
    final store = context.store;
    if (rated) {
      store.update(() => _c ? store.course(widget.courseRef).rating = _note : store.shipperRating = _note);
      toast(context, 'Merci pour ta note');
    }
    context.home(widget.role, tab: _c ? 1 : 2);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final store = context.store;
    final course = store.course(widget.courseRef);
    final other = _c ? (course.carrier.isEmpty ? 'Rodrigue Hounkpè' : course.carrier) : store.chargeur.name;
    return Screen(
      padding: const EdgeInsets.fromLTRB(16, 36, 16, 16),
      foot: [
        AsyncCta('Envoyer ma note', action: () => _done(rated: true)),
        _c ? LinkBtn('Voir le reçu', onTap: () => context.go(R.cRecu, args: course.ref)) : LinkBtn('Passer', onTap: () => _done(rated: false)),
      ],
      children: [
        Column(
          spacing: 8,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: context.reduceMotion ? 1 : .4, end: 1),
              duration: const Duration(milliseconds: 520),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
                child: Icon(LucideIcons.check, size: 32, color: c.onPrimary),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Semantics(header: true, child: Text(_c ? 'Bien arrivé chez ${course.recipient.split(' ').first}' : 'Livraison validée', textAlign: TextAlign.center, style: Ts.h1)),
            ),
            Sub(
              _c ? 'Livré à 16:52 · code validé\n${course.route} · ${money(course.total)} réglés' : 'Code correct · 16:52\nCotonou → Parakou · 415 km',
              align: TextAlign.center,
            ),
          ],
        ),
        if (!_c)
          AppCard(
            tone: CardTone.soft,
            child: Row(
              spacing: 12,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Text('Ta rémunération', style: Ts.b), Lab('88 000 + 8 000 de surpoids · versée sous 24 h')],
                  ),
                ),
                Text('+ 96 000', style: Ts.num(18)),
              ],
            ),
          ),
        AppCard(
          child: Column(
            spacing: 12,
            children: [
              Row(
                spacing: 12,
                children: [
                  Avatar(other, verified: _c),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [Lab(_c ? 'Ton transporteur' : 'Le chargeur'), Text('Comment était ${other.split(' ').first} ?', style: Ts.b)],
                    ),
                  ),
                ],
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: RatingInput(value: _note, onChanged: (v) => setState(() => _note = v), label: _c ? 'Note du transporteur' : 'Note du chargeur'),
              ),
            ],
          ),
        ),
        PillWrap(options: _tags, isOn: _picked.contains, onPick: (t) => setState(() => _picked.contains(t) ? _picked.remove(t) : _picked.add(t))),
        if (_c) const IfTextField(label: 'Un mot de plus ? (facultatif)', placeholder: 'Ce qui s’est bien ou mal passé…'),
      ],
    );
  }
}
