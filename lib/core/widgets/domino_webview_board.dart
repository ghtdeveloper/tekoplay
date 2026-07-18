// lib/core/widgets/domino_webview_board.dart

import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'domino_board_widgets.dart';

String _encodeBase64(Uint8List bytes) => base64Encode(bytes);

class DominoBoardWebView extends StatefulWidget {
  final List<DominoChainEntry> tiles;

  /// When true, amber hint circles appear on the chain endpoints in the board.
  final bool showEndpointHints;

  /// Pip value shown on the left endpoint hint.
  final int leftOpen;

  /// Pip value shown on the right endpoint hint.
  final int rightOpen;

  /// Called when the player taps the left endpoint hint.
  final VoidCallback? onLeftTapped;

  /// Called when the player taps the right endpoint hint.
  final VoidCallback? onRightTapped;

  const DominoBoardWebView({
    super.key,
    required this.tiles,
    this.showEndpointHints = false,
    this.leftOpen = 0,
    this.rightOpen = 0,
    this.onLeftTapped,
    this.onRightTapped,
  });

  @override
  State<DominoBoardWebView> createState() => _DominoBoardWebViewState();
}

class _DominoBoardWebViewState extends State<DominoBoardWebView> {
  late final WebViewController _ctrl;

  bool _ready = false;
  List<DominoChainEntry>? _pendingTiles;
  bool _pendingHints = false;

  @override
  void initState() {
    super.initState();

    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => _onReady(),
      ))
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (msg) {
          if (msg.message == 'ready') {
            _onReady();
          } else if (msg.message == 'imgError') {
            _streamSpriteSheet();
          } else if (msg.message == 'tapLeft') {
            widget.onLeftTapped?.call();
          } else if (msg.message == 'tapRight') {
            widget.onRightTapped?.call();
          }
        },
      );

    // Load HTML as a string to bypass WebView asset caching
    rootBundle.loadString('assets/domino_board/board.html').then((html) {
      _ctrl.loadHtmlString(html);
    });
  }

  void _onReady() {
    if (_ready) return;
    _ready = true;
    _send(_pendingTiles ?? widget.tiles);
    _pendingTiles = null;
    if (_pendingHints || widget.showEndpointHints) {
      _updateHints();
      _pendingHints = false;
    }
    _streamSpriteSheet();
  }

  void _send(List<DominoChainEntry> tiles) {
    if (!_ready) {
      _pendingTiles = tiles;
      return;
    }
    final json = jsonEncode(
      tiles.map((t) => {'l': t.left, 'r': t.right}).toList(),
    );
    _ctrl.runJavaScript('window.updateBoard($json)');
  }

  void _updateHints() {
    if (!_ready) {
      _pendingHints = widget.showEndpointHints;
      return;
    }
    if (widget.showEndpointHints) {
      _ctrl.runJavaScript(
          'window.showEndpointHints(${widget.leftOpen},${widget.rightOpen})');
    } else {
      _ctrl.runJavaScript('window.hideEndpointHints()');
    }
  }

  Future<void> _streamSpriteSheet() async {
    try {
      final imgData = await rootBundle.load('assets/domino_board/bg1.png');
      final b64 = await compute(
        _encodeBase64,
        imgData.buffer.asUint8List(imgData.offsetInBytes, imgData.lengthInBytes),
      );

      if (!mounted) return;

      const chunkSize = 65536;
      await _ctrl.runJavaScript('window._imgStart()');
      for (int i = 0; i < b64.length; i += chunkSize) {
        final chunk = b64.substring(i, min(i + chunkSize, b64.length));
        await _ctrl.runJavaScript("window._imgChunk('$chunk')");
        if (!mounted) return;
      }
      await _ctrl.runJavaScript('window._imgEnd()');
    } catch (_) {
      // Sprite sheet unavailable — pip fallback stays active.
    }
  }

  @override
  void didUpdateWidget(DominoBoardWebView old) {
    super.didUpdateWidget(old);
    if (old.tiles != widget.tiles) {
      _send(widget.tiles);
    }
    if (old.showEndpointHints != widget.showEndpointHints ||
        old.leftOpen != widget.leftOpen ||
        old.rightOpen != widget.rightOpen) {
      _updateHints();
    }
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _ctrl);
  }
}
