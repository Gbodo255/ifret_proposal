import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/store.dart';
import '../services/device.dart';
import '../theme/tokens.dart';
import 'brand.dart';
import 'extras.dart';
import 'ui.dart';

// Carte OpenStreetMap (gratuite, sans clé). Pour passer à un autre fournisseur de tuiles
// (MapTiler, Stadia…), il suffit de changer l'adresse ci-dessous.
const _tiles = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

LatLng _ll(Place p) => LatLng(p.lat, p.lng);

/// Fond de carte commun : tuiles, puis la mention obligatoire des contributeurs.
List<Widget> _base(BuildContext context, {required double attributionInset}) => [
      TileLayer(urlTemplate: _tiles, userAgentPackageName: 'com.ilt.ifret', maxNativeZoom: 19),
      Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: EdgeInsets.only(right: 8, bottom: attributionInset),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .85), borderRadius: BorderRadius.circular(4)),
            child: const Text('© OpenStreetMap', style: TextStyle(fontSize: 10, color: Color(0xFF333029))),
          ),
        ),
      ),
    ];

const _noRotation = InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate);

/// Déplace la carte. Tant qu'elle n'a pas été affichée une première fois, son contrôleur refuse
/// toute commande : on l'ignore, la carte s'ouvrira de toute façon sur le bon cadrage.
void _whenShown(VoidCallback move) {
  try {
    move();
  } on Exception {
    // Carte pas encore affichée.
  }
}

/// Marqueur de chargement (anneau) ou de livraison (drapeau jaune), aux couleurs de la charte.
class _Pin extends StatelessWidget {
  const _Pin({required this.dropoff});
  final bool dropoff;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      decoration: BoxDecoration(
        color: dropoff ? c.primary : c.surface,
        shape: BoxShape.circle,
        border: Border.all(color: c.ink, width: dropoff ? 2 : 6),
        boxShadow: [BoxShadow(color: c.shadow, blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: dropoff ? Icon(LucideIcons.flag, size: 14, color: c.onPrimary) : null,
    );
  }
}

/// Position de l'appareil : point bleu cerclé de blanc.
const _hereDot = DecoratedBox(
  decoration: BoxDecoration(
    color: Color(0xFF1D5FC2),
    shape: BoxShape.circle,
    border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 3)),
    boxShadow: [BoxShadow(color: Color(0x331D5FC2), blurRadius: 0, spreadRadius: 6)],
  ),
);

/// Carte du trajet : chargement, livraison, tracé et position du transporteur.
/// OpenStreetMap dans l'application ; fond de démonstration dans les tests.
class IfMap extends StatefulWidget {
  const IfMap({super.key, this.pickup, this.dropoff, this.progress});
  final Place? pickup;
  final Place? dropoff;

  /// Avancement du transporteur entre les deux points, de 0 à 1. Nul : pas de camion affiché.
  final double? progress;

  @override
  State<IfMap> createState() => _IfMapState();
}

class _IfMapState extends State<IfMap> {
  final _controller = MapController();

  /// Cadre la carte sur le trajet, ou sur le seul point connu.
  CameraFit? get _fit {
    final a = widget.pickup, b = widget.dropoff;
    if (a == null || b == null) return null;
    return CameraFit.bounds(bounds: LatLngBounds.fromPoints([_ll(a), _ll(b)]), padding: const EdgeInsets.fromLTRB(48, 96, 48, 72));
  }

