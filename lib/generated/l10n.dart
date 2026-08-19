// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'intl/messages_all.dart';

// **************************************************************************
// Generator: Flutter Intl IDE plugin
// Made by Localizely
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, lines_longer_than_80_chars
// ignore_for_file: join_return_with_assignment, prefer_final_in_for_each
// ignore_for_file: avoid_redundant_argument_values, avoid_escaping_inner_quotes

class S {
  S();

  static S? _current;

  static S get current {
    assert(
      _current != null,
      'No instance of S was loaded. Try to initialize the S delegate before accessing S.current.',
    );
    return _current!;
  }

  static const AppLocalizationDelegate delegate = AppLocalizationDelegate();

  static Future<S> load(Locale locale) {
    final name = (locale.countryCode?.isEmpty ?? false)
        ? locale.languageCode
        : locale.toString();
    final localeName = Intl.canonicalizedLocale(name);
    return initializeMessages(localeName).then((_) {
      Intl.defaultLocale = localeName;
      final instance = S();
      S._current = instance;

      return instance;
    });
  }

  static S of(BuildContext context) {
    final instance = S.maybeOf(context);
    assert(
      instance != null,
      'No instance of S present in the widget tree. Did you add S.delegate in localizationsDelegates?',
    );
    return instance!;
  }

