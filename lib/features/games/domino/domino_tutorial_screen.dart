import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/domino_tile.dart';
import '../../../generated/l10n.dart';

// Tracks chain tile display orientation (which side is left/right on board)
class _PlayedTile {
  final int displayLeft;
  final int displayRight;
  bool get isDouble => displayLeft == displayRight;
  _PlayedTile({required this.displayLeft, required this.displayRight});
}

class _TutorialController {
  List<DominoTile> hand = [];
  List<_PlayedTile> chain = [];
  int? leftEnd;
  int? rightEnd;

  void reset() {
    hand.clear();
    chain.clear();
    leftEnd = null;
    rightEnd = null;
  }

  bool canPlayLeft(DominoTile tile) {
    if (chain.isEmpty) return true;
    return tile.left == leftEnd || tile.right == leftEnd;
  }

  bool canPlayRight(DominoTile tile) {
    if (chain.isEmpty) return true;
    return tile.left == rightEnd || tile.right == rightEnd;
  }

  bool canPlay(DominoTile tile) => canPlayLeft(tile) || canPlayRight(tile);

  bool playTile(DominoTile tile, {required bool isLeft}) {
    int dL, dR;
    if (chain.isEmpty) {
      dL = tile.left;
      dR = tile.right;
      leftEnd = dL;
      rightEnd = dR;
      chain.add(_PlayedTile(displayLeft: dL, displayRight: dR));
    } else if (isLeft) {
      if (!canPlayLeft(tile)) return false;
      if (tile.right == leftEnd) {
        dL = tile.left;
        dR = tile.right;
      } else {
        dL = tile.right;
        dR = tile.left;
      }
      leftEnd = dL;
      chain.insert(0, _PlayedTile(displayLeft: dL, displayRight: dR));
    } else {
      if (!canPlayRight(tile)) return false;
      if (tile.left == rightEnd) {
        dL = tile.left;
        dR = tile.right;
      } else {
        dL = tile.right;
        dR = tile.left;
      }
      rightEnd = dR;
      chain.add(_PlayedTile(displayLeft: dL, displayRight: dR));
    }
    hand.remove(tile);
    return true;
  }

  void buildPreChain(List<Map<String, dynamic>> entries) {
    for (final e in entries) {
      final tile = DominoTile(left: e['left'] as int, right: e['right'] as int, id: 'pre');
      final isLeft = e['side'] == 'left';
      playTile(tile, isLeft: isLeft);
    }
  }
}

// ──────────────────────────────────────────────────────────────────────────────

class DominoImmersiveTutorialScreen extends StatefulWidget {
  const DominoImmersiveTutorialScreen({super.key});

  @override
  State<DominoImmersiveTutorialScreen> createState() =>
      _DominoImmersiveTutorialScreenState();
}

