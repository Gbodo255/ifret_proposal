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

// Inscription du transporteur : véhicule, documents, puis attente de la vérification ILT.
// Les deux premiers écrans servent aussi, depuis le profil, à mettre à jour le dossier.

/// Véhicule du transporteur.
class TVehiculeScreen extends StatefulWidget {
  const TVehiculeScreen({super.key, this.editing = false});

  /// Ouvert depuis le profil : pas d'étapes, on enregistre et on revient.
  final bool editing;

  @override
  State<TVehiculeScreen> createState() => _TVehiculeScreenState();
}

class _TVehiculeScreenState extends State<TVehiculeScreen> {
  bool _tried = false;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final plateError = requiredError(store.plate, 'Indique la plaque.');
    final capacityError = (int.tryParse(store.capacity) ?? 0) <= 0 ? 'Indique la capacité.' : null;
    final photosError = store.vehiclePhotos.isEmpty ? 'Ajoute au moins une photo du véhicule.' : null;

    Widget option(Vehicle v) => Expanded(
          child: Opt(
            selected: v == store.vehicle,
            onTap: () => store.update(() => store.vehicle = v),
            padding: const EdgeInsets.all(12),
            child: Column(
              spacing: 6,
              children: [
                Row(
                  spacing: 8,
                  children: [
                    Expanded(child: Text(v == Vehicle.semi ? v.name : v.short, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ts.b)),
                    Rad(v == store.vehicle),
                  ],
                ),
                VehicleImg(v, width: null, height: 58, imageWidth: 92),
              ],
            ),
          ),
        );
    return Screen(
      top: TopBar(widget.editing ? 'Mon véhicule' : 'Inscription transporteur'),
      steps: widget.editing ? null : const StepHeader(4, 5, 'Véhicule'),
      padding: const EdgeInsets.all(16),
      foot: [
        AsyncCta(
          widget.editing ? 'Enregistrer' : 'Continuer',
          validate: () {
            setState(() => _tried = true);
            return plateError == null && capacityError == null && photosError == null;
          },
          action: () {
            if (!widget.editing) return context.go(R.tDossier);
            toast(context, 'Véhicule enregistré');
            Navigator.pop(context);
          },
        ),
      ],
      children: [
        const Heading('Ton véhicule', sub: 'C’est lui qui décide des missions que tu reçois.'),
        Column(
          spacing: 10,
          children: [
            Row(spacing: 10, children: [option(Vehicle.tricycle), option(Vehicle.van)]),
            Row(spacing: 10, children: [option(Vehicle.truck), option(Vehicle.semi)]),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 10,
          children: [
            Expanded(
              flex: 3,
              child: IfTextField(label: 'Plaque', initialValue: store.plate, placeholder: 'AB 1234 RB', error: _tried ? plateError : null, onChanged: (v) => setState(() => store.plate = v.toUpperCase())),
            ),
            Expanded(
              flex: 2,
              child: IfTextField(
                label: 'Capacité',
                initialValue: store.capacity,
                suffix: 't',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
                error: _tried ? capacityError : null,
                onChanged: (v) => setState(() => store.capacity = v),
              ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            const Text('Photos du véhicule', style: Ts.b),
            PhotoStrip(store.vehiclePhotos, max: 4, onChanged: () => store.update(() {})),
            if (_tried && photosError != null)
              Text(photosError, style: Ts.small.copyWith(fontWeight: FontWeight.w600, color: context.c.danger))
            else
              const Lab('Avant, arrière, côté et plateau. La plaque doit être lisible.'),
          ],
        ),
      ],
    );
  }
}

const _documents = [
  (LucideIcons.idCard, 'Pièce d’identité', 'CNI ou passeport · recto verso'),
  (LucideIcons.badgeCheck, 'Permis de conduire', 'Expire le 14 mars 2029'),
  (LucideIcons.fileText, 'Carte grise', 'Au nom du propriétaire du véhicule'),
  (LucideIcons.shieldCheck, 'Assurance du véhicule', 'En cours de validité'),
  (LucideIcons.scrollText, 'Visite technique', 'Dernier contrôle'),
];

/// Pièces du dossier : chaque pièce se photographie depuis l'application.
class TDossierScreen extends StatefulWidget {
  const TDossierScreen({super.key, this.editing = false});
  final bool editing;

  @override
  State<TDossierScreen> createState() => _TDossierScreenState();
}

class _TDossierScreenState extends State<TDossierScreen> {
  bool _tried = false;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final added = store.documents;
    final missing = _documents.length - added.length;

    Future<void> capture(int i) async {
      final path = await pickPhoto(context);
      if (path != null) store.update(() => added.add(i));
    }

    return Screen(
      top: TopBar(widget.editing ? 'Mes documents' : 'Inscription transporteur'),
      steps: widget.editing ? null : const StepHeader(5, 5, 'Documents'),
      padding: const EdgeInsets.all(16),
      gap: 10,
      foot: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Lab('${added.length} pièces sur ${_documents.length}'),
              SizedBox(width: 120, child: ProgressBar(added.length / _documents.length)),
            ],
          ),
        ),
        if (_tried && missing > 0)
          Semantics(
            liveRegion: true,
            child: Text(
              missing == 1 ? 'Il manque encore 1 pièce : ILT ne vérifie qu’un dossier complet.' : 'Il manque encore $missing pièces : ILT ne vérifie qu’un dossier complet.',
              style: Ts.small.copyWith(fontWeight: FontWeight.w600, color: context.c.danger),
            ),
          ),
        if (widget.editing)
          Cta('Terminé', onTap: () => Navigator.pop(context))
        else
          AsyncCta(
            'Envoyer mon dossier',
            validate: () {
              setState(() => _tried = true);
              return missing == 0;
            },
            action: () => context.reset(R.tAttente),
          ),
      ],
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: Heading('Tes documents', sub: 'Une photo nette de chaque pièce. ILT les vérifie avant d’ouvrir ton compte.'),
        ),
        for (final (i, (icon, title, detail)) in _documents.indexed)
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Li(
              icon: icon,
              title: title,
              subtitle: detail,
              padding: EdgeInsets.zero,
              trailing: added.contains(i)
                  ? Tag('Ajouté', tone: Tone.success, icon: LucideIcons.check, onTap: () => capture(i))
                  : Tag('Ajouter', tone: Tone.dark, icon: LucideIcons.camera, onTap: () => capture(i)),
            ),
          ),
        const Padding(padding: EdgeInsets.all(4), child: InfoRow(LucideIcons.lock, 'Tes documents ne sont vus que par l’équipe ILT. Touche une pièce ajoutée pour la reprendre.')),
      ],
    );
  }
}

