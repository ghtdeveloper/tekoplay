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
    _drawSpecialSquares(canvas, squareSize);
    _drawHomeStretches(canvas, size, squareSize);
    _drawCenterTriangles(canvas, size, squareSize);
    _drawStartingSquares(canvas, squareSize); // NUEVO: Casillas de salida coloreadas
    _drawPathNumbers(canvas, squareSize);
    _drawPieces(canvas, size, squareSize);
  }

  void _drawBackground(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = Color(0xFF8B0000);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);
  }

  void _drawHomeAreas(Canvas canvas, Size size, double squareSize) {
    _drawHomeArea(canvas, Rect.fromLTWH(0, 0, 6 * squareSize, 6 * squareSize), Color(0xFFFFD700), squareSize);
    _drawHomeArea(canvas, Rect.fromLTWH(9 * squareSize, 0, 6 * squareSize, 6 * squareSize), Color(0xFF00C853), squareSize);
    _drawHomeArea(canvas, Rect.fromLTWH(9 * squareSize, 9 * squareSize, 6 * squareSize, 6 * squareSize), Color(0xFFFF5252), squareSize);
    _drawHomeArea(canvas, Rect.fromLTWH(0, 9 * squareSize, 6 * squareSize, 6 * squareSize), Color(0xFF2979FF), squareSize);
  }

  void _drawHomeArea(Canvas canvas, Rect area, Color color, double squareSize) {
    final homePaint = Paint()..color = color..style = PaintingStyle.fill;
    canvas.drawRect(area, homePaint);

    final borderPaint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3.0;
    canvas.drawRect(area, borderPaint);

    final centerX = area.left + area.width / 2;
    final centerY = area.top + area.height / 2;
    final innerSize = squareSize * 3.2;

    final innerRect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: innerSize,
      height: innerSize,
    );

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

    final circlePaint = Paint()..color = Color(0xFFF5F5F5)..style = PaintingStyle.fill;
    final circleBorderPaint = Paint()..color = Color(0xFFBDBDBD)..style = PaintingStyle.stroke..strokeWidth = 2.0;

    for (final pos in circlePositions) {
      canvas.drawCircle(pos, squareSize * 0.28, circlePaint);
      canvas.drawCircle(pos, squareSize * 0.28, circleBorderPaint);
    }
  }

  void _drawPath(Canvas canvas, Size size, double squareSize) {
    final whitePaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final borderPaint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 2.0;

    for (int i = 0; i < 6; i++) {
      final rect = Rect.fromLTWH(i * squareSize, 6 * squareSize, squareSize, squareSize);
      canvas.drawRect(rect, whitePaint);
      canvas.drawRect(rect, borderPaint);
    }

    for (int col in [6, 8]) {
      for (int i = 0; i < 6; i++) {
        final rect = Rect.fromLTWH(col * squareSize, i * squareSize, squareSize, squareSize);
        canvas.drawRect(rect, whitePaint);
        canvas.drawRect(rect, borderPaint);
      }
      for (int i = 9; i < 15; i++) {
        final rect = Rect.fromLTWH(col * squareSize, i * squareSize, squareSize, squareSize);
        canvas.drawRect(rect, whitePaint);
        canvas.drawRect(rect, borderPaint);
      }
    }

    for (int i = 9; i < 15; i++) {
      final rect = Rect.fromLTWH(i * squareSize, 6 * squareSize, squareSize, squareSize);
      canvas.drawRect(rect, whitePaint);
      canvas.drawRect(rect, borderPaint);
    }

    for (int i = 0; i < 6; i++) {
      final rect = Rect.fromLTWH(i * squareSize, 8 * squareSize, squareSize, squareSize);
      canvas.drawRect(rect, whitePaint);
      canvas.drawRect(rect, borderPaint);
    }

    for (int i = 9; i < 15; i++) {
      final rect = Rect.fromLTWH(i * squareSize, 8 * squareSize, squareSize, squareSize);
      canvas.drawRect(rect, whitePaint);
      canvas.drawRect(rect, borderPaint);
    }
  }

  void _drawSpecialSquares(Canvas canvas, double squareSize) {
    final specialSquares = [
      {'pos': Offset(6, 0), 'color': Color(0xFFFFFFFF)},
      {'pos': Offset(8, 0), 'color': Color(0xFFFFFFFF)},
      {'pos': Offset(14, 6), 'color': Color(0xFFFFFFFF)},
      {'pos': Offset(14, 8), 'color': Color(0xFFFFFFFF)},
      {'pos': Offset(6, 14), 'color': Color(0xFFFFFFFF)},
      {'pos': Offset(8, 14), 'color': Color(0xFFFFFFFF)},
      {'pos': Offset(0, 6), 'color': Color(0xFFFFFFFF)},
      {'pos': Offset(0, 8), 'color': Color(0xFFFFFFFF)},

      {'pos': Offset(7, 0), 'color': Color(0xFFFFD700)},
      {'pos': Offset(14, 7), 'color': Color(0xFF00C853)},
      {'pos': Offset(7, 14), 'color': Color(0xFFFF5252)},
      {'pos': Offset(0, 7), 'color': Color(0xFF2979FF)},
    ];

    final borderPaint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 2.0;

    for (final sq in specialSquares) {
      final pos = sq['pos'] as Offset;
      final color = sq['color'] as Color;

      final rect = Rect.fromLTWH(pos.dx * squareSize, pos.dy * squareSize, squareSize, squareSize);
      final paint = Paint()..color = color..style = PaintingStyle.fill;

      canvas.drawRect(rect, paint);
      canvas.drawRect(rect, borderPaint);
    }
  }

  void _drawHomeStretches(Canvas canvas, Size size, double squareSize) {
    _drawHomeStretch(canvas, Color(0xFFFFD700), squareSize, 7, 1, true, 5);
    _drawHomeStretch(canvas, Color(0xFF00C853), squareSize, 9, 7, false, 5);
    _drawHomeStretch(canvas, Color(0xFFFF5252), squareSize, 7, 9, true, 5);
    _drawHomeStretch(canvas, Color(0xFF2979FF), squareSize, 1, 7, false, 5);
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

    _drawTriangle(canvas, Color(0xFFFFD700), [
      Offset(centerX, centerY),
      Offset(6 * squareSize, 6 * squareSize),
      Offset(9 * squareSize, 6 * squareSize),
    ]);

    _drawTriangle(canvas, Color(0xFF00C853), [
      Offset(centerX, centerY),
      Offset(9 * squareSize, 6 * squareSize),
      Offset(9 * squareSize, 9 * squareSize),
    ]);

    _drawTriangle(canvas, Color(0xFFFF5252), [
      Offset(centerX, centerY),
      Offset(9 * squareSize, 9 * squareSize),
      Offset(6 * squareSize, 9 * squareSize),
    ]);

    _drawTriangle(canvas, Color(0xFF2979FF), [
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

  // NUEVO: Casillas de salida coloreadas en lugar de estrellas
  void _drawStartingSquares(Canvas canvas, double squareSize) {
    final startingSquares = {
      Offset(1, 6): {'color': Color(0xFFFFD700), 'position': 0},   // Yellow
      Offset(8, 2): {'color': Color(0xFF00C853), 'position': 13},  // Green
      Offset(13, 8): {'color': Color(0xFFFF5252), 'position': 26}, // Red
      Offset(6, 12): {'color': Color(0xFF2979FF), 'position': 39}, // Blue
    };

    // Otras casillas seguras (gris)
    final otherSafeSquares = [
      Offset(2, 6),   // Posición 1 (Yellow safe)
      Offset(6, 2),   // Posición 8 (Yellow to Green)
      Offset(12, 6),  // Posición 21 (Green safe)
      Offset(12, 8),  // Posición 34 (Red safe)
      Offset(8, 12),  // Posición 47 (Blue safe)
      Offset(2, 8),   // Posición 47 (Blue to Yellow)
    ];

    final borderPaint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 2.0;

    // Dibujar casillas de salida con color
    startingSquares.forEach((pos, data) {
      final color = data['color'] as Color;

      final rect = Rect.fromLTWH(
        pos.dx * squareSize,
        pos.dy * squareSize,
        squareSize,
        squareSize,
      );

      // Fondo con color semi-transparente
      final bgPaint = Paint()
        ..color = color.withOpacity(0.4)
        ..style = PaintingStyle.fill;
      canvas.drawRect(rect, bgPaint);

      // Borde del mismo color más fuerte
      final colorBorderPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0;
      canvas.drawRect(rect, colorBorderPaint);

      // Borde negro encima
      canvas.drawRect(rect, borderPaint);
    });

    // Dibujar otras casillas seguras con estrellas grises
    for (final pos in otherSafeSquares) {
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
          text: '${i + 1}',
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
      Offset(1, 6), Offset(2, 6), Offset(3, 6), Offset(4, 6), Offset(5, 6),
      Offset(6, 5), Offset(6, 4), Offset(6, 3), Offset(6, 2), Offset(6, 1), Offset(6, 0),
      Offset(7, 0), Offset(8, 0),
      Offset(8, 1), Offset(8, 2), Offset(8, 3), Offset(8, 4), Offset(8, 5),
      Offset(9, 6), Offset(10, 6), Offset(11, 6), Offset(12, 6), Offset(13, 6), Offset(14, 6),
      Offset(14, 7), Offset(14, 8),
      Offset(13, 8), Offset(12, 8), Offset(11, 8), Offset(10, 8), Offset(9, 8),
      Offset(8, 9), Offset(8, 10), Offset(8, 11), Offset(8, 12), Offset(8, 13), Offset(8, 14),
      Offset(7, 14), Offset(6, 14),
      Offset(6, 13), Offset(6, 12), Offset(6, 11), Offset(6, 10), Offset(6, 9),
      Offset(5, 8), Offset(4, 8), Offset(3, 8), Offset(2, 8), Offset(1, 8), Offset(0, 8),
      Offset(0, 7), Offset(0, 6),
    ];
  }

  void _drawPieces(Canvas canvas, Size size, double squareSize) {
    // Agrupar fichas por posición
    final piecesAtPosition = <int, List<Map<String, dynamic>>>{};

    void addPieceToPosition(LudoPiece piece, Color color, String colorName) {
      if (piece.isHome || piece.isFinished) return;

      if (!piecesAtPosition.containsKey(piece.position)) {
        piecesAtPosition[piece.position] = [];
      }
      piecesAtPosition[piece.position]!.add({
        'piece': piece,
        'color': color,
        'colorName': colorName,
      });
    }

    // Agregar todas las fichas en el tablero
    for (final piece in gameState.yellowPieces) {
      addPieceToPosition(piece, Color(0xFFFFD700), 'yellow');
    }
    for (final piece in gameState.greenPieces) {
      addPieceToPosition(piece, Color(0xFF00C853), 'green');
    }
    for (final piece in gameState.redPieces) {
      addPieceToPosition(piece, Color(0xFFFF5252), 'red');
    }
    for (final piece in gameState.bluePieces) {
      addPieceToPosition(piece, Color(0xFF2979FF), 'blue');
    }

    // Dibujar fichas apiladas en el tablero
    for (final entry in piecesAtPosition.entries) {
      final position = entry.key;
      final piecesHere = entry.value;

      final boardPos = _getBoardPosition(position, squareSize);
      if (boardPos != null) {
        if (piecesHere.length == 1) {
          _drawSinglePiece(canvas, piecesHere[0]['piece'], piecesHere[0]['color'],
              piecesHere[0]['colorName'], boardPos, squareSize);
        } else {
          // NUEVO: Dibujar fichas apiladas como en Parchís Star
          _drawStackedPiecesNew(canvas, piecesHere, boardPos, squareSize);
        }
      }
    }

    // Dibujar fichas en casa y finalizadas
    _drawColorPieces(canvas, gameState.yellowPieces, Color(0xFFFFD700), 'yellow', squareSize, true);
    _drawColorPieces(canvas, gameState.greenPieces, Color(0xFF00C853), 'green', squareSize, true);
    _drawColorPieces(canvas, gameState.redPieces, Color(0xFFFF5252), 'red', squareSize, true);
    _drawColorPieces(canvas, gameState.bluePieces, Color(0xFF2979FF), 'blue', squareSize, true);
  }

  // NUEVO: Método mejorado para apilar fichas - MÁXIMO 2 DEL MISMO COLOR
  void _drawStackedPiecesNew(Canvas canvas, List<Map<String, dynamic>> pieces, Offset center, double squareSize) {
    final radius = squareSize * 0.35;

    // Agrupar por color - máximo 2 fichas del mismo color
    final Map<String, List<Map<String, dynamic>>> byColor = {};
    for (final piece in pieces) {
      final colorName = piece['colorName'] as String;
      if (!byColor.containsKey(colorName)) {
        byColor[colorName] = [];
      }
      // SOLO agregar si hay menos de 2 del mismo color
      if (byColor[colorName]!.length < 2) {
        byColor[colorName]!.add(piece);
      }
    }

    // Aplanar lista limitada
    final limitedPieces = <Map<String, dynamic>>[];
    byColor.forEach((color, colorPieces) {
      limitedPieces.addAll(colorPieces);
    });

    if (limitedPieces.length == 1) {
      // 1 ficha: centrada
      _drawSinglePiece(
        canvas,
        limitedPieces[0]['piece'],
        limitedPieces[0]['color'],
        limitedPieces[0]['colorName'],
        center,
        squareSize,
      );
    } else if (limitedPieces.length == 2) {
      // 2 fichas: una al lado de la otra con MÁS ESPACIO
      final offset = squareSize * 0.28; // Aumentado de 0.22 a 0.28

      _drawSinglePiece(
        canvas,
        limitedPieces[0]['piece'],
        limitedPieces[0]['color'],
        limitedPieces[0]['colorName'],
        center - Offset(offset, 0),
        squareSize,
        radius: radius * 0.85,
      );

      _drawSinglePiece(
        canvas,
        limitedPieces[1]['piece'],
        limitedPieces[1]['color'],
        limitedPieces[1]['colorName'],
        center + Offset(offset, 0),
        squareSize,
        radius: radius * 0.85,
      );
    } else if (limitedPieces.length == 3) {
      // 3 fichas: 2 arriba, 1 abajo con más espacio
      final offsetX = squareSize * 0.26; // Aumentado
      final offsetY = squareSize * 0.22; // Aumentado

      _drawSinglePiece(canvas, limitedPieces[0]['piece'], limitedPieces[0]['color'], limitedPieces[0]['colorName'],
          center - Offset(offsetX, offsetY), squareSize, radius: radius * 0.75);
      _drawSinglePiece(canvas, limitedPieces[1]['piece'], limitedPieces[1]['color'], limitedPieces[1]['colorName'],
          center + Offset(offsetX, -offsetY), squareSize, radius: radius * 0.75);
      _drawSinglePiece(canvas, limitedPieces[2]['piece'], limitedPieces[2]['color'], limitedPieces[2]['colorName'],
          center + Offset(0, offsetY), squareSize, radius: radius * 0.75);
    } else if (limitedPieces.length >= 4) {
      // 4 fichas: 2x2 con más espacio
      final offset = squareSize * 0.24; // Aumentado de 0.18 a 0.24

      _drawSinglePiece(canvas, limitedPieces[0]['piece'], limitedPieces[0]['color'], limitedPieces[0]['colorName'],
          center - Offset(offset, offset), squareSize, radius: radius * 0.7);
      _drawSinglePiece(canvas, limitedPieces[1]['piece'], limitedPieces[1]['color'], limitedPieces[1]['colorName'],
          center + Offset(offset, -offset), squareSize, radius: radius * 0.7);
      _drawSinglePiece(canvas, limitedPieces[2]['piece'], limitedPieces[2]['color'], limitedPieces[2]['colorName'],
          center + Offset(-offset, offset), squareSize, radius: radius * 0.7);
      _drawSinglePiece(canvas, limitedPieces[3]['piece'], limitedPieces[3]['color'], limitedPieces[3]['colorName'],
          center + Offset(offset, offset), squareSize, radius: radius * 0.7);
    }
  }

  void _drawColorPieces(Canvas canvas, List<LudoPiece> pieces, Color color, String colorName, double squareSize, bool skipBoard) {
    for (final piece in pieces) {
      if (skipBoard && !piece.isHome && !piece.isFinished) continue;
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

  void _drawSinglePiece(Canvas canvas, LudoPiece piece, Color color, String colorName, Offset position, double squareSize, {double? radius}) {
    final pieceRadius = radius ?? squareSize * 0.42;

    final isHighlighted = highlightedPieceColor == colorName && highlightedPieceId == piece.id;

    // Sombra
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(position + Offset(4, 4), pieceRadius, shadowPaint);

    // Gradiente de la ficha
    final gradient = RadialGradient(
      colors: [color.withOpacity(0.9), color, color.withOpacity(0.7)],
      stops: [0.0, 0.6, 1.0],
    );

    final piecePaint = Paint()
      ..shader = gradient.createShader(Rect.fromCircle(center: position, radius: pieceRadius))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, pieceRadius, piecePaint);

    // Borde negro
    final borderPaint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3.5;
    canvas.drawCircle(position, pieceRadius, borderPaint);

    // Borde interior blanco
    final innerBorderPaint = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2.5;
    canvas.drawCircle(position, pieceRadius * 0.7, innerBorderPaint);

    // Brillo
    final highlightPaint = Paint()..color = Colors.white.withOpacity(0.7)..style = PaintingStyle.fill;
    canvas.drawCircle(position - Offset(pieceRadius * 0.25, pieceRadius * 0.35), pieceRadius * 0.28, highlightPaint);

    // Resaltado si está seleccionada
    if (isHighlighted) {
      final selectPaint = Paint()
        ..color = Colors.white.withOpacity(0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0;
      canvas.drawCircle(position, pieceRadius * 1.3, selectPaint);
    }
  }

  Offset _getHomePosition(String color, int pieceId, double squareSize) {
    final homes = {
      'yellow': Offset(3.0, 3.0),
      'green': Offset(12.0, 3.0),
      'red': Offset(12.0, 12.0),
      'blue': Offset(3.0, 12.0),
    };

    final basePos = homes[color]!;

    final positions = [
      Offset((basePos.dx - 0.75) * squareSize, (basePos.dy - 0.75) * squareSize),
      Offset((basePos.dx + 0.75) * squareSize, (basePos.dy - 0.75) * squareSize),
      Offset((basePos.dx - 0.75) * squareSize, (basePos.dy + 0.75) * squareSize),
      Offset((basePos.dx + 0.75) * squareSize, (basePos.dy + 0.75) * squareSize),
    ];

    return positions[pieceId];
  }

  Offset _getFinishPosition(String color, int pieceId, double squareSize) {
    final centerX = 7.5;
    final centerY = 7.5;

    switch (color) {
      case 'yellow':
        return Offset(centerX * squareSize, (centerY - 1.0 - pieceId * 0.55) * squareSize);
      case 'green':
        return Offset((centerX + 1.0 + pieceId * 0.55) * squareSize, centerY * squareSize);
      case 'red':
        return Offset(centerX * squareSize, (centerY + 1.0 + pieceId * 0.55) * squareSize);
      case 'blue':
        return Offset((centerX - 1.0 - pieceId * 0.55) * squareSize, centerY * squareSize);
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