import 'dart:math';
import 'package:flutter/material.dart';
import '../service/betting_security_service.dart';
import '../../generated/l10n.dart';

class CaptchaVerificationDialog extends StatefulWidget {
  const CaptchaVerificationDialog({super.key});

  @override
  State<CaptchaVerificationDialog> createState() => _CaptchaVerificationDialogState();
}

class _CaptchaVerificationDialogState extends State<CaptchaVerificationDialog> {
  final _random = Random();
  late int _numA;
  late int _numB;
  late String _operator;
  late int _answer;
  final _controller = TextEditingController();
  bool _verified = false;
  bool _error = false;
  int _attempts = 0;

  @override
  void initState() {
    super.initState();
    _generateChallenge();
  }

  void _generateChallenge() {
    _numA = _random.nextInt(20) + 5;
    _numB = _random.nextInt(10) + 2;
    final ops = ['+', '-', 'x'];
    _operator = ops[_random.nextInt(ops.length)];
    switch (_operator) {
      case '+':
        _answer = _numA + _numB;
        break;
      case '-':
        if (_numB > _numA) {
          final temp = _numA;
          _numA = _numB;
          _numB = temp;
        }
        _answer = _numA - _numB;
        break;
      case 'x':
        _numA = _random.nextInt(9) + 2;
        _numB = _random.nextInt(9) + 2;
        _answer = _numA * _numB;
        break;
    }
    _controller.clear();
    _error = false;
  }

  void _verify() {
    final input = int.tryParse(_controller.text.trim());
    if (input == _answer) {
      BettingSecurityService().recordCaptchaPass();
      setState(() => _verified = true);
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) Navigator.pop(context, true);
      });
    } else {
      _attempts++;
      setState(() {
        _error = true;
        _generateChallenge();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _verified ? Icons.check_circle : Icons.security,
              size: 48,
              color: _verified ? Colors.green : const Color(0xFFEC7A34),
            ),
            const SizedBox(height: 16),
            Text(
              s.securityVerification,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              s.captchaDesc,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_verified)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Icon(Icons.check_circle, color: Colors.green, size: 56),
              )
            else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  '$_numA $_operator $_numB = ?',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  autofocus: true,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: '?',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFEC7A34), width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onSubmitted: (_) => _verify(),
                ),
              ),
              if (_error)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _attempts >= 3 ? s.tryAgain : s.incorrectAnswer,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(s.cancel),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _verify,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEC7A34),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: Text(s.verify),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
