import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tekoplay/core/service/firestore_service.dart';
import 'package:tekoplay/core/utils/game_type.dart';
import '../../../core/service/auth_service.dart';
import '../../../generated/l10n.dart';
import '../../adds/banner_ad_widget.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  static const _kPageSize = 20;
  static const _kAccent = Color(0xFFEC7A34);
  static const _kGold = Color(0xFFFFD700);
  static const _kSilver = Color(0xFF9E9E9E);
  static const _kBronze = Color(0xFFCD7F32);

  final Map<GameTypeModel, List<Map<String, dynamic>>> _leaderboards = {};
  final Map<GameTypeModel, DocumentSnapshot?> _lastDocuments = {};
  final Map<GameTypeModel, bool> _hasMore = {};
  final Map<GameTypeModel, bool> _isLoadingMore = {};
  bool _isLoading = true;
  bool _isScreenKeepOnActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(
      length: GameTypeModel.values.length,
      vsync: this,
    );
    _loadInitialData();
    _enableWakeLock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
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

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      for (final gameType in GameTypeModel.values) {
        await _loadPage(gameType, isInitial: true);
      }
    } catch (e) {
      if (kDebugMode) print('Error loading ranking data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPage(GameTypeModel gameType, {bool isInitial = false}) async {
    if (!isInitial && (_isLoadingMore[gameType] == true || _hasMore[gameType] == false)) {
      return;
    }

    if (!isInitial) {
      setState(() => _isLoadingMore[gameType] = true);
    }

    try {
      final page = await _firestoreService.getGameLeaderboardPaginated(
        gameType: gameType,
        pageSize: _kPageSize,
        startAfterDoc: isInitial ? null : _lastDocuments[gameType],
      );

      if (mounted) {
        setState(() {
          if (isInitial) {
            _leaderboards[gameType] = page.items;
          } else {
            _leaderboards[gameType] = [...(_leaderboards[gameType] ?? []), ...page.items];
          }
          _lastDocuments[gameType] = page.lastDocument;
          _hasMore[gameType] = page.hasMore;
          _isLoadingMore[gameType] = false;
        });
      }
    } catch (e) {
      if (kDebugMode) print('Error loading page: $e');
      if (mounted) setState(() => _isLoadingMore[gameType] = false);
    }
  }

  Future<void> _refreshData() async {
    for (final gameType in GameTypeModel.values) {
      _lastDocuments[gameType] = null;
      _hasMore[gameType] = true;
    }
    await _loadInitialData();
  }

  Widget _buildPodium(GameTypeModel gameType) {
    final leaderboard = _leaderboards[gameType] ?? [];
    if (leaderboard.length < 3) return const SizedBox.shrink();

    final currentUserId = _authService.getCurrentUser()?.uid;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.fromLTRB(8, 20, 8, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: _podiumSlot(leaderboard[1], 2, currentUserId, 70)),
          const SizedBox(width: 6),
          Expanded(child: _podiumSlot(leaderboard[0], 1, currentUserId, 100)),
          const SizedBox(width: 6),
          Expanded(child: _podiumSlot(leaderboard[2], 3, currentUserId, 50)),
        ],
      ),
    );
  }

  Widget _podiumSlot(
      Map<String, dynamic> player, int rank, String? currentUserId, double height) {
    final isMe = player['userId'] == currentUserId;
    final Color medalColor =
        rank == 1 ? _kGold : rank == 2 ? _kSilver : _kBronze;
    final double avatarSize = rank == 1 ? 54 : 42;
    final name = player['userName'] ?? S.of(context).user;
    final pts = player['points'] ?? 0;
    final winRate = (player['winRate'] as num?)?.toDouble() ?? 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (rank == 1)
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
            ).createShader(bounds),
            child: const Icon(Icons.workspace_premium, size: 32, color: Colors.white),
          )
        else
          Icon(Icons.emoji_events, size: 24, color: medalColor),
        const SizedBox(height: 4),

        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: medalColor, width: rank == 1 ? 3 : 2),
            boxShadow: [
              if (rank == 1)
                BoxShadow(
                  color: _kGold.withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: CircleAvatar(
            radius: avatarSize / 2,
            backgroundColor: Colors.grey[100],
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: rank == 1 ? 22 : 16,
                fontWeight: FontWeight.w900,
                color: Colors.black87,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),

        Text(
          isMe ? S.of(context).me : _truncateName(name),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isMe ? _kAccent : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: rank == 1 ? 13 : 11,
          ),
        ),

        Text(
          '$pts pts',
          style: TextStyle(
            color: medalColor == _kSilver ? Colors.grey[700] : medalColor,
            fontWeight: FontWeight.bold,
            fontSize: rank == 1 ? 15 : 12,
          ),
        ),

        const SizedBox(height: 3),
        _miniWinBar(winRate, medalColor, rank == 1 ? 54 : 42),

        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                medalColor.withValues(alpha: 0.3),
                medalColor.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border(
              top: BorderSide(color: medalColor.withValues(alpha: 0.6), width: 2),
              left: BorderSide(color: medalColor.withValues(alpha: 0.2)),
              right: BorderSide(color: medalColor.withValues(alpha: 0.2)),
            ),
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: TextStyle(
                fontSize: rank == 1 ? 28 : 20,
                fontWeight: FontWeight.w900,
                color: Colors.black.withValues(alpha: 0.15),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _miniWinBar(double winRate, Color color, double width) {
    return SizedBox(
      width: width,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: winRate / 100,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${winRate.toStringAsFixed(0)}%',
            style: TextStyle(color: Colors.grey[600], fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerRow(Map<String, dynamic> player, int position) {
    final currentUserId = _authService.getCurrentUser()?.uid;
    final isMe = player['userId'] == currentUserId;
    final pts = player['points'] ?? 0;
    final winRate = (player['winRate'] as num?)?.toDouble() ?? 0.0;
    final gamesPlayed = player['gamesPlayed'] ?? 0;
    final name = player['userName'] ?? S.of(context).user;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? _kAccent.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMe ? _kAccent.withValues(alpha: 0.4) : Colors.grey[200]!,
          width: isMe ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '$position',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isMe ? _kAccent : Colors.grey[600],
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: isMe ? FontWeight.bold : FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _kAccent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          S.of(context).me,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.sports_esports,
                        size: 11, color: Colors.grey[400]),
                    const SizedBox(width: 3),
                    Text(
                      '$gamesPlayed',
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 44,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: winRate / 100,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation(
                            winRate >= 60
                                ? Colors.green
                                : winRate >= 30
                                    ? Colors.amber
                                    : Colors.redAccent,
                          ),
                          minHeight: 4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${winRate.toStringAsFixed(0)}%',
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$pts',
              style: TextStyle(
                color: isMe ? _kAccent : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(GameTypeModel gameType) {
    final leaderboard = _leaderboards[gameType] ?? [];

    if (leaderboard.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.leaderboard_rounded, size: 64,
                color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              S.of(context).notRankingInfo,
              style: TextStyle(fontSize: 15, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    final hasTop3 = leaderboard.length >= 3;
    final restOfList = hasTop3 ? leaderboard.sublist(3) : leaderboard;
    final startIndex = hasTop3 ? 4 : 1;
    final hasMore = _hasMore[gameType] ?? false;
    final isLoadingMore = _isLoadingMore[gameType] ?? false;

    return RefreshIndicator(
      color: _kAccent,
      onRefresh: _refreshData,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollEndNotification &&
              notification.metrics.pixels >=
                  notification.metrics.maxScrollExtent - 200) {
            _loadPage(gameType);
          }
          return false;
        },
        child: CustomScrollView(
          slivers: [
            if (hasTop3) SliverToBoxAdapter(child: _buildPodium(gameType)),

            if (hasTop3)
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                          child: Container(height: 1, color: Colors.grey[300])),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          S.of(context).ranking,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      Expanded(
                          child: Container(height: 1, color: Colors.grey[300])),
                    ],
                  ),
                ),
              ),

            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) =>
                    _buildPlayerRow(restOfList[index], index + startIndex),
                childCount: restOfList.length,
              ),
            ),

            if (isLoadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(_kAccent),
                      ),
                    ),
                  ),
                ),
              ),

            if (!hasMore && restOfList.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      '- - -',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ),
                ),
              ),

            const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
          ],
        ),
      ),
    );
  }

  String _truncateName(String name) {
    return name.length > 12 ? '${name.substring(0, 10)}..' : name;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.leaderboard_rounded, size: 22),
            const SizedBox(width: 10),
            Text(
              S.of(context).ranking,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
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
          labelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontSize: 13),
          tabs: GameTypeModel.values.map((gameType) {
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _getGameTabIcon(gameType),
                  const SizedBox(width: 6),
                  Text(gameType.displayName),
                ],
              ),
            );
          }).toList(),
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
                        const SizedBox(
                          width: 44,
                          height: 44,
                          child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(_kAccent),
                            strokeWidth: 3,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          S.of(context).loadingRanking,
                          style: TextStyle(
                              fontSize: 15, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: GameTypeModel.values
                        .map((gameType) => _buildTabContent(gameType))
                        .toList(),
                  ),
          ),
          const BannerAdWidget(),
        ],
      ),
    );
  }

  Widget _getGameTabIcon(GameTypeModel gameType) {
    final String asset;
    switch (gameType) {
      case GameTypeModel.chess:
        asset = 'assets/images/chess.png';
        break;
      case GameTypeModel.domino:
      case GameTypeModel.dominoPase:
        asset = 'assets/images/domino.png';
        break;
      case GameTypeModel.ludo:
        asset = 'assets/images/parchis.png';
        break;
    }
    return Image.asset(asset, width: 20, height: 20, fit: BoxFit.contain);
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
