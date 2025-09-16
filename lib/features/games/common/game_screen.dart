import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tekoplay/features/games/chess/chess_tutorial_screen.dart';
import 'package:tekoplay/features/games/common/ranking_screen.dart';

import '../../../core/models/multiplayer_game_match_chess.dart';
import '../../../core/service/auth_service.dart';
import '../../../core/service/firestore_service.dart';
import '../../../core/service/notification_service.dart';
import '../../../core/service/payment_service.dart';
import '../../../generated/l10n.dart';
import '../../../widgets/game_mode_widget.dart';
import '../../adds/BannerAdWidget.dart';
import '../../coins/coin_purchase_dialog.dart';
import '../../coins/diamond_purchase_dialog.dart';
import '../../home/home_screen.dart';
import '../../settings/settings_screen.dart';
import '../chess/chess_vs_cpu_screen.dart';
import '../chess/multiplayer_chess_screen.dart';
import '../chess/online_chess_screen.dart';
import '../domino/domino_tutorial_screen.dart';
import '../domino/domino_vs_cpu_screen.dart';
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

class _GameScreenState extends State<GameScreen> {
  late String gameType;
  late String matchType;
  User? _currentUser;
  String? _currentPhotoUrl;
  int? _userDiamonds;
  int? _userCoins;
  String? _anonymousPlayerName;
  bool _isAnonymousMode = false;
  late AudioPlayer _audioPlayer;
  double _currentVolume = 0.5;
  bool _isDisposed = false;
  bool _isInitialized = false;
  StreamSubscription<List<Map<String, dynamic>>>? _invitationsSubscription;
  StreamSubscription<List<MultiplayerGameMatch>>? _activeGamesSubscription;
  StreamSubscription<DocumentSnapshot>? _diamondsSubscription;

  bool get isChess => gameType == S.of(context).chess;

  bool get isDomino => gameType == S.of(context).domino;

  @override
  void initState() {
    super.initState();
    gameType = widget.gameType;
    matchType = widget.matchType;
    _initializeAsync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setupWalletInfoUser();
  }

