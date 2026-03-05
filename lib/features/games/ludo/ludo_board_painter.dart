import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../core/models/ludo_game_match.dart';

class LudoBoardPainter extends CustomPainter {
  final LudoGameState gameState;
  final String? highlightedPieceColor;
  final int? highlightedPieceId;
  final List<int> validMovePositions;

  LudoBoardPainter({
    required this.gameState,
    this.highlightedPieceColor,
    this.highlightedPieceId,
    this.validMovePositions = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    final squareSize = size.width / 15;
    _drawBackground(canvas, size);
    _drawHomeAreas(canvas, size, squareSize);
    _drawPath(canvas, size, squareSize);
    _drawHomeStretches(canvas, size, squareSize);
    _drawCenterTriangles(canvas, size, squareSize);
    _drawStartingSquares(canvas, squareSize);
    _drawSafeStars(canvas, squareSize);
    _drawPathNumbers(canvas, squareSize);
    _drawPieces(canvas, size, squareSize);
  }

  void _drawBackground(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF8B0000);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);
  }

  void _drawHomeAreas(Canvas canvas, Size size, double squareSize) {
    _drawHomeArea(canvas, Rect.fromLTWH(0, 0, 6 * squareSize, 6 * squareSize), const Color(0xFFFFD700), squareSize);
    _drawHomeArea(canvas, Rect.fromLTWH(9 * squareSize, 0, 6 * squareSize, 6 * squareSize), const Color(0xFF00C853), squareSize);
    _drawHomeArea(canvas, Rect.fromLTWH(0, 9 * squareSize, 6 * squareSize, 6 * squareSize), const Color(0xFF2979FF), squareSize);
    _drawHomeArea(canvas, Rect.fromLTWH(9 * squareSize, 9 * squareSize, 6 * squareSize, 6 * squareSize), const Color(0xFFFF5252), squareSize);
  }

  void _drawHomeArea(Canvas canvas, Rect area, Color color, double squareSize) {
    final homePaint = Paint()..color = color..style = PaintingStyle.fill;
    canvas.drawRect(area, homePaint);

    final borderPaint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3.0;
    canvas.drawRect(area, borderPaint);

    final centerX = area.left + area.width / 2;
    final centerY = area.top + area.height / 2;
    final innerSize = squareSize * 3.2;

    final innerRect = Rect.fromCenter(center: Offset(centerX, centerY), width: innerSize, height: innerSize);
    final innerPaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    canvas.drawRect(innerRect, innerPaint);
    canvas.drawRect(innerRect, borderPaint);

    final offset = squareSize * 0.75;
    final circlePositions = [
      Offset(centerX - offset, centerY - offset),
      Offset(centerX + offset, centerY - offset),
      Offset(centerX - offset, centerY + offset),
      Offset(centerX + offset, centerY + offset),
    ];

    final circlePaint = Paint()..color = color.withOpacity(0.85)..style = PaintingStyle.fill;
    final circleBorderPaint = Paint()..color = color.withOpacity(0.5)..style = PaintingStyle.stroke..strokeWidth = 2.0;

    for (final pos in circlePositions) {
      canvas.drawCircle(pos, squareSize * 0.3, circlePaint);
      canvas.drawCircle(pos, squareSize * 0.3, circleBorderPaint);
    }
  }

  void _drawPath(Canvas canvas, Size size, double squareSize) {
    final whitePaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final borderPaint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 2.0;

    for (int row in [6, 8]) {
      for (int col = 0; col < 15; col++) {
        if (col >= 6 && col <= 8 && row >= 6 && row <= 8) continue;
        final rect = Rect.fromLTWH(col * squareSize, row * squareSize, squareSize, squareSize);
        canvas.drawRect(rect, whitePaint);
        canvas.drawRect(rect, borderPaint);
      }
    }

    for (int col in [6, 8]) {
      for (int row = 0; row < 15; row++) {
        if (col >= 6 && col <= 8 && row >= 6 && row <= 8) continue;
        final rect = Rect.fromLTWH(col * squareSize, row * squareSize, squareSize, squareSize);
        canvas.drawRect(rect, whitePaint);
        canvas.drawRect(rect, borderPaint);
      }
    }
  }

  void _drawHomeStretches(Canvas canvas, Size size, double squareSize) {
    _drawHomeStretch(canvas, const Color(0xFFFFD700), squareSize, 7, 1, true, 5);
    _drawHomeStretch(canvas, const Color(0xFF00C853), squareSize, 9, 7, false, 5);
    _drawHomeStretch(canvas, const Color(0xFFFF5252), squareSize, 7, 9, true, 5);
    _drawHomeStretch(canvas, const Color(0xFF2979FF), squareSize, 1, 7, false, 5);
  }

  void _drawHomeStretch(Canvas canvas, Color color, double squareSize, int startCol, int startRow, bool isVertical, int count) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final borderPaint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 2.0;

    for (int i = 0; i < count; i++) {
      final rect = isVertical
          ? Rect.fromLTWH(startCol * squareSize, (startRow + i) * squareSize, squareSize, squareSize)
          : Rect.fromLTWH((startCol + i) * squareSize, startRow * squareSize, squareSize, squareSize);
      canvas.drawRect(rect, paint);
      canvas.drawRect(rect, borderPaint);
    }
  }

  void _drawCenterTriangles(Canvas canvas, Size size, double squareSize) {
    final centerX = 7.5 * squareSize;
    final centerY = 7.5 * squareSize;

    _drawTriangle(canvas, const Color(0xFFFFD700), [
      Offset(centerX, centerY),
      Offset(6 * squareSize, 6 * squareSize),
      Offset(9 * squareSize, 6 * squareSize),
    ]);
    _drawTriangle(canvas, const Color(0xFF00C853), [
      Offset(centerX, centerY),
      Offset(9 * squareSize, 6 * squareSize),
      Offset(9 * squareSize, 9 * squareSize),
    ]);
    _drawTriangle(canvas, const Color(0xFFFF5252), [
      Offset(centerX, centerY),
      Offset(9 * squareSize, 9 * squareSize),
      Offset(6 * squareSize, 9 * squareSize),
    ]);
    _drawTriangle(canvas, const Color(0xFF2979FF), [
      Offset(centerX, centerY),
      Offset(6 * squareSize, 9 * squareSize),
      Offset(6 * squareSize, 6 * squareSize),
    ]);

    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawLine(Offset(6 * squareSize, 6 * squareSize), Offset(9 * squareSize, 9 * squareSize), borderPaint);
    canvas.drawLine(Offset(6 * squareSize, 9 * squareSize), Offset(9 * squareSize, 6 * squareSize), borderPaint);
  }

  void _drawTriangle(Canvas canvas, Color color, List<Offset> points) {
    final path = Path()
      ..moveTo(points[0].dx, points[0].dy)
      ..lineTo(points[1].dx, points[1].dy)
      ..lineTo(points[2].dx, points[2].dy)
      ..close();
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);
  }

  void _drawStartingSquares(Canvas canvas, double squareSize) {
    final borderPaint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 2.0;

    final startingSquares = [
      {'col': 6, 'row': 1, 'color': const Color(0xFFFFD700)},
      {'col': 13, 'row': 6, 'color': const Color(0xFF00C853)},
      {'col': 8, 'row': 13, 'color': const Color(0xFFFF5252)},
      {'col': 1, 'row': 8, 'color': const Color(0xFF2979FF)},
    ];

    for (final sq in startingSquares) {
      final col = sq['col'] as int;
      final row = sq['row'] as int;
      final color = sq['color'] as Color;
      final rect = Rect.fromLTWH(col * squareSize, row * squareSize, squareSize, squareSize);
      final paint = Paint()..color = color..style = PaintingStyle.fill;
      canvas.drawRect(rect, paint);
      canvas.drawRect(rect, borderPaint);
    }
  }

  void _drawSafeStars(Canvas canvas, double squareSize) {
    final safeSquares = [
      Offset(6, 5),
      Offset(9, 6),
      Offset(8, 9),
      Offset(5, 8),
      Offset(2, 6),
      Offset(12, 8),
      Offset(6, 12),
      Offset(8, 2),
    ];

    for (final pos in safeSquares) {
      _drawStar(
        canvas,
        Offset((pos.dx + 0.5) * squareSize, (pos.dy + 0.5) * squareSize),
        squareSize * 0.32,
        Colors.grey[400]!,
      );
    }
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Color color) {
    final path = Path();
    const numPoints = 5;
    const angleStep = math.pi * 2 / numPoints;

    for (int i = 0; i < numPoints * 2; i++) {
      final r = i % 2 == 0 ? radius : radius * 0.38;
      final angle = i * angleStep / 2 - math.pi / 2;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    final paint = Paint()..color = color..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);
    final borderPaint = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2.0;
    canvas.drawPath(path, borderPaint);
  }

  void _drawPathNumbers(Canvas canvas, double squareSize) {
    final positions = _getPositionCoordinates();

    for (int i = 0; i < positions.length; i++) {
      final pos = positions[i];
      final center = Offset((pos.dx + 0.5) * squareSize, (pos.dy + 0.5) * squareSize);

      final textPainter = TextPainter(
        text: TextSpan(
          text: '$i',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: squareSize * 0.22,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          center.dx - textPainter.width / 2,
          center.dy - textPainter.height / 2 - squareSize * 0.25,
        ),
      );
    }
  }

  List<Offset> _getPositionCoordinates() {
    return [
      Offset(6, 1), Offset(6, 2), Offset(6, 3), Offset(6, 4), Offset(6, 5),
      Offset(5, 6), Offset(4, 6), Offset(3, 6), Offset(2, 6), Offset(1, 6), Offset(0, 6),
      Offset(0, 7), Offset(0, 8),
      Offset(1, 8), Offset(2, 8), Offset(3, 8), Offset(4, 8), Offset(5, 8),
      Offset(6, 9), Offset(6, 10), Offset(6, 11), Offset(6, 12), Offset(6, 13), Offset(6, 14),
      Offset(7, 14), Offset(8, 14),
      Offset(8, 13), Offset(8, 12), Offset(8, 11), Offset(8, 10), Offset(8, 9),
      Offset(9, 8), Offset(10, 8), Offset(11, 8), Offset(12, 8), Offset(13, 8), Offset(14, 8),
      Offset(14, 7), Offset(14, 6),
      Offset(13, 6), Offset(12, 6), Offset(11, 6), Offset(10, 6), Offset(9, 6),
      Offset(8, 5), Offset(8, 4), Offset(8, 3), Offset(8, 2), Offset(8, 1), Offset(8, 0),
      Offset(7, 0), Offset(6, 0),
    ];
  }

  void _drawPieces(Canvas canvas, Size size, double squareSize) {
    final piecesAtPosition = <int, List<Map<String, dynamic>>>{};

    void addPieceToPosition(LudoPiece piece, Color color, String colorName) {
      if (piece.isHome || piece.isFinished) return;
      if (!piecesAtPosition.containsKey(piece.position)) {
        piecesAtPosition[piece.position] = [];
      }
      piecesAtPosition[piece.position]!.add({'piece': piece, 'color': color, 'colorName': colorName});
    }

    for (final piece in gameState.yellowPieces) addPieceToPosition(piece, const Color(0xFFFFD700), 'yellow');
    for (final piece in gameState.greenPieces) addPieceToPosition(piece, const Color(0xFF00C853), 'green');
    for (final piece in gameState.redPieces) addPieceToPosition(piece, const Color(0xFFFF5252), 'red');
    for (final piece in gameState.bluePieces) addPieceToPosition(piece, const Color(0xFF2979FF), 'blue');

    for (final entry in piecesAtPosition.entries) {
      final position = entry.key;
      final piecesHere = entry.value;
      final boardPos = _getBoardPosition(position, squareSize);
      if (boardPos != null) {
        if (piecesHere.length == 1) {
          _drawSinglePiece(canvas, piecesHere[0]['piece'], piecesHere[0]['color'],
              piecesHere[0]['colorName'], boardPos, squareSize);
        } else {
          _drawStackedPieces(canvas, piecesHere, boardPos, squareSize);
        }
      }
    }

    _drawColorPieces(canvas, gameState.yellowPieces, const Color(0xFFFFD700), 'yellow', squareSize);
    _drawColorPieces(canvas, gameState.greenPieces, const Color(0xFF00C853), 'green', squareSize);
    _drawColorPieces(canvas, gameState.redPieces, const Color(0xFFFF5252), 'red', squareSize);
    _drawColorPieces(canvas, gameState.bluePieces, const Color(0xFF2979FF), 'blue', squareSize);
  }

  void _drawStackedPieces(Canvas canvas, List<Map<String, dynamic>> pieces, Offset center, double squareSize) {
    final radius = squareSize * 0.35;
    final Map<String, List<Map<String, dynamic>>> byColor = {};

    for (final piece in pieces) {
      final colorName = piece['colorName'] as String;
      if (!byColor.containsKey(colorName)) byColor[colorName] = [];
      if (byColor[colorName]!.length < 2) byColor[colorName]!.add(piece);
    }

    final limited = <Map<String, dynamic>>[];
    byColor.forEach((_, colorPieces) => limited.addAll(colorPieces));

    if (limited.length == 1) {
      _drawSinglePiece(canvas, limited[0]['piece'], limited[0]['color'], limited[0]['colorName'], center, squareSize);
    } else if (limited.length == 2) {
      final off = squareSize * 0.28;
      _drawSinglePiece(canvas, limited[0]['piece'], limited[0]['color'], limited[0]['colorName'], center - Offset(off, 0), squareSize, radius: radius * 0.85);
      _drawSinglePiece(canvas, limited[1]['piece'], limited[1]['color'], limited[1]['colorName'], center + Offset(off, 0), squareSize, radius: radius * 0.85);
    } else if (limited.length == 3) {
      final ox = squareSize * 0.26;
      final oy = squareSize * 0.22;
      _drawSinglePiece(canvas, limited[0]['piece'], limited[0]['color'], limited[0]['colorName'], center - Offset(ox, oy), squareSize, radius: radius * 0.75);
      _drawSinglePiece(canvas, limited[1]['piece'], limited[1]['color'], limited[1]['colorName'], center + Offset(ox, -oy), squareSize, radius: radius * 0.75);
      _drawSinglePiece(canvas, limited[2]['piece'], limited[2]['color'], limited[2]['colorName'], center + Offset(0, oy), squareSize, radius: radius * 0.75);
    } else {
      final off = squareSize * 0.24;
      _drawSinglePiece(canvas, limited[0]['piece'], limited[0]['color'], limited[0]['colorName'], center - Offset(off, off), squareSize, radius: radius * 0.7);
      _drawSinglePiece(canvas, limited[1]['piece'], limited[1]['color'], limited[1]['colorName'], center + Offset(off, -off), squareSize, radius: radius * 0.7);
      _drawSinglePiece(canvas, limited[2]['piece'], limited[2]['color'], limited[2]['colorName'], center + Offset(-off, off), squareSize, radius: radius * 0.7);
      _drawSinglePiece(canvas, limited[3]['piece'], limited[3]['color'], limited[3]['colorName'], center + Offset(off, off), squareSize, radius: radius * 0.7);
    }
  }

  void _drawColorPieces(Canvas canvas, List<LudoPiece> pieces, Color color, String colorName, double squareSize) {
    for (final piece in pieces) {
      if (!piece.isHome && !piece.isFinished) continue;
      _drawPiece(canvas, piece, color, colorName, squareSize);
    }
  }

  void _drawPiece(Canvas canvas, LudoPiece piece, Color color, String colorName, double squareSize) {
    Offset? position;
    if (piece.isHome) {
      position = _getHomePosition(colorName, piece.id, squareSize);
    } else if (piece.isFinished) {
      position = _getFinishPosition(colorName, piece.id, squareSize);
    } else {
      return;
    }
    if (position == null) return;
    _drawSinglePiece(canvas, piece, color, colorName, position, squareSize);
  }

  void _drawSinglePiece(Canvas canvas, LudoPiece piece, Color color, String colorName,
      Offset position, double squareSize, {double? radius}) {
    final pieceRadius = radius ?? squareSize * 0.38;
    final isHighlighted = highlightedPieceColor == colorName && highlightedPieceId == piece.id;

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(position + const Offset(3, 3), pieceRadius, shadowPaint);

    final gradient = RadialGradient(
      colors: [color.withOpacity(0.9), color, color.withOpacity(0.7)],
      stops: const [0.0, 0.6, 1.0],
    );
    final piecePaint = Paint()
      ..shader = gradient.createShader(Rect.fromCircle(center: position, radius: pieceRadius))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, pieceRadius, piecePaint);

    final borderPaint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3.0;
    canvas.drawCircle(position, pieceRadius, borderPaint);

    final innerBorderPaint = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2.0;
    canvas.drawCircle(position, pieceRadius * 0.65, innerBorderPaint);

    final highlightPaint = Paint()..color = Colors.white.withOpacity(0.7)..style = PaintingStyle.fill;
    canvas.drawCircle(position - Offset(pieceRadius * 0.25, pieceRadius * 0.3), pieceRadius * 0.25, highlightPaint);

    if (isHighlighted) {
      final selectPaint = Paint()
        ..color = Colors.white.withOpacity(0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0;
      canvas.drawCircle(position, pieceRadius * 1.4, selectPaint);
    }
  }

  Offset _getHomePosition(String color, int pieceId, double squareSize) {
    final homes = {
      'yellow': const Offset(3.0, 3.0),
      'green': const Offset(12.0, 3.0),
      'blue': const Offset(3.0, 12.0),
      'red': const Offset(12.0, 12.0),
    };
    final basePos = homes[color]!;
    const offset = 0.75;
    final positions = [
      Offset((basePos.dx - offset) * squareSize, (basePos.dy - offset) * squareSize),
      Offset((basePos.dx + offset) * squareSize, (basePos.dy - offset) * squareSize),
      Offset((basePos.dx - offset) * squareSize, (basePos.dy + offset) * squareSize),
      Offset((basePos.dx + offset) * squareSize, (basePos.dy + offset) * squareSize),
    ];
    return positions[pieceId];
  }

  Offset _getFinishPosition(String color, int pieceId, double squareSize) {
    const centerX = 7.5;
    const centerY = 7.5;
    switch (color) {
      case 'yellow':
        return Offset(centerX * squareSize, (centerY - 0.8 - pieceId * 0.45) * squareSize);
      case 'green':
        return Offset((centerX + 0.8 + pieceId * 0.45) * squareSize, centerY * squareSize);
      case 'red':
        return Offset(centerX * squareSize, (centerY + 0.8 + pieceId * 0.45) * squareSize);
      case 'blue':
        return Offset((centerX - 0.8 - pieceId * 0.45) * squareSize, centerY * squareSize);
      default:
        return Offset(centerX * squareSize, centerY * squareSize);
    }
  }

  Offset? _getBoardPosition(int position, double squareSize) {
    final positions = _getPositionCoordinates();
    if (position >= 0 && position < positions.length) {
      final pos = positions[position];
      return Offset((pos.dx + 0.5) * squareSize, (pos.dy + 0.5) * squareSize);
    }
    return null;
  }

  @override
  bool shouldRepaint(LudoBoardPainter oldDelegate) {
    return oldDelegate.gameState != gameState ||
        oldDelegate.highlightedPieceColor != highlightedPieceColor ||
        oldDelegate.highlightedPieceId != highlightedPieceId ||
        oldDelegate.validMovePositions != validMovePositions;
  }
}