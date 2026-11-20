import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/store.dart';
import '../routes.dart';
import '../services/device.dart';
import '../theme/tokens.dart';
import '../widgets/layout.dart';
import '../widgets/ui.dart';

/// Passage obligé à l'entrée : sans localisation autorisée, on ne va pas plus loin.
class LocationGateScreen extends StatefulWidget {
  const LocationGateScreen({super.key});

  @override
  State<LocationGateScreen> createState() => _LocationGateScreenState();
}

class _LocationGateScreenState extends State<LocationGateScreen> with WidgetsBindingObserver {
  LocationStatus _status = LocationStatus.denied;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Retour des réglages du téléphone : on revérifie sans rien demander.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy) _check(ask: false);
  }

  Future<void> _check({required bool ask}) async {
    setState(() => _busy = true);
    final (status, here) = await locate(ask: ask);
    if (!mounted) return;
    if (status != LocationStatus.granted) {
      setState(() {
        _status = status;
        _busy = false;
      });
      return;
    }
    final store = context.store;
    if (here != null) store.update(() => store.here = here);
    Navigator.pushReplacementNamed(context, R.onboarding);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    // Refus définitif ou GPS éteint : seul un passage par les réglages débloque.
    final needsSettings = _status == LocationStatus.deniedForever || _status == LocationStatus.serviceOff;
    Widget reason(IconData icon, String title, String text) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Ic(icon, size: 40, iconSize: 20),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Ts.b), Lab(text)])),
          ],
        );
    return Screen(
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
      gap: 18,
      foot: [
        if (needsSettings)
          Semantics(
            liveRegion: true,
            child: Text(
              _status == LocationStatus.serviceOff
                  ? 'La localisation de ton téléphone est éteinte. Active-la dans les réglages, puis reviens ici.'
                  : 'L’autorisation a été refusée. Ouvre les réglages de l’application et autorise la localisation.',
              textAlign: TextAlign.center,
              style: Ts.small.copyWith(fontWeight: FontWeight.w600, color: c.danger),
            ),
          ),
        Cta(
          needsSettings ? 'Ouvrir les réglages' : 'Autoriser la localisation',
          icon: needsSettings ? LucideIcons.settings : LucideIcons.locateFixed,
          busy: _busy,
          onTap: () => needsSettings ? openLocationSettings(_status) : _check(ask: true),
        ),
        if (needsSettings) LinkBtn('J’ai activé la localisation', onTap: () => _check(ask: false)),
      ],
      children: [
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(kRadius * 2)),
            child: Icon(LucideIcons.mapPinned, size: 44, color: c.onPrimary),
          ),
        ),
        const Heading('Active ta localisation', sub: 'i-fret a besoin de ta position pour fonctionner. Elle n’est utilisée que pendant que tu te sers de l’application.'),
        reason(LucideIcons.truck, 'Trouver les transporteurs proches', 'Ta demande part d’abord à ceux qui sont autour de toi.'),
        reason(LucideIcons.mapPin, 'Proposer ton point de chargement', 'La carte s’ouvre là où tu te trouves.'),
        reason(LucideIcons.route, 'Suivre la marchandise', 'Tu vois le camion avancer jusqu’à la livraison.'),
      ],
    );
  }
}
