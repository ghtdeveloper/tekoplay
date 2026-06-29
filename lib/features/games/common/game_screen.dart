import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tekoplay/features/games/chess/chess_tutorial_screen.dart';
import 'package:tekoplay/features/games/common/ranking_screen.dart';
import 'package:tekoplay/features/games/common/withdraw_dialog.dart';
import 'package:tekoplay/features/games/common/withdrawal_widget.dart';
import 'package:tekoplay/features/games/ludo/ludo_tutorial_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/models/ludo_game_match.dart';
import '../../../core/models/multiplayer_game_match_chess.dart';
import '../../../core/service/anonymous_wallet_service.dart';
import '../../../core/service/auth_service.dart';
import '../../../core/service/firestore_service.dart';
import '../../../core/service/ludo_game_service.dart';
import '../../../core/service/multiplayer_game_service.dart';
import '../../../core/service/notification_service.dart';
import '../../../core/service/payment_service.dart';
import '../../../generated/l10n.dart';
import '../../../widgets/game_mode_widget.dart';
import '../../adds/banner_ad_widget.dart';
import '../../coins/coin_purchase_dialog.dart';
import '../../coins/diamond_purchase_dialog.dart';
import '../../home/home_screen.dart';
import '../../settings/settings_screen.dart';
import '../chess/chess_vs_cpu_screen.dart';
import '../chess/multiplayer_chess_screen.dart';
import '../chess/online_chess_screen.dart';
import '../domino/domino_tutorial_screen.dart';
import '../domino/domino_vs_cpu_screen.dart';
import '../ludo/ludo_vs_cpu_screen.dart';
import '../ludo/multiplayer_ludo_screen.dart';
import '../ludo/online_ludo_screen.dart';
import 'game_history_screen.dart';

class GameScreen extends StatefulWidget {
  final String gameType;
  final String matchType;

  const GameScreen({
    super.key,
    required this.gameType,
    required this.matchType,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late String gameType;
  late String matchType;
  User? _currentUser;
  String? _currentPhotoUrl;
  int? _userDiamonds;
  int? _userCoins;
  String? _anonymousPlayerName;
  bool _isAnonymousMode = false;
  AudioPlayer? _audioPlayer;
  double _currentVolume = 0.5;
  bool _isDisposed = false;
  bool _isInitialized = false;
  StreamSubscription<List<Map<String, dynamic>>>? _invitationsSubscription;
  StreamSubscription<List<MultiplayerGameMatch>>? _activeGamesSubscription;
  StreamSubscription<List<LudoGameMatch>>? _activeLudoGamesSubscription;
  List<LudoGameMatch> _previousActiveLudoGames = [];
  StreamSubscription<DocumentSnapshot>? _diamondsSubscription;
  final AnonymousWalletService _walletService = AnonymousWalletService();
  bool _isScreenKeepOnActive = false;

  String? _localizedChess;
  String? _localizedDomino;
  String? _localizedLudo;

  int? _withdrawableDiamonds;
  List<MultiplayerGameMatch> _previousActiveGames = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    gameType = widget.gameType;
    matchType = widget.matchType;
    _initializeAsync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setupWalletInfoUser();
    _localizedChess = S.of(context).chess;
    _localizedDomino = S.of(context).domino;
    _localizedLudo = S.of(context).parchisShort;
  }

  bool get isChess => gameType == _localizedChess;

  bool get isDomino => gameType == _localizedDomino;

  bool get isLudo => gameType == _localizedLudo;

  void _setupWalletInfoUser() {
    if (_currentUser == null) {
      _setupAnonymousWalletListener();
    } else {
      _setupFirestoreWalletListener();
    }
  }

  void _setupFirestoreWalletListener() {
    _diamondsSubscription?.cancel();

    _diamondsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.uid)
        .snapshots()
        .listen(
          (DocumentSnapshot document) {
            if (document.exists && mounted && !_isDisposed) {
              final userData = document.data() as Map<String, dynamic>;
              setState(() {
                _userDiamonds = userData['diamonds'] ?? 0;
                _userCoins = userData['coins'] ?? 0;
                _withdrawableDiamonds = userData['diamondsEarned'] ?? 0;
              });
            }
          },
          onError: (error) {
            if (kDebugMode) {
              print('Error listening to diamonds: $error');
            }
            if (mounted && !_isDisposed) {
              setState(() {
                _userDiamonds = 0;
                _userCoins = 0;
                _withdrawableDiamonds = 0;
              });
            }
          },
        );
  }

