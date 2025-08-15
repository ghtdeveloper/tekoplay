import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/splash/splash_screen.dart';
import 'generated/l10n.dart';

class TekoplayApp extends StatefulWidget {
  const TekoplayApp({super.key});

  static void setLocale(BuildContext context, Locale newLocale) {
    _TekoplayAppState? state =
        context.findAncestorStateOfType<_TekoplayAppState>();
    state?.setLocale(newLocale);
  }

  @override
  State<TekoplayApp> createState() => _TekoplayAppState();
}

class _TekoplayAppState extends State<TekoplayApp> {
  Locale? _locale;

  @override
  void initState() {
    super.initState();
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('languageCode') ?? 'es';
    setState(() {
      _locale = Locale(code);
    });
  }

  void setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tekoplay',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const SplashScreen(),
      locale: _locale,
      supportedLocales: S.delegate.supportedLocales,
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
