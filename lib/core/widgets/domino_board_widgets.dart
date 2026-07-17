// lib/core/widgets/domino_board_widgets.dart
//
// Sprite-based Domino tile and chain-board widgets.
// Uses bg1.png sprite sheet (from CodeCanyon Domino v3).
//
// Public API:
//   DominoSpriteSheet.preload()  – call once in initState
//   DominoTileWidget             – single tile (hand / chain)
//   DominoChainBoard             – full snake-layout board
//   DominoChainEntry             – (left, right) pair for the board

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SPRITE SHEET
// ─────────────────────────────────────────────────────────────────────────────

/// Loads and caches the bg1.png domino sprite sheet.
class DominoSpriteSheet {
  DominoSpriteSheet._();

  static ui.Image? _image;
  static bool _loading = false;

  /// Frame data from bg1.json — [x, y, width, height] in pixels.
  /// Sprite is 1496 × 1788 px.  Tile frames are 99 × 188 px (portrait).
  static const Map<String, List<double>> _frames = {
    '0-0': [630, 586, 99, 188],
    '0-1': [769, 586, 99, 188],
    '0-2': [980, 0, 99, 188],
    '0-3': [980, 228, 99, 188],
    '0-4': [980, 456, 99, 188],
    '0-5': [980, 684, 99, 188],
    '0-6': [980, 912, 99, 188],
    '1-1': [1119, 0, 99, 188],
    '1-2': [1119, 228, 99, 188],
    '1-3': [490, 586, 100, 188],
    '1-4': [1119, 456, 99, 188],
    '1-5': [1119, 684, 99, 188],
    '1-6': [1119, 912, 99, 188],
    '2-2': [1119, 1140, 99, 188],
    '2-3': [1258, 0, 99, 188],
    '2-4': [1258, 228, 99, 188],
    '2-5': [1258, 456, 99, 188],
    '2-6': [1258, 684, 99, 188],
    '3-3': [1258, 912, 99, 188],
    '3-4': [1258, 1140, 99, 188],
    '3-5': [1397, 0, 99, 188],
    '3-6': [1397, 228, 99, 188],
    '4-4': [1397, 456, 99, 188],
    '4-5': [1397, 684, 99, 188],
    '4-6': [1397, 912, 99, 188],
    '5-5': [1397, 1140, 99, 188],
    '5-6': [0, 1412, 99, 188],
    '6-6': [139, 1412, 99, 188],
    // "0.png" in the original JSON — used as face-down (back) tile
    'back': [980, 1140, 99, 188],
  };

