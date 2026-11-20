import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/store.dart';
import '../../routes.dart';
import '../../services/device.dart';
import '../../services/receipt.dart';
import '../../theme/tokens.dart';
import '../../widgets/brand.dart';
import '../../widgets/extras.dart';
import '../../widgets/forms.dart';
import '../../widgets/layout.dart';
import '../../widgets/map.dart';
import '../../widgets/ui.dart';
import 'home.dart';

// Vie d'une course côté chargeur : suivi, solde, reçu, annulation, adresses.

/// Suivi en temps réel sur la carte.
class SuiviScreen extends StatelessWidget {
  const SuiviScreen({super.key, this.courseRef});
  final String? courseRef;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final course = store.course(courseRef);
    final progress = courseProgress(course);
    final carrier = course.carrier.isEmpty ? 'Transporteur' : course.carrier;
    final done = (course.km * progress).round();
    return MapSheetScreen(
      mapFraction: .46,
      pickup: course.from,
      dropoff: course.to,
      progress: progress,
      overlay: [
        IconBtn(LucideIcons.arrowLeft, label: 'Retour', tone: IbTone.floating, onTap: () => Navigator.maybePop(context)),
        Tag(course.ref, tone: Tone.floating),
      ],
      foot: [
        // Aperçu de la maquette : en production, l'arrivée est signalée par le serveur.
        if (course.status == CourseStatus.enRoute)
          Cta(
            'Aperçu : le camion arrive',
            tone: CtaTone.outline,
            onTap: () {
              store.truckArrives(course);
              context.go(R.cSolde, args: course.ref);
            },
          )
        else if (course.status == CourseStatus.arrived)
          Cta('Payer le solde', onTap: () => context.go(R.cSolde, args: course.ref)),
      ],
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: [
                  Tag(course.status.label),
                  Semantics(header: true, child: Text(course.status == CourseStatus.arrived ? 'Le camion est arrivé' : 'Arrivée vers 16:40', style: Ts.h1)),
                ],
              ),
            ),
            Padding(padding: const EdgeInsets.only(top: 4), child: Lab('$done km parcourus\n${course.km - done} km restants', align: TextAlign.right)),
          ],
        ),
        ProgressBar(progress),
        Row(
          spacing: 12,
          children: [
            Avatar(carrier, verified: true),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Text(carrier, style: Ts.b), Lab('${course.vehicle.short} · ${course.plate}')],
              ),
            ),
            IconBtn(LucideIcons.phone, label: 'Appeler $carrier', tone: IbTone.outline, onTap: () => callNumber(context, store.conversation('rodrigue').phone)),
            IconBtn(LucideIcons.messageCircle, label: 'Écrire à $carrier', tone: IbTone.primary, onTap: () => context.go(R.chat, args: 'rodrigue')),
          ],
        ),
        AppCard(
          tone: CardTone.soft,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            spacing: 12,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [const Text('Code de livraison', style: Ts.b), Lab('${course.recipient.split(' ').first} le donne à la remise, pas avant.')],
                ),
              ),
              Semantics(
                label: 'Code ${course.code.split('').join(' ')}',
                child: ExcludeSemantics(child: Row(spacing: 6, children: [for (final digit in course.code.split('')) Dig(digit)])),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Arrivée du camion : paiement du solde avant déchargement.
class SoldeScreen extends StatelessWidget {
  const SoldeScreen({super.key, this.courseRef});
  final String? courseRef;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final course = store.course(courseRef);
    final account = store.accountOf(Role.chargeur);
    final carrier = course.carrier.isEmpty ? 'Le transporteur' : course.carrier.split(' ').first;
    return Screen(
      top: const TopBar('Payer le solde'),
      foot: [
        AsyncCta(
          'Payer ${money(course.balance)}',
          action: () {
            store.payBalance(course);
            Navigator.pushNamedAndRemoveUntil(context, R.cNotation, ModalRoute.withName(R.c), arguments: course.ref);
          },
        ),
        if (course.adjustment > 0) LinkBtn('Contester l’ajustement', onTap: () => context.go(R.chat, args: 'ilt')),
      ],
      children: [
        AppCard(
          tone: CardTone.yellow,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Text('$carrier est arrivé à ${course.to.city} · 16:38', style: Ts.small),
              Amount(formatNumber(course.balance), size: 34, unitSize: 15),
              const Text('Il décharge dès que ton paiement est confirmé.', style: Ts.small),
            ],
          ),
        ),
        AppCard(
          child: Column(
            spacing: 12,
            children: [
              Kv('Prix de la course', formatNumber(course.price), muted: false),
              if (course.adjustment > 0)
                Kv(
                  'Surpoids',
                  '+ ${formatNumber(course.adjustment)}',
                  muted: false,
                  badge: const Tag('Validé par ILT', tone: Tone.warning, height: 20),
                  sub: '8,6 t pesées au lieu de 8 t déclarées',
                ),
              Kv('Acompte déjà payé', '− ${formatNumber(course.deposit)}', muted: false, sub: mobileMoney[course.operator]),
              const Hr(),
              Kv('Reste à payer', money(course.balance), total: true),
            ],
          ),
        ),
        AppCard(
          tone: CardTone.soft,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Li(
            icon: LucideIcons.smartphone,
            iconBg: context.c.primary,
            title: mobileMoney[account.operator]!,
            subtitle: '+229 ${formatPhone(account.phone)}',
            padding: EdgeInsets.zero,
            trailing: TextLink('Changer', onTap: () => context.go(R.comptes, args: Role.chargeur)),
          ),
        ),
      ],
    );
  }
}

