import 'package:flutter/material.dart';

class GameModeButton extends StatefulWidget {
  final String imagePath;
  final String label;
  final VoidCallback onPressed;
  final int animationDelay;

  const GameModeButton({
    super.key,
    required this.imagePath,
    required this.label,
    required this.onPressed,
    this.animationDelay = 0,
  });

  @override
  State<GameModeButton> createState() => _GameModeButtonState();
}

class _GameModeButtonState extends State<GameModeButton>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late Animation<double> _entryScale;
  late Animation<double> _entryFade;
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _entryScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutBack),
    );

    _entryFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _floatController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1800 + (widget.animationDelay * 200)),
    );

    _floatAnimation = Tween<double>(begin: -3.0, end: 3.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    Future.delayed(
      Duration(milliseconds: 100 + (widget.animationDelay * 100)),
      () {
        if (mounted) {
          _entryController.forward();
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) _floatController.repeat(reverse: true);
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _entryController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _entryFade,
      child: ScaleTransition(
        scale: _entryScale,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) {
            setState(() => _isPressed = false);
            widget.onPressed();
          },
          onTapCancel: () => setState(() => _isPressed = false),
          child: AnimatedScale(
            scale: _isPressed ? 0.90 : 1.0,
            duration: const Duration(milliseconds: 100),
            child: Container(
              width: 80,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: _isPressed ? 0.1 : 0.18),
                    blurRadius: _isPressed ? 4 : 10,
                    offset: Offset(0, _isPressed ? 2 : 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _floatAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _floatAnimation.value),
                        child: child,
                      );
                    },
                    child: Image.asset(
                      widget.imagePath,
                      height: 36,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
