import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/models.dart';

// Tout ce qui touche à l'appareil : position, adresses, téléphone, photos, réseau.
// Les tests automatiques n'ont ni GPS ni appareil photo : ils reçoivent des valeurs fixes.

/// Vrai pendant `flutter test`.
final inTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

/// La carte OpenStreetMap charge ses images par le réseau : les tests dessinent le fond de démonstration à la place.
bool hasLiveMap = !inTest;

// ───────────── Position ─────────────

enum LocationStatus { granted, serviceOff, denied, deniedForever }

/// État de la localisation et, si elle est autorisée, position de l'appareil.
/// Avec [ask], demande l'autorisation si elle n'a pas encore été donnée.
Future<(LocationStatus, Place?)> locate({bool ask = false}) async {
  if (inTest) return (LocationStatus.granted, Mock.cotonou);
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return (LocationStatus.serviceOff, null);
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && ask) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.deniedForever) return (LocationStatus.deniedForever, null);
    if (permission == LocationPermission.denied) return (LocationStatus.denied, null);
  } catch (_) {
    return (LocationStatus.denied, null);
  }
  // L'autorisation est acquise : une position introuvable (intérieur, GPS lent) ne bloque pas l'entrée.
  try {
    final last = kIsWeb ? null : await Geolocator.getLastKnownPosition();
    final p = last ?? await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 8)));
    return (LocationStatus.granted, Place('Ma position', '', p.latitude, p.longitude));
  } catch (_) {
    return (LocationStatus.granted, null);
  }
}

Future<void> openLocationSettings(LocationStatus status) async {
  if (inTest) return;
  status == LocationStatus.serviceOff ? await Geolocator.openLocationSettings() : await Geolocator.openAppSettings();
}

// ───────────── Adresses ─────────────

String _coords(double lat, double lng) => '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';

/// Nom du lieu à ces coordonnées. Sans réseau, renvoie les coordonnées.
Future<Place> describePlace(double lat, double lng) async {
  final fallback = Place('Lieu choisi', _coords(lat, lng), lat, lng);
  if (inTest || kIsWeb) return fallback;
  try {
    final marks = await Geocoding().placemarkFromCoordinates(lat, lng).timeout(const Duration(seconds: 6));
    if (marks.isEmpty) return fallback;
    final m = marks.first;
    bool useful(String? s) => s != null && s.trim().isNotEmpty && !s.contains('+');
    final name = [m.name, m.thoroughfare, m.subLocality].where(useful).firstOrNull ?? m.locality ?? fallback.name;
    final detail = {m.subLocality, m.locality}.where(useful).where((s) => s != name).join(', ');
    return Place(name, detail.isEmpty ? (m.administrativeArea ?? '') : detail, lat, lng);
  } catch (_) {
    return fallback;
  }
}

/// Cherche une adresse saisie au clavier, au Bénin d'abord. Nul si rien n'est trouvé.
Future<Place?> searchPlace(String query) async {
  if (inTest || kIsWeb || query.trim().isEmpty) return null;
  try {
    final found = await Geocoding().locationFromAddress('${query.trim()}, Bénin').timeout(const Duration(seconds: 6));
    if (found.isEmpty) return null;
    return await describePlace(found.first.latitude, found.first.longitude);
  } catch (_) {
    return null;
  }
}

// ───────────── Téléphone et navigation ─────────────

/// Ouvre l'application Téléphone avec le numéro déjà composé.
Future<void> callNumber(BuildContext context, String phone) async {
  if (inTest) return;
  final messenger = ScaffoldMessenger.of(context);
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  var opened = false;
  try {
    opened = await launchUrl(Uri(scheme: 'tel', path: '+229$digits'));
  } catch (_) {}
  if (!opened) messenger.showSnackBar(SnackBar(content: Text('Impossible d’ouvrir le téléphone. Numéro : +229 ${formatPhone(digits)}')));
}

/// Lance l'itinéraire vers [to] dans l'application de navigation choisie.
Future<void> openNavigation(BuildContext context, Place to, String app) async {
  if (inTest) return;
  final messenger = ScaffoldMessenger.of(context);
  final url = app == 'Waze'
      ? Uri.parse('https://waze.com/ul?ll=${to.lat},${to.lng}&navigate=yes')
      : Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${to.lat},${to.lng}&travelmode=driving');
  var opened = false;
  try {
    opened = await launchUrl(url, mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (!opened) messenger.showSnackBar(SnackBar(content: Text('Impossible d’ouvrir $app.')));
}

// ───────────── Photos ─────────────

/// Propose l'appareil photo ou la galerie, et renvoie le chemin de l'image choisie.
Future<String?> pickPhoto(BuildContext context) async {
  if (inTest) return 'demo';
  final messenger = ScaffoldMessenger.of(context);
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(leading: const Icon(LucideIcons.camera), title: const Text('Prendre une photo'), onTap: () => Navigator.pop(context, ImageSource.camera)),
          ListTile(leading: const Icon(LucideIcons.image), title: const Text('Choisir dans la galerie'), onTap: () => Navigator.pop(context, ImageSource.gallery)),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (source == null) return null;
  try {
    // Image réduite : envoi plus rapide sur une connexion mobile.
    final file = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 80);
    return file?.path;
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text('Impossible d’ouvrir l’appareil photo. Vérifie l’autorisation dans les réglages.')));
    return null;
  }
}

/// Image d'une photo prise ou choisie. `demo` désigne une photo d'exemple sans fichier.
Widget photoImage(String path, {BoxFit fit = BoxFit.cover}) {
  if (path == 'demo') return const Center(child: Icon(LucideIcons.image, color: Color(0xFF6B655A)));
  return kIsWeb ? Image.network(path, fit: fit) : Image.file(File(path), fit: fit, cacheWidth: 400);
}

// ───────────── Réseau ─────────────

enum NetState { online, slow, offline }

/// Surveille la connexion : hors ligne si le réseau ne répond pas, faible s'il répond lentement.
class NetMonitor extends ValueNotifier<NetState> {
  NetMonitor() : super(NetState.online);
  Timer? _timer;

  void start() {
    if (inTest || kIsWeb) return;
    check();
    _timer = Timer.periodic(const Duration(seconds: 12), (_) => check());
  }

  Future<void> check() async {
    if (inTest || kIsWeb) return;
    final watch = Stopwatch()..start();
    try {
      final found = await InternetAddress.lookup('one.one.one.one').timeout(const Duration(seconds: 6));
      value = found.isEmpty ? NetState.offline : (watch.elapsedMilliseconds > 2000 ? NetState.slow : NetState.online);
    } catch (_) {
      value = NetState.offline;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