/// Reçu d'une course : acompte seul tant qu'elle n'est pas livrée, détail complet ensuite.
class RecuScreen extends StatelessWidget {
  const RecuScreen({super.key, this.courseRef});
  final String? courseRef;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    // Sans course précise, on montre la dernière livrée.
    final course = courseRef == null ? (store.courses.where((c) => c.status == CourseStatus.delivered).firstOrNull ?? store.courses.first) : store.course(courseRef);
    final delivered = course.status == CourseStatus.delivered;
    final cancelled = course.status == CourseStatus.cancelled;
    final paid = delivered ? course.total : (cancelled ? 0 : course.deposit);
    final operator = mobileMoney[course.operator]!;
    return Screen(
      top: const TopBar('Reçu'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      gap: 12,
      foot: [
        Row(
          spacing: 8,
          children: [
            Expanded(child: Cta('Partager', tone: CtaTone.outline, icon: LucideIcons.share2, onTap: () => shareReceipt(context, course))),
            Expanded(flex: 2, child: Cta('Télécharger le PDF', icon: LucideIcons.download, onTap: () => saveReceipt(context, course))),
          ],
        ),
      ],
      children: [
        AppCard(
          tone: CardTone.yellow,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 2,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(child: Text('Reçu ${course.ref}', style: Ts.small)),
                  Tag(course.status.label, tone: Tone.dark, icon: delivered ? LucideIcons.check : null),
                ],
              ),
              Amount(formatNumber(paid)),
              Text(
                cancelled ? 'Demande annulée · acompte remboursé' : (delivered ? 'Payé en deux fois par $operator · ${course.date}' : 'Acompte payé par $operator · ${course.date}'),
                style: Ts.small,
              ),
            ],
          ),
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14,
            children: [
              RoutePoints(
                fromLabel: delivered ? 'Chargé · ${course.date}' : 'Chargement',
                from: course.from.name,
                toLabel: delivered ? 'Livré · ${course.date} · code validé' : 'Livraison · ${course.km} km',
                to: course.to.name,
              ),
              if (course.carrier.isNotEmpty) ...[
                const Hr(),
                Row(
                  spacing: 12,
                  children: [
                    Avatar(course.carrier, size: 32, verified: true),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [Text(course.carrier, style: Ts.b), Lab('${course.vehicle.short} · ${course.plate} · ${course.cargo}')],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        AppCard(
          child: Column(
            spacing: 10,
            children: [
              Kv('Prix de la course', formatNumber(course.price)),
              if (course.adjustment > 0) Kv('Surpoids validé par ILT', '+ ${formatNumber(course.adjustment)}'),
              const Hr(),
              Kv('Acompte', formatNumber(course.deposit)),
              if (delivered) Kv('Solde', formatNumber(course.balance)),
              if (cancelled) Kv('Remboursement', '− ${formatNumber(course.deposit)}'),
              const Hr(),
              Kv('Total payé', money(paid), total: true),
            ],
          ),
        ),
      ],
    );
  }
}

/// Annulation d'une demande : gratuite avant acceptation, puis selon le barème.
class AnnulationScreen extends StatefulWidget {
  const AnnulationScreen({super.key, this.courseRef});
  final String? courseRef;

