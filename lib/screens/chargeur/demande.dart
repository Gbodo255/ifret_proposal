import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/store.dart';
import '../../routes.dart';
import '../../theme/tokens.dart';
import '../../widgets/brand.dart';
import '../../widgets/extras.dart';
import '../../widgets/forms.dart';
import '../../widgets/layout.dart';
import '../../widgets/map.dart';
import '../../widgets/ui.dart';

// Parcours « créer une demande et payer l'acompte » : cinq étapes, puis paiement et recherche.
// La demande en cours de saisie vit dans le magasin : chaque étape la complète.

/// Message d'erreur rouge sous un groupe de champs.
class _Error extends StatelessWidget {
  const _Error(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Row(
          spacing: 8,
          children: [
            Icon(LucideIcons.circleAlert, size: 16, color: context.c.danger),
            Expanded(child: Text(text, style: Ts.small.copyWith(fontWeight: FontWeight.w600, color: context.c.danger))),
          ],
        ),
      );
}

/// Étape 1 : trajet, sur la carte.
class TrajetScreen extends StatefulWidget {
  const TrajetScreen({super.key});

  @override
  State<TrajetScreen> createState() => _TrajetScreenState();
}

class _TrajetScreenState extends State<TrajetScreen> {
  bool _tried = false;

  String? _error(Draft d) {
    if (d.dropoff == null) return 'Choisis le lieu de livraison.';
    if (d.pickup.distanceTo(d.dropoff!) < .2) return 'Le chargement et la livraison sont au même endroit.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final draft = store.draft;
    final error = _tried ? _error(draft) : null;

    Future<void> choose({required bool dropoff}) async {
      final picked = await pickPlace(context, title: dropoff ? 'Lieu de livraison' : 'Lieu de chargement', initial: dropoff ? draft.dropoff : draft.pickup);
      if (picked != null) store.update(() => dropoff ? draft.dropoff = picked : draft.pickup = picked);
    }

    Widget place(String label, Place? p, {required bool dropoff}) => FieldBox(
          height: 56,
          muted: p == null,
          onTap: () => choose(dropoff: dropoff),
          children: [
            RouteDot(dropoff: dropoff),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Lab(label),
                  Text(p?.name ?? 'Choisir sur la carte', maxLines: 1, overflow: TextOverflow.ellipsis, style: p == null ? null : Ts.b),
                ],
              ),
            ),
            Icon(p == null ? LucideIcons.mapPinned : LucideIcons.pencil, size: 18),
          ],
        );

    return MapSheetScreen(
      mapFraction: .46,
      pickup: draft.pickup,
      dropoff: draft.dropoff,
      overlay: [IconBtn(LucideIcons.x, label: 'Fermer', tone: IbTone.floating, onTap: () => Navigator.maybePop(context))],
      foot: [
        Cta(
          'Continuer',
          onTap: () {
            setState(() => _tried = true);
            if (_error(draft) == null) context.go(R.cMarchandise);
          },
        ),
      ],
      children: [
        const StepHeader(1, 5, 'Trajet', padding: EdgeInsets.zero),
        Semantics(header: true, child: const Text('D’où à où ?', style: Ts.h1)),
        Column(
          spacing: 8,
          children: [
            place('Chargement', draft.pickup, dropoff: false),
            place('Livraison', draft.dropoff, dropoff: true),
          ],
        ),
        if (error != null) _Error(error),
        if (store.addresses.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in store.addresses.take(4))
                Tag(
                  a.label,
                  tone: Tone.outline,
                  icon: LucideIcons.mapPin,
                  height: 32,
                  // Une adresse enregistrée connaît déjà son usage : chargement ou livraison.
                  onTap: () => store.update(() {
                    final p = Place(a.label, a.place.detail, a.place.lat, a.place.lng);
                    a.kind == AddressKind.pickup ? draft.pickup = p : draft.dropoff = p;
                  }),
                ),
            ],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          spacing: 12,
          children: [
            const Sub('Distance estimée'),
            Flexible(child: Text(draft.dropoff == null ? '—' : '${draft.km} km · ${draft.duration}', style: Ts.b)),
          ],
        ),
      ],
    );
  }
}

/// Étape 2 : nature, poids ou volume, nombre de colis.
class MarchandiseScreen extends StatefulWidget {
  const MarchandiseScreen({super.key});

  @override
  State<MarchandiseScreen> createState() => _MarchandiseScreenState();
}

