import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:flutter_stockfish_plugin/stockfish.dart';
import 'package:flutter_stockfish_plugin/stockfish_state.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/models/multiplayer_game_match_chess.dart';
import '../../../core/service/auth_service.dart';
import '../../../core/service/firestore_service.dart';
import '../../../core/service/online_match_chess_game_service.dart';
import '../../../core/utils/bet_negotation_state.dart';
import '../../../core/utils/game_result.dart';
import '../../../core/utils/game_type.dart';
import '../../../generated/l10n.dart';
import '../../adds/BannerAdWidget.dart';
import '../../adds/InterstitialAdHelper.dart';


class OnlineChessScreen extends StatefulWidget {
  final String matchType;

  const OnlineChessScreen({super.key, required this.matchType});

  @override
  State<OnlineChessScreen> createState() => _OnlineChessScreenState();
}

class _OnlineChessScreenState extends State<OnlineChessScreen>
    with WidgetsBindingObserver {
  String? _lastMoveFrom;
  String? _lastMoveTo;
  String? _lastMovePromotion;
  late InterstitialAdHelper _interstitialHelper;
  OnlineGameState _gameState = OnlineGameState.timeSelection;
  int? _myRanking;
  int? _opponentRanking;
  int? _selectedBetAmount;
  int? _opponentBetAmount;
  bool _isBetNegotiating = false;
  bool _betAccepted = false;
  int? _userDiamonds;
  BetNegotiationState _betState = BetNegotiationState.selecting;
  String? _pendingGameId;
  final List<int> _betOptions = [10, 25, 50, 100, 250, 500, 1000,5000,10000];
  int? _userCoins;
  final List<int> _coinBetOptions = [50, 100, 250, 500, 1000, 2500, 5000];
  String? _lastMoveFromSquare;
  String? _lastMoveToSquare;
  bool _showLastMove = false;
  bool _lastMoveWasMine = false;

  int? _selectedTimeMinutes;
  final List<TimeOption> _timeOptions = [
    TimeOption(minutes: 1, display: '1 minuto'),
    TimeOption(minutes: 3, display: '3 minutos'),
    TimeOption(minutes: 5, display: '5 minutos'),
    TimeOption(minutes: 10, display: '10 minutos'),
  ];

  Timer? _matchmakingTimer;
  Timer? _gameTimer;
  int _matchmakingSeconds = 0;

  ChessBoardController controller = ChessBoardController();
  MultiplayerGameMatch? _currentGame;
  StreamSubscription<MultiplayerGameMatch?>? _gameSubscription;
  StreamSubscription<DocumentSnapshot>? _betNegotiationSubscription;

  User? get currentUser => FirebaseAuth.instance.currentUser;
  final FirestoreService _firestoreService = FirestoreService();
  bool _isMyTurn = false;
  PlayerColor? _myColor;
  String? _opponentName;
  String? _opponentPhotoUrl;
  bool _gameEnded = false;
  bool _waitingForMoveResponse = false;
  DateTime? _gameStartTime;

  int _myTimeSeconds = 0;
  int _opponentTimeSeconds = 0;
  Timer? _playerTimer;

  bool _isPlayingAgainstBot = false;
  Stockfish? _stockfish;
  bool _isStockfishReady = false;
  int _cpuMoveTime = 200;
  Timer? _botMoveTimer;
  final Random _random = Random();


  final List<Map<String, String>> _botProfiles = [
    {'name': 'Player1923', 'avatar': '🤖'},
    {'name': 'Player2323', 'avatar': '👾'},
    {'name': 'Player6303', 'avatar': '🎮'},
    {'name': 'Player8093', 'avatar': '👑'},
    {'name': 'Player7993', 'avatar': '♟️'},
    {'name': 'Player0967', 'avatar': '🧠'},
    {'name': 'Player1569', 'avatar': '👾'},
    {'name': 'Player5529', 'avatar': '👑'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeStockfish();
    _interstitialHelper = InterstitialAdHelper(showFrequency: 3);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
      _loadUserCurrency();
  }

  void _initializeStockfish() {
    _stockfish = Stockfish();

    _stockfish!.stdout.listen((output) {
      if (!_isPlayingAgainstBot) return;

      if (output.contains('bestmove ')) {
        final parts = output.split(' ');
        if (parts.length >= 2) {
          final best = parts[1];

          if (best == '0000' || best == '(none)') return;

          if (_shouldBotMakeMove()) {
            Future.delayed(const Duration(milliseconds: 200), () {
              if (mounted) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _applyBotMove(best);
                });
              }
            });
          } else {
            _makeBadMove();
          }

          setState(() {});
        }
      }
    });

    _stockfish!.state.addListener(() async {
      if (_stockfish!.state.value == StockfishState.ready &&
          !_isStockfishReady) {
        _isStockfishReady = true;
        await _setupStockfish();
      }
    });
  }

  Future<void> _loadUserCurrency() async {
    if (currentUser == null) return;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _userDiamonds = userData['diamonds'] ?? 0;
          _userCoins = userData['coins'] ?? 0;
        });
      }
    } catch (e) {
      print('Error loading user currency: $e');
      setState(() {
        _userDiamonds = 0;
        _userCoins = 0;
      });
    }
  }

  Future<void> _setupStockfish() async {
    _stockfish!.stdin = "uci";
    await Future.delayed(const Duration(milliseconds: 300));
    _stockfish!.stdin = "isready";
    await Future.delayed(const Duration(milliseconds: 300));

    if (widget.matchType == S.of(context).bet) {
      _cpuMoveTime = 150;
      _stockfish!.stdin = "setoption name Threads value 2";
      _stockfish!.stdin = "setoption name Hash value 64";
      _stockfish!.stdin = "setoption name Skill Level value 20";
    } else if (widget.matchType == S.of(context).fun) {
      _cpuMoveTime = 75;
      _stockfish!.stdin = "setoption name Threads value 1";
      _stockfish!.stdin = "setoption name Hash value 32";
      _stockfish!.stdin = "setoption name Skill Level value 10";
    } else {
      // Normal
      _cpuMoveTime = 100;
      _stockfish!.stdin = "setoption name Threads value 1";
      _stockfish!.stdin = "setoption name Hash value 32";
      _stockfish!.stdin = "setoption name Skill Level value 12";
    }
  }

  bool _shouldBotMakeMove() {
    if (widget.matchType == S.of(context).bet) {
      return _random.nextInt(100) < 99;
    } else if (widget.matchType == S.of(context).fun) {
      return _random.nextInt(100) < 55;
    }
    return _random.nextInt(100) < 75;
  }

  void _makeBadMove() {
    _botMoveTimer = Timer(Duration(milliseconds: 500), () {
      if (!_gameEnded && !_isMyTurn && _isPlayingAgainstBot) {
        final fen = controller.getFen();
        _stockfish!.stdin = "position fen $fen";
        _stockfish!.stdin = "go movetime 10";
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanupTimers();
    _gameSubscription?.cancel();
    _botMoveTimer?.cancel();
    _betNegotiationSubscription?.cancel();
    if (_isStockfishReady && _stockfish != null) {
      _stockfish!.stdin = "quit";
    }
    _stockfish?.dispose();
    _interstitialHelper.dispose();
    super.dispose();
  }

  void _cleanupTimers() {
    _matchmakingTimer?.cancel();
    _gameTimer?.cancel();
    _playerTimer?.cancel();
    _botMoveTimer?.cancel();
  }

  Widget _buildTimeSelectionScreen() {
    return Scaffold(
      backgroundColor: const ui.Color(0xFFEC7A34),
      appBar: AppBar(
        backgroundColor: const ui.Color(0xFFEC7A34),
        elevation: 0,
        title: Text(
          S.of(context).playOnline,
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildTimeSelection(),
                      if (_selectedTimeMinutes != null)
                        _buildBetSelection(),
                    ],
                  ),
                ),
              ),

              _buildStartGameButton(),
              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeSelection() {
    return Column(
      children: [
        Text(
          S.of(context).selectGameTime,
          style: TextStyle(
            color: Colors.white,
            fontSize: 22, // Reducir un poco el tamaño
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 20),
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: _timeOptions.length,
          itemBuilder: (context, index) {
            final option = _timeOptions[index];
            final isSelected = _selectedTimeMinutes == option.minutes;

            return Container(
              margin: EdgeInsets.only(bottom: 8),
              child: Material(
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() {
                    _selectedTimeMinutes = option.minutes;
                    _selectedBetAmount = null;
                  }),
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: isSelected ? Colors.green[100] : Colors.white,
                      border: Border.all(
                        color: isSelected ? Colors.green : Colors.grey[300]!,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: isSelected ? Colors.green : Colors.grey,
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            option.display,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? Colors.green[800]
                                  : Colors.black87,
                            ),
                          ),
                        ),
                        if (option.minutes != null)
                          Icon(
                            Icons.timer,
                            color: isSelected ? Colors.green : Colors.grey,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBetSelection() {
    final bool useDiamonds = widget.matchType == S.of(context).bet;
    final currentBalance = useDiamonds ? _userDiamonds : _userCoins;
    final currencyIcon = useDiamonds ? Icons.diamond : Icons.monetization_on;
    final currencyColor = useDiamonds ? Colors.amber : Colors.blue;
    final betOptions = useDiamonds ? _betOptions : _coinBetOptions;

    return Column(
      children: [
        SizedBox(height: 16), // Reducir espacio
        Container(
          padding: EdgeInsets.all(14), // Reducir padding
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: .3)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(currencyIcon, color: currencyColor, size: 24),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      S.of(context).selectYourBet,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6),
              if (currentBalance != null)
                Text(
                  '${_getCurrencyName()} ${S.of(context).available}: $currentBalance',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: betOptions.map((amount) {
                  final isSelected = _selectedBetAmount == amount;
                  final canAfford = _getCurrentBalance() != null &&
                      _getCurrentBalance()! >= amount;

                  return GestureDetector(
                    onTap: canAfford ? () => setState(() => _selectedBetAmount = amount) : null,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? currencyColor
                            : (canAfford ? Colors.white : Colors.grey[400]),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected
                              ? currencyColor.withValues(alpha: 0.8)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            currencyIcon,
                            color: isSelected
                                ? Colors.white
                                : (canAfford ? currencyColor : Colors.grey[600]),
                            size: 14,
                          ),
                          SizedBox(width: 3),
                          Text(
                            amount.toString(),
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : (canAfford ? Colors.black : Colors.grey[600]),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStartGameButton() {
    bool canStart = _selectedTimeMinutes != null;

    if (widget.matchType == S.of(context).bet) {
      canStart = canStart && _selectedBetAmount != null;
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: canStart ? _startMatchmaking : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          S.of(context).searchGame,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _startMatchmaking() async {
    if (currentUser == null) return;
    if (widget.matchType == S.of(context).bet && !_canAffordBet()) {
      _showError('${S.of(context).notEnough} ${_getCurrencyName()} ${S.of(context).forThisBet}');
      return;
    }

    setState(() {
      _gameState = OnlineGameState.searching;
      _matchmakingSeconds = 0;
    });

    final userRanking = await _getUserRanking();
    String? gameId;

    _matchmakingTimer = Timer.periodic(Duration(seconds: 1), (timer) async {
      setState(() => _matchmakingSeconds++);

      if (_matchmakingSeconds % 5 == 0 && !_isPlayingAgainstBot) {
        try {
          final waitingGames = await OnlineMatchmakingChessService()
              .findWaitingGamesProgressive(
            gameType: 'Ajedrez',
            userRanking: userRanking,
            timeMinutes: _selectedTimeMinutes,
            searchTimeSeconds: _matchmakingSeconds,
          );

          if (waitingGames.isNotEmpty) {
            final game = waitingGames.first;
            final success = await MultiplayerGameService().joinGame(
              game.id,
              currentUser!.uid,
              currentUser!.displayName ?? 'Usuario',
              currentUser!.photoURL,
            );

            if (success) {
              gameId = game.id;
              timer.cancel();
              _startGameSubscription(gameId!);
              return;
            }
          }
        } catch (e) {
          print('Error durante la búsqueda progresiva: $e');
        }
      }

      if (_matchmakingSeconds == 1) {
        try {
          gameId = await _findOrCreateGame(userRanking);
          if (gameId != null && !_isPlayingAgainstBot) {
            timer.cancel();
            _startGameSubscription(gameId!);
            return;
          }
        } catch (e) {
          print('Error creando partida inicial: $e');
        }
      }

      const int maxWaitTime = 45;

      if (_matchmakingSeconds >= maxWaitTime && !_isPlayingAgainstBot) {
        timer.cancel();
        _startBotGame();
      }
    });
  }

  void _startBotGame() {
    setState(() {
      _isPlayingAgainstBot = true;
      _gameState = OnlineGameState.playing;
      final botProfile = _botProfiles[_random.nextInt(_botProfiles.length)];
      _opponentName = botProfile['name'];
      _opponentPhotoUrl = null;
      _myColor = _random.nextBool() ? PlayerColor.white : PlayerColor.black;
      controller.resetBoard();
      _gameStartTime = DateTime.now();

      if (widget.matchType == S.of(context).bet && _selectedBetAmount != null) {
        _opponentBetAmount = _selectedBetAmount;
        _betAccepted = true;
        print('Rival acepta apuesta de $_selectedBetAmount ${_getCurrencyName()}');
      }

      _loadMyRankingAndGenerateBotRanking();

      if (_selectedTimeMinutes != null) {
        _myTimeSeconds = _selectedTimeMinutes! * 60;
        _opponentTimeSeconds = _selectedTimeMinutes! * 60;
        _startPlayerTimer();
      }

      _isMyTurn = _myColor == PlayerColor.white;

      if (_myColor == PlayerColor.black) {
        _makeBotMove();
      }
    });

    if (widget.matchType == S.of(context).bet && _selectedBetAmount != null) {
      _showRivalFoundDialog();
    }
  }


  void _showRivalFoundDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.green,
            ),
            SizedBox(width: 8),
            Text(S.of(context).opponentFound),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                children: [
                  Icon(Icons.person, size: 48, color: Colors.green),
                  SizedBox(height: 12),
                  Text(
                    '$_opponentName ${S.of(context).acceptsYourBet}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: widget.matchType == S.of(context).bet ? Colors.amber : Colors.blue,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.matchType == S.of(context).bet ? Icons.diamond : Icons.monetization_on,
                          color: Colors.white,
                          size: 18,
                        ),
                        SizedBox(width: 6),
                        Text(
                          '${_selectedBetAmount} ${_getCurrencyName()}',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Text(
              '¡Que comience la partida!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.green,
              backgroundColor: Colors.green[50],
            ),
            child: Text('¡Jugar!'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadMyRankingAndGenerateBotRanking() async {
    try {
      final myGameStats = await AuthService().getCurrentUserGameStats(
        GameTypeModel.chess,
      );
      _myRanking = myGameStats?.points ?? 1000;

      if (widget.matchType == S.of(context).bet) {
        _opponentRanking = (_myRanking! + _random.nextInt(200) - 50).clamp(
          800,
          2400,
        );
      } else if (widget.matchType == S.of(context).fun) {
        _opponentRanking = (_myRanking! + _random.nextInt(400) - 300).clamp(
          600,
          1800,
        );
      } else {
        _opponentRanking = (_myRanking! + _random.nextInt(300) - 150).clamp(
          700,
          2200,
        );
      }

      setState(() {});
    } catch (e) {
      print('Error cargando mi ranking: $e');
      _myRanking = 1000;
      _opponentRanking = 1000 + _random.nextInt(400) - 200;
      setState(() {});
    }
  }

  void _makeBotMove() {
    if (!_isStockfishReady || _gameEnded || !_isPlayingAgainstBot) return;

    _botMoveTimer = Timer(
      Duration(milliseconds: 500 + _random.nextInt(200)),
      () {
        if (!_gameEnded && !_isMyTurn) {
          final fen = controller.getFen();
          _stockfish!.stdin = "position fen $fen";
          _stockfish!.stdin = "go movetime $_cpuMoveTime";
        }
      },
    );
  }

  void _applyBotMove(String uci) {
    if (_gameEnded || _isMyTurn || !_isPlayingAgainstBot) return;

    String from, to, promo = '';

    if (uci.length == 4) {
      from = uci.substring(0, 2);
      to = uci.substring(2, 4);
      controller.makeMove(from: from, to: to);
    } else if (uci.length == 5) {
      from = uci.substring(0, 2);
      to = uci.substring(2, 4);
      promo = uci.substring(4).toUpperCase();
      controller.makeMoveWithPromotion(
        from: from,
        to: to,
        pieceToPromoteTo: promo,
      );
    } else {
      return;
    }
    setState(() {
      _isMyTurn = true;
      _lastMoveFromSquare = from;
      _lastMoveToSquare = to;
      _showLastMove = true;
    });

    _checkGameEnd();
  }

  Future<int> _getUserRanking() async {
    final gameStats = await AuthService().getCurrentUserGameStats(
      GameTypeModel.chess,
    );
    return gameStats?.points ?? 1000;
  }

  Future<String?> _findOrCreateGame(int userRanking) async {
    try {
      final waitingGames = await OnlineMatchmakingChessService()
          .findWaitingGames(
            gameType: 'Ajedrez',
            userRanking: userRanking,
            timeMinutes: _selectedTimeMinutes,
            betAmount: _selectedBetAmount,
          );

      if (waitingGames.isNotEmpty) {
        final game = waitingGames.first;

        if (widget.matchType == S.of(context).bet &&
            game.betAmount != _selectedBetAmount) {
          _showBetNegotiation(game);
          return null;
        }

        final success = await MultiplayerGameService().joinGame(
          game.id,
          currentUser!.uid,
          currentUser!.displayName ?? 'Usuario',
          currentUser!.photoURL,
        );

        return success ? game.id : null;
      } else {
        return await OnlineMatchmakingChessService().createOnlineGame(
          hostId: currentUser!.uid,
          hostName: currentUser!.displayName ?? 'Usuario',
          hostPhotoUrl: currentUser!.photoURL,
          gameType: 'Ajedrez',
          timeMinutes: _selectedTimeMinutes,
          hostRanking: userRanking,
          betAmount: _selectedBetAmount,
        );
      }
    } catch (e) {
      print('Error in matchmaking: $e');
      return null;
    }
  }

  void _showBetNegotiation(MultiplayerGameMatch game) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.diamond, color: Colors.amber),
                SizedBox(width: 8),
                Text(S.of(context).betNegotiation),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${game.hostName} ${S.of(context).hasBet}'),
                Container(
                  padding: EdgeInsets.all(12),
                  margin: EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.diamond, color: Colors.amber),
                      SizedBox(width: 8),
                      Text(
                        '${game.betAmount} ${_getCurrencyName()}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Text(S.of(context).yourCurrentBet),
                Container(
                  padding: EdgeInsets.all(12),
                  margin: EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.diamond, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        '${game.betAmount} ${_getCurrencyName()}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(S.of(context).cancel),
              ),
              TextButton(
                onPressed: () {
                  setState(() => _selectedBetAmount = game.betAmount);
                  Navigator.of(context).pop();
                  _joinGameWithBet(game);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.green),
                child: Text(S.of(context).acceptTheirBet),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _showCounterOfferDialog(game);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.orange),
                child: Text(S.of(context).counteroffer),
              ),
            ],
          ),
    );
  }

  void _showCounterOfferDialog(MultiplayerGameMatch game) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(S.of(context).makeCounteroffer),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(S.of(context).selectYourCounteroffer),
                SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      _betOptions.map((amount) {
                        final canAfford = _getCurrentBalance() != null && _getCurrentBalance()! >= amount;

                        return GestureDetector(
                          onTap:
                              canAfford
                                  ? () {
                                    Navigator.of(context).pop();
                                    _sendCounterOffer(game, amount);
                                  }
                                  : null,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  canAfford ? Colors.amber : Colors.grey[300],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.diamond,
                                  color:
                                      canAfford
                                          ? Colors.white
                                          : Colors.grey[600],
                                  size: 16,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  amount.toString(),
                                  style: TextStyle(
                                    color:
                                        canAfford
                                            ? Colors.white
                                            : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancelar'),
              ),
            ],
          ),
    );
  }

  Future<void> _joinGameWithBet(MultiplayerGameMatch game) async {
    final success = await MultiplayerGameService().joinGame(
      game.id,
      currentUser!.uid,
      currentUser!.displayName ?? 'Usuario',
      currentUser!.photoURL,
    );

    if (success) {
      _startGameSubscription(game.id);
    }
  }

  Future<void> _sendCounterOffer(
    MultiplayerGameMatch game,
    int newAmount,
  ) async {
    try {
      if (_userDiamonds != null && _userDiamonds! < newAmount) {
        _showError('No tienes suficientes ${_getCurrencyName()} para esta apuesta');
        setState(() => _gameState = OnlineGameState.timeSelection);
        return;
      }

      await FirebaseFirestore.instance
          .collection('multiplayer_games')
          .doc(game.id)
          .update({
            'betNegotiation': {
              'status': 'counter_offer',
              'counterOfferBy': currentUser!.uid,
              'counterOfferName': currentUser!.displayName ?? 'Usuario',
              'originalAmount': game.betAmount,
              'counterAmount': newAmount,
              'timestamp': FieldValue.serverTimestamp(),
            },
            'gameSettings.betAmount': newAmount,
            'betAmount': newAmount,
            'lastUpdated': FieldValue.serverTimestamp(),
          });

      await _sendCounterOfferNotification(
        game.hostId,
        game.hostName,
        newAmount,
        game.betAmount!,
      );

      setState(() {
        _selectedBetAmount = newAmount;
        _gameState = OnlineGameState.betNegotiation;
        _pendingGameId = game.id;
        _betState = BetNegotiationState.waiting;
      });

      _startBetNegotiationListener(game.id);
    } catch (e) {
      print('Error enviando contraoferta: $e');
      _showError('Error enviando contraoferta');
      setState(() => _gameState = OnlineGameState.timeSelection);
    }
  }

  Future<void> _sendCounterOfferNotification(
    String hostId,
    String? hostName,
    int counterAmount,
    int originalAmount,
  ) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': hostId,
        'type': 'bet_counter_offer',
        'title': 'Contraoferta de apuesta',
        'message':
            '${currentUser!.displayName ?? 'Un jugador'} ha hecho una contraoferta de $counterAmount diamantes (original: $originalAmount)',
        'data': {
          'gameId': _pendingGameId,
          'counterOfferBy': currentUser!.uid,
          'counterOfferName': currentUser!.displayName ?? 'Usuario',
          'counterAmount': counterAmount,
          'originalAmount': originalAmount,
        },
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error enviando notificación: $e');
    }
  }


  void _startBetNegotiationListener(String gameId) {
    _betNegotiationSubscription?.cancel();

    _betNegotiationSubscription = FirebaseFirestore.instance
        .collection('multiplayer_games')
        .doc(gameId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) return;

      final gameData = snapshot.data() as Map<String, dynamic>;
      final betNegotiation = gameData['betNegotiation'] as Map<String, dynamic>?;

      if (betNegotiation != null) {
        final status = betNegotiation['status'] as String?;

        if (status == 'accepted') {
          _betNegotiationSubscription?.cancel();
          Navigator.of(context).pop();
          _handleCounterOfferAccepted(MultiplayerGameMatch.fromFirestore(snapshot));
        } else if (status == 'rejected') {
          _betNegotiationSubscription?.cancel();
          Navigator.of(context).pop();
          _handleCounterOfferRejected();
        } else if (status == 'new_counter_offer' &&
            betNegotiation['counterOfferBy'] != currentUser!.uid) {
          _betNegotiationSubscription?.cancel();
          Navigator.of(context).pop();
          final newAmount = betNegotiation['counterAmount'] as int;
          _handleNewCounterOffer(newAmount, betNegotiation);
        }
      }
    });
  }

  Future<void> _handleCounterOfferAccepted(MultiplayerGameMatch game) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text(S.of(context).counterofferAccepted),
              ],
            ),
            content: Text(
              '${game.hostName}${S.of(context).acceptedYourCounterofferOf} $_selectedBetAmount ${_getCurrencyName()}.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _joinGameWithBet(game);
                },
                child: Text(S.of(context).play),
              ),
            ],
          ),
    );
  }

  void _handleCounterOfferRejected() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.cancel, color: Colors.red),
                SizedBox(width: 8),
                Text(S.of(context).counterofferRejected),
              ],
            ),
            content: Text(S.of(context).opponentRejectedCounteroffer),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() => _gameState = OnlineGameState.timeSelection);
                },
                child: Text(S.of(context).backTo),
              ),
            ],
          ),
    );
  }

  void _handleNewCounterOffer(int newAmount, Map<String, dynamic> negotiationData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(S.of(context).newCounteroffer),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${negotiationData['counterOfferName']} ${S.of(context).madeNewCounteroffer}'),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.diamond, color: Colors.amber),
                  SizedBox(width: 8),
                  Text(
                    '$newAmount ${_getCurrencyName()}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _rejectCounterOffer();
            },
            child: Text(S.of(context).reject),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _acceptCounterOffer(newAmount);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            child: Text(S.of(context).accept),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showSimpleCounterOfferDialog();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: Text(S.of(context).counteroffer),
          ),
        ],
      ),
    );
  }

  void _showSimpleCounterOfferDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.of(context).makeCounteroffer),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(S.of(context).selectYourCounteroffer),
            SizedBox(height: 16),
            Container(
              constraints: BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _betOptions.map((amount) {
                    final canAfford = _getCurrentBalance() != null && _getCurrentBalance()! >= amount;

                    return GestureDetector(
                      onTap: canAfford ? () {
                        Navigator.of(context).pop();
                        _sendSimpleCounterOffer(amount);
                      } : null,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: canAfford ? Colors.amber : Colors.grey[300],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.diamond,
                              color: canAfford ? Colors.white : Colors.grey[600],
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Text(
                              amount.toString(),
                              style: TextStyle(
                                color: canAfford ? Colors.white : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() => _gameState = OnlineGameState.timeSelection);
            },
            child: Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendSimpleCounterOffer(int newAmount) async {
    try {
      if (_userDiamonds != null && _userDiamonds! < newAmount) {
        _showError('${S.of(context).notEnough} ${_getCurrencyName()}${S.of(context).forThisBet}');
        setState(() => _gameState = OnlineGameState.timeSelection);
        return;
      }

      await FirebaseFirestore.instance
          .collection('multiplayer_games')
          .doc(_pendingGameId!)
          .update({
        'betNegotiation': {
          'status': 'new_counter_offer',
          'counterOfferBy': currentUser!.uid,
          'counterOfferName': currentUser!.displayName ?? 'Usuario',
          'counterAmount': newAmount,
          'timestamp': FieldValue.serverTimestamp(),
        },
        'betAmount': newAmount,
        'gameSettings.betAmount': newAmount,
      });

      setState(() {
        _selectedBetAmount = newAmount;
        _gameState = OnlineGameState.betNegotiation;
      });

    } catch (e) {
      print('Error enviando contraoferta: $e');
      _showError('Error enviando contraoferta');
      setState(() => _gameState = OnlineGameState.timeSelection);
    }
  }



  Future<void> _acceptCounterOffer(int amount) async {
    try {
      await FirebaseFirestore.instance
          .collection('multiplayer_games')
          .doc(_pendingGameId!)
          .update({
        'betNegotiation.status': 'accepted',
        'betNegotiation.acceptedBy': currentUser!.uid,
        'betNegotiation.acceptedAt': FieldValue.serverTimestamp(),
        'betAmount': amount,
        'gameSettings.betAmount': amount,
      });

      setState(() => _selectedBetAmount = amount);

    } catch (e) {
      print('Error aceptando contraoferta: $e');
      _showError(S.of(context).errorAcceptingCounteroffer);
    }
  }

  Future<void> _rejectCounterOffer() async {
    try {
      await FirebaseFirestore.instance
          .collection('multiplayer_games')
          .doc(_pendingGameId!)
          .update({
            'betNegotiation.status': 'rejected',
            'betNegotiation.rejectedBy': currentUser!.uid,
            'betNegotiation.rejectedAt': FieldValue.serverTimestamp(),
          });

      setState(() => _gameState = OnlineGameState.timeSelection);
    } catch (e) {
      print('Error rechazando contraoferta: $e');
      _showError(S.of(context).errorRejectingCounteroffer);
    }
  }

  Future<void> _updateUserDiamonds(int change) async {
    if (currentUser == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .update({'diamonds': FieldValue.increment(change)});
      setState(() {
        _userDiamonds = (_userDiamonds ?? 0) + change;
      });
    } catch (e) {
      print('Error actualizando diamantes: $e');
    }
  }

  void _startGameSubscription(String gameId) {
    _gameSubscription = MultiplayerGameService()
        .getGameStream(gameId)
        .listen(
          (game) {
            if (game == null) {
              _showErrorAndReturn(S.of(context).gameNotFound);
              return;
            }
            _handleGameUpdate(game);
          },
          onError: (error) {
            print('Error in game stream: $error');
            _showErrorAndReturn(S.of(context).connectionError);
          },
        );
  }

  void _handleGameUpdate(MultiplayerGameMatch game) {
    final previousGame = _currentGame;
    _currentGame = game;

    if (previousGame?.status != 'active' && game.status == 'active') {
      _setupGame(game);
      setState(() => _gameState = OnlineGameState.playing);
    }

    final wasMyTurn = _isMyTurn;
    _isMyTurn = game.isPlayerTurn(currentUser!.uid);
    _waitingForMoveResponse = false;
    bool shouldSync = false;
    bool isOpponentMove = false;

    if (previousGame == null) {
      shouldSync = true;
    } else if (!_waitingForMoveResponse && previousGame.currentFen != game.currentFen) {
      shouldSync = true;
      isOpponentMove = _isMyTurn && !wasMyTurn;
    }

    if (shouldSync && !_waitingForMoveResponse) {
      _syncGameState();

      if (isOpponentMove && game.lastMoveFrom != null && game.lastMoveTo != null) {
        setState(() {
          // Reemplazar con el movimiento del oponente
          _lastMoveFromSquare = game.lastMoveFrom;
          _lastMoveToSquare = game.lastMoveTo;
          _showLastMove = true;
          _lastMoveWasMine = false;
        });
      }
    }

    if (!_gameEnded && game.isFinished) {
      _gameEnded = true;
      _handleGameEnd(game);
    }

    setState(() {});
  }


  Widget _buildLastMoveOverlay() {
    if (!_showLastMove || _lastMoveFromSquare == null || _lastMoveToSquare == null) {
      return SizedBox.shrink();
    }

    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: LastMovePainter(
            fromSquare: _lastMoveFromSquare!,
            toSquare: _lastMoveToSquare!,
            boardOrientation: _myColor ?? PlayerColor.white,
            isMyMove: _lastMoveWasMine,
          ),
        ),
      ),
    );
  }


  void _setupGame(MultiplayerGameMatch game) {
    final isHost = game.hostId == currentUser!.uid;
    _myColor = isHost ? PlayerColor.white : PlayerColor.black;
    _opponentName = game.getOpponentName(currentUser!.uid);
    _opponentPhotoUrl = isHost ? game.guestPhotoUrl : game.hostPhotoUrl;
    controller.loadFen(game.currentFen);
    _gameStartTime = DateTime.now();

    _loadPlayerRankings(game);

    if (_selectedTimeMinutes != null) {
      _myTimeSeconds = _selectedTimeMinutes! * 60;
      _opponentTimeSeconds = _selectedTimeMinutes! * 60;
      _startPlayerTimer();
    }
  }

  Future<void> _loadPlayerRankings(MultiplayerGameMatch game) async {
    try {
      final myGameStats = await AuthService().getCurrentUserGameStats(
        GameTypeModel.chess,
      );
      _myRanking = myGameStats?.points ?? 1000;

      final opponentId = game.getOpponentId(currentUser!.uid);
      final opponentStats = await FirestoreService().getUserGameStats(
        opponentId!,
        GameTypeModel.chess,
      );
      _opponentRanking = opponentStats?.points ?? 1000;

      setState(() {});
    } catch (e) {
      print('Error cargando rankings: $e');
      _myRanking = 1000;
      _opponentRanking = 1000;
      setState(() {});
    }
  }

  void _startPlayerTimer() {
    _playerTimer?.cancel();

    if (_selectedTimeMinutes == null) return;

    _playerTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_gameEnded) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_isMyTurn) {
          _myTimeSeconds--;
          if (_myTimeSeconds <= 0) {
            _timeOut(isMyTimeout: true);
          }
        } else {
          _opponentTimeSeconds--;
          if (_opponentTimeSeconds <= 0) {
            _timeOut(isMyTimeout: false);
          }
        }
      });
    });
  }

  void _timeOut({required bool isMyTimeout}) {
    if (_gameEnded) return;

    _gameEnded = true;
    _playerTimer?.cancel();

    _showTimeoutDialog(isMyTimeout: isMyTimeout);

    final result = isMyTimeout ? GameResultModel.loss : GameResultModel.win;
    _recordGameResult(result);

    if (!_isPlayingAgainstBot && _currentGame != null) {
      final winnerId =
          isMyTimeout
              ? _currentGame!.getOpponentId(currentUser!.uid)
              : currentUser!.uid;

      MultiplayerGameService().finishGame(
        gameId: _currentGame!.id,
        result: result,
        winnerId: winnerId,
        reason: 'timeout',
      );
    }

    _interstitialHelper.forceShowAd(
      onComplete: () {
        _showTimeoutDialog(isMyTimeout: isMyTimeout);
      },
    );
  }

  void _showTimeoutDialog({required bool isMyTimeout}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.timer_off,
                  color: isMyTimeout ? Colors.red : Colors.green,
                  size: 28,
                ),
                SizedBox(width: 12),
                Text(
                  isMyTimeout ? S.of(context).timeOut : S.of(context).youWon,
                  style: TextStyle(
                    color: isMyTimeout ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isMyTimeout ? Colors.red[50] : Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          isMyTimeout ? Colors.red[200]! : Colors.green[200]!,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        isMyTimeout ? Icons.timer_off : Icons.emoji_events,
                        size: 48,
                        color: isMyTimeout ? Colors.red : Colors.green,
                      ),
                      SizedBox(height: 12),
                      Text(
                        isMyTimeout
                            ? S.of(context).youLostByTimeout
                            : S.of(context).opponentLostByTimeout,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color:
                              isMyTimeout ? Colors.red[800] : Colors.green[800],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        isMyTimeout
                            ? S.of(context).timeRunOutMessage
                            : S.of(context).opponentTimeRunOutMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                child: Text(S.of(context).exit),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _startNewGame();
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.green,
                  backgroundColor: Colors.green[50],
                ),
                child: Text(S.of(context).playAgain),
              ),
            ],
          ),
    );
  }

  void _syncGameState() {
    if (_currentGame == null || _waitingForMoveResponse) return;

    try {
      final currentFen = controller.getFen();
      final targetFen = _currentGame!.currentFen;

      if (currentFen != targetFen) {
        controller.loadFen(targetFen);
      }
    } catch (e) {
      print('Error syncing game state: $e');
    }
  }

  void _playerMoved({String? from, String? to, String? promotion}) async {
    if (from != null && to != null) {
      setState(() {
        _lastMoveFromSquare = from;
        _lastMoveToSquare = to;
        _showLastMove = true;
        _lastMoveWasMine = true;
      });
    }

    if (_isPlayingAgainstBot) {
      _handleBotGameMove();
    } else {
      await _handleOnlineGameMove(from: from, to: to, promotion: promotion);
    }
  }

  void _handleBotGameMove() {
    if (!_isMyTurn || _gameEnded || _waitingForMoveResponse) return;

    setState(() {
      _isMyTurn = false;
    });

    _checkGameEnd();

    if (!_gameEnded) {
      _makeBotMove();
    }
  }

  Future<void> _handleOnlineGameMove({
    String? from,
    String? to,
    String? promotion,
  }) async {
    if (!_isMyTurn || _gameEnded || _waitingForMoveResponse || _currentGame == null) {
      return;
    }

    _waitingForMoveResponse = true;
    final savedFromSquare = _lastMoveFromSquare;
    final savedToSquare = _lastMoveToSquare;
    final savedShowLastMove = _showLastMove;

    try {
      final newFen = controller.getFen();

      String moveFrom = from ?? _lastMoveFrom ?? "xx";
      String moveTo = to ?? _lastMoveTo ?? "xx";
      String? movePromotion = promotion ?? _lastMovePromotion;

      String moveNotation = movePromotion != null
          ? '$moveFrom$moveTo$movePromotion'
          : '$moveFrom$moveTo';

      final success = await MultiplayerGameService().makeMove(
        gameId: _currentGame!.id,
        playerId: currentUser!.uid,
        from: moveFrom,
        to: moveTo,
        promotion: movePromotion,
        newFen: newFen,
        moveNotation: moveNotation,
      );

      if (!success) {
        _syncGameState();
        _showError(S.of(context).errorSendMove);
        setState(() {
          _showLastMove = false;
          _lastMoveFromSquare = null;
          _lastMoveToSquare = null;
        });
      } else {
        _lastMoveFrom = moveFrom;
        _lastMoveTo = moveTo;
        _lastMovePromotion = movePromotion;

        setState(() {
          _lastMoveFromSquare = savedFromSquare;
          _lastMoveToSquare = savedToSquare;
          _showLastMove = savedShowLastMove;
          _lastMoveWasMine = true;
        });

        _checkForGameEnd(newFen);
      }
    } catch (e) {
      print('Error in _handleOnlineGameMove: $e');
      _syncGameState();
      _showError(S.of(context).errorMakeMove);
      setState(() {
        _showLastMove = false;
      });
    } finally {
      _waitingForMoveResponse = false;
    }
  }

  void _checkGameEnd() {
    if (_gameEnded) return;

    bool isCheckMate = controller.isCheckMate();
    bool isDraw = controller.isDraw();
    bool isStaleMate = controller.isStaleMate();
    bool isThreefoldRepetition = controller.isThreefoldRepetition();
    bool isInsufficientMaterial = controller.isInsufficientMaterial();

    if (isCheckMate) {
      _gameEnded = true;
      final isWhiteTurn = controller.getFen().split(' ')[1] == 'w';
      final playerWon =
          (_myColor == PlayerColor.white && !isWhiteTurn) ||
          (_myColor == PlayerColor.black && isWhiteTurn);

      if (_isPlayingAgainstBot) {
        _recordGameResult(
          playerWon ? GameResultModel.win : GameResultModel.loss,
        );

        _interstitialHelper.showAdIfReady(
          onComplete: () {
            _showGameEndDialog(
              playerWon
                  ? '${S.of(context).youWonCheckMate}\n${S.of(context).youWonCheckMate}'
                  : '${S.of(context).cpuWonCheckMate}\n${S.of(context).youWonCheckMate}',
            );
          },
        );
      }
    } else if (isDraw ||
        isStaleMate ||
        isThreefoldRepetition ||
        isInsufficientMaterial) {
      _gameEnded = true;
      String message =
          isDraw
              ? S.of(context).drawMsg
              : isStaleMate
              ? S.of(context).drawByStalemate
              : isThreefoldRepetition
              ? S.of(context).tieByReply
              : S.of(context).tieByInsufficient;

      if (_isPlayingAgainstBot) {
        _recordGameResult(GameResultModel.draw);

        _interstitialHelper.forceShowAd(
          onComplete: () {
            _showGameEndDialog(message);
          },
        );
      }
    }
  }

  void _checkForGameEnd(String fen) {
    if (_gameEnded) return;

    bool isCheckMate = controller.isCheckMate();
    bool isDraw = controller.isDraw();
    bool isStaleMate = controller.isStaleMate();

    GameResultModel? result;
    String? winnerId;

    if (isCheckMate) {
      result = GameResultModel.win;
      winnerId = currentUser!.uid;
    } else if (isDraw || isStaleMate) {
      result = GameResultModel.draw;
    }

    if (result != null) {
      _finishGame(result, winnerId);
    }
  }

  Future<void> _finishGame(GameResultModel result, String? winnerId) async {
    if (_gameEnded) return;

    _gameEnded = true;
    _playerTimer?.cancel();

    try {
      await MultiplayerGameService().finishGame(
        gameId: _currentGame!.id,
        result: result,
        winnerId: winnerId,
      );
    } catch (e) {
      print('Error finishing game: $e');
    }
  }

  void _handleGameEnd(MultiplayerGameMatch game) {
    _playerTimer?.cancel();

    String message;
    GameResultModel gameResult;
    bool opponentAbandoned = false;
    bool isTimeout = false;

    if (game.reason == 'timeout') {
      isTimeout = true;
      return;
    } else if (game.reason == 'abandoned' &&
        game.winnerId == currentUser!.uid) {
      opponentAbandoned = true;
      message = S.of(context).opponentAbandoned;
      gameResult = GameResultModel.win;
    } else if (game.result == GameResultModel.draw) {
      message = S.of(context).drawMsg;
      gameResult = GameResultModel.draw;
    } else if (game.winnerId == currentUser!.uid) {
      message = S.of(context).youWon;
      gameResult = GameResultModel.win;
    } else {
      message = S.of(context).youLost;
      gameResult = GameResultModel.loss;
    }

    _recordGameResult(gameResult);

    _interstitialHelper.forceShowAd(
      onComplete: () {
        if (opponentAbandoned) {
          _showOpponentAbandonedDialog();
        } else {
          _showGameEndDialog(message);
        }
      },
    );
  }

  Future<void> _recordGameResult(GameResultModel result) async {
    if (currentUser == null || _gameStartTime == null) return;

    try {
      final gameDuration = DateTime.now().difference(_gameStartTime!).inMinutes;
      int pointsEarned = 0;
      int currencyChange = 0;
      bool isApuesta = widget.matchType == S.of(context).bet;
      bool useDiamonds = isApuesta;

      switch (result) {
        case GameResultModel.win:
          pointsEarned = 20;
          if (_selectedBetAmount != null) {
            if (_isPlayingAgainstBot) {
              if (isApuesta) {
                currencyChange = _selectedBetAmount! + (_selectedBetAmount! * 0.8).round();
              } else {
                currencyChange = _selectedBetAmount! + (_selectedBetAmount! * 0.5).round();
              }
            } else {
              final winnings = (_selectedBetAmount! * 0.7).round();
              currencyChange = winnings + _selectedBetAmount!;
            }
          }
          break;

        case GameResultModel.loss:
          pointsEarned = -5;
          if (_selectedBetAmount != null) {
            currencyChange = -_selectedBetAmount!;

          }
          break;

        case GameResultModel.draw:
          pointsEarned = 8;
          if (_isPlayingAgainstBot && _selectedBetAmount != null) {
            currencyChange = 0;
          }
          break;
      }

      if (currencyChange != 0) {
        final userData = await _firestoreService.getUser(currentUser!.uid);
        if (userData != null) {
          if (useDiamonds) {
            final currentDiamonds = userData.diamonds ?? 0;
            final newDiamonds = currentDiamonds + currencyChange;
            await _firestoreService.updateUserDiamonds(currentUser!.uid, newDiamonds);
            setState(() {
              _userDiamonds = newDiamonds;
            });
          } else {
            final currentCoins = userData.coins;
            final newCoins = currentCoins + currencyChange;
            await _firestoreService.updateUserCoins(currentUser!.uid, newCoins);

            setState(() {
              _userCoins = newCoins;
            });
          }
        }
      }

      final success = await _firestoreService.recordGameMatch(
        userId: currentUser!.uid,
        gameType: GameTypeModel.chess,
        result: result,
        pointsEarned: pointsEarned,
        durationMinutes: gameDuration > 0 ? gameDuration : 1,
        opponentName: _opponentName ??
            (_isPlayingAgainstBot ? 'Bot Player' : 'Jugador en línea'),
        additionalData: {
          'gameMode': _isPlayingAgainstBot ? 'online_bot' : 'online_matchmaking',
          'matchType': widget.matchType,
          'timeControl': _selectedTimeMinutes != null
              ? '${_selectedTimeMinutes!} minutos'
              : 'Sin límite',
          'playerColor': _myColor == PlayerColor.white ? 'white' : 'black',
          'finalFEN': controller.getFen(),
          'betAmount': _selectedBetAmount,
          'currencyChange': currencyChange,
          'currencyType': _getCurrencyType(),
          'isPlayingAgainstBot': _isPlayingAgainstBot,
          'botAcceptedBet': _isPlayingAgainstBot && _selectedBetAmount != null,
        },
      );

      if (success) {
        print('Partida registrada exitosamente');
        if (currencyChange > 0) {
          String currency = _getCurrencyName();
          print('Ganaste $currencyChange $currency');

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${S.of(context).youWonShort} $currencyChange $currency!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          }
        } else if (currencyChange < 0) {
          String currency = _getCurrencyName();
          print('Perdiste ${currencyChange.abs()} $currency');

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${S.of(context).youLost} ${currencyChange.abs()} $currency'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          }
        } else if (result == GameResultModel.draw && _selectedBetAmount != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${S.of(context).drawBetReturned} $_selectedBetAmount ${_getCurrencyName()}'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } catch (e) {
      print('Error al registrar la partida: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al procesar el resultado de la apuesta'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool _canAffordBet() {
    if (_selectedBetAmount == null) return true;

    final currentBalance = _getCurrentBalance();
    if (currentBalance == null) return false;

    return currentBalance >= _selectedBetAmount!;
  }

  void _cancelMatchmaking(String reason) {
    _matchmakingTimer?.cancel();
    _showErrorAndReturn(reason);
  }

  void _showErrorAndReturn(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Text(S.of(context).error),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                child: Text('OK'),
              ),
            ],
          ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showGameEndDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Text(S.of(context).gameOver),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [Text(message, textAlign: TextAlign.center)],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                child: Text(S.of(context).exit),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _gameState = OnlineGameState.timeSelection;
                    _selectedTimeMinutes = null;
                    _currentGame = null;
                    _gameEnded = false;
                    _gameStartTime = null;
                    _isPlayingAgainstBot = false;
                    _isMyTurn = false;
                    _myColor = null;
                    _opponentName = null;
                    _opponentPhotoUrl = null;
                    controller.resetBoard();
                    _cleanupTimers();
                  });
                },
                child: Text(S.of(context).playAgain),
              ),
            ],
          ),
    );
  }

  void _showAbandonGameDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Text(S.of(context).abandonGame),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning, color: Colors.orange, size: 48),
                SizedBox(height: 16),
                Text(
                  S.of(context).abandonGameWarning,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(
                  S.of(context).continueGame,
                  style: TextStyle(color: Colors.green),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _abandonGame();
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text(S.of(context).abandonGame),
              ),
            ],
          ),
    );
  }

  Future<void> _abandonGame() async {
    if (_gameEnded) return;
    _gameEnded = true;
    _playerTimer?.cancel();
    _cleanupTimers();

    if (_isPlayingAgainstBot) {
      _recordGameResult(GameResultModel.loss);

      _interstitialHelper.forceShowAd(
        onComplete: () {
          Navigator.of(context).pop();
        },
      );
      return;
    }

    if (_currentGame != null) {
      try {
        final opponentId = _currentGame!.getOpponentId(currentUser!.uid);

        await MultiplayerGameService().finishGame(
          gameId: _currentGame!.id,
          result: GameResultModel.win,
          winnerId: opponentId,
          reason: 'abandoned',
        );
        _recordGameResult(GameResultModel.loss);
      } catch (e) {
        print('Error al abandonar la partida: $e');
        _recordGameResult(GameResultModel.loss);
      }
    }

    _interstitialHelper.forceShowAd(
      onComplete: () {
        Navigator.of(context).pop();
      },
    );
  }

  void _showOpponentAbandonedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 28),
                SizedBox(width: 12),
                Text(S.of(context).opponentLeft),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  S.of(context).opponentAbandonedMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.emoji_events, color: Colors.green, size: 24),
                      SizedBox(width: 8),
                      Text(
                        S.of(context).youWon,
                        style: TextStyle(
                          color: Colors.green[800],
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                child: Text(S.of(context).exit),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _startNewGame();
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.green,
                  backgroundColor: Colors.green[50],
                ),
                child: Text(S.of(context).findNewOpponent),
              ),
            ],
          ),
    );
  }

  void _startNewGame() {
    setState(() {
      _gameState = OnlineGameState.timeSelection;
      _selectedTimeMinutes = null;
      _currentGame = null;
      _gameEnded = false;
      _gameStartTime = null;
      _isPlayingAgainstBot = false;
      _isMyTurn = false;
      _myColor = null;
      _opponentName = null;
      _opponentPhotoUrl = null;
      _myRanking = null;
      _opponentRanking = null;
      _lastMoveFromSquare = null;
      _lastMoveToSquare = null;
      _showLastMove = false;
      controller.resetBoard();
      _cleanupTimers();
    });
  }


  bool _onWillPop() {
    if (_gameState == OnlineGameState.playing && !_gameEnded) {
      _showAbandonGameDialog();
      return false;
    }
    if (_gameState == OnlineGameState.searching) {
      _cancelMatchmaking(S.of(context).searchCanceled);
      return false;
    }
    return true;
  }

  Widget _buildSearchingScreen() {
    return Scaffold(
      backgroundColor: const ui.Color(0xFFEC7A34),
      appBar: AppBar(
        backgroundColor: const ui.Color(0xFFEC7A34),
        elevation: 0,
        title: Text(
          S.of(context).searchingOpponent,
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            _cancelMatchmaking(S.of(context).searchCanceled);
          },
        ),
      ),
      body: Column(
        children: [
          const BannerAdWidget(),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                  SizedBox(height: 30),
                  Text(
                    '${S.of(context).searchingOpponent}...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    '${S.of(context).time}: ${_formatTime(_matchmakingSeconds)}',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  if (_matchmakingSeconds >= 35) ...[
                    SizedBox(height: 20),
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: 20),
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        S.of(context).searchingOpponent,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  SizedBox(height: 20),
                  Text(
                    '${S.of(context).timeSettings}: ${_getTimeDisplay()}',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: () => _cancelMatchmaking(S.of(context).searchCanceled),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(S.of(context).cancelSearch),
                  ),
                ],
              ),
            ),
          ),
          const BannerAdWidget(),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildGameScreen() {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _onWillPop();
        }
      },
      child: Scaffold(
        backgroundColor: const ui.Color(0xFFEC7A34),
        appBar: AppBar(
          backgroundColor: const ui.Color(0xFFEC7A34),
          elevation: 0,
          title: Text(
            S.of(context).onlineGame,
            style: TextStyle(color: Colors.white),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              if (!_onWillPop()) {
                return;
              }
              Navigator.of(context).pop();
            },
          ),
        ),
        body: Column(
          children: [
            _buildPlayerInfo(isMe: false),

            if (_selectedTimeMinutes != null)
              _buildTimer(_opponentTimeSeconds, isMyTimer: false),

            Expanded(
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Stack(
                      children: [
                        GestureDetector(
                          onPanUpdate: (_) {},
                          onPanStart: (_) {},
                          onPanEnd: (_) {},
                          behavior: HitTestBehavior.opaque,
                          child: ChessBoard(
                            controller: controller,
                            boardColor: BoardColor.brown,
                            boardOrientation: _myColor ?? PlayerColor.white,
                            enableUserMoves: _isMyTurn && !_gameEnded,
                            onMove: _playerMoved,
                          ),
                        ),
                        _buildLastMoveOverlay(),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (_selectedTimeMinutes != null)
              _buildTimer(_myTimeSeconds, isMyTimer: true),

            _buildPlayerInfo(isMe: true),

            if (!_gameEnded)
              Container(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _isMyTurn
                      ? S.of(context).yourTurn
                      : S.of(context).opponentTurn,
                  style: TextStyle(
                    color: _isMyTurn ? Colors.green[300] : Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const BannerAdWidget(),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerInfo({required bool isMe}) {
    final name =
        isMe
            ? (currentUser?.displayName ?? S.of(context).you)
            : (_opponentName ?? S.of(context).rivals);

    final photoUrl = isMe ? currentUser?.photoURL : _opponentPhotoUrl;
    final isPlayerTurn = isMe ? _isMyTurn : !_isMyTurn;
    final ranking = isMe ? _myRanking : _opponentRanking;

    String? botAvatar;
    if (!isMe && _isPlayingAgainstBot && _opponentName != null) {
      final botProfile = _botProfiles.firstWhere(
        (p) => p['name'] == _opponentName,
        orElse: () => _botProfiles[0],
      );
      botAvatar = botProfile['avatar'];
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color:
            isPlayerTurn ? Colors.black.withValues(alpha: 0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isPlayerTurn ? Border.all(color: Colors.green, width: 2) : null,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.grey[300],
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
            child:
                photoUrl == null
                    ? (_isPlayingAgainstBot && !isMe && botAvatar != null
                        ? Text(botAvatar, style: TextStyle(fontSize: 24))
                        : Icon(Icons.person, size: 24))
                    : null,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_isPlayingAgainstBot && !isMe)
                      Container(
                        margin: EdgeInsets.only(left: 8),
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getRankingColor(ranking),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.emoji_events,
                            size: 12,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            ranking?.toString() ?? '---',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                    if (isPlayerTurn)
                      Expanded(
                        child: Text(
                          '${S.of(context).playing}...',
                          style: TextStyle(
                            color: Colors.green[300],
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ui.Color _getRankingColor(int? ranking) {
    if (ranking == null) return Colors.grey;

    if (ranking >= 2000) return Colors.purple;
    if (ranking >= 1800) return Colors.blue;
    if (ranking >= 1600) return Colors.green;
    if (ranking >= 1400) return Colors.orange;
    if (ranking >= 1200) return Colors.yellow[700]!;
    return Colors.red;
  }

  Widget _buildTimer(int seconds, {required bool isMyTimer}) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    final timeString =
        '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';

    final isRunningOut = seconds <= 30;
    final isActive = isMyTimer ? _isMyTurn : !_isMyTurn;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color:
            isActive
                ? (isRunningOut ? Colors.red[700] : Colors.green[700])
                : Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        timeString,
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _getTimeDisplay() {
    if (_selectedTimeMinutes == null) return S.of(context).outOfTime;
    return '$_selectedTimeMinutes ${S.of(context).minute}${_selectedTimeMinutes! > 1 ? 's' : ''}';
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Widget _buildBetNegotiationScreen() {
    return Scaffold(
      backgroundColor: const ui.Color(0xFFEC7A34),
      appBar: AppBar(
        backgroundColor: const ui.Color(0xFFEC7A34),
        elevation: 0,
        title: Text(
          S.of(context).negotiatingBet,
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            _cancelBetNegotiation();
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white, strokeWidth: 3),

              SizedBox(height: 30),

              Flexible(
                child: Text(
                  S.of(context).negotiatingBet,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              SizedBox(height: 20),

              Flexible(
                child: Container(
                  width: double.infinity,
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.9,
                  ),
                  margin: EdgeInsets.symmetric(horizontal: 20),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.diamond, color: Colors.amber, size: 24),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '${S.of(context).bet}: ${_selectedBetAmount ?? 0} ${S.of(context).diamonds}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 12),

                      Text(
                       S.of(context).waitingOpponentResponse,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _cancelBetNegotiation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    S.of(context).cancelNegotiation,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _cancelBetNegotiation() {
    _betNegotiationSubscription?.cancel();
    _gameSubscription?.cancel();

    if (_pendingGameId != null) {
      FirebaseFirestore.instance
          .collection('multiplayer_games')
          .doc(_pendingGameId!)
          .update({'status': 'cancelled'});
    }

    setState(() {
      _gameState = OnlineGameState.timeSelection;
      _betState = BetNegotiationState.selecting;
      _pendingGameId = null;
      _isBetNegotiating = false;
    });
  }


  @override
  Widget build(BuildContext context) {
    if (_gameState == OnlineGameState.betNegotiation) {
      return _buildBetNegotiationScreen();
    }
    switch (_gameState) {
      case OnlineGameState.timeSelection:
        return _buildTimeSelectionScreen();
      case OnlineGameState.searching:
        return _buildSearchingScreen();
      case OnlineGameState.playing:
        return _buildGameScreen();
      case OnlineGameState.betNegotiation:
        throw UnimplementedError();
    }
  }

  String _getCurrencyType() {
    return widget.matchType == S.of(context).bet ? 'diamonds' : 'coins';
  }

  String _getCurrencyName() {
    return widget.matchType == S.of(context).bet ? 'diamantes' : 'monedas';
  }


  int? _getCurrentBalance() {
    return widget.matchType == S.of(context).bet ? _userDiamonds : _userCoins;
  }
}

enum OnlineGameState { timeSelection, searching, playing, betNegotiation }

class TimeOption {
  final int? minutes;
  final String display;

  TimeOption({required this.minutes, required this.display});
}

class LastMovePainter extends CustomPainter {
  final String fromSquare;
  final String toSquare;
  final PlayerColor boardOrientation;
  final bool isMyMove;

  LastMovePainter({
    required this.fromSquare,
    required this.toSquare,
    required this.boardOrientation,
    this.isMyMove = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paintFrom = Paint()
      ..color = (isMyMove ? Colors.blue : Colors.yellow).withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final paintTo = Paint()
      ..color = (isMyMove ? Colors.green : Colors.orange).withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = (isMyMove ? Colors.blue : Colors.yellow).withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final squareSize = size.width / 8;

    final fromCoords = _squareToCoordinates(fromSquare, boardOrientation);
    final toCoords = _squareToCoordinates(toSquare, boardOrientation);

    final fromRect = Rect.fromLTWH(
      fromCoords.dx * squareSize,
      fromCoords.dy * squareSize,
      squareSize,
      squareSize,
    );
    canvas.drawRect(fromRect, paintFrom);
    canvas.drawRect(fromRect, strokePaint);

    final toRect = Rect.fromLTWH(
      toCoords.dx * squareSize,
      toCoords.dy * squareSize,
      squareSize,
      squareSize,
    );
    canvas.drawRect(toRect, paintTo);

    final strokePaintTo = Paint()
      ..color = (isMyMove ? Colors.green : Colors.orange).withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRect(toRect, strokePaintTo);
  }

  Offset _squareToCoordinates(String square, PlayerColor orientation) {
    if (square.length != 2) return Offset.zero;

    final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0); // 0-7
    final rank = int.parse(square[1]) - 1; // 0-7

    double x, y;

    if (orientation == PlayerColor.white) {
      x = file.toDouble();
      y = (7 - rank).toDouble();
    } else {
      x = (7 - file).toDouble();
      y = rank.toDouble();
    }

    return Offset(x, y);
  }

  @override
  bool shouldRepaint(covariant LastMovePainter oldDelegate) {
    return oldDelegate.fromSquare != fromSquare ||
        oldDelegate.toSquare != toSquare ||
        oldDelegate.boardOrientation != boardOrientation;
  }
}