  void _showWithdrawalDialog() {
    if (_currentUser == null ||
        _withdrawableDiamonds == null ||
        _withdrawableDiamonds! <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No tienes diamantes disponibles para retirar'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return WithdrawalDialog(
          withdrawableAmount: _withdrawableDiamonds!,
          onWithdraw: (amount) => _processWithdrawal(amount),
        );
      },
    );
  }

  Future<void> _processWithdrawal(int amount) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Solicitud de retiro procesada: $amount diamantes'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error en retiro: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al procesar el retiro'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        if (_isScreenKeepOnActive) {
          _enableWakeLock();
        }
        _resumeGameMusic();
        break;
      case AppLifecycleState.paused:
        _disableWakeLock();
        _audioPlayer?.pause();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _audioPlayer?.pause();
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _resumeGameMusic() async {
    if (_isDisposed || _audioPlayer == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentVolume = prefs.getDouble('musicVolume') ?? 0.5;
      await _audioPlayer?.setVolume(_currentVolume);
      await _audioPlayer?.resume();
    } catch (e) {
      if (kDebugMode) {
        print('Error reanudando música del juego: $e');
      }
    }
  }

  Future<void> _enableWakeLock() async {
    try {
      if (!await WakelockPlus.enabled) {
        await WakelockPlus.enable();
        if (mounted && !_isDisposed) {
          setState(() {
            _isScreenKeepOnActive = true;
          });
        }
        if (kDebugMode) {
          print('WakeLock enabled - screen will stay on');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error enabling WakeLock: $e');
      }
    }
  }

  Future<void> _disableWakeLock() async {
    try {
      if (await WakelockPlus.enabled) {
        await WakelockPlus.disable();
        if (mounted && !_isDisposed) {
          setState(() {
            _isScreenKeepOnActive = false;
          });
        }
        if (kDebugMode) {
          print('WakeLock disabled - screen can turn off normally');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error disabling WakeLock: $e');
      }
    }
  }

  void _setupAnonymousWalletListener() {
    _updateAnonymousWalletUI();
  }

  Future<bool> _validateUserFundsForInvitation() async {
    if (_currentUser == null) return false;

    try {
      final currentBalance =
          matchType == S.of(context).bet
              ? (_userDiamonds ?? 0)
              : (_userCoins ?? 0);

      bool hasInsufficientFunds = false;
      if (matchType == S.of(context).bet) {
        hasInsufficientFunds = currentBalance < 50;
      } else {
        hasInsufficientFunds = currentBalance < 100;
      }

      if (hasInsufficientFunds) {
        _showInsufficientFundsDialog();
        return false;
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('💥 Error validating user funds for invitation: $e');
      }
      return false;
    }
  }

  void _showInsufficientFundsDialog() {
    if (!mounted) return;

    final currencyName = _getCurrencyName();
    final currencyIcon = _getCurrencyIcon();
    final currentBalance = _getCurrentBalance() ?? 0;

    String title = S.of(context).insufficientFunds;
    String message;

    if (widget.matchType == S.of(context).bet) {
      message =
          '${S.of(context).insufficientFunds} $currencyName ${S.of(context).toJoinThisGame}\n\n'
          '${S.of(context).youNeed}:  $currencyName\n'
          '${S.of(context).youHave}: $currentBalance $currencyName\n\n'
          '${S.of(context).buyMore} $currencyName ${S.of(context).inOurStore}';
    } else {
      message =
          '${S.of(context).youDontHave}$currencyName ${S.of(context).enoughToPlay}.\n\n'
          '${S.of(context).needAtLeast100} $currencyName${S.of(context).toParticipate}.\n'
          '${S.of(context).youHave}: $currentBalance $currencyName\n\n'
          '${S.of(context).buyMore} $currencyName ${S.of(context).inOurStore}';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange, size: 24),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(currencyIcon, size: 48, color: Colors.red),
                      SizedBox(height: 12),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
              ],
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            actions: [
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                icon: Icon(Icons.arrow_back),
                label: Text(S.of(context).back),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
    );
  }

  String _getCurrencyName() {
    return widget.matchType == S.of(context).bet ? 'diamonds' : 'coins';
  }

  IconData _getCurrencyIcon() {
    return widget.matchType == S.of(context).bet
        ? Icons.diamond
        : Icons.monetization_on;
  }

  int? _getCurrentBalance() {
    return widget.matchType == S.of(context).bet ? _userDiamonds : _userCoins;
  }

  Future<void> _updateAnonymousWalletUI() async {
    if (_currentUser != null) return;

    try {
      final coins = await _walletService.getAnonymousCoins();
      final diamonds = await _walletService.getAnonymousDiamonds();

      if (mounted && !_isDisposed) {
        setState(() {
          _userCoins = coins;
          _userDiamonds = diamonds;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error actualizando UI de wallet anónima: $e');
      }
    }
  }

  Future<void> _initializeAsync() async {
    try {
      if (_isDisposed) return;
      _audioPlayer = AudioPlayer();
      final prefs = await SharedPreferences.getInstance();
      _currentVolume = prefs.getDouble('musicVolume') ?? 0.5;
      await _audioPlayer!.setVolume(_currentVolume);
      await _audioPlayer!.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer!.play(AssetSource('audio/background_music.mp3'));
      _loadCurrentUser();
      if (_isDisposed) return;
      _initializeNotifications();
      if (_isDisposed) return;
      _setupStreams();
      if (_isDisposed) return;
      await _enableWakeLock();
      if (AuthService().getCurrentUser() == null) {
        _enableAnonymousMode();
      }
      if (_isDisposed) return;
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error en inicialización: $e');
      }
      if (mounted && !_isDisposed) {
        setState(() {
          _isInitialized = true;
        });
      }
    }
  }

  Future<void> _updateVolume(double newVolume) async {
    if (_isDisposed) return;
    try {
      _currentVolume = newVolume;
      await _audioPlayer?.setVolume(newVolume);
      if (mounted) setState(() {});
    } catch (e) {
      if (kDebugMode) {
        print('Error actualizando volumen: $e');
      }
    }
  }

  Future<void> _enableAnonymousMode() async {
    if (_isDisposed) return;

    try {
      final playerName = await AuthService().enableAnonymousMode();
      if (playerName != null && mounted && !_isDisposed) {
        setState(() {
          _anonymousPlayerName = playerName;
          _isAnonymousMode = true;
        });
        await _updateAnonymousWalletUI();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error en modo anónimo: $e');
      }
    }
  }

  Future<void> _loadCurrentUser() async {
    if (_isDisposed) return;

    try {
      final user = AuthService().getCurrentUser();
      if (_isDisposed) return;

      if (mounted) {
        setState(() {
          _currentUser = user;
          if (user != null) _isAnonymousMode = false;
        });
      }

      if (user != null && !_isDisposed) {
        // Conectar listener en tiempo real tan pronto se conoce el usuario
        _setupFirestoreWalletListener();
        final userData = await FirestoreService().getUser(user.uid);
        if (userData != null && mounted && !_isDisposed) {
          setState(() {
            _currentPhotoUrl = userData.urlPhoto;
          });
        }
      } else {
        await _updateAnonymousWalletUI();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error cargando usuario: $e');
      }
    }
  }

  void _initializeNotifications() {
    if (_isDisposed) return;

    try {
      NotificationService().initialize();
    } catch (e) {
      if (kDebugMode) {
        print('Error inicializando notificaciones: $e');
      }
    }
  }

  void _setupStreams() {
    if (_isDisposed || _currentUser == null) return;
    try {
      _invitationsSubscription?.cancel();
      _activeGamesSubscription?.cancel();
      _invitationsSubscription = GameInvitationService()
          .getPendingInvitations(_currentUser!.uid)
          .handleError((error) {
            if (kDebugMode) {
              print('Error en stream de invitaciones: $error');
            }
          })
          .listen(
            (invitations) {
              if (mounted && !_isDisposed) {
                setState(() {});
              }
            },
            onError: (error) {
              if (kDebugMode) {
                print('Error en subscription de invitaciones: $error');
              }
            },
          );

      _activeGamesSubscription = MultiplayerGameService()
          .getActiveGames(_currentUser!.uid)
          .handleError((error) {
            if (kDebugMode) {
              print('Error en stream de juegos: $error');
            }
          })
          .listen(
            (games) {
              if (mounted && !_isDisposed) {
                setState(() {});
                _handleNewActiveGames(games);
              }
            },
            onError: (error) {
              if (kDebugMode) {
                print('Error en subscription de juegos: $error');
              }
            },
          );

      _activeLudoGamesSubscription?.cancel();
      _activeLudoGamesSubscription = LudoGameService()
          .getActiveGames(_currentUser!.uid)
          .handleError((error) {
            if (kDebugMode) {
              print('Error en stream de juegos Ludo: $error');
            }
          })
          .listen(
            (games) {
              if (mounted && !_isDisposed) {
                _handleNewActiveLudoGames(games);
              }
            },
            onError: (error) {
              if (kDebugMode) {
                print('Error en subscription de juegos Ludo: $error');
              }
            },
          );
    } catch (e) {
      if (kDebugMode) {
        print('Error configurando streams: $e');
      }
    }
  }

  void _handleNewActiveGames(List<MultiplayerGameMatch> currentGames) {
    final newGames =
        currentGames.where((game) {
          return !_previousActiveGames.any(
            (prevGame) => prevGame.id == game.id,
          );
        }).toList();

    for (final newGame in newGames) {
      if (newGame.hostId == _currentUser!.uid &&
          newGame.status == 'active' &&
          newGame.guestId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => MultiplayerChessScreen(
                  gameId: newGame.id,
                  isHost: true,
                  matchType: matchType,
                ),
          ),
        );
        break;
      }
    }
    _previousActiveGames = List.from(currentGames);
  }

  void _handleNewActiveLudoGames(List<LudoGameMatch> currentGames) {
    final newGames = currentGames.where((game) {
      return !_previousActiveLudoGames.any((prev) => prev.id == game.id);
    }).toList();

    for (final newGame in newGames) {
      if (newGame.hostId == _currentUser!.uid &&
          newGame.status == 'active' &&
          newGame.guest2Id != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MultiplayerLudoScreen(
              gameId: newGame.id,
              playerNumber: 1,
              matchType: newGame.currencyType,
            ),
          ),
        );
        break;
      }
    }
    _previousActiveLudoGames = List.from(currentGames);
  }

  void _showCoinPurchaseDialog() {
    showCoinPurchaseDialog(
      context,
      onPurchase: (coinAmount, price) {
        _processCoinPurchase(coinAmount, price);
      },
    );
  }

  void _showDiamondPurchaseDialog() {
    showDiamondPurchaseDialog(
      context,
      onPurchase: (diamondAmount, price) {
        _processDiamondPurchase(diamondAmount, price);
      },
    );
  }

  Future<void> _processCoinPurchase(int coins, int price) async {
    final notAvailableMsg = S.of(context).googlePayNotAvailable;
    final coinsLabel = S.of(context).coins;
    final successMsg = S.of(context).purchaseSuccessful;
    final errorMsg = S.of(context).paymentProcessingError;
    try {
      final paymentService = PaymentService();
      final canPay = await paymentService.canMakePayments();
      if (!canPay) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(notAvailableMsg),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final result = await paymentService.makePayment(
        label: '$coins $coinsLabel',
        amount: price.toDouble(),
        productId: 'coins_$coins',
      );

      if (result != null && result['success'] == true) {
        final success = await AuthService().addCoins(coins);

        if (success) {
          if (_currentUser == null) {
            await _updateAnonymousWalletUI();
          } else {
            if (mounted && !_isDisposed) {
              setState(() { _userCoins = (_userCoins ?? 0) + coins; });
            }
          }
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$successMsg +$coins $coinsLabel'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          throw Exception('Failed to update coins');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error en compra: $e');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _processDiamondPurchase(int diamonds, double price) async {
    final notAvailableMsg = S.of(context).googlePayNotAvailable;
    final diamondsLabel = S.of(context).diamonds;
    final successMsg = S.of(context).purchaseSuccessful;
    final errorMsg = S.of(context).paymentProcessingError;
    try {
      final paymentService = PaymentService();
      final canPay = await paymentService.canMakePayments();
      if (!canPay) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(notAvailableMsg),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final result = await paymentService.makePayment(
        label: '$diamonds $diamondsLabel',
        amount: price,
        productId: 'diamonds_$diamonds',
      );

      if (result != null && result['success'] == true) {
        final success = await AuthService().addDiamonds(diamonds);

        if (success) {
          if (_currentUser == null) {
            await _updateAnonymousWalletUI();
          }
          // For authenticated users the Firestore realtime listener
          // already updates _userDiamonds automatically — no manual setState needed.
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$successMsg +$diamonds $diamondsLabel'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          throw Exception('Failed to update diamonds');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error en compra: $e');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void deactivate() {
    // Detenemos el audio en cuanto la pantalla sale del árbol de widgets,
    // antes de que home_screen reanude su propio player.
    _audioPlayer?.stop();
    super.deactivate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disableWakeLock();
    _isDisposed = true;
    _invitationsSubscription?.cancel();
    _activeGamesSubscription?.cancel();
    _activeLudoGamesSubscription?.cancel();
    _diamondsSubscription?.cancel();
    _audioPlayer?.dispose();
    _previousActiveGames.clear();
    _previousActiveLudoGames.clear();
    if (_isAnonymousMode) {
      try {
        AuthService().disableAnonymousMode();
      } catch (e) {
        if (kDebugMode) {
          print('Error deshabilitando modo anónimo: $e');
        }
      }
    }
    super.dispose();
  }

  Widget _buildUserAvatar() {
    String? photoUrl = _currentPhotoUrl ?? _currentUser?.photoURL;

    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 60,
        backgroundColor: Colors.grey[300],
        backgroundImage: NetworkImage(photoUrl),
        onBackgroundImageError: (exception, stackTrace) {
          if (mounted && !_isDisposed) {
            setState(() {
              _currentPhotoUrl = null;
            });
          }
        },
      );
    } else {
      return CircleAvatar(
        radius: 60,
        backgroundImage: AssetImage('assets/images/img_perfil_unknown.png'),
        backgroundColor: Colors.grey[300],
      );
    }
  }

  Widget _buildMatchTypeIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: matchType == S.of(context).bet ? Colors.amber : Colors.green,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            matchType == S.of(context).bet
                ? Icons.monetization_on
                : Icons.sports_esports,
            color: Colors.white,
            size: 16,
          ),
          SizedBox(width: 4),
          Text(
            matchType,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _showLoginRequiredDialog(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline, size: 48, color: Color(0xFFEC7A34)),
                  SizedBox(height: 16),
                  Text(
                    S.of(context).loginRequired,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '${S.of(context).toUse} $feature ${S.of(context).youNeedToLogin}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(S.of(context).cancel),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => SettingsScreen(
                                      onVolumeChangedLive: (newVolume) {
                                        _updateVolume(newVolume);
                                      },
                                    ),
                              ),
                            );
                            _loadCurrentUser();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFFEC7A34),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(S.of(context).login),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _showUserOptionsDialog(BuildContext context) {
    if (_currentUser == null) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),

                _buildUserAvatar(),
                SizedBox(height: 12),

                Text(
                  _currentUser!.displayName ?? S.of(context).anonymous,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),

                SizedBox(height: 20),

                // Botón Ranking
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RankingScreen(),
                        ),
                      );
                    },
                    icon: Icon(Icons.leaderboard),
                    label: Text(
                      S.of(context).ranking,
                      style: TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEC7A34),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),

                SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GameHistoryScreen(),
                        ),
                      );
                    },
                    icon: Icon(Icons.history),
                    label: Text(
                      S.of(context).gameStats,
                      style: TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEC7A34),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserNameSection() {
    final displayName =
        _currentUser?.displayName ??
        _anonymousPlayerName ??
        S.of(context).anonymous;
    final isInteractive = _currentUser != null;

    return GestureDetector(
      onTap:
          isInteractive
              ? () => _showUserOptionsDialog(context)
              : () => _showAnonymousUserDialog(context),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isAnonymousMode) ...[
              Icon(Icons.person_outline, color: Colors.white70, size: 16),
              SizedBox(width: 4),
            ],
            Text(
              displayName,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _isAnonymousMode ? Colors.white70 : Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            if (isInteractive) ...[
              SizedBox(width: 8),
              Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 20),
            ] else if (_isAnonymousMode) ...[
              SizedBox(width: 8),
              Icon(Icons.info_outline, color: Colors.white70, size: 16),
            ],
          ],
        ),
      ),
    );
  }

  void _showAnonymousUserDialog(BuildContext context) {
    final screenContext = context;
    showDialog(
      context: context,
      builder:
          (dialogCtx) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 48,
                    color: Color(0xFFEC7A34),
                  ),
                  SizedBox(height: 16),
                  Text(
                    S.of(dialogCtx).playingAsGuest,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '${S.of(dialogCtx).yourTemporaryName}: $_anonymousPlayerName',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 16),
                  Text(
                    S.of(dialogCtx).loginToAccessFeatures,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14),
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(dialogCtx).pop(),
                          child: Text(S.of(dialogCtx).continueAsGuest),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.of(dialogCtx).pop();
                            await Navigator.push(
                              screenContext,
                              MaterialPageRoute(
                                builder:
                                    (_) => SettingsScreen(
                                      onVolumeChangedLive: (newVolume) {
                                        _updateVolume(newVolume);
                                      },
                                    ),
                              ),
                            );
                            if (mounted) await _loadCurrentUser();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFFEC7A34),
                            foregroundColor: Colors.white,
                          ),
                          child: Text(S.of(dialogCtx).login),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: Color(0xFFEC7A34),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Cargando...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Color(0xFFEC7A34),
      body: SafeArea(
        child: Column(
          children: [
            const BannerAdWidget(),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        if (!_isDisposed) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => MainScreen()),
                          );
                        }
                      },
                    ),
                  ),
                  SizedBox(width: 4),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final shouldStack = constraints.maxWidth < 200 &&
                            matchType == S.of(context).bet &&
                            (_withdrawableDiamonds ?? 0) > 0;

                        if (shouldStack) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildBalanceRow(),
                              SizedBox(height: 4),
                              WithdrawalCounterWidget(
                                withdrawableAmount: _withdrawableDiamonds ?? 0,
                                onWithdraw: _showWithdrawalDialog,
                              ),
                            ],
                          );
                        } else {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(child: _buildBalanceRow()),
                              if (matchType == S.of(context).bet &&
                                  (_withdrawableDiamonds ?? 0) > 0) ...[
                                SizedBox(width: 4),
                                WithdrawalCounterWidget(
                                  withdrawableAmount: _withdrawableDiamonds ?? 0,
                                  onWithdraw: _showWithdrawalDialog,
                                ),
                              ],
                            ],
                          );
                        }
                      },
                    ),
                  ),
                  SizedBox(width: 4),
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: _buildNotificationsIcon(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildUserAvatar(),
                    SizedBox(height: 10),
                    Text(
                      gameType,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    _buildMatchTypeIndicator(),
                    SizedBox(height: 8),
                    _buildUserNameSection(),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  GameModeButton(
                    imagePath: 'assets/images/icon_play_vs_friend.png',
                    label: S.of(context).vsFriend,
                    onPressed: () {
                      if (!_isDisposed) _showFriendGameDialog(context);
                    },
                  ),
                  GameModeButton(
                    imagePath: 'assets/images/icon_lessons.png',
                    label: S.of(context).tutorial,
                    onPressed: () {
                      if (!_isDisposed) _showTutorial(context);
                    },
                  ),
                  GameModeButton(
                    imagePath: 'assets/images/icon_play_vs_computer.png',
                    label: S.of(context).vsCpu,
                    onPressed: () {
                      if (!_isDisposed) _showComputerGameDialog(context);
                    },
                  ),
                  if (matchType != S.of(context).fun)
                    GameModeButton(
                      imagePath: 'assets/images/icon_play_online.png',
                      label: S.of(context).online,
                      onPressed: () {
                        if (!_isDisposed) _showOnlineGameDialog(context);
                      },
                    ),
                ],
              ),
            ),
            const BannerAdWidget(),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceRow() {
    final isBet = matchType == S.of(context).bet;
    final balance = isBet ? (_userDiamonds ?? 0) : (_userCoins ?? 0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Balance número
        Flexible(
          child: Text(
            '$balance',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),

        SizedBox(width: 4),

        if (matchType == S.of(context).fun)
          Image.asset(
            'assets/images/coin.png',
            height: 24,
            errorBuilder: (context, error, stackTrace) {
              return Icon(Icons.monetization_on, color: Colors.blue, size: 24);
            },
          )
        else if (matchType == S.of(context).bet)
          Image.asset(
            'assets/images/diamond.png',
            height: 24,
            errorBuilder: (context, error, stackTrace) {
              return Icon(Icons.diamond, color: Colors.amber, size: 24);
            },
          ),

        SizedBox(width: 2),

        SizedBox(
          width: 28,
          height: 28,
          child: IconButton(
            icon: Icon(Icons.add_circle, color: Colors.white, size: 20),
            padding: EdgeInsets.zero,
            onPressed: () {
              if (matchType == S.of(context).fun) {
                _showCoinPurchaseDialog();
              } else if (matchType == S.of(context).bet) {
                _showDiamondPurchaseDialog();
              }
            },
          ),
        ),
      ],
    );
  }


  Widget _buildNotificationsIcon() {
    if (_currentUser == null || !_isInitialized) {
      return Icon(Icons.message, size: 30.0, color: Colors.white);
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: GameInvitationService().getPendingInvitations(_currentUser!.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Icon(Icons.notifications, color: Colors.white, size: 30);
        }

        final invitations = snapshot.data ?? [];
        final hasInvitations = invitations.isNotEmpty;

        return Stack(
          children: [
            IconButton(
              icon: Icon(Icons.notifications, color: Colors.white, size: 30),
              onPressed: () {
                if (!_isDisposed) {
                  _showNotificationsDialog(context, invitations);
                }
              },
            ),
            if (hasInvitations)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    '${invitations.length}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showNotificationsDialog(
    BuildContext context,
    List<Map<String, dynamic>> invitations,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              width: double.infinity,
              height: 400,
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        S.of(context).invitations,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Expanded(
                    child:
                        invitations.isEmpty
                            ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.notifications_none,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    S.of(context).noInvitation,
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                            : ListView.builder(
                              itemCount: invitations.length,
                              itemBuilder: (context, index) {
                                final invitation = invitations[index];
                                return Card(
                                  margin: EdgeInsets.only(bottom: 8),
                                  child: Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.sports_esports,
                                              color: Color(0xFFEC7A34),
                                              size: 24,
                                            ),
                                            SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '${invitation['fromUserName']} ${S.of(context).invitesYou}',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    maxLines: 2,
                                                  ),
                                                  Text(
                                                    '${invitation['betAmount']}  ${invitation['currencyType']}',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    maxLines: 2,
                                                  ),
                                                  SizedBox(height: 4),
                                                  Text(
                                                    '${invitation['gameType']}',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            TextButton(
                                              onPressed: () async {
                                                final rejectedMsg = S.of(context).invitationRejected;
                                                final result =
                                                    await GameInvitationService()
                                                        .respondToInvitation(
                                                          invitation['id'],
                                                          false,
                                                        );
                                                if (result != null &&
                                                    result['success'] == true) {
                                                  if (!context.mounted) return;
                                                  Navigator.of(context).pop();
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(rejectedMsg),
                                                      backgroundColor:
                                                          Colors.orange,
                                                    ),
                                                  );
                                                }
                                              },
                                              child: Text(
                                                S.of(context).reject,
                                                style: TextStyle(
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            ElevatedButton(
                                              onPressed: () async {
                                                if (_currentUser == null) {
                                                  return;
                                                }

                                                final hasEnoughFunds =
                                                    await _validateUserFundsForInvitation();
                                                if (!hasEnoughFunds) {
                                                  if (!context.mounted) return;
                                                  Navigator.of(context).pop();
                                                  return;
                                                }

                                                if (!context.mounted) return;
                                                showDialog(
                                                  context: context,
                                                  barrierDismissible: false,
                                                  builder:
                                                      (context) => Center(
                                                        child:
                                                            CircularProgressIndicator(),
                                                      ),
                                                );

                                                final result =
                                                    await GameInvitationService()
                                                        .respondToInvitation(
                                                          invitation['id'],
                                                          true,
                                                        );

                                                if (!context.mounted) return;
                                                Navigator.of(context).pop();

                                                if (result != null &&
                                                    result['success'] == true &&
                                                    result['gameId'] != null) {
                                                  Navigator.of(context).pop();

                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) => result['isLudo'] == true
                                                          ? MultiplayerLudoScreen(
                                                              gameId: result['gameId'],
                                                              playerNumber: result['playerNumber'] ?? 2,
                                                              matchType: result['matchType'] ?? widget.matchType,
                                                            )
                                                          : MultiplayerChessScreen(
                                                              gameId: result['gameId'],
                                                              isHost: false,
                                                              matchType: widget.matchType,
                                                            ),
                                                    ),
                                                  );
                                                } else {
                                                  final errorMsg = S.of(context).errorAcceptedInvitation;
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(errorMsg),
                                                      backgroundColor:
                                                          Colors.red,
                                                    ),
                                                  );
                                                }
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Color(
                                                  0xFFEC7A34,
                                                ),
                                                foregroundColor: Colors.white,
                                              ),
                                              child: Text(S.of(context).accept),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _showFriendGameDialog(BuildContext context) {
    if (_currentUser == null) {
      _showLoginRequiredDialog(context, S.of(context).vsFriend);
      return;
    }

    _validateUserFundsForInvitation().then((hasEnoughFunds) {
      if (!hasEnoughFunds) {
        return;
      }
      if (!context.mounted) return;

      final TextEditingController emailController = TextEditingController();
      final TextEditingController betAmountController = TextEditingController();
      bool isLoading = false;
      String? betAmountError;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              void validateBetAmount(String value) {
                if (matchType != S.of(context).bet) return;

                setState(() {
                  if (value.isEmpty) {
                    betAmountError = 'Por favor ingresa un monto';
                  } else {
                    final amount = int.tryParse(value);
                    if (amount == null) {
                      betAmountError = 'Por favor ingresa un número válido';
                    } else if (amount < 1) {
                      betAmountError = 'El monto debe ser mayor a 0';
                    } else if (amount > (_userDiamonds ?? 0)) {
                      betAmountError =
                          '${S.of(context).insufficientFunds}. ${S.of(context).youHave}: ${_userDiamonds ?? 0}';
                    } else {
                      betAmountError = null;
                    }
                  }
                });
              }

              bool isFormValid =
                  emailController.text.trim().isNotEmpty &&
                  (matchType != S.of(context).bet ||
                      (betAmountController.text.isNotEmpty &&
                          betAmountError == null));

              return Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                backgroundColor: Colors.white,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              S.of(context).playWithFriend,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close),
                              onPressed:
                                  isLoading
                                      ? null
                                      : () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),

                        // Balance actual
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                matchType == S.of(context).bet
                                    ? Icons.diamond
                                    : Icons.monetization_on,
                                color:
                                    matchType == S.of(context).bet
                                        ? Colors.amber
                                        : Colors.blue,
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                '${S.of(context).youHave}: ${matchType == S.of(context).bet ? (_userDiamonds ?? 0) : (_userCoins ?? 0)} ${matchType == S.of(context).bet ? 'diamantes' : 'monedas'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green[800],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 20),

                        // Campo de email
                        TextField(
                          controller: emailController,
                          enabled: !isLoading,
                          keyboardType: TextInputType.emailAddress,
                          onChanged: (value) {
                            setState(() {});
                          },
                          decoration: InputDecoration(
                            labelText: S.of(context).opponentEmail,
                            hintText: 'ejemplo@email.com',
                            prefixIcon: Icon(Icons.email),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),

                        if (matchType == S.of(context).bet) ...[
                          SizedBox(height: 16),
                          TextField(
                            controller: betAmountController,
                            enabled: !isLoading,
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              validateBetAmount(value);
                            },
                            decoration: InputDecoration(
                              labelText: 'Monto a apostar (diamantes)',
                              hintText: 'Ingresa el monto',
                              prefixIcon: Icon(
                                Icons.diamond,
                                color: Colors.amber,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              errorText: betAmountError,
                              helperText:
                                  'Disponible: ${_userDiamonds ?? 0} diamantes',
                              helperStyle: TextStyle(fontSize: 11),
                            ),
                          ),

                          // Botones de monto rápido
                          SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children:
                                [10, 50, 100, 250, 500].map((amount) {
                                  final canSelect =
                                      amount <= (_userDiamonds ?? 0);
                                  return ActionChip(
                                    label: Text('$amount'),
                                    onPressed:
                                        !isLoading && canSelect
                                            ? () {
                                              betAmountController.text =
                                                  amount.toString();
                                              validateBetAmount(
                                                amount.toString(),
                                              );
                                            }
                                            : null,
                                    backgroundColor:
                                        canSelect
                                            ? Colors.amber.withValues(
                                              alpha: 0.2,
                                            )
                                            : Colors.grey.withValues(
                                              alpha: 0.2,
                                            ),
                                    labelStyle: TextStyle(
                                      color:
                                          canSelect
                                              ? Colors.amber[800]
                                              : Colors.grey,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                }).toList(),
                          ),
                        ],

                        SizedBox(height: 20),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed:
                                (isLoading || !isFormValid)
                                    ? null
                                    : () async {
                                      final isBetMode = matchType == S.of(context).bet;
                                      final successMsg = S.of(context).successfulSentInvitation;
                                      final stillHasEnoughFunds =
                                          await _validateUserFundsForInvitation();
                                      if (!stillHasEnoughFunds) {
                                        if (!context.mounted) return;
                                        Navigator.of(context).pop();
                                        return;
                                      }
                                      if (!context.mounted) return;
                                      if (isBetMode) {
                                        final betAmount = int.tryParse(
                                          betAmountController.text.trim(),
                                        );
                                        if (betAmount == null ||
                                            betAmount < 1 ||
                                            betAmount > (_userDiamonds ?? 0)) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Monto de apuesta inválido',
                                              ),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                          return;
                                        }
                                      }

                                      setState(() => isLoading = true);

                                      final error =
                                          await GameInvitationService()
                                              .createInvitation(
                                                fromUserId: _currentUser!.uid,
                                                fromUserName:
                                                    _currentUser!.displayName ??
                                                    'Usuario',
                                                toUserEmail:
                                                    emailController.text.trim(),
                                                gameType: gameType,
                                                betAmount: isBetMode
                                                        ? int.parse(
                                                          betAmountController
                                                              .text
                                                              .trim(),
                                                        )
                                                        : null,
                                                currencyType:
                                                    _getCurrencyName(),
                                              );

                                      setState(() => isLoading = false);

                                      if (!context.mounted) return;
                                      if (error == null) {
                                        Navigator.of(context).pop();
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(successMsg),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(error),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    },
                            icon:
                                isLoading
                                    ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                    : Icon(Icons.send),
                            label: Text(
                              isLoading
                                  ? S.of(context).sending
                                  : S.of(context).sentInvitation,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEC7A34),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    });
  }

  void _showTutorial(BuildContext context) {
    if (isChess) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ChessImmersiveTutorialScreen()),
      );
    } else if (isDomino) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DominoImmersiveTutorialScreen(),
        ),
      );
    }
    else if (isLudo) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LudoTutorialScreen(),
        ),
      );
    }
  }


  void _showComputerGameDialog(BuildContext context) {
    if (isChess) {
      if (matchType == S.of(context).bet) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChessVsComputerScreen(
              'Muy difícil',
              matchType: widget.matchType,
            ),
          ),
        );
      } else {
        _showChessCpuDialog(context);
      }
    } else if (isDomino) {
      _showDominoCpuDialog(context);
    }
    else if (isLudo) {
      _showLudoCpuDialog(context);
    }
  }

  void _showLudoCpuDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final isBet = widget.matchType == 'Apuesta';
        // En modo apuesta solo existe dificultad máxima para que la CPU gane
        String selectedDifficulty = isBet ? S.of(context).ultraDifficult : S.of(context).normal;
        int selectedCpuCount = 1;

        return StatefulBuilder(
          builder: (context, setState) {
            final screenHeight = MediaQuery.of(context).size.height;
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: screenHeight * 0.82),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Header fijo ──────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEC7A34).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.casino, size: 28, color: Color(0xFFEC7A34)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              S.of(context).playVsComputer,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.black54),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 20),

                    // ── Contenido scrollable ─────────────────────────────
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Selector de CPUs
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.people, color: Color(0xFFEC7A34), size: 18),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Cantidad de oponentes CPU',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [1, 2, 3].map((n) {
                                      final isSelected = selectedCpuCount == n;
                                      return Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 4),
                                          child: GestureDetector(
                                            onTap: () => setState(() => selectedCpuCount = n),
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 180),
                                              padding: const EdgeInsets.symmetric(vertical: 10),
                                              decoration: BoxDecoration(
                                                color: isSelected ? const Color(0xFFEC7A34) : Colors.white,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: isSelected ? const Color(0xFFEC7A34) : Colors.grey.shade300,
                                                  width: 2,
                                                ),
                                                boxShadow: isSelected
                                                    ? [BoxShadow(color: const Color(0xFFEC7A34).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))]
                                                    : [],
                                              ),
                                              child: Column(
                                                children: [
                                                  Icon(Icons.smart_toy,
                                                      color: isSelected ? Colors.white : Colors.grey.shade400, size: 22),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '$n CPU${n > 1 ? 's' : ''}',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      color: isSelected ? Colors.white : Colors.black87,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  Text(
                                                    n == 1 ? '(1 vs 1)' : n == 2 ? '(3 jugadores)' : '(4 jugadores)',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      color: isSelected ? Colors.white70 : Colors.grey.shade500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 14),

                            // Selector de dificultad (oculto en modo apuesta — siempre Difícil)
                            if (!isBet) ...[
                              Container(
                                padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.07),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.speed, color: Color(0xFFEC7A34), size: 18),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Dificultad',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    ...[
                                      S.of(context).veryEasy,
                                      S.of(context).easy,
                                      S.of(context).normal,
                                      S.of(context).difficult,
                                      S.of(context).ultraDifficult,
                                    ].map((level) => RadioListTile<String>(
                                      title: Text(level, style: const TextStyle(fontSize: 14)),
                                      value: level,
                                      groupValue: selectedDifficulty,
                                      dense: true,
                                      visualDensity: const VisualDensity(vertical: -2),
                                      contentPadding: EdgeInsets.zero,
                                      activeColor: const Color(0xFFEC7A34),
                                      onChanged: (v) => setState(() => selectedDifficulty = v!),
                                    )),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                            ] else ...[
                              // Badge informativo en modo apuesta
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.07),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.psychology, color: Colors.red, size: 18),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Dificultad: Máxima',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red),
                                          ),
                                          Text(
                                            'En modo apuesta la CPU juega al máximo nivel.',
                                            style: TextStyle(fontSize: 11, color: Colors.red.shade700),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],

                            // Info card
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline, color: Colors.green, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      selectedCpuCount == 1
                                          ? 'Jugarás 1 vs 1 contra la CPU en posiciones opuestas'
                                          : selectedCpuCount == 2
                                              ? 'Jugarás contra 2 CPUs (3 jugadores en total)'
                                              : 'Jugarás contra 3 CPUs (4 jugadores en total)',
                                      style: TextStyle(fontSize: 12, color: Colors.green.shade800),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),

                    // ── Botón Empezar siempre visible ────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LudoVsCpuScreen(
                                  difficulty: selectedDifficulty,
                                  matchType: widget.matchType,
                                  cpuCount: selectedCpuCount,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.play_arrow_rounded, size: 22),
                          label: Text(
                            S.of(context).startGame,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEC7A34),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            elevation: 3,
                            shadowColor: const Color(0xFFEC7A34).withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }



  void _showChessCpuDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        List<String> availableDifficulties;
        String selectedDifficulty;

        if (matchType == S.of(context).bet) {
          availableDifficulties = [
            S.of(context).normal,
            S.of(context).difficult,
          ];
          selectedDifficulty = S.of(context).normal;
        } else {
          availableDifficulties = [
            S.of(context).veryEasy,
            S.of(context).easy,
            S.of(context).normal,
            S.of(context).difficult,
          ];
          selectedDifficulty = S.of(context).normal;
        }

        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    Text(
                      S.of(context).playVsComputer,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.black87,
                      ),
                    ),

                    SizedBox(height: 20),

                    Column(
                      children: availableDifficulties.map((level) {
                        return RadioListTile<String>(
                          title: Text(level),
                          value: level,
                          groupValue: selectedDifficulty,
                          onChanged: (value) {
                            setState(() {
                              selectedDifficulty = value!;
                            });
                          },
                        );
                      }).toList(),
                    ),

                    SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChessVsComputerScreen(
                                selectedDifficulty,
                                matchType: widget.matchType,
                              ),
                            ),
                          );
                        },
                        icon: Icon(Icons.smart_toy),
                        label: Text(
                          S.of(context).startGame,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEC7A34),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDominoCpuDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        String selectedDifficulty = S.of(context).normal;

        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    Text(
                      S.of(context).playVsComputer,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 20),

                    Column(
                      children:
                          [
                            S.of(context).veryEasy,
                            S.of(context).easy,
                            S.of(context).normal,
                            S.of(context).difficult,
                          ].map((level) {
                            return RadioListTile<String>(
                              title: Text(level),
                              value: level,
                              groupValue: selectedDifficulty,
                              onChanged: (value) {
                                setState(() {
                                  selectedDifficulty = value!;
                                });
                              },
                            );
                          }).toList(),
                    ),

                    SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => DominoVsComputerScreen(
                                    selectedDifficulty,
                                  ),
                            ),
                          );
                        },
                        icon: Icon(Icons.smart_toy),
                        label: Text(
                          S.of(context).startGame,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEC7A34),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showOnlineGameDialog(BuildContext context) {
    if (_currentUser == null) {
      _showLoginRequiredDialog(context, S.of(context).online);
      return;
    }
    if (isChess) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OnlineChessScreen(matchType: matchType),
        ),
      );
    } else if (isLudo) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OnlineLudoScreen(matchType: matchType),
        ),
      );
    } else if (isDomino) {
      final TextEditingController roomCodeController = TextEditingController();
      _showOnlineDialogDomino(context, roomCodeController);
    }
  }

  void _showOnlineDialogDomino(
    BuildContext context,
    TextEditingController roomCodeController,
  ) {
    if (_currentUser == null) {
      _showLoginRequiredDialog(context, S.of(context).online);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                Text(
                  S.of(context).playOnline,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 20),

                TextField(
                  controller: roomCodeController,
                  decoration: InputDecoration(
                    labelText: S.of(context).roomCode,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final roomCode = roomCodeController.text.trim();
                      if (roomCode.isNotEmpty) {
                        Navigator.of(context).pop();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(S.of(context).pleaseEnterValidCode),
                          ),
                        );
                      }
                    },
                    icon: Icon(Icons.login),
                    label: Text(
                      S.of(context).joinRoom,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEC7A34),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),

                SizedBox(height: 20),

                Divider(),

                SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final generatedRoomCode = 'ROOM12345';
                      Clipboard.setData(ClipboardData(text: generatedRoomCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${S.of(context).generatedAndCopiedCode} : $generatedRoomCode',
                          ),
                        ),
                      );
                      Navigator.of(context).pop();
                    },
                    icon: Icon(Icons.add),
                    label: Text(
                      S.of(context).createNewRoom,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEC7A34),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