  @override
  State<AnnulationScreen> createState() => _AnnulationScreenState();
}

class _AnnulationScreenState extends State<AnnulationScreen> {
  static const _reasons = ['Changement de date', 'Attente trop longue', 'Erreur dans la demande', 'Autre solution trouvée', 'Autre'];
  String _reason = _reasons.first;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final course = store.course(widget.courseRef);
    // Barème repris de la maquette : montants à confirmer par ILT.
    final rate = switch (course.status) { CourseStatus.enRoute => 10, CourseStatus.arrived => 30, _ => 0 };
    final fee = course.deposit * rate ~/ 100;
    return Screen(
      top: const TopBar('Annulation', close: true),
      foot: [
        AsyncCta(
          'Confirmer l’annulation',
          tone: CtaTone.dark,
          action: () {
            store.cancel(course);
            toast(context, 'Demande annulée. ${money(course.deposit - fee)} remboursés sous 24 h.');
            context.home(Role.chargeur);
          },
        ),
        LinkBtn('Garder ma demande', onTap: () => Navigator.maybePop(context)),
      ],
      children: [
        Heading(
          'Annuler ta demande ?',
          sub: rate == 0 ? 'Aucun transporteur n’a encore accepté : l’annulation est gratuite.' : 'Un transporteur a déjà accepté : $rate % de l’acompte sont retenus.',
        ),
        AppCard(
          tone: CardTone.soft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              Kv('Acompte payé', formatNumber(course.deposit)),
              Kv('Frais d’annulation', formatNumber(fee)),
              const Hr(),
              Kv('Remboursement', money(course.deposit - fee), total: true),
              Lab('Remboursé sur ton ${mobileMoney[course.operator]} sous 24 h.'),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            const Text('Pourquoi annules-tu ?', style: Ts.b),
            PillWrap(options: _reasons, isOn: (r) => r == _reason, onPick: (r) => setState(() => _reason = r)),
          ],
        ),
        const AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              Text('Le barème d’annulation', style: Ts.b),
              Kv('Avant l’acceptation', 'Gratuit'),
              Kv('Transporteur en route', '10 % de l’acompte'),
              Kv('Transporteur sur place', '30 % de l’acompte'),
            ],
          ),
        ),
      ],
    );
  }
}

/// Adresses enregistrées, avec recherche.
class AdressesScreen extends StatefulWidget {
  const AdressesScreen({super.key});

  @override
  State<AdressesScreen> createState() => _AdressesScreenState();
}

class _AdressesScreenState extends State<AdressesScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final all = context.store.addresses.where((a) => q.isEmpty || '${a.label} ${a.place.detail} ${a.contact}'.toLowerCase().contains(q)).toList();
    Widget group(String label, AddressKind kind) {
      final items = all.where((a) => a.kind == kind).toList();
      if (items.isEmpty) return const SizedBox.shrink();
      return Labeled(
        label,
        child: Grp([
          for (final a in items)
            SetRow(
              icon: kind == AddressKind.pickup ? LucideIcons.building2 : LucideIcons.mapPin,
              title: a.label,
              subtitle: a.contact.isEmpty ? a.place.detail : '${a.place.detail} · contact : ${a.contact}',
              badge: a.isDefault ? const Tag('Par défaut', tone: Tone.neutral, height: 20) : null,
              chevron: true,
              onTap: () => context.go(R.cAdresse, args: a),
            ),
        ]),
      );
    }

    return Screen(
      top: const TopBar('Mes adresses'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      foot: [Cta('Ajouter une adresse', icon: LucideIcons.plus, onTap: () => context.go(R.cAdresse))],
      children: [
        SearchBox('Chercher une adresse', onChanged: (v) => setState(() => _query = v)),
        if (all.isEmpty)
          EmptyCard(LucideIcons.mapPin, 'Aucune adresse', q.isEmpty ? 'Ajoute tes lieux habituels pour gagner du temps.' : 'Rien ne correspond à « $_query ».')
        else ...[
          group('Chargement', AddressKind.pickup),
          group('Livraison', AddressKind.dropoff),
        ],
        const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Lab('Une adresse enregistrée se choisit en un geste quand tu crées une demande.')),
      ],
    );
  }
}

