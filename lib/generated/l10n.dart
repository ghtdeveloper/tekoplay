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
