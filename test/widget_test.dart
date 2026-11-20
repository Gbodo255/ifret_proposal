import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ifret/app.dart';
import 'package:ifret/data/store.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:ifret/routes.dart';
import 'package:ifret/services/device.dart';
import 'package:ifret/widgets/brand.dart';

/// Toutes les routes, pour vérifier que chaque écran se construit sans débordement.
const _routes = [
  R.splash, R.gate, R.onboarding, R.compte, R.telephone, R.code, R.identite, R.conditions,
  R.infos, R.comptes, R.codeApp, R.chat,
  R.c, R.cTrajet, R.cMarchandise, R.cVehicule, R.cDetails, R.cRecap, R.cPaiement, R.cRecherche, R.cSuivi, R.cChat,
  R.cSolde, R.cNotation, R.cRecu, R.cAnnulation, R.cAdresses, R.cAdresse, R.cSignalement, R.cParametres, R.cNotifications, R.cAide,
  R.tVehicule, R.tDossier, R.tAttente, R.t, R.tMission, R.tChargement, R.tArrivee, R.tLivraison, R.tNotation,
  R.tSignalement, R.tParametres, R.tNotifications, R.tAide,
];

/// Petit téléphone, téléphone de la maquette, tablette portrait, bureau.
const _sizes = [Size(320, 568), Size(390, 844), Size(768, 1024), Size(1280, 800)];

