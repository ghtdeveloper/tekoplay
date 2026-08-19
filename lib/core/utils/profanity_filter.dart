class ProfanityFilter {
  static final Set<String> _badWords = {
    'puta', 'puto', 'mierda', 'coño', 'verga', 'pendejo', 'pendeja',
    'cabron', 'cabrón', 'cabrones', 'chingar', 'chingada', 'chingado',
    'joder', 'jodido', 'jodida', 'culo', 'culos', 'marica', 'maricon',
    'maricón', 'zorra', 'zorro', 'perra', 'perro', 'idiota', 'estupido',
    'estúpido', 'estupida', 'estúpida', 'imbecil', 'imbécil', 'tarado',
    'tarada', 'malparido', 'malparida', 'hijueputa', 'hijoputa',
    'gonorrea', 'mamaguevo', 'mamagüevo', 'cojonudo', 'cojones',
    'carajo', 'putas', 'putos', 'mierdas', 'vergon', 'vergudo',
    'pinche', 'chingon', 'chingón', 'culero', 'culera', 'mamón',
    'mamon', 'baboso', 'babosa', 'huevon', 'huevón', 'guevon',
    'güevon', 'boludo', 'boluda', 'pelotudo', 'pelotuda', 'forro',
    'garca', 'trolo', 'trola', 'pajero', 'pajera',
    'fuck', 'shit', 'bitch', 'asshole', 'dick', 'cock', 'pussy',
    'bastard', 'damn', 'cunt', 'whore', 'slut', 'nigger', 'faggot',
    'retard', 'motherfucker',
  };

  static bool containsProfanity(String text) {
    final normalized = _normalize(text);
    final words = normalized.split(RegExp(r'\s+'));
    for (final word in words) {
      if (_badWords.contains(word)) return true;
    }
    return false;
  }

  static String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[.,!?;:()¿¡]'), '')
        .replaceAll('4', 'a')
        .replaceAll('3', 'e')
        .replaceAll('1', 'i')
        .replaceAll('0', 'o')
        .replaceAll('@', 'a')
        .replaceAll('\$', 's')
        .trim();
  }
}