class _DominoImmersiveTutorialScreenState
    extends State<DominoImmersiveTutorialScreen> with TickerProviderStateMixin {
  final _TutorialController _ctrl = _TutorialController();
  int _currentStep = 0;
  DominoTile? _selectedTile;
  late AnimationController _pulseCtrl;

  static const Color _feltColor = Color(0xFF2D7A3A);
  static const Color _tableDark = Color(0xFF1A4C1C);
  static const Color _tileColor = Color(0xFFFFF8E1);
  static const Color _tileBorder = Color(0xFF4A3728);
  static const Color _accentOrange = Color(0xFFEC7A34);

  // Steps: type='info' just reads and advances; type='play' requires interaction
  final List<Map<String, dynamic>> _steps = [
    {
      'type': 'info',
      'title': 'Las Fichas del Dominó',
      'description': 'Cada ficha tiene dos mitades con puntos. Los extremos deben coincidir para conectar fichas.',
      'infoType': 'tile_demo',
    },
    {
      'type': 'play',
      'title': 'Primera Jugada',
      'description': 'Selecciona [6·6] y tócala en el tablero.',
      'tiles': [
        {'left': 6, 'right': 6, 'id': '6-6'},
        {'left': 5, 'right': 3, 'id': '5-3'},
        {'left': 2, 'right': 4, 'id': '2-4'},
      ],
      'expectedTile': '6-6',
      'targetSide': null,
    },
    {
      'type': 'play',
      'title': 'Conectar a la Derecha',
      'description': 'Extremo derecho: [6]. Selecciona [6·3] y toca la zona DERECHA.',
      'tiles': [
        {'left': 6, 'right': 3, 'id': '6-3'},
        {'left': 5, 'right': 2, 'id': '5-2'},
        {'left': 1, 'right': 4, 'id': '1-4'},
      ],
      'preChain': [
        {'left': 6, 'right': 6},
      ],
      'expectedTile': '6-3',
      'targetSide': 'right',
    },
    {
      'type': 'play',
      'title': 'Conectar a la Izquierda',
      'description': 'Extremo izquierdo: [6]. Selecciona [6·1] y toca la zona IZQUIERDA.',
      'tiles': [
        {'left': 6, 'right': 1, 'id': '6-1'},
        {'left': 3, 'right': 2, 'id': '3-2'},
        {'left': 4, 'right': 5, 'id': '4-5'},
      ],
      'preChain': [
        {'left': 6, 'right': 6},
        {'left': 6, 'right': 3, 'side': 'right'},
      ],
      'expectedTile': '6-1',
      'targetSide': 'left',
    },
    {
      'type': 'info',
      'title': 'Pasar Turno',
      'description': 'Si ninguna ficha coincide, debes robar del mazo o pasar turno.',
      'infoType': 'blocked',
    },
    {
      'type': 'info',
      'title': '¡Cómo Ganar!',
      'description': 'El primero en quedarse sin fichas gana. Si nadie puede jugar, gana quien tenga menos puntos.',
      'infoType': 'win',
    },
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    _pulseCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
          ..repeat(reverse: true);
    _loadStep();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    // Delay so the pop animation completes before the orientation snaps back,
    // preventing overflow errors on the last rendered frames.
    Future.delayed(const Duration(milliseconds: 300), () {
      SystemChrome.setPreferredOrientations(
          [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    });
    super.dispose();
  }

  void _loadStep() {
    _ctrl.reset();
    _selectedTile = null;
    final step = _steps[_currentStep];
    if (step['type'] == 'info') {
      setState(() {});
      return;
    }
    final tilesMaps = step['tiles'] as List<Map<String, dynamic>>;
    _ctrl.hand = tilesMaps
        .map((m) => DominoTile(
            left: m['left'] as int,
            right: m['right'] as int,
            id: m['id'] as String))
        .toList();
    if (step.containsKey('preChain')) {
      _ctrl.buildPreChain(step['preChain'] as List<Map<String, dynamic>>);
    }
    setState(() {});
  }

  void _goNext() async {
    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
      _loadStep();
    } else {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(S.of(context).congratulations),
          content: Text(S.of(context).completeDominoTutorial),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(S.of(context).back)),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  void _goPrev() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _loadStep();
    }
  }

  void _onTileTap(DominoTile tile) {
    setState(() => _selectedTile = _selectedTile == tile ? null : tile);
  }

  void _onDropZoneTap({required bool isLeft}) {
    if (_selectedTile == null) return;
    final step = _steps[_currentStep];
    if (step['type'] != 'play') return;

    final expectedId = step['expectedTile'] as String;
    final targetSide = step['targetSide'] as String?;

    if (_selectedTile!.id != expectedId) {
      _showMsg('Esa no es la ficha correcta — selecciona [${_tileLabel(expectedId)}]');
      return;
    }

    if (targetSide != null) {
      final needsLeft = targetSide == 'left';
      if (needsLeft != isLeft) {
        final side = targetSide == 'left' ? 'IZQUIERDA' : 'DERECHA';
        _showMsg('Colócala del lado $side');
        return;
      }
    }

    final placed = _ctrl.playTile(_selectedTile!, isLeft: isLeft);
    if (placed) {
      setState(() => _selectedTile = null);
      _showMsg('¡Muy bien!', success: true);
      Future.delayed(const Duration(milliseconds: 700), _goNext);
    } else {
      _showMsg('No se puede colocar ahí');
    }
  }

  void _demoMove() {
    final step = _steps[_currentStep];
    if (step['type'] != 'play') return;
    final expectedId = step['expectedTile'] as String;
    final targetSide = step['targetSide'] as String?;
    final tile = _ctrl.hand.firstWhere((t) => t.id == expectedId,
        orElse: () => _ctrl.hand.first);
    final isLeft = targetSide == 'left' || (targetSide == null && _ctrl.chain.isEmpty);
    setState(() => _selectedTile = null);
    _ctrl.playTile(tile, isLeft: isLeft);
    setState(() {});
    Future.delayed(const Duration(milliseconds: 700), _goNext);
  }

  String _tileLabel(String id) {
    final parts = id.replaceAll(RegExp(r'[^0-9-]'), '').split('-');
    if (parts.length >= 2) return '${parts[0]}·${parts[1]}';
    return id;
  }

  void _showMsg(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: success ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1400),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // During landscape→portrait transition the widget briefly renders with
    // portrait dimensions causing overflow. Show a safe fallback instead.
    final orientation = MediaQuery.of(context).orientation;
    if (orientation == Orientation.portrait) {
      return Scaffold(
        backgroundColor: _tableDark,
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.screen_rotation, color: Colors.white38, size: 48),
            const SizedBox(height: 12),
            const Text('Gira el dispositivo a horizontal',
                style: TextStyle(color: Colors.white54, fontSize: 14)),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: Colors.white38),
              label: const Text('Volver',
                  style: TextStyle(color: Colors.white54)),
            ),
          ]),
        ),
      );
    }

    final step = _steps[_currentStep];
    return Scaffold(
      backgroundColor: _feltColor,
      body: SafeArea(
        child: ClipRect(
          child: Column(
            children: [
              _buildHeader(step),
              Expanded(child: _buildContent(step)),
              _buildFooter(step),
            ],
          ),
        ),
      ),
    );
  }

  // ── HEADER ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(Map<String, dynamic> step) {
    final isPlay = step['type'] == 'play';
    return ClipRect(
      child: Container(
      height: 52,
      color: _tableDark,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28),
          ),
          const SizedBox(width: 8),
          // Progress dots
          Row(
            children: List.generate(_steps.length, (i) {
              final done = i < _currentStep;
              final current = i == _currentStep;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: current ? 18 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: done
                      ? _accentOrange
                      : current
                          ? Colors.white
                          : Colors.white30,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step['title']!,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(step['description']!,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 10, height: 1.2),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (isPlay) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _demoMove,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: _accentOrange,
                    borderRadius: BorderRadius.circular(8)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.play_arrow, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text('Ver jugada',
                      style: TextStyle(color: Colors.white, fontSize: 10)),
                ]),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: _loadStep,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.replay, color: Colors.white54, size: 14),
              ),
            ),
          ],
        ],
      ),
      ),
    );
  }

  // ── CONTENT ────────────────────────────────────────────────────────────────

  Widget _buildContent(Map<String, dynamic> step) {
    if (step['type'] == 'info') return _buildInfoContent(step);
    return _buildPlayContent();
  }

  // ── INFO STEPS ─────────────────────────────────────────────────────────────

  Widget _buildInfoContent(Map<String, dynamic> step) {
    switch (step['infoType'] as String) {
      case 'tile_demo':
        return _buildTileDemoInfo();
      case 'blocked':
        return _buildBlockedInfo();
      case 'win':
        return _buildWinInfo();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTileDemoInfo() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Single tile explained
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('Una ficha',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 10),
            _buildDominoTile(
                left: 3, right: 5, isPortrait: true, width: 44, height: 80),
            const SizedBox(height: 6),
            const Text('[3 · 5]',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
            const SizedBox(height: 3),
            const Text('3 puntos  +  5 puntos',
                style: TextStyle(color: Colors.white54, fontSize: 10)),
          ]),
          const SizedBox(width: 28),
          Container(width: 1, height: 80, color: Colors.white24),
          const SizedBox(width: 28),
          // Connection example
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('Conectar fichas',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _buildDominoTile(
                  left: 2, right: 5, isPortrait: false, width: 72, height: 36),
              const SizedBox(width: 3),
              _buildDominoTile(
                  left: 5, right: 3, isPortrait: false, width: 72, height: 36),
            ]),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('[2·5]',
                  style: TextStyle(color: Colors.white54, fontSize: 11)),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: _accentOrange,
                    borderRadius: BorderRadius.circular(6)),
                child: const Text('5 = 5',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 6),
              const Text('[5·3]',
                  style: TextStyle(color: Colors.white54, fontSize: 11)),
            ]),
            const SizedBox(height: 6),
            const Text('Los 5 coinciden — se pueden unir',
                style: TextStyle(color: Colors.white70, fontSize: 10)),
          ]),
        ],
      ),
    );
  }

  Widget _buildBlockedInfo() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.black26, borderRadius: BorderRadius.circular(14)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Extremos de la cadena',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _buildEndBadge(2, active: false),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('——', style: TextStyle(color: Colors.white30)),
            ),
            _buildEndBadge(4, active: false),
          ]),
          const SizedBox(height: 14),
          const Text('Tu mano: [1·5]  [3·6]  [0·0]',
              style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 6),
          const Text('Ninguna coincide con 2 ni con 4',
              style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
                color: _accentOrange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: _accentOrange.withValues(alpha: 0.5))),
            child: const Text('Roba del mazo  •  o pasa turno',
                style: TextStyle(
                    color: _accentOrange,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    );
  }

  Widget _buildWinInfo() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 36),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.black26, borderRadius: BorderRadius.circular(14)),
        child: const Column(mainAxisSize: MainAxisSize.min, children: [
          _WinRule(
              icon: Icons.emoji_events,
              color: Colors.amber,
              text:
                  'Coloca todas tus fichas primero → GANAS la ronda'),
          SizedBox(height: 14),
          _WinRule(
              icon: Icons.lock_outline,
              color: Colors.redAccent,
              text:
                  'Si nadie puede jugar → gana quien tenga MENOS puntos en mano'),
          SizedBox(height: 14),
          _WinRule(
              icon: Icons.monetization_on,
              color: Color(0xFFEC7A34),
              text:
                  '¡Gana monedas y diamantes con cada victoria en línea!'),
        ]),
      ),
    );
  }

  Widget _buildEndBadge(int value, {bool active = true}) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: active ? _accentOrange : Colors.white24,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text('$value',
            style: TextStyle(
                color: active ? Colors.white : Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
      ),
    );
  }

  // ── PLAY STEPS ─────────────────────────────────────────────────────────────

  Widget _buildPlayContent() {
    final hasChain = _ctrl.chain.isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasChain) _buildDropZone(isLeft: true),
        Expanded(
            child: hasChain ? _buildSnakeChainArea() : _buildEmptyBoard()),
        if (hasChain) _buildDropZone(isLeft: false),
      ],
    );
  }

  Widget _buildDropZone({required bool isLeft}) {
    final canPlace = _selectedTile != null &&
        (isLeft
            ? _ctrl.canPlayLeft(_selectedTile!)
            : _ctrl.canPlayRight(_selectedTile!));
    final endValue = isLeft ? _ctrl.leftEnd : _ctrl.rightEnd;

    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, __) {
        final pulse = canPlace ? _pulseCtrl.value : 0.0;
        return GestureDetector(
          onTap: canPlace ? () => _onDropZoneTap(isLeft: isLeft) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 58,
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 3),
            decoration: BoxDecoration(
              color: canPlace
                  ? _accentOrange.withValues(alpha: 0.08 + pulse * 0.12)
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: canPlace
                    ? _accentOrange.withValues(alpha: 0.55 + pulse * 0.45)
                    : Colors.white24,
                width: canPlace ? 2 : 1,
              ),
              boxShadow: canPlace
                  ? [
                      BoxShadow(
                          color: _accentOrange.withValues(alpha: pulse * 0.35),
                          blurRadius: 14,
                          spreadRadius: 2)
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                    isLeft
                        ? Icons.arrow_back_ios
                        : Icons.arrow_forward_ios,
                    color: canPlace ? _accentOrange : Colors.white24,
                    size: 13),
                const SizedBox(height: 6),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: canPlace ? _accentOrange : Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text('${endValue ?? '?'}',
                        style: TextStyle(
                            color: canPlace ? Colors.white : Colors.white54,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 5),
                Text(isLeft ? 'IZQ' : 'DER',
                    style: TextStyle(
                        color: canPlace ? Colors.white70 : Colors.white24,
                        fontSize: 9,
                        fontWeight: FontWeight.bold)),
                if (canPlace) ...[
                  const SizedBox(height: 3),
                  Text('Tocar',
                      style: TextStyle(
                          color: _accentOrange.withValues(alpha: 0.7 + pulse * 0.3),
                          fontSize: 8)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyBoard() {
    if (_selectedTile == null) {
      return const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.touch_app, color: Colors.white24, size: 40),
          SizedBox(height: 8),
          Text('Selecciona una ficha de tu mano',
              style: TextStyle(color: Colors.white38, fontSize: 13)),
        ]),
      );
    }
    return Center(
      child: GestureDetector(
        onTap: () => _onDropZoneTap(isLeft: true),
        child: AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (_, __) => Container(
            width: 110,
            height: 86,
            decoration: BoxDecoration(
              color: _accentOrange.withValues(alpha: 0.08 + _pulseCtrl.value * 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: _accentOrange
                      .withValues(alpha: 0.55 + _pulseCtrl.value * 0.45),
                  width: 2),
              boxShadow: [
                BoxShadow(
                    color: _accentOrange.withValues(alpha: _pulseCtrl.value * 0.35),
                    blurRadius: 16,
                    spreadRadius: 3)
              ],
            ),
            child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline, color: _accentOrange, size: 30),
                  SizedBox(height: 6),
                  Text('Colocar aquí',
                      style: TextStyle(color: Colors.white70, fontSize: 11)),
                ]),
          ),
        ),
      ),
    );
  }

  // ── SNAKE CHAIN ────────────────────────────────────────────────────────────

  Widget _buildSnakeChainArea() {
    // LayoutBuilder inside Expanded+Row gives bounded constraints (safe to use)
    return LayoutBuilder(builder: (ctx, constraints) {
      return Center(child: _buildSnakeChain(constraints.maxWidth));
    });
  }

  Widget _buildSnakeChain(double availWidth) {
    const double tW = 52.0, tH = 26.0, dW = 26.0, dH = 52.0;
    const double gap = 2.0, rowGap = 4.0, hPad = 8.0;
    final double rowW = availWidth - hPad * 2;

    final List<List<_PlayedTile>> rows = [];
    List<_PlayedTile> current = [];
    double curW = 0;
    for (final pt in _ctrl.chain) {
      final w = pt.isDouble ? dW : tW;
      if (current.isNotEmpty && curW + gap + w > rowW) {
        rows.add(current);
        current = [pt];
        curW = w;
      } else {
        if (current.isNotEmpty) curW += gap;
        curW += w;
        current.add(pt);
      }
    }
    if (current.isNotEmpty) rows.add(current);

    final singleRow = rows.length == 1;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0) SizedBox(height: rowGap),
            _buildSnakeRow(rows[i], i, rowW, singleRow, tW, tH, dW, dH, gap),
          ],
        ],
      ),
    );
  }

  Widget _buildSnakeRow(List<_PlayedTile> rowTiles, int idx, double rowW,
      bool singleRow, double tW, double tH, double dW, double dH, double gap) {
    final leftToRight = idx.isEven;
    final tiles = leftToRight ? rowTiles : rowTiles.reversed.toList();
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (int i = 0; i < tiles.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          _buildDominoTile(
            left: tiles[i].displayLeft,
            right: tiles[i].displayRight,
            isPortrait: tiles[i].isDouble,
            width: tiles[i].isDouble ? dW : tW,
            height: tiles[i].isDouble ? dH : tH,
          ),
        ],
      ],
    );
    if (singleRow) return row;
    return SizedBox(
      width: rowW,
      child: Align(
        alignment:
            leftToRight ? Alignment.centerLeft : Alignment.centerRight,
        child: row,
      ),
    );
  }

  // ── FOOTER ─────────────────────────────────────────────────────────────────

  Widget _buildFooter(Map<String, dynamic> step) {
    final isPlay = step['type'] == 'play';
    final isLast = _currentStep == _steps.length - 1;
    return Container(
      height: 58,
      color: _tableDark,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          if (_currentStep > 0) ...[
            OutlinedButton(
              onPressed: _goPrev,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white24),
                foregroundColor: Colors.white54,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Icon(Icons.chevron_left, size: 22),
            ),
            const SizedBox(width: 8),
          ],
          // Player hand tiles
          if (isPlay)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5E3C),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _accentOrange, width: 1.5),
                ),
                child: _buildHandTiles(),
              ),
            )
          else
            const Spacer(),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _goNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentOrange,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(
                isLast
                    ? 'Finalizar'
                    : isPlay
                        ? 'Saltar'
                        : 'Siguiente',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(width: 4),
              Icon(isLast ? Icons.check : Icons.chevron_right, size: 18),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildHandTiles() {
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      children: _ctrl.hand.map((tile) {
        final isSelected = _selectedTile == tile;
        final canPlay = _ctrl.canPlay(tile);
        return GestureDetector(
          onTap: () => _onTileTap(tile),
          child: AnimatedScale(
            scale: isSelected ? 1.15 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _buildDominoTile(
                left: tile.left,
                right: tile.right,
                isPortrait: true,
                width: 24,
                height: 44,
                isSelected: isSelected,
                isPlayable: canPlay && !isSelected,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── TILE WIDGET ────────────────────────────────────────────────────────────

  Widget _buildDominoTile({
    required int left,
    required int right,
    required bool isPortrait,
    required double width,
    required double height,
    bool isSelected = false,
    bool isPlayable = false,
  }) {
    final borderColor = isSelected
        ? _accentOrange
        : isPlayable
            ? Colors.green[400]!
            : _tileBorder;
    final borderWidth = (isSelected || isPlayable) ? 2.0 : 1.0;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFFFF176) : _tileColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? _accentOrange.withValues(alpha: 0.5)
                : isPlayable
                    ? Colors.green.withValues(alpha: 0.3)
                    : Colors.black38,
            blurRadius: isSelected ? 8 : 3,
            offset: const Offset(1, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: isPortrait
            ? Column(children: [
                Expanded(child: _buildPips(left)),
                Container(
                    height: 1.5,
                    color: _tileBorder.withValues(alpha: 0.5)),
                Expanded(child: _buildPips(right)),
              ])
            : Row(children: [
                Expanded(child: _buildPips(left)),
                Container(
                    width: 1.5,
                    color: _tileBorder.withValues(alpha: 0.5)),
                Expanded(child: _buildPips(right)),
              ]),
      ),
    );
  }

  Widget _buildPips(int count) {
    if (count == 0) return const SizedBox.expand();
    return LayoutBuilder(builder: (context, constraints) {
      final side = constraints.maxWidth < constraints.maxHeight
          ? constraints.maxWidth
          : constraints.maxHeight;
      final dotSize = (side * 0.22).clamp(3.0, 7.0);
      final pad = dotSize * 0.55;
      return Stack(
        children: _pipPositions(count)
            .map((align) => Align(
                  alignment: align,
                  child: Padding(
                    padding: EdgeInsets.all(pad),
                    child: Container(
                      width: dotSize,
                      height: dotSize,
                      decoration: const BoxDecoration(
                          color: Color(0xFF1A1A1A), shape: BoxShape.circle),
                    ),
                  ),
                ))
            .toList(),
      );
    });
  }

  List<Alignment> _pipPositions(int count) {
    switch (count) {
      case 1:
        return [Alignment.center];
      case 2:
        return [Alignment.topRight, Alignment.bottomLeft];
      case 3:
        return [Alignment.topRight, Alignment.center, Alignment.bottomLeft];
      case 4:
        return [
          Alignment.topLeft,
          Alignment.topRight,
          Alignment.bottomLeft,
          Alignment.bottomRight
        ];
      case 5:
        return [
          Alignment.topLeft,
          Alignment.topRight,
          Alignment.center,
          Alignment.bottomLeft,
          Alignment.bottomRight
        ];
      case 6:
        return [
          const Alignment(-1, -1),
          const Alignment(1, -1),
          const Alignment(-1, 0),
          const Alignment(1, 0),
          const Alignment(-1, 1),
          const Alignment(1, 1),
        ];
      default:
        return [];
    }
  }
}

// ── HELPERS ────────────────────────────────────────────────────────────────────

class _WinRule extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _WinRule({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: 10),
      Expanded(
          child: Text(text,
              style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.4))),
    ]);
  }
}