class _MarchandiseScreenState extends State<MarchandiseScreen> {
  static const _categories = ['Alimentaire', 'Matériaux', 'Électroménager', 'Textile', 'Mobilier', 'Autre'];
  final _amount = TextEditingController();
  bool _tried = false;
  bool _filled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_filled) return;
    _filled = true;
    final d = context.store.draft;
    _amount.text = '${d.byWeight ? d.kg : d.m3}';
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final store = context.store;
    final d = store.draft;
    final value = d.byWeight ? d.kg : d.m3;
    final step = d.byWeight ? 500 : 5;
    final presets = d.byWeight ? const [1000, 5000, 8000, 10000, 20000] : const [5, 20, 40, 60, 90];
    void set(int v) => store.update(() => d.byWeight ? d.kg = v : d.m3 = v);
    // Boutons et raccourcis : le champ reprend la nouvelle valeur.
    void pick(int v) {
      _amount.text = '$v';
      set(v);
    }

    final error = !_tried || value > 0 ? null : (d.byWeight ? 'Indique le poids de ta marchandise.' : 'Indique le volume de ta marchandise.');

    return Screen(
      top: const TopBar('Nouvelle demande'),
      steps: const StepHeader(2, 5, 'Marchandise'),
      padding: const EdgeInsets.all(16),
      gap: 16,
      foot: [
        Cta(
          'Continuer',
          onTap: () {
            setState(() => _tried = true);
            if (value <= 0) return;
            // Le véhicule conseillé est présélectionné selon le poids.
            if (d.byWeight) store.update(() => d.vehicle = Vehicle.forWeight(d.kg));
            context.go(R.cVehicule);
          },
        ),
      ],
      children: [
        Semantics(header: true, child: const Text('Qu’est-ce qu’on transporte ?', style: Ts.h1)),
        PillWrap(options: _categories, isOn: (o) => o == d.category, onPick: (o) => store.update(() => d.category = o)),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14,
            children: [
              Row(
                spacing: 12,
                children: [
                  Expanded(child: Text(d.byWeight ? 'Poids estimé' : 'Volume estimé', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
                  Seg(options: const ['Poids', 'Volume'], value: d.byWeight ? 'Poids' : 'Volume', onChanged: (o) {
                    store.update(() => d.byWeight = o == 'Poids');
                    _amount.text = '${d.byWeight ? d.kg : d.m3}';
                  }),
                ],
              ),
              Row(
                spacing: 12,
                children: [
                  IconBtn(LucideIcons.minus, label: 'Diminuer', size: 44, onTap: () => pick(value - step < step ? step : value - step)),
                  // Le chiffre se tape directement, en plus des boutons et des raccourcis.
                  Expanded(
                    child: Container(
                      height: 60,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(kRadius),
                        border: Border.all(color: error != null ? c.danger : c.lineStrong, width: 1.5),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        spacing: 6,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _amount,
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(d.byWeight ? 5 : 3)],
                              onChanged: (v) => set(int.tryParse(v) ?? 0),
                              style: Ts.num(30).copyWith(color: c.ink),
                              decoration: InputDecoration.collapsed(hintText: '0', hintStyle: Ts.num(30).copyWith(color: c.lineStrong)),
                            ),
                          ),
                          Text(d.byWeight ? 'kg' : 'm³', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.muted)),
                        ],
                      ),
                    ),
                  ),
                  IconBtn(LucideIcons.plus, label: 'Augmenter', tone: IbTone.primary, size: 44, onTap: () => pick(value + step)),
                ],
              ),
              if (error != null) _Error(error),
              Row(
                spacing: 6,
                children: [
                  for (final p in presets)
                    Expanded(child: Pill(d.byWeight ? '${p ~/ 1000} t' : '$p m³', height: 32, expand: true, selected: p == value, onTap: () => pick(p))),
                ],
              ),
              const InfoRow(LucideIcons.info, 'Tape le chiffre exact ou choisis un raccourci. Le transporteur vérifie au chargement.', iconSize: 14),
            ],
          ),
        ),
        QuantityStepper(label: 'Nombre de colis', value: d.parcels, onChanged: (v) => store.update(() => d.parcels = v)),
        IfCheckbox(
          label: 'Marchandise fragile',
          description: 'Le transporteur est prévenu de manipuler avec soin.',
          value: d.fragile,
          onChanged: (v) => store.update(() => d.fragile = v),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Row(
              spacing: 12,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Text('Photos de la marchandise', style: Ts.b), Lab('Utiles au transporteur et en cas de litige')],
                  ),
                ),
                Tag('${d.photos.length} sur 6', tone: Tone.neutral),
              ],
            ),
            PhotoStrip(d.photos, onChanged: () => store.update(() {})),
          ],
        ),
      ],
    );
  }
}

