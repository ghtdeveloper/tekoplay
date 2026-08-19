import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tekoplay/core/utils/game_type.dart';
import 'package:tekoplay/core/utils/game_result.dart';
import '../../../core/models/game_stats.dart';
import '../../../core/service/auth_service.dart';
import '../../../core/models/game_match.dart';
import '../../../generated/l10n.dart';
import '../../adds/banner_ad_widget.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class GameHistoryScreen extends StatefulWidget {
  const GameHistoryScreen({super.key});

  @override
  State<GameHistoryScreen> createState() => _GameHistoryScreenState();
}

class _GameHistoryScreenState extends State<GameHistoryScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  final AuthService _authService = AuthService();
  bool _isScreenKeepOnActive = false;
  final Map<GameTypeModel, List<GameMatch>> _gameHistory = {};
  List<GameMatch> _allHistory = [];
  final Map<GameTypeModel, GameStats> _gameStats = {};
  bool _isLoading = true;

  static const _kAccent = Color(0xFFEC7A34);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(
      length: GameTypeModel.values.length + 1,
      vsync: this,
    );
    _loadGameHistory();
    _enableWakeLock();
  }

  @override
  void dispose() {
    _tabController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _disableWakeLock();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        if (_isScreenKeepOnActive) _enableWakeLock();
        break;
      case AppLifecycleState.paused:
        _disableWakeLock();
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
        break;
    }
  }

  Future<void> _enableWakeLock() async {
    try {
      if (!await WakelockPlus.enabled) {
        await WakelockPlus.enable();
        if (mounted) setState(() => _isScreenKeepOnActive = true);
        if (kDebugMode) print('WakeLock enabled - screen will stay on');
      }
    } catch (e) {
      if (kDebugMode) print('Error enabling WakeLock: $e');
    }
  }

  Future<void> _disableWakeLock() async {
    try {
      if (await WakelockPlus.enabled) {
        await WakelockPlus.disable();
        if (mounted) setState(() => _isScreenKeepOnActive = false);
        if (kDebugMode) print('WakeLock disabled - screen can turn off normally');
      }
    } catch (e) {
      if (kDebugMode) print('Error disabling WakeLock: $e');
    }
  }

  Future<void> _loadGameHistory() async {
    setState(() => _isLoading = true);

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

      _allHistory = await _authService.getCurrentUserGameHistory(
        limit: 100,
      );

      if (_allHistory.isEmpty) {
        final merged = <GameMatch>[];
        for (final matches in _gameHistory.values) {
          merged.addAll(matches);
        }
        merged.sort((a, b) => b.playedAt.compareTo(a.playedAt));
        _allHistory = merged;
      }
    } catch (e) {
      if (kDebugMode) print('Error loading game history: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart, color: _kAccent, size: 24),
                const SizedBox(width: 10),
                Text(
                  S.of(context).generalSummary,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    S.of(context).games, '$totalGames', Icons.games,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatItem(
                    S.of(context).victories, '$totalWins', Icons.emoji_events,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    S.of(context).victoriesPct,
                    '${winRate.toStringAsFixed(1)}%',
                    Icons.trending_up,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatItem(
                    S.of(context).totalPoints, '$totalPoints', Icons.star,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final stats = _gameStats[gameType] ?? GameStats.initial(gameType);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              getGameIcon(gameType, size: 24),
              const SizedBox(width: 10),
              Text(
                '${gameType.displayName} - ${S.of(context).stats}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  S.of(context).games, '${stats.gamesPlayed}', Icons.games,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatItem(
                  S.of(context).point, '${stats.points}', Icons.star,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  S.of(context).victories, '${stats.wins}', Icons.emoji_events,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatItem(
                  S.of(context).defeats, '${stats.losses}', Icons.close,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  S.of(context).ties, '${stats.draws}', Icons.handshake,
                ),
              ),
              const SizedBox(width: 8),
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
            const SizedBox(height: 8),
            _buildStatItem(
              S.of(context).averageTime,
              '${stats.averageGameTimeMinutes.toStringAsFixed(1)} min',
              Icons.access_time,
              fullWidth: true,
            ),
          ],
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: fullWidth
          ? Row(
              children: [
                Icon(icon, color: _kAccent, size: 18),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const Spacer(),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            )
          : Column(
              children: [
                Icon(icon, color: _kAccent, size: 18),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildGameHistoryList(GameTypeModel? gameType) {
    List<GameMatch> matches;

    if (gameType == null) {
      matches = _allHistory;
    } else {
      matches = _gameHistory[gameType] ?? [];
    }

    if (matches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              gameType == null
                  ? S.of(context).notPlayedGameYet
                  : '${S.of(context).youHaventPlayed} ${gameType.displayName} ${S.of(context).still}',
              style: TextStyle(fontSize: 15, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: matches.length,
      itemBuilder: (context, index) => _buildMatchCard(matches[index]),
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

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: resultColor.withValues(alpha: 0.12),
          child: Icon(resultIcon, color: resultColor, size: 22),
        ),
        title: Row(
          children: [
            getGameIcon(match.gameType, size: 20),
            const SizedBox(width: 8),
            Text(
              match.gameType.displayName,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: resultColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                resultText,
                style: TextStyle(
                  color: resultColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            if (match.opponentName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'vs ${match.opponentName}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            Row(
              children: [
                Icon(Icons.access_time, size: 12, color: Colors.grey[400]),
                const SizedBox(width: 3),
                Text(
                  '${match.durationMinutes} min',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
                const SizedBox(width: 14),
                Icon(Icons.calendar_today, size: 12, color: Colors.grey[400]),
                const SizedBox(width: 3),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(match.playedAt),
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
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
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
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
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFEC7A34),
                Color(0xFFE06820),
                Color(0xFFD45A15),
              ],
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          isScrollable: true,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 13),
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.all_inclusive, size: 18),
                  const SizedBox(width: 6),
                  Text(S.of(context).all),
                ],
              ),
            ),
            ...GameTypeModel.values.map((gameType) {
              return Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    getGameIcon(gameType, size: 18),
                    const SizedBox(width: 6),
                    Text(gameType.displayName),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(_kAccent),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          S.of(context).loadingHistory,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // "All" tab
                      RefreshIndicator(
                        color: _kAccent,
                        onRefresh: _loadGameHistory,
                        child: Column(
                          children: [
                            _buildSummaryCard(null),
                            Expanded(child: _buildGameHistoryList(null)),
                          ],
                        ),
                      ),
                      // Per-game tabs
                      ...GameTypeModel.values.map((gameType) {
                        return RefreshIndicator(
                          color: _kAccent,
                          onRefresh: _loadGameHistory,
                          child: Column(
                            children: [
                              _buildSummaryCard(gameType),
                              Expanded(
                                child: _buildGameHistoryList(gameType),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
          ),
          const BannerAdWidget(),
        ],
      ),
    );
  }

  Widget getGameIcon(GameTypeModel gameType, {double size = 32}) {
    switch (gameType) {
      case GameTypeModel.chess:
        return Image.asset('assets/images/chess.png',
            width: size, height: size, fit: BoxFit.contain);
      case GameTypeModel.domino:
        return Image.asset('assets/images/domino.png',
            width: size, height: size, fit: BoxFit.contain);
      case GameTypeModel.ludo:
        return Image.asset('assets/images/parchis.png',
            width: size, height: size, fit: BoxFit.contain);
      case GameTypeModel.dominoPase:
        return Image.asset('assets/images/domino.png',
            width: size, height: size, fit: BoxFit.contain);
    }
  }
}
