import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/store.dart';
import '../../routes.dart';
import '../../services/device.dart';
import '../../theme/tokens.dart';
import '../../widgets/brand.dart';
import '../../widgets/extras.dart';
import '../../widgets/forms.dart';
import '../../widgets/layout.dart';
import '../../widgets/ui.dart';

// Vie d'une mission côté transporteur : proposition, chargement, arrivée, livraison par code.

/// Détail d'une mission proposée.
class TMissionScreen extends StatelessWidget {
  const TMissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    Widget fact(String label, String value) => Expanded(
          child: AppCard(
            tone: CardTone.soft,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Lab(label, maxLines: 1), Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ts.b)],
            ),
          ),
        );
    return MapSheetScreen(
      mapFraction: .34,
      pickup: Mock.port,
      dropoff: Mock.arzeke,
      gap: 12,
      overlay: [
        IconBtn(LucideIcons.arrowLeft, label: 'Retour', tone: IbTone.floating, onTap: () => Navigator.maybePop(context)),
        const Tag('Expire dans 0:45', tone: Tone.warning, icon: LucideIcons.timer, shadow: true),
      ],
      foot: [
        Row(
          spacing: 8,
          children: [
            Expanded(
              child: Cta(
                'Refuser',
                tone: CtaTone.outline,
                onTap: () {
                  store.update(() => store.mission = MissionStep.declined);
                  Navigator.maybePop(context);
                },
              ),
            ),
            Expanded(
              flex: 2,
              child: AsyncCta(
                'Accepter la mission',
                action: () {
                  store.update(() => store.mission = MissionStep.loading);
                  Navigator.pushReplacementNamed(context, R.tChargement);
                },
              ),
            ),
          ],
        ),
      ],
      children: [
        AppCard(
          tone: CardTone.yellow,
          child: Row(
            spacing: 12,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [const Text('Ta rémunération', style: Ts.small), Amount(formatNumber(88000), size: 30)],
                ),
              ),
              const Text('Versée après\nla livraison', textAlign: TextAlign.right, style: Ts.lab),
            ],
          ),
        ),
        const AppCard(
          child: RoutePoints(
            fromLabel: 'Chargement · aujourd’hui 09:00 · à 3,2 km',
            from: 'Port autonome de Cotonou',
            toLabel: 'Livraison · 415 km · environ 7 h',
            to: 'Marché Arzèkè, Parakou',
          ),
        ),
        Row(spacing: 8, children: [fact('Marchandise', 'Matériaux'), fact('Poids', '8 t'), fact('Colis', '120')]),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            spacing: 8,
            children: [
              Icon(LucideIcons.users, size: 16, color: context.c.muted),
              const Expanded(child: Lab('Manutention demandée · 2 photos jointes')),
              TextLink(
                'Voir',
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  builder: (context) => const SafeArea(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 12,
                        children: [Text('Photos de la marchandise', style: Ts.h2), PhotoStrip(['demo', 'demo']), Lab('Photos jointes par le chargeur à sa demande.')],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

typedef _Gap = (String kind, int amount, String note);

/// Sur place : vérification, écart éventuel, photos.
class TChargementScreen extends StatefulWidget {
  const TChargementScreen({super.key});

  @override
  State<TChargementScreen> createState() => _TChargementScreenState();
}

class _TChargementScreenState extends State<TChargementScreen> {
  final _gaps = <_Gap>[('Surpoids', 8000, '8,6 t pesées au lieu de 8 t · ticket de pesée joint.')];
  bool _tried = false;

  /// Feuille de déclaration d'un écart : type, montant demandé, explication.
  void _declare() {
    var kind = 'Surpoids';
    var amount = '';
    var note = '';
    var tried = false;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) {
          final amountError = (int.tryParse(amount) ?? 0) <= 0 ? 'Indique le montant demandé.' : null;
          final noteError = requiredError(note, 'Explique l’écart en une phrase.');
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 14,
                children: [
                  const Text('Déclarer un écart', style: Ts.h2),
                  PillWrap(options: const ['Surpoids', 'Attente', 'Colis en plus'], isOn: (o) => o == kind, onPick: (o) => setSheet(() => kind = o)),
                  IfTextField(
                    label: 'Montant demandé',
                    suffix: 'FCFA',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                    error: tried ? amountError : null,
                    onChanged: (v) => setSheet(() => amount = v),
                  ),
                  IfTextField(label: 'Explication', placeholder: 'Ex. : 8,6 t pesées au lieu de 8 t', error: tried ? noteError : null, onChanged: (v) => setSheet(() => note = v)),
                  Cta(
                    'Envoyer à ILT',
                    onTap: () {
                      setSheet(() => tried = true);
                      if (amountError != null || noteError != null) return;
                      setState(() => _gaps.add((kind, int.parse(amount), note.trim())));
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final shipper = store.chargeur;
    final enough = store.loadingPhotos.length >= 2;
    return Screen(
      top: const TopBar('Chargement', trailing: Tag('Sur place')),
      foot: [
        AsyncCta(
          'Chargement terminé, je pars',
          validate: () {
            setState(() => _tried = true);
            return enough;
          },
          action: () {
            store.update(() => store.mission = MissionStep.arrived);
            context.go(R.tArrivee);
          },
        ),
      ],
      children: [
        AppCard(
          tone: CardTone.soft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              Row(
                spacing: 12,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [Text('Port autonome de Cotonou', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)), Lab('Magasin B, portail 3')],
                    ),
                  ),
                  IconBtn(LucideIcons.navigation, label: 'Lancer l’itinéraire', tone: IbTone.floating, onTap: () => openNavigation(context, Mock.port, store.navApp)),
                ],
              ),
              Row(
                spacing: 12,
                children: [
                  Avatar(shipper.name, size: 32),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(shipper.name, style: Ts.b), const Lab('Chargeur')]),
                  ),
                  IconBtn(LucideIcons.phone, label: 'Appeler ${shipper.firstName}', tone: IbTone.outline, onTap: () => callNumber(context, shipper.phone)),
                  IconBtn(LucideIcons.messageCircle, label: 'Écrire à ${shipper.firstName}', tone: IbTone.primary, onTap: () => context.go(R.chat, args: 'koffi')),
                ],
              ),
            ],
          ),
        ),
        AppCard(
          child: Column(
            spacing: 18,
            children: [
              const CheckStep(Ck.done(), 'Marchandise vérifiée', 'Matériaux · 120 colis comptés'),
              CheckStep(
                const Ck.n(2),
                'Un écart ? Déclare-le',
                'Surpoids, attente, colis en plus…',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 8,
                  children: [
                    for (final (kind, amount, note) in _gaps)
                      AppCard(
                        tone: CardTone.soft,
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: 4,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              spacing: 8,
                              children: [
                                Flexible(child: Tag('$kind · envoyé à ILT', tone: Tone.warning, height: 22)),
                                Text('+ ${formatNumber(amount)}', style: Ts.num()),
                              ],
                            ),
                            Lab('$note ILT valide avant le paiement du solde.'),
                          ],
                        ),
                      ),
                    Align(alignment: Alignment.centerLeft, child: Tag('Déclarer un écart', tone: Tone.outline, icon: LucideIcons.plus, height: 32, onTap: _declare)),
                  ],
                ),
              ),
              CheckStep(
                const Ck.n(3),
                'Photos du chargement',
                'Au moins 2 photos : elles te protègent en cas de litige.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 6,
                  children: [
                    PhotoStrip(store.loadingPhotos, onChanged: () => store.update(() {})),
                    if (_tried && !enough) Text('Prends au moins 2 photos avant de partir.', style: Ts.small.copyWith(fontWeight: FontWeight.w600, color: context.c.danger)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Arrivé à destination : attente du paiement du solde.
class TArriveeScreen extends StatelessWidget {
  const TArriveeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final course = store.course('IFR-2611-0042');
    return MapSheetScreen(
      mapFraction: .42,
      pickup: Mock.port,
      dropoff: Mock.arzeke,
      progress: 1,
      overlay: [
        IconBtn(LucideIcons.arrowLeft, label: 'Retour', tone: IbTone.floating, onTap: () => Navigator.maybePop(context)),
        const Tag('Arrivé · 16:38', tone: Tone.floating),
      ],
      foot: [
        // Aperçu de la maquette : en production, le paiement est confirmé par le serveur.
        Cta(
          'Aperçu : solde payé',
          tone: CtaTone.outline,
          onTap: () {
            store.update(() => store.mission = MissionStep.paid);
            context.go(R.tLivraison);
          },
        ),
        LinkBtn('Signaler un problème', onTap: () => context.go(R.tSignalement)),
      ],
      children: [
        const Tag('En attente du solde', tone: Tone.warning),
        Semantics(header: true, child: const Text('Tu es arrivé.\nNe décharge pas encore.', style: Ts.h1)),
        AppCard(
          tone: CardTone.soft,
          child: Row(
            spacing: 12,
            children: [
              const Ck.now(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Text('${store.chargeur.firstName} règle le solde', style: Ts.b), const Lab('Tu es prévenu ici dès que le paiement est confirmé.')],
                ),
              ),
            ],
          ),
        ),
        Row(
          spacing: 12,
          children: [
            Avatar(course.recipient, size: 32),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(course.recipient, style: Ts.b), const Lab('Destinataire · Marché Arzèkè')]),
            ),
            IconBtn(LucideIcons.phone, label: 'Appeler ${course.recipient}', tone: IbTone.outline, onTap: () => callNumber(context, '0196000034')),
          ],
        ),
      ],
    );
  }
}