/// Dossier envoyé, en attente de vérification.
class TAttenteScreen extends StatelessWidget {
  const TAttenteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return Screen(
      top: SizedBox(
        height: 56,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Logo(height: 28),
              Tag('Aide', tone: Tone.outline, icon: LucideIcons.headset, height: 36, onTap: () => context.go(R.tAide)),
            ],
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      gap: 16,
      // Aperçu de la maquette : en production, la validation arrive d'ILT.
      foot: [
        Cta(
          'Aperçu : dossier validé',
          tone: CtaTone.outline,
          onTap: () {
            store.update(() => store.dossierValidated = true);
            context.home(Role.transporteur);
          },
        ),
      ],
      children: [
        AppCard(
          tone: CardTone.yellow,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              const Ic(LucideIcons.shieldCheck, bg: Colors.white),
              Padding(padding: const EdgeInsets.only(top: 8), child: Semantics(header: true, child: const Text('ILT vérifie ton dossier', style: Ts.h1))),
              const Text('On te prévient par SMS dès que c’est fait. Tu recevras tes premières missions juste après.'),
              const Padding(padding: EdgeInsets.only(top: 6), child: Tag('Dossier envoyé', tone: Tone.dark)),
            ],
          ),
        ),
        AppCard(
          child: Column(
            spacing: 16,
            children: [
              CheckStep(const Ck.done(), 'Compte et véhicule', '${store.vehicle.name} · ${store.plate}'),
              const CheckStep(Ck.done(), 'Documents reçus', '5 pièces sur 5'),
              const CheckStep(Ck.now(), 'Vérification par ILT', 'En cours'),
              const CheckStep(Ck.todo(), 'Compte activé', 'Tu pourras passer en ligne'),
            ],
          ),
        ),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Lab('Délai habituel : moins de 24 h les jours ouvrés.')),
      ],
    );
  }
}
