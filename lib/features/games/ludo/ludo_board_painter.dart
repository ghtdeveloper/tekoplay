import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../core/models/ludo_game_match.dart';

class LudoBoardPainter extends CustomPainter {
  final LudoGameState gameState;
  final String? highlightedPieceColor;
  final int? highlightedPieceId;
  final List<int> validMovePositions;
  final double pulseValue;
  final Set<String> movableKeys;

  LudoBoardPainter({
    required this.gameState,
    this.highlightedPieceColor,
    this.highlightedPieceId,
    this.validMovePositions = const [],
    this.pulseValue = 0.0,
    this.movableKeys = const {},
  });

  @override
  void paint(Canvas canvas, Size size) {
    final squareSize = size.width / 15;
    _drawBackground(canvas, size);
    _drawHomeAreas(canvas, size, squareSize);
    _drawPath(canvas, size, squareSize);
    _drawHomeStretches(canvas, size, squareSize);
    _drawCenterTriangles(canvas, size, squareSize);
    _drawEntryCorners(canvas, squareSize);
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
    _drawHomeArea(canvas, Rect.fromLTWH(0, 0, 6 * squareSize, 6 * squareSize), const Color(0xFF00C853), squareSize);
    _drawHomeArea(canvas, Rect.fromLTWH(9 * squareSize, 0, 6 * squareSize, 6 * squareSize), const Color(0xFFFFD700), squareSize);
    _drawHomeArea(canvas, Rect.fromLTWH(0, 9 * squareSize, 6 * squareSize, 6 * squareSize), const Color(0xFFFF5252), squareSize);
    _drawHomeArea(canvas, Rect.fromLTWH(9 * squareSize, 9 * squareSize, 6 * squareSize, 6 * squareSize), const Color(0xFF2979FF), squareSize);
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

    final circlePaint = Paint()..color = color.withValues(alpha: 0.85)..style = PaintingStyle.fill;
    final circleBorderPaint = Paint()..color = color.withValues(alpha: 0.5)..style = PaintingStyle.stroke..strokeWidth = 2.0;

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

    // col=7 (pasillo vertical): rows 0..5 y rows 9..14
    for (int row = 0; row < 15; row++) {
      if (row >= 6 && row <= 8) continue;
      final rect = Rect.fromLTWH(7 * squareSize, row * squareSize, squareSize, squareSize);
      canvas.drawRect(rect, whitePaint);
      canvas.drawRect(rect, borderPaint);
    }

    // row=7 (pasillo horizontal): cols 0..5 y cols 9..14
    for (int col = 0; col < 15; col++) {
      if (col >= 6 && col <= 8) continue;
      final rect = Rect.fromLTWH(col * squareSize, 7 * squareSize, squareSize, squareSize);
      canvas.drawRect(rect, whitePaint);
      canvas.drawRect(rect, borderPaint);
    }
  }

  void _drawHomeStretches(Canvas canvas, Size size, double squareSize) {
    _drawHomeStretch(canvas, const Color(0xFF00C853), squareSize, 7, 1, true, 5);
    _drawHomeStretch(canvas, const Color(0xFFFFD700), squareSize, 9, 7, false, 5);
    _drawHomeStretch(canvas, const Color(0xFF2979FF), squareSize, 7, 9, true, 5);
    _drawHomeStretch(canvas, const Color(0xFFFF5252), squareSize, 1, 7, false, 5);
  }

  void _drawColoredCorner(Canvas canvas, int col, int row, Color color, double squareSize, Paint borderPaint) {
    final rect = Rect.fromLTWH(col * squareSize, row * squareSize, squareSize, squareSize);
    canvas.drawRect(rect, Paint()..color = color..style = PaintingStyle.fill);
    canvas.drawRect(rect, borderPaint);
  }

