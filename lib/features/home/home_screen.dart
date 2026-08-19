import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

import '../../generated/l10n.dart';
import '../adds/banner_ad_widget.dart';
import '../adds/interstitial_ad_helper.dart';
import '../games/common/game_screen.dart';
import '../settings/settings_screen.dart';
import '../../core/service/auth_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  late AudioPlayer _audioPlayer;
  double _currentVolume = 0.5;
  bool _isPausedForNavigation = false;
  User? _currentUser;
  bool _isEmailVerified = true;
  Timer? _emailVerificationTimer;
  bool _isEmailVerificationDialogOpen = false;
  bool _isScreenKeepOnActive = false;
  late InterstitialAdHelper _interstitialHelper;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initMusic();
    _loadCurrentUser();
    _startEmailVerificationCheck();
    _interstitialHelper = InterstitialAdHelper(showFrequency: 3);
    _enableWakeLock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disableWakeLock();
    _audioPlayer.dispose();
    _emailVerificationTimer?.cancel();
    _interstitialHelper.dispose();
    super.dispose();
  }

  void _startEmailVerificationCheck() {
    _emailVerificationTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      await _checkEmailVerification();
    });
  }

  Future<void> _checkEmailVerification() async {
    final user = AuthService().getCurrentUser();
    if (user != null) {
      await user.reload();
      final updatedUser = FirebaseAuth.instance.currentUser;

      if (updatedUser != null) {
        final wasVerified = _isEmailVerified;
        final isVerified = await AuthService().canAccessApp();

        if (!wasVerified && isVerified) {
          await AuthService().checkEmailVerificationAndCreateUser();

          if (_isEmailVerificationDialogOpen && mounted) {
            Navigator.of(context).pop();
            _isEmailVerificationDialogOpen = false;
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(S.of(context).emailVerifiedSuccess),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 4),
              ),
            );
          }
        }

        setState(() {
          _currentUser = updatedUser;
          _isEmailVerified = isVerified;
        });
      }
    }
  }

  void _loadCurrentUser() async {
    final user = AuthService().getCurrentUser();
    final canAccess = await AuthService().canAccessApp();

    setState(() {
      _currentUser = user;
      _isEmailVerified = canAccess;
    });
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

  Future<void> _resumeMusic() async {
    await _loadAndApplyVolume();
    await _audioPlayer.resume();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        if (_isScreenKeepOnActive) {
          _enableWakeLock();
        }
        if (!_isPausedForNavigation) {
          _resumeMusic();
        }
        _checkEmailVerification();
        break;
      case AppLifecycleState.paused:
        _disableWakeLock();
        _audioPlayer.pause();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _audioPlayer.pause();
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _enableWakeLock() async {
    try {
      if (!await WakelockPlus.enabled) {
        await WakelockPlus.enable();
        if (mounted) {
          setState(() {
            _isScreenKeepOnActive = true;
          });
        }
        if (kDebugMode) {
          print('WakeLock enabled - screen will stay on');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error enabling WakeLock: $e');
      }
    }
  }

  Future<void> _disableWakeLock() async {
    try {
      if (await WakelockPlus.enabled) {
        await WakelockPlus.disable();
        if (mounted) {
          setState(() {
            _isScreenKeepOnActive = false;
          });
        }
        if (kDebugMode) {
          print('WakeLock disabled - screen can turn off normally');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error disabling WakeLock: $e');
      }
    }
  }

  void _showDominoModeDialog(BuildContext context) {
    if (_currentUser != null && !_isEmailVerified) {
      _showEmailVerificationDialog(context);
      return;
    }
    _interstitialHelper.showAdIfReady(onComplete: () {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Text(
                    S.of(context).selectGameType,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showGameTypeDialog(context, S.of(context).domino);
                      },
                      icon: Icon(Icons.sports_esports),
                      label: Text(
                        S.of(context).traditionalDomino,
                        style: TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        _isPausedForNavigation = true;
                        await _audioPlayer.pause();
                        if (!context.mounted) return;
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GameScreen(
                              gameType: S.of(context).domino,
                              matchType: S.of(context).pase,
                            ),
                          ),
                        );
                        _isPausedForNavigation = false;
                        await _resumeMusic();
                      },
                      icon: Icon(Icons.casino),
                      label: Text(
                        S.of(context).dominoPaseTitle,
                        style: TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9C27B0),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  void _showGameTypeDialog(BuildContext context, String gameType) {
    if (_currentUser != null && !_isEmailVerified) {
      _showEmailVerificationDialog(context);
      return;
    }
    _interstitialHelper.showAdIfReady(onComplete: () {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Text(
                    S.of(context).selectGameType,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        _isPausedForNavigation = true;
                        await _audioPlayer.pause();
                        if (!context.mounted) return;
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GameScreen(
                              gameType: gameType,
                              matchType: S.of(context).fun,
                            ),
                          ),
                        );
                        _isPausedForNavigation = false;
                        await _resumeMusic();
                      },
                      icon: Icon(Icons.sports_esports),
                      label: Text(
                        S.of(context).fun,
                        style: TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),

                  SizedBox(height: 15),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        _isPausedForNavigation = true;
                        await _audioPlayer.pause();
                        if (!context.mounted) return;
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GameScreen(
                              gameType: gameType,
                              matchType: S.of(context).bet,
                            ),
                          ),
                        );
                        _isPausedForNavigation = false;
                        await _resumeMusic();
                      },
                      icon: Icon(Icons.monetization_on),
                      label: Text(
                        S.of(context).bet,
                        style: TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF9800),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),

                ],
              ),
            ),
          );
        },
      );
    });
  }

  void _showEmailVerificationDialog(BuildContext context) {
    _isEmailVerificationDialogOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.email_outlined,
                  size: 64,
                  color: Color(0xFFEC7A34),
                ),
                SizedBox(height: 16),
                Text(
                  S.of(context).verifyEmail,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12),
                Text(
                  S.of(context).verificationEmailSent,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final success = await AuthService().resendEmailVerification();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success
                                ? S.of(context).verificationEmailResent
                                : S.of(context).errorResendEmail),
                            backgroundColor: success ? Colors.green : Colors.red,
                          ),
                        );
                      }
                    },
                    icon: Icon(Icons.refresh),
                    label: Text(S.of(context).resendEmail),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFEC7A34),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),

                SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      _isEmailVerificationDialogOpen = false;
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade300,
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(S.of(context).close),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      _isEmailVerificationDialogOpen = false;
    });
  }

  Future<void> _signInWithGoogle() async {
    try {
      final user = await AuthService().signInWithGoogle();
      if (!mounted) return;

      if (user != null) {
        setState(() {
          _currentUser = user;
          _isEmailVerified = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${S.of(context).loggedInAs} ${user.displayName ?? user.email}"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.of(context).errorSignInGoogle),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.of(context).errorSignInGoogle),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _signInWithFacebook() async {
    try {
      final user = await AuthService().signInWithFacebook();
      if (!mounted) return;

      if (user != null) {
        setState(() {
          _currentUser = user;
          _isEmailVerified = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${S.of(context).loggedInAs} ${user.displayName ?? user.email}"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.of(context).errorSignInFacebook),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.of(context).errorSignInFacebook),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _signInWithEmail(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          insetPadding: const EdgeInsets.all(20),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        S.of(context).tekoplayAccount,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _showSignUpDialog(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEC7A34),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      S.of(context).signUp,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _showLogInDialog(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      S.of(context).logIn,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSignUpDialog(BuildContext context) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final nameController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              insetPadding: const EdgeInsets.all(20),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            S.of(context).signUp,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: isLoading ? null : () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    TextField(
                      controller: nameController,
                      enabled: !isLoading,
                      decoration: InputDecoration(
                        labelText: S.of(context).name,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: emailController,
                      enabled: !isLoading,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: S.of(context).email,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: passwordController,
                      enabled: !isLoading,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: S.of(context).password,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : () async {
                          if (emailController.text.trim().isEmpty ||
                              passwordController.text.trim().isEmpty ||
                              nameController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(S.of(context).pleaseFillAllFields),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setDialogState(() {
                            isLoading = true;
                          });

                          try {
                            final user = await AuthService().registerWithEmail(
                              emailController.text.trim(),
                              passwordController.text.trim(),
                              nameController.text.trim(),
                            );

                            if (!context.mounted) return;

                            Navigator.of(context).pop();

                            if (user != null) {
                              setState(() {
                                _currentUser = user;
                                _isEmailVerified = false;
                              });

                              _showEmailVerificationSuccessDialog(context);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(S.of(context).emailAlreadyRegistered),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } catch (e) {
                            if (!mounted) return;
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(S.of(context).errorCreateAccount),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEC7A34),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            strokeWidth: 2,
                          ),
                        )
                            : Text(
                          S.of(context).createAccount,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEmailVerificationSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.mark_email_read_outlined,
                  size: 64,
                  color: Colors.green,
                ),
                SizedBox(height: 16),
                Text(
                  S.of(context).accountCreatedUpdt,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12),
                Text(
                  S.of(context).verificationEmailSent,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFEC7A34),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(S.of(context).understood),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLogInDialog(BuildContext context) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              insetPadding: const EdgeInsets.all(20),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            S.of(context).logIn,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: isLoading ? null : () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    TextField(
                      controller: emailController,
                      enabled: !isLoading,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: S.of(context).email,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: passwordController,
                      enabled: !isLoading,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: S.of(context).password,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : () async {
                          if (emailController.text.trim().isEmpty ||
                              passwordController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(S.of(context).pleaseFillAllFields),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setDialogState(() {
                            isLoading = true;
                          });

                          try {
                            final user = await AuthService().signInWithEmail(
                              emailController.text.trim(),
                              passwordController.text.trim(),
                            );

                            if (!context.mounted) return;

                            Navigator.of(context).pop();

                            if (user != null) {
                              setState(() {
                                _currentUser = user;
                                _isEmailVerified = true;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("${S.of(context).loggedInAs} ${user.displayName ?? user.email}"),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            } else {
                              final currentUser = AuthService().getCurrentUser();
                              if (currentUser != null && !currentUser.emailVerified) {
                                setState(() {
                                  _currentUser = currentUser;
                                  _isEmailVerified = false;
                                });
                                _showEmailVerificationDialog(context);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(S.of(context).invalidCredentials),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            if (!mounted) return;
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(S.of(context).errorLogin),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEC7A34),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            strokeWidth: 2,
                          ),
                        )
                            : Text(
                          S.of(context).logIn,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showLoginDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          insetPadding: const EdgeInsets.all(20),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),

                const SizedBox(height: 8),

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    S.of(context).login,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  child: ListTile(
                    leading: const Icon(
                      Icons.g_mobiledata,
                      color: Colors.red,
                      size: 32,
                    ),
                    title: Text(S.of(context).googleLogin),
                    onTap: () async {
                      Navigator.of(context).pop();
                      await _signInWithGoogle();
                    },
                  ),
                ),

                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  child: ListTile(
                    leading: const Icon(
                      Icons.facebook,
                      color: Colors.blue,
                      size: 32,
                    ),
                    title: Text(S.of(context).facebookLogin),
                    onTap: () async {
                      Navigator.of(context).pop();
                      await _signInWithFacebook();
                    },
                  ),
                ),

                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  child: ListTile(
                    leading: const Icon(
                      Icons.email,
                      color: Colors.black,
                      size: 32,
                    ),
                    title: Text(S.of(context).emailLogin),
                    onTap: () async {
                      Navigator.of(context).pop();
                      _signInWithEmail(context);
                    },
                  ),
                ),

                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardSize = (screenWidth * 0.40).clamp(130.0, 170.0);

    return Scaffold(
      backgroundColor: const Color(0xFFEC7A34),
      appBar: AppBar(
        title: const Text(
          'TekoPlay',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
            letterSpacing: 1.2,
          ),
        ),
        automaticallyImplyLeading: false,
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () async {
              _isPausedForNavigation = true;
              await _audioPlayer.pause();
              if (!context.mounted) return;
              final _ = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(
                    onVolumeChangedLive: (newVolume) {
                      _updateVolume(newVolume);
                    },
                  ),
                ),
              );
              _loadCurrentUser();
              _isPausedForNavigation = false;
              await _resumeMusic();
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFEC7A34),
              Color(0xFFE06820),
              Color(0xFFD45A15),
            ],
          ),
        ),
        child: Column(
          children: [
            if (_currentUser != null && !_isEmailVerified)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Card(
                  color: Colors.white.withValues(alpha: 0.15),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: InkWell(
                    onTap: () => _showEmailVerificationDialog(context),
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_outlined,
                            color: Colors.white,
                            size: 26,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  S.of(context).verifyYourEmail,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  S.of(context).tapHereForFeatures,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white.withValues(alpha: 0.7),
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            if (_currentUser == null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Card(
                  color: Colors.white.withValues(alpha: 0.15),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: InkWell(
                    onTap: () => _showLoginDialog(context),
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.account_circle_outlined,
                            color: Colors.white,
                            size: 26,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  S.of(context).addAccount,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  S.of(context).loginToSaveProgress,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white.withValues(alpha: 0.7),
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutBack,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value.clamp(0.0, 1.0),
                            child: Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: child,
                            ),
                          );
                        },
                        child: Text(
                          S.of(context).whatPlay,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            shadows: [
                              Shadow(
                                color: Color(0x40000000),
                                blurRadius: 8,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Container(
                        constraints: BoxConstraints(
                          maxWidth: screenWidth - 32,
                          maxHeight: (cardSize * 2) + 44,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                GameCard(
                                  imagePath: 'assets/images/chess.png',
                                  title: S.of(context).chess,
                                  onTap: () {
                                    _showGameTypeDialog(
                                        context, S.of(context).chess);
                                  },
                                  size: cardSize,
                                  isEnabled: true,
                                  animationDelay: 0,
                                ),
                                GameCard(
                                  imagePath: 'assets/images/domino.png',
                                  title: S.of(context).domino,
                                  onTap: () {
                                    _showDominoModeDialog(context);
                                  },
                                  size: cardSize,
                                  isEnabled: true,
                                  animationDelay: 1,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                GameCard(
                                  imagePath: 'assets/images/parchis.png',
                                  title: S.of(context).parchisShort,
                                  onTap: () {
                                    _showGameTypeDialog(
                                        context, S.of(context).parchisShort);
                                  },
                                  size: cardSize,
                                  isEnabled: true,
                                  animationDelay: 2,
                                ),
                                GameCard(
                                  imagePath: 'assets/images/poker.png',
                                  title: S.of(context).poker,
                                  onTap: () {},
                                  size: cardSize,
                                  isEnabled: false,
                                  animationDelay: 3,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const BannerAdWidget(),
          ],
        ),
      ),
    );
  }
}

class GameCard extends StatefulWidget {
  final String imagePath;
  final String title;
  final VoidCallback onTap;
  final double size;
  final bool isEnabled;
  final int animationDelay;

  const GameCard({
    super.key,
    required this.imagePath,
    required this.title,
    required this.onTap,
    required this.size,
    this.isEnabled = true,
    this.animationDelay = 0,
  });

  @override
  State<GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<GameCard>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _floatController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _floatAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _floatController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2000 + (widget.animationDelay * 300)),
    );

    _floatAnimation = Tween<double>(begin: -4.0, end: 4.0).animate(
      CurvedAnimation(
        parent: _floatController,
        curve: Curves.easeInOut,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    Future.delayed(
      Duration(milliseconds: 200 + (widget.animationDelay * 120)),
      () {
        if (mounted) {
          _controller.forward();
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted) _floatController.repeat(reverse: true);
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: child,
            ),
          ),
        );
      },
      child: GestureDetector(
        onTapDown: widget.isEnabled
            ? (_) => setState(() => _isPressed = true)
            : null,
        onTapUp: widget.isEnabled
            ? (_) {
                setState(() => _isPressed = false);
                widget.onTap();
              }
            : null,
        onTapCancel: widget.isEnabled
            ? () => setState(() => _isPressed = false)
            : null,
        child: AnimatedScale(
          scale: _isPressed ? 0.93 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeInOut,
          child: Stack(
            children: [
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: _isPressed ? 0.15 : 0.2),
                      blurRadius: _isPressed ? 8 : 16,
                      offset: Offset(0, _isPressed ? 3 : 6),
                      spreadRadius: _isPressed ? -2 : 0,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: AnimatedBuilder(
                        animation: _floatAnimation,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, _floatAnimation.value),
                            child: child,
                          );
                        },
                        child: Image.asset(
                          widget.imagePath,
                          fit: BoxFit.contain,
                          color: widget.isEnabled
                              ? null
                              : Colors.grey.withValues(alpha: 0.1),
                          colorBlendMode:
                              widget.isEnabled ? null : BlendMode.srcATop,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: widget.isEnabled
                            ? Colors.black87
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              if (!widget.isEnabled)
                Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        color: Colors.white.withValues(alpha: 0.9),
                        size: widget.size * 0.14,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEC7A34),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEC7A34)
                                  .withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          S.of(context).comingSoon,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: widget.size * 0.065,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
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