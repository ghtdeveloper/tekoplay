// lib/core/widgets/domino_webview_board.dart
//
// WebView-based domino chain board.
//
// Flow:
//   1. loadFlutterAsset loads the small HTML (no image embedded).
//   2. JS calls FlutterChannel.postMessage('ready') after 50 ms.
//   3. Flutter sends tile JSON → tiles appear immediately with pip fallback.
//   4. Flutter streams bg1.png as 64 KB base64 chunks → sprites upgrade.

import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'domino_board_widgets.dart';

// Offload base64 encoding to a background isolate (avoids UI jank).
String _encodeBase64(Uint8List bytes) => base64Encode(bytes);

class DominoBoardWebView extends StatefulWidget {
  final List<DominoChainEntry> tiles;

  const DominoBoardWebView({super.key, required this.tiles});

  @override
  State<DominoBoardWebView> createState() => _DominoBoardWebViewState();
}

class _DominoBoardWebViewState extends State<DominoBoardWebView> {
  late final WebViewController _ctrl;

  bool _ready = false;
  List<DominoChainEntry>? _pendingTiles;

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
          }
        },
      )
      ..loadFlutterAsset('assets/domino_board/board.html');
  }

  // ── Ready handler (fires from onPageFinished OR JS 'ready' — whichever first)

  void _onReady() {
    if (_ready) return; // guard: only run once
    _ready = true;
    _send(_pendingTiles ?? widget.tiles);
    _pendingTiles = null;
    // Always stream the sprite sheet — Android WebView file:// access is unreliable.
    _streamSpriteSheet();
  }

  // ── Tile sending ──────────────────────────────────────────────────────────

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

  // ── Sprite sheet streaming ────────────────────────────────────────────────

  Future<void> _streamSpriteSheet() async {
    try {
      final imgData = await rootBundle.load('assets/domino_board/bg1.png');
      // Use offsetInBytes+lengthInBytes to avoid extra buffer padding.
      final b64 = await compute(
        _encodeBase64,
        imgData.buffer.asUint8List(imgData.offsetInBytes, imgData.lengthInBytes),
      );

      if (!mounted) return;

      // Stream in 64 KB chunks to stay within runJavaScript limits.
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

  // ── Widget lifecycle ──────────────────────────────────────────────────────

  @override
  void didUpdateWidget(DominoBoardWebView old) {
    super.didUpdateWidget(old);
    _send(widget.tiles);
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _ctrl);
  }
}