  void _setupWalletInfoUser() {
    if (_currentUser == null) return;

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
              });
            }
          },
          onError: (error) {
            print('Error listening to diamonds: $error');
            if (mounted && !_isDisposed) {
              setState(() {
                _userDiamonds = 0;
                _userCoins = 0;
              });
            }
          },
        );
  }

  Future<void> _initializeAsync() async {
    try {
      if (_isDisposed) return;
      _audioPlayer = AudioPlayer();
      _loadCurrentUser();
      if (_isDisposed) return;
      _initializeNotifications();
      if (_isDisposed) return;
      _setupStreams();
      if (_isDisposed) return;
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
      print('Error en inicialización: $e');
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
      await _audioPlayer.setVolume(newVolume);
      if (mounted) setState(() {});
    } catch (e) {
      print('Error actualizando volumen: $e');
    }
  }

  void _enableAnonymousMode() async {
    if (_isDisposed) return;

    try {
      final playerName = await AuthService().enableAnonymousMode();
      if (playerName != null && mounted && !_isDisposed) {
        setState(() {
          _anonymousPlayerName = playerName;
          _isAnonymousMode = true;
        });
      }
    } catch (e) {
      print('Error en modo anónimo: $e');
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
        });
      }

      if (user != null && !_isDisposed) {
        final userData = await FirestoreService().getUser(user.uid);
        if (userData != null && mounted && !_isDisposed) {
          setState(() {
            _currentPhotoUrl = userData.urlPhoto;
          });
        }
      }
    } catch (e) {
      print('Error cargando usuario: $e');
    }
  }

  void _initializeNotifications() {
    if (_isDisposed) return;

    try {
      NotificationService().initialize();
    } catch (e) {
      print('Error inicializando notificaciones: $e');
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
            print('Error en stream de invitaciones: $error');
          })
          .listen(
            (invitations) {
              if (mounted && !_isDisposed) {
                setState(() {});
              }
            },
            onError: (error) {
              print('Error en subscription de invitaciones: $error');
            },
          );

      _activeGamesSubscription = MultiplayerGameService()
          .getActiveGames(_currentUser!.uid)
          .handleError((error) {
            print('Error en stream de juegos: $error');
          })
          .listen(
            (games) {
              if (mounted && !_isDisposed) {
                setState(() {});
              }
            },
            onError: (error) {
              print('Error en subscription de juegos: $error');
            },
          );
    } catch (e) {
      print('Error configurando streams: $e');
    }
  }

  void _showCoinPurchaseDialog() {
    showCoinPurchaseDialog(
      context,
      onPurchase: (coinAmount, price) {
        print('Comprando $coinAmount monedas por \$${price} CLP');
        _processCoinPurchase(coinAmount, price);
      },
    );
  }

  void _showDiamondPurchaseDialog() {
    showDiamondPurchaseDialog(
      context,
      onPurchase: (coinAmount, price) {
        _processCoinPurchase(coinAmount, price);
      },
    );
  }

  Future<void> _processCoinPurchase(int coins, int price) async {
    try {
      final paymentService = PaymentService();
      final canPay = await paymentService.canMakePayments();
      if (!canPay) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google Pay no está disponible en este dispositivo'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final result = await paymentService.makePayment(
        label: '$coins Monedas',
        amount: price.toDouble(),
        productId: 'coins_$coins',
      );

      if (result != null && result['success'] == true) {
        setState(() {
          _userCoins = (_userCoins ?? 0) + coins;
        });

        if (_currentUser != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(_currentUser!.uid)
              .update({'coins': FieldValue.increment(coins)});
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Compra exitosa! +$coins monedas'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error en compra: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error procesando el pago'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _processDiamondPurchase(int diamond, int price) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(child: CircularProgressIndicator()),
      );
      // Simular procesamiento de pago
      await Future.delayed(Duration(seconds: 2));
      // Actualizar diamantes del usuario
      setState(() {
        _userDiamonds = (_userDiamonds ?? 0) + diamond;
      });
      Navigator.of(context).pop(); // Cerrar loading
      // Mostrar confirmación
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Compra exitosa! +$diamond diamantes'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Navigator.of(context).pop(); // Cerrar loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error en la compra'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _invitationsSubscription?.cancel();
    _activeGamesSubscription?.cancel();
    _diamondsSubscription?.cancel();
    _audioPlayer.dispose();
    if (_isAnonymousMode) {
      try {
        AuthService().disableAnonymousMode();
      } catch (e) {
        print('Error deshabilitando modo anónimo: $e');
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
                  Icon(
                    Icons.person_outline,
                    size: 48,
                    color: Color(0xFFEC7A34),
                  ),
                  SizedBox(height: 16),
                  Text(
                    S.of(context).playingAsGuest,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '${S.of(context).yourTemporaryName}: $_anonymousPlayerName',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 16),
                  Text(
                    S.of(context).loginToAccessFeatures,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14),
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(S.of(context).continueAsGuest),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
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
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFFEC7A34),
                            foregroundColor: Colors.white,
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
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      if (!_isDisposed) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => MainScreen()),
                        );
                      }
                    },
                  ),
                  Row(
                    children: [
                      Text(
                        matchType == S.of(context).bet
                            ? '${(_userDiamonds ?? 0.0).toInt()}'
                            : matchType == S.of(context).fun
                            ? '${(_userCoins ?? 0.0).toInt()}'
                            : '0',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 5),
                      if (matchType == S.of(context).fun)
                        Image.asset('assets/images/coin.png', height: 30.0)
                      else if (matchType == S.of(context).bet)
                        Image.asset('assets/images/diamond.png', height: 30.0)
                      else
                        SizedBox(width: 30.0),
                      IconButton(
                        icon: Icon(Icons.add_circle, color: Colors.white),
                        onPressed:
                            () => {
                              if (matchType == S.of(context).fun)
                                _showCoinPurchaseDialog()
                              else if (matchType == S.of(context).bet)
                                _showDiamondPurchaseDialog(),
                            },
                      ),
                    ],
                  ),
                  _buildNotificationsIcon(),
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

  Widget _buildNotificationsIcon() {
    if (_currentUser == null || !_isInitialized) {
      return Icon(Icons.message, size: 30.0, color: Colors.white);
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: GameInvitationService().getPendingInvitations(_currentUser!.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print('Error en StreamBuilder de notificaciones: ${snapshot.error}');
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
                                  child: ListTile(
                                    leading: Icon(
                                      Icons.sports_esports,
                                      color: Color(0xFFEC7A34),
                                    ),
                                    title: Text(
                                      '${invitation['fromUserName']} ${S.of(context).invitesYou}',
                                    ),
                                    subtitle: Text('${invitation['gameType']}'),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextButton(
                                          onPressed: () async {
                                            final result =
                                                await GameInvitationService()
                                                    .respondToInvitation(
                                                      invitation['id'],
                                                      false,
                                                    );
                                            if (result != null &&
                                                result['success'] == true) {
                                              Navigator.of(context).pop();
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    S
                                                        .of(context)
                                                        .invitationRejected,
                                                  ),
                                                  backgroundColor:
                                                      Colors.orange,
                                                ),
                                              );
                                            }
                                          },
                                          child: Text(
                                            S.of(context).reject,
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                        ElevatedButton(
                                          onPressed: () async {
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

                                            Navigator.of(context).pop();

                                            if (result != null &&
                                                result['success'] == true &&
                                                result['gameId'] != null) {
                                              Navigator.of(context).pop();

                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder:
                                                      (context) =>
                                                          MultiplayerChessScreen(
                                                            gameId:
                                                                result['gameId'],
                                                            isHost: false,
                                                            matchType:
                                                                widget
                                                                    .matchType,
                                                          ),
                                                ),
                                              );
                                            } else {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    S
                                                        .of(context)
                                                        .errorAcceptedInvitation,
                                                  ),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Color(0xFFEC7A34),
                                            foregroundColor: Colors.white,
                                          ),
                                          child: Text(S.of(context).accept),
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

    final TextEditingController emailController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
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
                    SizedBox(height: 20),

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
                    SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed:
                            (isLoading || emailController.text.trim().isEmpty)
                                ? null
                                : () async {
                                  setState(() => isLoading = true);

                                  final error = await GameInvitationService()
                                      .createInvitation(
                                        fromUserId: _currentUser!.uid,
                                        fromUserName:
                                            _currentUser!.displayName ??
                                            'Usuario',
                                        toUserEmail:
                                            emailController.text.trim(),
                                        gameType: gameType,
                                      );

                                  setState(() => isLoading = false);

                                  if (error == null) {
                                    Navigator.of(context).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          S
                                              .of(context)
                                              .successfulSentInvitation,
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
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
            );
          },
        );
      },
    );
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
  }

  void _showComputerGameDialog(BuildContext context) {
    if (isChess) {
      _showChessCpuDialog(context);
    } else if (isDomino) {
      _showDominoCpuDialog(context);
    }
  }

  void _showChessCpuDialog(BuildContext context) {
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
                                  (context) => ChessVsComputerScreen(
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
                        print('Unirse a la sala con código: $roomCode');
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
                      print('Sala creada: $generatedRoomCode');
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
