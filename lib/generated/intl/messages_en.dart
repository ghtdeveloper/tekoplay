// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a en locale. All the
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
  String get localeName => 'en';

  static String m0(count) => "Available: ${count} diamonds";

  static String m1(amount, currency) => "Bet: ${amount} ${currency}";

  static String m2(name, amount, original) =>
      "${name} has made a counteroffer of ${amount} diamonds (original: ${original})";

  static String m3(current, total) => "exercise ${current} of ${total}";

  static String m4(cost) => "Cost: ${cost}";

  static String m5(n) =>
      "Insufficient balance for rematch (you need ${n} diamonds)";

  static String m6(amount) =>
      "Withdrawal request processed: ${amount} diamonds";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "GameOverDraw": MessageLookupByLibrary.simpleMessage(
      "Draw - Refunds will be processed...",
    ),
    "GameOverProcess": MessageLookupByLibrary.simpleMessage(
      "Game over. Processing results...",
    ),
    "abandonGame": MessageLookupByLibrary.simpleMessage("Abandon game"),
    "abandonGameWarning": MessageLookupByLibrary.simpleMessage(
      "Are you sure you want to abandon the game?\n\nIf you leave, it will count as a defeat and you will lose points.",
    ),
    "abandonWarningBet": MessageLookupByLibrary.simpleMessage(
      "You will lose your bet if you abandon.",
    ),
    "abandonWarningFun": MessageLookupByLibrary.simpleMessage(
      "The current game will be closed.",
    ),
    "abandonWarningPase": MessageLookupByLibrary.simpleMessage(
      "You will lose your bet and backup if you abandon. Other players will recover their diamonds.",
    ),
    "accept": MessageLookupByLibrary.simpleMessage("Accept"),
    "acceptRematch": MessageLookupByLibrary.simpleMessage("Accept rematch"),
    "acceptTheirBet": MessageLookupByLibrary.simpleMessage("Accept their bet"),
    "acceptedYourCounterofferOf": MessageLookupByLibrary.simpleMessage(
      "has accepted your counteroffer of",
    ),
    "acceptsYourBet": MessageLookupByLibrary.simpleMessage("accepts your bet"),
    "accountCreated": MessageLookupByLibrary.simpleMessage(
      "Account created successfully. Verify your email.",
    ),
    "accountCreatedCheckEmail": MessageLookupByLibrary.simpleMessage(
      "Account created. Verify your email before signing in.",
    ),
    "accountCreatedUpdt": MessageLookupByLibrary.simpleMessage(
      "Account created successfully!",
    ),
    "addAccount": MessageLookupByLibrary.simpleMessage("Add account"),
    "adjustGameMusic": MessageLookupByLibrary.simpleMessage(
      "Adjust music volume",
    ),
    "all": MessageLookupByLibrary.simpleMessage("All"),
    "allReadyStarting": MessageLookupByLibrary.simpleMessage(
      "Everyone ready! Starting...",
    ),
    "anonymous": MessageLookupByLibrary.simpleMessage("Anonymous"),
    "appTitle": MessageLookupByLibrary.simpleMessage("Tekoplay"),
    "appleLogin": MessageLookupByLibrary.simpleMessage("Sign in with Apple ID"),
    "areYouSure": MessageLookupByLibrary.simpleMessage("Are you sure?"),
    "attempt": MessageLookupByLibrary.simpleMessage("Try"),
    "available": MessageLookupByLibrary.simpleMessage("available"),
    "availableDiamondsCount": m0,
    "availableToWithdraw": MessageLookupByLibrary.simpleMessage(
      "Available to withdraw",
    ),
    "averageTime": MessageLookupByLibrary.simpleMessage("Average Time"),
    "back": MessageLookupByLibrary.simpleMessage("Back"),
    "backTo": MessageLookupByLibrary.simpleMessage("Back"),
    "backupAmount": MessageLookupByLibrary.simpleMessage("Backup"),
    "bestValue": MessageLookupByLibrary.simpleMessage("BEST VALUE!"),
    "bet": MessageLookupByLibrary.simpleMessage("Bet"),
    "betAmountDiamonds": MessageLookupByLibrary.simpleMessage(
      "Bet amount (diamonds)",
    ),
    "betAmountLabel": MessageLookupByLibrary.simpleMessage("Bet amount"),
    "betCollectedReady": MessageLookupByLibrary.simpleMessage(
      "Bets collected. Game is ready!",
    ),
    "betDisplay": m1,
    "betGamesRequirement": MessageLookupByLibrary.simpleMessage(
      "For betting games, you need at least 50 diamonds.",
    ),
    "betMode": MessageLookupByLibrary.simpleMessage("Bet mode"),
    "betNegotiation": MessageLookupByLibrary.simpleMessage("Bet Negotiation"),
    "bishopStep1Desc": MessageLookupByLibrary.simpleMessage(
      "Move the pawn to start opening lines.",
    ),
    "bishopStep1Title": MessageLookupByLibrary.simpleMessage("First Move"),
    "bishopStep2Desc": MessageLookupByLibrary.simpleMessage(
      "Now the bishop can move diagonally.",
    ),
    "bishopStep2Title": MessageLookupByLibrary.simpleMessage(
      "Bishop\'s Diagonal Move",
    ),
    "blacks": MessageLookupByLibrary.simpleMessage("Blacks"),
    "buy": MessageLookupByLibrary.simpleMessage("Buy"),
    "buyMore": MessageLookupByLibrary.simpleMessage("Buy more"),
    "camera": MessageLookupByLibrary.simpleMessage("Camera"),
    "cancel": MessageLookupByLibrary.simpleMessage("Cancel"),
    "cancelNegotiation": MessageLookupByLibrary.simpleMessage(
      "Cancel Negotiation",
    ),
    "cancelRoom": MessageLookupByLibrary.simpleMessage("Cancel room"),
    "cancelSearch": MessageLookupByLibrary.simpleMessage("Cancel search"),
    "cannotCreateRematch": MessageLookupByLibrary.simpleMessage(
      "Could not create the rematch",
    ),
    "changeColor": MessageLookupByLibrary.simpleMessage("Select your color"),
    "changeGameLanguage": MessageLookupByLibrary.simpleMessage(
      "Change game language",
    ),
    "check": MessageLookupByLibrary.simpleMessage("Check!"),
    "checkOnline": MessageLookupByLibrary.simpleMessage("♚ CHECK!"),
    "checkmate": MessageLookupByLibrary.simpleMessage("Checkmate!"),
    "chess": MessageLookupByLibrary.simpleMessage("Chess"),
    "chessPieceBishop": MessageLookupByLibrary.simpleMessage("Bishop"),
    "chessPieceKing": MessageLookupByLibrary.simpleMessage("King"),
    "chessPieceKnight": MessageLookupByLibrary.simpleMessage("Knight"),
    "chessPiecePawn": MessageLookupByLibrary.simpleMessage("Pawn"),
    "chessPieceQueen": MessageLookupByLibrary.simpleMessage("Queen"),
    "chessPieceRook": MessageLookupByLibrary.simpleMessage("Rook"),
    "chooseAnotherPiece": MessageLookupByLibrary.simpleMessage(
      "Choose another piece",
    ),
    "chooseBetAmountDiamonds": MessageLookupByLibrary.simpleMessage(
      "Choose the diamond amount for this game",
    ),
    "choosePerfectPackage": MessageLookupByLibrary.simpleMessage(
      "Choose the perfect package for you",
    ),
    "choosePlayerCountForGame": MessageLookupByLibrary.simpleMessage(
      "Choose the number of players for the game",
    ),
    "close": MessageLookupByLibrary.simpleMessage("Close"),
    "coinStore": MessageLookupByLibrary.simpleMessage("Coin Store"),
    "coins": MessageLookupByLibrary.simpleMessage("coins"),
    "comingSoon": MessageLookupByLibrary.simpleMessage("COMING SOON"),
    "completeDominoTutorial": MessageLookupByLibrary.simpleMessage(
      "You have completed the domino tutorial.",
    ),
    "completeTutorial": MessageLookupByLibrary.simpleMessage(
      "You have completed the tutorial",
    ),
    "congrats": MessageLookupByLibrary.simpleMessage("Congratulations"),
    "congratulations": MessageLookupByLibrary.simpleMessage("Congratulations!"),
    "congratulationsShort": MessageLookupByLibrary.simpleMessage(
      "Congratulations",
    ),
    "connectionError": MessageLookupByLibrary.simpleMessage("Connection error"),
    "contactSupport": MessageLookupByLibrary.simpleMessage(
      "Contact our support team",
    ),
    "continueAsGuest": MessageLookupByLibrary.simpleMessage(
      "Continue as guest",
    ),
    "continueGame": MessageLookupByLibrary.simpleMessage("Continue playing"),
    "copyLinkToShare": MessageLookupByLibrary.simpleMessage(
      "Copy link to share",
    ),
    "correctMove": MessageLookupByLibrary.simpleMessage(
      "Excellent! Correct move.",
    ),
    "couldNotPlayTile": MessageLookupByLibrary.simpleMessage(
      "Could not play tile",
    ),
    "counterOfferMsg": m2,
    "counterOfferTitle": MessageLookupByLibrary.simpleMessage(
      "Bet counteroffer",
    ),
    "counteroffer": MessageLookupByLibrary.simpleMessage("Counteroffer"),
    "counterofferAccepted": MessageLookupByLibrary.simpleMessage(
      "Counteroffer Accepted!",
    ),
    "counterofferRejected": MessageLookupByLibrary.simpleMessage(
      "Counteroffer Rejected",
    ),
    "cpu": MessageLookupByLibrary.simpleMessage("CPU"),
    "cpuOpponentCount": MessageLookupByLibrary.simpleMessage(
      "Number of CPU opponents",
    ),
    "cpuTurn": MessageLookupByLibrary.simpleMessage("CPU\'s turn"),
    "cpuVs1Description": MessageLookupByLibrary.simpleMessage(
      "You will play 1 vs 1 against the CPU in opposite positions",
    ),
    "cpuVs2Description": MessageLookupByLibrary.simpleMessage(
      "You will play against 2 CPUs (3 players total)",
    ),
    "cpuVs3Description": MessageLookupByLibrary.simpleMessage(
      "You will play against 3 CPUs (4 players total)",
    ),
    "cpuWon": MessageLookupByLibrary.simpleMessage("The CPU has won"),
    "cpuWonCheckMate": MessageLookupByLibrary.simpleMessage(
      "The CPU won by checkmate",
    ),
    "createAccount": MessageLookupByLibrary.simpleMessage("Create account"),
    "createNewRoom": MessageLookupByLibrary.simpleMessage("Create new room"),
    "createPublicGame": MessageLookupByLibrary.simpleMessage(
      "Create public game",
    ),
    "createdAgo": MessageLookupByLibrary.simpleMessage("Created"),
    "creatingRematch": MessageLookupByLibrary.simpleMessage(
      "Creating rematch...",
    ),
    "customAmount": MessageLookupByLibrary.simpleMessage("Custom amount"),
    "customNotifications": MessageLookupByLibrary.simpleMessage(
      "Customize your notifications",
    ),
    "defeats": MessageLookupByLibrary.simpleMessage("Defeats"),
    "deletePhoto": MessageLookupByLibrary.simpleMessage("Delete photo"),
    "demo": MessageLookupByLibrary.simpleMessage("Demo"),
    "describeIssue": MessageLookupByLibrary.simpleMessage(
      "Describe your issue or question:",
    ),
    "diamondStore": MessageLookupByLibrary.simpleMessage("Diamond Store"),
    "diamonds": MessageLookupByLibrary.simpleMessage("diamonds"),
    "diamondsOnlyChallenge": MessageLookupByLibrary.simpleMessage(
      "Diamonds only - Ready for the challenge?",
    ),
    "difficult": MessageLookupByLibrary.simpleMessage("Difficult"),
    "difficulty": MessageLookupByLibrary.simpleMessage("Difficulty"),
    "difficultyMax": MessageLookupByLibrary.simpleMessage(
      "Difficulty: Maximum",
    ),
    "difficultyMaxNote": MessageLookupByLibrary.simpleMessage(
      "In bet mode the CPU plays at maximum level.",
    ),
    "domino": MessageLookupByLibrary.simpleMessage("Domino"),
    "dominoFriends": MessageLookupByLibrary.simpleMessage("Domino - Friends"),
    "dominoPaseFriends": MessageLookupByLibrary.simpleMessage(
      "El Pase - Friends",
    ),
    "dominoPaseTitle": MessageLookupByLibrary.simpleMessage("Domino Pase"),
    "dominoPaseWaitingRoom": MessageLookupByLibrary.simpleMessage(
      "El Pase Room",
    ),
    "dominoPaseWaitingRoomFriends": MessageLookupByLibrary.simpleMessage(
      "El Pase - Friends Room",
    ),
    "dominoTutorial": MessageLookupByLibrary.simpleMessage("Domino Tutorial"),
    "dominoVsCpu": MessageLookupByLibrary.simpleMessage("Domino vs CPU"),
    "doubleHome": MessageLookupByLibrary.simpleMessage(
      "Double at home! Roll again.",
    ),
    "drawBetReturned": MessageLookupByLibrary.simpleMessage(
      "Draw: Your bet of has been returned",
    ),
    "drawByStalemate": MessageLookupByLibrary.simpleMessage(
      "Draw by stalemate!",
    ),
    "drawMsg": MessageLookupByLibrary.simpleMessage("Draw"),
    "easy": MessageLookupByLibrary.simpleMessage("Easy"),
    "email": MessageLookupByLibrary.simpleMessage("Email"),
    "emailAlreadyRegistered": MessageLookupByLibrary.simpleMessage(
      "The email entered is already registered, please use another one",
    ),
    "emailLogin": MessageLookupByLibrary.simpleMessage("Sign in with Tekoplay"),
    "emailNotVerified": MessageLookupByLibrary.simpleMessage(
      "Verify your email before signing in",
    ),
    "emailVerifiedSuccess": MessageLookupByLibrary.simpleMessage(
      "Email verified successfully! You can now access all features.",
    ),
    "emptyPotDomino": MessageLookupByLibrary.simpleMessage("The pot is empty"),
    "endGame": MessageLookupByLibrary.simpleMessage("End of the game"),
    "endOfGame": MessageLookupByLibrary.simpleMessage("END OF GAME"),
    "enoughToPlay": MessageLookupByLibrary.simpleMessage("enough to play"),
    "enterAmount": MessageLookupByLibrary.simpleMessage("Enter amount"),
    "enterAmountToWithdraw": MessageLookupByLibrary.simpleMessage(
      "Enter the amount to withdraw",
    ),
    "enterEmailToReset": MessageLookupByLibrary.simpleMessage(
      "Enter your email to receive a recovery link",
    ),
    "enterFriendEmail": MessageLookupByLibrary.simpleMessage(
      "Enter your friend\'s email",
    ),
    "enterGuestEmails": MessageLookupByLibrary.simpleMessage(
      "Enter each guest\'s email",
    ),
    "enterValidEmail": MessageLookupByLibrary.simpleMessage(
      "Enter a valid email",
    ),
    "error": MessageLookupByLibrary.simpleMessage("Error"),
    "errorAcceptInvitation": MessageLookupByLibrary.simpleMessage(
      "Error accepting invitation",
    ),
    "errorAcceptedInvitation": MessageLookupByLibrary.simpleMessage(
      "Error accepting invitation",
    ),
    "errorAcceptingCounteroffer": MessageLookupByLibrary.simpleMessage(
      "Error accepting counteroffer",
    ),
    "errorCreateAccount": MessageLookupByLibrary.simpleMessage(
      "Error creating account",
    ),
    "errorCreatePublicGame": MessageLookupByLibrary.simpleMessage(
      "Error creating the game",
    ),
    "errorCreatingAccount": MessageLookupByLibrary.simpleMessage(
      "Error creating account",
    ),
    "errorCreatingRoom": MessageLookupByLibrary.simpleMessage(
      "Error creating the room. Please try again.",
    ),
    "errorJoinGame": MessageLookupByLibrary.simpleMessage(
      "Could not join the game",
    ),
    "errorLogin": MessageLookupByLibrary.simpleMessage("Error logging in"),
    "errorMakeMove": MessageLookupByLibrary.simpleMessage("Error making move"),
    "errorProcessInvitation": MessageLookupByLibrary.simpleMessage(
      "Error processing invitation",
    ),
    "errorRejectingCounteroffer": MessageLookupByLibrary.simpleMessage(
      "Error rejecting counteroffer",
    ),
    "errorResendEmail": MessageLookupByLibrary.simpleMessage(
      "Error resending email",
    ),
    "errorResult": MessageLookupByLibrary.simpleMessage(
      "Error processing result",
    ),
    "errorSearchGame": MessageLookupByLibrary.simpleMessage(
      "Error searching game",
    ),
    "errorSendMove": MessageLookupByLibrary.simpleMessage("Error sending move"),
    "errorSendingPasswordReset": MessageLookupByLibrary.simpleMessage(
      "Error sending password reset email",
    ),
    "errorSignInEmail": MessageLookupByLibrary.simpleMessage(
      "Sign in error. Check your credentials.",
    ),
    "errorSignInFacebook": MessageLookupByLibrary.simpleMessage(
      "Error signing in with Facebook",
    ),
    "errorSignInGoogle": MessageLookupByLibrary.simpleMessage(
      "Error signing in with Google",
    ),
    "exercise": MessageLookupByLibrary.simpleMessage("exercise"),
    "exerciseOf": m3,
    "exit": MessageLookupByLibrary.simpleMessage("Exit"),
    "extremes": MessageLookupByLibrary.simpleMessage("Extremes"),
    "facebookLogin": MessageLookupByLibrary.simpleMessage(
      "Sign in with Facebook",
    ),
    "fillAllFields": MessageLookupByLibrary.simpleMessage("Fill all fields"),
    "findNewOpponent": MessageLookupByLibrary.simpleMessage(
      "Find new opponent",
    ),
    "finish": MessageLookupByLibrary.simpleMessage("Finish"),
    "firstMove": MessageLookupByLibrary.simpleMessage("(First move:"),
    "firstMoveCompleted": MessageLookupByLibrary.simpleMessage(
      "Well done! Correct move",
    ),
    "forThisBet": MessageLookupByLibrary.simpleMessage("for this bet"),
    "forgotPassword": MessageLookupByLibrary.simpleMessage(
      "Forgot your password?",
    ),
    "friendEmailLabel": MessageLookupByLibrary.simpleMessage("Friend\'s email"),
    "fun": MessageLookupByLibrary.simpleMessage("Fun"),
    "funGamesRequirement": MessageLookupByLibrary.simpleMessage(
      "For fun games, you need at least 100 coins.",
    ),
    "funMode": MessageLookupByLibrary.simpleMessage("Fun mode"),
    "gallery": MessageLookupByLibrary.simpleMessage("Gallery"),
    "gameCode": MessageLookupByLibrary.simpleMessage("Game code"),
    "gameCostLabel": m4,
    "gameDraw": MessageLookupByLibrary.simpleMessage(
      "The game ended in a draw",
    ),
    "gameHistory": MessageLookupByLibrary.simpleMessage("Game History"),
    "gameInvitation": MessageLookupByLibrary.simpleMessage("Game invitation"),
    "gameMusic": MessageLookupByLibrary.simpleMessage("Game music"),
    "gameNotFound": MessageLookupByLibrary.simpleMessage("Game not found"),
    "gameOver": MessageLookupByLibrary.simpleMessage("Game over"),
    "gamePlayed": MessageLookupByLibrary.simpleMessage("Games Played"),
    "gameStats": MessageLookupByLibrary.simpleMessage("Game Statistics"),
    "games": MessageLookupByLibrary.simpleMessage("Games"),
    "generalSummary": MessageLookupByLibrary.simpleMessage("General Summary"),
    "generatedAndCopiedCode": MessageLookupByLibrary.simpleMessage(
      "Code generated and copied",
    ),
    "getMore": MessageLookupByLibrary.simpleMessage("Get more"),
    "getMoreCoins": MessageLookupByLibrary.simpleMessage("Get more coins!"),
    "getMoreDiamonds": MessageLookupByLibrary.simpleMessage(
      "Get more diamonds!",
    ),
    "googleLogin": MessageLookupByLibrary.simpleMessage("Sign in with Google"),
    "googlePayNotAvailable": MessageLookupByLibrary.simpleMessage(
      "Google Pay is not available on this device",
    ),
    "guestEmailLabel": MessageLookupByLibrary.simpleMessage("Guest email"),
    "hasBet": MessageLookupByLibrary.simpleMessage("has bet:"),
    "hasLeftTheGame": MessageLookupByLibrary.simpleMessage("has left the game"),
    "howManyPlayers": MessageLookupByLibrary.simpleMessage("How many players?"),
    "howMuchBet": MessageLookupByLibrary.simpleMessage(
      "How much do you want to bet?",
    ),
    "inOurStore": MessageLookupByLibrary.simpleMessage("in our store."),
    "incorrectMove": MessageLookupByLibrary.simpleMessage("Incorrect move"),
    "incorrectTab": MessageLookupByLibrary.simpleMessage(
      "Incorrect tile. Try with the tile",
    ),
    "insufficientDiamondsForRematch": m5,
    "insufficientForRematch": MessageLookupByLibrary.simpleMessage(
      "Insufficient balance for rematch",
    ),
    "insufficientFunds": MessageLookupByLibrary.simpleMessage(
      "Insufficient Funds",
    ),
    "invalidAmountToWithdraw": MessageLookupByLibrary.simpleMessage(
      "Invalid amount to withdraw",
    ),
    "invalidBetAmount": MessageLookupByLibrary.simpleMessage(
      "Invalid bet amount",
    ),
    "invalidCredentials": MessageLookupByLibrary.simpleMessage(
      "Invalid credentials",
    ),
    "invitationRejected": MessageLookupByLibrary.simpleMessage(
      "Invitation rejected",
    ),
    "invitationSentWaiting": MessageLookupByLibrary.simpleMessage(
      "Invitation sent! Waiting for your friend to accept...",
    ),
    "invitations": MessageLookupByLibrary.simpleMessage("Invitations"),
    "inviteAnotherFriend": MessageLookupByLibrary.simpleMessage(
      "Invite another friend",
    ),
    "inviteFriend": MessageLookupByLibrary.simpleMessage("Invite friend"),
    "inviteFriends": MessageLookupByLibrary.simpleMessage("Invite friends"),
    "invitesYou": MessageLookupByLibrary.simpleMessage("invites you"),
    "invitesYouToPlay": MessageLookupByLibrary.simpleMessage(
      "invites you to play",
    ),
    "join": MessageLookupByLibrary.simpleMessage("Join"),
    "joinRoom": MessageLookupByLibrary.simpleMessage("Join room"),
    "kingStep1Desc": MessageLookupByLibrary.simpleMessage(
      "The king can move one square in any direction. Move it horizontally.",
    ),
    "kingStep1Title": MessageLookupByLibrary.simpleMessage(
      "King in the Center",
    ),
    "kingStep2Desc": MessageLookupByLibrary.simpleMessage(
      "Now move the king vertically upward.",
    ),
    "kingStep2Title": MessageLookupByLibrary.simpleMessage("Vertical Move"),
    "kingStep3Desc": MessageLookupByLibrary.simpleMessage(
      "The king can also move diagonally. Move it diagonally.",
    ),
    "kingStep3Title": MessageLookupByLibrary.simpleMessage("Diagonal Move"),
    "kingStep4Desc": MessageLookupByLibrary.simpleMessage(
      "The king is versatile: horizontal, vertical and diagonal. Move it however you like!",
    ),
    "kingStep4Title": MessageLookupByLibrary.simpleMessage("All Directions"),
    "knightStep1Desc": MessageLookupByLibrary.simpleMessage(
      "The knight moves in an L-shape.",
    ),
    "knightStep1Title": MessageLookupByLibrary.simpleMessage("L-Shaped Move"),
    "knightStep2Desc": MessageLookupByLibrary.simpleMessage(
      "The knight can jump over other pieces.",
    ),
    "knightStep2Title": MessageLookupByLibrary.simpleMessage(
      "The Knight Jumps",
    ),
    "language": MessageLookupByLibrary.simpleMessage("Language"),
    "languageEn": MessageLookupByLibrary.simpleMessage("English"),
    "languageEs": MessageLookupByLibrary.simpleMessage("Spanish"),
    "languageFr": MessageLookupByLibrary.simpleMessage("French"),
    "languageSelect": MessageLookupByLibrary.simpleMessage("Select language"),
    "left": MessageLookupByLibrary.simpleMessage("left"),
    "letGameBegin": MessageLookupByLibrary.simpleMessage("Let the game begin!"),
    "linkCopied": MessageLookupByLibrary.simpleMessage("Link copied"),
    "loadingDots": MessageLookupByLibrary.simpleMessage("Loading..."),
    "loadingGame": MessageLookupByLibrary.simpleMessage("Loading game..."),
    "loadingHistory": MessageLookupByLibrary.simpleMessage(
      "Loading history...",
    ),
    "loadingRanking": MessageLookupByLibrary.simpleMessage(
      "Loading rankings...",
    ),
    "logIn": MessageLookupByLibrary.simpleMessage("Log In"),
    "loggedInAs": MessageLookupByLibrary.simpleMessage("Logged in as"),
    "login": MessageLookupByLibrary.simpleMessage("Login"),
    "loginRequired": MessageLookupByLibrary.simpleMessage("Login required"),
    "loginToAccessFeatures": MessageLookupByLibrary.simpleMessage(
      "To access all features and save your progress, log in with your account.",
    ),
    "loginToSaveProgress": MessageLookupByLibrary.simpleMessage(
      "Log in to save your progress",
    ),
    "lose": MessageLookupByLibrary.simpleMessage("Loss"),
    "madeNewCounteroffer": MessageLookupByLibrary.simpleMessage(
      "has made a new counteroffer:",
    ),
    "makeCounteroffer": MessageLookupByLibrary.simpleMessage(
      "Make Counteroffer",
    ),
    "marker": MessageLookupByLibrary.simpleMessage("Scoreboard"),
    "me": MessageLookupByLibrary.simpleMessage("Me"),
    "megaPack": MessageLookupByLibrary.simpleMessage("MEGA PACK!"),
    "messages": MessageLookupByLibrary.simpleMessage("Receive new messages"),
    "minute": MessageLookupByLibrary.simpleMessage("minute"),
    "mostPopular": MessageLookupByLibrary.simpleMessage("MOST POPULAR!"),
    "moveHorses": MessageLookupByLibrary.simpleMessage("Move knights"),
    "moveTowers": MessageLookupByLibrary.simpleMessage("Move rooks"),
    "movement": MessageLookupByLibrary.simpleMessage("Moves"),
    "movingPaws": MessageLookupByLibrary.simpleMessage("Move pawns"),
    "multiplayer": MessageLookupByLibrary.simpleMessage("Multiplayer game"),
    "name": MessageLookupByLibrary.simpleMessage("Name"),
    "needAtLeast100": MessageLookupByLibrary.simpleMessage(
      "You need at least 100",
    ),
    "needDoubleForBet": MessageLookupByLibrary.simpleMessage(
      "You need double the bet (bet + backup)",
    ),
    "negotiatingBet": MessageLookupByLibrary.simpleMessage(
      "Negotiating bet...",
    ),
    "newCounteroffer": MessageLookupByLibrary.simpleMessage("New Counteroffer"),
    "newGame": MessageLookupByLibrary.simpleMessage("\'New game"),
    "next": MessageLookupByLibrary.simpleMessage("Next"),
    "nextRound": MessageLookupByLibrary.simpleMessage("Next round"),
    "noInvitation": MessageLookupByLibrary.simpleMessage("No invitations"),
    "noMoreChips": MessageLookupByLibrary.simpleMessage(
      "There are no more chips in the pot",
    ),
    "noPublicGame": MessageLookupByLibrary.simpleMessage("No games available"),
    "noTime": MessageLookupByLibrary.simpleMessage("Out of time"),
    "noValidMoves": MessageLookupByLibrary.simpleMessage(
      "No valid moves. Turn skipped.",
    ),
    "noWithdrawableDiamonds": MessageLookupByLibrary.simpleMessage(
      "No diamonds available to withdraw",
    ),
    "nominalBet": MessageLookupByLibrary.simpleMessage("Nominal bet"),
    "normal": MessageLookupByLibrary.simpleMessage("Normal"),
    "notAllowed": MessageLookupByLibrary.simpleMessage(
      "This tile cannot be connected here",
    ),
    "notEnough": MessageLookupByLibrary.simpleMessage("You don\'t have enough"),
    "notEnoughCurrencyForMultiplayer": MessageLookupByLibrary.simpleMessage(
      "You don\'t have enough coins or diamonds to join multiplayer games",
    ),
    "notPlayedGameYet": MessageLookupByLibrary.simpleMessage(
      "You haven\'t played any games yet",
    ),
    "notRankingIn": MessageLookupByLibrary.simpleMessage(
      "You don\'t have a ranking in",
    ),
    "notRankingInfo": MessageLookupByLibrary.simpleMessage(
      "No ranking data available",
    ),
    "notifications": MessageLookupByLibrary.simpleMessage("Notifications"),
    "nowYouTry": MessageLookupByLibrary.simpleMessage("Now you try"),
    "offlineOpponent": MessageLookupByLibrary.simpleMessage(
      "Your opponent has disconnected",
    ),
    "online": MessageLookupByLibrary.simpleMessage("Online"),
    "onlineGame": MessageLookupByLibrary.simpleMessage("Online game"),
    "onlyEmailAccounts": MessageLookupByLibrary.simpleMessage(
      "Only available for email accounts",
    ),
    "opponentAbandoned": MessageLookupByLibrary.simpleMessage(
      "The opponent abandoned the game",
    ),
    "opponentAbandonedMessage": MessageLookupByLibrary.simpleMessage(
      "Your opponent has abandoned the game.\n\nYou won automatically!",
    ),
    "opponentEmail": MessageLookupByLibrary.simpleMessage("Opponent\'s email"),
    "opponentFound": MessageLookupByLibrary.simpleMessage("Opponent Found!"),
    "opponentLeft": MessageLookupByLibrary.simpleMessage("Opponent left"),
    "opponentLostByTimeout": MessageLookupByLibrary.simpleMessage(
      "Opponent lost by timeout",
    ),
    "opponentNotFound": MessageLookupByLibrary.simpleMessage(
      "No opponent found",
    ),
    "opponentRejectedCounteroffer": MessageLookupByLibrary.simpleMessage(
      "The opponent has rejected your counteroffer.",
    ),
    "opponentTimeRunOutMessage": MessageLookupByLibrary.simpleMessage(
      "Your opponent ran out of time",
    ),
    "opponentTurn": MessageLookupByLibrary.simpleMessage("Opponent\'s turn"),
    "outOfTime": MessageLookupByLibrary.simpleMessage("Out of time"),
    "parchisOnline": MessageLookupByLibrary.simpleMessage("Ludo Online"),
    "parchisShort": MessageLookupByLibrary.simpleMessage("Ludo"),
    "parchisVsFriend": MessageLookupByLibrary.simpleMessage("Ludo vs Friend"),
    "pase": MessageLookupByLibrary.simpleMessage("El Pase"),
    "paseBetBody": MessageLookupByLibrary.simpleMessage(
      "To enter you need double your bet as minimum balance.\n\nThe winner takes the pot minus a 10% commission.\n\nPass payments are added or subtracted from each player\'s final prize.",
    ),
    "paseBetHighlight": MessageLookupByLibrary.simpleMessage(
      "Diamonds only — no coins",
    ),
    "paseBetTitle": MessageLookupByLibrary.simpleMessage("The Bet"),
    "paseBlockedBody": MessageLookupByLibrary.simpleMessage(
      "The game can end when a player runs out of tiles or when the board is blocked.\n\nPoints are counted by adding both sides of each tile. Example: 6-2 and 1-0 = 9 points.\n\nIf tied, the player closest to the starting position wins.",
    ),
    "paseBlockedTitle": MessageLookupByLibrary.simpleMessage("Blocked game"),
    "paseHowToPlay": MessageLookupByLibrary.simpleMessage("How to play"),
    "paseHowToPlayBody": MessageLookupByLibrary.simpleMessage(
      "At the start each player receives 7 tiles. The player with the highest double goes first.\n\nThe game flows counter-clockwise. Place tiles by connecting matching numbers at the ends of the chain.",
    ),
    "paseHowToWin": MessageLookupByLibrary.simpleMessage("How to win?"),
    "paseHowToWinBody": MessageLookupByLibrary.simpleMessage(
      "The player who places all their tiles first wins.\n\nIf the game is blocked (nobody can play), the player with the FEWEST points in their remaining tiles wins.\n\nIn case of a tie, the player closest to the starting position in turn order wins.",
    ),
    "paseThePase": MessageLookupByLibrary.simpleMessage("The Pase!"),
    "paseThePaseBody": MessageLookupByLibrary.simpleMessage(
      "If you can\'t play any tile, you must pass your turn. When you pass, each of your rivals pays you a diamond amount.\n\nOnce a valid pass is made, the turn continues with the next player.",
    ),
    "paseThePaseHighlight": MessageLookupByLibrary.simpleMessage(
      "Passing can be profitable!",
    ),
    "paseTutorialTitle": MessageLookupByLibrary.simpleMessage(
      "How to play — El Pase",
    ),
    "paseWhatBody": MessageLookupByLibrary.simpleMessage(
      "El Pase is a special domino mode for 2, 3 or 4 players.\n\nA single hand is played per game, with diamonds only.",
    ),
    "paseWhatIsIt": MessageLookupByLibrary.simpleMessage("What is El Pase?"),
    "pass": MessageLookupByLibrary.simpleMessage("Pass"),
    "passAutomatic": MessageLookupByLibrary.simpleMessage(
      "No options, you pass automatically",
    ),
    "passCountLabel": MessageLookupByLibrary.simpleMessage("Passes"),
    "passValueLabel": MessageLookupByLibrary.simpleMessage("Pass value"),
    "passed": MessageLookupByLibrary.simpleMessage("Step"),
    "password": MessageLookupByLibrary.simpleMessage("Password"),
    "passwordResetSent": MessageLookupByLibrary.simpleMessage(
      "Recovery email sent. Check your inbox.",
    ),
    "pawnStep1Desc": MessageLookupByLibrary.simpleMessage(
      "Pawns advance one square forward.",
    ),
    "pawnStep1Title": MessageLookupByLibrary.simpleMessage("Basic Pawn Move"),
    "pawnStep2Desc": MessageLookupByLibrary.simpleMessage(
      "On their first move, a pawn can advance two squares.",
    ),
    "pawnStep2Title": MessageLookupByLibrary.simpleMessage(
      "Two-Square Advance",
    ),
    "pawnStep3Desc": MessageLookupByLibrary.simpleMessage(
      "The pawn captures enemy pieces by moving diagonally.",
    ),
    "pawnStep3Title": MessageLookupByLibrary.simpleMessage("Diagonal Capture"),
    "paymentProcessingError": MessageLookupByLibrary.simpleMessage(
      "Error processing payment",
    ),
    "play": MessageLookupByLibrary.simpleMessage("Play!"),
    "playAgain": MessageLookupByLibrary.simpleMessage("Play again"),
    "playOnline": MessageLookupByLibrary.simpleMessage("Play online"),
    "playVsComputer": MessageLookupByLibrary.simpleMessage(
      "Play against the computer",
    ),
    "playWithFriend": MessageLookupByLibrary.simpleMessage(
      "Play with a friend",
    ),
    "playerAbandonedGame": MessageLookupByLibrary.simpleMessage(
      "A player abandoned the game",
    ),
    "playerVsCpu": MessageLookupByLibrary.simpleMessage("Player vs CPU"),
    "players3total": MessageLookupByLibrary.simpleMessage("(3 players)"),
    "players4total": MessageLookupByLibrary.simpleMessage("(4 players)"),
    "playing": MessageLookupByLibrary.simpleMessage("Playing"),
    "playingAsGuest": MessageLookupByLibrary.simpleMessage("Playing as guest!"),
    "pleaseEnterValidCode": MessageLookupByLibrary.simpleMessage(
      "Please enter a valid code",
    ),
    "pleaseFillAllFields": MessageLookupByLibrary.simpleMessage(
      "Please fill in all fields",
    ),
    "pleaseWriteIssue": MessageLookupByLibrary.simpleMessage(
      "Please write a message",
    ),
    "point": MessageLookupByLibrary.simpleMessage("Points"),
    "poker": MessageLookupByLibrary.simpleMessage("Poker"),
    "popular": MessageLookupByLibrary.simpleMessage("POPULAR!"),
    "privacy": MessageLookupByLibrary.simpleMessage("Privacy policy"),
    "privacyTitle": MessageLookupByLibrary.simpleMessage("Privacy"),
    "processing": MessageLookupByLibrary.simpleMessage("Processing..."),
    "profilePhotoDeleted": MessageLookupByLibrary.simpleMessage(
      "Profile photo deleted",
    ),
    "profilePhotoUpdated": MessageLookupByLibrary.simpleMessage(
      "Profile photo updated",
    ),
    "publicGame": MessageLookupByLibrary.simpleMessage("Public games"),
    "purchaseSuccessful": MessageLookupByLibrary.simpleMessage(
      "Purchase successful!",
    ),
    "qualifier": MessageLookupByLibrary.simpleMessage("Qualifier"),
    "queenStep1Desc": MessageLookupByLibrary.simpleMessage(
      "First move the pawn to open the queen\'s diagonal.",
    ),
    "queenStep1Title": MessageLookupByLibrary.simpleMessage("Clear the Path"),
    "queenStep2Desc": MessageLookupByLibrary.simpleMessage(
      "Now the queen can move freely diagonally.",
    ),
    "queenStep2Title": MessageLookupByLibrary.simpleMessage(
      "Queen\'s Power - Diagonal Move",
    ),
    "queenStep3Desc": MessageLookupByLibrary.simpleMessage(
      "The queen moves like a rook in straight lines.",
    ),
    "queenStep3Title": MessageLookupByLibrary.simpleMessage(
      "Queen\'s Horizontal Move",
    ),
    "queenStep4Desc": MessageLookupByLibrary.simpleMessage(
      "The queen can capture enemy pieces.",
    ),
    "queenStep4Title": MessageLookupByLibrary.simpleMessage("Queen Captures"),
    "quickAmounts": MessageLookupByLibrary.simpleMessage("Quick amounts:"),
    "ranking": MessageLookupByLibrary.simpleMessage("Ranking"),
    "realPlayersNoBots": MessageLookupByLibrary.simpleMessage(
      "Search players ",
    ),
    "realPlayersOnly": MessageLookupByLibrary.simpleMessage("Search players"),
    "reconnecting": MessageLookupByLibrary.simpleMessage("Reconnecting..."),
    "recovered": MessageLookupByLibrary.simpleMessage("Recovered"),
    "reject": MessageLookupByLibrary.simpleMessage("Reject"),
    "rematch": MessageLookupByLibrary.simpleMessage("Rematch"),
    "rematchCancelled": MessageLookupByLibrary.simpleMessage(
      "Rematch cancelled: a player has insufficient balance",
    ),
    "reminder": MessageLookupByLibrary.simpleMessage("Event reminder"),
    "requestWithdrawal": MessageLookupByLibrary.simpleMessage(
      "Request Withdrawal",
    ),
    "resendEmail": MessageLookupByLibrary.simpleMessage("Resend email"),
    "reset": MessageLookupByLibrary.simpleMessage("Reset"),
    "resetPassed": MessageLookupByLibrary.simpleMessage("Reset step"),
    "restartGame": MessageLookupByLibrary.simpleMessage("Restart game"),
    "right": MessageLookupByLibrary.simpleMessage("right"),
    "rivals": MessageLookupByLibrary.simpleMessage("Opponent"),
    "rollDice": MessageLookupByLibrary.simpleMessage("Roll dice"),
    "rookStep1Desc": MessageLookupByLibrary.simpleMessage(
      "The rook moves in a straight line.",
    ),
    "rookStep1Title": MessageLookupByLibrary.simpleMessage("Vertical Move"),
    "rookStep2Desc": MessageLookupByLibrary.simpleMessage(
      "The rook can also move horizontally in a straight line.",
    ),
    "rookStep2Title": MessageLookupByLibrary.simpleMessage("Horizontal Move"),
    "roomCode": MessageLookupByLibrary.simpleMessage("Room code"),
    "roundBlocked": MessageLookupByLibrary.simpleMessage("Blocked"),
    "roundLost": MessageLookupByLibrary.simpleMessage("Round lost"),
    "roundWon": MessageLookupByLibrary.simpleMessage("Round won"),
    "search": MessageLookupByLibrary.simpleMessage("Search"),
    "searchByUsername": MessageLookupByLibrary.simpleMessage(
      "Search by username",
    ),
    "searchCanceled": MessageLookupByLibrary.simpleMessage("Search canceled"),
    "searchGame": MessageLookupByLibrary.simpleMessage("Search game"),
    "searchPublicGame": MessageLookupByLibrary.simpleMessage(
      "Search public game",
    ),
    "searchingOpponent": MessageLookupByLibrary.simpleMessage(
      "Searching opponent",
    ),
    "searchingRealPlayers": MessageLookupByLibrary.simpleMessage(
      "Searching for players...",
    ),
    "seconds": MessageLookupByLibrary.simpleMessage("seconds"),
    "selectGameTime": MessageLookupByLibrary.simpleMessage("Select game time"),
    "selectGameType": MessageLookupByLibrary.simpleMessage("Select game type"),
    "selectImage": MessageLookupByLibrary.simpleMessage("Select image"),
    "selectPieceToLearn": MessageLookupByLibrary.simpleMessage(
      "Select a piece to learn:",
    ),
    "selectYourBet": MessageLookupByLibrary.simpleMessage("Select your bet"),
    "selectYourCounteroffer": MessageLookupByLibrary.simpleMessage(
      "Select your counteroffer:",
    ),
    "send": MessageLookupByLibrary.simpleMessage("Send"),
    "sendInvitation": MessageLookupByLibrary.simpleMessage("Send invitation"),
    "sendInvitations": MessageLookupByLibrary.simpleMessage("Send invitations"),
    "sendIssueFailed": MessageLookupByLibrary.simpleMessage(
      "Failed to send the message. Please try again.",
    ),
    "sendIssueSuccessfully": MessageLookupByLibrary.simpleMessage(
      "Message sent successfully. We will contact you soon.",
    ),
    "sending": MessageLookupByLibrary.simpleMessage("Sending..."),
    "sentInvitation": MessageLookupByLibrary.simpleMessage("Send invitation"),
    "settings": MessageLookupByLibrary.simpleMessage("Settings"),
    "signInAccount": MessageLookupByLibrary.simpleMessage(
      "Sign in with your account",
    ),
    "signOut": MessageLookupByLibrary.simpleMessage("Sign out"),
    "signOutAccount": MessageLookupByLibrary.simpleMessage(
      "Sign out of your account",
    ),
    "signOutConfirmation": MessageLookupByLibrary.simpleMessage(
      "Are you sure you want to sign out?",
    ),
    "signOutFailed": MessageLookupByLibrary.simpleMessage("Sign out failed"),
    "signOutSuccessful": MessageLookupByLibrary.simpleMessage(
      "Signed out successfully",
    ),
    "signUp": MessageLookupByLibrary.simpleMessage("Sign Up"),
    "someEmailsFailed": MessageLookupByLibrary.simpleMessage(
      "Some emails could not be sent:",
    ),
    "startGame": MessageLookupByLibrary.simpleMessage("Start game"),
    "stats": MessageLookupByLibrary.simpleMessage("Statistics"),
    "still": MessageLookupByLibrary.simpleMessage("yet"),
    "stole": MessageLookupByLibrary.simpleMessage("Stole"),
    "successfulSentInvitation": MessageLookupByLibrary.simpleMessage(
      "Invitation sent successfully!",
    ),
    "supportTitle": MessageLookupByLibrary.simpleMessage("Technical Support"),
    "tapHereForFeatures": MessageLookupByLibrary.simpleMessage(
      "Tap here to access all features",
    ),
    "tapPhotoToChange": MessageLookupByLibrary.simpleMessage(
      "Tap the photo to change it",
    ),
    "tapTileToStart": MessageLookupByLibrary.simpleMessage(
      "Tap a tile to start",
    ),
    "technicalSupport": MessageLookupByLibrary.simpleMessage(
      "Technical Support",
    ),
    "tekoplayAccount": MessageLookupByLibrary.simpleMessage("Tekoplay account"),
    "tekoplayCommission": MessageLookupByLibrary.simpleMessage(
      "Tekoplay commission",
    ),
    "terms": MessageLookupByLibrary.simpleMessage("Terms and conditions"),
    "termsCheck": MessageLookupByLibrary.simpleMessage("Check our terms"),
    "threeDoublesHome": MessageLookupByLibrary.simpleMessage(
      "Three doubles at home! Turn lost.",
    ),
    "tie": MessageLookupByLibrary.simpleMessage("Tie"),
    "tieByInsufficient": MessageLookupByLibrary.simpleMessage(
      "Tie due to insufficient material!",
    ),
    "tieByReply": MessageLookupByLibrary.simpleMessage("Tie by replay!"),
    "ties": MessageLookupByLibrary.simpleMessage("Ties"),
    "tileDoesntConnect": MessageLookupByLibrary.simpleMessage(
      "This tile doesn\'t connect with the ends",
    ),
    "time": MessageLookupByLibrary.simpleMessage("Time"),
    "timeExpiredFirstMove": MessageLookupByLibrary.simpleMessage(
      "Time expired: You did not make your first move in 14 seconds",
    ),
    "timeExpiredMove": MessageLookupByLibrary.simpleMessage(
      "Time expired: You did not complete your move in 1 minute",
    ),
    "timeExpiredTitle": MessageLookupByLibrary.simpleMessage("Time Expired"),
    "timeExpiredWaiting": MessageLookupByLibrary.simpleMessage(
      "Waiting time expired.",
    ),
    "timeLostMatch": MessageLookupByLibrary.simpleMessage(
      "You lost the match due to time",
    ),
    "timeOut": MessageLookupByLibrary.simpleMessage("Time out!"),
    "timeRunOutMessage": MessageLookupByLibrary.simpleMessage(
      "You ran out of time to make your move",
    ),
    "timeSettings": MessageLookupByLibrary.simpleMessage("Time settings"),
    "toJoinThisGame": MessageLookupByLibrary.simpleMessage(
      "to join this game.",
    ),
    "toParticipate": MessageLookupByLibrary.simpleMessage("to participate"),
    "toPlay": MessageLookupByLibrary.simpleMessage("to play"),
    "toUse": MessageLookupByLibrary.simpleMessage("To use"),
    "tokens": MessageLookupByLibrary.simpleMessage("Tokens"),
    "top": MessageLookupByLibrary.simpleMessage("TOP"),
    "totalPoints": MessageLookupByLibrary.simpleMessage("Total Points"),
    "totalRequired": MessageLookupByLibrary.simpleMessage("Total required"),
    "traditionalDomino": MessageLookupByLibrary.simpleMessage(
      "Traditional Domino",
    ),
    "tripleDouble": MessageLookupByLibrary.simpleMessage(
      "Triple double! Piece sent home",
    ),
    "tutorial": MessageLookupByLibrary.simpleMessage("Tutorial"),
    "tutorialChessTitle": MessageLookupByLibrary.simpleMessage(
      "Chess Tutorial",
    ),
    "tutorialCompleted": MessageLookupByLibrary.simpleMessage(
      "You have completed the tutorial of",
    ),
    "tutorialShort": MessageLookupByLibrary.simpleMessage("Tutorial"),
    "tutorialTitle": MessageLookupByLibrary.simpleMessage("How to play Ludo"),
    "ultraDifficult": MessageLookupByLibrary.simpleMessage("Ultra difficult"),
    "understood": MessageLookupByLibrary.simpleMessage("Understood"),
    "user": MessageLookupByLibrary.simpleMessage("User"),
    "userDataLoadError": MessageLookupByLibrary.simpleMessage(
      "Error loading user data",
    ),
    "userNotFound": MessageLookupByLibrary.simpleMessage(
      "User not authenticated",
    ),
    "verificationEmailResent": MessageLookupByLibrary.simpleMessage(
      "Verification email resent",
    ),
    "verificationEmailSent": MessageLookupByLibrary.simpleMessage(
      "We have sent a verification link to your email. Please check your email to activate your account and access all features.",
    ),
    "verifyEmail": MessageLookupByLibrary.simpleMessage("Verify your email"),
    "verifyYourEmail": MessageLookupByLibrary.simpleMessage(
      "Verify your email",
    ),
    "version": MessageLookupByLibrary.simpleMessage("Version"),
    "veryEasy": MessageLookupByLibrary.simpleMessage("Very easy"),
    "victories": MessageLookupByLibrary.simpleMessage("Victories"),
    "victoriesPct": MessageLookupByLibrary.simpleMessage("Win %"),
    "victory": MessageLookupByLibrary.simpleMessage("VICTORY!"),
    "volume": MessageLookupByLibrary.simpleMessage("Music volume"),
    "vsCpu": MessageLookupByLibrary.simpleMessage("Vs CPU"),
    "vsFriend": MessageLookupByLibrary.simpleMessage("Vs Friend"),
    "waiting": MessageLookupByLibrary.simpleMessage("Waiting"),
    "waitingForOpponentJoin": MessageLookupByLibrary.simpleMessage(
      "Waiting for an opponent to join...",
    ),
    "waitingOpponent": MessageLookupByLibrary.simpleMessage(
      "Waiting for opponent...",
    ),
    "waitingOpponentResponse": MessageLookupByLibrary.simpleMessage(
      "Waiting for opponent\'s response...",
    ),
    "waitingOthers": MessageLookupByLibrary.simpleMessage(
      "Waiting for others...",
    ),
    "waitingRoom": MessageLookupByLibrary.simpleMessage("Waiting room"),
    "wantsRematch": MessageLookupByLibrary.simpleMessage("wants a rematch!"),
    "watchMovement": MessageLookupByLibrary.simpleMessage("Watch movement"),
    "welcome": MessageLookupByLibrary.simpleMessage("Welcome"),
    "well": MessageLookupByLibrary.simpleMessage("Well"),
    "wellDone": MessageLookupByLibrary.simpleMessage("Well done! Correct move"),
    "whatPlay": MessageLookupByLibrary.simpleMessage(
      "What do you want to play?",
    ),
    "whichDiceToUse": MessageLookupByLibrary.simpleMessage("Which die to use?"),
    "whites": MessageLookupByLibrary.simpleMessage("Whites"),
    "winRate": MessageLookupByLibrary.simpleMessage("Win rate"),
    "wins": MessageLookupByLibrary.simpleMessage("Win"),
    "withdrawDiamonds": MessageLookupByLibrary.simpleMessage(
      "Withdraw Diamonds",
    ),
    "withdrawProcessError": MessageLookupByLibrary.simpleMessage(
      "Error processing the withdrawal",
    ),
    "withdrawalProcessed": m6,
    "withdrawalsProcessedIn": MessageLookupByLibrary.simpleMessage(
      "Withdrawals are processed within 24-48 business hours",
    ),
    "writeIssueHere": MessageLookupByLibrary.simpleMessage(
      "Write your message here...",
    ),
    "wrongSide": MessageLookupByLibrary.simpleMessage(
      "Wrong side. Try the side",
    ),
    "you": MessageLookupByLibrary.simpleMessage("You"),
    "youDid": MessageLookupByLibrary.simpleMessage("you did"),
    "youDontHave": MessageLookupByLibrary.simpleMessage("You don’t have"),
    "youHave": MessageLookupByLibrary.simpleMessage("You have"),
    "youHavePlayableTiles": MessageLookupByLibrary.simpleMessage(
      "You have playable tiles",
    ),
    "youHaveWon": MessageLookupByLibrary.simpleMessage("You have won the game"),
    "youHaventPlayed": MessageLookupByLibrary.simpleMessage(
      "You haven\'t played",
    ),
    "youLost": MessageLookupByLibrary.simpleMessage("You lost\nGood try"),
    "youLostByTimeout": MessageLookupByLibrary.simpleMessage(
      "You lost by timeout",
    ),
    "youLostHand": MessageLookupByLibrary.simpleMessage("You lost the hand"),
    "youNeed": MessageLookupByLibrary.simpleMessage("You need"),
    "youNeedToLogin": MessageLookupByLibrary.simpleMessage(
      "you need to log in",
    ),
    "youStoleChip": MessageLookupByLibrary.simpleMessage(
      "You stole a chip from the pot",
    ),
    "youWon": MessageLookupByLibrary.simpleMessage("You won!\nCongratulations"),
    "youWonCheckMate": MessageLookupByLibrary.simpleMessage(
      "You won! Checkmate",
    ),
    "youWonHand": MessageLookupByLibrary.simpleMessage("You won the hand!"),
    "youWonProcess": MessageLookupByLibrary.simpleMessage(
      "You won! Your rewards are being processed...",
    ),
    "youWonShort": MessageLookupByLibrary.simpleMessage("You Won"),
    "yourCurrentBalance": MessageLookupByLibrary.simpleMessage(
      "Your current balance:",
    ),
    "yourCurrentBet": MessageLookupByLibrary.simpleMessage("Your current bet:"),
    "yourPositionIn": MessageLookupByLibrary.simpleMessage("Your position in"),
    "yourTemporaryName": MessageLookupByLibrary.simpleMessage(
      "Your temporary name",
    ),
    "yourTurn": MessageLookupByLibrary.simpleMessage("Your turn"),
  };
}
