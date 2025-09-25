import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tekoplay/core/service/firestore_service.dart';
import 'package:tekoplay/core/utils/game_type.dart';
import '../../../core/service/auth_service.dart';
import '../../../generated/l10n.dart';
import '../../adds/banner_ad_widget.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  _RankingScreenState createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  final Map<GameTypeModel, List<Map<String, dynamic>>> _leaderboards = {};
  final Map<GameTypeModel, int?> _userRanks = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: GameTypeModel.values.length,
      vsync: this,
    );
    _loadRankingData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRankingData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      for (GameTypeModel gameType in GameTypeModel.values) {
        final leaderboard = await _firestoreService.getGameLeaderboard(
          gameType: gameType,
          limit: 50,
        );
        final userRank = await _authService.getUserRankInGame(gameType);

        _leaderboards[gameType] = leaderboard;
        _userRanks[gameType] = userRank;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading ranking data: $e');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildUserRankCard(GameTypeModel gameType) {
    final userRank = _userRanks[gameType];
    if (userRank == null) {
      return Card(
        margin: EdgeInsets.all(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.grey),
              SizedBox(width: 12),
              Text(
                '${S.of(context).notRankingIn} ${gameType.displayName}',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    Color rankColor;
    IconData rankIcon;

    if (userRank <= 3) {
      rankColor = Colors.amber;
      rankIcon = Icons.emoji_events;
    } else if (userRank <= 10) {
      rankColor = Colors.blue;
      rankIcon = Icons.star;
    } else {
      rankColor = Colors.green;
      rankIcon = Icons.trending_up;
    }

    return Card(
      margin: EdgeInsets.all(16),
      color: Colors.black.withValues(alpha: 0.1),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(rankIcon, color: rankColor, size: 32),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${S.of(context).yourPositionIn} ${gameType.displayName}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '#$userRank',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: rankColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardList(GameTypeModel gameType) {
    final leaderboard = _leaderboards[gameType] ?? [];

    if (leaderboard.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.leaderboard, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              S.of(context).notRankingInfo,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16),
      itemCount: leaderboard.length,
      itemBuilder: (context, index) {
        final player = leaderboard[index];
        final position = index + 1;

        Color? cardColor;
        Widget? leadingWidget;

        switch (position) {
          case 1:
            cardColor = Colors.black.withValues(alpha: 0.1);
            leadingWidget = Icon(
              Icons.emoji_events,
              color: Colors.amber,
              size: 32,
            );
            break;
          case 2:
            cardColor = Colors.black.withValues(alpha: 0.1);
            leadingWidget = Icon(
              Icons.emoji_events,
              color: Colors.grey,
              size: 32,
            );
            break;
          case 3:
            cardColor = Colors.black.withValues(alpha: 0.1);
            leadingWidget = Icon(
              Icons.emoji_events,
              color: Colors.orange,
              size: 32,
            );
            break;
          default:
            leadingWidget = CircleAvatar(
              backgroundColor: const Color(0xFFEC7A34),
              child: Text(
                '$position',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
        }

        final currentUserId = _authService.getCurrentUser()?.uid;
        final isCurrentUser = player['userId'] == currentUserId;

        return Card(
          margin: EdgeInsets.symmetric(vertical: 4),
          color: isCurrentUser ? Colors.black.withValues(alpha: 0.1) : cardColor,
          child: ListTile(
            leading: leadingWidget,
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    player['userName'] ?? S.of(context).user,
                    style: TextStyle(
                      fontWeight:
                          isCurrentUser ? FontWeight.bold : FontWeight.normal,
                      color: isCurrentUser ? Colors.blue : null,
                    ),
                  ),
                ),
                if (isCurrentUser)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Tú',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
              ],
            ),
            subtitle: Text(
              '${player['gamesPlayed']} ${S.of(context).gamePlayed} • ${player['winRate'].toStringAsFixed(1)}% ${S.of(context).victories}',
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${player['points']} pts',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: const Color(0xFFEC7A34),
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          S.of(context).ranking,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFEC7A34),
        iconTheme: IconThemeData(color: Colors.white),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs:
              GameTypeModel.values.map((gameType) {
                return Tab(text: gameType.displayName);
              }).toList(),
        ),
      ),
      body:
          _isLoading
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        const Color(0xFFEC7A34),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      S.of(context).loadingRanking,
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
              : TabBarView(
                controller: _tabController,
                children:
                    GameTypeModel.values.map((gameType) {
                      return RefreshIndicator(
                        onRefresh: _loadRankingData,
                        child: Column(
                          children: [
                            _buildUserRankCard(gameType),
                            Expanded(child: _buildLeaderboardList(gameType)),
                            const BannerAdWidget(),
                          ],
                        ),
                      );
                    }).toList(),
              ),
    );
  }

  Widget getGameIcon(GameTypeModel gameType, {double size = 32}) {
    switch (gameType) {
      case GameTypeModel.chess:
        return Image.asset(
          'assets/images/chess.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
        );
      case GameTypeModel.domino:
        return Image.asset(
          'assets/images/domino.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
        );
    }
  }
}
