import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/store.dart';
import '../routes.dart';
import '../theme/tokens.dart';
import '../widgets/brand.dart';
import '../widgets/extras.dart';
import '../widgets/forms.dart';
import '../widgets/layout.dart';
import '../widgets/ui.dart';

// Inscription : choix du compte, numéro, code SMS, identité. Le transporteur enchaîne
// ensuite sur son véhicule et ses documents.

/// Nombre d'étapes de l'inscription selon le compte.
int _steps(Role role) => role == Role.chargeur ? 3 : 5;

/// Choix du compte : chargeur ou transporteur.
class CompteScreen extends StatelessWidget {
  const CompteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Widget choice(String title, String text, String account, {bool muted = false}) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            Padding(padding: const EdgeInsets.only(top: 10), child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
            muted ? Sub(text) : Text(text),
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(spacing: 12, children: [Flexible(child: Text(account, style: Ts.b)), const Icon(LucideIcons.arrowRight, size: 18)]),
            ),
          ],
        );

    return Screen(
      top: const Padding(padding: EdgeInsets.fromLTRB(20, 20, 20, 0), child: Align(alignment: Alignment.centerLeft, child: Logo(height: 32))),
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 16),
      gap: 12,
      foot: const [Lab('i-fret, un service ILT', align: TextAlign.center)],
      children: [
        const Padding(padding: EdgeInsets.only(bottom: 12), child: Heading('Bienvenue sur i-fret', sub: 'Choisis ton compte pour commencer.')),
        AppCard(
          tone: CardTone.yellow,
          padding: const EdgeInsets.all(20),
          onTap: () => context.go(R.telephone, args: Role.chargeur),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Ic(LucideIcons.package, bg: Colors.white),
              choice('J’expédie une marchandise', 'Je décris mon envoi et i-fret me trouve un transporteur vérifié.', 'Compte chargeur'),
            ],
          ),
        ),
        AppCard(
          padding: const EdgeInsets.fromLTRB(20, 20, 10, 16),
          onTap: () => context.go(R.telephone, args: Role.transporteur),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Ic(LucideIcons.truck),
              // Le texte prend la place que laisse le camion : rien ne se chevauche, quelle que soit la largeur.
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                spacing: 8,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: choice('Je transporte', 'J’ai un véhicule et je reçois des missions près de moi.', 'Compte transporteur', muted: true),
                    ),
                  ),
                  const VehicleImg(Vehicle.truck, width: 128, height: 92, imageWidth: 128),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Étape 1 : numéro de téléphone.
class TelephoneScreen extends StatefulWidget {
  const TelephoneScreen({super.key, required this.role});
  final Role role;

  @override
  State<TelephoneScreen> createState() => _TelephoneScreenState();
}

class _TelephoneScreenState extends State<TelephoneScreen> {
  String _phone = '';
  bool _tried = false;

  @override
  Widget build(BuildContext context) => Screen(
        top: const TopBar('Inscription'),
        steps: StepHeader(1, _steps(widget.role), 'Numéro'),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        gap: 16,
        foot: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Lab('En continuant, tu acceptes les '),
                InkWell(
                  onTap: () => context.go(R.conditions),
                  child: Text('conditions d’utilisation', style: Ts.lab.copyWith(color: context.c.muted, decoration: TextDecoration.underline)),
                ),
                const Lab('.'),
              ],
            ),
          ),
          AsyncCta(
            'Recevoir le code',
            validate: () {
              setState(() => _tried = true);
              return phoneError(_phone) == null;
            },
            action: () => context.go(R.code, args: (widget.role, _phone)),
          ),
        ],
        children: [
          const Heading('Ton numéro de téléphone', sub: 'C’est lui qui identifie ton compte i-fret.'),
          PhoneField(
            hint: 'On t’envoie un code par SMS pour vérifier que c’est bien toi.',
            error: _tried ? phoneError(_phone) : null,
            onChanged: (v) => setState(() => _phone = v),
          ),
        ],
      );
}

/// Étape 2 : code reçu par SMS.
class CodeScreen extends StatefulWidget {
  const CodeScreen({super.key, required this.role, required this.phone});
  final Role role;
  final String phone;

  @override
  State<CodeScreen> createState() => _CodeScreenState();
}

class _CodeScreenState extends State<CodeScreen> {
  static const _wait = 45;
  String _code = '';
  bool _tried = false;
  int _left = _wait;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _countdown();
  }

  void _countdown() {
    _timer?.cancel();
    setState(() => _left = _wait);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _left--);
      if (_left == 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final incomplete = _tried && _code.length < 6;
    return Screen(
      top: const TopBar('Inscription'),
      steps: StepHeader(2, _steps(widget.role), 'Vérification'),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      gap: 16,
      foot: [
        // shortcut: sans serveur, tout code de 6 chiffres est accepté, à remplacer par la vérification du SMS.
        AsyncCta(
          'Vérifier',
          validate: () {
            setState(() => _tried = true);
            return _code.length == 6;
          },
          action: () => context.go(R.identite, args: (widget.role, widget.phone)),
        ),
        LinkBtn('Changer de numéro', onTap: () => Navigator.maybePop(context)),
      ],
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            Semantics(header: true, child: const Text('Le code reçu par SMS', style: Ts.h1)),
            Text.rich(
              TextSpan(
                text: '6 chiffres envoyés au ',
                children: [TextSpan(text: '+229 ${formatPhone(widget.phone)}', style: TextStyle(fontWeight: FontWeight.w600, color: c.ink))],
              ),
              style: TextStyle(color: c.muted),
            ),
          ],
        ),
        OtpInput(label: 'Code SMS', onChanged: (v) => setState(() => _code = v)),
        if (incomplete)
          Semantics(liveRegion: true, child: Text('Saisis les 6 chiffres du code.', style: Ts.small.copyWith(fontWeight: FontWeight.w600, color: c.danger)))
        else if (_left > 0)
          Sub('Pas reçu ? Nouveau code possible dans 0:${_left.toString().padLeft(2, '0')}.')
        else
          Align(
            alignment: Alignment.centerLeft,
            child: TextLink(
              'Renvoyer le code',
              onTap: () {
                _countdown();
                toast(context, 'Nouveau code envoyé au +229 ${formatPhone(widget.phone)}');
              },
            ),
          ),
      ],
    );
  }
}