/// Étape 3 : type de véhicule.
class VehiculeScreen extends StatelessWidget {
  const VehiculeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final d = store.draft;
    final suggested = d.byWeight ? Vehicle.forWeight(d.kg) : null;
    final tooHeavy = d.byWeight && d.kg > d.vehicle.maxKg;
    return Screen(
      top: const TopBar('Nouvelle demande'),
      steps: const StepHeader(3, 5, 'Véhicule'),
      padding: const EdgeInsets.all(16),
      gap: 12,
      foot: [Cta('Continuer', onTap: tooHeavy ? null : () => context.go(R.cDetails))],
      children: [
        Heading(
          'Quel véhicule ?',
          sub: suggested == null ? 'Choisis le véhicule adapté à ton volume.' : 'Pour ${d.load} de ${d.category.toLowerCase()}, on te conseille : ${suggested.name.toLowerCase()}.',
        ),
        for (final v in Vehicle.values)
          Opt(
            selected: v == d.vehicle,
            onTap: () => store.update(() => d.vehicle = v),
            child: Row(
              spacing: 12,
              children: [
                VehicleImg(v, imageWidth: 88),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(v.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      Lab(v.capacity),
                      if (v == suggested) const Padding(padding: EdgeInsets.only(top: 4), child: Tag('Conseillé', height: 22)),
                    ],
                  ),
                ),
                Rad(v == d.vehicle),
              ],
            ),
          ),
        if (tooHeavy) _Error('${d.vehicle.name} : trop petit pour ${d.load}. Choisis un véhicule plus grand.'),
      ],
    );
  }
}

/// Étape 4 : date du transport et destinataire.
class DetailsScreen extends StatefulWidget {
  const DetailsScreen({super.key});

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  bool _tried = false;

  /// Date puis heure du départ. Fermer l'une des deux fenêtres ne change rien.
  Future<void> _schedule() async {
    final store = context.store;
    final now = DateTime.now();
    final current = store.draft.scheduled ?? now.add(const Duration(days: 1));
    final day = await showDatePicker(context: context, initialDate: current, firstDate: now, lastDate: now.add(const Duration(days: 60)), helpText: 'Jour du chargement');
    if (day == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay(hour: store.draft.scheduled?.hour ?? 8, minute: store.draft.scheduled?.minute ?? 30), helpText: 'Heure du chargement');
    if (time == null) return;
    store.update(() => store.draft.scheduled = DateTime(day.year, day.month, day.day, time.hour, time.minute));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final d = store.draft;
    final l10n = MaterialLocalizations.of(context);
    final nameError = requiredError(d.recipientName, 'Indique le nom du destinataire.');
    final numberError = phoneError(d.recipientPhone);

    Widget when({required bool now, required IconData icon, required String label, required String sub, required VoidCallback onTap}) => Expanded(
          child: Opt(
            selected: (d.scheduled == null) == now,
            onTap: onTap,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Icon(icon, size: 22), Rad((d.scheduled == null) == now)]),
                const SizedBox(height: 18),
                Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                Lab(sub),
              ],
            ),
          ),
        );

    return Screen(
      top: const TopBar('Nouvelle demande'),
      steps: const StepHeader(4, 5, 'Date et destinataire'),
      padding: const EdgeInsets.all(16),
      foot: [
        Cta(
          'Voir le prix',
          onTap: () {
            setState(() => _tried = true);
            if (nameError == null && numberError == null) context.go(R.cRecap);
          },
        ),
      ],
      children: [
        Semantics(header: true, child: const Text('Quand, et pour qui ?', style: Ts.h1)),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: [
              when(now: true, icon: LucideIcons.clock, label: 'Maintenant', sub: 'Dès qu’un transporteur accepte', onTap: () => store.update(() => d.scheduled = null)),
              when(
                now: false,
                icon: LucideIcons.calendar,
                label: 'Programmer',
                sub: d.scheduled == null ? 'Choisir le jour et l’heure' : '${l10n.formatMediumDate(d.scheduled!)} · ${l10n.formatTimeOfDay(TimeOfDay.fromDateTime(d.scheduled!), alwaysUse24HourFormat: true)}',
                onTap: _schedule,
              ),
            ],
          ),
        ),
        Padding(padding: const EdgeInsets.only(top: 4), child: Semantics(header: true, child: const Text('Destinataire', style: Ts.h2))),
        IfTextField(
          label: 'Nom',
          initialValue: d.recipientName,
          icon: LucideIcons.user,
          autofillHints: const [AutofillHints.name],
          error: _tried ? nameError : null,
          onChanged: (v) => setState(() => d.recipientName = v),
        ),
        PhoneField(
          label: 'Numéro',
          initialValue: d.recipientPhone,
          hint: 'Il reçoit par SMS le lien de suivi et son code de livraison.',
          error: _tried ? numberError : null,
          onChanged: (v) => setState(() => d.recipientPhone = v),
        ),
        IfCheckbox(
          label: 'Besoin de manutention',
          description: 'Aide au chargement ou au déchargement.',
          value: d.handling,
          onChanged: (v) => store.update(() => d.handling = v),
        ),
      ],
    );
  }
}