  /// Start loading the sprite sheet. Safe to call multiple times.
  static Future<void> preload() async {
    if (_image != null || _loading) return;
    _loading = true;
    try {
      final data = await rootBundle.load('assets/images/bg1.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      _image = frame.image;
    } catch (_) {
      // Asset missing → fallback pip renderer kicks in automatically.
    } finally {
      _loading = false;
    }
  }

  static bool get isLoaded => _image != null;
  static ui.Image? get image => _image;

  /// Source [Rect] for the given tile values in the sprite sheet.
  /// Always uses canonical form min(a,b)–max(a,b).
  static ui.Rect frameFor(int a, int b) {
    final lo = math.min(a, b);
    final hi = math.max(a, b);
    final f = _frames['$lo-$hi'] ?? _frames['back']!;
    return ui.Rect.fromLTWH(f[0], f[1], f[2], f[3]);
  }

  static ui.Rect get backFrame {
    final f = _frames['back']!;
    return ui.Rect.fromLTWH(f[0], f[1], f[2], f[3]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DOMINO TILE WIDGET
// ─────────────────────────────────────────────────────────────────────────────

const Color _kTileBorder = Color(0xFF4A3728);
const Color _kAccentOrange = Color(0xFFEC7A34);
const Color _kTileColor = Color(0xFFFFF8E1);

/// Renders a single domino tile using the sprite sheet (pip fallback if not loaded).
///
/// Orientation rules:
/// • [landscape] = false (default) → portrait tile — used in hand displays.
/// • [landscape] = true            → horizontal chain tile:
///     - regular tiles rotate 90° to appear landscape (wide & short).
///     - double tiles stay portrait (narrow & tall) — same visual as CodeCanyon.
/// • [faceDown]  = true            → shows the back of the tile.
class DominoTileWidget extends StatelessWidget {
  const DominoTileWidget({
    super.key,
    required this.left,
    required this.right,
    required this.width,
    required this.height,
    this.landscape = false,
    this.isPlayable = false,
    this.isSelected = false,
    this.isMandatory = false,
    this.faceDown = false,
  });

  final int left, right;
  final double width, height;
  final bool landscape;
  final bool isPlayable, isSelected, isMandatory, faceDown;

  bool get _isDouble => left == right;

  @override
  Widget build(BuildContext context) {
    // Doubles in a chain stay portrait even when landscape is requested.
    final bool actualLandscape = landscape && !_isDouble;

    Color borderColor = _kTileBorder;
    double borderWidth = 1.0;
    BoxShadow shadow =
        const BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(1, 2));

    if (isSelected) {
      borderColor = _kAccentOrange;
      borderWidth = 2.0;
    } else if (isMandatory) {
      borderColor = Colors.amber;
      borderWidth = 2.0;
    } else if (isPlayable) {
      borderColor = const Color(0xFF4CAF50);
      borderWidth = 2.0;
      shadow = BoxShadow(
        color: Colors.green.withValues(alpha: 0.5),
        blurRadius: 8,
        offset: const Offset(0, 2),
      );
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: [shadow],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: DominoSpriteSheet.isLoaded
            ? CustomPaint(
                painter: _TileSpritePainter(
                  left: left,
                  right: right,
                  landscape: actualLandscape,
                  faceDown: faceDown,
                  image: DominoSpriteSheet.image!,
                ),
              )
            : _FallbackTile(
                left: left,
                right: right,
                landscape: actualLandscape,
                faceDown: faceDown,
              ),
      ),
    );
  }
}

// ── Sprite painter ────────────────────────────────────────────────────────────

class _TileSpritePainter extends CustomPainter {
  const _TileSpritePainter({
    required this.left,
    required this.right,
    required this.landscape,
    required this.faceDown,
    required this.image,
  });

  final int left, right;
  final bool landscape, faceDown;
  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    final src =
        faceDown ? DominoSpriteSheet.backFrame : DominoSpriteSheet.frameFor(left, right);
    final paint = Paint()..filterQuality = FilterQuality.medium;

    if (landscape) {
      // Sprite is stored portrait (low value on top, high value on bottom).
      // Rotate canvas so it appears landscape:
      //   left ≤ right → rotate −90° (CCW): "top" of portrait → LEFT of landscape.
      //   left >  right → rotate +90° (CW):  "bottom" → LEFT, which puts high value left.
      final angle = (faceDown || left <= right) ? -math.pi / 2 : math.pi / 2;
      canvas.save();
      canvas.translate(size.width / 2, size.height / 2);
      canvas.rotate(angle);
      // Portrait sprite draws into (height × width) area in the rotated frame.
      canvas.drawImageRect(
        image,
        src,
        Rect.fromLTWH(-size.height / 2, -size.width / 2, size.height, size.width),
        paint,
      );
      canvas.restore();
    } else {
      // Portrait.  Sprite: low value on top, high value on bottom.
      // If left > right we need to flip 180° so displayLeft appears on top.
      if (!faceDown && left > right) {
        canvas.save();
        canvas.translate(size.width / 2, size.height / 2);
        canvas.rotate(math.pi);
        canvas.drawImageRect(
          image,
          src,
          Rect.fromLTWH(-size.width / 2, -size.height / 2, size.width, size.height),
          paint,
        );
        canvas.restore();
      } else {
        canvas.drawImageRect(
            image, src, Rect.fromLTWH(0, 0, size.width, size.height), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_TileSpritePainter old) =>
      old.left != left ||
      old.right != right ||
      old.landscape != landscape ||
      old.faceDown != faceDown;
}

// ── Fallback pip renderer (used while sprite sheet is loading) ────────────────

class _FallbackTile extends StatelessWidget {
  const _FallbackTile({
    required this.left,
    required this.right,
    required this.landscape,
    required this.faceDown,
  });

  final int left, right;
  final bool landscape, faceDown;

  @override
  Widget build(BuildContext context) {
    if (faceDown) {
      return Container(
        color: const Color(0xFF4A3728),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF5C4A38),
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: Colors.white12, width: 0.5),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      );
    }

    final dividerColor = _kTileBorder.withValues(alpha: 0.4);
    return Container(
      color: _kTileColor,
      child: landscape
          ? Row(children: [
              Expanded(child: _PipGrid(count: left)),
              Container(width: 1, color: dividerColor),
              Expanded(child: _PipGrid(count: right)),
            ])
          : Column(children: [
              Expanded(child: _PipGrid(count: left)),
              Container(height: 1, color: dividerColor),
              Expanded(child: _PipGrid(count: right)),
            ]),
    );
  }
}

class _PipGrid extends StatelessWidget {
  const _PipGrid({required this.count});

  final int count;

  static const _pos = <int, List<Alignment>>{
    0: [],
    1: [Alignment.center],
    2: [Alignment(-0.6, -0.6), Alignment(0.6, 0.6)],
    3: [Alignment(0.6, -0.6), Alignment.center, Alignment(-0.6, 0.6)],
    4: [
      Alignment(-0.6, -0.6),
      Alignment(0.6, -0.6),
      Alignment(-0.6, 0.6),
      Alignment(0.6, 0.6),
    ],
    5: [
      Alignment(-0.6, -0.6),
      Alignment(0.6, -0.6),
      Alignment.center,
      Alignment(-0.6, 0.6),
      Alignment(0.6, 0.6),
    ],
    6: [
      Alignment(-0.6, -0.6),
      Alignment(0.6, -0.6),
      Alignment(-0.6, 0.0),
      Alignment(0.6, 0.0),
      Alignment(-0.6, 0.6),
      Alignment(0.6, 0.6),
    ],
  };

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.expand();
    final alignments = _pos[count] ?? [];
    return LayoutBuilder(builder: (_, c) {
      final side = math.min(c.maxWidth, c.maxHeight);
      final dot = (side * 0.22).clamp(3.0, 8.0);
      return Stack(
        children: alignments
            .map((a) => Align(
                  alignment: a,
                  child: Container(
                    width: dot,
                    height: dot,
                    margin: EdgeInsets.all(dot * 0.3),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1A1A1A),
                      shape: BoxShape.circle,
                    ),
                  ),
                ))
            .toList(),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DOMINO CHAIN BOARD
// ─────────────────────────────────────────────────────────────────────────────

/// A single tile entry for [DominoChainBoard].
class DominoChainEntry {
  const DominoChainEntry({required this.left, required this.right});
  final int left, right;
  bool get isDouble => left == right;
}

/// Renders the full domino chain as a snake (zigzag) layout.
///
/// Layout rules (matching CodeCanyon visual):
/// • Regular tiles → landscape (wide & short) in each horizontal row.
/// • Double tiles  → portrait  (narrow & tall) in each horizontal row.
/// • Rows alternate left-to-right and right-to-left.
class DominoChainBoard extends StatelessWidget {
  const DominoChainBoard({
    super.key,
    required this.tiles,
    this.emptyMessage = 'La cadena aparecerá aquí',
  });

  final List<DominoChainEntry> tiles;
  final String emptyMessage;

  // ── Layout constants ──────────────────────────────────────────────────────
  static const double _tw = 50.0; // portrait tile width
  static const double _th = 95.0; // portrait tile height
  static const double _gap = 4.0; // gap between tiles in a row
  static const double _rowGap = 6.0; // gap between rows
  static const double _hPad = 8.0;  // horizontal padding

  // Display dimensions for a tile in a horizontal row:
  static double _dw(bool isDouble) => isDouble ? _tw : _th; // landscape W = portrait H
  static double _dh(bool isDouble) => isDouble ? _th : _tw; // landscape H = portrait W

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) {
      return Center(
        child: Text(emptyMessage,
            style: const TextStyle(color: Colors.white54, fontSize: 13)),
      );
    }
    return LayoutBuilder(builder: (_, c) => _buildSnake(c.maxWidth));
  }

  Widget _buildSnake(double availWidth) {
    final rowW = availWidth - _hPad * 2;

    // Split chain into rows that fit within rowW.
    final rows = <List<DominoChainEntry>>[];
    var current = <DominoChainEntry>[];
    var curW = 0.0;

    for (final t in tiles) {
      final w = _dw(t.isDouble);
      if (current.isNotEmpty && curW + _gap + w > rowW) {
        rows.add(current);
        current = [t];
        curW = w;
      } else {
        if (current.isNotEmpty) curW += _gap;
        curW += w;
        current.add(t);
      }
    }
    if (current.isNotEmpty) rows.add(current);

    final bool single = rows.length == 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _hPad, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: _rowGap),
            _buildRow(rows[i], i, rowW, single),
          ],
        ],
      ),
    );
  }

  Widget _buildRow(
    List<DominoChainEntry> rowTiles,
    int idx,
    double rowW,
    bool single,
  ) {
    // Even rows: left → right.  Odd rows: right → left (reversed display).
    final isLTR = idx.isEven;
    final ordered = isLTR ? rowTiles : rowTiles.reversed.toList();

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (int i = 0; i < ordered.length; i++) ...[
          if (i > 0) const SizedBox(width: _gap),
          DominoTileWidget(
            left: ordered[i].left,
            right: ordered[i].right,
            landscape: true, // doubles handled internally
            width: _dw(ordered[i].isDouble),
            height: _dh(ordered[i].isDouble),
          ),
        ],
      ],
    );

    if (single) return row;
    return SizedBox(
      width: rowW,
      child: Align(
        alignment: isLTR ? Alignment.centerLeft : Alignment.centerRight,
        child: row,
      ),
    );
  }
}