/// Étape 3 : prénom, nom et coordonnées.
class IdentiteScreen extends StatefulWidget {
  const IdentiteScreen({super.key, required this.role, required this.phone});
  final Role role;
  final String phone;

  @override
  State<IdentiteScreen> createState() => _IdentiteScreenState();
}

class _IdentiteScreenState extends State<IdentiteScreen> {
  String _first = '', _last = '', _email = '', _company = '';
  bool _tried = false;

  String? get _firstError => requiredError(_first, 'Indique ton prénom.');
  String? get _lastError => requiredError(_last, 'Indique ton nom.');

  void _save() {
    final store = context.store;
    store.update(() {
      store.role = widget.role;
      store.profileOf(widget.role)
        ..name = '${_first.trim()} ${_last.trim()}'
        ..phone = widget.phone.isEmpty ? store.profileOf(widget.role).phone : widget.phone
        ..email = _email.trim()
        ..company = _company.trim();
      if (widget.phone.isNotEmpty) store.accountOf(widget.role).phone = widget.phone;
    });
    widget.role == Role.chargeur ? context.home(Role.chargeur) : context.go(R.tVehicule);
  }

  @override
  Widget build(BuildContext context) {
    final shipper = widget.role == Role.chargeur;
    String? shown(String? error) => _tried ? error : null;
    return Screen(
      top: const TopBar('Inscription'),
      steps: StepHeader(3, _steps(widget.role), 'Ton profil'),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      gap: 16,
      foot: [
        AsyncCta(
          shipper ? 'Créer mon compte' : 'Continuer',
          validate: () {
            setState(() => _tried = true);
            return _firstError == null && _lastError == null && emailError(_email) == null;
          },
          action: _save,
        ),
      ],
      children: [
        Heading('Comment t’appelles-tu ?', sub: shipper ? 'Ton nom apparaît sur tes demandes et tes reçus.' : 'Ton nom est montré aux chargeurs quand tu acceptes une mission.'),
        IfTextField(label: 'Prénom', placeholder: 'Koffi', icon: LucideIcons.user, autofillHints: const [AutofillHints.givenName], error: shown(_firstError), onChanged: (v) => setState(() => _first = v)),
        IfTextField(label: 'Nom', placeholder: 'Agossou', icon: LucideIcons.user, autofillHints: const [AutofillHints.familyName], error: shown(_lastError), onChanged: (v) => setState(() => _last = v)),
        if (shipper) IfTextField(label: 'Entreprise (facultatif)', placeholder: 'Nom de ta société', icon: LucideIcons.building2, onChanged: (v) => _company = v),
        IfTextField(
          label: 'E-mail (facultatif)',
          placeholder: 'nom@exemple.com',
          icon: LucideIcons.mail,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          hint: 'Pour recevoir tes reçus.',
          error: shown(emailError(_email)),
          onChanged: (v) => setState(() => _email = v),
        ),
      ],
    );
  }
}

/// Conditions d'utilisation et confidentialité.
// shortcut: résumé des règles déjà présentes dans l'application, à remplacer par le texte juridique validé par ILT.
class ConditionsScreen extends StatelessWidget {
  const ConditionsScreen({super.key});

  static const _sections = [
    ('Le service', 'i-fret met en relation des chargeurs et des transporteurs vérifiés par ILT. ILT contrôle les documents des transporteurs avant d’ouvrir leur compte.'),
    ('Prix et paiement', 'Le prix est annoncé sous forme de fourchette avant la confirmation. Un acompte de 50 % est payé à la commande par Mobile Money, le solde à l’arrivée, avant le déchargement.'),
    ('Frais imprévus', 'Un surpoids, une attente ou des colis en plus peuvent modifier le prix. Chaque ajustement est déclaré par le transporteur et validé par ILT avant le paiement du solde.'),
    ('Annulation', 'L’annulation est gratuite tant qu’aucun transporteur n’a accepté. Ensuite, une partie de l’acompte est retenue selon le barème affiché au moment d’annuler.'),
    ('Livraison', 'Le destinataire reçoit un code à quatre chiffres par SMS. Il le donne au transporteur une fois la marchandise déchargée : c’est ce code qui valide la livraison.'),
    ('Tes données', 'Ton numéro, ton nom et ta position servent à faire fonctionner le service. Les documents des transporteurs ne sont vus que par l’équipe ILT. Tu peux supprimer ton compte depuis les paramètres.'),
  ];

  @override
  Widget build(BuildContext context) => Screen(
        top: const TopBar('Conditions'),
        gap: 18,
        children: [
          const Heading('Conditions d’utilisation', sub: 'L’essentiel de ce que tu acceptes en utilisant i-fret.'),
          for (final (title, text) in _sections)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [Semantics(header: true, child: Text(title, style: Ts.h2)), Text(text)],
            ),
          const Lab('Texte de présentation. La version juridique complète est fournie par ILT.'),
        ],
      );
}
