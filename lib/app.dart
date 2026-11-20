import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/store.dart';
import 'routes.dart';
import 'screens/auth.dart';
import 'screens/chargeur/course.dart';
import 'screens/chargeur/demande.dart';
import 'screens/chargeur/home.dart';
import 'screens/chat.dart';
import 'screens/location_gate.dart';
import 'screens/onboarding.dart';
import 'screens/shared.dart';
import 'screens/splash.dart';
import 'screens/transporteur/home.dart';
import 'screens/transporteur/inscription.dart';
import 'screens/transporteur/mission.dart';
import 'services/device.dart';
import 'theme/tokens.dart';
import 'widgets/extras.dart';

class IfretApp extends StatefulWidget {
  const IfretApp({super.key});

  @override
  State<IfretApp> createState() => _IfretAppState();
}

class _IfretAppState extends State<IfretApp> {
  final _store = AppStore();
  final _net = NetMonitor();

  @override
  void initState() {
    super.initState();
    _net.start();
  }

  @override
  void dispose() {
    _net.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StoreScope(
        store: _store,
        child: MaterialApp(
          title: 'i-fret',
          debugShowCheckedModeBanner: false,
          theme: ifretTheme(),
          themeMode: ThemeMode.light,
          locale: const Locale('fr'),
          supportedLocales: const [Locale('fr')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
            // Fond clair partout : icônes de la barre d'état en sombre, sauf sur les écrans noirs.
            value: SystemUiOverlayStyle.dark,
            // Le texte suit le réglage de taille du téléphone, jusqu'à +30 % : au-delà, les écrans denses débordent.
            child: MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3, child: NetBanner(net: _net, child: child!)),
          ),
          routes: {
            R.splash: (_) => const SplashScreen(),
            R.gate: (_) => const LocationGateScreen(),
            R.onboarding: (_) => const OnboardingScreen(),
            R.compte: (_) => const CompteScreen(),
            R.telephone: (context) => TelephoneScreen(role: context.arg<Role>() ?? Role.chargeur),
            R.code: (context) {
              final (role, phone) = context.arg<(Role, String)>() ?? (Role.chargeur, '');
              return CodeScreen(role: role, phone: phone);
            },
            R.identite: (context) {
              final (role, phone) = context.arg<(Role, String)>() ?? (Role.chargeur, '');
              return IdentiteScreen(role: role, phone: phone);
            },
            R.conditions: (_) => const ConditionsScreen(),

            R.infos: (context) => InfosScreen(context.arg<Role>() ?? context.store.role),
            R.comptes: (context) => ComptesScreen(context.arg<Role>() ?? context.store.role),
            R.codeApp: (_) => const CodeAppScreen(),
            R.chat: (context) => ChatScreen(conversationId: context.arg<String>()),

            R.c: (context) => ChargeurShell(initialTab: context.arg<int>() ?? 0),
            R.cTrajet: (_) => const TrajetScreen(),
            R.cMarchandise: (_) => const MarchandiseScreen(),
            R.cVehicule: (_) => const VehiculeScreen(),
            R.cDetails: (_) => const DetailsScreen(),
            R.cRecap: (_) => const RecapScreen(),
            R.cPaiement: (_) => const PaiementScreen(),
            R.cRecherche: (context) => RechercheScreen(courseRef: context.arg<String>()),
            R.cSuivi: (context) => SuiviScreen(courseRef: context.arg<String>()),
            R.cChat: (_) => const ChatScreen(conversationId: 'rodrigue'),
            R.cSolde: (context) => SoldeScreen(courseRef: context.arg<String>()),
            R.cNotation: (context) => NotationScreen(Role.chargeur, courseRef: context.arg<String>()),
            R.cRecu: (context) => RecuScreen(courseRef: context.arg<String>()),
            R.cAnnulation: (context) => AnnulationScreen(courseRef: context.arg<String>()),
            R.cAdresses: (_) => const AdressesScreen(),
            R.cAdresse: (context) => AdresseScreen(address: context.arg<SavedAddress>()),
            R.cSignalement: (_) => const SignalementScreen(Role.chargeur),
            R.cParametres: (_) => const ParametresScreen(Role.chargeur),
            R.cNotifications: (_) => const NotificationsScreen(Role.chargeur),
            R.cAide: (_) => const AideScreen(Role.chargeur),

            R.tVehicule: (context) => TVehiculeScreen(editing: context.arg<bool>() ?? false),
            R.tDossier: (context) => TDossierScreen(editing: context.arg<bool>() ?? false),
            R.tAttente: (_) => const TAttenteScreen(),
            R.t: (context) => TransporteurShell(initialTab: context.arg<int>() ?? 0),
            R.tMission: (_) => const TMissionScreen(),
            R.tChargement: (_) => const TChargementScreen(),
            R.tArrivee: (_) => const TArriveeScreen(),
            R.tLivraison: (_) => const TLivraisonScreen(),
            R.tNotation: (_) => const NotationScreen(Role.transporteur),
            R.tSignalement: (_) => const SignalementScreen(Role.transporteur),
            R.tParametres: (_) => const ParametresScreen(Role.transporteur),
            R.tNotifications: (_) => const NotificationsScreen(Role.transporteur),
            R.tAide: (_) => const AideScreen(Role.transporteur),
          },
        ),
      );
}