/// Livraison : saisie du code à quatre chiffres donné par le destinataire.
class TLivraisonScreen extends StatefulWidget {
  const TLivraisonScreen({super.key});

  @override
  State<TLivraisonScreen> createState() => _TLivraisonScreenState();
}

class _TLivraisonScreenState extends State<TLivraisonScreen> {
  final _code = TextEditingController();
  int _tries = 3;
  bool _wrong = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  // shortcut: code comparé sur l'appareil, à remplacer par la vérification côté serveur (qui compte aussi les essais).
  void _validate() {
    final store = context.store;
    if (_code.text == store.course('IFR-2611-0042').code) {
      store.deliverMission();
      context.go(R.tNotation);
      return;
    }
    setState(() {
      _tries--;
      _wrong = true;
      _code.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final store = context.store;
    final ready = _code.text.length == 4 && _tries > 0;
    return Screen(
      top: const TopBar('Livraison'),
      gap: 16,
      foot: [
        AsyncCta('Valider la livraison', enabled: ready, action: _validate),
        if (_tries == 0) LinkBtn('Appeler l’assistance ILT', icon: LucideIcons.phone, onTap: () => callNumber(context, kAssistancePhone)),
      ],
      children: [
        const Tag('Solde payé · tu peux décharger', tone: Tone.success, icon: LucideIcons.circleCheck, height: 32),
        const Heading('Le code de livraison', sub: 'Le destinataire l’a reçu par SMS. Demande-le une fois la marchandise déchargée.'),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: OtpInput(length: 4, large: true, controller: _code, label: 'Code de livraison', onChanged: (_) => setState(() => _wrong = false)),
        ),
        if (_wrong)
          Semantics(
            liveRegion: true,
            child: Text(
              _tries > 0 ? 'Code incorrect. Il te reste $_tries ${_tries > 1 ? 'essais' : 'essai'}.' : 'Code incorrect trois fois. Appelle l’assistance ILT.',
              textAlign: TextAlign.center,
              style: Ts.small.copyWith(fontWeight: FontWeight.w600, color: c.danger),
            ),
          )
        else
          const InfoRow(LucideIcons.lock, '3 essais possibles · sinon appelle l’assistance ILT', center: true),
        const Hr(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [const Text('Photos de la marchandise livrée', style: Ts.b), PhotoStrip(store.deliveryPhotos, onChanged: () => store.update(() {}))],
        ),
      ],
    );
  }
}
