import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../generated/l10n.dart';
import '../../../core/models/ludo_game_match.dart';
import 'ludo_board_painter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class LudoTutorialScreen extends StatefulWidget {
  const LudoTutorialScreen({super.key});

  @override
  State<LudoTutorialScreen> createState() => _LudoTutorialScreenState();
}

class _LudoTutorialScreenState extends State<LudoTutorialScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  bool _showLessonSelector = true;
  String? _selectedLesson;
  int _currentStep = 0;
  LudoGameState _gameState = LudoGameState.initial();
  bool _waitingForAction = false;
  bool _isScreenKeepOnActive = false;
  int _dice1Value = 0;
  int _dice2Value = 0;
  double _boardSize = 0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _arrowController;
  late Animation<double> _arrowAnimation;

  final Map<String, Map<String, dynamic>> _lessons = {
    'welcome': {
      'name': '¡Bienvenido al Parchís!',
      'icon': '👋',
      'color': Colors.purple,
      'steps': [
        {
          'title': '¡Bienvenido!',
          'description': 'Aprende a jugar Parchís paso a paso. Este tutorial te enseñará todo lo que necesitas saber.',
          'action': 'observe',
          'image': 'assets/tutorial/welcome.png',
        },
        {
          'title': 'Objetivo del Juego',
          'description': 'El objetivo es sacar tus 4 fichas de casa y llevarlas hasta el centro del tablero antes que tus oponentes.',
          'action': 'observe',
          'highlightArea': 'center',
        },
        {
          'title': 'Las Fichas',
          'description': 'Cada jugador tiene 4 fichas del mismo color. Las tuyas son AMARILLAS y están en la esquina superior izquierda.',
          'action': 'observe',
          'highlightArea': 'yellow-home',
        },
      ],
    },
    'dice': {
      'name': 'Los Dados',
      'icon': '🎲',
      'color': Colors.blue,
      'steps': [
        {
          'title': 'Dos Dados',
          'description': 'En Parchís se juega con DOS dados. Los lanzas juntos y puedes usar sus valores por separado o sumados.',
          'action': 'observe',
          'showDice': true,
          'dice1': 3,
          'dice2': 4,
        },
        {
          'title': 'Uso de los Dados',
          'description': 'Si sacas 3 y 4, puedes:\n• Mover una ficha 3 casillas\n• Mover otra ficha 4 casillas\n• O mover UNA ficha 7 casillas (3+4)',
          'action': 'observe',
          'showDice': true,
          'dice1': 3,
          'dice2': 4,
        },
        {
          'title': 'Dobles',
          'description': 'Si sacas el mismo número en ambos dados (dobles), ¡tienes un turno extra! Podrás lanzar de nuevo.',
          'action': 'observe',
          'showDice': true,
          'dice1': 5,
          'dice2': 5,
        },
      ],
    },
    'startingOut': {
      'name': 'Sacar Fichas de Casa',
      'icon': '🏠',
      'color': Colors.green,
      'steps': [
        {
          'title': 'Salir de Casa',
          'description': 'Para sacar una ficha de casa necesitas sacar un 5 o un 6 en cualquiera de los dados.',
          'action': 'observe',
          'setupPieces': true,
        },
        {
          'title': '¡Sacaste un 6!',
          'description': 'Perfecto, sacaste un 6. Ahora toca una de tus fichas AMARILLAS en la casa para sacarla.',
          'action': 'selectPieceInHome',
          'dice1': 6,
          'dice2': 2,
          'color': 'yellow',
          'pieceId': 0,
          'highlightPieces': [0],
        },
        {
          'title': '¡Excelente!',
          'description': 'Tu ficha salió de casa y está en la casilla de SALIDA (casilla amarilla). Desde aquí puede avanzar por el tablero.',
          'action': 'observe',
        },
        {
          'title': 'Turno Bonus',
          'description': 'Como sacaste un 6, ¡obtienes un turno extra! Puedes lanzar los dados de nuevo.',
          'action': 'observe',
          'showDice': true,
          'dice1': 6,
          'dice2': 2,
        },
      ],
    },
    'basicMovement': {
      'name': 'Movimiento Básico',
      'icon': '➡️',
      'color': Colors.orange,
      'steps': [
        {
          'title': 'Mover por el Tablero',
          'description': 'Las fichas avanzan por las casillas blancas siguiendo las flechas en sentido horario (como las agujas del reloj).',
          'action': 'observe',
          'setupPieces': true,
        },
        {
          'title': 'Elige tu Movimiento',
          'description': 'Sacaste 3 y 4. Toca tu ficha amarilla y elige con cuál dado quieres moverla.',
          'action': 'movePiece',
          'dice1': 3,
          'dice2': 4,
          'color': 'yellow',
          'pieceId': 0,
          'fromPosition': 0,
          'toPosition': 3,
          'highlightPieces': [0],
        },
        {
          'title': '¡Bien Hecho!',
          'description': 'Moviste tu ficha. Fíjate que cada casilla tiene un número que te ayuda a contar.',
          'action': 'observe',
        },
      ],
    },
    'safeSquares': {
      'name': 'Casillas Seguras',
      'icon': '⭐',
      'color': Colors.amber,
      'steps': [
        {
          'title': 'Estrellas de Seguridad',
          'description': 'Las casillas marcadas con ESTRELLAS rojas son especiales. Aquí tus fichas están SEGURAS.',
          'action': 'observe',
          'highlightStars': true,
        },
        {
          'title': 'Protección',
          'description': 'En una casilla con estrella, ningún oponente puede capturar tu ficha. ¡Es tu refugio!',
          'action': 'observe',
          'highlightStars': true,
        },
        {
          'title': 'Bloqueo',
          'description': 'Si colocas 2 o más fichas tuyas en una casilla (segura o no), creas un BLOQUEO. Ningún oponente puede pasar.',
          'action': 'observe',
          'setupBlock': true,
        },
      ],
    },
    'capturing': {
      'name': 'Capturar Oponentes',
      'icon': '⚔️',
      'color': Colors.red,
      'steps': [
        {
          'title': 'Capturar',
          'description': 'Si tu ficha cae en una casilla ocupada por UN oponente (que no sea estrella), ¡lo capturas!',
          'action': 'observe',
          'setupCapture': true,
        },
        {
          'title': '¡A Capturar!',
          'description': 'Sacaste 3. Mueve tu ficha amarilla para capturar la ficha verde.',
          'action': 'movePiece',
          'dice1': 3,
          'dice2': 1,
          'color': 'yellow',
          'pieceId': 0,
          'fromPosition': 10,
          'toPosition': 13,
          'captureOpponent': true,
          'highlightPieces': [0],
        },
        {
          'title': '¡Captura Exitosa!',
          'description': 'La ficha verde regresa a su casa. Además, ¡obtienes 20 casillas de bonus que puedes usar en tu próximo turno!',
          'action': 'observe',
        },
      ],
    },
    'homeStretch': {
      'name': 'La Recta Final',
      'icon': '🏁',
      'color': Colors.indigo,
      'steps': [
        {
          'title': 'Entrada a Casa',
          'description': 'Cuando completes la vuelta al tablero, tus fichas entran por el pasillo de tu color hacia el centro.',
          'action': 'observe',
          'highlightHomeStretch': 'yellow',
        },
        {
          'title': 'Cuenta Exacta',
          'description': 'Para llegar al centro necesitas sacar el número EXACTO. Si te pasas, el movimiento no cuenta.',
          'action': 'observe',
          'setupFinalStretch': true,
        },
        {
          'title': 'Victoria',
          'description': 'El primer jugador que meta sus 4 fichas en el centro ¡GANA EL JUEGO! 🏆',
          'action': 'observe',
          'highlightArea': 'center',
        },
      ],
    },
    'strategy': {
      'name': 'Estrategia Básica',
      'icon': '🧠',
      'color': Colors.teal,
      'steps': [
        {
          'title': 'Distribución',
          'description': 'Es mejor tener varias fichas en juego que todas en casa. Así tienes más opciones.',
          'action': 'observe',
        },
        {
          'title': 'Usa las Estrellas',
          'description': 'Intenta moverte de estrella en estrella para mantener tus fichas seguras.',
          'action': 'observe',
          'highlightStars': true,
        },
        {
          'title': 'Bloquea Estratégicamente',
          'description': 'Crear bloqueos cerca de las entradas de tus oponentes puede retrasar su avance.',
          'action': 'observe',
        },
        {
          'title': '¡Listo para Jugar!',
          'description': '¡Ya sabes todo lo necesario! Ahora ve y disfruta del juego. ¡Buena suerte! 🎉',
          'action': 'observe',
        },
      ],
    },
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enableWakeLock();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _arrowController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _arrowAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _arrowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disableWakeLock();
    _pulseController.dispose();
    _arrowController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_isScreenKeepOnActive) {
          _enableWakeLock();
        }
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
        if (mounted) {
          setState(() {
            _isScreenKeepOnActive = true;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error enabling WakeLock: $e');
      }
    }
  }

  Future<void> _disableWakeLock() async {
    try {
      if (await WakelockPlus.enabled) {
        await WakelockPlus.disable();
        if (mounted) {
          setState(() {
            _isScreenKeepOnActive = false;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error disabling WakeLock: $e');
      }
    }
  }

  void _selectLesson(String lessonKey) {
    setState(() {
      _selectedLesson = lessonKey;
      _showLessonSelector = false;
      _currentStep = 0;
      _waitingForAction = false;
      _gameState = LudoGameState.initial();
      _dice1Value = 0;
      _dice2Value = 0;
    });
    _setupStep();
  }

  void _setupStep() {
    if (_selectedLesson == null) return;

    final steps = _lessons[_selectedLesson]!['steps'] as List;
    if (_currentStep >= steps.length) return;

    final step = steps[_currentStep] as Map<String, dynamic>;

    setState(() {
      _gameState = LudoGameState.initial();
      _waitingForAction = step['action'] != 'observe';
      _dice1Value = 0;
      _dice2Value = 0;
    });

    if (step.containsKey('dice1')) {
      _dice1Value = step['dice1'] as int;
    }
    if (step.containsKey('dice2')) {
      _dice2Value = step['dice2'] as int;
    }

    if (step.containsKey('setupPieces') && step['setupPieces'] == true) {
      _gameState.yellowPieces[0].position = 0;
    }

    if (step.containsKey('setupCapture') && step['setupCapture'] == true) {
      _gameState.yellowPieces[0].position = 10;
      _gameState.greenPieces[0].position = 13;
    }

    if (step.containsKey('setupBlock') && step['setupBlock'] == true) {
      _gameState.yellowPieces[0].position = 8;
      _gameState.yellowPieces[1].position = 8;
    }

    if (step.containsKey('setupFinalStretch') && step['setupFinalStretch'] == true) {
      _gameState.yellowPieces[0].position = 54;
    }

    if (step.containsKey('fromPosition')) {
      final color = step['color'] as String;
      final pieceId = step['pieceId'] as int;
      final position = step['fromPosition'] as int;

      final pieces = _gameState.getPiecesByColor(color);
      if (pieceId < pieces.length) {
        pieces[pieceId].position = position;
      }
    }
  }

  void _handleBoardTap(Offset localPosition) {
    if (!_waitingForAction || _selectedLesson == null || _boardSize == 0) return;

    final steps = _lessons[_selectedLesson]!['steps'] as List;
    final step = steps[_currentStep] as Map<String, dynamic>;

    final squareSize = _boardSize / 15;

    String? tappedColor;
    int? tappedPieceId;

    for (int i = 0; i < _gameState.yellowPieces.length; i++) {
      final piece = _gameState.yellowPieces[i];
      final piecePos = _getPieceScreenPosition(piece, 'yellow', squareSize);
      if (piecePos != null) {
        final distance = (localPosition - piecePos).distance;
        if (distance < squareSize * 0.5) {
          tappedColor = 'yellow';
          tappedPieceId = i;
          break;
        }
      }
    }

    if (tappedColor != null && tappedPieceId != null) {
      _handlePieceTap(tappedColor, tappedPieceId);
    }
  }

  Offset? _getPieceScreenPosition(LudoPiece piece, String color, double squareSize) {
    if (piece.isHome) {
      return _getHomePosition(color, piece.id, squareSize);
    } else if (piece.isFinished) {
      return null;
    } else {
      return _getBoardPosition(piece.position, squareSize);
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

  Offset? _getBoardPosition(int position, double squareSize) {
    final positions = <Offset>[
      Offset(1, 6), Offset(2, 6), Offset(3, 6), Offset(4, 6), Offset(5, 6),
      Offset(6, 5), Offset(6, 4), Offset(6, 3), Offset(6, 2), Offset(6, 1), Offset(6, 0),
      Offset(7, 0), Offset(8, 0),
      Offset(8, 1), Offset(8, 2), Offset(8, 3), Offset(8, 4), Offset(8, 5),
    ];

    if (position >= 0 && position < positions.length) {
      final pos = positions[position];
      return Offset((pos.dx + 0.5) * squareSize, (pos.dy + 0.5) * squareSize);
    }
    return null;
  }

  void _handlePieceTap(String color, int pieceId) {
    if (!_waitingForAction || _selectedLesson == null) return;

    final steps = _lessons[_selectedLesson]!['steps'] as List;
    final step = steps[_currentStep] as Map<String, dynamic>;

    if (step['action'] == 'selectPieceInHome') {
      if (color == step['color'] && pieceId == step['pieceId']) {
        final pieces = _gameState.getPiecesByColor(color);
        pieces[pieceId].position = _getStartPosition(color);

        _showSnack('¡Correcto! Ficha sacada de casa', isSuccess: true);
        setState(() {
          _waitingForAction = false;
        });

        Future.delayed(const Duration(seconds: 2), _nextStep);
      } else {
        _showSnack('Toca la ficha correcta (la que brilla)', isSuccess: false);
      }
    } else if (step['action'] == 'movePiece') {
      if (color == step['color'] && pieceId == step['pieceId']) {
        final pieces = _gameState.getPiecesByColor(color);
        final targetPosition = step['toPosition'] as int;

        pieces[pieceId].position = targetPosition;

        if (step.containsKey('captureOpponent') && step['captureOpponent'] == true) {
          _gameState.greenPieces[0].position = -1;
          _showSnack('¡Captura exitosa! +20 casillas bonus', isSuccess: true);
        } else {
          _showSnack('¡Movimiento correcto!', isSuccess: true);
        }

        setState(() {
          _waitingForAction = false;
        });

        Future.delayed(const Duration(seconds: 2), _nextStep);
      } else {
        _showSnack('Toca la ficha correcta (la que brilla)', isSuccess: false);
      }
    }
  }

  int _getStartPosition(String color) {
    switch (color) {
      case 'yellow': return 0;
      case 'green': return 13;
      case 'red': return 26;
      case 'blue': return 39;
      default: return 0;
    }
  }

  void _nextStep() {
    if (_selectedLesson == null) return;

    final steps = _lessons[_selectedLesson]!['steps'] as List;

    if (_currentStep < steps.length - 1) {
      setState(() {
        _currentStep++;
        _waitingForAction = false;
      });
      _setupStep();
    } else {
      _showCompletionDialog();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _waitingForAction = false;
      });
      _setupStep();
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Text('🎉', style: TextStyle(fontSize: 32)),
            SizedBox(width: 12),
            Expanded(child: Text('¡Felicidades!')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '¡Has completado la lección!\n"${_lessons[_selectedLesson]!['name']}"',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star, color: Colors.amber, size: 28),
                  SizedBox(width: 8),
                  Text(
                    '¡Lección Completada!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade900,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.star, color: Colors.amber, size: 28),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _showLessonSelector = true;
                _selectedLesson = null;
                _currentStep = 0;
              });
            },
            child: Text('Ver más lecciones'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFEC7A34),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('¡A Jugar!'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, {bool isSuccess = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.info,
              color: Colors.white,
            ),
            SizedBox(width: 12),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: isSuccess ? Colors.green : Colors.orange,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: isSuccess ? 2 : 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildLessonSelector() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFEC7A34),
            Color(0xFFD66A2C),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('📚', style: TextStyle(fontSize: 32)),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Aprende a Jugar',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Tutorial Interactivo de Parchís',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: _lessons.length,
                itemBuilder: (context, index) {
                  final lessonKey = _lessons.keys.elementAt(index);
                  final lesson = _lessons[lessonKey]!;
                  final progress = 0;

                  return Card(
                    margin: EdgeInsets.only(bottom: 12),
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: InkWell(
                      onTap: () => _selectLesson(lessonKey),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    lesson['color'].withOpacity(0.3),
                                    lesson['color'].withOpacity(0.1),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: lesson['color'].withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  lesson['icon'],
                                  style: TextStyle(fontSize: 36),
                                ),
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    lesson['name'],
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(Icons.play_circle_outline, size: 16, color: Colors.grey[600]),
                                      SizedBox(width: 4),
                                      Text(
                                        '${(lesson['steps'] as List).length} pasos',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      Spacer(),
                                      if (progress > 0) ...[
                                        Icon(Icons.check_circle, size: 16, color: Colors.green),
                                        SizedBox(width: 4),
                                        Text(
                                          'Completado',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 20,
                              color: lesson['color'],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTutorial() {
    if (_selectedLesson == null) return const SizedBox();

    final lessonData = _lessons[_selectedLesson]!;
    final steps = lessonData['steps'] as List;
    final step = steps[_currentStep] as Map<String, dynamic>;
    final total = steps.length;

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [lessonData['color'], lessonData['color'].withOpacity(0.8)],
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      lessonData['icon'],
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step['title'],
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Paso ${_currentStep + 1} de $total',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline, color: Colors.orange, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        step['description'],
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black87,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (step.containsKey('showDice') && step['showDice'] == true) ...[
                SizedBox(height: 16),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTutorialDice(_dice1Value),
                      SizedBox(width: 16),
                      _buildTutorialDice(_dice2Value),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: Color(0xFFF5F5F5),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.maxWidth < constraints.maxHeight
                    ? constraints.maxWidth * 0.95
                    : constraints.maxHeight * 0.95;

                _boardSize = size;

                return Center(
                  child: GestureDetector(
                    onTapUp: (details) {
                      _handleBoardTap(details.localPosition);
                    },
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          CustomPaint(
                            painter: LudoBoardPainter(
                              gameState: _gameState,
                              highlightedPieceColor: null,
                              highlightedPieceId: null,
                              validMovePositions: [],
                            ),
                          ),
                          if (_waitingForAction && step.containsKey('highlightPieces'))
                            ..._buildHighlightedPieces(step, size / 15),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: Offset(0, -2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              LinearProgressIndicator(
                value: (_currentStep + 1) / total,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(lessonData['color']),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _currentStep > 0 ? _previousStep : null,
                      icon: const Icon(Icons.arrow_back, size: 20),
                      label: const Text('Anterior'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        foregroundColor: Colors.black87,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _showLessonSelector = true;
                        _selectedLesson = null;
                        _currentStep = 0;
                      });
                    },
                    icon: const Icon(Icons.home, size: 20),
                    label: const Text('Menú'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[100],
                      foregroundColor: Colors.orange[900],
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: !_waitingForAction ? _nextStep : null,
                      icon: const Icon(Icons.arrow_forward, size: 20),
                      label: Text(_currentStep == total - 1 ? 'Finalizar' : 'Siguiente'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: lessonData['color'],
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildHighlightedPieces(Map<String, dynamic> step, double squareSize) {
    final List<Widget> highlights = [];
    final highlightPieces = step['highlightPieces'] as List<int>;

    for (final pieceId in highlightPieces) {
      final piece = _gameState.yellowPieces[pieceId];
      final pos = _getPieceScreenPosition(piece, 'yellow', squareSize);

      if (pos != null) {
        highlights.add(
          Positioned(
            left: pos.dx - squareSize * 0.6,
            top: pos.dy - squareSize * 0.6,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: squareSize * 1.2,
                    height: squareSize * 1.2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.6),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );

        highlights.add(
          Positioned(
            left: pos.dx - squareSize * 0.3,
            top: pos.dy - squareSize * 1.2,
            child: AnimatedBuilder(
              animation: _arrowAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, -_arrowAnimation.value),
                  child: Icon(
                    Icons.arrow_downward,
                    color: Colors.white,
                    size: squareSize * 0.6,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      }
    }

    return highlights;
  }

  Widget _buildTutorialDice(int value) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: CustomPaint(
        painter: DiceDotsPainter(value),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const ui.Color(0xFFEC7A34),
      appBar: AppBar(
        backgroundColor: _showLessonSelector
            ? Color(0xFFEC7A34)
            : _lessons[_selectedLesson]?['color'] ?? Color(0xFFEC7A34),
        elevation: 0,
        title: Text(
          _showLessonSelector
              ? 'Tutorial de Parchís'
              : _lessons[_selectedLesson]?['name'] ?? '',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (!_showLessonSelector && _selectedLesson != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.school, size: 16, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        '${_currentStep + 1}/${(_lessons[_selectedLesson]!['steps'] as List).length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: _showLessonSelector ? _buildLessonSelector() : _buildTutorial(),
      ),
    );
  }
}

class DiceDotsPainter extends CustomPainter {
  final int value;

  DiceDotsPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final dotRadius = size.width * 0.08;
    final positions = <Offset>[];

    switch (value) {
      case 1:
        positions.add(Offset(size.width / 2, size.height / 2));
        break;
      case 2:
        positions.add(Offset(size.width * 0.3, size.height * 0.3));
        positions.add(Offset(size.width * 0.7, size.height * 0.7));
        break;
      case 3:
        positions.add(Offset(size.width * 0.3, size.height * 0.3));
        positions.add(Offset(size.width / 2, size.height / 2));
        positions.add(Offset(size.width * 0.7, size.height * 0.7));
        break;
      case 4:
        positions.add(Offset(size.width * 0.3, size.height * 0.3));
        positions.add(Offset(size.width * 0.7, size.height * 0.3));
        positions.add(Offset(size.width * 0.3, size.height * 0.7));
        positions.add(Offset(size.width * 0.7, size.height * 0.7));
        break;
      case 5:
        positions.add(Offset(size.width * 0.3, size.height * 0.3));
        positions.add(Offset(size.width * 0.7, size.height * 0.3));
        positions.add(Offset(size.width / 2, size.height / 2));
        positions.add(Offset(size.width * 0.3, size.height * 0.7));
        positions.add(Offset(size.width * 0.7, size.height * 0.7));
        break;
      case 6:
        positions.add(Offset(size.width * 0.3, size.height * 0.25));
        positions.add(Offset(size.width * 0.7, size.height * 0.25));
        positions.add(Offset(size.width * 0.3, size.height * 0.5));
        positions.add(Offset(size.width * 0.7, size.height * 0.5));
        positions.add(Offset(size.width * 0.3, size.height * 0.75));
        positions.add(Offset(size.width * 0.7, size.height * 0.75));
        break;
    }

    for (final pos in positions) {
      canvas.drawCircle(pos, dotRadius, paint);
    }
  }

  @override
  bool shouldRepaint(DiceDotsPainter oldDelegate) => oldDelegate.value != value;
}