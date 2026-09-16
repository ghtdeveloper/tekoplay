// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a fr locale. All the
// messages from the main program should be duplicated here with the same
// function name.

// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps, unnecessary_new
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names, avoid_escaping_inner_quotes
// ignore_for_file:unnecessary_string_interpolations, unnecessary_string_escapes

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = new MessageLookup();

typedef String MessageIfAbsent(String messageStr, List<dynamic> args);

class MessageLookup extends MessageLookupByLibrary {
  String get localeName => 'fr';

  static String m0(n) => "Avance +${n}";

  static String m1(count) => "Disponible : ${count} diamants";

  static String m2(amount, currency) => "Mise : ${amount} ${currency}";

  static String m3(amount) => "Votre mise de ${amount} 💎 sera remboursée";

  static String m4(n) => "Bonus +${n} cases";

  static String m5(n) => "Bot a capturé ! +${n} cases";

  static String m6(name) => "${name} : double à la maison, relance";

  static String m7(n) => "Bot a terminé un pion ! +${n} cases";

  static String m8(name) => "${name} a perdu le tour (3 doubles)";

  static String m9(name) => "${name} n\'a pas de mouvements";

  static String m10(name) =>
      "${name} : trois doubles à la maison, perd le tour";

  static String m11(n) => "Capturé ! +${n} cases";

  static String m12(n) => "Capturé ! Choisis un pion pour +${n}";

  static String m13(n) => "Capturé ! Touchez la pièce à déplacer +${n}";

  static String m14(code) => "Code : ${code}";

  static String m15(name, amount, original) =>
      "${name} a fait une contre-offre de ${amount} diamants (original : ${original})";

  static String m16(n) => "CPU : But ! +${n} cases";

  static String m17(n, value) => "Dé ${n} : ${value}";

  static String m18(current, total) => "exercice ${current} sur ${total}";

  static String m19(n) => "Arrivé au but ! +${n} cases";

  static String m20(n) => "Arrivé au but ! Choisis un pion pour +${n}";

  static String m21(cost) => "Coût : ${cost}";

  static String m22(amount) => "Solde insuffisant (vous avez ${amount})";

  static String m23(cost) =>
      "Pièces insuffisantes (vous avez besoin de ${cost} 🪙)";

  static String m24(cost) =>
      "Diamants insuffisants (vous avez besoin de ${cost} 💎)";

  static String m25(n) =>
      "Solde insuffisant pour la revanche (vous avez besoin de ${n} diamants)";

  static String m26(joined, total) => "${joined} / ${total} joueurs";

  static String m27(n) => "Déplacer ${n} cases";

  static String m28(n) => "${n} joueurs";

  static String m29(count, plural, difficulty) =>
      "Parchís vs ${count} CPU${plural} - ${difficulty}";

  static String m30(pieceNum, from, to) =>
      "Pièce ${pieceNum}  •  Case ${from} → ${to}";

  static String m31(name) => "${name} a rejoint la partie !";

  static String m32(name) => "${name} a gagné";

  static String m33(n) => "Arrivé au but ! +${n} cases";

  static String m34(n) => "Arrivé au but ! Touchez la pièce à déplacer +${n}";

  static String m35(n) => "${n} joueurs · recherche...";

  static String m36(n) => "Démarrage dans ${n}\"";

  static String m37(n) => "Touchez la pièce qui recevra +${n}";

  static String m38(name) => "Tour de ${name}";

  static String m39(n) => "En attente de ${n} joueur(s) de plus...";

  static String m40(amount) =>
      "Demande de retrait traitée : ${amount} diamants";

  static String m41(amount, currency) => "Ton solde : ${amount} ${currency}";

