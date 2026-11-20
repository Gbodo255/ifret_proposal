import 'dart:math' as math;

import 'package:flutter/widgets.dart';

enum Role { chargeur, transporteur }

/// Les quatre catégories de véhicules illustrées dans la maquette.
enum Vehicle {
  tricycle('Tricycle', 'Tricycle', 'Petits colis, courtes distances', 'assets/images/vehicule_tricycle.jpg', 90, 500),
  van('Camionnette', 'Camionnette', 'Cartons, sacs · jusqu’à 1,5 t', 'assets/images/vehicule_camionnette.jpg', 150, 1500),
  truck('Camion', 'Camion 10 t bâché', 'Palettes, matériaux · jusqu’à 10 t', 'assets/images/vehicule_camion.jpg', 240, 10000),
  semi('Semi', 'Semi-remorque', 'Gros volumes · jusqu’à 30 t', 'assets/images/vehicule_semi.jpg', 380, 30000);

  const Vehicle(this.short, this.name, this.capacity, this.asset, this.ratePerKm, this.maxKg);
  final String short;
  final String name;
  final String capacity;
  final String asset;

  /// Tarif de démonstration, en FCFA par kilomètre.
  final int ratePerKm;
  final int maxKg;

  /// Plus petit véhicule capable de porter ce poids.
  static Vehicle forWeight(int kg) => values.firstWhere((v) => kg <= v.maxKg, orElse: () => semi);
}

@immutable
class Place {
  const Place(this.name, this.detail, this.lat, this.lng);
  final String name;
  final String detail;
  final double lat;
  final double lng;

  /// Ville ou premier mot utile, pour les titres courts « Cotonou → Parakou ».
  String get city => detail.isEmpty ? name : detail.split(RegExp(r'[,·]')).last.trim();

  /// Distance à vol d'oiseau, en kilomètres.
  double distanceTo(Place other) {
    const r = 6371.0;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(other.lat - lat), dLng = rad(other.lng - lng);
    final a = math.pow(math.sin(dLat / 2), 2) + math.cos(rad(lat)) * math.cos(rad(other.lat)) * math.pow(math.sin(dLng / 2), 2);
    return 2 * r * math.asin(math.sqrt(a));
  }

  // shortcut: distance routière estimée à 1,25 fois le vol d'oiseau, à remplacer par l'itinéraire calculé côté serveur.
  int roadKmTo(Place other) => math.max(1, (distanceTo(other) * 1.25).round());
}

enum AddressKind { pickup, dropoff }

class SavedAddress {
  SavedAddress(this.label, this.place, this.kind, {this.contact = '', this.isDefault = false});
  String label;
  Place place;
  AddressKind kind;
  String contact;
  bool isDefault;
}

class Profile {
  Profile(this.name, this.phone, {this.company = '', this.email = ''});
  String name;
  String phone;
  String company;
  String email;

  String get firstName => name.split(' ').first;
}

/// Compte Mobile Money (paiement du chargeur, versement du transporteur).
class MoneyAccount {
  MoneyAccount(this.operator, this.phone, {this.isDefault = false});
  String operator;
  String phone;
  bool isDefault;
}

const mobileMoney = {'mtn': 'MTN MoMo', 'moov': 'Moov Money', 'celtiis': 'Celtiis Cash'};

/// Demande en cours de saisie.
class Draft {
  Draft({Place? pickup, this.dropoff}) : pickup = pickup ?? Mock.port;
  Place pickup;
  Place? dropoff;
  String category = 'Matériaux';
  bool byWeight = true;
  int kg = 8000;
  int m3 = 40;
  int parcels = 120;
  bool fragile = false;
  final photos = <String>[];
  Vehicle vehicle = Vehicle.truck;

  /// Nul : départ dès qu'un transporteur accepte.
  DateTime? scheduled;
  String recipientName = 'Aïcha Bio';
  String recipientPhone = '0196000034';
  bool handling = true;

  Place get to => dropoff ?? Mock.arzeke;
  int get km => pickup.roadKmTo(to);

  /// Durée de route à 55 km/h de moyenne.
  String get duration {
    final minutes = (km / 55 * 60).round();
    return minutes < 60 ? '$minutes min' : 'environ ${minutes ~/ 60} h${minutes % 60 >= 30 ? ' 30' : ''}';
  }

  // shortcut: prix de démonstration (distance × tarif du véhicule), à remplacer par le calcul du serveur.
  int get price => math.max(3000, (km * vehicle.ratePerKm / 1000).round() * 1000);
  int get priceMin => (price * .8 / 1000).round() * 1000;
  int get priceMax => (price * 1.2 / 1000).round() * 1000;
  int get deposit => price ~/ 2;