  // Pintadas DESPUÉS de los triángulos centrales para que no queden tapadas
  void _drawEntryCorners(Canvas canvas, double squareSize) {
    final bp = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 2.0;
    // Arriba (col=7, row=0) → Verde
    _drawColoredCorner(canvas, 7, 0, const Color(0xFF00C853), squareSize, bp);
    // Derecha (col=14, row=7) → Amarillo
    _drawColoredCorner(canvas, 14, 7, const Color(0xFFFFD700), squareSize, bp);
    // Izquierda (col=0, row=7) → Rojo
    _drawColoredCorner(canvas, 0, 7, const Color(0xFFFF5252), squareSize, bp);
    // Abajo (col=7, row=14) → Azul
    _drawColoredCorner(canvas, 7, 14, const Color(0xFF2979FF), squareSize, bp);
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

    // Verde: triángulo superior (casa arriba-izq, recta entra desde arriba)
    _drawTriangle(canvas, const Color(0xFF00C853), [
      Offset(centerX, centerY),
      Offset(6 * squareSize, 6 * squareSize),
      Offset(9 * squareSize, 6 * squareSize),
    ]);
    // Amarillo: triángulo derecho (casa arriba-der, recta entra desde la derecha)
    _drawTriangle(canvas, const Color(0xFFFFD700), [
      Offset(centerX, centerY),
      Offset(9 * squareSize, 6 * squareSize),
      Offset(9 * squareSize, 9 * squareSize),
    ]);
    // Azul: triángulo inferior (casa abajo-der, recta entra desde abajo)
    _drawTriangle(canvas, const Color(0xFF2979FF), [
      Offset(centerX, centerY),
      Offset(9 * squareSize, 9 * squareSize),
      Offset(6 * squareSize, 9 * squareSize),
    ]);
    // Rojo: triángulo izquierdo (casa abajo-izq, recta entra desde la izquierda)
    _drawTriangle(canvas, const Color(0xFFFF5252), [
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
    final safeBorderPaint = Paint()
      ..color = const Color(0xFFE65100)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    const startingSquares = [
      (col: 6,  row: 1,  color: Color(0xFF00C853)),
      (col: 1,  row: 8,  color: Color(0xFFFF5252)),
      (col: 8,  row: 13, color: Color(0xFF2979FF)),
      (col: 13, row: 6,  color: Color(0xFFFFD700)),
    ];

    for (final sq in startingSquares) {
      final center = Offset((sq.col + 0.5) * squareSize, (sq.row + 0.5) * squareSize);
      final rect = Rect.fromLTWH(sq.col * squareSize, sq.row * squareSize, squareSize, squareSize);

      canvas.drawRect(rect, Paint()..color = sq.color..style = PaintingStyle.fill);
      canvas.drawCircle(center, squareSize * 0.33, Paint()..color = Colors.white..style = PaintingStyle.fill);
      canvas.drawCircle(center, squareSize * 0.33, Paint()..color = sq.color..style = PaintingStyle.stroke..strokeWidth = 2.5);
      canvas.drawCircle(center, squareSize * 0.10, Paint()..color = sq.color..style = PaintingStyle.fill);
      canvas.drawRect(rect, safeBorderPaint);
    }
  }

  void _drawSafeStars(Canvas canvas, double squareSize) {
    final safeSquares = [
      Offset(6, 5),
      Offset(5, 8),
      Offset(8, 9),
      Offset(9, 6),
      Offset(2, 6),
      Offset(12, 8),
      Offset(6, 12),
      Offset(8, 2),
    ];

    final safeBgPaint = Paint()..color = const Color(0xFFFFE0B2)..style = PaintingStyle.fill;
    final safeBorderPaint = Paint()..color = const Color(0xFFE65100)..style = PaintingStyle.stroke..strokeWidth = 2.5;

    for (final pos in safeSquares) {
      final rect = Rect.fromLTWH(pos.dx * squareSize, pos.dy * squareSize, squareSize, squareSize);
      canvas.drawRect(rect, safeBgPaint);
      canvas.drawRect(rect, safeBorderPaint);
      _drawStar(
        canvas,
        Offset((pos.dx + 0.5) * squareSize, (pos.dy + 0.5) * squareSize),
        squareSize * 0.34,
        const Color(0xFFFFC107),
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

    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.fill);
    canvas.drawPath(path, Paint()..color = const Color(0xFFE65100)..style = PaintingStyle.stroke..strokeWidth = 1.5);
  }

  void _drawPathNumbers(Canvas canvas, double squareSize) {
    final positions = _getPositionCoordinates();

    for (int i = 0; i < positions.length; i++) {
      final pos = positions[i];
      final center = Offset((pos.dx + 0.5) * squareSize, (pos.dy + 0.5) * squareSize);

      final textPainter = TextPainter(
        text: TextSpan(
          text: '$i',
          style: TextStyle(color: Colors.grey[600], fontSize: squareSize * 0.22, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2 - squareSize * 0.25,
      ));
    }
  }

  // RECORRIDO ANTIHORARIO:
  // Pos  0: Verde sale (col=6,row=1) → baja col=6
  // Pos 13: Rojo  sale (col=1,row=8) → va derecha row=8
  // Pos 26: Azul  sale (col=8,row=13)→ sube col=8
  // Pos 39: Amarillo sale (col=13,row=6)→ va izquierda row=6
  List<Offset> _getPositionCoordinates() {
    return [
      // Verde sale pos=0, baja col=6
      Offset(6, 1), Offset(6, 2), Offset(6, 3), Offset(6, 4), Offset(6, 5),
      // Gira izquierda por row=6
      Offset(5, 6), Offset(4, 6), Offset(3, 6), Offset(2, 6), Offset(1, 6), Offset(0, 6),
      // Baja col=0
      Offset(0, 7), Offset(0, 8),
      // Rojo sale pos=13, va derecha row=8
      Offset(1, 8), Offset(2, 8), Offset(3, 8), Offset(4, 8), Offset(5, 8),
      // Baja col=6
      Offset(6, 9), Offset(6, 10), Offset(6, 11), Offset(6, 12), Offset(6, 13), Offset(6, 14),
      // Va derecha row=14
      Offset(7, 14), Offset(8, 14),
      // Azul sale pos=26, sube col=8
      Offset(8, 13), Offset(8, 12), Offset(8, 11), Offset(8, 10), Offset(8, 9),
      // Va derecha row=8
      Offset(9, 8), Offset(10, 8), Offset(11, 8), Offset(12, 8), Offset(13, 8), Offset(14, 8),
      // Sube col=14
      Offset(14, 7), Offset(14, 6),
      // Amarillo sale pos=39, va izquierda row=6
      Offset(13, 6), Offset(12, 6), Offset(11, 6), Offset(10, 6), Offset(9, 6),
      // Sube col=8
      Offset(8, 5), Offset(8, 4), Offset(8, 3), Offset(8, 2), Offset(8, 1), Offset(8, 0),
      // Va izquierda row=0
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

    for (final piece in gameState.yellowPieces) { addPieceToPosition(piece, const Color(0xFFFFD700), 'yellow'); }
    for (final piece in gameState.greenPieces) { addPieceToPosition(piece, const Color(0xFF00C853), 'green'); }
    for (final piece in gameState.redPieces) { addPieceToPosition(piece, const Color(0xFFFF5252), 'red'); }
    for (final piece in gameState.bluePieces) { addPieceToPosition(piece, const Color(0xFF2979FF), 'blue'); }

    for (final entry in piecesAtPosition.entries) {
      final position = entry.key;
      final piecesHere = entry.value;
      final boardPos = _getBoardPosition(position, squareSize);
      if (boardPos != null) {
        final Map<String, int> colorCount = {};
        for (final p in piecesHere) {
          final cn = p['colorName'] as String;
          colorCount[cn] = (colorCount[cn] ?? 0) + 1;
        }
        final barrierEntry = colorCount.entries.where((e) => e.value >= 2).firstOrNull;
        if (barrierEntry != null) {
          final barrierColor = (piecesHere.firstWhere((p) => p['colorName'] == barrierEntry.key)['color'] as Color);
          _drawBarrierIndicator(canvas, boardPos, squareSize, barrierColor);
        }

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
      final pieceR = radius * 0.70;
      final off = pieceR + squareSize * 0.06;
      _drawSinglePiece(canvas, limited[0]['piece'], limited[0]['color'], limited[0]['colorName'], center - Offset(off, 0), squareSize, radius: pieceR);
      _drawSinglePiece(canvas, limited[1]['piece'], limited[1]['color'], limited[1]['colorName'], center + Offset(off, 0), squareSize, radius: pieceR);
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

  void _drawBarrierIndicator(Canvas canvas, Offset center, double squareSize, Color color) {
    final outerRadius = squareSize * 0.52;
    canvas.drawCircle(center, outerRadius, Paint()..color = color.withValues(alpha: 0.35)..style = PaintingStyle.fill);
    canvas.drawCircle(center, outerRadius, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 3.5);
    canvas.drawCircle(center, outerRadius + 2, Paint()..color = Colors.black.withValues(alpha: 0.6)..style = PaintingStyle.stroke..strokeWidth = 1.5);

    final textPainter = TextPainter(
      text: const TextSpan(text: '🛡', style: TextStyle(fontSize: 14)),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, center - Offset(textPainter.width / 2, squareSize * 0.44));
  }

  void _drawColorPieces(Canvas canvas, List<LudoPiece> pieces, Color color, String colorName, double squareSize) {
    for (final piece in pieces) {
      final inStretch = piece.position >= 52 && piece.position <= 56;
      if (!piece.isHome && !piece.isFinished && !inStretch) continue;
      _drawPiece(canvas, piece, color, colorName, squareSize);
    }
  }

  void _drawPiece(Canvas canvas, LudoPiece piece, Color color, String colorName, double squareSize) {
    Offset position;
    if (piece.isHome) {
      position = _getHomePosition(colorName, piece.id, squareSize);
    } else if (piece.isFinished) {
      position = _getFinishPosition(colorName, piece.id, squareSize);
    } else if (piece.position >= 52 && piece.position <= 56) {
      position = _getHomeStretchBoardPosition(colorName, piece.position, squareSize);
    } else {
      return;
    }
    _drawSinglePiece(canvas, piece, color, colorName, position, squareSize);
  }

  void _drawSinglePiece(Canvas canvas, LudoPiece piece, Color color, String colorName,
      Offset position, double squareSize, {double? radius}) {
    final pieceRadius = radius ?? squareSize * 0.38;
    final isHighlighted = highlightedPieceColor == colorName && highlightedPieceId == piece.id;

    canvas.drawCircle(position + const Offset(3, 3), pieceRadius,
        Paint()..color = Colors.black.withValues(alpha: 0.5)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));

    final gradient = RadialGradient(
      colors: [color.withValues(alpha: 0.9), color, color.withValues(alpha: 0.7)],
      stops: const [0.0, 0.6, 1.0],
    );
    canvas.drawCircle(position, pieceRadius,
        Paint()..shader = gradient.createShader(Rect.fromCircle(center: position, radius: pieceRadius))..style = PaintingStyle.fill);
    canvas.drawCircle(position, pieceRadius, Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3.0);
    canvas.drawCircle(position, pieceRadius * 0.65, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2.0);
    canvas.drawCircle(position - Offset(pieceRadius * 0.25, pieceRadius * 0.3), pieceRadius * 0.25,
        Paint()..color = Colors.white.withValues(alpha: 0.7)..style = PaintingStyle.fill);

    if (isHighlighted) {
      canvas.drawCircle(position, pieceRadius * 1.4,
          Paint()..color = Colors.white.withValues(alpha: 0.7)..style = PaintingStyle.stroke..strokeWidth = 5.0);
    }

    if (movableKeys.contains('$colorName-${piece.id}')) {
      final ringRadius = pieceRadius * (1.3 + pulseValue * 0.55);
      final ringOpacity = (0.9 - pulseValue * 0.9).clamp(0.0, 1.0);
      canvas.drawCircle(position, ringRadius,
          Paint()..color = Colors.white.withValues(alpha: ringOpacity)..style = PaintingStyle.stroke..strokeWidth = 3.5);
      canvas.drawCircle(position, ringRadius * 1.25,
          Paint()..color = color.withValues(alpha: ringOpacity * 0.7)..style = PaintingStyle.stroke..strokeWidth = 2.0);
    }
  }

  Offset _getHomePosition(String color, int pieceId, double squareSize) {
    final homes = {
      'green':  const Offset(3.0, 3.0),
      'yellow': const Offset(12.0, 3.0),
      'red':    const Offset(3.0, 12.0),
      'blue':   const Offset(12.0, 12.0),
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
    const cx = 7.5;
    const cy = 7.5;
    final row = pieceId ~/ 2;
    final col = pieceId % 2;
    switch (color) {
      case 'green':
        return Offset((cx - 0.2 + col * 0.4) * squareSize, (cy - 0.65 - row * 0.5) * squareSize);
      case 'yellow':
        return Offset((cx + 0.65 + row * 0.5) * squareSize, (cy - 0.2 + col * 0.4) * squareSize);
      case 'blue':
        return Offset((cx - 0.2 + col * 0.4) * squareSize, (cy + 0.65 + row * 0.5) * squareSize);
      case 'red':
        return Offset((cx - 0.65 - row * 0.5) * squareSize, (cy - 0.2 + col * 0.4) * squareSize);
      default:
        return Offset(cx * squareSize, cy * squareSize);
    }
  }

  // Pasillo de llegada (posiciones 52–56):
  // Verde  → col=7, baja desde row=5 hacia row=1
  // Rojo   → row=7, va derecha desde col=1 hacia col=5
  // Azul   → col=7, baja desde row=9 hacia row=13
  // Amarillo→ row=7, va izquierda desde col=13 hacia col=9
  Offset _getHomeStretchBoardPosition(String color, int position, double squareSize) {
    final si = position - 52;
    switch (color) {
      case 'green':
        return Offset(7.5 * squareSize, (1.5 + si) * squareSize);
      case 'red':
        return Offset((1.5 + si) * squareSize, 7.5 * squareSize);
      case 'blue':
        return Offset(7.5 * squareSize, (13.5 - si) * squareSize);
      case 'yellow':
        return Offset((13.5 - si) * squareSize, 7.5 * squareSize);
      default:
        return Offset(7.5 * squareSize, 7.5 * squareSize);
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
  bool shouldRepaint(LudoBoardPainter oldDelegate) => true;
}