/// Avance le temps par petits pas : les animations en boucle empêchent d'attendre « la fin ».
Future<void> _wait(WidgetTester tester, [int ms = 1600]) async {
  for (var t = 0; t < ms; t += 200) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _tap(WidgetTester tester, String text) async {
  final target = find.text(text).last;
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await _wait(tester);
}

/// Démarre l'application en format téléphone, directement sur [route].
Future<NavigatorState> _open(WidgetTester tester, String route, {Object? args, Size size = const Size(390, 844)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const IfretApp());
  final navigator = tester.state<NavigatorState>(find.byType(Navigator));
  navigator.pushNamedAndRemoveUntil(route, (_) => false, arguments: args);
  await _wait(tester, 1000);
  return navigator;
}

AppStore _store(WidgetTester tester) => tester.element(find.byType(Navigator)).store;

void main() {
  // Sans la vraie police, le texte de test est bien plus large et tout déborde à tort.
  setUpAll(() async {
    final loader = FontLoader('WorkSans');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold', 'BlackItalic']) {
      loader.addFont(File('assets/fonts/WorkSans-$weight.ttf').readAsBytes().then((b) => ByteData.sublistView(b)));
    }
    await loader.load();
  });

  // Vide l'arbre à la fin de chaque test : les minuteurs en cours (code SMS, réponse du chat) s'arrêtent.
  tearDown(() async {});

  group('formats', () {
    test('formatPhone groupe les 10 chiffres par paires', () {
      expect(formatPhone('0197000012'), '01 97 00 00 12');
      expect(formatPhone('019'), '01 9');
      expect(formatPhone('01 97-00.00 12 99'), '01 97 00 00 12');
    });

    test('formatNumber et money groupent par milliers', () {
      expect(formatNumber(8000), '8 000');
      expect(money(108000), '108 000 FCFA');
      expect(formatNumber(40), '40');
    });

    test('le prix de démonstration retrouve la fourchette de la maquette', () {
      final draft = Draft(dropoff: Mock.arzeke);
      expect(draft.km, 415);
      expect((draft.priceMin, draft.priceMax, draft.deposit), (80000, 120000, 50000));
      expect(Vehicle.forWeight(800), Vehicle.van);
      expect(Vehicle.forWeight(8000), Vehicle.truck);
      expect(Vehicle.forWeight(45000), Vehicle.semi);
    });
  });

  for (final size in _sizes) {
    for (final scale in const [1.0, 1.3]) {
      testWidgets('tous les écrans tiennent en ${size.width.toInt()}×${size.height.toInt()}, texte ×$scale', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final navigator = await _open(tester, R.compte, size: size);
        final failures = <String>[];
        for (final route in _routes) {
          navigator.pushNamedAndRemoveUntil(route, (_) => false);
          await _wait(tester, 800);
          final error = tester.takeException();
          if (error != null) failures.add('$route : ${'$error'.split('\n').first}');
        }
        expect(failures, isEmpty);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  testWidgets('l’animation d’entrée mène à l’onboarding', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const IfretApp());
    await _wait(tester, 4800);
    expect(find.text('Passer'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('sur grand écran, la carte du suivi occupe toute la hauteur', (tester) async {
    await _open(tester, R.cSuivi, size: const Size(1280, 800));
    expect(tester.getSize(find.byType(MapView)), const Size(840, 800));
  });

  testWidgets('inscription chargeur : champs vides refusés, puis compte créé', (tester) async {
    await _open(tester, R.compte);
    await _tap(tester, 'Compte chargeur');

    // Numéro vide, puis trop court : message d'erreur, pas de passage à la suite.
    await _tap(tester, 'Recevoir le code');
    expect(find.text('Indique un numéro de téléphone.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '0197');
    await _tap(tester, 'Recevoir le code');
    expect(find.text('Le numéro doit compter 10 chiffres.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '0190112233');
    await _tap(tester, 'Recevoir le code');
    expect(find.text('Le code reçu par SMS'), findsOneWidget);

    await _tap(tester, 'Vérifier');
    expect(find.text('Saisis les 6 chiffres du code.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '482159');
    await _tap(tester, 'Vérifier');
    expect(find.text('Comment t’appelles-tu ?'), findsOneWidget);

    await _tap(tester, 'Créer mon compte');
    expect(find.text('Indique ton prénom.'), findsOneWidget);
    expect(find.text('Indique ton nom.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'Awa');
    await tester.enterText(find.byType(TextFormField).at(1), 'Zinsou');
    await tester.enterText(find.byType(TextFormField).at(3), 'awa@');
    await _tap(tester, 'Créer mon compte');
    expect(find.text('Cette adresse e-mail n’est pas valide.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(3), 'awa@exemple.bj');
    await _tap(tester, 'Créer mon compte');

    expect(find.text('Bonjour, Awa'), findsOneWidget);
    expect(_store(tester).chargeur.phone, '0190112233');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('demande complète : trajet, poids saisi, paiement, suivi, solde, note', (tester) async {
    await _open(tester, R.c);
    await _tap(tester, 'Où livrer ta marchandise ?');
    expect(find.text('D’où à où ?'), findsOneWidget);

    // Sans lieu de livraison, on ne passe pas.
    await _tap(tester, 'Continuer');
    expect(find.text('Choisis le lieu de livraison.'), findsOneWidget);
    await _tap(tester, 'Marché Arzèkè');
    await _tap(tester, 'Continuer');
    expect(find.text('Qu’est-ce qu’on transporte ?'), findsOneWidget);

    // Poids tapé au clavier, hors des raccourcis proposés.
    await tester.enterText(find.byType(TextField).first, '');
    await _tap(tester, 'Continuer');
    expect(find.text('Indique le poids de ta marchandise.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '1250');
    await tester.pump();
    expect(_store(tester).draft.kg, 1250);
    await _tap(tester, 'Continuer');
    expect(find.text('Quel véhicule ?'), findsOneWidget);
    expect(_store(tester).draft.vehicle, Vehicle.van);

    await _tap(tester, 'Continuer');
    await _tap(tester, 'Voir le prix');
    expect(find.text('Acompte à payer'), findsOneWidget);
    final deposit = _store(tester).draft.deposit;
    await _tap(tester, 'Confirmer et payer l’acompte');
    await _tap(tester, 'Payer ${money(deposit)}');
    expect(find.text('On cherche ton transporteur…'), findsOneWidget);
    final course = _store(tester).courses.first;
    expect(course.status, CourseStatus.searching);
    expect(course.to.name, 'Marché Arzèkè');

    await _tap(tester, 'Aperçu : un transporteur accepte');
    expect(course.status, CourseStatus.enRoute);
    await _tap(tester, 'Aperçu : le camion arrive');
    expect(find.text('Reste à payer'), findsOneWidget);
    await _tap(tester, 'Payer ${money(course.balance)}');
    expect(course.status, CourseStatus.delivered);
    await _tap(tester, 'Envoyer ma note');
    expect(course.rating, 5);
    expect(find.text('Mes courses'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('carte OpenStreetMap : affichage, recadrage et choix d’un lieu', (tester) async {
    // Seul test qui affiche la vraie carte ; ses images ne se chargent pas hors ligne, la carte reste grise.
    hasLiveMap = true;
    addTearDown(() => hasLiveMap = false);
    await _open(tester, R.cTrajet);
    expect(find.byType(FlutterMap), findsOneWidget);

    // Changer la livraison recadre la carte sur le nouveau trajet.
    await _tap(tester, 'Boutique Dantokpa');
    expect(_store(tester).draft.dropoff!.name, 'Boutique Dantokpa');

    // Choix du chargement sur la carte : une adresse enregistrée déplace la carte, puis on confirme.
    // Le premier « Port autonome de Cotonou » est le champ ; le second, la pastille d'adresse.
    await tester.tap(find.text('Port autonome de Cotonou').first);
    await _wait(tester);
    expect(find.text('Lieu de chargement'), findsOneWidget);
    await _tap(tester, 'Entrepôt Akpakpa');
    await _tap(tester, 'Confirmer ce lieu');
    expect(_store(tester).draft.pickup.name, 'Entrepôt Akpakpa');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('annulation : la course passe en annulée', (tester) async {
    final navigator = await _open(tester, R.c);
    final store = _store(tester);
    final course = store.confirmDraft('mtn');
    navigator.pushNamed(R.cAnnulation, arguments: course.ref);
    await _wait(tester);
    expect(find.text('Aucun transporteur n’a encore accepté : l’annulation est gratuite.'), findsOneWidget);
    await _tap(tester, 'Confirmer l’annulation');
    expect(course.status, CourseStatus.cancelled);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('adresse : nom et emplacement obligatoires, puis enregistrement', (tester) async {
    await _open(tester, R.cAdresses);
    final before = _store(tester).addresses.length;
    await _tap(tester, 'Ajouter une adresse');
    await _tap(tester, 'Enregistrer');
    expect(find.text('Donne un nom à cette adresse.'), findsOneWidget);
    expect(find.text('Place l’adresse sur la carte.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Chantier Fidjrossè');
    await _tap(tester, 'Choisir sur la carte');
    await _tap(tester, 'Confirmer ce lieu');
    await _tap(tester, 'Enregistrer');
    expect(_store(tester).addresses.length, before + 1);
    expect(find.text('Chantier Fidjrossè'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('chat : le message envoyé s’affiche, puis une réponse arrive', (tester) async {
    await _open(tester, R.chat, args: 'rodrigue');
    final chat = _store(tester).conversation('rodrigue');
    final before = chat.lines.length;
    await tester.enterText(find.byType(TextField), 'Tu arrives à quelle heure ?');
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Envoyer'));
    await tester.pump();
    expect(find.text('Tu arrives à quelle heure ?'), findsOneWidget);
    expect(chat.lines.length, before + 1);
    await _wait(tester, 1200);
    expect(chat.typing, isTrue);
    await _wait(tester, 2000);
    expect(chat.typing, isFalse);
    expect(chat.lines.length, before + 2);
    expect(chat.unread, 0);
  });

  testWidgets('profil : les informations modifiées se retrouvent sur le profil', (tester) async {
    await _open(tester, R.infos, args: Role.chargeur);
    await tester.enterText(find.byType(TextFormField).first, '');
    await _tap(tester, 'Enregistrer');
    expect(find.text('Indique ton prénom et ton nom.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Koffi B. Agossou');
    await _tap(tester, 'Enregistrer');
    expect(_store(tester).chargeur.name, 'Koffi B. Agossou');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('mission transporteur : acceptation, chargement, code de livraison, gains', (tester) async {
    await _open(tester, R.t);
    final store = _store(tester);
    await _tap(tester, 'Voir la mission');
    await _tap(tester, 'Accepter la mission');
    expect(store.mission, MissionStep.loading);
    await _tap(tester, 'Chargement terminé, je pars');
    expect(store.mission, MissionStep.arrived);
    await _tap(tester, 'Aperçu : solde payé');

    // Mauvais code : refusé, un essai en moins. Bon code : livraison validée.
    await tester.enterText(find.byType(TextField), '1111');
    await tester.pump();
    await _tap(tester, 'Valider la livraison');
    expect(find.textContaining('Il te reste 2 essais'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '4729');
    await tester.pump();
    await _tap(tester, 'Valider la livraison');
    expect(find.text('Livraison validée'), findsOneWidget);
    expect(store.mission, MissionStep.delivered);

    await _tap(tester, 'Envoyer ma note');
    expect(store.shipperRating, 5);
    expect(find.text('Mes gains'), findsOneWidget);
    expect(store.payouts.first.amount, 96000);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('dossier transporteur : incomplet refusé, complet envoyé', (tester) async {
    await _open(tester, R.tDossier);
    await _tap(tester, 'Envoyer mon dossier');
    expect(find.textContaining('Il manque encore 2 pièces'), findsOneWidget);
    await _tap(tester, 'Ajouter');
    await _tap(tester, 'Ajouter');
    expect(_store(tester).documents.length, 5);
    await _tap(tester, 'Envoyer mon dossier');
    expect(find.text('ILT vérifie ton dossier'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('aide : la réponse se déplie et la recherche filtre', (tester) async {
    await _open(tester, R.cAide);
    await _tap(tester, 'Quand dois-je payer le solde ?');
    expect(find.textContaining('avant le déchargement'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'annule');
    await _wait(tester, 600);
    expect(find.text('Que se passe-t-il si j’annule ?'), findsOneWidget);
    expect(find.text('Comment le prix est-il calculé ?'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
