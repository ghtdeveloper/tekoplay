import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class BotNameService {
  static const _prefKey = 'bot_names_seen';

  static const _bases = [
    'Carlos',  'Luis',     'Sofia',    'Andres',  'Camila',
    'Diego',   'Pablo',    'Laura',    'Maria',   'Jose',
    'Ricardo', 'Fernando', 'Jorge',    'Alejandro','Mario',
    'Victor',  'Gabriel',  'Roberto',  'Eduardo', 'Sergio',
    'Marco',   'Nicolas',  'Adrian',   'Kevin',   'Bryan',
    'Monica',  'Daniela',  'Valeria',  'Lucia',   'Karla',
    'Patricia','Natalia',  'Viviana',  'Lorena',  'Claudia',
    'Alejandra','Paola',   'Fernanda', 'Vanessa', 'Yessenia',
    'Christian','Armando', 'Esteban',  'Rodrigo', 'Ivan',
    'Samuel',  'Jonathan', 'Brayan',   'Mauricio','Gerardo',
  ];

  static const _suffixes = [
    '_99',   '_07',   '_2024', '_MX',   '_CR',
    '_GT',   '_COL',  '_VE',   '_ARG',  '_PE',
    '_pro',  '_play', '_game', '_top',  '_win',
    '01',    '55',    '77',    'X',     '_boss',
  ];

  static const _emojis = [
    '😎', '🎮', '👑', '🔥', '🏆', '⚡', '🌟', '🎲',
    '😤', '🎯', '🦁', '💫', '🚀', '😈', '🎪', '😏',
    '🦊', '💎', '🃏', '💪', '🐯', '💣', '🦅', '🌙',
    '🏎️', '🐲', '🦾', '💥', '🔮', '☠️',
  ];

  static List<String>? _pool;
  static List<String> get _allNames {
    _pool ??= [
      for (final base in _bases)
        for (final suffix in _suffixes)
          '$base$suffix',
    ];
    return _pool!;
  }

  static const _lossKey = 'bot_consecutive_bet_losses';

  static const int lossThreshold = 3;

  static Future<bool> shouldBotPlayWeak() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_lossKey) ?? 0) >= lossThreshold;
  }

  static Future<void> recordBetResult({required bool playerWon}) async {
    final prefs = await SharedPreferences.getInstance();
    if (playerWon) {
      await prefs.setInt(_lossKey, 0);
    } else {
      final current = prefs.getInt(_lossKey) ?? 0;
      await prefs.setInt(_lossKey, (current + 1).clamp(0, lossThreshold + 1));
    }
  }


  static Future<Map<String, String>> pickUnseenProfile(Random random) async {
    final prefs = await SharedPreferences.getInstance();
    final seen = Set<String>.from(prefs.getStringList(_prefKey) ?? []);
    final pool = _allNames;

    if (seen.length >= pool.length) {
      seen.clear();
      await prefs.remove(_prefKey);
    }

    final available = pool.where((n) => !seen.contains(n)).toList();
    final name = available[random.nextInt(available.length)];
    final emoji = _emojis[random.nextInt(_emojis.length)];

    seen.add(name);
    await prefs.setStringList(_prefKey, seen.toList());

    return {'name': name, 'emoji': emoji, 'avatar': emoji};
  }
}
