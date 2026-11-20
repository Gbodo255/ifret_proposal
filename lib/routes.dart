import 'package:flutter/widgets.dart';

import 'data/models.dart';

export 'data/models.dart' show Role;

/// Noms des routes. Les écrans d'un rôle sont rangés sous sa coque à onglets :
/// ouvrir `/chargeur/suivi` par lien direct empile donc l'accueil dessous.
abstract final class R {
  static const splash = '/';
  static const gate = '/localisation';
  static const onboarding = '/bienvenue';
  static const compte = '/compte';
  static const telephone = '/inscription';
  static const code = '/inscription-code';
  static const identite = '/inscription-profil';
  static const conditions = '/conditions';

  // Compte, communs aux deux rôles.
  static const infos = '/mon-compte';
  static const comptes = '/mon-compte-paiement';
  static const codeApp = '/mon-compte-code';
  static const chat = '/conversation';

  static const c = '/chargeur';
  static const cTrajet = '/chargeur/trajet';
  static const cMarchandise = '/chargeur/marchandise';
  static const cVehicule = '/chargeur/vehicule';
  static const cDetails = '/chargeur/details';
  static const cRecap = '/chargeur/recap';
  static const cPaiement = '/chargeur/paiement';
  static const cRecherche = '/chargeur/recherche';
  static const cSuivi = '/chargeur/suivi';
  static const cChat = '/chargeur/chat';
  static const cSolde = '/chargeur/solde';
  static const cNotation = '/chargeur/notation';
  static const cRecu = '/chargeur/recu';
  static const cAnnulation = '/chargeur/annulation';
  static const cAdresses = '/chargeur/adresses';
  static const cAdresse = '/chargeur/adresse';
  static const cSignalement = '/chargeur/signalement';
  static const cParametres = '/chargeur/parametres';
  static const cNotifications = '/chargeur/notifications';
  static const cAide = '/chargeur/aide';

  static const t = '/transporteur';
  static const tVehicule = '/inscription-vehicule';
  static const tDossier = '/inscription-dossier';
  static const tAttente = '/dossier-en-attente';
  static const tMission = '/transporteur/mission';
  static const tChargement = '/transporteur/chargement';
  static const tArrivee = '/transporteur/arrivee';
  static const tLivraison = '/transporteur/livraison';
  static const tNotation = '/transporteur/notation';
  static const tSignalement = '/transporteur/signalement';
  static const tParametres = '/transporteur/parametres';
  static const tNotifications = '/transporteur/notifications';
  static const tAide = '/transporteur/aide';
}

extension Nav on BuildContext {
  void go(String route, {Object? args}) => Navigator.pushNamed(this, route, arguments: args);

  /// Remplace toute la pile : changement de rôle, fin de parcours, déconnexion.
  void reset(String route, {Object? args}) => Navigator.pushNamedAndRemoveUntil(this, route, (_) => false, arguments: args);

  /// Fin d'un parcours : revient à la coque du rôle, sur l'onglet voulu.
  void home(Role role, {int tab = 0}) => reset(role == Role.chargeur ? R.c : R.t, args: tab);

  /// Argument de la route courante, ignoré s'il n'a pas le type attendu (lien direct).
  T? arg<T>() {
    final args = ModalRoute.of(this)?.settings.arguments;
    return args is T ? args : null;
  }
}
