import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

import '../../generated/l10n.dart';
import '../adds/banner_ad_widget.dart';
import '../adds/Interstitial_ad_helper.dart';
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        if (_isScreenKeepOnActive) {
          _enableWakeLock();
        }
        _loadAndApplyVolume();
        _checkEmailVerification();
        break;
      case AppLifecycleState.paused:
        _disableWakeLock();
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
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
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GameScreen(
                              gameType: gameType,
                              matchType: S.of(context).fun,
                            ),
                          ),
                        );
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
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GameScreen(
                              gameType: gameType,
                              matchType: S.of(context).bet,
                            ),
                          ),
                        );
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
    final cardSize = (screenWidth * 0.35).clamp(120.0, 160.0);

    return Scaffold(
      backgroundColor: const Color(0xFFEC7A34),
      appBar: AppBar(
        title: const Text('TekoPlay', style: TextStyle(color: Colors.white)),
        automaticallyImplyLeading: false,
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: const Color(0xFFEC7A34),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () async {
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
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const BannerAdWidget(),
          if (_currentUser != null && !_isEmailVerified)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16.0),
              child: Card(
                color: Colors.orange.shade50,
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.orange, width: 1),
                ),
                child: InkWell(
                  onTap: () => _showEmailVerificationDialog(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_outlined,
                          color: Colors.orange.shade700,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                S.of(context).verifyYourEmail,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                              Text(
                                S.of(context).tapHereForFeatures,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.orange.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.orange.shade600,
                          size: 16,
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
              margin: const EdgeInsets.all(16.0),
              child: Card(
                color: Colors.white,
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  onTap: () => _showLoginDialog(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.account_circle_outlined,
                          color: Color(0xFFEC7A34),
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                S.of(context).addAccount,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              Text(
                                S.of(context).loginToSaveProgress,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.black45,
                          size: 16,
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
                    const SizedBox(height: 20),
                    Container(
                      constraints: BoxConstraints(
                        maxWidth: screenWidth - 32,
                        maxHeight: (cardSize * 2) + 40,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Primera fila
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Ajedrez - Habilitado
                              GameCard(
                                imagePath: 'assets/images/chess.png',
                                title: S.of(context).chess,
                                onTap: () {
                                  _showGameTypeDialog(context, S.of(context).chess);
                                },
                                size: cardSize,
                                isEnabled: true,
                              ),
                              // Dominó - Deshabilitado
                              GameCard(
                                imagePath: 'assets/images/domino.png',
                                title: S.of(context).domino,
                                onTap: () {
                                },
                                size: cardSize,
                                isEnabled: false,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Segunda fila
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              GameCard(
                                imagePath: 'assets/images/parchis.png',
                                title: S.of(context).parchisShort,
                                onTap: () {
                                },
                                size: cardSize,
                                isEnabled: false,
                              ),
                              // Poker - Deshabilitado
                              GameCard(
                                imagePath: 'assets/images/poker.png',
                                title: S.of(context).poker,
                                onTap: () {
                                },
                                size: cardSize,
                                isEnabled: false,
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
    );
  }
}

class GameCard extends StatelessWidget {
  final String imagePath;
  final String title;
  final VoidCallback onTap;
  final double size;
  final bool isEnabled;

  const GameCard({
    super.key,
    required this.imagePath,
    required this.title,
    required this.onTap,
    required this.size,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        InkWell(
          onTap: isEnabled ? onTap : null,
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
                  Expanded(
                    child: Image.asset(
                      imagePath,
                      fit: BoxFit.contain,
                      color: isEnabled ? null : Colors.grey.withValues(alpha: 0.1),
                      colorBlendMode: isEnabled ? null : BlendMode.srcATop,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isEnabled ? Colors.black : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!isEnabled)
          Container(
            width: size,
            height: size,
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.70),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  color: Colors.white,
                  size: size * 0.12,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEC7A34),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    S.of(context).comingSoon,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: size * 0.06,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}