  String get load => byWeight ? (kg >= 1000 ? '${_trim(kg / 1000)} t' : '$kg kg') : '$m3 m³';
  String get cargo => '$category · $load · $parcels colis';
}

String _trim(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1).replaceAll('.', ',');

enum CourseStatus {
  searching('Recherche'),
  enRoute('En route'),
  arrived('Arrivé'),
  delivered('Livrée'),
  cancelled('Annulée');

  const CourseStatus(this.label);
  final String label;
  bool get active => index <= arrived.index;
}

class Course {
  Course({
    required this.ref,
    required this.from,
    required this.to,
    required this.date,
    required this.price,
    required this.vehicle,
    required this.cargo,
    this.status = CourseStatus.searching,
    this.adjustment = 0,
    this.carrier = '',
    this.plate = '',
    this.recipient = 'Aïcha Bio',
    this.operator = 'mtn',
    this.code = '4729',
  });
  final String ref;
  final Place from;
  final Place to;
  final String date;
  final int price;
  final Vehicle vehicle;
  final String cargo;
  CourseStatus status;

  /// Frais imprévus validés par ILT (surpoids, attente).
  int adjustment;
  String carrier;
  String plate;
  String recipient;
  String operator;

  /// Code de livraison à quatre chiffres remis au destinataire.
  final String code;
  int? rating;

  int get deposit => price ~/ 2;
  int get total => price + adjustment;
  int get balance => total - deposit;
  String get route => '${from.city} → ${to.city}';
  int get km => from.roadKmTo(to);
}

class ChatLine {
  const ChatLine(this.text, this.time, {this.me, this.photo});
  final String text;
  final String time;

  /// Nul : événement de la course, pas un message.
  final bool? me;
  final String? photo;
}

class Conversation {
  Conversation(this.id, this.name, this.subtitle, this.lines, {this.verified = true, this.phone = '', this.unread = 0, this.active = false, this.role = Role.chargeur});
  final String id;
  final String name;
  final String subtitle;
  final List<ChatLine> lines;
  final bool verified;
  final String phone;
  int unread;

  /// Rattachée à une course en cours.
  final bool active;

  /// Rôle qui voit cette conversation.
  final Role role;
  bool typing = false;

  ChatLine? get last => lines.lastWhere((l) => l.me != null, orElse: () => lines.last);
}

class Notif {
  Notif(this.day, this.icon, this.title, this.text, this.time, this.route, {this.unread = false});
  final String day;
  final IconData icon;
  final String title;
  final String text;
  final String time;
  final String route;
  bool unread;
}

/// Mission proposée au transporteur, puis suivie jusqu'à la livraison.
enum MissionStep { offered, declined, loading, arrived, paid, delivered }

class Payout {
  const Payout(this.route, this.detail, this.amount, this.state);
  final String route;
  final String detail;
  final int amount;
  final String state;
}

/// Lieux de démonstration (Bénin).
abstract final class Mock {
  static const port = Place('Port autonome de Cotonou', 'Magasin B, portail 3 · Cotonou', 6.3486, 2.4313);
  static const arzeke = Place('Marché Arzèkè', 'Parakou', 9.3300, 2.6283);
  static const akpakpa = Place('Entrepôt Akpakpa', 'Rue 1204, Akpakpa, Cotonou', 6.3622, 2.4551);
  static const dantokpa = Place('Boutique Dantokpa', 'Marché Dantokpa, allée 7, Cotonou', 6.3705, 2.4330);
  static const bohicon = Place('Marché de Bohicon', 'Bohicon', 7.1783, 2.0667);
  static const calavi = Place('Carrefour Kpota', 'Abomey-Calavi', 6.4485, 2.3557);
  static const seme = Place('Sèmè-Kraké', 'Sèmè', 6.3780, 2.6930);
  static const portoNovo = Place('Grand marché', 'Porto-Novo', 6.4969, 2.6289);
  static const ouidah = Place('Gare routière', 'Ouidah', 6.3631, 2.0851);
  static const cotonou = Place('Cotonou', 'Cotonou', 6.3654, 2.4183);
}

/// Numéro béninois à 10 chiffres, affiché par paires : 01 97 00 00 12.
String formatPhone(String digits) {
  final d = digits.replaceAll(RegExp(r'\D'), '');
  final pairs = [for (var i = 0; i < d.length && i < 10; i += 2) d.substring(i, i + 2 > d.length ? d.length : i + 2)];
  return pairs.join(' ');
}

/// Entier groupé par milliers avec espace fine insécable : 108 000.
String formatNumber(int n) => n.abs().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => ' ');

/// Montant en francs CFA : 108 000 FCFA.
String money(int n) => '${formatNumber(n)} FCFA';
