import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../generated/l10n.dart';
import '../games/game_screen.dart';
import '../settings/settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  late AudioPlayer _audioPlayer;
  double _currentVolume = 0.5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initMusic();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _initMusic() async {
    _audioPlayer = AudioPlayer();
    await _loadAndApplyVolume();
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.play(AssetSource('audio/background_music.mp3'));
  }

  Future<void> _loadAndApplyVolume() async {
    final prefs = await SharedPreferences.getInstance();
    _currentVolume = prefs.getDouble('musicVolume') ?? 0.5;
    await _audioPlayer.setVolume(_currentVolume);
  }

  Future<void> _updateVolume(double newVolume) async {
    _currentVolume = newVolume;
    await _audioPlayer.setVolume(newVolume);
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _loadAndApplyVolume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardSize = screenWidth * 0.4;

    return Scaffold(
      backgroundColor: const Color(0xFFEC7A34),
      appBar: AppBar(
        title: const Text('TekoPlay', style: TextStyle(color: Colors.white)),
        automaticallyImplyLeading: false,
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: const Color(0xFFEC7A34),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(
                    onVolumeChangedLive: (newVolume) {
                      _updateVolume(newVolume);
                    },
                  ),
                ),
              );
              await _loadAndApplyVolume();
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                S.of(context).whatPlay,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: cardSize + 24,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GameCard(
                      imagePath: 'assets/images/chess.png',
                      title: S.of(context).chess,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                GameScreen(gameType: S.of(context).chess),
                          ),
                        );
                      },
                      size: cardSize,
                    ),
                    GameCard(
                      imagePath: 'assets/images/domino.png',
                      title: S.of(context).domino,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                GameScreen(gameType: S.of(context).domino),
                          ),
                        );
                      },
                      size: cardSize,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GameCard extends StatelessWidget {
  final String imagePath;
  final String title;
  final VoidCallback onTap;
  final double size;

  const GameCard({
    super.key,
    required this.imagePath,
    required this.title,
    required this.onTap,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(child: Image.asset(imagePath, fit: BoxFit.contain)),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}