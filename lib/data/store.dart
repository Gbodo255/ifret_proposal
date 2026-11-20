import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../routes.dart';
import 'models.dart';

export 'models.dart';

/// Délai d'une action qui passerait par le serveur (paiement, envoi) : assez long
/// pour montrer l'état de chargement, assez court pour ne pas faire attendre.
const kServerDelay = Duration(milliseconds: 650);

String _hhmm([DateTime? d]) {
  final t = d ?? DateTime.now();
  return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

/// État de l'application et données de démonstration.
///
/// Le front n'a pas encore de serveur : tout vit en mémoire, le temps de la session.
/// Chaque méthode ci-dessous correspond à un appel d'API à brancher plus tard.
class AppStore extends ChangeNotifier {
  Role role = Role.chargeur;

  /// Position de l'appareil, connue une fois la localisation autorisée.
  Place? here;

  final chargeur = Profile('Koffi Agossou', '0197000012', company: 'Agossou Matériaux', email: 'koffi@agossou.bj');
  final transporteur = Profile('Rodrigue Hounkpè', '0196442018');
  Profile profileOf(Role r) => r == Role.chargeur ? chargeur : transporteur;
  Profile get me => profileOf(role);

  final addresses = [
    SavedAddress('Entrepôt Akpakpa', Mock.akpakpa, AddressKind.pickup, isDefault: true),
    SavedAddress('Port autonome de Cotonou', Mock.port, AddressKind.pickup),
    SavedAddress('Boutique Dantokpa', Mock.dantokpa, AddressKind.dropoff),
    SavedAddress('Marché Arzèkè', Mock.arzeke, AddressKind.dropoff, contact: 'Aïcha Bio'),
  ];

  final _accounts = {
    Role.chargeur: [MoneyAccount('mtn', '0197000012', isDefault: true)],
    Role.transporteur: [MoneyAccount('mtn', '0196442018', isDefault: true)],
  };
  List<MoneyAccount> accountsOf(Role r) => _accounts[r]!;
  MoneyAccount accountOf(Role r) => accountsOf(r).firstWhere((a) => a.isDefault, orElse: () => accountsOf(r).first);
  MoneyAccount get account => accountOf(Role.chargeur);

  final settings = {'push': true, 'sms': true, 'promo': false, 'bio': true, 'son': true, 'retour': false};
  String appCode = '1234';
  int radiusKm = 25;
  String navApp = 'Google Maps';

  // ───────────── Chargeur ─────────────

  Draft draft = Draft(dropoff: Mock.arzeke);

  final courses = [
    Course(ref: 'IFR-2611-0042', from: Mock.port, to: Mock.arzeke, date: 'aujourd’hui', price: 100000, adjustment: 8000, vehicle: Vehicle.truck, cargo: 'Matériaux · 8,6 t · 120 colis', status: CourseStatus.enRoute, carrier: 'Rodrigue Hounkpè', plate: 'AB 4521 RB'),
    Course(ref: 'IFR-0911-0031', from: Mock.port, to: Mock.bohicon, date: '9 nov.', price: 45000, vehicle: Vehicle.truck, cargo: 'Matériaux · 6 t', status: CourseStatus.delivered, carrier: 'Mathieu Dossou', plate: 'BK 2210 RB')..rating = 5,
    Course(ref: 'IFR-0211-0019', from: Mock.seme, to: Mock.calavi, date: '2 nov.', price: 18000, vehicle: Vehicle.van, cargo: 'Textile · 800 kg', status: CourseStatus.delivered, carrier: 'Ibrahim Sanni', plate: 'AT 7754 RB')..rating = 5,
    Course(ref: 'IFR-2810-0007', from: Mock.akpakpa, to: Mock.portoNovo, date: '28 oct.', price: 32000, vehicle: Vehicle.van, cargo: 'Alimentaire · 1,2 t', status: CourseStatus.delivered, carrier: 'Mathieu Dossou', plate: 'BK 2210 RB')..rating = 4,
    Course(ref: 'IFR-2110-0003', from: Mock.ouidah, to: Mock.dantokpa, date: '21 oct.', price: 22000, vehicle: Vehicle.van, cargo: 'Mobilier · 900 kg', status: CourseStatus.cancelled),
  ];

  /// Course en cours la plus récente, s'il y en a une.
  Course? get activeCourse => courses.where((c) => c.status.active).firstOrNull;
  Course course(String? ref) => courses.where((c) => c.ref == ref).firstOrNull ?? activeCourse ?? courses.first;

  /// Nouvelle demande : part de l'adresse de chargement par défaut, livraison à choisir.
  void newDraft() => update(() => draft = Draft(pickup: addresses.where((a) => a.kind == AddressKind.pickup && a.isDefault).firstOrNull?.place ?? here));

  /// Acompte payé : la demande devient une course en recherche de transporteur.
  Course confirmDraft(String operator) {
    final now = DateTime.now();
    final d = draft;
    final created = Course(
      ref: 'IFR-${now.day.toString().padLeft(2, '0')}${now.month.toString().padLeft(2, '0')}-${(courses.length + 38).toString().padLeft(4, '0')}',
      from: d.pickup,
      to: d.to,
      date: 'aujourd’hui',
      price: d.price,
      vehicle: d.vehicle,
      cargo: d.cargo,
      recipient: d.recipientName,
      operator: operator,
    );
    update(() {
      courses.insert(0, created);
      draft = Draft(dropoff: Mock.arzeke);
      _notify(Role.chargeur, LucideIcons.circleCheck, 'Acompte reçu', '${money(created.deposit)} payés par ${mobileMoney[operator]}.', R.cRecu);
    });
    return created;
  }

  void carrierAccepts(Course c) => update(() {
        c
          ..status = CourseStatus.enRoute
          ..carrier = 'Rodrigue Hounkpè'
          ..plate = 'AB 4521 RB';
        _notify(Role.chargeur, LucideIcons.userCheck, 'Transporteur trouvé', 'Rodrigue Hounkpè a accepté ta demande.', R.cSuivi);
      });

  void truckArrives(Course c) => update(() => c.status = CourseStatus.arrived);

  void payBalance(Course c) => update(() {
        c.status = CourseStatus.delivered;
        _notify(Role.chargeur, LucideIcons.packageCheck, 'Course livrée', '${c.ref} · ${c.route}.', R.cRecu);
      });

  void cancel(Course c) => update(() => c.status = CourseStatus.cancelled);

  // ───────────── Transporteur ─────────────

  bool online = true;
  MissionStep mission = MissionStep.offered;
  Vehicle vehicle = Vehicle.truck;
  String plate = 'AB 4521 RB';
  String capacity = '10';
  final vehiclePhotos = ['demo', 'demo', 'demo'];
  final loadingPhotos = ['demo', 'demo'];
  final deliveryPhotos = <String>[];

  /// Pièces du dossier déjà fournies (indices dans la liste des documents).
  final documents = {0, 1, 2};
  bool dossierValidated = false;
  int? shipperRating;

  final payouts = [
    const Payout('Cotonou → Bohicon', '14 nov. · MTN MoMo', 62000, 'Versé'),
    const Payout('Porto-Novo → Cotonou', '12 nov. · MTN MoMo', 38000, 'Versé'),
    const Payout('Cotonou → Abomey', '8 nov. · MTN MoMo', 54000, 'Versé'),
  ];

  /// Livraison validée par le code : la rémunération part en versement.
  void deliverMission() => update(() {
        mission = MissionStep.delivered;
        payouts.insert(0, const Payout('Cotonou → Parakou', 'Aujourd’hui · MTN MoMo', 96000, 'En cours'));
        _notify(Role.transporteur, LucideIcons.banknote, 'Versement en cours', '96 000 FCFA arrivent sur ton MTN MoMo sous 24 h.', R.t);
      });

  // ───────────── Messages ─────────────

  final conversations = [
    Conversation('rodrigue', 'Rodrigue Hounkpè', 'IFR-2611-0042 · Cotonou → Parakou', phone: '0196442018', unread: 1, active: true, [
      const ChatLine('Le transporteur est arrivé au chargement · 09:05', ''),
      const ChatLine('Bonjour, je suis devant le portail 3. Le quai est libre ?', '09:06', me: false),
      const ChatLine('Oui, avance jusqu’au magasin B, on t’attend.', '09:07', me: true),
      const ChatLine('Marchandise chargée · en route · 09:40', ''),
      const ChatLine('Je viens de passer Bohicon, la route est dégagée.', '12:15', me: false),
    ]),
    Conversation('ilt', 'Assistance ILT', 'Service client', verified: false, phone: kAssistancePhone, [
      const ChatLine('Bonjour Koffi, ici l’assistance ILT. Comment peut-on t’aider ?', '09:58', me: false),
      const ChatLine('Je voulais comprendre le surpoids ajouté à ma course.', '10:01', me: true),
      const ChatLine('Ton ajustement a été validé. Bonne journée !', '10:04', me: false),
    ]),
    Conversation('mathieu', 'Mathieu Dossou', 'IFR-0911-0031 · Cotonou → Bohicon', phone: '0195112233', [
      const ChatLine('Livré, merci pour la confiance.', '9 nov.', me: false),
    ]),
    Conversation('ibrahim', 'Ibrahim Sanni', 'IFR-0211-0019 · Sèmè → Abomey-Calavi', phone: '0194556677', [
      const ChatLine('Je suis au portail.', '2 nov.', me: false),
    ]),
    Conversation('koffi', 'Koffi Agossou', 'IFR-2611-0042 · Chargeur', verified: false, phone: '0197000012', active: true, role: Role.transporteur, [
      const ChatLine('Mission acceptée · 08:55', ''),
      const ChatLine('Bonjour Rodrigue, le chargement est prêt au magasin B.', '08:58', me: false),
    ]),
    Conversation('ilt-t', 'Assistance ILT', 'Service transporteurs', verified: false, phone: kAssistancePhone, role: Role.transporteur, [
      const ChatLine('Bonjour Rodrigue, ici l’assistance ILT. Comment peut-on t’aider ?', '08:30', me: false),
    ]),
  ];

  Conversation conversation(String? id) => conversations.where((c) => c.id == id).firstOrNull ?? conversations.first;

  static const _replies = ['D’accord, bien noté.', 'Je te tiens au courant dès que possible.', 'Merci, c’est reçu.', 'Pas de souci, on s’en occupe.'];

  /// Envoie un message, puis simule la réponse de l'autre personne.
  // shortcut: réponse automatique de démonstration, à remplacer par la messagerie temps réel du serveur.
  void send(Conversation c, String text, {String? photo}) {
    update(() => c.lines.add(ChatLine(text, _hhmm(), me: true, photo: photo)));
    Timer(const Duration(milliseconds: 900), () => update(() => c.typing = true));
    Timer(const Duration(milliseconds: 2600), () {
      update(() {
        c
          ..typing = false
          ..lines.add(ChatLine(_replies[c.lines.length % _replies.length], _hhmm(), me: false));
      });
    });
  }

  void read(Conversation c) {
    if (c.unread > 0) update(() => c.unread = 0);
  }

  // ───────────── Notifications ─────────────

  final _notifs = {
    Role.chargeur: [
      Notif('Aujourd’hui', LucideIcons.truck, 'Rodrigue a passé Bohicon', 'Arrivée à Parakou prévue à 16:40.', '12:15', R.cSuivi, unread: true),
      Notif('Aujourd’hui', LucideIcons.messageCircle, 'Nouveau message de Rodrigue', '« Je viens de passer Bohicon, la route est dégagée. »', '12:15', R.cChat, unread: true),
      Notif('Aujourd’hui', LucideIcons.triangleAlert, 'Ajustement validé par ILT', 'Surpoids : + 8 000 FCFA ajoutés au solde.', '10:02', R.cSolde),
      Notif('Aujourd’hui', LucideIcons.userCheck, 'Transporteur trouvé', 'Rodrigue Hounkpè a accepté ta demande.', '08:55', R.cSuivi),
      Notif('Plus tôt', LucideIcons.circleCheck, 'Acompte reçu', '50 000 FCFA payés par MTN MoMo.', '08:52', R.cRecu),
      Notif('Plus tôt', LucideIcons.packageCheck, 'Course livrée', 'IFR-0911-0031 · Cotonou → Bohicon.', '9 nov.', R.cRecu),
    ],
    Role.transporteur: [
      Notif('Aujourd’hui', LucideIcons.route, 'Nouvelle mission à 3,2 km', 'Cotonou → Parakou · 88 000 FCFA. Expire dans 0:45.', '08:54', R.tMission, unread: true),
      Notif('Aujourd’hui', LucideIcons.circleCheck, 'Solde payé par le chargeur', 'Tu peux décharger et demander le code.', '16:44', R.tLivraison, unread: true),
      Notif('Aujourd’hui', LucideIcons.triangleAlert, 'Surpoids validé par ILT', '+ 8 000 FCFA ajoutés à ta rémunération.', '10:02', R.tChargement),
      Notif('Plus tôt', LucideIcons.banknote, 'Versement effectué', '62 000 FCFA envoyés sur ton MTN MoMo.', '14 nov.', R.t),
      Notif('Plus tôt', LucideIcons.fileText, 'Assurance à renouveler', 'Elle expire le 14 mars 2027.', '10 nov.', R.tDossier),
      Notif('Plus tôt', LucideIcons.badgeCheck, 'Dossier validé', 'Bienvenue : tu peux passer en ligne.', '2 nov.', R.t),
    ],
  };
  List<Notif> notifsOf(Role r) => _notifs[r]!;
  int unreadNotifs(Role r) => notifsOf(r).where((n) => n.unread).length;

  void _notify(Role to, IconData icon, String title, String text, String route) =>
      _notifs[to]!.insert(0, Notif('Aujourd’hui', icon, title, text, _hhmm(), route, unread: true));

  /// Applique une modification et prévient les écrans affichés.
  void update(VoidCallback change) {
    change();
    notifyListeners();
  }
}

/// Numéro de l'assistance ILT. Valeur de démonstration, à remplacer par le vrai numéro.
const kAssistancePhone = '0100000000';


/// Donne le magasin à tous les écrans, qui se redessinent à chaque changement.
class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({super.key, required AppStore store, required super.child}) : super(notifier: store);
}

extension StoreContext on BuildContext {
  AppStore get store => dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}