  static String m42(amount, currency) => "Ton solde : ${amount} ${currency}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "GameOverDraw": MessageLookupByLibrary.simpleMessage(
      "Match nul - Les remboursements seront traités...",
    ),
    "GameOverProcess": MessageLookupByLibrary.simpleMessage(
      "Partie terminée. Traitement des résultats...",
    ),
    "abandonGame": MessageLookupByLibrary.simpleMessage("Abandonner la partie"),
    "abandonGameWarning": MessageLookupByLibrary.simpleMessage(
      "Êtes-vous sûr de vouloir abandonner la partie ?\n\nSi vous quittez, cela comptera comme une défaite et vous perdrez des points.",
    ),
    "abandonWarningBet": MessageLookupByLibrary.simpleMessage(
      "Vous perdrez votre mise si vous abandonnez.",
    ),
    "abandonWarningFun": MessageLookupByLibrary.simpleMessage(
      "La partie en cours sera fermée.",
    ),
    "abandonWarningPase": MessageLookupByLibrary.simpleMessage(
      "Vous perdrez votre mise et votre caution si vous abandonnez. Les autres joueurs récupéreront leurs diamants.",
    ),
    "accept": MessageLookupByLibrary.simpleMessage("Accepter"),
    "acceptRematch": MessageLookupByLibrary.simpleMessage(
      "Accepter la revanche",
    ),
    "acceptTheirBet": MessageLookupByLibrary.simpleMessage(
      "Accepter leur mise",
    ),
    "acceptedYourCounterofferOf": MessageLookupByLibrary.simpleMessage(
      "a accepté votre contre-offre de",
    ),
    "acceptsYourBet": MessageLookupByLibrary.simpleMessage(
      "accepte votre mise",
    ),
    "accountCreated": MessageLookupByLibrary.simpleMessage(
      "Compte créé avec succès. Vérifiez votre e-mail.",
    ),
    "accountCreatedCheckEmail": MessageLookupByLibrary.simpleMessage(
      "Compte créé. Vérifiez votre email avant de vous connecter.",
    ),
    "accountCreatedUpdt": MessageLookupByLibrary.simpleMessage(
      "Compte créé avec succès !",
    ),
    "addAccount": MessageLookupByLibrary.simpleMessage("Ajouter un compte"),
    "adjustGameMusic": MessageLookupByLibrary.simpleMessage(
      "Ajuster le volume de la musique",
    ),
    "advanceNSteps": m0,
    "all": MessageLookupByLibrary.simpleMessage("Tous"),
    "allReadyStarting": MessageLookupByLibrary.simpleMessage(
      "Tout le monde est prêt ! Démarrage...",
    ),
    "almostExpandingSearch": MessageLookupByLibrary.simpleMessage(
      "Presque ! Élargissement de la recherche...",
    ),
    "anonymous": MessageLookupByLibrary.simpleMessage("Anonyme"),
    "appTitle": MessageLookupByLibrary.simpleMessage("Tekoplay"),
    "appleLogin": MessageLookupByLibrary.simpleMessage(
      "Se connecter avec Apple ID",
    ),
    "areYouSure": MessageLookupByLibrary.simpleMessage("Êtes-vous sûr ?"),
    "attempt": MessageLookupByLibrary.simpleMessage("Essaye"),
    "available": MessageLookupByLibrary.simpleMessage("disponibles"),
    "availableDiamondsCount": m1,
    "availableToWithdraw": MessageLookupByLibrary.simpleMessage(
      "Disponible pour retirer",
    ),
    "averageTime": MessageLookupByLibrary.simpleMessage("Temps Moyen"),
    "back": MessageLookupByLibrary.simpleMessage("Retour"),
    "backTo": MessageLookupByLibrary.simpleMessage("Retour"),
    "backupAmount": MessageLookupByLibrary.simpleMessage("Caution"),
    "bestValue": MessageLookupByLibrary.simpleMessage("MEILLEURE OFFRE !"),
    "bet": MessageLookupByLibrary.simpleMessage("Pari"),
    "betAmountDiamonds": MessageLookupByLibrary.simpleMessage(
      "Montant de la mise (diamants)",
    ),
    "betAmountLabel": MessageLookupByLibrary.simpleMessage(
      "Montant de la mise",
    ),
    "betCollectedReady": MessageLookupByLibrary.simpleMessage(
      "Mises collectées. Le jeu est prêt !",
    ),
    "betDisplay": m2,
    "betGamesRequirement": MessageLookupByLibrary.simpleMessage(
      "Pour les parties avec mise, vous avez besoin d\'au moins 50 diamants.",
    ),
    "betMode": MessageLookupByLibrary.simpleMessage("Mode mise"),
    "betNegotiation": MessageLookupByLibrary.simpleMessage(
      "Négociation de Mise",
    ),
    "betWillBeReturned": m3,
    "bishopStep1Desc": MessageLookupByLibrary.simpleMessage(
      "Déplacez le pion pour commencer à ouvrir des lignes.",
    ),
    "bishopStep1Title": MessageLookupByLibrary.simpleMessage(
      "Premier Mouvement",
    ),
    "bishopStep2Desc": MessageLookupByLibrary.simpleMessage(
      "Maintenant le fou peut se déplacer en diagonale.",
    ),
    "bishopStep2Title": MessageLookupByLibrary.simpleMessage(
      "Mouvement diagonal du Fou",
    ),
    "blacks": MessageLookupByLibrary.simpleMessage("Noirs"),
    "blueColor": MessageLookupByLibrary.simpleMessage("Bleu"),
    "bonusNSteps": m4,
    "botCapturedBonusN": m5,
    "botDoubleHomeReroll": m6,
    "botFinishedBonusN": m7,
    "botLostTurnTriple": m8,
    "botNoMoves": m9,
    "botTripleDoublesHome": m10,
    "buy": MessageLookupByLibrary.simpleMessage("Acheter"),
    "buyMore": MessageLookupByLibrary.simpleMessage("Achetez plus"),
    "camera": MessageLookupByLibrary.simpleMessage("Caméra"),
    "cancel": MessageLookupByLibrary.simpleMessage("Annuler"),
    "cancelNegotiation": MessageLookupByLibrary.simpleMessage(
      "Annuler la négociation",
    ),
    "cancelRoom": MessageLookupByLibrary.simpleMessage("Annuler la salle"),
    "cancelSearch": MessageLookupByLibrary.simpleMessage(
      "Annuler la recherche",
    ),
    "cannotCreateRematch": MessageLookupByLibrary.simpleMessage(
      "Impossible de créer la revanche",
    ),
    "capturedAnother": MessageLookupByLibrary.simpleMessage(
      "Capturé une autre !",
    ),
    "capturedBonusN": m11,
    "capturedChoosePiece": m12,
    "capturedNoBonus": MessageLookupByLibrary.simpleMessage(
      "Capturé ! Pas de bonus disponible",
    ),
    "capturedTouchPieceBonusN": m13,
    "capturedYourPiece": MessageLookupByLibrary.simpleMessage(
      "a capturé ta pièce",
    ),
    "changeColor": MessageLookupByLibrary.simpleMessage(
      "Sélectionnez votre couleur",
    ),
    "changeGameLanguage": MessageLookupByLibrary.simpleMessage(
      "Changer la langue du jeu",
    ),
    "check": MessageLookupByLibrary.simpleMessage("Échec !"),
    "checkOnline": MessageLookupByLibrary.simpleMessage("♚ ÉCHEC !"),
    "checkmate": MessageLookupByLibrary.simpleMessage("Échec et mat !"),
    "chess": MessageLookupByLibrary.simpleMessage("Échecs"),
    "chessPieceBishop": MessageLookupByLibrary.simpleMessage("Fou"),
    "chessPieceKing": MessageLookupByLibrary.simpleMessage("Roi"),
    "chessPieceKnight": MessageLookupByLibrary.simpleMessage("Cavalier"),
    "chessPiecePawn": MessageLookupByLibrary.simpleMessage("Pion"),
    "chessPieceQueen": MessageLookupByLibrary.simpleMessage("Dame"),
    "chessPieceRook": MessageLookupByLibrary.simpleMessage("Tour"),
    "chooseAnotherPiece": MessageLookupByLibrary.simpleMessage(
      "Choisir une autre pièce",
    ),
    "chooseBetAmountDiamonds": MessageLookupByLibrary.simpleMessage(
      "Choisissez le montant en diamants pour cette partie",
    ),
    "choosePerfectPackage": MessageLookupByLibrary.simpleMessage(
      "Choisissez le forfait parfait pour vous",
    ),
    "choosePlayerCountForGame": MessageLookupByLibrary.simpleMessage(
      "Choisissez le nombre de joueurs pour la partie",
    ),
    "close": MessageLookupByLibrary.simpleMessage("Fermer"),
    "codeLabelValue": m14,
    "coinStore": MessageLookupByLibrary.simpleMessage("Boutique de pièces"),
    "coins": MessageLookupByLibrary.simpleMessage("pièces"),
    "colorBlue": MessageLookupByLibrary.simpleMessage("Bleu"),
    "colorGreen": MessageLookupByLibrary.simpleMessage("Vert"),
    "colorRed": MessageLookupByLibrary.simpleMessage("Rouge"),
    "colorYellow": MessageLookupByLibrary.simpleMessage("Jaune"),
    "comingSoon": MessageLookupByLibrary.simpleMessage("BIENTÔT DISPONIBLE"),
    "completeDominoTutorial": MessageLookupByLibrary.simpleMessage(
      "Vous avez terminé le tutoriel de domino.",
    ),
    "completeTutorial": MessageLookupByLibrary.simpleMessage(
      "Vous avez terminé le tutoriel",
    ),
    "completingWithBots": MessageLookupByLibrary.simpleMessage(
      "Complétion avec des bots...",
    ),
    "congrats": MessageLookupByLibrary.simpleMessage("Félicitations"),
    "congratulations": MessageLookupByLibrary.simpleMessage("Félicitations !"),
    "congratulationsShort": MessageLookupByLibrary.simpleMessage(
      "Félicitations",
    ),
    "connectingWithPlayers": MessageLookupByLibrary.simpleMessage(
      "Connexion avec d\'autres joueurs...",
    ),
    "connectionError": MessageLookupByLibrary.simpleMessage(
      "Erreur de connexion",
    ),
    "contactSupport": MessageLookupByLibrary.simpleMessage(
      "Contactez notre équipe d\'assistance",
    ),
    "continueAsGuest": MessageLookupByLibrary.simpleMessage(
      "Continuer comme invité",
    ),
    "continueGame": MessageLookupByLibrary.simpleMessage("Continuer à jouer"),
    "copyLinkToShare": MessageLookupByLibrary.simpleMessage(
      "Copier le lien pour partager",
    ),
    "correctMove": MessageLookupByLibrary.simpleMessage(
      "Excellent ! Mouvement correct.",
    ),
    "couldNotPlayTile": MessageLookupByLibrary.simpleMessage(
      "Impossible de jouer la tuile",
    ),
    "counterOfferMsg": m15,
    "counterOfferTitle": MessageLookupByLibrary.simpleMessage(
      "Contre-offre de mise",
    ),
    "counteroffer": MessageLookupByLibrary.simpleMessage("Contre-offre"),
    "counterofferAccepted": MessageLookupByLibrary.simpleMessage(
      "Contre-offre Acceptée !",
    ),
    "cpu": MessageLookupByLibrary.simpleMessage("CPU"),
    "cpuDoubleHome": MessageLookupByLibrary.simpleMessage(
      "CPU : double à la maison, relance les dés.",
    ),
    "cpuOpponentCount": MessageLookupByLibrary.simpleMessage(
      "Nombre d\'adversaires CPU",
    ),
    "cpuReachedGoalBonusN": m16,
    "cpuTripleDoublesHome": MessageLookupByLibrary.simpleMessage(
      "CPU : triple double à la maison, perd le tour.",
    ),
    "cpuTurn": MessageLookupByLibrary.simpleMessage("Tour du CPU"),
    "cpuVs1Description": MessageLookupByLibrary.simpleMessage(
      "Vous jouerez 1 contre 1 contre le CPU en positions opposées",
    ),
    "cpuVs2Description": MessageLookupByLibrary.simpleMessage(
      "Vous jouerez contre 2 CPU (3 joueurs au total)",
    ),
    "cpuVs3Description": MessageLookupByLibrary.simpleMessage(
      "Vous jouerez contre 3 CPU (4 joueurs au total)",
    ),
    "cpuWon": MessageLookupByLibrary.simpleMessage("Le CPU a gagné"),
    "cpuWonCheckMate": MessageLookupByLibrary.simpleMessage(
      "Le CPU a gagné par échec et mat",
    ),
    "createAccount": MessageLookupByLibrary.simpleMessage("Créer un compte"),
    "createNewRoom": MessageLookupByLibrary.simpleMessage(
      "Créer une nouvelle salle",
    ),
    "createPublicGame": MessageLookupByLibrary.simpleMessage(
      "Créer une partie publique",
    ),
    "createdAgo": MessageLookupByLibrary.simpleMessage("Créé il y a"),
    "creatingRematch": MessageLookupByLibrary.simpleMessage(
      "Création de la revanche...",
    ),
    "customAmount": MessageLookupByLibrary.simpleMessage(
      "Montant personnalisé",
    ),
    "customNotifications": MessageLookupByLibrary.simpleMessage(
      "Personnaliser vos notifications",
    ),
    "defeats": MessageLookupByLibrary.simpleMessage("Défaites"),
    "deletePhoto": MessageLookupByLibrary.simpleMessage("Supprimer la photo"),
    "demo": MessageLookupByLibrary.simpleMessage("Démo"),
    "describeIssue": MessageLookupByLibrary.simpleMessage(
      "Décrivez votre problème ou question :",
    ),
    "diamondStore": MessageLookupByLibrary.simpleMessage(
      "Boutique de diamants",
    ),
    "diamonds": MessageLookupByLibrary.simpleMessage("diamants"),
    "diamondsOnlyChallenge": MessageLookupByLibrary.simpleMessage(
      "Diamants uniquement - Prêt pour le défi ?",
    ),
    "diceNValue": m17,
    "difficult": MessageLookupByLibrary.simpleMessage("Difficile"),
    "difficulty": MessageLookupByLibrary.simpleMessage("pot"),
    "difficultyMax": MessageLookupByLibrary.simpleMessage(
      "Difficulté : Maximum",
    ),
    "difficultyMaxNote": MessageLookupByLibrary.simpleMessage(
      "En mode mise, le CPU joue au niveau maximum.",
    ),
    "domino": MessageLookupByLibrary.simpleMessage("Domino"),
    "dominoFriends": MessageLookupByLibrary.simpleMessage("Domino - Amis"),
    "dominoPaseFriends": MessageLookupByLibrary.simpleMessage("El Pase - Amis"),
    "dominoPaseTitle": MessageLookupByLibrary.simpleMessage("Domino Pase"),
    "dominoPaseWaitingRoom": MessageLookupByLibrary.simpleMessage(
      "Salle El Pase",
    ),
    "dominoPaseWaitingRoomFriends": MessageLookupByLibrary.simpleMessage(
      "Salle El Pase - Amis",
    ),
    "dominoTutorial": MessageLookupByLibrary.simpleMessage(
      "Tutoriel de domino",
    ),
    "dominoVsCpu": MessageLookupByLibrary.simpleMessage("Domino contre CPU"),
    "doubleHome": MessageLookupByLibrary.simpleMessage(
      "Double à la maison ! Rejouez.",
    ),
    "doublesRollAgain": MessageLookupByLibrary.simpleMessage(
      "Doubles ! Relancez",
    ),
    "doublesWarningPenalty": MessageLookupByLibrary.simpleMessage(
      "Doubles x2 ! ⚠ Un autre double = pénalité",
    ),
    "drawBetReturned": MessageLookupByLibrary.simpleMessage(
      "Égalité : Votre mise de a été remboursée",
    ),
    "drawByStalemate": MessageLookupByLibrary.simpleMessage(
      "Match nul par pat !",
    ),
    "drawMsg": MessageLookupByLibrary.simpleMessage("Match nul"),
    "earned": MessageLookupByLibrary.simpleMessage("gagnés"),
    "earningsDiamonds": MessageLookupByLibrary.simpleMessage(
      "Gains (Diamants)",
    ),
    "easy": MessageLookupByLibrary.simpleMessage("Facile"),
    "email": MessageLookupByLibrary.simpleMessage("E-mail"),
    "emailAlreadyRegistered": MessageLookupByLibrary.simpleMessage(
      "L\'adresse e-mail saisie est déjà enregistrée, veuillez en utiliser une autre",
    ),
    "emailLogin": MessageLookupByLibrary.simpleMessage(
      "Se connecter avec Tekoplay",
    ),
    "emailNotVerified": MessageLookupByLibrary.simpleMessage(
      "Vérifiez votre email avant de vous connecter",
    ),
    "emailVerifiedSuccess": MessageLookupByLibrary.simpleMessage(
      "E-mail vérifié avec succès ! Vous pouvez maintenant accéder à toutes les fonctionnalités.",
    ),
    "emptyPotDomino": MessageLookupByLibrary.simpleMessage("Le pot est vide"),
    "endGame": MessageLookupByLibrary.simpleMessage("Fin de la partie"),
    "endOfGame": MessageLookupByLibrary.simpleMessage("FIN DU JEU"),
    "enoughToPlay": MessageLookupByLibrary.simpleMessage(
      "suffisants pour jouer",
    ),
    "enterAmount": MessageLookupByLibrary.simpleMessage("Entrez le montant"),
    "enterAmountToWithdraw": MessageLookupByLibrary.simpleMessage(
      "Saisissez le montant à retirer",
    ),
    "enterBetAmountHint": MessageLookupByLibrary.simpleMessage(
      "Saisissez un montant",
    ),
    "enterEmailToReset": MessageLookupByLibrary.simpleMessage(
      "Entrez votre email pour recevoir un lien de récupération",
    ),
    "enterFriendEmail": MessageLookupByLibrary.simpleMessage(
      "Entrez l\'e-mail de votre ami",
    ),
    "enterGuestEmails": MessageLookupByLibrary.simpleMessage(
      "Entrez l\'e-mail de chaque invité",
    ),
    "enterValidEmail": MessageLookupByLibrary.simpleMessage(
      "Entrez un email valide",
    ),
    "error": MessageLookupByLibrary.simpleMessage("Erreur"),
    "errorAcceptInvitation": MessageLookupByLibrary.simpleMessage(
      "Erreur lors de l\'acceptation de l\'invitation",
    ),
    "errorAcceptedInvitation": MessageLookupByLibrary.simpleMessage(
      "Erreur lors de l\'acceptation de l\'invitation",
    ),
    "errorAcceptingCounteroffer": MessageLookupByLibrary.simpleMessage(
      "Erreur lors de l\'acceptation de la contre-offre",
    ),
    "errorCreateAccount": MessageLookupByLibrary.simpleMessage(
      "Erreur lors de la création du compte",
    ),
    "errorCreatePublicGame": MessageLookupByLibrary.simpleMessage(
      "Erreur lors de la création de la partie",
    ),
    "errorCreatingAccount": MessageLookupByLibrary.simpleMessage(
      "Erreur lors de la création du compte",
    ),
    "errorCreatingRoom": MessageLookupByLibrary.simpleMessage(
      "Erreur lors de la création de la salle. Veuillez réessayer.",
    ),
    "errorJoinGame": MessageLookupByLibrary.simpleMessage(
      "Impossible de rejoindre la partie",
    ),
    "errorLogin": MessageLookupByLibrary.simpleMessage(
      "Erreur lors de la connexion",
    ),
    "errorMakeMove": MessageLookupByLibrary.simpleMessage(
      "Erreur lors de l\'exécution du mouvement",
    ),
    "errorProcessInvitation": MessageLookupByLibrary.simpleMessage(
      "Erreur lors du traitement de l\'invitation",
    ),
    "errorRejectingCounteroffer": MessageLookupByLibrary.simpleMessage(
      "Erreur lors du refus de la contre-offre",
    ),
    "errorResendEmail": MessageLookupByLibrary.simpleMessage(
      "Erreur lors du renvoi de l\'e-mail",
    ),
    "errorResult": MessageLookupByLibrary.simpleMessage(
      "Erreur lors du traitement du résultat",
    ),
    "errorSearchGame": MessageLookupByLibrary.simpleMessage(
      "Erreur lors de la recherche de partie",
    ),
    "errorSendMove": MessageLookupByLibrary.simpleMessage(
      "Erreur lors de l\'envoi du mouvement",
    ),
    "errorSendingPasswordReset": MessageLookupByLibrary.simpleMessage(
      "Erreur lors de l\'envoi de l\'email de récupération de mot de passe",
    ),
    "errorSignInEmail": MessageLookupByLibrary.simpleMessage(
      "Erreur de connexion. Vérifiez vos informations d\'identification.",
    ),
    "errorSignInFacebook": MessageLookupByLibrary.simpleMessage(
      "Erreur lors de la connexion avec Facebook",
    ),
    "errorSignInGoogle": MessageLookupByLibrary.simpleMessage(
      "Erreur de connexion avec Google",
    ),
    "exercise": MessageLookupByLibrary.simpleMessage("exercice"),
    "exerciseOf": m18,
    "exit": MessageLookupByLibrary.simpleMessage("Quitter"),
    "extremes": MessageLookupByLibrary.simpleMessage("Extrémités"),
    "facebookLogin": MessageLookupByLibrary.simpleMessage(
      "Se connecter avec Facebook",
    ),
    "fillAllFields": MessageLookupByLibrary.simpleMessage(
      "Remplissez tous les champs",
    ),
    "findNewOpponent": MessageLookupByLibrary.simpleMessage(
      "Chercher un nouvel adversaire",
    ),
    "finish": MessageLookupByLibrary.simpleMessage("Terminer"),
    "finishedBonusN": m19,
    "finishedChoosePiece": m20,
    "firstMove": MessageLookupByLibrary.simpleMessage("(Premier mouvement :"),
    "firstMoveCompleted": MessageLookupByLibrary.simpleMessage(
      "Bien joué ! Coup correct",
    ),
    "forThisBet": MessageLookupByLibrary.simpleMessage("pour ce pari"),
    "forgotPassword": MessageLookupByLibrary.simpleMessage(
      "Mot de passe oublié ?",
    ),
    "friendEmailLabel": MessageLookupByLibrary.simpleMessage(
      "E-mail de l\'ami",
    ),
    "fun": MessageLookupByLibrary.simpleMessage("Divertissement"),
    "funGamesRequirement": MessageLookupByLibrary.simpleMessage(
      "Pour les parties de divertissement, vous avez besoin d\'au moins 100 pièces.",
    ),
    "funMode": MessageLookupByLibrary.simpleMessage("Mode divertissement"),
    "gallery": MessageLookupByLibrary.simpleMessage("Galerie"),
    "gameCode": MessageLookupByLibrary.simpleMessage("Code de la partie"),
    "gameCostLabel": m21,
    "gameDraw": MessageLookupByLibrary.simpleMessage(
      "La partie s’est terminée par un match nul",
    ),
    "gameHasBeenCancelled": MessageLookupByLibrary.simpleMessage(
      "La partie a été annulée",
    ),
    "gameHistory": MessageLookupByLibrary.simpleMessage(
      "Historique des parties",
    ),
    "gameInvitation": MessageLookupByLibrary.simpleMessage("Invitation de jeu"),
    "gameMusic": MessageLookupByLibrary.simpleMessage("Musique du jeu"),
    "gameNotFound": MessageLookupByLibrary.simpleMessage("Jeu non trouvé"),
    "gameOver": MessageLookupByLibrary.simpleMessage("Fin de la partie"),
    "gamePlayed": MessageLookupByLibrary.simpleMessage("Parties jouées"),
    "gameStats": MessageLookupByLibrary.simpleMessage("Statistiques du jeu"),
    "games": MessageLookupByLibrary.simpleMessage("Parties"),
    "generalSummary": MessageLookupByLibrary.simpleMessage("Résumé Général"),
    "generatedAndCopiedCode": MessageLookupByLibrary.simpleMessage(
      "Code généré et copié",
    ),
    "getMore": MessageLookupByLibrary.simpleMessage("Obtenez plus"),
    "getMoreCoins": MessageLookupByLibrary.simpleMessage(
      "Obtenez plus de pièces !",
    ),
    "getMoreDiamonds": MessageLookupByLibrary.simpleMessage(
      "Obtenez plus de diamants !",
    ),
    "googleLogin": MessageLookupByLibrary.simpleMessage(
      "Se connecter avec Google",
    ),
    "googlePayNotAvailable": MessageLookupByLibrary.simpleMessage(
      "Google Pay n\'est pas disponible sur cet appareil",
    ),
    "greenColor": MessageLookupByLibrary.simpleMessage("Vert"),
    "guestEmailLabel": MessageLookupByLibrary.simpleMessage(
      "E-mail de l\'invité",
    ),
    "hasBet": MessageLookupByLibrary.simpleMessage("a misé :"),
    "hasLeftTheGame": MessageLookupByLibrary.simpleMessage(
      "a quitté la partie",
    ),
    "howManyPlayers": MessageLookupByLibrary.simpleMessage(
      "Combien de joueurs ?",
    ),
    "howMuchBet": MessageLookupByLibrary.simpleMessage(
      "Combien voulez-vous miser ?",
    ),
    "inOurStore": MessageLookupByLibrary.simpleMessage("dans notre boutique."),
    "incorrectMove": MessageLookupByLibrary.simpleMessage("Coup incorrect"),
    "incorrectTab": MessageLookupByLibrary.simpleMessage(
      "Mauvaise tuile. Essaye avec la tuile",
    ),
    "insufficientBalanceAmount": m22,
    "insufficientCoins": m23,
    "insufficientDiamonds": m24,
    "insufficientDiamondsForRematch": m25,
    "insufficientForRematch": MessageLookupByLibrary.simpleMessage(
      "Solde insuffisant pour la revanche",
    ),
    "insufficientFunds": MessageLookupByLibrary.simpleMessage(
      "Fonds insuffisants",
    ),
    "invalidAmountError": MessageLookupByLibrary.simpleMessage(
      "Montant invalide",
    ),
    "invalidAmountToWithdraw": MessageLookupByLibrary.simpleMessage(
      "Montant invalide à retirer",
    ),
    "invalidBetAmount": MessageLookupByLibrary.simpleMessage(
      "Montant de mise invalide",
    ),
    "invalidCredentials": MessageLookupByLibrary.simpleMessage(
      "Identifiants incorrects",
    ),
    "invitationRejected": MessageLookupByLibrary.simpleMessage(
      "La demande de jeu a été refusée",
    ),
    "invitationSentWaiting": MessageLookupByLibrary.simpleMessage(
      "Invitation envoyée ! En attente que votre ami accepte...",
    ),
    "invitations": MessageLookupByLibrary.simpleMessage("Invitations"),
    "inviteAnotherFriend": MessageLookupByLibrary.simpleMessage(
      "Inviter un autre ami",
    ),
    "inviteFriend": MessageLookupByLibrary.simpleMessage("Inviter un ami"),
    "inviteFriends": MessageLookupByLibrary.simpleMessage("Inviter des amis"),
    "invitesYou": MessageLookupByLibrary.simpleMessage("vous invite"),
    "invitesYouToPlay": MessageLookupByLibrary.simpleMessage(
      "vous invite à jouer",
    ),
    "join": MessageLookupByLibrary.simpleMessage("Rejoindre"),
    "joinRoom": MessageLookupByLibrary.simpleMessage("Rejoindre la salle"),
    "joinedOfTotal": m26,
    "kingStep1Desc": MessageLookupByLibrary.simpleMessage(
      "Le roi peut se déplacer d\'une case dans n\'importe quelle direction. Déplacez-le horizontalement.",
    ),
    "kingStep1Title": MessageLookupByLibrary.simpleMessage("Le Roi au Centre"),
    "kingStep2Desc": MessageLookupByLibrary.simpleMessage(
      "Maintenant déplacez le roi verticalement vers le haut.",
    ),
    "kingStep2Title": MessageLookupByLibrary.simpleMessage(
      "Mouvement vertical",
    ),
    "kingStep3Desc": MessageLookupByLibrary.simpleMessage(
      "Le roi peut également se déplacer en diagonale. Déplacez-le en diagonale.",
    ),
    "kingStep3Title": MessageLookupByLibrary.simpleMessage(
      "Mouvement diagonal",
    ),
    "kingStep4Desc": MessageLookupByLibrary.simpleMessage(
      "Le roi est polyvalent : horizontal, vertical et diagonal. Déplacez-le comme vous voulez !",
    ),
    "kingStep4Title": MessageLookupByLibrary.simpleMessage(
      "Toutes les Directions",
    ),
    "knightStep1Desc": MessageLookupByLibrary.simpleMessage(
      "Le cavalier se déplace en forme de L.",
    ),
    "knightStep1Title": MessageLookupByLibrary.simpleMessage("Mouvement en L"),
    "knightStep2Desc": MessageLookupByLibrary.simpleMessage(
      "Le cavalier peut sauter par-dessus d\'autres pièces.",
    ),
    "knightStep2Title": MessageLookupByLibrary.simpleMessage(
      "Le Cavalier Saute",
    ),
    "language": MessageLookupByLibrary.simpleMessage("Langue"),
    "languageEn": MessageLookupByLibrary.simpleMessage("Anglais"),
    "languageEs": MessageLookupByLibrary.simpleMessage("Espagnol"),
    "languageFr": MessageLookupByLibrary.simpleMessage("Français"),
    "languageSelect": MessageLookupByLibrary.simpleMessage(
      "Sélectionner la langue",
    ),
    "left": MessageLookupByLibrary.simpleMessage("gauche"),
    "letGameBegin": MessageLookupByLibrary.simpleMessage(
      "Que la partie commence !",
    ),
    "linkCopied": MessageLookupByLibrary.simpleMessage("Lien copié"),
    "loadingDots": MessageLookupByLibrary.simpleMessage("Chargement..."),
    "loadingGame": MessageLookupByLibrary.simpleMessage(
      "Chargement de la partie...",
    ),
    "loadingHistory": MessageLookupByLibrary.simpleMessage(
      "Chargement de l\'historique...",
    ),
    "loadingRanking": MessageLookupByLibrary.simpleMessage(
      "Chargement des classements...",
    ),
    "logIn": MessageLookupByLibrary.simpleMessage("Se connecter"),
    "loggedInAs": MessageLookupByLibrary.simpleMessage("Connecté en tant que"),
    "login": MessageLookupByLibrary.simpleMessage("Connexion"),
    "loginRequired": MessageLookupByLibrary.simpleMessage("Connexion requise"),
    "loginToAccessFeatures": MessageLookupByLibrary.simpleMessage(
      "Pour accéder à toutes les fonctionnalités et sauvegarder votre progression, connectez-vous avec votre compte.",
    ),
    "loginToSaveProgress": MessageLookupByLibrary.simpleMessage(
      "Connectez-vous pour sauvegarder votre progression",
    ),
    "lose": MessageLookupByLibrary.simpleMessage("Défaite"),
    "madeNewCounteroffer": MessageLookupByLibrary.simpleMessage(
      "a fait une nouvelle contre-offre :",
    ),
    "makeCounteroffer": MessageLookupByLibrary.simpleMessage(
      "Faire une contre-offre",
    ),
    "marker": MessageLookupByLibrary.simpleMessage("Tableau de score"),
    "me": MessageLookupByLibrary.simpleMessage("Moi"),
    "meLabel": MessageLookupByLibrary.simpleMessage("Moi"),
    "megaPack": MessageLookupByLibrary.simpleMessage("MEGA PACK !"),
    "messages": MessageLookupByLibrary.simpleMessage(
      "Recevoir de nouveaux messages",
    ),
    "minute": MessageLookupByLibrary.simpleMessage("minute"),
    "mostPopular": MessageLookupByLibrary.simpleMessage("LE PLUS POPULAIRE !"),
    "moveButton": MessageLookupByLibrary.simpleMessage("Déplacer"),
    "moveHorses": MessageLookupByLibrary.simpleMessage(
      "Déplacer les cavaliers",
    ),
    "moveNSquares": m27,
    "movePiece": MessageLookupByLibrary.simpleMessage("Déplacer pièce"),
    "moveTowers": MessageLookupByLibrary.simpleMessage("Déplacer les tours"),
    "movement": MessageLookupByLibrary.simpleMessage("Mouvements"),
    "movingPaws": MessageLookupByLibrary.simpleMessage("Déplacer les pions"),
    "multiplayer": MessageLookupByLibrary.simpleMessage("Partie multijoueur"),
    "nPlayersLabel": m28,
    "name": MessageLookupByLibrary.simpleMessage("Nom"),
    "needAtLeast100": MessageLookupByLibrary.simpleMessage(
      "Vous avez besoin d\'au moins 100",
    ),
    "needDoubleForBet": MessageLookupByLibrary.simpleMessage(
      "Vous avez besoin du double de la mise (mise + caution)",
    ),
    "negotiatingBet": MessageLookupByLibrary.simpleMessage(
      "Négociation de la mise...",
    ),
    "netCoins": MessageLookupByLibrary.simpleMessage("Pièces (net)"),
    "netDiamonds": MessageLookupByLibrary.simpleMessage("Diamants (net)"),
    "newCounteroffer": MessageLookupByLibrary.simpleMessage(
      "Nouvelle contre-offre",
    ),
    "newGame": MessageLookupByLibrary.simpleMessage("Nouvelle partie"),
    "next": MessageLookupByLibrary.simpleMessage("Suivant"),
    "nextRound": MessageLookupByLibrary.simpleMessage("Manche suivante"),
    "noInvitation": MessageLookupByLibrary.simpleMessage("Aucune invitation"),
    "noMoreChips": MessageLookupByLibrary.simpleMessage(
      "Il n’y a plus de jetons dans le pot",
    ),
    "noPublicGame": MessageLookupByLibrary.simpleMessage(
      "Aucune partie disponible",
    ),
    "noTime": MessageLookupByLibrary.simpleMessage("Temps écoulé"),
    "noValidMoves": MessageLookupByLibrary.simpleMessage(
      "Aucun mouvement valide. Tour annulé.",
    ),
    "noWithdrawableDiamonds": MessageLookupByLibrary.simpleMessage(
      "Aucun diamant disponible pour le retrait",
    ),
    "nominalBet": MessageLookupByLibrary.simpleMessage("Mise nominale"),
    "normal": MessageLookupByLibrary.simpleMessage("Normal"),
    "notAllowed": MessageLookupByLibrary.simpleMessage(
      "Cette tuile ne peut pas être connectée ici",
    ),
    "notEnough": MessageLookupByLibrary.simpleMessage(
      "Vous n\'en avez pas assez",
    ),
    "notEnoughCurrencyForMultiplayer": MessageLookupByLibrary.simpleMessage(
      "Vous n\'avez pas assez de pièces ou de diamants pour participer à des parties multijoueurs",
    ),
    "notPlayedGameYet": MessageLookupByLibrary.simpleMessage(
      "Vous n\'avez encore joué aucune partie",
    ),
    "notRankingIn": MessageLookupByLibrary.simpleMessage(
      "Vous n\'avez pas de classement dans",
    ),
    "notRankingInfo": MessageLookupByLibrary.simpleMessage(
      "Aucune donnée de classement disponible",
    ),
    "notifications": MessageLookupByLibrary.simpleMessage("Notifications"),
    "nowYouTry": MessageLookupByLibrary.simpleMessage("À toi d’essayer"),
    "offlineOpponent": MessageLookupByLibrary.simpleMessage(
      "Votre adversaire s\'est déconnecté",
    ),
    "online": MessageLookupByLibrary.simpleMessage("En ligne"),
    "onlineGame": MessageLookupByLibrary.simpleMessage("Partie en ligne"),
    "onlyEmailAccounts": MessageLookupByLibrary.simpleMessage(
      "Disponible uniquement pour les comptes email",
    ),
    "opponentAbandoned": MessageLookupByLibrary.simpleMessage(
      "L\'adversaire a abandonné la partie",
    ),
    "opponentAbandonedMessage": MessageLookupByLibrary.simpleMessage(
      "Votre adversaire a abandonné la partie.\n\nVous avez gagné automatiquement !",
    ),
    "opponentEmail": MessageLookupByLibrary.simpleMessage(
      "E-mail de l\'adversaire",
    ),
    "opponentFound": MessageLookupByLibrary.simpleMessage(
      "Adversaire Trouvé !",
    ),
    "opponentLeft": MessageLookupByLibrary.simpleMessage(
      "L\'adversaire a quitté",
    ),
    "opponentLostByTimeout": MessageLookupByLibrary.simpleMessage(
      "L\'adversaire a perdu par dépassement de temps",
    ),
    "opponentNotFound": MessageLookupByLibrary.simpleMessage(
      "Aucun adversaire trouvé",
    ),
    "opponentRejectedCounteroffer": MessageLookupByLibrary.simpleMessage(
      "L\'adversaire a rejeté votre contre-offre.",
    ),
    "opponentTimeRunOutMessage": MessageLookupByLibrary.simpleMessage(
      "Votre adversaire n\'a plus de temps",
    ),
    "opponentTurn": MessageLookupByLibrary.simpleMessage(
      "Tour de l\'adversaire",
    ),
    "outOfTime": MessageLookupByLibrary.simpleMessage("Temps écoulé"),
    "parchisOnline": MessageLookupByLibrary.simpleMessage("Ludo en ligne"),
    "parchisShort": MessageLookupByLibrary.simpleMessage("Jeu de ludo"),
    "parchisVsCpu": m29,
    "parchisVsFriend": MessageLookupByLibrary.simpleMessage("Ludo vs Ami"),
    "pase": MessageLookupByLibrary.simpleMessage("El Pase"),
    "paseBetBody": MessageLookupByLibrary.simpleMessage(
      "Pour entrer, vous avez besoin du double de votre mise comme solde minimum.\n\nLe gagnant remporte le pot moins une commission de 10%.\n\nLes paiements de \"passe\" s\'ajoutent ou se soustraient du prix final de chaque joueur.",
    ),
    "paseBetHighlight": MessageLookupByLibrary.simpleMessage(
      "Diamants uniquement — sans pièces",
    ),
    "paseBetTitle": MessageLookupByLibrary.simpleMessage("La Mise"),
    "paseHowToPlay": MessageLookupByLibrary.simpleMessage("Comment jouer"),
    "paseHowToPlayBody": MessageLookupByLibrary.simpleMessage(
      "Au début, chaque joueur reçoit 7 tuiles. Le joueur avec le double le plus élevé commence.\n\nPlacez les tuiles en connectant les numéros correspondants aux extrémités de la chaîne.",
    ),
    "paseHowToWin": MessageLookupByLibrary.simpleMessage("Comment gagner ?"),
    "paseHowToWinBody": MessageLookupByLibrary.simpleMessage(
      "Le joueur qui place toutes ses tuiles en premier gagne.\n\nSi la partie est bloquée (personne ne peut jouer), le joueur avec le moins de points dans ses tuiles restantes gagne.",
    ),
    "paseThePase": MessageLookupByLibrary.simpleMessage("Le Passe !"),
    "paseThePaseBody": MessageLookupByLibrary.simpleMessage(
      "Si vous ne pouvez jouer aucune tuile, vous devez passer votre tour. Quand vous passez, chacun de vos rivaux vous paie une quantité en diamants.\n\nVous pouvez aussi passer s\'il y a un blocage total (personne ne peut jouer).",
    ),
    "paseThePaseHighlight": MessageLookupByLibrary.simpleMessage(
      "Passer peut être rentable !",
    ),
    "paseTutorialTitle": MessageLookupByLibrary.simpleMessage(
      "Comment jouer — El Pase",
    ),
    "paseWhatBody": MessageLookupByLibrary.simpleMessage(
      "El Pase est un mode spécial de domino pour 3 ou 4 joueurs.\n\nUne seule main est jouée par partie, avec des diamants uniquement.",
    ),
    "paseWhatIsIt": MessageLookupByLibrary.simpleMessage(
      "Qu\'est-ce que El Pase ?",
    ),
    "pass": MessageLookupByLibrary.simpleMessage("Passe"),
    "passAutomatic": MessageLookupByLibrary.simpleMessage(
      "Aucune option, vous passez automatiquement",
    ),
    "passCountLabel": MessageLookupByLibrary.simpleMessage("Passes"),
    "passValueLabel": MessageLookupByLibrary.simpleMessage("Valeur du passe"),
    "passed": MessageLookupByLibrary.simpleMessage("Passé"),
    "password": MessageLookupByLibrary.simpleMessage("Mot de passe"),
    "passwordResetSent": MessageLookupByLibrary.simpleMessage(
      "Email de récupération envoyé. Vérifiez votre boîte de réception.",
    ),
    "pawnStep1Desc": MessageLookupByLibrary.simpleMessage(
      "Les pions avancent d\'une case vers l\'avant.",
    ),
    "pawnStep1Title": MessageLookupByLibrary.simpleMessage(
      "Mouvement de base du Pion",
    ),
    "pawnStep2Desc": MessageLookupByLibrary.simpleMessage(
      "Lors de leur premier mouvement, un pion peut avancer de deux cases.",
    ),
    "pawnStep2Title": MessageLookupByLibrary.simpleMessage(
      "Avance de deux cases",
    ),
    "pawnStep3Desc": MessageLookupByLibrary.simpleMessage(
      "Le pion capture les pièces ennemies en se déplaçant en diagonale.",
    ),
    "pawnStep3Title": MessageLookupByLibrary.simpleMessage(
      "Capture en diagonale",
    ),
    "paymentProcessingError": MessageLookupByLibrary.simpleMessage(
      "Erreur lors du traitement du paiement",
    ),
    "pieceNSquareFromTo": m30,
    "play": MessageLookupByLibrary.simpleMessage("Jouer !"),
    "playAgain": MessageLookupByLibrary.simpleMessage("Rejouer"),
    "playOnline": MessageLookupByLibrary.simpleMessage("Jouer en ligne"),
    "playVsComputer": MessageLookupByLibrary.simpleMessage(
      "Jouer contre l’ordinateur",
    ),
    "playWithFriend": MessageLookupByLibrary.simpleMessage("Jouer avec un ami"),
    "playerAbandonedGame": MessageLookupByLibrary.simpleMessage(
      "Un joueur a abandonné la partie",
    ),
    "playerAbandonedGameMsg": MessageLookupByLibrary.simpleMessage(
      "Un joueur a abandonné la partie.",
    ),
    "playerJoinedGame": m31,
    "playerVsCpu": MessageLookupByLibrary.simpleMessage("Joueur vs CPU"),
    "playerWon": m32,
    "players3total": MessageLookupByLibrary.simpleMessage("(3 joueurs)"),
    "players4total": MessageLookupByLibrary.simpleMessage("(4 joueurs)"),
    "playing": MessageLookupByLibrary.simpleMessage("En jeu"),
    "playingAsGuest": MessageLookupByLibrary.simpleMessage(
      "En jouant comme invité !",
    ),
    "pleaseEnterValidCode": MessageLookupByLibrary.simpleMessage(
      "Veuillez entrer un code valide",
    ),
    "pleaseFillAllFields": MessageLookupByLibrary.simpleMessage(
      "Veuillez remplir tous les champs",
    ),
    "pleaseWriteIssue": MessageLookupByLibrary.simpleMessage(
      "Veuillez écrire un message",
    ),
    "point": MessageLookupByLibrary.simpleMessage("Points"),
    "poker": MessageLookupByLibrary.simpleMessage("Poker"),
    "popular": MessageLookupByLibrary.simpleMessage("POPULAIRE !"),
    "privacy": MessageLookupByLibrary.simpleMessage(
      "Politique de confidentialité",
    ),
    "privacyTitle": MessageLookupByLibrary.simpleMessage("Confidentialité"),
    "processing": MessageLookupByLibrary.simpleMessage(
      "Traitement en cours...",
    ),
    "profilePhotoDeleted": MessageLookupByLibrary.simpleMessage(
      "Photo de profil supprimée",
    ),
    "profilePhotoUpdated": MessageLookupByLibrary.simpleMessage(
      "Photo de profil mise à jour",
    ),
    "publicGame": MessageLookupByLibrary.simpleMessage("Parties publiques"),
    "purchaseSuccessful": MessageLookupByLibrary.simpleMessage(
      "Achat réussi !",
    ),
    "qualifier": MessageLookupByLibrary.simpleMessage("Qualification"),
    "queenStep1Desc": MessageLookupByLibrary.simpleMessage(
      "D\'abord déplacez le pion pour ouvrir la diagonale de la reine.",
    ),
    "queenStep1Title": MessageLookupByLibrary.simpleMessage(
      "Dégager le chemin",
    ),
    "queenStep2Desc": MessageLookupByLibrary.simpleMessage(
      "Maintenant la reine peut se déplacer librement en diagonale.",
    ),
    "queenStep2Title": MessageLookupByLibrary.simpleMessage(
      "Pouvoir de la Reine - Mouvement diagonal",
    ),
    "queenStep3Desc": MessageLookupByLibrary.simpleMessage(
      "La reine se déplace comme une tour en lignes droites.",
    ),
    "queenStep3Title": MessageLookupByLibrary.simpleMessage(
      "Mouvement horizontal de la Reine",
    ),
    "queenStep4Desc": MessageLookupByLibrary.simpleMessage(
      "La reine peut capturer des pièces ennemies.",
    ),
    "queenStep4Title": MessageLookupByLibrary.simpleMessage("La Reine Capture"),
    "quickAmounts": MessageLookupByLibrary.simpleMessage("Montants rapides :"),
    "ranking": MessageLookupByLibrary.simpleMessage("Classement"),
    "reachedGoalBonusN": m33,
    "reachedGoalNoBonus": MessageLookupByLibrary.simpleMessage(
      "Arrivé au but ! Pas de bonus disponible",
    ),
    "reachedGoalTouchPieceBonusN": m34,
    "realPlayersNoBots": MessageLookupByLibrary.simpleMessage(
      "Recherche de joueurs",
    ),
    "realPlayersOnly": MessageLookupByLibrary.simpleMessage(
      "Recherche de joueurs",
    ),
    "reconnecting": MessageLookupByLibrary.simpleMessage("Reconnexion..."),
    "recovered": MessageLookupByLibrary.simpleMessage("Récupéré"),
    "redColor": MessageLookupByLibrary.simpleMessage("Rouge"),
    "reject": MessageLookupByLibrary.simpleMessage("Refuser"),
    "rematch": MessageLookupByLibrary.simpleMessage("Revanche"),
    "rematchCancelled": MessageLookupByLibrary.simpleMessage(
      "Revanche annulée : un joueur n\'a pas assez de solde",
    ),
    "reminder": MessageLookupByLibrary.simpleMessage("Rappel d’événements"),
    "requestWithdrawal": MessageLookupByLibrary.simpleMessage(
      "Demander un retrait",
    ),
    "resendEmail": MessageLookupByLibrary.simpleMessage("Renvoyer l\'e-mail"),
    "reset": MessageLookupByLibrary.simpleMessage("Réinitialiser"),
    "resetPassed": MessageLookupByLibrary.simpleMessage(
      "Réinitialiser l’étape",
    ),
    "restartGame": MessageLookupByLibrary.simpleMessage(
      "Recommencer la partie",
    ),
    "right": MessageLookupByLibrary.simpleMessage("droite"),
    "rivals": MessageLookupByLibrary.simpleMessage("Adversaire"),
    "rollDice": MessageLookupByLibrary.simpleMessage("Lancer les dés"),
    "rookStep1Desc": MessageLookupByLibrary.simpleMessage(
      "La tour se déplace en ligne droite.",
    ),
    "rookStep1Title": MessageLookupByLibrary.simpleMessage(
      "Mouvement vertical",
    ),
    "rookStep2Desc": MessageLookupByLibrary.simpleMessage(
      "La tour peut également se déplacer horizontalement en ligne droite.",
    ),
    "rookStep2Title": MessageLookupByLibrary.simpleMessage(
      "Mouvement horizontal",
    ),
    "roomCode": MessageLookupByLibrary.simpleMessage("Code de salle"),
    "roundBlocked": MessageLookupByLibrary.simpleMessage("Bloqué"),
    "roundLost": MessageLookupByLibrary.simpleMessage("Manche perdue"),
    "roundWon": MessageLookupByLibrary.simpleMessage("Manche gagnée"),
    "safeSquare": MessageLookupByLibrary.simpleMessage("Case sûre"),
    "search": MessageLookupByLibrary.simpleMessage("Rechercher"),
    "searchByUsername": MessageLookupByLibrary.simpleMessage(
      "Rechercher par nom d’utilisateur",
    ),
    "searchCanceled": MessageLookupByLibrary.simpleMessage("Recherche annulée"),
    "searchGame": MessageLookupByLibrary.simpleMessage("Rechercher une partie"),
    "searchPublicGame": MessageLookupByLibrary.simpleMessage(
      "Rechercher une partie publique",
    ),
    "searchingNPlayers": m35,
    "searchingOpponent": MessageLookupByLibrary.simpleMessage(
      "Recherche d\'adversaire",
    ),
    "searchingRealPlayers": MessageLookupByLibrary.simpleMessage(
      "Recherche de joueurs...",
    ),
    "seconds": MessageLookupByLibrary.simpleMessage("secondes"),
    "selectGameTime": MessageLookupByLibrary.simpleMessage(
      "Sélectionnez le temps de jeu",
    ),
    "selectGameType": MessageLookupByLibrary.simpleMessage(
      "Sélectionner le type de partie",
    ),
    "selectImage": MessageLookupByLibrary.simpleMessage(
      "Sélectionner une image",
    ),
    "selectPieceToLearn": MessageLookupByLibrary.simpleMessage(
      "Sélectionnez une pièce pour apprendre :",
    ),
    "selectYourBet": MessageLookupByLibrary.simpleMessage(
      "Sélectionnez votre mise",
    ),
    "selectYourCounteroffer": MessageLookupByLibrary.simpleMessage(
      "Sélectionnez votre contre-offre :",
    ),
    "selectYourMove": MessageLookupByLibrary.simpleMessage(
      "Sélectionnez votre mouvement",
    ),
    "send": MessageLookupByLibrary.simpleMessage("Envoyer"),
    "sendInvitation": MessageLookupByLibrary.simpleMessage(
      "Envoyer une invitation",
    ),
    "sendInvitations": MessageLookupByLibrary.simpleMessage(
      "Envoyer des invitations",
    ),
    "sendIssueFailed": MessageLookupByLibrary.simpleMessage(
      "Échec de l\'envoi du message. Veuillez réessayer.",
    ),
    "sendIssueSuccessfully": MessageLookupByLibrary.simpleMessage(
      "Message envoyé avec succès. Nous vous contacterons bientôt.",
    ),
    "sending": MessageLookupByLibrary.simpleMessage("Envoi..."),
    "sentInvitation": MessageLookupByLibrary.simpleMessage(
      "Envoyer une invitation",
    ),
    "settings": MessageLookupByLibrary.simpleMessage("Paramètres"),
    "signInAccount": MessageLookupByLibrary.simpleMessage(
      "Se connecter avec votre compte",
    ),
    "signOut": MessageLookupByLibrary.simpleMessage("Se déconnecter"),
    "signOutAccount": MessageLookupByLibrary.simpleMessage(
      "Se déconnecter de votre compte",
    ),
    "signOutConfirmation": MessageLookupByLibrary.simpleMessage(
      "Êtes-vous sûr de vouloir vous déconnecter ?",
    ),
    "signOutFailed": MessageLookupByLibrary.simpleMessage(
      "Échec de la déconnexion",
    ),
    "signOutSuccessful": MessageLookupByLibrary.simpleMessage(
      "Déconnexion réussie",
    ),
    "signUp": MessageLookupByLibrary.simpleMessage("S\'inscrire"),
    "someEmailsFailed": MessageLookupByLibrary.simpleMessage(
      "Certains e-mails n\'ont pas pu être envoyés :",
    ),
    "startGame": MessageLookupByLibrary.simpleMessage("Commencer la partie"),
    "startingInSeconds": m36,
    "stats": MessageLookupByLibrary.simpleMessage("Statistiques"),
    "still": MessageLookupByLibrary.simpleMessage("encore"),
    "stole": MessageLookupByLibrary.simpleMessage("Volé"),
    "successfulSentInvitation": MessageLookupByLibrary.simpleMessage(
      "Invitation envoyée avec succès !",
    ),
    "supportTitle": MessageLookupByLibrary.simpleMessage("Support Technique"),
    "tapHereForFeatures": MessageLookupByLibrary.simpleMessage(
      "Touchez ici pour accéder à toutes les fonctionnalités",
    ),
    "tapPhotoToChange": MessageLookupByLibrary.simpleMessage(
      "Touchez la photo pour la changer",
    ),
    "tapTileToStart": MessageLookupByLibrary.simpleMessage(
      "Touchez une tuile pour commencer",
    ),
    "technicalSupport": MessageLookupByLibrary.simpleMessage(
      "Support technique",
    ),
    "tekoplayAccount": MessageLookupByLibrary.simpleMessage("Compte Tekoplay"),
    "tekoplayCommission": MessageLookupByLibrary.simpleMessage(
      "Commission TekoPlay",
    ),
    "terms": MessageLookupByLibrary.simpleMessage("Termes et conditions"),
    "termsCheck": MessageLookupByLibrary.simpleMessage("Consultez nos termes"),
    "threeDoublesHome": MessageLookupByLibrary.simpleMessage(
      "Trois doubles à la maison ! Tour perdu.",
    ),
    "tie": MessageLookupByLibrary.simpleMessage("Match nul"),
    "tieByInsufficient": MessageLookupByLibrary.simpleMessage(
      "Match nul par matériel insuffisant !",
    ),
    "tieByReply": MessageLookupByLibrary.simpleMessage("Égalité par reprise !"),
    "ties": MessageLookupByLibrary.simpleMessage("Matchs nuls"),
    "tileDoesntConnect": MessageLookupByLibrary.simpleMessage(
      "Cette tuile ne se connecte pas aux extrémités",
    ),
    "time": MessageLookupByLibrary.simpleMessage("Temps"),
    "timeExpiredFirstMove": MessageLookupByLibrary.simpleMessage(
      "Temps écoulé : vous n\'avez pas effectué votre premier mouvement en 14 secondes",
    ),
    "timeExpiredMove": MessageLookupByLibrary.simpleMessage(
      "Temps écoulé : vous n\'avez pas effectué votre mouvement en 1 minute",
    ),
    "timeExpiredTitle": MessageLookupByLibrary.simpleMessage("Temps Expiré"),
    "timeExpiredWaiting": MessageLookupByLibrary.simpleMessage(
      "Délai d\'attente expiré.",
    ),
    "timeLostMatch": MessageLookupByLibrary.simpleMessage(
      "Vous avez perdu la partie par temps",
    ),
    "timeOut": MessageLookupByLibrary.simpleMessage("Temps écoulé !"),
    "timeRunOutMessage": MessageLookupByLibrary.simpleMessage(
      "Vous n\'avez plus de temps pour jouer votre coup",
    ),
    "timeSettings": MessageLookupByLibrary.simpleMessage("Paramètres du temps"),
    "toJoinThisGame": MessageLookupByLibrary.simpleMessage(
      "pour participer à cette partie.",
    ),
    "toParticipate": MessageLookupByLibrary.simpleMessage("pour participer"),
    "toPlay": MessageLookupByLibrary.simpleMessage("pour jouer"),
    "toUse": MessageLookupByLibrary.simpleMessage("Pour utiliser"),
    "tokens": MessageLookupByLibrary.simpleMessage("Jetons"),
    "top": MessageLookupByLibrary.simpleMessage("TOP"),
    "totalPoints": MessageLookupByLibrary.simpleMessage("Classement"),
    "totalRequired": MessageLookupByLibrary.simpleMessage("Total requis"),
    "touchPieceBonusN": m37,
    "touchPieceToMove": MessageLookupByLibrary.simpleMessage(
      "Touchez une pièce pour déplacer",
    ),
    "traditionalDomino": MessageLookupByLibrary.simpleMessage(
      "Domino Traditionnel",
    ),
    "tripleDouble": MessageLookupByLibrary.simpleMessage(
      "Triple double ! Pièce renvoyée à la maison",
    ),
    "turnOfPlayer": m38,
    "tutorial": MessageLookupByLibrary.simpleMessage("Tutoriel"),
    "tutorialChessTitle": MessageLookupByLibrary.simpleMessage(
      "Tutoriel d’échecs",
    ),
    "tutorialCompleted": MessageLookupByLibrary.simpleMessage(
      "Vous avez terminé le tutoriel de",
    ),
    "tutorialShort": MessageLookupByLibrary.simpleMessage("Tutoriel"),
    "tutorialTitle": MessageLookupByLibrary.simpleMessage(
      "Comment jouer au Ludo",
    ),
    "ultraDifficult": MessageLookupByLibrary.simpleMessage("Ultra difficile"),
    "understood": MessageLookupByLibrary.simpleMessage("Compris"),
    "user": MessageLookupByLibrary.simpleMessage("Utilisateur"),
    "userDataLoadError": MessageLookupByLibrary.simpleMessage(
      "Erreur lors du chargement des données utilisateur",
    ),
    "userNotFound": MessageLookupByLibrary.simpleMessage(
      "Utilisateur non authentifié",
    ),
    "verificationEmailResent": MessageLookupByLibrary.simpleMessage(
      "E-mail de vérification renvoyé",
    ),
    "verificationEmailSent": MessageLookupByLibrary.simpleMessage(
      "Nous avons envoyé un lien de vérification à votre e-mail. Veuillez vérifier votre e-mail pour activer votre compte et accéder à toutes les fonctionnalités.",
    ),
    "verifyEmail": MessageLookupByLibrary.simpleMessage(
      "Vérifiez votre e-mail",
    ),
    "verifyYourEmail": MessageLookupByLibrary.simpleMessage(
      "Vérifiez votre e-mail",
    ),
    "version": MessageLookupByLibrary.simpleMessage("Version"),
    "veryEasy": MessageLookupByLibrary.simpleMessage("Très facile"),
    "victories": MessageLookupByLibrary.simpleMessage("Victoires"),
    "victoriesPct": MessageLookupByLibrary.simpleMessage("% de victoires"),
    "victory": MessageLookupByLibrary.simpleMessage("VICTOIRE !"),
    "volume": MessageLookupByLibrary.simpleMessage("Volume de la musique"),
    "vsCpu": MessageLookupByLibrary.simpleMessage("Vs CPU"),
    "vsFriend": MessageLookupByLibrary.simpleMessage("Vs Ami"),
    "waiting": MessageLookupByLibrary.simpleMessage("En attente"),
    "waitingForOpponentJoin": MessageLookupByLibrary.simpleMessage(
      "En attente qu\'un adversaire rejoigne...",
    ),
    "waitingMorePlayers": m39,
    "waitingOpponent": MessageLookupByLibrary.simpleMessage(
      "En attente de l\'adversaire...",
    ),
    "waitingOpponentResponse": MessageLookupByLibrary.simpleMessage(
      "En attente de la réponse de l\'adversaire...",
    ),
    "waitingOthers": MessageLookupByLibrary.simpleMessage(
      "En attente des autres...",
    ),
    "waitingRoom": MessageLookupByLibrary.simpleMessage("Salle d\'attente"),
    "wantsRematch": MessageLookupByLibrary.simpleMessage("veut une revanche !"),
    "watchMovement": MessageLookupByLibrary.simpleMessage("Voir le mouvement"),
    "welcome": MessageLookupByLibrary.simpleMessage("Bienvenue"),
    "wellDone": MessageLookupByLibrary.simpleMessage(
      "Bien joué ! Coup correct",
    ),
    "whatPlay": MessageLookupByLibrary.simpleMessage(
      "À quoi voulez-vous jouer ?",
    ),
    "whichDiceToUse": MessageLookupByLibrary.simpleMessage(
      "Quel dé utiliser ?",
    ),
    "whites": MessageLookupByLibrary.simpleMessage("Blancs"),
    "willCaptureAnother": MessageLookupByLibrary.simpleMessage(
      "Capturera une autre pièce !",
    ),
    "winRate": MessageLookupByLibrary.simpleMessage("Taux de victoire"),
    "wins": MessageLookupByLibrary.simpleMessage("Victoire"),
    "withdrawDiamonds": MessageLookupByLibrary.simpleMessage(
      "Retirer des Diamants",
    ),
    "withdrawProcessError": MessageLookupByLibrary.simpleMessage(
      "Erreur lors du traitement du retrait",
    ),
    "withdrawalProcessed": m40,
    "withdrawalsProcessedIn": MessageLookupByLibrary.simpleMessage(
      "Les retraits sont traités sous 24 à 48 heures ouvrables",
    ),
    "writeIssueHere": MessageLookupByLibrary.simpleMessage(
      "Écrivez votre message ici...",
    ),
    "wrongSide": MessageLookupByLibrary.simpleMessage(
      "Mauvais côté. Essaye du côté",
    ),
    "yellowColor": MessageLookupByLibrary.simpleMessage("Jaune"),
    "you": MessageLookupByLibrary.simpleMessage("Tu"),
    "youDid": MessageLookupByLibrary.simpleMessage("tu as fait"),
    "youDontHave": MessageLookupByLibrary.simpleMessage("Vous n’avez pas"),
    "youHave": MessageLookupByLibrary.simpleMessage("Vous avez"),
    "youHavePlayableTiles": MessageLookupByLibrary.simpleMessage(
      "Vous avez des tuiles jouables",
    ),
    "youHaveWon": MessageLookupByLibrary.simpleMessage("Tu as gagné la partie"),
    "youHaventPlayed": MessageLookupByLibrary.simpleMessage(
      "Vous n\'avez pas joué",
    ),
    "youLost": MessageLookupByLibrary.simpleMessage(
      "Vous avez perdu\nBien essayé",
    ),
    "youLostByTimeout": MessageLookupByLibrary.simpleMessage(
      "Vous avez perdu par dépassement de temps",
    ),
    "youLostHand": MessageLookupByLibrary.simpleMessage(
      "Vous avez perdu la main",
    ),
    "youNeed": MessageLookupByLibrary.simpleMessage("Vous avez besoin de"),
    "youNeedToLogin": MessageLookupByLibrary.simpleMessage(
      "vous devez vous connecter",
    ),
    "youStoleChip": MessageLookupByLibrary.simpleMessage(
      "Tu as volé un jeton du pot",
    ),
    "youWon": MessageLookupByLibrary.simpleMessage(
      "Vous avez gagné !\nFélicitations",
    ),
    "youWonCheckMate": MessageLookupByLibrary.simpleMessage(
      "Tu as gagné ! Échec et mat",
    ),
    "youWonHand": MessageLookupByLibrary.simpleMessage(
      "Vous avez gagné la main !",
    ),
    "youWonProcess": MessageLookupByLibrary.simpleMessage(
      "Tu as gagné ! Tes récompenses sont en cours de traitement...",
    ),
    "youWonShort": MessageLookupByLibrary.simpleMessage("Vous avez gagné"),
    "yourBalanceAmount": m41,
    "yourCurrentBalance": MessageLookupByLibrary.simpleMessage(
      "Votre solde actuel :",
    ),
    "yourCurrentBet": MessageLookupByLibrary.simpleMessage(
      "Votre mise actuelle :",
    ),
    "yourPositionIn": MessageLookupByLibrary.simpleMessage(
      "Votre position dans",
    ),
    "yourSaldoAmount": m42,
    "yourTemporaryName": MessageLookupByLibrary.simpleMessage(
      "Votre nom temporaire",
    ),
    "yourTurn": MessageLookupByLibrary.simpleMessage("À votre tour"),
    "yourTurnLabel": MessageLookupByLibrary.simpleMessage("VOTRE TOUR"),
  };
}