/// Étape 5 : fourchette de prix, acompte et récapitulatif.
class RecapScreen extends StatelessWidget {
  const RecapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final d = context.store.draft;
    final l10n = MaterialLocalizations.of(context);
    final when = d.scheduled == null ? 'maintenant' : '${l10n.formatMediumDate(d.scheduled!)}, ${l10n.formatTimeOfDay(TimeOfDay.fromDateTime(d.scheduled!), alwaysUse24HourFormat: true)}';
    return Screen(
      top: const TopBar('Nouvelle demande'),
      steps: const StepHeader(5, 5, 'Prix'),
      padding: const EdgeInsets.all(16),
      gap: 12,
      foot: [Cta('Confirmer et payer l’acompte', onTap: () => context.go(R.cPaiement))],
      children: [
        AppCard(
          tone: CardTone.yellow,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [const Flexible(child: Text('Prix estimé de ta course', style: Ts.small)), Tag('${d.km} km', tone: Tone.dark)],
              ),
              LayoutBuilder(
                builder: (context, box) {
                  final size = box.maxWidth < 300 ? 24.0 : 30.0;
                  // Les deux prix sont déjà en très grand : ils ne suivent pas l'agrandissement du texte, sinon la ligne déborde.
                  Widget price(String label, int value) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [Text(label, style: Ts.lab), Text(formatNumber(value), textScaler: TextScaler.noScaling, style: Ts.num(size).copyWith(height: 34 / 30))],
                      );
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    spacing: 10,
                    children: [
                      price('De', d.priceMin),
                      const Expanded(child: Padding(padding: EdgeInsets.only(bottom: 15), child: DashLine())),
                      price('À', d.priceMax),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 5),
                        child: Text('FCFA', textScaler: TextScaler.noScaling, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  );
                },
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(kRadius)),
                child: Row(
                  spacing: 12,
                  children: [
                    const Ic(LucideIcons.handCoins, size: 36, iconSize: 18),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [Text('Acompte à payer', style: Ts.b), Lab('50 % maintenant · le solde à l’arrivée')],
                      ),
                    ),
                    Text(money(d.deposit), style: Ts.num(17)),
                  ],
                ),
              ),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  Padding(padding: EdgeInsets.only(top: 1), child: Icon(LucideIcons.info, size: 14)),
                  Expanded(child: Text('Le prix final dépend des frais imprévus validés par ILT.', style: Ts.lab)),
                ],
              ),
            ],
          ),
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14,
            children: [
              RoutePoints(fromLabel: 'Chargement · $when', from: d.pickup.name, toLabel: 'Livraison · ${d.km} km', to: d.to.name),
              const Hr(),
              Row(
                spacing: 12,
                children: [
                  VehicleImg(d.vehicle, width: 84, height: 60, imageWidth: 80),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.vehicle.name, style: Ts.b),
                        Lab(d.cargo + (d.fragile ? ' · fragile' : '')),
                        Lab('Pour ${d.recipientName} · ${d.handling ? 'avec' : 'sans'} manutention'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Lab('Annulation gratuite tant qu’aucun transporteur n’a accepté. Ensuite, une partie de l’acompte est retenue selon le barème.'),
        ),
      ],
    );
  }
}

/// Paiement de l'acompte par Mobile Money.
class PaiementScreen extends StatefulWidget {
  const PaiementScreen({super.key});

  @override
  State<PaiementScreen> createState() => _PaiementScreenState();
}