/// Ajout ou modification d'une adresse.
class AdresseScreen extends StatefulWidget {
  const AdresseScreen({super.key, this.address});

  /// Nul : nouvelle adresse.
  final SavedAddress? address;

  @override
  State<AdresseScreen> createState() => _AdresseScreenState();
}

class _AdresseScreenState extends State<AdresseScreen> {
  late String _label = widget.address?.label ?? '';
  late String _contact = widget.address?.contact ?? '';
  late AddressKind _kind = widget.address?.kind ?? AddressKind.pickup;
  late Place? _place = widget.address?.place;
  late bool _default = widget.address?.isDefault ?? false;
  bool _tried = false;

  void _save() {
    final store = context.store;
    store.update(() {
      // Une seule adresse par défaut pour chaque usage.
      if (_default) {
        for (final a in store.addresses.where((a) => a.kind == _kind)) {
          a.isDefault = false;
        }
      }
      final a = widget.address;
      if (a == null) {
        store.addresses.add(SavedAddress(_label.trim(), _place!, _kind, contact: _contact.trim(), isDefault: _default));
      } else {
        a
          ..label = _label.trim()
          ..place = _place!
          ..kind = _kind
          ..contact = _contact.trim()
          ..isDefault = _default;
      }
    });
    toast(context, 'Adresse enregistrée');
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final store = context.store;
    final ok = await confirm(context, title: 'Supprimer cette adresse ?', text: '« ${widget.address!.label} » ne sera plus proposée dans tes demandes.', action: 'Supprimer', danger: true);
    if (!ok || !mounted) return;
    store.update(() => store.addresses.remove(widget.address));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final labelError = requiredError(_label, 'Donne un nom à cette adresse.');
    final placeError = _place == null ? 'Place l’adresse sur la carte.' : null;
    return Screen(
      top: TopBar(widget.address == null ? 'Nouvelle adresse' : 'Modifier l’adresse'),
      gap: 16,
      foot: [
        AsyncCta(
          'Enregistrer',
          validate: () {
            setState(() => _tried = true);
            return labelError == null && placeError == null;
          },
          action: _save,
        ),
        if (widget.address != null) LinkBtn('Supprimer cette adresse', icon: LucideIcons.trash2, color: c.danger, onTap: _delete),
      ],
      children: [
        IfTextField(label: 'Nom de l’adresse', placeholder: 'Entrepôt, boutique, chantier…', initialValue: _label, error: _tried ? labelError : null, onChanged: (v) => setState(() => _label = v)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            const Text('Cette adresse sert pour', style: TextStyle(fontWeight: FontWeight.w500)),
            Seg(
              options: const ['Le chargement', 'La livraison'],
              value: _kind == AddressKind.pickup ? 'Le chargement' : 'La livraison',
              onChanged: (o) => setState(() => _kind = o == 'Le chargement' ? AddressKind.pickup : AddressKind.dropoff),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            const Text('Emplacement', style: TextStyle(fontWeight: FontWeight.w500)),
            FieldBox(
              height: 56,
              muted: _place == null,
              onTap: () async {
                final picked = await pickPlace(context, title: 'Emplacement de l’adresse', initial: _place);
                if (picked != null) setState(() => _place = picked);
              },
              children: [
                const Icon(LucideIcons.mapPinned),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_place?.name ?? 'Choisir sur la carte', maxLines: 1, overflow: TextOverflow.ellipsis, style: _place == null ? null : Ts.b),
                      if (_place != null && _place!.detail.isNotEmpty) Lab(_place!.detail, maxLines: 1),
                    ],
                  ),
                ),
                const Icon(LucideIcons.chevronRight, size: 18),
              ],
            ),
            if (_tried && placeError != null) Text(placeError, style: Ts.small.copyWith(fontWeight: FontWeight.w600, color: c.danger)),
          ],
        ),
        IfTextField(label: 'Contact sur place (facultatif)', placeholder: 'Nom de la personne à demander', icon: LucideIcons.user, initialValue: _contact, onChanged: (v) => _contact = v),
        Row(
          spacing: 12,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Text('Adresse par défaut', style: Ts.b), Lab('Proposée en premier dans tes nouvelles demandes')],
              ),
            ),
            Sw(value: _default, label: 'Adresse par défaut', onChanged: (v) => setState(() => _default = v)),
          ],
        ),
      ],
    );
  }
}
