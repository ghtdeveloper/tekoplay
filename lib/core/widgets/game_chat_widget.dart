import 'dart:async';

import 'package:flutter/material.dart';

import '../service/game_chat_service.dart';
import '../utils/profanity_filter.dart';

class GameChatWidget extends StatefulWidget {
  final String gameId;
  final String collectionName;
  final String currentUserId;
  final String currentUserName;
  final void Function(int count)? onUnreadCountChanged;
  final void Function(String senderId, String senderName)? onNewMessageFromOther;
  final void Function(String senderId, String senderName, String text)? onNewMessageWithText;
  final void Function(String text)? onOwnMessageSent;
  final bool showFloatingBubbles;

  const GameChatWidget({
    super.key,
    required this.gameId,
    required this.collectionName,
    required this.currentUserId,
    required this.currentUserName,
    this.onUnreadCountChanged,
    this.onNewMessageFromOther,
    this.onNewMessageWithText,
    this.onOwnMessageSent,
    this.showFloatingBubbles = true,
  });

  @override
  State<GameChatWidget> createState() => GameChatWidgetState();
}

class GameChatWidgetState extends State<GameChatWidget>
    with SingleTickerProviderStateMixin {
  late final GameChatService _chatService;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<ChatMessage> _messages = [];
  StreamSubscription? _chatSub;
  int unreadCount = 0;
  bool _isOpen = false;
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnimation;

  String? _ownBubbleText;
  String? _otherBubbleText;
  String? _otherBubbleName;

  String? get lastOwnBubbleText => _ownBubbleText;
  Timer? _ownBubbleTimer;
  Timer? _otherBubbleTimer;

  @override
  void initState() {
    super.initState();
    _chatService = GameChatService(
      collectionName: widget.collectionName,
      gameId: widget.gameId,
    );
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    ));
    _chatSub = _chatService.getMessages().listen((messages) {
      if (!mounted) return;
      final hadMessages = _messages.length;
      setState(() {
        _messages = messages;
        if (!_isOpen && messages.length > hadMessages) {
          unreadCount += messages.length - hadMessages;
          widget.onUnreadCountChanged?.call(unreadCount);
        }
      });
      if (messages.length > hadMessages) {
        for (int i = hadMessages; i < messages.length; i++) {
          final msg = messages[i];
          if (msg.senderId != widget.currentUserId) {
            widget.onNewMessageFromOther?.call(msg.senderId, msg.senderName);
            widget.onNewMessageWithText?.call(msg.senderId, msg.senderName, msg.text);
            _showOtherBubble(msg.text, msg.senderName);
          }
        }
      }
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _chatSub?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    _animController.dispose();
    _ownBubbleTimer?.cancel();
    _otherBubbleTimer?.cancel();
    super.dispose();
  }

  void _showOwnBubble(String text) {
    if (_isOpen) return;
    _ownBubbleTimer?.cancel();
    setState(() => _ownBubbleText = text);
    _ownBubbleTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _ownBubbleText = null);
    });
  }

  void _showOtherBubble(String text, String senderName) {
    if (_isOpen) return;
    _otherBubbleTimer?.cancel();
    setState(() {
      _otherBubbleText = text;
      _otherBubbleName = senderName;
    });
    _otherBubbleTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() { _otherBubbleText = null; _otherBubbleName = null; });
    });
  }


  void toggleChat() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        unreadCount = 0;
        widget.onUnreadCountChanged?.call(0);
        _animController.forward();
        _scrollToBottom();
        _ownBubbleText = null;
        _otherBubbleText = null;
        _otherBubbleName = null;
      } else {
        _animController.reverse();
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    if (ProfanityFilter.containsProfanity(text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El mensaje contiene palabras no permitidas'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    _chatService.sendMessage(
      senderId: widget.currentUserId,
      senderName: widget.currentUserName,
      text: text,
    );
    _textController.clear();
    _showOwnBubble(text);
    widget.onOwnMessageSent?.call(text);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (widget.showFloatingBubbles && _otherBubbleText != null)
          Positioned(
            top: 56,
            left: 12,
            child: _buildBubble(
              key: ValueKey('other:$_otherBubbleText:$_otherBubbleName'),
              text: _otherBubbleText!,
              name: _otherBubbleName,
              isMe: false,
            ),
          ),
        if (widget.showFloatingBubbles && _ownBubbleText != null)
          Positioned(
            bottom: 130,
            right: 12,
            child: _buildBubble(
              key: ValueKey('own:$_ownBubbleText'),
              text: _ownBubbleText!,
              name: null,
              isMe: true,
            ),
          ),

        if (_isOpen || _animController.isAnimating)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: MediaQuery.of(context).size.width * 0.75,
            child: SlideTransition(
              position: _slideAnimation,
              child: Material(
                elevation: 8,
                color: const Color(0xFF2C2C2C),
                child: SafeArea(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF3A3A3A),
                          border: Border(
                            bottom: BorderSide(color: Colors.white24),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.chat, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Chat',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.close,
                                  color: Colors.white70, size: 20),
                              onPressed: toggleChat,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                      // Messages
                      Expanded(
                        child: _messages.isEmpty
                            ? const Center(
                                child: Text(
                                  'Sin mensajes aun',
                                  style: TextStyle(color: Colors.white38),
                                ),
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.all(8),
                                itemCount: _messages.length,
                                itemBuilder: (context, index) {
                                  final msg = _messages[index];
                                  final isMe =
                                      msg.senderId == widget.currentUserId;
                                  return _buildMessageBubble(msg, isMe);
                                },
                              ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: const BoxDecoration(
                          color: Color(0xFF333333),
                          border: Border(top: BorderSide(color: Colors.white12)),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              '👍', '👎', '😂', '😅', '😮', '😯', '🤣',
                              '😍', '🥰', '😎', '🤩', '😜', '😏', '🤔',
                              '😢', '😭', '😡', '🤬', '🤦', '🤷', '😤',
                              '🔥', '🥵', '💪', '🙌', '👏', '🎉', '🏆', '💯',
                              '❤️', '💔', '😴', '🤯', '😱', '🥶', '🤮',
                            ].map((emoji) =>
                              GestureDetector(
                                onTap: () {
                                  _textController.text = _textController.text + emoji;
                                  _textController.selection = TextSelection.fromPosition(
                                    TextPosition(offset: _textController.text.length),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: Text(emoji, style: const TextStyle(fontSize: 20)),
                                ),
                              ),
                            ).toList(),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF3A3A3A),
                          border: Border(
                            top: BorderSide(color: Colors.white24),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _textController,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 14),
                                maxLength: 100,
                                decoration: InputDecoration(
                                  hintText: 'Escribe un mensaje...',
                                  hintStyle:
                                      const TextStyle(color: Colors.white38),
                                  filled: true,
                                  fillColor: const Color(0xFF1E1E1E),
                                  counterText: '',
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                onSubmitted: (_) => _sendMessage(),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.send,
                                  color: Colors.amber, size: 22),
                              onPressed: _sendMessage,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBubble({
    required Key key,
    required String text,
    required String? name,
    required bool isMe,
  }) {
    final bool isEmoji = text.characters.length <= 3 &&
        !text.contains(RegExp(r'[a-zA-Z0-9]'));

    return TweenAnimationBuilder<double>(
      key: key,
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      builder: (_, v, child) => Transform.scale(
        scale: v.clamp(0.0, 1.0),
        alignment: isMe ? Alignment.bottomRight : Alignment.topLeft,
        child: child,
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 190),
        padding: EdgeInsets.symmetric(
          horizontal: isEmoji ? 10 : 12,
          vertical: isEmoji ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: isMe
              ? const Color(0xFFF57F17)
              : Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft:
                isMe ? const Radius.circular(16) : const Radius.circular(3),
            bottomRight:
                isMe ? const Radius.circular(3) : const Radius.circular(16),
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe && name != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Color(0xFFF57F17),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Text(
              text,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: isEmoji ? 30 : 13,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.55),
        decoration: BoxDecoration(
          color: isMe ? Colors.amber.shade700 : const Color(0xFF444444),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(12),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Text(
                msg.senderName,
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            Text(
              msg.text,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            Text(
              '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget chatButton({
    required int unreadCount,
    required VoidCallback onPressed,
  }) {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
          onPressed: onPressed,
          tooltip: 'Chat',
        ),
        if (unreadCount > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Text(
                unreadCount > 9 ? '9+' : '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}