class _PaiementScreenState extends State<PaiementScreen> {
  String? _operator;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final account = store.accountOf(Role.chargeur);
    final operator = _operator ?? account.operator;
    final deposit = store.draft.deposit;
    return Screen(
      top: const TopBar('Payer l’acompte'),
      gap: 16,
      foot: [
        AsyncCta(
          'Payer ${money(deposit)}',
          action: () {
            final course = store.confirmDraft(operator);
            // Après le paiement, « retour » ramène à l'accueil, pas à l'écran de paiement.
            Navigator.pushNamedAndRemoveUntil(context, R.cRecherche, ModalRoute.withName(R.c), arguments: course.ref);
          },
        ),
      ],
      children: [
        AppCard(
          tone: CardTone.soft,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
          child: Column(
            spacing: 4,
            children: [
              const Tag('Acompte · 50 %'),
              Padding(padding: const EdgeInsets.only(top: 6), child: Amount(formatNumber(deposit), size: 38, unitSize: 16)),
              const Lab('Le solde se paie à l’arrivée, avant le déchargement.', align: TextAlign.center),
            ],
          ),
        ),
        PaymentMethodPicker(value: operator, onChanged: (m) => setState(() => _operator = m), phone: account.phone),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: InfoRow(LucideIcons.lock, 'Tu valides le débit sur ton téléphone avec ton code PIN Mobile Money. i-fret ne voit jamais ton code.'),
        ),
      ],
    );
  }
}

/// Recherche du transporteur : ondes qui partent du camion.
class RechercheScreen extends StatelessWidget {
  const RechercheScreen({super.key, this.courseRef});
  final String? courseRef;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final store = context.store;
    final course = store.course(courseRef);
    Widget ring(double phase) => Loop(
          duration: const Duration(milliseconds: 2400),
          phase: phase,
          builder: (context, t, child) {
            final e = kEase.transform(t);
            return Opacity(opacity: 1 - e, child: Transform.scale(scale: .25 + .75 * e, child: child));
          },
          child: Container(decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.lineStrong, width: 1.5))),
        );
    Widget nearby(double phase) => Loop(
          duration: const Duration(milliseconds: 1100),
          phase: phase,
          builder: (context, t, child) => Transform.translate(offset: Offset(0, -3 * (1 - (2 * t - 1).abs())), child: child),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle, boxShadow: [BoxShadow(color: c.shadow, blurRadius: 12, offset: const Offset(0, 4))]),
            child: const Icon(LucideIcons.truck, size: 18),
          ),
        );
    Widget disc(double inset, Color color) => Positioned.fill(
          child: Padding(padding: EdgeInsets.all(inset), child: DecoratedBox(decoration: BoxDecoration(color: color, shape: BoxShape.circle))),
        );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kContentMax),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 56,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(child: Tag('Acompte payé · ${money(course.deposit)}', tone: Tone.success, icon: LucideIcons.circleCheck, height: 32)),
                        TextLink('Reçu', onTap: () => context.go(R.cRecu, args: course.ref)),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: ExcludeSemantics(
                    child: RepaintBoundary(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: SizedBox(
                            width: 300,
                            height: 300,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Positioned.fill(child: ring(0)),
                                Positioned.fill(child: ring(1 / 3)),
                                Positioned.fill(child: ring(2 / 3)),
                                disc(40, c.fillSoft),
                                disc(90, c.track),
                                Container(
                                  width: 84,
                                  height: 84,
                                  decoration: BoxDecoration(
                                    color: c.primary,
                                    shape: BoxShape.circle,
                                    boxShadow: const [BoxShadow(color: Color(0x291E1E1E), blurRadius: 20, offset: Offset(0, 8))],
                                  ),
                                  child: Icon(LucideIcons.truck, size: 32, color: c.onPrimary),
                                ),
                                Positioned(left: 34, top: 70, child: nearby(0)),
                                Positioned(right: 30, bottom: 84, child: nearby(.36)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 10,
                    children: [
                      const Tag('Rayon 5 km · palier 1 sur 3', tone: Tone.neutral),
                      Semantics(header: true, liveRegion: true, child: const Text('On cherche ton transporteur…', style: Ts.h1)),
                      Sub('Ta demande ${course.ref} est partie aux transporteurs vérifiés autour de ${course.from.name}. Le premier qui accepte prend la mission.'),
                      const SizedBox(height: 6),
                      // Aperçu de la maquette : en production, l'acceptation arrive du serveur.
                      Cta(
                        'Aperçu : un transporteur accepte',
                        tone: CtaTone.outline,
                        onTap: () {
                          store.carrierAccepts(course);
                          Navigator.pushReplacementNamed(context, R.cSuivi, arguments: course.ref);
                        },
                      ),
                      LinkBtn('Annuler la demande', onTap: () => context.go(R.cAnnulation, args: course.ref)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
