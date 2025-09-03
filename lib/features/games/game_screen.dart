import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tekoplay/features/games/chess_tutorial_screen.dart';

import '../../core/service/auth_service.dart';
import '../../generated/l10n.dart';
import '../../widgets/game_mode_widget.dart';
import '../home/home_screen.dart';
import 'chess_vs_cpu_screen.dart';
import 'domino_tutorial_screen.dart';
import 'domino_vs_cpu_screen.dart';
import 'ranking_screen.dart';
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

  bool get isChess => gameType == S.of(context).chess;

  bool get isDomino => gameType == S.of(context).domino;

  @override
  void initState() {
    super.initState();
    gameType = widget.gameType;
    matchType = widget.matchType;
    _loadCurrentUser();
  }

  void _loadCurrentUser() {
    setState(() {
      _currentUser = AuthService().getCurrentUser();
    });
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
                  Icon(Icons.message, size: 30.0, color: Colors.white),
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

  void _showFriendGameDialog(BuildContext context) {
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
                  S.of(context).playWithFriend,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 20),

                TextField(
                  decoration: InputDecoration(
                    labelText: S.of(context).searchByUsername,
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
                      Navigator.of(context).pop();
                    },
                    icon: Icon(Icons.search),
                    label: Text(
                      S.of(context).search,
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

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: 'https://tuapp.com/invite/12345'),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(S.of(context).linkCopied)),
                      );
                    },
                    icon: Icon(Icons.link),
                    label: Text(
                      S.of(context).copyLinkToShare,
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