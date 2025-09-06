import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tekoplay/features/games/chess_tutorial_screen.dart';

import '../../core/models/multiplayer_game_match_chess.dart';
import '../../core/service/auth_service.dart';
import '../../core/service/notification_service.dart';
import '../../generated/l10n.dart';
import '../../widgets/game_mode_widget.dart';
import '../home/home_screen.dart';
import 'chess_vs_cpu_screen.dart';
import 'domino_tutorial_screen.dart';
import 'domino_vs_cpu_screen.dart';
import 'multiplayer_chess_screen.dart';
import 'ranking_screen.dart';
import 'game_history_screen.dart';

StreamSubscription<List<Map<String, dynamic>>>? _invitationsSubscription;
StreamSubscription<List<MultiplayerGameMatch>>? _activeGamesSubscription;

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

  bool get isChess => gameType == S.of(context).chess;

  bool get isDomino => gameType == S.of(context).domino;

  @override
  void initState() {
    super.initState();
    gameType = widget.gameType;
    matchType = widget.matchType;
    _loadCurrentUser();
    _initializeNotifications();
    _setupStreams();
  }

  void _loadCurrentUser() {
    setState(() {
      _currentUser = AuthService().getCurrentUser();
    });
  }

  void _initializeNotifications() {
    NotificationService().initialize();
  }

  void _setupStreams() {
    if (_currentUser != null) {
      // Stream de invitaciones
      _invitationsSubscription = GameInvitationService()
          .getPendingInvitations(_currentUser!.uid)
          .listen((invitations) {
        if (mounted) setState(() {});
      });

      // Stream de partidas activas
      _activeGamesSubscription = MultiplayerGameService()
          .getActiveGames(_currentUser!.uid)
          .listen((games) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _invitationsSubscription?.cancel();
    _activeGamesSubscription?.cancel();
    super.dispose();
  }

  Widget _buildUserAvatar() {
    if (_currentUser?.photoURL != null && _currentUser!.photoURL!.isNotEmpty) {
      return CircleAvatar(
        radius: 60,
        backgroundColor: Colors.grey[300],
        backgroundImage: NetworkImage(_currentUser!.photoURL!),
        onBackgroundImageError: (exception, stackTrace) {},
        child: _currentUser!.photoURL == null || _currentUser!.photoURL!.isEmpty
            ? const Icon(Icons.person, color: Colors.white, size: 60)
            : null,
      );
    } else {
      return CircleAvatar(
        radius: 60,
        backgroundImage: AssetImage('assets/images/img_perfil_unknown.png'),
        backgroundColor: Colors.grey[300],
      );
    }
  }

  Widget _buildActiveGamesWidget() {
    if (_currentUser == null) return SizedBox();

    return StreamBuilder<List<MultiplayerGameMatch>>(
      stream: MultiplayerGameService().getActiveGames(_currentUser!.uid),
      builder: (context, snapshot) {
        final games = snapshot.data ?? [];
        if (games.isEmpty) return SizedBox();

        return Container(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Partidas activas (${games.length})',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              SizedBox(height: 8),
              Container(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: games.length,
                  itemBuilder: (context, index) {
                    final game = games[index];
                    final opponentName = game.getOpponentName(_currentUser!.uid) ?? "Oponente";

                    return Container(
                      width: 180,
                      margin: EdgeInsets.only(right: 8),
                      child: Card(
                        color: game.isPlayerTurn(_currentUser!.uid) ? Colors.green[50] : Colors.white,
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MultiplayerChessScreen(
                                  gameId: game.id,
                                  isHost: game.hostId == _currentUser!.uid,
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'vs $opponentName',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Movimientos: ${game.moves.length}',
                                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                ),
                                SizedBox(height: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: game.isPlayerTurn(_currentUser!.uid) ? Colors.green : Colors.orange,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    game.isPlayerTurn(_currentUser!.uid) ? 'Tu turno' : 'Esperando',
                                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
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
            matchType == S.of(context).bet ? Icons.monetization_on : Icons.sports_esports,
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

                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: _currentUser!.photoURL != null
                      ? NetworkImage(_currentUser!.photoURL!)
                      : AssetImage('assets/images/img_perfil_unknown.png') as ImageProvider,
                  child: _currentUser!.photoURL == null
                      ? Icon(Icons.person, color: Colors.white, size: 40)
                      : null,
                ),

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFEC7A34),
      body: SafeArea(
        child: Column(
          children: [
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => MainScreen()),
                      );
                    },
                  ),
                  Row(
                    children: [
                      Text(
                        '500',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 5),
                      Image.asset('assets/images/coin.png', height: 30.0),
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
                    _buildActiveGamesWidget(),
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

                    GestureDetector(
                      onTap: _currentUser != null ? () => _showUserOptionsDialog(context) : null,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: _currentUser != null ? BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ) : null,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _currentUser?.displayName ?? S.of(context).anonymous,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                            if (_currentUser != null) ...[
                              SizedBox(width: 8),
                              Icon(
                                Icons.keyboard_arrow_down,
                                color: Colors.white,
                                size: 20,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
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
                    onPressed: () => _showFriendGameDialog(context),
                  ),
                  GameModeButton(
                    imagePath: 'assets/images/icon_lessons.png',
                    label: S.of(context).tutorial,
                    onPressed: () => _showTutorial(context),
                  ),
                  GameModeButton(
                    imagePath: 'assets/images/icon_play_vs_computer.png',
                    label: S.of(context).vsCpu,
                    onPressed: () => _showComputerGameDialog(context),
                  ),
                  GameModeButton(
                    imagePath: 'assets/images/icon_play_online.png',
                    label: S.of(context).online,
                    onPressed: () => _showOnlineGameDialog(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsIcon() {
    if (_currentUser == null) return Icon(Icons.message, size: 30.0, color: Colors.white);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: GameInvitationService().getPendingInvitations(_currentUser!.uid),
      builder: (context, snapshot) {
        final invitations = snapshot.data ?? [];
        final hasInvitations = invitations.isNotEmpty;

        return Stack(
          children: [
            IconButton(
              icon: Icon(Icons.notifications, color: Colors.white, size: 30),
              onPressed: () => _showNotificationsDialog(context, invitations),
            ),
            if (hasInvitations)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: EdgeInsets.all(2),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                  constraints: BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    '${invitations.length}',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // 7. Agregar estos métodos al final de la clase _GameScreenState:
  void _showNotificationsDialog(BuildContext context, List<Map<String, dynamic>> invitations) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: double.infinity,
          height: 400,
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Invitaciones', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                ],
              ),
              SizedBox(height: 16),
              Expanded(
                child: invitations.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none, size: 48, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No hay invitaciones', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
                    : ListView.builder(
                  itemCount: invitations.length,
                  itemBuilder: (context, index) {
                    final invitation = invitations[index];
                    return Card(
                      child: ListTile(
                        leading: Icon(Icons.sports_esports, color: Color(0xFFEC7A34)),
                        title: Text('${invitation['fromUserName']} te invita'),
                        subtitle: Text('${invitation['gameType']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () async {
                                final result = await GameInvitationService().respondToInvitation(invitation['id'], false);
                                if (result != null && result['success'] == true) {
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Invitación rechazada'), backgroundColor: Colors.orange),
                                  );
                                }
                              },
                              child: Text('Rechazar', style: TextStyle(color: Colors.red)),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                // Mostrar indicador de carga
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (context) => Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );

                                final result = await GameInvitationService().respondToInvitation(invitation['id'], true);

                                // Cerrar indicador de carga
                                Navigator.of(context).pop();

                                if (result != null && result['success'] == true && result['gameId'] != null) {
                                  // Cerrar diálogo de notificaciones
                                  Navigator.of(context).pop();

                                  // Navegar a la pantalla de juego
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => MultiplayerChessScreen(
                                        gameId: result['gameId'],
                                        isHost: false, // El que acepta siempre es guest
                                      ),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text('Error al aceptar invitación'),
                                        backgroundColor: Colors.red
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFFEC7A34),
                                foregroundColor: Colors.white,
                              ),
                              child: Text('Aceptar'),
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
    final TextEditingController emailController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          S.of(context).playWithFriend,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        IconButton(
                          icon: Icon(Icons.close),
                          onPressed: isLoading ? null : () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),

                    // Campo de email con listener
                    TextField(
                      controller: emailController,
                      enabled: !isLoading,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (value) {
                        // Actualizar el estado cuando cambie el texto
                        setState(() {});
                      },
                      decoration: InputDecoration(
                        labelText: 'Email del oponente',
                        hintText: 'ejemplo@email.com',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    SizedBox(height: 20),

                    // Botón enviar invitación
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: (isLoading || emailController.text.trim().isEmpty) ? null : () async {
                          setState(() => isLoading = true);

                          final error = await GameInvitationService().createInvitation(
                            fromUserId: _currentUser!.uid,
                            fromUserName: _currentUser!.displayName ?? 'Usuario',
                            toUserEmail: emailController.text.trim(),
                            gameType: gameType,
                          );

                          setState(() => isLoading = false);

                          if (error == null) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('¡Invitación enviada exitosamente!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error), backgroundColor: Colors.red),
                            );
                          }
                        },
                        icon: isLoading
                            ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Icon(Icons.send),
                        label: Text(isLoading ? 'Enviando...' : 'Enviar invitación'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEC7A34),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),

                    SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text('O', style: TextStyle(color: Colors.grey)),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),

                    SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isLoading ? null : () async {
                          Navigator.of(context).pop();
                          _createPublicGame(context);
                        },
                        icon: Icon(Icons.public),
                        label: Text('Crear partida pública'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),

                    SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isLoading ? null : () {
                          Navigator.of(context).pop();
                          _showPublicGamesDialog(context);
                        },
                        icon: Icon(Icons.search),
                        label: Text('Buscar partidas públicas'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  void _createPublicGame(BuildContext context) async {
    if (_currentUser == null) return;

    try {
      final gameId = await MultiplayerGameService().createGame(
        hostId: _currentUser!.uid,
        hostName: _currentUser!.displayName ?? 'Usuario',
        gameType: gameType,
        hostPhotoUrl: _currentUser!.photoURL,
      );

      if (gameId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MultiplayerChessScreen(gameId: gameId, isHost: true),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al crear la partida'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al crear la partida'), backgroundColor: Colors.red),
      );
    }
  }

  void _showPublicGamesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          child: Container(
            width: double.infinity,
            height: 400,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Partidas Públicas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    IconButton(icon: Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                  ],
                ),
                SizedBox(height: 16),
                Expanded(
                  child: FutureBuilder<List<MultiplayerGameMatch>>(
                    future: MultiplayerGameService().getWaitingGames(gameType: gameType),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      }

                      final games = snapshot.data ?? [];
                      final availableGames = games.where((game) => game.hostId != _currentUser?.uid).toList();

                      if (availableGames.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off, size: 48, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('No hay partidas disponibles', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: availableGames.length,
                        itemBuilder: (context, index) {
                          final game = availableGames[index];

                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.grey[300],
                                backgroundImage: game.hostPhotoUrl != null ? NetworkImage(game.hostPhotoUrl!) : null,
                                child: game.hostPhotoUrl == null ? Icon(Icons.person) : null,
                              ),
                              title: Text(game.hostName),
                              subtitle: Text('Creado hace ${_getTimeAgo(game.createdAt)}'),
                              trailing: ElevatedButton(
                                onPressed: () async {
                                  Navigator.of(context).pop();
                                  await _joinGame(context, game);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFFEC7A34),
                                  foregroundColor: Colors.white,
                                ),
                                child: Text('Unirse'),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _joinGame(BuildContext context, MultiplayerGameMatch game) async {
    if (_currentUser == null) return;

    try {
      final success = await MultiplayerGameService().joinGame(
        game.id,
        _currentUser!.uid,
        _currentUser!.displayName ?? 'Usuario',
        _currentUser!.photoURL,
      );

      if (success) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MultiplayerChessScreen(gameId: game.id, isHost: false),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo unir a la partida'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al unirse a la partida'), backgroundColor: Colors.red),
      );
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) return 'Ahora';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m';
    if (difference.inHours < 24) return '${difference.inHours}h';
    return '${difference.inDays}d';
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
                                  (context) =>
                                  ChessVsComputerScreen(selectedDifficulty),
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
    final TextEditingController roomCodeController = TextEditingController();
    if (isChess) {
      _showOnlineDialogChess(context, roomCodeController);
    } else if (isDomino) {
      _showOnlineDialogDomino(context, roomCodeController);
    }
  }

  void _showOnlineDialogChess(
      BuildContext context,
      TextEditingController roomCodeController,
      ) {
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

  void _showOnlineDialogDomino(
      BuildContext context,
      TextEditingController roomCodeController,
      ) {
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