  static S? maybeOf(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  /// `Tekoplay`
  String get appTitle {
    return Intl.message('Tekoplay', name: 'appTitle', desc: '', args: []);
  }

  /// `Settings`
  String get settings {
    return Intl.message('Settings', name: 'settings', desc: '', args: []);
  }

  /// `Language`
  String get language {
    return Intl.message('Language', name: 'language', desc: '', args: []);
  }

  /// `Select language`
  String get languageSelect {
    return Intl.message(
      'Select language',
      name: 'languageSelect',
      desc: '',
      args: [],
    );
  }

  /// `Spanish`
  String get languageEs {
    return Intl.message('Spanish', name: 'languageEs', desc: '', args: []);
  }

  /// `English`
  String get languageEn {
    return Intl.message('English', name: 'languageEn', desc: '', args: []);
  }

  /// `French`
  String get languageFr {
    return Intl.message('French', name: 'languageFr', desc: '', args: []);
  }

  /// `Change game language`
  String get changeGameLanguage {
    return Intl.message(
      'Change game language',
      name: 'changeGameLanguage',
      desc: '',
      args: [],
    );
  }

  /// `Game music`
  String get gameMusic {
    return Intl.message('Game music', name: 'gameMusic', desc: '', args: []);
  }

  /// `Adjust music volume`
  String get adjustGameMusic {
    return Intl.message(
      'Adjust music volume',
      name: 'adjustGameMusic',
      desc: '',
      args: [],
    );
  }

  /// `Add account`
  String get addAccount {
    return Intl.message('Add account', name: 'addAccount', desc: '', args: []);
  }

  /// `Login`
  String get login {
    return Intl.message('Login', name: 'login', desc: '', args: []);
  }

  /// `Sign in with your account`
  String get signInAccount {
    return Intl.message(
      'Sign in with your account',
      name: 'signInAccount',
      desc: '',
      args: [],
    );
  }

  /// `Sign in with Google`
  String get googleLogin {
    return Intl.message(
      'Sign in with Google',
      name: 'googleLogin',
      desc: '',
      args: [],
    );
  }

  /// `Sign in with Facebook`
  String get facebookLogin {
    return Intl.message(
      'Sign in with Facebook',
      name: 'facebookLogin',
      desc: '',
      args: [],
    );
  }

  /// `Sign in with Tekoplay`
  String get emailLogin {
    return Intl.message(
      'Sign in with Tekoplay',
      name: 'emailLogin',
      desc: '',
      args: [],
    );
  }

  /// `Sign in with Apple ID`
  String get appleLogin {
    return Intl.message(
      'Sign in with Apple ID',
      name: 'appleLogin',
      desc: '',
      args: [],
    );
  }

  /// `Music volume`
  String get volume {
    return Intl.message('Music volume', name: 'volume', desc: '', args: []);
  }

  /// `Accept`
  String get accept {
    return Intl.message('Accept', name: 'accept', desc: '', args: []);
  }

  /// `Notifications`
  String get notifications {
    return Intl.message(
      'Notifications',
      name: 'notifications',
      desc: '',
      args: [],
    );
  }

  /// `Customize your notifications`
  String get customNotifications {
    return Intl.message(
      'Customize your notifications',
      name: 'customNotifications',
      desc: '',
      args: [],
    );
  }

  /// `Event reminder`
  String get reminder {
    return Intl.message('Event reminder', name: 'reminder', desc: '', args: []);
  }

  /// `Privacy`
  String get privacyTitle {
    return Intl.message('Privacy', name: 'privacyTitle', desc: '', args: []);
  }

  /// `Receive new messages`
  String get messages {
    return Intl.message(
      'Receive new messages',
      name: 'messages',
      desc: '',
      args: [],
    );
  }

  /// `Privacy policy`
  String get privacy {
    return Intl.message('Privacy policy', name: 'privacy', desc: '', args: []);
  }

  /// `Terms and conditions`
  String get terms {
    return Intl.message(
      'Terms and conditions',
      name: 'terms',
      desc: '',
      args: [],
    );
  }

  /// `Check our terms`
  String get termsCheck {
    return Intl.message(
      'Check our terms',
      name: 'termsCheck',
      desc: '',
      args: [],
    );
  }

  /// `Version`
  String get version {
    return Intl.message('Version', name: 'version', desc: '', args: []);
  }

  /// `What do you want to play?`
  String get whatPlay {
    return Intl.message(
      'What do you want to play?',
      name: 'whatPlay',
      desc: '',
      args: [],
    );
  }

  /// `Chess`
  String get chess {
    return Intl.message('Chess', name: 'chess', desc: '', args: []);
  }

  /// `Domino`
  String get domino {
    return Intl.message('Domino', name: 'domino', desc: '', args: []);
  }

  /// `Vs Friend`
  String get vsFriend {
    return Intl.message('Vs Friend', name: 'vsFriend', desc: '', args: []);
  }

  /// `Tutorial`
  String get tutorial {
    return Intl.message('Tutorial', name: 'tutorial', desc: '', args: []);
  }

  /// `Vs CPU`
  String get vsCpu {
    return Intl.message('Vs CPU', name: 'vsCpu', desc: '', args: []);
  }

  /// `Online`
  String get online {
    return Intl.message('Online', name: 'online', desc: '', args: []);
  }

  /// `Play with a friend`
  String get playWithFriend {
    return Intl.message(
      'Play with a friend',
      name: 'playWithFriend',
      desc: '',
      args: [],
    );
  }

  /// `Search by username`
  String get searchByUsername {
    return Intl.message(
      'Search by username',
      name: 'searchByUsername',
      desc: '',
      args: [],
    );
  }

  /// `Search`
  String get search {
    return Intl.message('Search', name: 'search', desc: '', args: []);
  }

  /// `Link copied`
  String get linkCopied {
    return Intl.message('Link copied', name: 'linkCopied', desc: '', args: []);
  }

  /// `Copy link to share`
  String get copyLinkToShare {
    return Intl.message(
      'Copy link to share',
      name: 'copyLinkToShare',
      desc: '',
      args: [],
    );
  }

  /// `Normal`
  String get normal {
    return Intl.message('Normal', name: 'normal', desc: '', args: []);
  }

  /// `Play against the computer`
  String get playVsComputer {
    return Intl.message(
      'Play against the computer',
      name: 'playVsComputer',
      desc: '',
      args: [],
    );
  }

  /// `Very easy`
  String get veryEasy {
    return Intl.message('Very easy', name: 'veryEasy', desc: '', args: []);
  }

  /// `Easy`
  String get easy {
    return Intl.message('Easy', name: 'easy', desc: '', args: []);
  }

  /// `Difficult`
  String get difficult {
    return Intl.message('Difficult', name: 'difficult', desc: '', args: []);
  }

  /// `Ultra difficult`
  String get ultraDifficult {
    return Intl.message(
      'Ultra difficult',
      name: 'ultraDifficult',
      desc: '',
      args: [],
    );
  }

  /// `Start game`
  String get startGame {
    return Intl.message('Start game', name: 'startGame', desc: '', args: []);
  }

  /// `Play online`
  String get playOnline {
    return Intl.message('Play online', name: 'playOnline', desc: '', args: []);
  }

  /// `Room code`
  String get roomCode {
    return Intl.message('Room code', name: 'roomCode', desc: '', args: []);
  }

  /// `Please enter a valid code`
  String get pleaseEnterValidCode {
    return Intl.message(
      'Please enter a valid code',
      name: 'pleaseEnterValidCode',
      desc: '',
      args: [],
    );
  }

  /// `Join room`
  String get joinRoom {
    return Intl.message('Join room', name: 'joinRoom', desc: '', args: []);
  }

  /// `Code generated and copied`
  String get generatedAndCopiedCode {
    return Intl.message(
      'Code generated and copied',
      name: 'generatedAndCopiedCode',
      desc: '',
      args: [],
    );
  }

  /// `Create new room`
  String get createNewRoom {
    return Intl.message(
      'Create new room',
      name: 'createNewRoom',
      desc: '',
      args: [],
    );
  }

  /// `Select your color`
  String get changeColor {
    return Intl.message(
      'Select your color',
      name: 'changeColor',
      desc: '',
      args: [],
    );
  }

  /// `Whites`
  String get whites {
    return Intl.message('Whites', name: 'whites', desc: '', args: []);
  }

  /// `Blacks`
  String get blacks {
    return Intl.message('Blacks', name: 'blacks', desc: '', args: []);
  }

  /// `Player vs CPU`
  String get playerVsCpu {
    return Intl.message(
      'Player vs CPU',
      name: 'playerVsCpu',
      desc: '',
      args: [],
    );
  }

  /// `Scoreboard`
  String get marker {
    return Intl.message('Scoreboard', name: 'marker', desc: '', args: []);
  }

  /// `CPU`
  String get cpu {
    return Intl.message('CPU', name: 'cpu', desc: '', args: []);
  }

  /// `Restart game`
  String get restartGame {
    return Intl.message(
      'Restart game',
      name: 'restartGame',
      desc: '',
      args: [],
    );
  }

  /// `Anonymous`
  String get anonymous {
    return Intl.message('Anonymous', name: 'anonymous', desc: '', args: []);
  }

  /// `Congratulations!`
  String get congratulations {
    return Intl.message(
      'Congratulations!',
      name: 'congratulations',
      desc: '',
      args: [],
    );
  }

  /// `You have completed the tutorial`
  String get completeTutorial {
    return Intl.message(
      'You have completed the tutorial',
      name: 'completeTutorial',
      desc: '',
      args: [],
    );
  }

  /// `Close`
  String get close {
    return Intl.message('Close', name: 'close', desc: '', args: []);
  }

  /// `Well done! Correct move`
  String get firstMoveCompleted {
    return Intl.message(
      'Well done! Correct move',
      name: 'firstMoveCompleted',
      desc: '',
      args: [],
    );
  }

  /// `Incorrect move`
  String get incorrectMove {
    return Intl.message(
      'Incorrect move',
      name: 'incorrectMove',
      desc: '',
      args: [],
    );
  }

  /// `you did`
  String get youDid {
    return Intl.message('you did', name: 'youDid', desc: '', args: []);
  }

  /// `Try`
  String get attempt {
    return Intl.message('Try', name: 'attempt', desc: '', args: []);
  }

  /// `Chess Tutorial`
  String get tutorialChessTitle {
    return Intl.message(
      'Chess Tutorial',
      name: 'tutorialChessTitle',
      desc: '',
      args: [],
    );
  }

  /// `Step`
  String get passed {
    return Intl.message('Step', name: 'passed', desc: '', args: []);
  }

  /// `Watch movement`
  String get watchMovement {
    return Intl.message(
      'Watch movement',
      name: 'watchMovement',
      desc: '',
      args: [],
    );
  }

  /// `Reset step`
  String get resetPassed {
    return Intl.message('Reset step', name: 'resetPassed', desc: '', args: []);
  }

  /// `Back`
  String get back {
    return Intl.message('Back', name: 'back', desc: '', args: []);
  }

  /// `Finish`
  String get finish {
    return Intl.message('Finish', name: 'finish', desc: '', args: []);
  }

  /// `Next`
  String get next {
    return Intl.message('Next', name: 'next', desc: '', args: []);
  }

  /// `Move pawns`
  String get movingPaws {
    return Intl.message('Move pawns', name: 'movingPaws', desc: '', args: []);
  }

  /// `Move knights`
  String get moveHorses {
    return Intl.message('Move knights', name: 'moveHorses', desc: '', args: []);
  }

  /// `Move rooks`
  String get moveTowers {
    return Intl.message('Move rooks', name: 'moveTowers', desc: '', args: []);
  }

  /// `You have completed the domino tutorial.`
  String get completeDominoTutorial {
    return Intl.message(
      'You have completed the domino tutorial.',
      name: 'completeDominoTutorial',
      desc: '',
      args: [],
    );
  }

  /// `Incorrect tile. Try with the tile`
  String get incorrectTab {
    return Intl.message(
      'Incorrect tile. Try with the tile',
      name: 'incorrectTab',
      desc: '',
      args: [],
    );
  }

  /// `Well done! Correct move`
  String get wellDone {
    return Intl.message(
      'Well done! Correct move',
      name: 'wellDone',
      desc: '',
      args: [],
    );
  }

  /// `Wrong side. Try the side`
  String get wrongSide {
    return Intl.message(
      'Wrong side. Try the side',
      name: 'wrongSide',
      desc: '',
      args: [],
    );
  }

  /// `left`
  String get left {
    return Intl.message('left', name: 'left', desc: '', args: []);
  }

  /// `right`
  String get right {
    return Intl.message('right', name: 'right', desc: '', args: []);
  }

  /// `This tile cannot be connected here`
  String get notAllowed {
    return Intl.message(
      'This tile cannot be connected here',
      name: 'notAllowed',
      desc: '',
      args: [],
    );
  }

  /// `Domino Tutorial`
  String get dominoTutorial {
    return Intl.message(
      'Domino Tutorial',
      name: 'dominoTutorial',
      desc: '',
      args: [],
    );
  }

  /// `Extremes`
  String get extremes {
    return Intl.message('Extremes', name: 'extremes', desc: '', args: []);
  }

  /// `There are no more chips in the pot`
  String get noMoreChips {
    return Intl.message(
      'There are no more chips in the pot',
      name: 'noMoreChips',
      desc: '',
      args: [],
    );
  }

  /// `You stole a chip from the pot`
  String get youStoleChip {
    return Intl.message(
      'You stole a chip from the pot',
      name: 'youStoleChip',
      desc: '',
      args: [],
    );
  }

  /// `You have won the game`
  String get youHaveWon {
    return Intl.message(
      'You have won the game',
      name: 'youHaveWon',
      desc: '',
      args: [],
    );
  }

  /// `End of the game`
  String get endGame {
    return Intl.message('End of the game', name: 'endGame', desc: '', args: []);
  }

  /// `The CPU has won`
  String get cpuWon {
    return Intl.message('The CPU has won', name: 'cpuWon', desc: '', args: []);
  }

  /// `Draw`
  String get drawMsg {
    return Intl.message('Draw', name: 'drawMsg', desc: '', args: []);
  }

  /// `The game ended in a draw`
  String get gameDraw {
    return Intl.message(
      'The game ended in a draw',
      name: 'gameDraw',
      desc: '',
      args: [],
    );
  }

  /// `'New game`
  String get newGame {
    return Intl.message('\'New game', name: 'newGame', desc: '', args: []);
  }

  /// `Difficulty`
  String get difficulty {
    return Intl.message('Difficulty', name: 'difficulty', desc: '', args: []);
  }

  /// `Well`
  String get well {
    return Intl.message('Well', name: 'well', desc: '', args: []);
  }

  /// `You`
  String get you {
    return Intl.message('You', name: 'you', desc: '', args: []);
  }

  /// `Stole`
  String get stole {
    return Intl.message('Stole', name: 'stole', desc: '', args: []);
  }

  /// `Pass`
  String get pass {
    return Intl.message('Pass', name: 'pass', desc: '', args: []);
  }

  /// `Tokens`
  String get tokens {
    return Intl.message('Tokens', name: 'tokens', desc: '', args: []);
  }

  /// `You won! Checkmate`
  String get youWonCheckMate {
    return Intl.message(
      'You won! Checkmate',
      name: 'youWonCheckMate',
      desc: '',
      args: [],
    );
  }

  /// `The CPU won by checkmate`
  String get cpuWonCheckMate {
    return Intl.message(
      'The CPU won by checkmate',
      name: 'cpuWonCheckMate',
      desc: '',
      args: [],
    );
  }

  /// `Draw by stalemate!`
  String get drawByStalemate {
    return Intl.message(
      'Draw by stalemate!',
      name: 'drawByStalemate',
      desc: '',
      args: [],
    );
  }

  /// `Tie by replay!`
  String get tieByReply {
    return Intl.message(
      'Tie by replay!',
      name: 'tieByReply',
      desc: '',
      args: [],
    );
  }

  /// `Tie due to insufficient material!`
  String get tieByInsufficient {
    return Intl.message(
      'Tie due to insufficient material!',
      name: 'tieByInsufficient',
      desc: '',
      args: [],
    );
  }

  /// `Game over`
  String get gameOver {
    return Intl.message('Game over', name: 'gameOver', desc: '', args: []);
  }

  /// `Exit`
  String get exit {
    return Intl.message('Exit', name: 'exit', desc: '', args: []);
  }

  /// `Welcome`
  String get welcome {
    return Intl.message('Welcome', name: 'welcome', desc: '', args: []);
  }

  /// `Error signing in with Google`
  String get errorSignInGoogle {
    return Intl.message(
      'Error signing in with Google',
      name: 'errorSignInGoogle',
      desc: '',
      args: [],
    );
  }

  /// `Error signing in with Facebook`
  String get errorSignInFacebook {
    return Intl.message(
      'Error signing in with Facebook',
      name: 'errorSignInFacebook',
      desc: '',
      args: [],
    );
  }

  /// `Sign out`
  String get signOut {
    return Intl.message('Sign out', name: 'signOut', desc: '', args: []);
  }

  /// `Sign out of your account`
  String get signOutAccount {
    return Intl.message(
      'Sign out of your account',
      name: 'signOutAccount',
      desc: '',
      args: [],
    );
  }

  /// `User`
  String get user {
    return Intl.message('User', name: 'user', desc: '', args: []);
  }

  /// `Are you sure you want to sign out?`
  String get signOutConfirmation {
    return Intl.message(
      'Are you sure you want to sign out?',
      name: 'signOutConfirmation',
      desc: '',
      args: [],
    );
  }

  /// `Cancel`
  String get cancel {
    return Intl.message('Cancel', name: 'cancel', desc: '', args: []);
  }

  /// `Signed out successfully`
  String get signOutSuccessful {
    return Intl.message(
      'Signed out successfully',
      name: 'signOutSuccessful',
      desc: '',
      args: [],
    );
  }

  /// `Sign out failed`
  String get signOutFailed {
    return Intl.message(
      'Sign out failed',
      name: 'signOutFailed',
      desc: '',
      args: [],
    );
  }

  /// `Technical Support`
  String get supportTitle {
    return Intl.message(
      'Technical Support',
      name: 'supportTitle',
      desc: '',
      args: [],
    );
  }

  /// `Describe your issue or question:`
  String get describeIssue {
    return Intl.message(
      'Describe your issue or question:',
      name: 'describeIssue',
      desc: '',
      args: [],
    );
  }

  /// `Write your message here...`
  String get writeIssueHere {
    return Intl.message(
      'Write your message here...',
      name: 'writeIssueHere',
      desc: '',
      args: [],
    );
  }

  /// `Please write a message`
  String get pleaseWriteIssue {
    return Intl.message(
      'Please write a message',
      name: 'pleaseWriteIssue',
      desc: '',
      args: [],
    );
  }

  /// `Send`
  String get send {
    return Intl.message('Send', name: 'send', desc: '', args: []);
  }

  /// `Message sent successfully. We will contact you soon.`
  String get sendIssueSuccessfully {
    return Intl.message(
      'Message sent successfully. We will contact you soon.',
      name: 'sendIssueSuccessfully',
      desc: '',
      args: [],
    );
  }

  /// `Failed to send the message. Please try again.`
  String get sendIssueFailed {
    return Intl.message(
      'Failed to send the message. Please try again.',
      name: 'sendIssueFailed',
      desc: '',
      args: [],
    );
  }

  /// `Tekoplay account`
  String get tekoplayAccount {
    return Intl.message(
      'Tekoplay account',
      name: 'tekoplayAccount',
      desc: '',
      args: [],
    );
  }

  /// `Sign Up`
  String get signUp {
    return Intl.message('Sign Up', name: 'signUp', desc: '', args: []);
  }

  /// `Log In`
  String get logIn {
    return Intl.message('Log In', name: 'logIn', desc: '', args: []);
  }

  /// `Forgot your password?`
  String get forgotPassword {
    return Intl.message(
      'Forgot your password?',
      name: 'forgotPassword',
      desc: '',
      args: [],
    );
  }

  /// `Email`
  String get email {
    return Intl.message('Email', name: 'email', desc: '', args: []);
  }

  /// `Password`
  String get password {
    return Intl.message('Password', name: 'password', desc: '', args: []);
  }

  /// `Create account`
  String get createAccount {
    return Intl.message(
      'Create account',
      name: 'createAccount',
      desc: '',
      args: [],
    );
  }

  /// `Name`
  String get name {
    return Intl.message('Name', name: 'name', desc: '', args: []);
  }

  /// `Fill all fields`
  String get fillAllFields {
    return Intl.message(
      'Fill all fields',
      name: 'fillAllFields',
      desc: '',
      args: [],
    );
  }

  /// `Account created. Verify your email before signing in.`
  String get accountCreatedCheckEmail {
    return Intl.message(
      'Account created. Verify your email before signing in.',
      name: 'accountCreatedCheckEmail',
      desc: '',
      args: [],
    );
  }

  /// `Error creating account`
  String get errorCreatingAccount {
    return Intl.message(
      'Error creating account',
      name: 'errorCreatingAccount',
      desc: '',
      args: [],
    );
  }

  /// `Verify your email before signing in`
  String get emailNotVerified {
    return Intl.message(
      'Verify your email before signing in',
      name: 'emailNotVerified',
      desc: '',
      args: [],
    );
  }

  /// `Sign in error. Check your credentials.`
  String get errorSignInEmail {
    return Intl.message(
      'Sign in error. Check your credentials.',
      name: 'errorSignInEmail',
      desc: '',
      args: [],
    );
  }

  /// `Enter your email to receive a recovery link`
  String get enterEmailToReset {
    return Intl.message(
      'Enter your email to receive a recovery link',
      name: 'enterEmailToReset',
      desc: '',
      args: [],
    );
  }

  /// `Enter a valid email`
  String get enterValidEmail {
    return Intl.message(
      'Enter a valid email',
      name: 'enterValidEmail',
      desc: '',
      args: [],
    );
  }

  /// `Recovery email sent. Check your inbox.`
  String get passwordResetSent {
    return Intl.message(
      'Recovery email sent. Check your inbox.',
      name: 'passwordResetSent',
      desc: '',
      args: [],
    );
  }

  /// `Error sending password reset email`
  String get errorSendingPasswordReset {
    return Intl.message(
      'Error sending password reset email',
      name: 'errorSendingPasswordReset',
      desc: '',
      args: [],
    );
  }

  /// `Select game type`
  String get selectGameType {
    return Intl.message(
      'Select game type',
      name: 'selectGameType',
      desc: '',
      args: [],
    );
  }

  /// `Fun`
  String get fun {
    return Intl.message('Fun', name: 'fun', desc: '', args: []);
  }

  /// `Bet`
  String get bet {
    return Intl.message('Bet', name: 'bet', desc: '', args: []);
  }

  /// `El Pase`
  String get pase {
    return Intl.message('El Pase', name: 'pase', desc: '', args: []);
  }

  /// `Ranking`
  String get ranking {
    return Intl.message('Ranking', name: 'ranking', desc: '', args: []);
  }

  /// `Game Statistics`
  String get gameStats {
    return Intl.message(
      'Game Statistics',
      name: 'gameStats',
      desc: '',
      args: [],
    );
  }

  /// `Your position in`
  String get yourPositionIn {
    return Intl.message(
      'Your position in',
      name: 'yourPositionIn',
      desc: '',
      args: [],
    );
  }

  /// `No ranking data available`
  String get notRankingInfo {
    return Intl.message(
      'No ranking data available',
      name: 'notRankingInfo',
      desc: '',
      args: [],
    );
  }

  /// `Games Played`
  String get gamePlayed {
    return Intl.message('Games Played', name: 'gamePlayed', desc: '', args: []);
  }

  /// `Victories`
  String get victories {
    return Intl.message('Victories', name: 'victories', desc: '', args: []);
  }

  /// `Loading rankings...`
  String get loadingRanking {
    return Intl.message(
      'Loading rankings...',
      name: 'loadingRanking',
      desc: '',
      args: [],
    );
  }

  /// `You don't have a ranking in`
  String get notRankingIn {
    return Intl.message(
      'You don\'t have a ranking in',
      name: 'notRankingIn',
      desc: '',
      args: [],
    );
  }

  /// `General Summary`
  String get generalSummary {
    return Intl.message(
      'General Summary',
      name: 'generalSummary',
      desc: '',
      args: [],
    );
  }

  /// `Games`
  String get games {
    return Intl.message('Games', name: 'games', desc: '', args: []);
  }

  /// `Win %`
  String get victoriesPct {
    return Intl.message('Win %', name: 'victoriesPct', desc: '', args: []);
  }

  /// `Total Points`
  String get totalPoints {
    return Intl.message(
      'Total Points',
      name: 'totalPoints',
      desc: '',
      args: [],
    );
  }

  /// `Statistics`
  String get stats {
    return Intl.message('Statistics', name: 'stats', desc: '', args: []);
  }

  /// `Points`
  String get point {
    return Intl.message('Points', name: 'point', desc: '', args: []);
  }

  /// `Defeats`
  String get defeats {
    return Intl.message('Defeats', name: 'defeats', desc: '', args: []);
  }

  /// `Ties`
  String get ties {
    return Intl.message('Ties', name: 'ties', desc: '', args: []);
  }

  /// `Average Time`
  String get averageTime {
    return Intl.message(
      'Average Time',
      name: 'averageTime',
      desc: '',
      args: [],
    );
  }

  /// `You haven't played any games yet`
  String get notPlayedGameYet {
    return Intl.message(
      'You haven\'t played any games yet',
      name: 'notPlayedGameYet',
      desc: '',
      args: [],
    );
  }

  /// `You haven't played`
  String get youHaventPlayed {
    return Intl.message(
      'You haven\'t played',
      name: 'youHaventPlayed',
      desc: '',
      args: [],
    );
  }

  /// `yet`
  String get still {
    return Intl.message('yet', name: 'still', desc: '', args: []);
  }

  /// `Win`
  String get wins {
    return Intl.message('Win', name: 'wins', desc: '', args: []);
  }

  /// `Loss`
  String get lose {
    return Intl.message('Loss', name: 'lose', desc: '', args: []);
  }

  /// `Tie`
  String get tie {
    return Intl.message('Tie', name: 'tie', desc: '', args: []);
  }

  /// `Game History`
  String get gameHistory {
    return Intl.message(
      'Game History',
      name: 'gameHistory',
      desc: '',
      args: [],
    );
  }

  /// `All`
  String get all {
    return Intl.message('All', name: 'all', desc: '', args: []);
  }

  /// `Loading history...`
  String get loadingHistory {
    return Intl.message(
      'Loading history...',
      name: 'loadingHistory',
      desc: '',
      args: [],
    );
  }

  /// `Technical Support`
  String get technicalSupport {
    return Intl.message(
      'Technical Support',
      name: 'technicalSupport',
      desc: '',
      args: [],
    );
  }

  /// `Contact our support team`
  String get contactSupport {
    return Intl.message(
      'Contact our support team',
      name: 'contactSupport',
      desc: '',
      args: [],
    );
  }

  /// `User not authenticated`
  String get userNotFound {
    return Intl.message(
      'User not authenticated',
      name: 'userNotFound',
      desc: '',
      args: [],
    );
  }

  /// `Game not found`
  String get gameNotFound {
    return Intl.message(
      'Game not found',
      name: 'gameNotFound',
      desc: '',
      args: [],
    );
  }

  /// `Congratulations`
  String get congrats {
    return Intl.message(
      'Congratulations',
      name: 'congrats',
      desc: '',
      args: [],
    );
  }

  /// `Opponent`
  String get rivals {
    return Intl.message('Opponent', name: 'rivals', desc: '', args: []);
  }

  /// `Your opponent has disconnected`
  String get offlineOpponent {
    return Intl.message(
      'Your opponent has disconnected',
      name: 'offlineOpponent',
      desc: '',
      args: [],
    );
  }

  /// `Your turn`
  String get yourTurn {
    return Intl.message('Your turn', name: 'yourTurn', desc: '', args: []);
  }

  /// `Reconnecting...`
  String get reconnecting {
    return Intl.message(
      'Reconnecting...',
      name: 'reconnecting',
      desc: '',
      args: [],
    );
  }

  /// `Moves`
  String get movement {
    return Intl.message('Moves', name: 'movement', desc: '', args: []);
  }

  /// `Qualifier`
  String get qualifier {
    return Intl.message('Qualifier', name: 'qualifier', desc: '', args: []);
  }

  /// `Loading game...`
  String get loadingGame {
    return Intl.message(
      'Loading game...',
      name: 'loadingGame',
      desc: '',
      args: [],
    );
  }

  /// `Waiting for opponent...`
  String get waitingOpponent {
    return Intl.message(
      'Waiting for opponent...',
      name: 'waitingOpponent',
      desc: '',
      args: [],
    );
  }

  /// `Waiting for an opponent to join...`
  String get waitingForOpponentJoin {
    return Intl.message(
      'Waiting for an opponent to join...',
      name: 'waitingForOpponentJoin',
      desc: '',
      args: [],
    );
  }

  /// `Game code`
  String get gameCode {
    return Intl.message('Game code', name: 'gameCode', desc: '', args: []);
  }

  /// `Multiplayer game`
  String get multiplayer {
    return Intl.message(
      'Multiplayer game',
      name: 'multiplayer',
      desc: '',
      args: [],
    );
  }

  /// `Opponent's turn`
  String get opponentTurn {
    return Intl.message(
      'Opponent\'s turn',
      name: 'opponentTurn',
      desc: '',
      args: [],
    );
  }

  /// `Invitations`
  String get invitations {
    return Intl.message('Invitations', name: 'invitations', desc: '', args: []);
  }

  /// `No invitations`
  String get noInvitation {
    return Intl.message(
      'No invitations',
      name: 'noInvitation',
      desc: '',
      args: [],
    );
  }

  /// `invites you`
  String get invitesYou {
    return Intl.message('invites you', name: 'invitesYou', desc: '', args: []);
  }

  /// `Invitation rejected`
  String get invitationRejected {
    return Intl.message(
      'Invitation rejected',
      name: 'invitationRejected',
      desc: '',
      args: [],
    );
  }

  /// `Reject`
  String get reject {
    return Intl.message('Reject', name: 'reject', desc: '', args: []);
  }

  /// `Error accepting invitation`
  String get errorAcceptedInvitation {
    return Intl.message(
      'Error accepting invitation',
      name: 'errorAcceptedInvitation',
      desc: '',
      args: [],
    );
  }

  /// `Opponent's email`
  String get opponentEmail {
    return Intl.message(
      'Opponent\'s email',
      name: 'opponentEmail',
      desc: '',
      args: [],
    );
  }

  /// `Invitation sent successfully!`
  String get successfulSentInvitation {
    return Intl.message(
      'Invitation sent successfully!',
      name: 'successfulSentInvitation',
      desc: '',
      args: [],
    );
  }

  /// `Sending...`
  String get sending {
    return Intl.message('Sending...', name: 'sending', desc: '', args: []);
  }

  /// `Send invitation`
  String get sentInvitation {
    return Intl.message(
      'Send invitation',
      name: 'sentInvitation',
      desc: '',
      args: [],
    );
  }

  /// `Create public game`
  String get createPublicGame {
    return Intl.message(
      'Create public game',
      name: 'createPublicGame',
      desc: '',
      args: [],
    );
  }

  /// `Search public game`
  String get searchPublicGame {
    return Intl.message(
      'Search public game',
      name: 'searchPublicGame',
      desc: '',
      args: [],
    );
  }

  /// `Error creating the game`
  String get errorCreatePublicGame {
    return Intl.message(
      'Error creating the game',
      name: 'errorCreatePublicGame',
      desc: '',
      args: [],
    );
  }

  /// `Public games`
  String get publicGame {
    return Intl.message('Public games', name: 'publicGame', desc: '', args: []);
  }

  /// `No games available`
  String get noPublicGame {
    return Intl.message(
      'No games available',
      name: 'noPublicGame',
      desc: '',
      args: [],
    );
  }

  /// `Created`
  String get createdAgo {
    return Intl.message('Created', name: 'createdAgo', desc: '', args: []);
  }

  /// `Join`
  String get join {
    return Intl.message('Join', name: 'join', desc: '', args: []);
  }

  /// `Could not join the game`
  String get errorJoinGame {
    return Intl.message(
      'Could not join the game',
      name: 'errorJoinGame',
      desc: '',
      args: [],
    );
  }

  /// `Out of time`
  String get noTime {
    return Intl.message('Out of time', name: 'noTime', desc: '', args: []);
  }

  /// `Select game time`
  String get selectGameTime {
    return Intl.message(
      'Select game time',
      name: 'selectGameTime',
      desc: '',
      args: [],
    );
  }

  /// `Search game`
  String get searchGame {
    return Intl.message('Search game', name: 'searchGame', desc: '', args: []);
  }

  /// `Error searching game`
  String get errorSearchGame {
    return Intl.message(
      'Error searching game',
      name: 'errorSearchGame',
      desc: '',
      args: [],
    );
  }

  /// `No opponent found`
  String get opponentNotFound {
    return Intl.message(
      'No opponent found',
      name: 'opponentNotFound',
      desc: '',
      args: [],
    );
  }

  /// `Connection error`
  String get connectionError {
    return Intl.message(
      'Connection error',
      name: 'connectionError',
      desc: '',
      args: [],
    );
  }

  /// `Error sending move`
  String get errorSendMove {
    return Intl.message(
      'Error sending move',
      name: 'errorSendMove',
      desc: '',
      args: [],
    );
  }

  /// `Error making move`
  String get errorMakeMove {
    return Intl.message(
      'Error making move',
      name: 'errorMakeMove',
      desc: '',
      args: [],
    );
  }

  /// `You won!\nCongratulations`
  String get youWon {
    return Intl.message(
      'You won!\nCongratulations',
      name: 'youWon',
      desc: '',
      args: [],
    );
  }

  /// `You lost\nGood try`
  String get youLost {
    return Intl.message(
      'You lost\nGood try',
      name: 'youLost',
      desc: '',
      args: [],
    );
  }

  /// `Error`
  String get error {
    return Intl.message('Error', name: 'error', desc: '', args: []);
  }

  /// `Play again`
  String get playAgain {
    return Intl.message('Play again', name: 'playAgain', desc: '', args: []);
  }

  /// `Searching opponent`
  String get searchingOpponent {
    return Intl.message(
      'Searching opponent',
      name: 'searchingOpponent',
      desc: '',
      args: [],
    );
  }

  /// `Search canceled`
  String get searchCanceled {
    return Intl.message(
      'Search canceled',
      name: 'searchCanceled',
      desc: '',
      args: [],
    );
  }

  /// `Time`
  String get time {
    return Intl.message('Time', name: 'time', desc: '', args: []);
  }

  /// `Time settings`
  String get timeSettings {
    return Intl.message(
      'Time settings',
      name: 'timeSettings',
      desc: '',
      args: [],
    );
  }

  /// `Cancel search`
  String get cancelSearch {
    return Intl.message(
      'Cancel search',
      name: 'cancelSearch',
      desc: '',
      args: [],
    );
  }

  /// `Online game`
  String get onlineGame {
    return Intl.message('Online game', name: 'onlineGame', desc: '', args: []);
  }

  /// `Playing`
  String get playing {
    return Intl.message('Playing', name: 'playing', desc: '', args: []);
  }

  /// `Out of time`
  String get outOfTime {
    return Intl.message('Out of time', name: 'outOfTime', desc: '', args: []);
  }

  /// `Error accepting invitation`
  String get errorAcceptInvitation {
    return Intl.message(
      'Error accepting invitation',
      name: 'errorAcceptInvitation',
      desc: '',
      args: [],
    );
  }

  /// `Error processing invitation`
  String get errorProcessInvitation {
    return Intl.message(
      'Error processing invitation',
      name: 'errorProcessInvitation',
      desc: '',
      args: [],
    );
  }

  /// `Game invitation`
  String get gameInvitation {
    return Intl.message(
      'Game invitation',
      name: 'gameInvitation',
      desc: '',
      args: [],
    );
  }

  /// `invites you to play`
  String get invitesYouToPlay {
    return Intl.message(
      'invites you to play',
      name: 'invitesYouToPlay',
      desc: '',
      args: [],
    );
  }

  /// `Domino vs CPU`
  String get dominoVsCpu {
    return Intl.message(
      'Domino vs CPU',
      name: 'dominoVsCpu',
      desc: '',
      args: [],
    );
  }

  /// `Tap a tile to start`
  String get tapTileToStart {
    return Intl.message(
      'Tap a tile to start',
      name: 'tapTileToStart',
      desc: '',
      args: [],
    );
  }

  /// `Playing as guest!`
  String get playingAsGuest {
    return Intl.message(
      'Playing as guest!',
      name: 'playingAsGuest',
      desc: '',
      args: [],
    );
  }

  /// `Your temporary name`
  String get yourTemporaryName {
    return Intl.message(
      'Your temporary name',
      name: 'yourTemporaryName',
      desc: '',
      args: [],
    );
  }

  /// `To access all features and save your progress, log in with your account.`
  String get loginToAccessFeatures {
    return Intl.message(
      'To access all features and save your progress, log in with your account.',
      name: 'loginToAccessFeatures',
      desc: '',
      args: [],
    );
  }

  /// `Continue as guest`
  String get continueAsGuest {
    return Intl.message(
      'Continue as guest',
      name: 'continueAsGuest',
      desc: '',
      args: [],
    );
  }

  /// `Log in to save your progress`
  String get loginToSaveProgress {
    return Intl.message(
      'Log in to save your progress',
      name: 'loginToSaveProgress',
      desc: '',
      args: [],
    );
  }

  /// `Error logging in`
  String get errorLogin {
    return Intl.message(
      'Error logging in',
      name: 'errorLogin',
      desc: '',
      args: [],
    );
  }

  /// `Logged in as`
  String get loggedInAs {
    return Intl.message('Logged in as', name: 'loggedInAs', desc: '', args: []);
  }

  /// `Please fill in all fields`
  String get pleaseFillAllFields {
    return Intl.message(
      'Please fill in all fields',
      name: 'pleaseFillAllFields',
      desc: '',
      args: [],
    );
  }

  /// `Error creating account`
  String get errorCreateAccount {
    return Intl.message(
      'Error creating account',
      name: 'errorCreateAccount',
      desc: '',
      args: [],
    );
  }

  /// `Account created successfully. Verify your email.`
  String get accountCreated {
    return Intl.message(
      'Account created successfully. Verify your email.',
      name: 'accountCreated',
      desc: '',
      args: [],
    );
  }

  /// `Tap here to access all features`
  String get tapHereForFeatures {
    return Intl.message(
      'Tap here to access all features',
      name: 'tapHereForFeatures',
      desc: '',
      args: [],
    );
  }

  /// `Verify your email`
  String get verifyYourEmail {
    return Intl.message(
      'Verify your email',
      name: 'verifyYourEmail',
      desc: '',
      args: [],
    );
  }

  /// `Invalid credentials`
  String get invalidCredentials {
    return Intl.message(
      'Invalid credentials',
      name: 'invalidCredentials',
      desc: '',
      args: [],
    );
  }

  /// `Understood`
  String get understood {
    return Intl.message('Understood', name: 'understood', desc: '', args: []);
  }

  /// `We have sent a verification link to your email. Please check your email to activate your account and access all features.`
  String get verificationEmailSent {
    return Intl.message(
      'We have sent a verification link to your email. Please check your email to activate your account and access all features.',
      name: 'verificationEmailSent',
      desc: '',
      args: [],
    );
  }

  /// `Account created successfully!`
  String get accountCreatedUpdt {
    return Intl.message(
      'Account created successfully!',
      name: 'accountCreatedUpdt',
      desc: '',
      args: [],
    );
  }

  /// `Resend email`
  String get resendEmail {
    return Intl.message(
      'Resend email',
      name: 'resendEmail',
      desc: '',
      args: [],
    );
  }

  /// `Error resending email`
  String get errorResendEmail {
    return Intl.message(
      'Error resending email',
      name: 'errorResendEmail',
      desc: '',
      args: [],
    );
  }

  /// `Verification email resent`
  String get verificationEmailResent {
    return Intl.message(
      'Verification email resent',
      name: 'verificationEmailResent',
      desc: '',
      args: [],
    );
  }

  /// `Verify your email`
  String get verifyEmail {
    return Intl.message(
      'Verify your email',
      name: 'verifyEmail',
      desc: '',
      args: [],
    );
  }

  /// `Email verified successfully! You can now access all features.`
  String get emailVerifiedSuccess {
    return Intl.message(
      'Email verified successfully! You can now access all features.',
      name: 'emailVerifiedSuccess',
      desc: '',
      args: [],
    );
  }

  /// `Tap the photo to change it`
  String get tapPhotoToChange {
    return Intl.message(
      'Tap the photo to change it',
      name: 'tapPhotoToChange',
      desc: '',
      args: [],
    );
  }

  /// `Opponent left`
  String get opponentLeft {
    return Intl.message(
      'Opponent left',
      name: 'opponentLeft',
      desc: '',
      args: [],
    );
  }

  /// `The opponent abandoned the game`
  String get opponentAbandoned {
    return Intl.message(
      'The opponent abandoned the game',
      name: 'opponentAbandoned',
      desc: '',
      args: [],
    );
  }

  /// `Your opponent has abandoned the game.\n\nYou won automatically!`
  String get opponentAbandonedMessage {
    return Intl.message(
      'Your opponent has abandoned the game.\n\nYou won automatically!',
      name: 'opponentAbandonedMessage',
      desc: '',
      args: [],
    );
  }

  /// `Find new opponent`
  String get findNewOpponent {
    return Intl.message(
      'Find new opponent',
      name: 'findNewOpponent',
      desc: '',
      args: [],
    );
  }

  /// `Abandon game`
  String get abandonGame {
    return Intl.message(
      'Abandon game',
      name: 'abandonGame',
      desc: '',
      args: [],
    );
  }

  /// `Are you sure you want to abandon the game?\n\nIf you leave, it will count as a defeat and you will lose points.`
  String get abandonGameWarning {
    return Intl.message(
      'Are you sure you want to abandon the game?\n\nIf you leave, it will count as a defeat and you will lose points.',
      name: 'abandonGameWarning',
      desc: '',
      args: [],
    );
  }

  /// `Continue playing`
  String get continueGame {
    return Intl.message(
      'Continue playing',
      name: 'continueGame',
      desc: '',
      args: [],
    );
  }

  /// `Time out!`
  String get timeOut {
    return Intl.message('Time out!', name: 'timeOut', desc: '', args: []);
  }

  /// `You lost by timeout`
  String get youLostByTimeout {
    return Intl.message(
      'You lost by timeout',
      name: 'youLostByTimeout',
      desc: '',
      args: [],
    );
  }

  /// `Opponent lost by timeout`
  String get opponentLostByTimeout {
    return Intl.message(
      'Opponent lost by timeout',
      name: 'opponentLostByTimeout',
      desc: '',
      args: [],
    );
  }

  /// `You ran out of time to make your move`
  String get timeRunOutMessage {
    return Intl.message(
      'You ran out of time to make your move',
      name: 'timeRunOutMessage',
      desc: '',
      args: [],
    );
  }

  /// `Your opponent ran out of time`
  String get opponentTimeRunOutMessage {
    return Intl.message(
      'Your opponent ran out of time',
      name: 'opponentTimeRunOutMessage',
      desc: '',
      args: [],
    );
  }

  /// `Get more coins!`
  String get getMoreCoins {
    return Intl.message(
      'Get more coins!',
      name: 'getMoreCoins',
      desc: '',
      args: [],
    );
  }

  /// `Choose the perfect package for you`
  String get choosePerfectPackage {
    return Intl.message(
      'Choose the perfect package for you',
      name: 'choosePerfectPackage',
      desc: '',
      args: [],
    );
  }

  /// `MOST POPULAR!`
  String get mostPopular {
    return Intl.message(
      'MOST POPULAR!',
      name: 'mostPopular',
      desc: '',
      args: [],
    );
  }

  /// `BEST VALUE!`
  String get bestValue {
    return Intl.message('BEST VALUE!', name: 'bestValue', desc: '', args: []);
  }

  /// `Coin Store`
  String get coinStore {
    return Intl.message('Coin Store', name: 'coinStore', desc: '', args: []);
  }

  /// `coins`
  String get coins {
    return Intl.message('coins', name: 'coins', desc: '', args: []);
  }

  /// `Buy`
  String get buy {
    return Intl.message('Buy', name: 'buy', desc: '', args: []);
  }

  /// `MEGA PACK!`
  String get megaPack {
    return Intl.message('MEGA PACK!', name: 'megaPack', desc: '', args: []);
  }

  /// `POPULAR!`
  String get popular {
    return Intl.message('POPULAR!', name: 'popular', desc: '', args: []);
  }

  /// `diamonds`
  String get diamonds {
    return Intl.message('diamonds', name: 'diamonds', desc: '', args: []);
  }

  /// `Diamond Store`
  String get diamondStore {
    return Intl.message(
      'Diamond Store',
      name: 'diamondStore',
      desc: '',
      args: [],
    );
  }

  /// `Get more diamonds!`
  String get getMoreDiamonds {
    return Intl.message(
      'Get more diamonds!',
      name: 'getMoreDiamonds',
      desc: '',
      args: [],
    );
  }

  /// `Login required`
  String get loginRequired {
    return Intl.message(
      'Login required',
      name: 'loginRequired',
      desc: '',
      args: [],
    );
  }

  /// `To use`
  String get toUse {
    return Intl.message('To use', name: 'toUse', desc: '', args: []);
  }

  /// `you need to log in`
  String get youNeedToLogin {
    return Intl.message(
      'you need to log in',
      name: 'youNeedToLogin',
      desc: '',
      args: [],
    );
  }

  /// `Cancel Negotiation`
  String get cancelNegotiation {
    return Intl.message(
      'Cancel Negotiation',
      name: 'cancelNegotiation',
      desc: '',
      args: [],
    );
  }

  /// `Negotiating bet...`
  String get negotiatingBet {
    return Intl.message(
      'Negotiating bet...',
      name: 'negotiatingBet',
      desc: '',
      args: [],
    );
  }

  /// `Error accepting counteroffer`
  String get errorAcceptingCounteroffer {
    return Intl.message(
      'Error accepting counteroffer',
      name: 'errorAcceptingCounteroffer',
      desc: '',
      args: [],
    );
  }

  /// `Error rejecting counteroffer`
  String get errorRejectingCounteroffer {
    return Intl.message(
      'Error rejecting counteroffer',
      name: 'errorRejectingCounteroffer',
      desc: '',
      args: [],
    );
  }

  /// `Google Pay is not available on this device`
  String get googlePayNotAvailable {
    return Intl.message(
      'Google Pay is not available on this device',
      name: 'googlePayNotAvailable',
      desc: '',
      args: [],
    );
  }

  /// `Purchase successful!`
  String get purchaseSuccessful {
    return Intl.message(
      'Purchase successful!',
      name: 'purchaseSuccessful',
      desc: '',
      args: [],
    );
  }

  /// `Error processing payment`
  String get paymentProcessingError {
    return Intl.message(
      'Error processing payment',
      name: 'paymentProcessingError',
      desc: '',
      args: [],
    );
  }

  /// `The email entered is already registered, please use another one`
  String get emailAlreadyRegistered {
    return Intl.message(
      'The email entered is already registered, please use another one',
      name: 'emailAlreadyRegistered',
      desc: '',
      args: [],
    );
  }

  /// `Select your bet`
  String get selectYourBet {
    return Intl.message(
      'Select your bet',
      name: 'selectYourBet',
      desc: '',
      args: [],
    );
  }

  /// `available`
  String get available {
    return Intl.message('available', name: 'available', desc: '', args: []);
  }

  /// `You don't have enough`
  String get notEnough {
    return Intl.message(
      'You don\'t have enough',
      name: 'notEnough',
      desc: '',
      args: [],
    );
  }

  /// `for this bet`
  String get forThisBet {
    return Intl.message('for this bet', name: 'forThisBet', desc: '', args: []);
  }

  /// `Waiting for opponent's response...`
  String get waitingOpponentResponse {
    return Intl.message(
      'Waiting for opponent\'s response...',
      name: 'waitingOpponentResponse',
      desc: '',
      args: [],
    );
  }

  /// `Make Counteroffer`
  String get makeCounteroffer {
    return Intl.message(
      'Make Counteroffer',
      name: 'makeCounteroffer',
      desc: '',
      args: [],
    );
  }

  /// `Select your counteroffer:`
  String get selectYourCounteroffer {
    return Intl.message(
      'Select your counteroffer:',
      name: 'selectYourCounteroffer',
      desc: '',
      args: [],
    );
  }

  /// `Counteroffer`
  String get counteroffer {
    return Intl.message(
      'Counteroffer',
      name: 'counteroffer',
      desc: '',
      args: [],
    );
  }

  /// `New Counteroffer`
  String get newCounteroffer {
    return Intl.message(
      'New Counteroffer',
      name: 'newCounteroffer',
      desc: '',
      args: [],
    );
  }

  /// `has made a new counteroffer:`
  String get madeNewCounteroffer {
    return Intl.message(
      'has made a new counteroffer:',
      name: 'madeNewCounteroffer',
      desc: '',
      args: [],
    );
  }

  /// `Back`
  String get backTo {
    return Intl.message('Back', name: 'backTo', desc: '', args: []);
  }

  /// `The opponent has rejected your counteroffer.`
  String get opponentRejectedCounteroffer {
    return Intl.message(
      'The opponent has rejected your counteroffer.',
      name: 'opponentRejectedCounteroffer',
      desc: '',
      args: [],
    );
  }

  /// `Counteroffer Rejected`
  String get counterofferRejected {
    return Intl.message(
      'Counteroffer Rejected',
      name: 'counterofferRejected',
      desc: '',
      args: [],
    );
  }

  /// `Play!`
  String get play {
    return Intl.message('Play!', name: 'play', desc: '', args: []);
  }

  /// `has accepted your counteroffer of`
  String get acceptedYourCounterofferOf {
    return Intl.message(
      'has accepted your counteroffer of',
      name: 'acceptedYourCounterofferOf',
      desc: '',
      args: [],
    );
  }

  /// `Counteroffer Accepted!`
  String get counterofferAccepted {
    return Intl.message(
      'Counteroffer Accepted!',
      name: 'counterofferAccepted',
      desc: '',
      args: [],
    );
  }

  /// `Accept their bet`
  String get acceptTheirBet {
    return Intl.message(
      'Accept their bet',
      name: 'acceptTheirBet',
      desc: '',
      args: [],
    );
  }

  /// `Your current bet:`
  String get yourCurrentBet {
    return Intl.message(
      'Your current bet:',
      name: 'yourCurrentBet',
      desc: '',
      args: [],
    );
  }

  /// `has bet:`
  String get hasBet {
    return Intl.message('has bet:', name: 'hasBet', desc: '', args: []);
  }

  /// `Bet Negotiation`
  String get betNegotiation {
    return Intl.message(
      'Bet Negotiation',
      name: 'betNegotiation',
      desc: '',
      args: [],
    );
  }

  /// `accepts your bet`
  String get acceptsYourBet {
    return Intl.message(
      'accepts your bet',
      name: 'acceptsYourBet',
      desc: '',
      args: [],
    );
  }

  /// `Opponent Found!`
  String get opponentFound {
    return Intl.message(
      'Opponent Found!',
      name: 'opponentFound',
      desc: '',
      args: [],
    );
  }

  /// `seconds`
  String get seconds {
    return Intl.message('seconds', name: 'seconds', desc: '', args: []);
  }

  /// `minute`
  String get minute {
    return Intl.message('minute', name: 'minute', desc: '', args: []);
  }

  /// `Draw: Your bet of has been returned`
  String get drawBetReturned {
    return Intl.message(
      'Draw: Your bet of has been returned',
      name: 'drawBetReturned',
      desc: '',
      args: [],
    );
  }

  /// `You Won`
  String get youWonShort {
    return Intl.message('You Won', name: 'youWonShort', desc: '', args: []);
  }

  /// `Excellent! Correct move.`
  String get correctMove {
    return Intl.message(
      'Excellent! Correct move.',
      name: 'correctMove',
      desc: '',
      args: [],
    );
  }

  /// `Congratulations`
  String get congratulationsShort {
    return Intl.message(
      'Congratulations',
      name: 'congratulationsShort',
      desc: '',
      args: [],
    );
  }

  /// `You have completed the tutorial of`
  String get tutorialCompleted {
    return Intl.message(
      'You have completed the tutorial of',
      name: 'tutorialCompleted',
      desc: '',
      args: [],
    );
  }

  /// `Choose another piece`
  String get chooseAnotherPiece {
    return Intl.message(
      'Choose another piece',
      name: 'chooseAnotherPiece',
      desc: '',
      args: [],
    );
  }

  /// `Now you try`
  String get nowYouTry {
    return Intl.message('Now you try', name: 'nowYouTry', desc: '', args: []);
  }

  /// `Select a piece to learn:`
  String get selectPieceToLearn {
    return Intl.message(
      'Select a piece to learn:',
      name: 'selectPieceToLearn',
      desc: '',
      args: [],
    );
  }

  /// `exercise`
  String get exercise {
    return Intl.message('exercise', name: 'exercise', desc: '', args: []);
  }

  /// `Reset`
  String get reset {
    return Intl.message('Reset', name: 'reset', desc: '', args: []);
  }

  /// `Tutorial`
  String get tutorialShort {
    return Intl.message('Tutorial', name: 'tutorialShort', desc: '', args: []);
  }

  /// `Poker`
  String get poker {
    return Intl.message('Poker', name: 'poker', desc: '', args: []);
  }

  /// `Ludo`
  String get parchisShort {
    return Intl.message('Ludo', name: 'parchisShort', desc: '', args: []);
  }

  /// `COMING SOON`
  String get comingSoon {
    return Intl.message('COMING SOON', name: 'comingSoon', desc: '', args: []);
  }

  /// `Are you sure?`
  String get areYouSure {
    return Intl.message(
      'Are you sure?',
      name: 'areYouSure',
      desc: '',
      args: [],
    );
  }

  /// `has left the game`
  String get hasLeftTheGame {
    return Intl.message(
      'has left the game',
      name: 'hasLeftTheGame',
      desc: '',
      args: [],
    );
  }

  /// `Error loading user data`
  String get userDataLoadError {
    return Intl.message(
      'Error loading user data',
      name: 'userDataLoadError',
      desc: '',
      args: [],
    );
  }

  /// `Insufficient Funds`
  String get insufficientFunds {
    return Intl.message(
      'Insufficient Funds',
      name: 'insufficientFunds',
      desc: '',
      args: [],
    );
  }

  /// `to join this game.`
  String get toJoinThisGame {
    return Intl.message(
      'to join this game.',
      name: 'toJoinThisGame',
      desc: '',
      args: [],
    );
  }

  /// `You need`
  String get youNeed {
    return Intl.message('You need', name: 'youNeed', desc: '', args: []);
  }

  /// `You have`
  String get youHave {
    return Intl.message('You have', name: 'youHave', desc: '', args: []);
  }

  /// `Get more`
  String get getMore {
    return Intl.message('Get more', name: 'getMore', desc: '', args: []);
  }

  /// `Buy more`
  String get buyMore {
    return Intl.message('Buy more', name: 'buyMore', desc: '', args: []);
  }

  /// `in our store.`
  String get inOurStore {
    return Intl.message(
      'in our store.',
      name: 'inOurStore',
      desc: '',
      args: [],
    );
  }

  /// `You don’t have`
  String get youDontHave {
    return Intl.message(
      'You don’t have',
      name: 'youDontHave',
      desc: '',
      args: [],
    );
  }

  /// `enough to play`
  String get enoughToPlay {
    return Intl.message(
      'enough to play',
      name: 'enoughToPlay',
      desc: '',
      args: [],
    );
  }

  /// `You need at least 100`
  String get needAtLeast100 {
    return Intl.message(
      'You need at least 100',
      name: 'needAtLeast100',
      desc: '',
      args: [],
    );
  }

  /// `to participate`
  String get toParticipate {
    return Intl.message(
      'to participate',
      name: 'toParticipate',
      desc: '',
      args: [],
    );
  }

  /// `You don't have enough coins or diamonds to join multiplayer games`
  String get notEnoughCurrencyForMultiplayer {
    return Intl.message(
      'You don\'t have enough coins or diamonds to join multiplayer games',
      name: 'notEnoughCurrencyForMultiplayer',
      desc: '',
      args: [],
    );
  }

  /// `For fun games, you need at least 100 coins.`
  String get funGamesRequirement {
    return Intl.message(
      'For fun games, you need at least 100 coins.',
      name: 'funGamesRequirement',
      desc: '',
      args: [],
    );
  }

  /// `For betting games, you need at least 50 diamonds.`
  String get betGamesRequirement {
    return Intl.message(
      'For betting games, you need at least 50 diamonds.',
      name: 'betGamesRequirement',
      desc: '',
      args: [],
    );
  }

  /// `to play`
  String get toPlay {
    return Intl.message('to play', name: 'toPlay', desc: '', args: []);
  }

  /// `Your current balance:`
  String get yourCurrentBalance {
    return Intl.message(
      'Your current balance:',
      name: 'yourCurrentBalance',
      desc: '',
      args: [],
    );
  }

  /// `(First move:`
  String get firstMove {
    return Intl.message('(First move:', name: 'firstMove', desc: '', args: []);
  }

  /// `Waiting`
  String get waiting {
    return Intl.message('Waiting', name: 'waiting', desc: '', args: []);
  }

  /// `Invalid amount to withdraw`
  String get invalidAmountToWithdraw {
    return Intl.message(
      'Invalid amount to withdraw',
      name: 'invalidAmountToWithdraw',
      desc: '',
      args: [],
    );
  }

  /// `Error processing the withdrawal`
  String get withdrawProcessError {
    return Intl.message(
      'Error processing the withdrawal',
      name: 'withdrawProcessError',
      desc: '',
      args: [],
    );
  }

  /// `Withdraw Diamonds`
  String get withdrawDiamonds {
    return Intl.message(
      'Withdraw Diamonds',
      name: 'withdrawDiamonds',
      desc: '',
      args: [],
    );
  }

  /// `Available to withdraw`
  String get availableToWithdraw {
    return Intl.message(
      'Available to withdraw',
      name: 'availableToWithdraw',
      desc: '',
      args: [],
    );
  }

  /// `Quick amounts:`
  String get quickAmounts {
    return Intl.message(
      'Quick amounts:',
      name: 'quickAmounts',
      desc: '',
      args: [],
    );
  }

  /// `Custom amount`
  String get customAmount {
    return Intl.message(
      'Custom amount',
      name: 'customAmount',
      desc: '',
      args: [],
    );
  }

  /// `Enter the amount to withdraw`
  String get enterAmountToWithdraw {
    return Intl.message(
      'Enter the amount to withdraw',
      name: 'enterAmountToWithdraw',
      desc: '',
      args: [],
    );
  }

  /// `Processing...`
  String get processing {
    return Intl.message(
      'Processing...',
      name: 'processing',
      desc: '',
      args: [],
    );
  }

  /// `Request Withdrawal`
  String get requestWithdrawal {
    return Intl.message(
      'Request Withdrawal',
      name: 'requestWithdrawal',
      desc: '',
      args: [],
    );
  }

  /// `Withdrawals are processed within 24-48 business hours`
  String get withdrawalsProcessedIn {
    return Intl.message(
      'Withdrawals are processed within 24-48 business hours',
      name: 'withdrawalsProcessedIn',
      desc: '',
      args: [],
    );
  }

  /// `Let the game begin!`
  String get letGameBegin {
    return Intl.message(
      'Let the game begin!',
      name: 'letGameBegin',
      desc: '',
      args: [],
    );
  }

  /// `You won! Your rewards are being processed...`
  String get youWonProcess {
    return Intl.message(
      'You won! Your rewards are being processed...',
      name: 'youWonProcess',
      desc: '',
      args: [],
    );
  }

  /// `Game over. Processing results...`
  String get GameOverProcess {
    return Intl.message(
      'Game over. Processing results...',
      name: 'GameOverProcess',
      desc: '',
      args: [],
    );
  }

  /// `Draw - Refunds will be processed...`
  String get GameOverDraw {
    return Intl.message(
      'Draw - Refunds will be processed...',
      name: 'GameOverDraw',
      desc: '',
      args: [],
    );
  }

  /// `Recovered`
  String get recovered {
    return Intl.message('Recovered', name: 'recovered', desc: '', args: []);
  }

  /// `Error processing result`
  String get errorResult {
    return Intl.message(
      'Error processing result',
      name: 'errorResult',
      desc: '',
      args: [],
    );
  }

  /// `How to play Ludo`
  String get tutorialTitle {
    return Intl.message(
      'How to play Ludo',
      name: 'tutorialTitle',
      desc: '',
      args: [],
    );
  }

  /// `How many players?`
  String get howManyPlayers {
    return Intl.message(
      'How many players?',
      name: 'howManyPlayers',
      desc: '',
      args: [],
    );
  }

  /// `Choose the number of players for the game`
  String get choosePlayerCountForGame {
    return Intl.message(
      'Choose the number of players for the game',
      name: 'choosePlayerCountForGame',
      desc: '',
      args: [],
    );
  }

  /// `Waiting room`
  String get waitingRoom {
    return Intl.message(
      'Waiting room',
      name: 'waitingRoom',
      desc: '',
      args: [],
    );
  }

  /// `Invite friend`
  String get inviteFriend {
    return Intl.message(
      'Invite friend',
      name: 'inviteFriend',
      desc: '',
      args: [],
    );
  }

  /// `Invite friends`
  String get inviteFriends {
    return Intl.message(
      'Invite friends',
      name: 'inviteFriends',
      desc: '',
      args: [],
    );
  }

  /// `Invite another friend`
  String get inviteAnotherFriend {
    return Intl.message(
      'Invite another friend',
      name: 'inviteAnotherFriend',
      desc: '',
      args: [],
    );
  }

  /// `Everyone ready! Starting...`
  String get allReadyStarting {
    return Intl.message(
      'Everyone ready! Starting...',
      name: 'allReadyStarting',
      desc: '',
      args: [],
    );
  }

  /// `Cancel room`
  String get cancelRoom {
    return Intl.message('Cancel room', name: 'cancelRoom', desc: '', args: []);
  }

  /// `Error creating the room. Please try again.`
  String get errorCreatingRoom {
    return Intl.message(
      'Error creating the room. Please try again.',
      name: 'errorCreatingRoom',
      desc: '',
      args: [],
    );
  }

  /// `Real players only`
  String get realPlayersOnly {
    return Intl.message(
      'Real players only',
      name: 'realPlayersOnly',
      desc: '',
      args: [],
    );
  }

  /// `Real players only - no bots`
  String get realPlayersNoBots {
    return Intl.message(
      'Real players only - no bots',
      name: 'realPlayersNoBots',
      desc: '',
      args: [],
    );
  }

  /// `No options, you pass automatically`
  String get passAutomatic {
    return Intl.message(
      'No options, you pass automatically',
      name: 'passAutomatic',
      desc: '',
      args: [],
    );
  }

  /// `You have playable tiles`
  String get youHavePlayableTiles {
    return Intl.message(
      'You have playable tiles',
      name: 'youHavePlayableTiles',
      desc: '',
      args: [],
    );
  }

  /// `This tile doesn't connect with the ends`
  String get tileDoesntConnect {
    return Intl.message(
      'This tile doesn\'t connect with the ends',
      name: 'tileDoesntConnect',
      desc: '',
      args: [],
    );
  }

  /// `Could not play tile`
  String get couldNotPlayTile {
    return Intl.message(
      'Could not play tile',
      name: 'couldNotPlayTile',
      desc: '',
      args: [],
    );
  }

  /// `The pot is empty`
  String get emptyPotDomino {
    return Intl.message(
      'The pot is empty',
      name: 'emptyPotDomino',
      desc: '',
      args: [],
    );
  }

  /// `The current game will be closed.`
  String get abandonWarningFun {
    return Intl.message(
      'The current game will be closed.',
      name: 'abandonWarningFun',
      desc: '',
      args: [],
    );
  }

  /// `You will lose your bet if you abandon.`
  String get abandonWarningBet {
    return Intl.message(
      'You will lose your bet if you abandon.',
      name: 'abandonWarningBet',
      desc: '',
      args: [],
    );
  }

  /// `You will lose your bet and backup if you abandon. Other players will recover their diamonds.`
  String get abandonWarningPase {
    return Intl.message(
      'You will lose your bet and backup if you abandon. Other players will recover their diamonds.',
      name: 'abandonWarningPase',
      desc: '',
      args: [],
    );
  }

  /// `Enter your friend's email`
  String get enterFriendEmail {
    return Intl.message(
      'Enter your friend\'s email',
      name: 'enterFriendEmail',
      desc: '',
      args: [],
    );
  }

  /// `Enter each guest's email`
  String get enterGuestEmails {
    return Intl.message(
      'Enter each guest\'s email',
      name: 'enterGuestEmails',
      desc: '',
      args: [],
    );
  }

  /// `Friend's email`
  String get friendEmailLabel {
    return Intl.message(
      'Friend\'s email',
      name: 'friendEmailLabel',
      desc: '',
      args: [],
    );
  }

  /// `Guest email`
  String get guestEmailLabel {
    return Intl.message(
      'Guest email',
      name: 'guestEmailLabel',
      desc: '',
      args: [],
    );
  }

  /// `Bet amount`
  String get betAmountLabel {
    return Intl.message(
      'Bet amount',
      name: 'betAmountLabel',
      desc: '',
      args: [],
    );
  }

  /// `Bet mode`
  String get betMode {
    return Intl.message('Bet mode', name: 'betMode', desc: '', args: []);
  }

  /// `Fun mode`
  String get funMode {
    return Intl.message('Fun mode', name: 'funMode', desc: '', args: []);
  }

  /// `Invitation sent! Waiting for your friend to accept...`
  String get invitationSentWaiting {
    return Intl.message(
      'Invitation sent! Waiting for your friend to accept...',
      name: 'invitationSentWaiting',
      desc: '',
      args: [],
    );
  }

  /// `Some emails could not be sent:`
  String get someEmailsFailed {
    return Intl.message(
      'Some emails could not be sent:',
      name: 'someEmailsFailed',
      desc: '',
      args: [],
    );
  }

  /// `Round won`
  String get roundWon {
    return Intl.message('Round won', name: 'roundWon', desc: '', args: []);
  }

  /// `Round lost`
  String get roundLost {
    return Intl.message('Round lost', name: 'roundLost', desc: '', args: []);
  }

  /// `Blocked`
  String get roundBlocked {
    return Intl.message('Blocked', name: 'roundBlocked', desc: '', args: []);
  }

  /// `Next round`
  String get nextRound {
    return Intl.message('Next round', name: 'nextRound', desc: '', args: []);
  }

  /// `Domino - Friends`
  String get dominoFriends {
    return Intl.message(
      'Domino - Friends',
      name: 'dominoFriends',
      desc: '',
      args: [],
    );
  }

  /// `Domino Pase`
  String get dominoPaseTitle {
    return Intl.message(
      'Domino Pase',
      name: 'dominoPaseTitle',
      desc: '',
      args: [],
    );
  }

  /// `El Pase - Friends`
  String get dominoPaseFriends {
    return Intl.message(
      'El Pase - Friends',
      name: 'dominoPaseFriends',
      desc: '',
      args: [],
    );
  }

  /// `El Pase Room`
  String get dominoPaseWaitingRoom {
    return Intl.message(
      'El Pase Room',
      name: 'dominoPaseWaitingRoom',
      desc: '',
      args: [],
    );
  }

  /// `El Pase - Friends Room`
  String get dominoPaseWaitingRoomFriends {
    return Intl.message(
      'El Pase - Friends Room',
      name: 'dominoPaseWaitingRoomFriends',
      desc: '',
      args: [],
    );
  }

  /// `You need double the bet (bet + backup)`
  String get needDoubleForBet {
    return Intl.message(
      'You need double the bet (bet + backup)',
      name: 'needDoubleForBet',
      desc: '',
      args: [],
    );
  }

  /// `Searching for real players...`
  String get searchingRealPlayers {
    return Intl.message(
      'Searching for real players...',
      name: 'searchingRealPlayers',
      desc: '',
      args: [],
    );
  }

  /// `You won the hand!`
  String get youWonHand {
    return Intl.message(
      'You won the hand!',
      name: 'youWonHand',
      desc: '',
      args: [],
    );
  }

  /// `You lost the hand`
  String get youLostHand {
    return Intl.message(
      'You lost the hand',
      name: 'youLostHand',
      desc: '',
      args: [],
    );
  }

  /// `Passes`
  String get passCountLabel {
    return Intl.message('Passes', name: 'passCountLabel', desc: '', args: []);
  }

  /// `Rematch`
  String get rematch {
    return Intl.message('Rematch', name: 'rematch', desc: '', args: []);
  }

  /// `Accept rematch`
  String get acceptRematch {
    return Intl.message(
      'Accept rematch',
      name: 'acceptRematch',
      desc: '',
      args: [],
    );
  }

  /// `Waiting for others...`
  String get waitingOthers {
    return Intl.message(
      'Waiting for others...',
      name: 'waitingOthers',
      desc: '',
      args: [],
    );
  }

  /// `Creating rematch...`
  String get creatingRematch {
    return Intl.message(
      'Creating rematch...',
      name: 'creatingRematch',
      desc: '',
      args: [],
    );
  }

  /// `Rematch cancelled: a player has insufficient balance`
  String get rematchCancelled {
    return Intl.message(
      'Rematch cancelled: a player has insufficient balance',
      name: 'rematchCancelled',
      desc: '',
      args: [],
    );
  }

  /// `A player abandoned the game`
  String get playerAbandonedGame {
    return Intl.message(
      'A player abandoned the game',
      name: 'playerAbandonedGame',
      desc: '',
      args: [],
    );
  }

  /// `wants a rematch!`
  String get wantsRematch {
    return Intl.message(
      'wants a rematch!',
      name: 'wantsRematch',
      desc: '',
      args: [],
    );
  }

  /// `Diamonds only - Ready for the challenge?`
  String get diamondsOnlyChallenge {
    return Intl.message(
      'Diamonds only - Ready for the challenge?',
      name: 'diamondsOnlyChallenge',
      desc: '',
      args: [],
    );
  }

  /// `Nominal bet`
  String get nominalBet {
    return Intl.message('Nominal bet', name: 'nominalBet', desc: '', args: []);
  }

  /// `Backup`
  String get backupAmount {
    return Intl.message('Backup', name: 'backupAmount', desc: '', args: []);
  }

  /// `Total required`
  String get totalRequired {
    return Intl.message(
      'Total required',
      name: 'totalRequired',
      desc: '',
      args: [],
    );
  }

  /// `Tekoplay commission`
  String get tekoplayCommission {
    return Intl.message(
      'Tekoplay commission',
      name: 'tekoplayCommission',
      desc: '',
      args: [],
    );
  }

  /// `Pass value`
  String get passValueLabel {
    return Intl.message(
      'Pass value',
      name: 'passValueLabel',
      desc: '',
      args: [],
    );
  }

  /// `Could not create the rematch`
  String get cannotCreateRematch {
    return Intl.message(
      'Could not create the rematch',
      name: 'cannotCreateRematch',
      desc: '',
      args: [],
    );
  }

  /// `Insufficient balance for rematch`
  String get insufficientForRematch {
    return Intl.message(
      'Insufficient balance for rematch',
      name: 'insufficientForRematch',
      desc: '',
      args: [],
    );
  }

  /// `Ludo vs Friend`
  String get parchisVsFriend {
    return Intl.message(
      'Ludo vs Friend',
      name: 'parchisVsFriend',
      desc: '',
      args: [],
    );
  }

  /// `Ludo Online`
  String get parchisOnline {
    return Intl.message(
      'Ludo Online',
      name: 'parchisOnline',
      desc: '',
      args: [],
    );
  }

  /// `How much do you want to bet?`
  String get howMuchBet {
    return Intl.message(
      'How much do you want to bet?',
      name: 'howMuchBet',
      desc: '',
      args: [],
    );
  }

  /// `Choose the diamond amount for this game`
  String get chooseBetAmountDiamonds {
    return Intl.message(
      'Choose the diamond amount for this game',
      name: 'chooseBetAmountDiamonds',
      desc: '',
      args: [],
    );
  }

  /// `Roll dice`
  String get rollDice {
    return Intl.message('Roll dice', name: 'rollDice', desc: '', args: []);
  }

  /// `Which die to use?`
  String get whichDiceToUse {
    return Intl.message(
      'Which die to use?',
      name: 'whichDiceToUse',
      desc: '',
      args: [],
    );
  }

  /// `VICTORY!`
  String get victory {
    return Intl.message('VICTORY!', name: 'victory', desc: '', args: []);
  }

  /// `END OF GAME`
  String get endOfGame {
    return Intl.message('END OF GAME', name: 'endOfGame', desc: '', args: []);
  }

  /// `No valid moves. Turn skipped.`
  String get noValidMoves {
    return Intl.message(
      'No valid moves. Turn skipped.',
      name: 'noValidMoves',
      desc: '',
      args: [],
    );
  }

  /// `Triple double! Piece sent home`
  String get tripleDouble {
    return Intl.message(
      'Triple double! Piece sent home',
      name: 'tripleDouble',
      desc: '',
      args: [],
    );
  }

  /// `Three doubles at home! Turn lost.`
  String get threeDoublesHome {
    return Intl.message(
      'Three doubles at home! Turn lost.',
      name: 'threeDoublesHome',
      desc: '',
      args: [],
    );
  }

  /// `Double at home! Roll again.`
  String get doubleHome {
    return Intl.message(
      'Double at home! Roll again.',
      name: 'doubleHome',
      desc: '',
      args: [],
    );
  }

  /// `Bet amount (diamonds)`
  String get betAmountDiamonds {
    return Intl.message(
      'Bet amount (diamonds)',
      name: 'betAmountDiamonds',
      desc: '',
      args: [],
    );
  }

  /// `How to play — El Pase`
  String get paseTutorialTitle {
    return Intl.message(
      'How to play — El Pase',
      name: 'paseTutorialTitle',
      desc: '',
      args: [],
    );
  }

  /// `What is El Pase?`
  String get paseWhatIsIt {
    return Intl.message(
      'What is El Pase?',
      name: 'paseWhatIsIt',
      desc: '',
      args: [],
    );
  }

  /// `El Pase is a special domino mode for 3 or 4 players.\n\nA single hand is played per game, with diamonds only.`
  String get paseWhatBody {
    return Intl.message(
      'El Pase is a special domino mode for 3 or 4 players.\n\nA single hand is played per game, with diamonds only.',
      name: 'paseWhatBody',
      desc: '',
      args: [],
    );
  }

  /// `How to play`
  String get paseHowToPlay {
    return Intl.message(
      'How to play',
      name: 'paseHowToPlay',
      desc: '',
      args: [],
    );
  }

  /// `At the start each player receives 7 tiles. The player with the highest double goes first.\n\nPlace tiles by connecting matching numbers at the ends of the chain.`
  String get paseHowToPlayBody {
    return Intl.message(
      'At the start each player receives 7 tiles. The player with the highest double goes first.\n\nPlace tiles by connecting matching numbers at the ends of the chain.',
      name: 'paseHowToPlayBody',
      desc: '',
      args: [],
    );
  }

  /// `The Pase!`
  String get paseThePase {
    return Intl.message('The Pase!', name: 'paseThePase', desc: '', args: []);
  }

  /// `If you can't play any tile, you must pass your turn. When you pass, each of your rivals pays you a diamond amount.\n\nYou can also pass if there is a total blockage (nobody can play).`
  String get paseThePaseBody {
    return Intl.message(
      'If you can\'t play any tile, you must pass your turn. When you pass, each of your rivals pays you a diamond amount.\n\nYou can also pass if there is a total blockage (nobody can play).',
      name: 'paseThePaseBody',
      desc: '',
      args: [],
    );
  }

  /// `Passing can be profitable!`
  String get paseThePaseHighlight {
    return Intl.message(
      'Passing can be profitable!',
      name: 'paseThePaseHighlight',
      desc: '',
      args: [],
    );
  }

  /// `How to win?`
  String get paseHowToWin {
    return Intl.message(
      'How to win?',
      name: 'paseHowToWin',
      desc: '',
      args: [],
    );
  }

  /// `The player who places all their tiles first wins.\n\nIf the game is blocked (nobody can play), the player with the fewest points in their remaining tiles wins.`
  String get paseHowToWinBody {
    return Intl.message(
      'The player who places all their tiles first wins.\n\nIf the game is blocked (nobody can play), the player with the fewest points in their remaining tiles wins.',
      name: 'paseHowToWinBody',
      desc: '',
      args: [],
    );
  }

  /// `The Bet`
  String get paseBetTitle {
    return Intl.message('The Bet', name: 'paseBetTitle', desc: '', args: []);
  }

  /// `To enter you need double your bet as minimum balance.\n\nThe winner takes the pot minus a 10% commission.\n\nPass payments are added or subtracted from each player's final prize.`
  String get paseBetBody {
    return Intl.message(
      'To enter you need double your bet as minimum balance.\n\nThe winner takes the pot minus a 10% commission.\n\nPass payments are added or subtracted from each player\'s final prize.',
      name: 'paseBetBody',
      desc: '',
      args: [],
    );
  }

  /// `Diamonds only — no coins`
  String get paseBetHighlight {
    return Intl.message(
      'Diamonds only — no coins',
      name: 'paseBetHighlight',
      desc: '',
      args: [],
    );
  }

  /// `Waiting time expired.`
  String get timeExpiredWaiting {
    return Intl.message(
      'Waiting time expired.',
      name: 'timeExpiredWaiting',
      desc: '',
      args: [],
    );
  }

  /// `Send invitations`
  String get sendInvitations {
    return Intl.message(
      'Send invitations',
      name: 'sendInvitations',
      desc: '',
      args: [],
    );
  }

  /// `Send invitation`
  String get sendInvitation {
    return Intl.message(
      'Send invitation',
      name: 'sendInvitation',
      desc: '',
      args: [],
    );
  }

  /// `Insufficient balance for rematch (you need {n} diamonds)`
  String insufficientDiamondsForRematch(Object n) {
    return Intl.message(
      'Insufficient balance for rematch (you need $n diamonds)',
      name: 'insufficientDiamondsForRematch',
      desc: '',
      args: [n],
    );
  }

  /// `Check!`
  String get check {
    return Intl.message('Check!', name: 'check', desc: '', args: []);
  }

  /// `♚ CHECK!`
  String get checkOnline {
    return Intl.message('♚ CHECK!', name: 'checkOnline', desc: '', args: []);
  }

  /// `Checkmate!`
  String get checkmate {
    return Intl.message('Checkmate!', name: 'checkmate', desc: '', args: []);
  }

  /// `Time Expired`
  String get timeExpiredTitle {
    return Intl.message(
      'Time Expired',
      name: 'timeExpiredTitle',
      desc: '',
      args: [],
    );
  }

  /// `Time expired: You did not make your first move in 14 seconds`
  String get timeExpiredFirstMove {
    return Intl.message(
      'Time expired: You did not make your first move in 14 seconds',
      name: 'timeExpiredFirstMove',
      desc: '',
      args: [],
    );
  }

  /// `Time expired: You did not complete your move in 1 minute`
  String get timeExpiredMove {
    return Intl.message(
      'Time expired: You did not complete your move in 1 minute',
      name: 'timeExpiredMove',
      desc: '',
      args: [],
    );
  }

  /// `You lost the match due to time`
  String get timeLostMatch {
    return Intl.message(
      'You lost the match due to time',
      name: 'timeLostMatch',
      desc: '',
      args: [],
    );
  }

  /// `Bets collected. Game is ready!`
  String get betCollectedReady {
    return Intl.message(
      'Bets collected. Game is ready!',
      name: 'betCollectedReady',
      desc: '',
      args: [],
    );
  }

  /// `Traditional Domino`
  String get traditionalDomino {
    return Intl.message(
      'Traditional Domino',
      name: 'traditionalDomino',
      desc: '',
      args: [],
    );
  }

  /// `Camera`
  String get camera {
    return Intl.message('Camera', name: 'camera', desc: '', args: []);
  }

  /// `Gallery`
  String get gallery {
    return Intl.message('Gallery', name: 'gallery', desc: '', args: []);
  }

  /// `Select image`
  String get selectImage {
    return Intl.message(
      'Select image',
      name: 'selectImage',
      desc: '',
      args: [],
    );
  }

  /// `Delete photo`
  String get deletePhoto {
    return Intl.message(
      'Delete photo',
      name: 'deletePhoto',
      desc: '',
      args: [],
    );
  }

  /// `Profile photo updated`
  String get profilePhotoUpdated {
    return Intl.message(
      'Profile photo updated',
      name: 'profilePhotoUpdated',
      desc: '',
      args: [],
    );
  }

  /// `Profile photo deleted`
  String get profilePhotoDeleted {
    return Intl.message(
      'Profile photo deleted',
      name: 'profilePhotoDeleted',
      desc: '',
      args: [],
    );
  }

  /// `Only available for email accounts`
  String get onlyEmailAccounts {
    return Intl.message(
      'Only available for email accounts',
      name: 'onlyEmailAccounts',
      desc: '',
      args: [],
    );
  }

  /// `No diamonds available to withdraw`
  String get noWithdrawableDiamonds {
    return Intl.message(
      'No diamonds available to withdraw',
      name: 'noWithdrawableDiamonds',
      desc: '',
      args: [],
    );
  }

  /// `Withdrawal request processed: {amount} diamonds`
  String withdrawalProcessed(Object amount) {
    return Intl.message(
      'Withdrawal request processed: $amount diamonds',
      name: 'withdrawalProcessed',
      desc: '',
      args: [amount],
    );
  }

  /// `Loading...`
  String get loadingDots {
    return Intl.message('Loading...', name: 'loadingDots', desc: '', args: []);
  }

  /// `Enter amount`
  String get enterAmount {
    return Intl.message(
      'Enter amount',
      name: 'enterAmount',
      desc: '',
      args: [],
    );
  }

  /// `Available: {count} diamonds`
  String availableDiamondsCount(Object count) {
    return Intl.message(
      'Available: $count diamonds',
      name: 'availableDiamondsCount',
      desc: '',
      args: [count],
    );
  }

  /// `Invalid bet amount`
  String get invalidBetAmount {
    return Intl.message(
      'Invalid bet amount',
      name: 'invalidBetAmount',
      desc: '',
      args: [],
    );
  }

  /// `Number of CPU opponents`
  String get cpuOpponentCount {
    return Intl.message(
      'Number of CPU opponents',
      name: 'cpuOpponentCount',
      desc: '',
      args: [],
    );
  }

  /// `(3 players)`
  String get players3total {
    return Intl.message(
      '(3 players)',
      name: 'players3total',
      desc: '',
      args: [],
    );
  }

  /// `(4 players)`
  String get players4total {
    return Intl.message(
      '(4 players)',
      name: 'players4total',
      desc: '',
      args: [],
    );
  }

  /// `Difficulty: Maximum`
  String get difficultyMax {
    return Intl.message(
      'Difficulty: Maximum',
      name: 'difficultyMax',
      desc: '',
      args: [],
    );
  }

  /// `In bet mode the CPU plays at maximum level.`
  String get difficultyMaxNote {
    return Intl.message(
      'In bet mode the CPU plays at maximum level.',
      name: 'difficultyMaxNote',
      desc: '',
      args: [],
    );
  }

  /// `You will play 1 vs 1 against the CPU in opposite positions`
  String get cpuVs1Description {
    return Intl.message(
      'You will play 1 vs 1 against the CPU in opposite positions',
      name: 'cpuVs1Description',
      desc: '',
      args: [],
    );
  }

  /// `You will play against 2 CPUs (3 players total)`
  String get cpuVs2Description {
    return Intl.message(
      'You will play against 2 CPUs (3 players total)',
      name: 'cpuVs2Description',
      desc: '',
      args: [],
    );
  }

  /// `You will play against 3 CPUs (4 players total)`
  String get cpuVs3Description {
    return Intl.message(
      'You will play against 3 CPUs (4 players total)',
      name: 'cpuVs3Description',
      desc: '',
      args: [],
    );
  }

  /// `CPU's turn`
  String get cpuTurn {
    return Intl.message('CPU\'s turn', name: 'cpuTurn', desc: '', args: []);
  }

  /// `Cost: {cost}`
  String gameCostLabel(Object cost) {
    return Intl.message(
      'Cost: $cost',
      name: 'gameCostLabel',
      desc: '',
      args: [cost],
    );
  }

  /// `Bet counteroffer`
  String get counterOfferTitle {
    return Intl.message(
      'Bet counteroffer',
      name: 'counterOfferTitle',
      desc: '',
      args: [],
    );
  }

  /// `{name} has made a counteroffer of {amount} diamonds (original: {original})`
  String counterOfferMsg(Object name, Object amount, Object original) {
    return Intl.message(
      '$name has made a counteroffer of $amount diamonds (original: $original)',
      name: 'counterOfferMsg',
      desc: '',
      args: [name, amount, original],
    );
  }

  /// `Bet: {amount} {currency}`
  String betDisplay(Object amount, Object currency) {
    return Intl.message(
      'Bet: $amount $currency',
      name: 'betDisplay',
      desc: '',
      args: [amount, currency],
    );
  }

  /// `Demo`
  String get demo {
    return Intl.message('Demo', name: 'demo', desc: '', args: []);
  }

  /// `exercise {current} of {total}`
  String exerciseOf(Object current, Object total) {
    return Intl.message(
      'exercise $current of $total',
      name: 'exerciseOf',
      desc: '',
      args: [current, total],
    );
  }

  /// `Pawn`
  String get chessPiecePawn {
    return Intl.message('Pawn', name: 'chessPiecePawn', desc: '', args: []);
  }

  /// `Knight`
  String get chessPieceKnight {
    return Intl.message('Knight', name: 'chessPieceKnight', desc: '', args: []);
  }

  /// `Bishop`
  String get chessPieceBishop {
    return Intl.message('Bishop', name: 'chessPieceBishop', desc: '', args: []);
  }

  /// `Rook`
  String get chessPieceRook {
    return Intl.message('Rook', name: 'chessPieceRook', desc: '', args: []);
  }

  /// `Queen`
  String get chessPieceQueen {
    return Intl.message('Queen', name: 'chessPieceQueen', desc: '', args: []);
  }

  /// `King`
  String get chessPieceKing {
    return Intl.message('King', name: 'chessPieceKing', desc: '', args: []);
  }

  /// `Basic Pawn Move`
  String get pawnStep1Title {
    return Intl.message(
      'Basic Pawn Move',
      name: 'pawnStep1Title',
      desc: '',
      args: [],
    );
  }

  /// `Pawns advance one square forward.`
  String get pawnStep1Desc {
    return Intl.message(
      'Pawns advance one square forward.',
      name: 'pawnStep1Desc',
      desc: '',
      args: [],
    );
  }

  /// `Two-Square Advance`
  String get pawnStep2Title {
    return Intl.message(
      'Two-Square Advance',
      name: 'pawnStep2Title',
      desc: '',
      args: [],
    );
  }

  /// `On their first move, a pawn can advance two squares.`
  String get pawnStep2Desc {
    return Intl.message(
      'On their first move, a pawn can advance two squares.',
      name: 'pawnStep2Desc',
      desc: '',
      args: [],
    );
  }

  /// `Diagonal Capture`
  String get pawnStep3Title {
    return Intl.message(
      'Diagonal Capture',
      name: 'pawnStep3Title',
      desc: '',
      args: [],
    );
  }

  /// `The pawn captures enemy pieces by moving diagonally.`
  String get pawnStep3Desc {
    return Intl.message(
      'The pawn captures enemy pieces by moving diagonally.',
      name: 'pawnStep3Desc',
      desc: '',
      args: [],
    );
  }

  /// `L-Shaped Move`
  String get knightStep1Title {
    return Intl.message(
      'L-Shaped Move',
      name: 'knightStep1Title',
      desc: '',
      args: [],
    );
  }

  /// `The knight moves in an L-shape.`
  String get knightStep1Desc {
    return Intl.message(
      'The knight moves in an L-shape.',
      name: 'knightStep1Desc',
      desc: '',
      args: [],
    );
  }

  /// `The Knight Jumps`
  String get knightStep2Title {
    return Intl.message(
      'The Knight Jumps',
      name: 'knightStep2Title',
      desc: '',
      args: [],
    );
  }

  /// `The knight can jump over other pieces.`
  String get knightStep2Desc {
    return Intl.message(
      'The knight can jump over other pieces.',
      name: 'knightStep2Desc',
      desc: '',
      args: [],
    );
  }

  /// `First Move`
  String get bishopStep1Title {
    return Intl.message(
      'First Move',
      name: 'bishopStep1Title',
      desc: '',
      args: [],
    );
  }

  /// `Move the pawn to start opening lines.`
  String get bishopStep1Desc {
    return Intl.message(
      'Move the pawn to start opening lines.',
      name: 'bishopStep1Desc',
      desc: '',
      args: [],
    );
  }

  /// `Bishop's Diagonal Move`
  String get bishopStep2Title {
    return Intl.message(
      'Bishop\'s Diagonal Move',
      name: 'bishopStep2Title',
      desc: '',
      args: [],
    );
  }

  /// `Now the bishop can move diagonally.`
  String get bishopStep2Desc {
    return Intl.message(
      'Now the bishop can move diagonally.',
      name: 'bishopStep2Desc',
      desc: '',
      args: [],
    );
  }

  /// `Vertical Move`
  String get rookStep1Title {
    return Intl.message(
      'Vertical Move',
      name: 'rookStep1Title',
      desc: '',
      args: [],
    );
  }

  /// `The rook moves in a straight line.`
  String get rookStep1Desc {
    return Intl.message(
      'The rook moves in a straight line.',
      name: 'rookStep1Desc',
      desc: '',
      args: [],
    );
  }

  /// `Horizontal Move`
  String get rookStep2Title {
    return Intl.message(
      'Horizontal Move',
      name: 'rookStep2Title',
      desc: '',
      args: [],
    );
  }

  /// `The rook can also move horizontally in a straight line.`
  String get rookStep2Desc {
    return Intl.message(
      'The rook can also move horizontally in a straight line.',
      name: 'rookStep2Desc',
      desc: '',
      args: [],
    );
  }

  /// `Clear the Path`
  String get queenStep1Title {
    return Intl.message(
      'Clear the Path',
      name: 'queenStep1Title',
      desc: '',
      args: [],
    );
  }

  /// `First move the pawn to open the queen's diagonal.`
  String get queenStep1Desc {
    return Intl.message(
      'First move the pawn to open the queen\'s diagonal.',
      name: 'queenStep1Desc',
      desc: '',
      args: [],
    );
  }

  /// `Queen's Power - Diagonal Move`
  String get queenStep2Title {
    return Intl.message(
      'Queen\'s Power - Diagonal Move',
      name: 'queenStep2Title',
      desc: '',
      args: [],
    );
  }

  /// `Now the queen can move freely diagonally.`
  String get queenStep2Desc {
    return Intl.message(
      'Now the queen can move freely diagonally.',
      name: 'queenStep2Desc',
      desc: '',
      args: [],
    );
  }

  /// `Queen's Horizontal Move`
  String get queenStep3Title {
    return Intl.message(
      'Queen\'s Horizontal Move',
      name: 'queenStep3Title',
      desc: '',
      args: [],
    );
  }

  /// `The queen moves like a rook in straight lines.`
  String get queenStep3Desc {
    return Intl.message(
      'The queen moves like a rook in straight lines.',
      name: 'queenStep3Desc',
      desc: '',
      args: [],
    );
  }

  /// `Queen Captures`
  String get queenStep4Title {
    return Intl.message(
      'Queen Captures',
      name: 'queenStep4Title',
      desc: '',
      args: [],
    );
  }

  /// `The queen can capture enemy pieces.`
  String get queenStep4Desc {
    return Intl.message(
      'The queen can capture enemy pieces.',
      name: 'queenStep4Desc',
      desc: '',
      args: [],
    );
  }

  /// `King in the Center`
  String get kingStep1Title {
    return Intl.message(
      'King in the Center',
      name: 'kingStep1Title',
      desc: '',
      args: [],
    );
  }

  /// `The king can move one square in any direction. Move it horizontally.`
  String get kingStep1Desc {
    return Intl.message(
      'The king can move one square in any direction. Move it horizontally.',
      name: 'kingStep1Desc',
      desc: '',
      args: [],
    );
  }

  /// `Vertical Move`
  String get kingStep2Title {
    return Intl.message(
      'Vertical Move',
      name: 'kingStep2Title',
      desc: '',
      args: [],
    );
  }

  /// `Now move the king vertically upward.`
  String get kingStep2Desc {
    return Intl.message(
      'Now move the king vertically upward.',
      name: 'kingStep2Desc',
      desc: '',
      args: [],
    );
  }

  /// `Diagonal Move`
  String get kingStep3Title {
    return Intl.message(
      'Diagonal Move',
      name: 'kingStep3Title',
      desc: '',
      args: [],
    );
  }

  /// `The king can also move diagonally. Move it diagonally.`
  String get kingStep3Desc {
    return Intl.message(
      'The king can also move diagonally. Move it diagonally.',
      name: 'kingStep3Desc',
      desc: '',
      args: [],
    );
  }

  /// `All Directions`
  String get kingStep4Title {
    return Intl.message(
      'All Directions',
      name: 'kingStep4Title',
      desc: '',
      args: [],
    );
  }

  /// `The king is versatile: horizontal, vertical and diagonal. Move it however you like!`
  String get kingStep4Desc {
    return Intl.message(
      'The king is versatile: horizontal, vertical and diagonal. Move it however you like!',
      name: 'kingStep4Desc',
      desc: '',
      args: [],
    );
  }
}

class AppLocalizationDelegate extends LocalizationsDelegate<S> {
  const AppLocalizationDelegate();

  List<Locale> get supportedLocales {
    return const <Locale>[
      Locale.fromSubtags(languageCode: 'en'),
      Locale.fromSubtags(languageCode: 'es'),
      Locale.fromSubtags(languageCode: 'fr'),
    ];
  }

  @override
  bool isSupported(Locale locale) => _isSupported(locale);
  @override
  Future<S> load(Locale locale) => S.load(locale);
  @override
  bool shouldReload(AppLocalizationDelegate old) => false;

  bool _isSupported(Locale locale) {
    for (var supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return true;
      }
    }
    return false;
  }
}
