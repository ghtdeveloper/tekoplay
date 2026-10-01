import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tekoplay/core/config/flavor_config.dart';
import '../../features/games/chess/multiplayer_chess_screen.dart';
import '../../features/games/domino/multiplayer_domino_screen.dart';
import '../../features/games/domino_pase/multiplayer_domino_pase_screen.dart';
import '../../features/games/ludo/multiplayer_ludo_screen.dart';
import '../../generated/l10n.dart';
import '../models/multiplayer_game_match_chess.dart';

class InvitationBellWidget extends StatelessWidget {
  const InvitationBellWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;
        if (user == null) return const SizedBox.shrink();

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: GameInvitationService().getPendingInvitations(user.uid),
          builder: (context, snapshot) {
            final invitations = snapshot.data ?? [];
            final hasInvitations = invitations.isNotEmpty;

            return Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications, color: Colors.white, size: 28),
                  onPressed: () => _showInvitationsDialog(context, user.uid),
                ),
                if (hasInvitations)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '${invitations.length}',
                        style: const TextStyle(
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
      },
    );
  }

  void _showInvitationsDialog(BuildContext parentContext, String userId) {
    final navigator = Navigator.of(parentContext);
    showDialog(
      context: parentContext,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: double.infinity,
          height: 400,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    S.of(dialogContext).invitations,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.grey[700]),
                    onPressed: () => navigator.pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: GameInvitationService().getPendingInvitations(userId),
                  builder: (context, snapshot) {
                    final invitations = snapshot.data ?? [];
                    if (invitations.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.notifications_none, size: 48, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              S.of(dialogContext).noInvitation,
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: invitations.length,
                      itemBuilder: (_, index) {
                        final invitation = invitations[index];
                        return _InvitationCard(
                          invitation: invitation,
                          parentContext: parentContext,
                        );
                      },
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
}

class _InvitationCard extends StatelessWidget {
  final Map<String, dynamic> invitation;
  final BuildContext parentContext;

  const _InvitationCard({
    required this.invitation,
    required this.parentContext,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sports_esports, color: Color(0xFFEC7A34), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${invitation['fromUserName']} ${S.of(context).invitesYou}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                      if (invitation['betAmount'] != null)
                        Text(
                          '${invitation['betAmount']}  ${invitation['currencyType'] ?? 'coins'}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      const SizedBox(height: 4),
                      Text(
                        '${invitation['gameType']}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _handleReject(context),
                  child: Text(
                    S.of(context).reject,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _handleAccept(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEC7A34),
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
  }

  Future<void> _handleReject(BuildContext context) async {
    final navigator = Navigator.of(parentContext);
    final rejectedMsg = S.of(context).invitationRejected;
    final result = await GameInvitationService().respondToInvitation(
      invitation['id'],
      false,
    );
    if (result != null && result['success'] == true) {
      navigator.pop();
      if (parentContext.mounted) {
        ScaffoldMessenger.of(parentContext).showSnackBar(
          SnackBar(content: Text(rejectedMsg), backgroundColor: Colors.orange),
        );
      }
    }
  }

  Future<void> _handleAccept(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final navigator = Navigator.of(parentContext);
    final s = S.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 8),
            Flexible(child: Text(s.areYouSure)),
          ],
        ),
        content: Text(s.acceptInvitationWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEC7A34),
              foregroundColor: Colors.white,
            ),
            child: Text(s.accept),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final invCurrency = invitation['currencyType'] as String? ?? 'coins';
    final usesDiamonds = invCurrency == 'diamonds';
    final betAmount = invitation['betAmount'] as int?;
    final minRequired = betAmount ?? (usesDiamonds ? 50 : 100);

    final userDoc = await FlavorConfig.firestore
        .collection('users')
        .doc(user.uid)
        .get();
    if (!userDoc.exists) return;
    final userData = userDoc.data()!;
    final currentBalance = usesDiamonds
        ? (userData['diamonds'] as int? ?? 0)
        : (userData['coins'] as int? ?? 0);

    if (currentBalance < minRequired) {
      navigator.pop();
      if (parentContext.mounted) {
        final currency = usesDiamonds ? s.diamonds : s.coins;
        showDialog(
          context: parentContext,
          builder: (ctx) => AlertDialog(
            title: Text(s.insufficientFunds),
            content: Text(s.needAtLeastNToPlay(minRequired, currency, currentBalance)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(s.close),
              ),
            ],
          ),
        );
      }
      return;
    }

    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
    }

    final result = await GameInvitationService().respondToInvitation(
      invitation['id'],
      true,
    );

    navigator.pop();

    if (result != null && result['success'] == true && result['gameId'] != null) {
      navigator.pop();

      final matchType = result['matchType'] as String? ?? '';

      final gameRoute = MaterialPageRoute(
        builder: (_) => result['isLudo'] == true
            ? MultiplayerLudoScreen(
                gameId: result['gameId'],
                playerNumber: result['playerNumber'] ?? 2,
                matchType: matchType,
              )
            : result['isDominoPase'] == true
                ? MultiplayerDominoPaseScreen(
                    gameId: result['gameId'],
                    playerNumber: result['playerNumber'] ?? 2,
                    matchType: matchType,
                  )
                : result['isDomino'] == true
                    ? MultiplayerDominoScreen(
                        gameId: result['gameId'],
                        playerNumber: result['playerNumber'] ?? 2,
                        matchType: matchType,
                      )
                    : MultiplayerChessScreen(
                        gameId: result['gameId'],
                        isHost: false,
                        matchType: matchType,
                      ),
      );

      navigator.pushReplacement(gameRoute);
    } else {
      navigator.pop();
      if (parentContext.mounted) {
        ScaffoldMessenger.of(parentContext).showSnackBar(
          SnackBar(
            content: Text(s.errorAcceptedInvitation),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