  @override
  void didUpdateWidget(IfMap old) {
    super.didUpdateWidget(old);
    if (!hasLiveMap || (old.pickup == widget.pickup && old.dropoff == widget.dropoff)) return;
    final fit = _fit, only = widget.pickup ?? widget.dropoff;
    _whenShown(() {
      if (fit != null) {
        _controller.fitCamera(fit);
      } else if (only != null) {
        _controller.move(_ll(only), 14);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.pickup, b = widget.dropoff, t = widget.progress;
    if (!hasLiveMap) return MapView(progress: t ?? .45, showCarrier: t != null);
    final c = context.c;
    final here = context.store.here;
    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: _ll(a ?? b ?? here ?? Mock.cotonou),
        initialZoom: 14,
        initialCameraFit: _fit,
        backgroundColor: c.fillSoft,
        interactionOptions: _noRotation,
      ),
      children: [
        ..._base(context, attributionInset: 52),
        // shortcut: trait droit entre les deux points, à remplacer par l'itinéraire routier (OpenRouteService ou serveur).
        if (a != null && b != null)
          PolylineLayer(
            polylines: [
              Polyline(points: [_ll(a), _ll(b)], strokeWidth: 8, color: Colors.white),
              Polyline(points: [_ll(a), _ll(b)], strokeWidth: 4, color: c.ink),
            ],
          ),
        MarkerLayer(
          markers: [
            if (here != null) Marker(point: _ll(here), width: 18, height: 18, child: _hereDot),
            if (a != null) Marker(point: _ll(a), width: 28, height: 28, child: const _Pin(dropoff: false)),
            if (b != null) Marker(point: _ll(b), width: 28, height: 28, child: const _Pin(dropoff: true)),
            if (a != null && b != null && t != null)
              Marker(
                point: LatLng(a.lat + (b.lat - a.lat) * t, a.lng + (b.lng - a.lng) * t),
                width: 44,
                height: 44,
                child: Container(
                  decoration: BoxDecoration(
                    color: c.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.ink, width: 3),
                    boxShadow: [BoxShadow(color: c.shadow, blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Icon(LucideIcons.truck, size: 18, color: c.onPrimary),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Choix d'un lieu sur la carte : on déplace la carte sous l'épingle, ou on cherche une adresse.
/// Se ferme en renvoyant le [Place] confirmé.
class PlacePickerScreen extends StatefulWidget {
  const PlacePickerScreen({super.key, required this.title, this.initial});
  final String title;
  final Place? initial;

  @override
  State<PlacePickerScreen> createState() => _PlacePickerScreenState();
}

class _PlacePickerScreenState extends State<PlacePickerScreen> {
  final _controller = MapController();
  final _search = TextEditingController();
  late Place _place;
  bool _resolving = false;
  bool _searching = false;
  Timer? _idle;
  int _request = 0;
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    _place = widget.initial ?? context.store.here ?? Mock.cotonou;
  }

  @override
  void dispose() {
    _idle?.cancel();
    _search.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Va sur un lieu déjà nommé (adresse enregistrée, résultat de recherche, ma position).
  void _goTo(Place place) {
    _idle?.cancel();
    _request++;
    setState(() {
      _place = place;
      _resolving = false;
    });
    if (hasLiveMap) _whenShown(() => _controller.move(_ll(place), 16));
  }

  /// La carte bouge sous le doigt : on attend qu'elle s'arrête, puis on cherche le nom du lieu sous l'épingle.
  void _onMoved(MapCamera camera, bool byGesture) {
    if (!byGesture) return;
    _idle?.cancel();
    if (!_resolving) setState(() => _resolving = true);
    final center = camera.center;
    _idle = Timer(const Duration(milliseconds: 450), () async {
      final request = ++_request;
      final place = await describePlace(center.latitude, center.longitude);
      // Une réponse arrivée après un nouveau déplacement est ignorée.
      if (!mounted || request != _request) return;
      setState(() {
        _place = place;
        _resolving = false;
      });
    });
  }

  Future<void> _find(String query) async {
    if (query.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    // Une adresse enregistrée dont le nom correspond passe avant la recherche en ligne.
    final saved = context.store.addresses.where((a) => a.label.toLowerCase().contains(query.trim().toLowerCase())).firstOrNull;
    if (saved != null) return _goTo(Place(saved.label, saved.place.detail, saved.place.lat, saved.place.lng));
    setState(() => _searching = true);
    final found = await searchPlace(query);
    if (!mounted) return;
    setState(() => _searching = false);
    found == null ? toast(context, 'Adresse introuvable. Déplace la carte pour placer l’épingle.') : _goTo(found);
  }

  Future<void> _myPosition() async {
    final store = context.store;
    final (_, here) = await locate();
    if (!mounted) return;
    if (here == null) return toast(context, 'Position introuvable pour l’instant.');
    store.update(() => store.here = here);
    final named = await describePlace(here.lat, here.lng);
    if (mounted) _goTo(named);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final store = context.store;
    final here = store.here;
    // Hauteur de la feuille du bas : l'épingle vise le centre de la partie de carte visible au-dessus.
    const sheet = 230.0;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            bottom: hasLiveMap ? sheet - kRadius : 0,
            child: hasLiveMap
                ? FlutterMap(
                    mapController: _controller,
                    options: MapOptions(initialCenter: _ll(_place), initialZoom: 15, backgroundColor: c.fillSoft, interactionOptions: _noRotation, onPositionChanged: _onMoved),
                    children: [
                      ..._base(context, attributionInset: kRadius + 6),
                      if (here != null) MarkerLayer(markers: [Marker(point: _ll(here), width: 18, height: 18, child: _hereDot)]),
                    ],
                  )
                : const MapView(showCarrier: false),
          ),
          // Épingle fixe : sa pointe marque le lieu choisi, au centre de la carte.
          const Positioned.fill(
            bottom: sheet - kRadius,
            child: IgnorePointer(
              child: Center(child: Padding(padding: EdgeInsets.only(bottom: 40), child: Icon(LucideIcons.mapPin, size: 44, color: Color(0xFF333029)))),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                spacing: 10,
                children: [
                  IconBtn(LucideIcons.arrowLeft, label: 'Retour', tone: IbTone.floating, onTap: () => Navigator.maybePop(context)),
                  Expanded(
                    child: Box(
                      color: c.surface,
                      radius: kRadius,
                      shadow: true,
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        spacing: 8,
                        children: [
                          _searching ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(LucideIcons.search, size: 18, color: c.muted),
                          Expanded(
                            child: TextField(
                              controller: _search,
                              textInputAction: TextInputAction.search,
                              onSubmitted: _find,
                              style: TextStyle(fontSize: 15, color: c.ink),
                              decoration: InputDecoration.collapsed(hintText: 'Chercher une adresse', hintStyle: TextStyle(color: c.muted)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: IconBtn(LucideIcons.locateFixed, label: 'Ma position', tone: IbTone.floating, size: 44, onTap: _myPosition),
                ),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: sheet),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(kRadius)),
                    boxShadow: const [BoxShadow(color: Color(0x1A1E1E1E), blurRadius: 24, offset: Offset(0, -8))],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: kContentMax),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            spacing: 12,
                            children: [
                              Lab(widget.title),
                              Semantics(
                                liveRegion: true,
                                child: Row(
                                  spacing: 12,
                                  children: [
                                    const RouteDot(),
                                    Expanded(
                                      child: _resolving
                                          ? const Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 6, children: [Skeleton(width: 180), Skeleton(width: 120, height: 12)])
                                          : Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(_place.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                                if (_place.detail.isNotEmpty) Lab(_place.detail, maxLines: 1),
                                              ],
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                              if (store.addresses.isNotEmpty)
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    spacing: 8,
                                    children: [
                                      for (final a in store.addresses) Tag(a.label, tone: Tone.outline, icon: LucideIcons.mapPin, height: 32, onTap: () => _goTo(Place(a.label, a.place.detail, a.place.lat, a.place.lng))),
                                    ],
                                  ),
                                ),
                              Cta('Confirmer ce lieu', busy: _resolving, onTap: () => Navigator.pop(context, _place)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ouvre le choix d'un lieu et renvoie celui qui a été confirmé.
Future<Place?> pickPlace(BuildContext context, {required String title, Place? initial}) =>
    Navigator.of(context).push<Place>(MaterialPageRoute(builder: (_) => PlacePickerScreen(title: title, initial: initial)));
