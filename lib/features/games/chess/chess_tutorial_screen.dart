import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import '../../../generated/l10n.dart';
import '../../adds/BannerAdWidget.dart';

class ChessImmersiveTutorialScreen extends StatefulWidget {
  const ChessImmersiveTutorialScreen({super.key});

  @override
  State<ChessImmersiveTutorialScreen> createState() =>
      _ChessImmersiveTutorialScreenState();
}

class _ChessImmersiveTutorialScreenState
    extends State<ChessImmersiveTutorialScreen> {
  final ChessBoardController _controller = ChessBoardController();

  int _currentStep = 0;


  final List<Map<String, String>> _steps =  [
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
      'to': 'a4',
    },
  ];

  @override
  void initState() {
    super.initState();
    _resetBoardForStep();
  }


  void _resetBoardForStep() {
    _controller.resetBoard();
    setState(() {});
  }


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
          title:  Text(S.of(context).congratulations),
          content: Text(S.of(context).completeTutorial),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:  Text(S.of(context).close),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  void _onUserMove() {
    final lastSan = _controller.getSan(); 
    final expectedSan = _steps[_currentStep]['san'];

    if (lastSan == expectedSan) {
      _showSnack('${S.of(context).firstMoveCompleted} ($lastSan)', isSuccess: true);
      Future.delayed(const Duration(milliseconds: 600), _nextStep);
    } else {
      _showSnack('${S.of(context).incorrectMove}: ${S.of(context).youDid} $lastSan, ${S.of(context).attempt} ${_steps[_currentStep]['san']}');
      _controller.undoMove();
    }
  }

  
  void _demoMove() async {
    final from = _steps[_currentStep]['from']!;
    final to = _steps[_currentStep]['to']!;
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
        title:  Text(
            (S.of(context).tutorialChessTitle),
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '${S.of(context).passed} ${_currentStep + 1} / $total',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const BannerAdWidget(),
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
                        label:  Text(S.of(context).watchMovement),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _resetBoardForStep,
                        icon: const Icon(Icons.replay),
                        label:  Text(S.of(context).resetPassed),
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

        
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ChessBoard(
                  controller: _controller,
                  boardColor: BoardColor.brown,
                  boardOrientation: PlayerColor.white,
                  enableUserMoves: true,
                  onMove: _onUserMove,
                ),
              ),
            ),

        
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
                      label:  Text(S.of(context).back),
                      style: TextButton.styleFrom(foregroundColor: Colors.white),
                    ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _nextStep,
                    icon: const Icon(Icons.chevron_right),
                    label: Text(_currentStep == total - 1 ? S.of(context).finish : S.of(context).next),
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                  ),
                ],
              ),
            ),
            const BannerAdWidget(),
          ],
        ),
      ),
    );
  }
}
