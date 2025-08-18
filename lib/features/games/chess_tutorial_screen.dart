import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';

class ChessImmersiveTutorialScreen extends StatefulWidget {
  const ChessImmersiveTutorialScreen({super.key});

  @override
  State<ChessImmersiveTutorialScreen> createState() =>
      _ChessImmersiveTutorialScreenState();
}

class _ChessImmersiveTutorialScreenState
    extends State<ChessImmersiveTutorialScreen> {
  final ChessBoardController _controller = ChessBoardController();

  /// Paso actual (0..n-1)
  int _currentStep = 0;

  /// Definición de pasos sencillos: se valida por SAN (e4, Nf3, a4, etc.)
  /// Además incluimos from/to para la demo automática.
  final List<Map<String, String>> _steps = const [
    {
      'title': 'Mover Peones',
      'description':
          'Toca el peón de e2 y muévelo a e4. Los peones avanzan 1 o 2 casillas desde su posición inicial.',
      'san': 'e4',
      'from': 'e2',
      'to': 'e4',
    },
    {
      'title': 'Mover Caballos',
      'description':
          'Los caballos se mueven en L. Toca el caballo de g1 y muévelo a f3.',
      'san': 'Nf3',
      'from': 'g1',
      'to': 'f3',
    },
    {
      'title': 'Mover Torres',
      'description':
          'Las torres se mueven en línea recta. Mueve la torre de a1 a a4.',
      'san': 'a4',
      'from': 'a2',
      'to': 'a4', // Para poder llegar a a4, primero mueve el peón a2-a4 (SAN "a4")
    },
  ];

  @override
  void initState() {
    super.initState();
    _resetBoardForStep();
  }

  /// Reinicia el tablero para practicar el paso actual desde la posición inicial.
  void _resetBoardForStep() {
    _controller.resetBoard();
    // Si tu paquete tuviera animaciones lentas o algo en curso, puedes esperar un frame.
    setState(() {});
  }

  /// Avanza al siguiente paso o muestra finalización.
  void _nextStep() async {
    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
      _resetBoardForStep();
    } else {
      // Fin del tutorial
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('¡Felicidades!'),
          content: const Text('Has completado el tutorial.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  /// Se llama después de cada movimiento del usuario.
  /// La API actual de flutter_chess_board expone la última jugada con getSan().
  void _onUserMove() {
    final lastSan = _controller.getSan(); // p.ej. "e4", "Nf3", "a4"
    final expectedSan = _steps[_currentStep]['san'];

    if (lastSan == expectedSan) {
      _showSnack('¡Bien hecho! Movimiento correcto ($lastSan)', isSuccess: true);
      Future.delayed(const Duration(milliseconds: 600), _nextStep);
    } else {
      _showSnack('Movimiento incorrecto: hiciste $lastSan, intenta ${_steps[_currentStep]['san']}');
      _controller.undoMove();
    }
  }

  /// Demostración automática del movimiento esperado en el paso actual.
  void _demoMove() async {
    final from = _steps[_currentStep]['from']!;
    final to = _steps[_currentStep]['to']!;
    // Reinicia el tablero por si el usuario probó algo
    _resetBoardForStep();
    await Future.delayed(const Duration(milliseconds: 200));
    _controller.makeMove(from: from, to: to);
  }

  void _showSnack(String msg, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isSuccess ? Colors.green : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];
    final total = _steps.length;

    return Scaffold(
      backgroundColor: const ui.Color(0xFFEC7A34),
      appBar: AppBar(
        backgroundColor: const ui.Color(0xFFEC7A34),
        elevation: 0,
        title: const Text('Tutorial de Ajedrez'),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Paso ${_currentStep + 1} / $total',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Título y descripción
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step['title']!,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    step['description']!,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _demoMove,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Ver movimiento'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _resetBoardForStep,
                        icon: const Icon(Icons.replay),
                        label: const Text('Reiniciar paso'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Tablero
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ChessBoard(
                  controller: _controller,
                  boardColor: BoardColor.brown,
                  boardOrientation: PlayerColor.white,
                  enableUserMoves: true,
                  onMove: _onUserMove, // <- importante: ahora es VoidCallback
                ),
              ),
            ),

            // Navegación simple entre pasos (opcional)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    TextButton.icon(
                      onPressed: () {
                        setState(() => _currentStep--);
                        _resetBoardForStep();
                      },
                      icon: const Icon(Icons.chevron_left),
                      label: const Text('Atrás'),
                      style: TextButton.styleFrom(foregroundColor: Colors.white),
                    ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _nextStep,
                    icon: const Icon(Icons.chevron_right),
                    label: Text(_currentStep == total - 1 ? 'Finalizar' : 'Siguiente'),
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
