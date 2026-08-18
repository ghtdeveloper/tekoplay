import 'package:flutter/material.dart';

class DominoPaseTutorialScreen extends StatefulWidget {
  const DominoPaseTutorialScreen({super.key});

  @override
  State<DominoPaseTutorialScreen> createState() => _DominoPaseTutorialScreenState();
}

class _DominoPaseTutorialScreenState extends State<DominoPaseTutorialScreen> {
  final PageController _pageCtrl = PageController();
  int _page = 0;

  static const Color _purple = Color(0xFF9C27B0);
  static const Color _purpleLight = Color(0xFFBA68C8);
  static const Color _purpleDark = Color(0xFF6A0080);
  static const Color _bg = Color(0xFF0D0A1E);

  static const List<_TutorialPage> _pages = [
    _TutorialPage(
      emoji: '🁣',
      title: '¿Qué es El Pase?',
      body:
          'El Pase es una modalidad especial de dominó para 3 o 4 jugadores.\n\n'
          'Se juega una sola mano por partida, solo con diamantes',
      highlight: null,
    ),
    _TutorialPage(
      emoji: '🀱',
      title: 'Cómo jugar',
      body:
          'Al inicio cada jugador recibe 7 fichas. El jugador con el doble más alto comienza.\n\n'
          'Coloca fichas conectando los números coincidentes en los extremos de la cadena.',
      highlight: null,
    ),
    _TutorialPage(
      emoji: '💸',
      title: '¡El Pase!',
      body:
          'Si no puedes jugar ninguna ficha, debes pasar turno. '
          'Cuando pasas, cada uno de tus rivales te paga una cantidad en diamantes.\n\n'
          'También se puede pasar si hay un bloqueo total (nadie puede jugar).',
      highlight: '¡Pasar puede ser rentable!',
    ),
    _TutorialPage(
      emoji: '🏆',
      title: '¿Cómo se gana?',
      body:
          'Gana quien coloque todas sus fichas primero.\n\n'
          'Si el juego se bloquea (nadie puede jugar), gana el jugador con menos puntos '
          'acumulados en sus fichas restantes.',
      highlight: null,
    ),
    _TutorialPage(
      emoji: '💎',
      title: 'La Apuesta',
      body:
          'Para entrar necesitas el doble de tu apuesta como saldo mínimo.\n\n'
          'El ganador se lleva el pozo menos una comisión del 10%.\n\n'
          'Los pagos de "pase" se suman o restan al premio final de cada jugador.',
      highlight: 'Solo diamantes — sin monedas',
    ),
  ];

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _pages.length - 1) {
      _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white54),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Cómo jugar — El Pase',
          style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) => _buildPage(_pages[i]),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(_TutorialPage page) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_purple, _purpleLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: _purple.withValues(alpha: 0.45), blurRadius: 20, offset: const Offset(0, 6)),
              ],
            ),
            child: Center(
              child: Text(page.emoji, style: const TextStyle(fontSize: 42)),
            ),
          ),

          const SizedBox(height: 28),

          Text(
            page.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Text(
              page.body,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 15,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          if (page.highlight != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_purple, _purpleDark]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: _purple.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    page.highlight!,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final isLast = _page == _pages.length - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_pages.length, (i) {
              final active = i == _page;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: active ? 20 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: active ? _purple : Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _next,
              style: ElevatedButton.styleFrom(
                backgroundColor: _purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Text(
                isLast ? '¡Entendido!' : 'Siguiente',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TutorialPage {
  final String emoji;
  final String title;
  final String body;
  final String? highlight;
  const _TutorialPage({
    required this.emoji,
    required this.title,
    required this.body,
    required this.highlight,
  });
}
