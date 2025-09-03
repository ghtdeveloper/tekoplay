import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tekoplay/core/utils/game_type.dart';
import 'package:tekoplay/core/utils/game_result.dart';
import '../../core/models/game_stats.dart';
import '../../core/service/auth_service.dart';
import '../../core/models/game_match.dart';
import '../../generated/l10n.dart';

class GameHistoryScreen extends StatefulWidget {
  const GameHistoryScreen({super.key});

  @override
  _GameHistoryScreenState createState() => _GameHistoryScreenState();
}

class _GameHistoryScreenState extends State<GameHistoryScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final AuthService _authService = AuthService();

  final Map<GameTypeModel, List<GameMatch>> _gameHistory = {};
  final Map<GameTypeModel, GameStats> _gameStats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: GameTypeModel.values.length + 1,
      vsync: this,
    );
    _loadGameHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadGameHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      for (GameTypeModel gameType in GameTypeModel.values) {
        final history = await _authService.getCurrentUserGameHistory(
          gameType: gameType,
          limit: 100,
        );

        final stats = await _authService.getCurrentUserGameStats(gameType);

        _gameHistory[gameType] = history;
        _gameStats[gameType] = stats ?? GameStats.initial(gameType);
      }
      final allHistory = await _authService.getCurrentUserGameHistory(
        limit: 100,
      );
      _gameHistory[GameTypeModel.chess] = allHistory;
    } catch (e) {
      print('Error loading game history: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildSummaryCard(GameTypeModel? gameType) {
    if (gameType == null) {
      int totalGames = 0;
      int totalWins = 0;
      int totalPoints = 0;

      for (GameStats stats in _gameStats.values) {
        totalGames += stats.gamesPlayed;
        totalWins += stats.wins;
        totalPoints += stats.points;
      }

      double winRate = totalGames > 0 ? (totalWins / totalGames) * 100 : 0;

      return Card(
        margin: EdgeInsets.all(16),
        elevation: 4,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.bar_chart,
                    color: const Color(0xFFEC7A34),
                    size: 28,
                  ),
                  SizedBox(width: 12),
                  Text(
                    S.of(context).generalSummary,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      S.of(context).games,
                      '$totalGames',
                      Icons.games,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      S.of(context).victories,
                      '$totalWins',
                      Icons.emoji_events,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      S.of(context).victoriesPct,
                      '${winRate.toStringAsFixed(1)}%',
                      Icons.trending_up,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      S.of(context).totalPoints,
                      '$totalPoints',
                      Icons.star,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final stats = _gameStats[gameType] ?? GameStats.initial(gameType);

    return Card(
      margin: EdgeInsets.all(16),
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                getGameIcon(gameType),
                SizedBox(width: 12),
                Text(
                  '${gameType.displayName} - ${S.of(context).stats}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    S.of(context).games,
                    '${stats.gamesPlayed}',
                    Icons.games,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    S.of(context).point,
                    '${stats.points}',
                    Icons.star,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    S.of(context).victories,
                    '${stats.wins}',
                    Icons.emoji_events,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    S.of(context).defeats,
                    '${stats.losses}',
                    Icons.close,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    S.of(context).ties,
                    '${stats.draws}',
                    Icons.handshake,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    S.of(context).victoriesPct,
                    '${stats.winRate.toStringAsFixed(1)}%',
                    Icons.trending_up,
                  ),
                ),
              ],
            ),
            if (stats.averageGameTimeMinutes > 0) ...[
              SizedBox(height: 12),
              _buildStatItem(
                S.of(context).averageTime,
                '${stats.averageGameTimeMinutes.toStringAsFixed(1)} min',
                Icons.access_time,
                fullWidth: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon, {
    bool fullWidth = false,
  }) {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child:
          fullWidth
              ? Row(
                children: [
                  Icon(icon, color: const Color(0xFFEC7A34), size: 20),
                  SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Spacer(),
                  Text(
                    value,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              )
              : Column(
                children: [
                  Icon(icon, color: const Color(0xFFEC7A34), size: 20),
                  SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
    );
  }

  Widget _buildGameHistoryList(GameTypeModel? gameType) {
    List<GameMatch> matches;

    if (gameType == null) {
      matches = [];
      for (List<GameMatch> gameMatches in _gameHistory.values) {
        matches.addAll(gameMatches);
      }
      matches.sort((a, b) => b.playedAt.compareTo(a.playedAt));
    } else {
      matches = _gameHistory[gameType] ?? [];
    }

    if (matches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              gameType == null
                  ? S.of(context).notPlayedGameYet
                  : '${S.of(context).youHaventPlayed} ${gameType.displayName} ${S.of(context).still}',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16),
      itemCount: matches.length,
      itemBuilder: (context, index) {
        final match = matches[index];
        return _buildMatchCard(match);
      },
    );
  }

  Widget _buildMatchCard(GameMatch match) {
    Color resultColor;
    IconData resultIcon;
    String resultText;

    switch (match.result) {
      case GameResultModel.win:
        resultColor = Colors.green;
        resultIcon = Icons.emoji_events;
        resultText = S.of(context).wins;
        break;
      case GameResultModel.loss:
        resultColor = Colors.red;
        resultIcon = Icons.close;
        resultText = S.of(context).lose;
        break;
      case GameResultModel.draw:
        resultColor = Colors.orange;
        resultIcon = Icons.handshake;
        resultText = S.of(context).tie;
        break;
    }

    return Card(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: resultColor.withOpacity(0.2),
          child: Icon(resultIcon, color: resultColor),
        ),
        title: Row(
          children: [
            getGameIcon(match.gameType),
            SizedBox(width: 8),
            Text(match.gameType.displayName),
            Spacer(),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: resultColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                resultText,
                style: TextStyle(
                  color: resultColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            if (match.opponentName != null) Text('vs ${match.opponentName}'),
            Row(
              children: [
                Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(
                  '${match.durationMinutes} min',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                SizedBox(width: 16),
                Icon(Icons.calendar_today, size: 12, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(match.playedAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${match.pointsEarned >= 0 ? '+' : ''}${match.pointsEarned}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: match.pointsEarned >= 0 ? Colors.green : Colors.red,
                fontSize: 16,
              ),
            ),
            Text(
              'pts',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          S.of(context).gameHistory,
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
          isScrollable: true,
          tabs: [
            Tab(text: S.of(context).all, icon: Icon(Icons.all_inclusive)),
            ...GameTypeModel.values.map((gameType) {
              return Tab(text: gameType.displayName);
            }).toList(),
          ],
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
                      S.of(context).loadingHistory,
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
              : TabBarView(
                controller: _tabController,
                children: [
                  RefreshIndicator(
                    onRefresh: _loadGameHistory,
                    child: Column(
                      children: [
                        _buildSummaryCard(null),
                        Expanded(child: _buildGameHistoryList(null)),
                      ],
                    ),
                  ),
                  ...GameTypeModel.values.map((gameType) {
                    return RefreshIndicator(
                      onRefresh: _loadGameHistory,
                      child: Column(
                        children: [
                          _buildSummaryCard(gameType),
                          Expanded(child: _buildGameHistoryList(gameType)),
                        ],
                      ),
                    );
                  }).toList(),
                ],
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
