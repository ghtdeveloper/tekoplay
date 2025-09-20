import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tekoplay/core/service/firestore_service.dart';
import 'package:tekoplay/core/utils/constants.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../../app.dart';
import '../../core/service/auth_service.dart';
import '../../generated/l10n.dart';
import '../adds/BannerAdWidget.dart';
import '../games/common/widget_profile_image_editor.dart';


class SettingsScreen extends StatefulWidget {
  final Function(double)? onVolumeChangedLive;

  const SettingsScreen({super.key, this.onVolumeChangedLive});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  String _appVersion = '';
  double _musicVolume = 0.5;
  User? _currentUser;
  String? _currentPhotoUrl;
  bool _isEmailVerified = true;
  Timer? _emailVerificationTimer;
  bool _isEmailVerificationDialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAppVersion();
    _loadMusicVolume();
    _loadCurrentUser();
    _startEmailVerificationCheck();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _emailVerificationTimer?.cancel();
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _checkEmailVerification();
    }
  }

  // Dialog para mostrar cuando el email no está verificado
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
                      if (mounted) {
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

  Future<void> _loadMusicVolume() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _musicVolume = prefs.getDouble('musicVolume') ?? 0.5;
    });
  }

  Future<void> _saveMusicVolume(double volume) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('musicVolume', volume);
    setState(() {
      _musicVolume = volume;
    });
    if (widget.onVolumeChangedLive != null) {
      widget.onVolumeChangedLive!(volume);
    }
  }

  bool _isEmailPasswordLogin(User? user) {
    if (user == null) return false;
    return user.providerData.length == 1 &&
        user.providerData.first.providerId == 'password';
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = '${S.of(context).version}${info.version}';
    });
  }

  void _loadCurrentUser() async {
    final user = AuthService().getCurrentUser();
    final canAccess = await AuthService().canAccessApp();

    setState(() {
      _currentUser = user;
      _isEmailVerified = canAccess;
    });

    if (user != null) {
      final userData = await FirestoreService().getUser(user.uid);
      if (userData != null && mounted) {
        setState(() {
          _currentPhotoUrl = userData.urlPhoto;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      final user = await AuthService().signInWithGoogle();
      if (!mounted) return;

      if (user != null) {
        setState(() {
          _currentUser = user;
          _isEmailVerified = true;
          _currentPhotoUrl = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${S.of(context).welcome} ${user.displayName ?? ''}"),
            backgroundColor: Colors.green,
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
          _currentPhotoUrl = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${S.of(context).welcome} ${user.displayName ?? ''}"),
            backgroundColor: Colors.green,
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

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('No se pudo abrir $url');
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
                          onPressed:
                          isLoading
                              ? null
                              : () => Navigator.of(context).pop(),
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
                        onPressed:
                        isLoading
                            ? null
                            : () async {
                          if (emailController.text.trim().isEmpty ||
                              passwordController.text.trim().isEmpty ||
                              nameController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  S.of(context).fillAllFields,
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setDialogState(() {
                            isLoading = true;
                          });

                          try {
                            final user = await AuthService()
                                .registerWithEmail(
                              emailController.text.trim(),
                              passwordController.text.trim(),
                              nameController.text.trim(),
                            );

                            if (!mounted) return;

                            Navigator.of(context).pop();

                            if (user != null) {
                              setState(() {
                                _currentUser = user;
                                _isEmailVerified = false;
                                _currentPhotoUrl = null;
                              });

                              _showEmailVerificationSuccessDialog(context);
                            } else {
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    S.of(context).emailAlreadyRegistered,
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } catch (e) {
                            if (!mounted) return;
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  S.of(context).errorCreatingAccount,
                                ),
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
                        child:
                        isLoading
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
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
                          onPressed:
                          isLoading
                              ? null
                              : () => Navigator.of(context).pop(),
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

                    const SizedBox(height: 12),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed:
                        isLoading
                            ? null
                            : () {
                          Navigator.of(context).pop();
                          _showForgotPasswordDialog(context);
                        },
                        child: Text(
                          S.of(context).forgotPassword,
                          style: const TextStyle(
                            color: Color(0xFFEC7A34),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                        isLoading
                            ? null
                            : () async {
                          if (emailController.text.trim().isEmpty ||
                              passwordController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  S.of(context).fillAllFields,
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setDialogState(() {
                            isLoading = true;
                          });

                          try {
                            final user = await AuthService()
                                .signInWithEmail(
                              emailController.text.trim(),
                              passwordController.text.trim(),
                            );

                            if (!mounted) return;

                            Navigator.of(context).pop();

                            if (user != null) {
                              setState(() {
                                _currentUser = user;
                                _isEmailVerified = true;
                              });
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "${S.of(context).welcome} ${user.displayName ?? user.email}",
                                  ),
                                  backgroundColor: Colors.green,
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
                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(
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
                                content: Text(
                                  S.of(context).errorSignInEmail,
                                ),
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
                        child:
                        isLoading
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
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

  void _showForgotPasswordDialog(BuildContext context) {
    final emailController = TextEditingController();
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
                            S.of(context).forgotPassword,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed:
                          isLoading
                              ? null
                              : () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    Text(
                      S.of(context).enterEmailToReset,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                      textAlign: TextAlign.center,
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

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                        isLoading
                            ? null
                            : () async {
                          if (emailController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  S.of(context).enterValidEmail,
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setDialogState(() {
                            isLoading = true;
                          });

                          try {
                            await FirebaseAuth.instance
                                .sendPasswordResetEmail(
                              email: emailController.text.trim(),
                            );

                            if (!mounted) return;

                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  S.of(context).passwordResetSent,
                                ),
                                backgroundColor: Colors.green,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            setDialogState(() {
                              isLoading = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  S
                                      .of(context)
                                      .errorSendingPasswordReset,
                                ),
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
                        child:
                        isLoading
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                            strokeWidth: 2,
                          ),
                        )
                            : Text(
                          S.of(context).send,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEC7A34),
      appBar: AppBar(
        title: Text(
          S.of(context).settings,
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFFEC7A34),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
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

          if (_currentUser != null) _buildUserSection(),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _currentUser == null
                    ? _buildSettingsCard(
                  title: S.of(context).addAccount,
                  subtitle: S.of(context).signInAccount,
                  icon: Icons.account_circle_outlined,
                  onTap: () => _showLoginDialog(context),
                )
                    : _buildSettingsCard(
                  title: S.of(context).signOut,
                  subtitle: S.of(context).signOutAccount,
                  icon: Icons.logout,
                  onTap: () => _showLogoutDialog(context),
                ),

                _buildSettingsCard(
                  title: S.of(context).gameMusic,
                  subtitle: S.of(context).adjustGameMusic,
                  icon: Icons.music_note,
                  onTap: () => _showMusicVolumeDialog(context),
                ),
                _buildSettingsCard(
                  title: S.of(context).language,
                  subtitle: S.of(context).changeGameLanguage,
                  icon: Icons.language,
                  onTap: () {
                    _showLanguageDialog(context);
                  },
                ),
                _buildSettingsCard(
                  title: S.of(context).privacyTitle,
                  subtitle: S.of(context).privacy,
                  icon: Icons.privacy_tip_outlined,
                  onTap: () {
                    _launchUrl(AppConstants.urlPrivacy);
                  },
                ),
                _buildSettingsCard(
                  title: S.of(context).terms,
                  subtitle: S.of(context).termsCheck,
                  icon: Icons.description_outlined,
                  onTap: () {
                    _launchUrl(AppConstants.urlTerms);
                  },
                ),
                _buildSettingsCard(
                  title: S.of(context).technicalSupport,
                  subtitle: S.of(context).contactSupport,
                  icon: Icons.support_agent,
                  onTap: () => _showTechnicalSupportDialog(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _appVersion,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          const BannerAdWidget(),
        ],
      ),
    );
  }

  Widget _buildUserSection() {
    bool isEmailPasswordOnly = _isEmailPasswordLogin(_currentUser);

    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ProfileImageEditor(
            userId: _currentUser!.uid,
            currentImageUrl: _currentPhotoUrl ?? _currentUser!.photoURL,
            isEmailLogin: isEmailPasswordOnly,
            onImageUpdated: (newImageUrl) {
              setState(() {
                _currentPhotoUrl = newImageUrl;
              });
              _loadCurrentUser();
            },
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentUser?.displayName ?? 'Usuario',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currentUser?.email ?? '',
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
                if (isEmailPasswordOnly)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                     S.of(context).tapPhotoToChange,
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFEC7A34),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      color: Colors.white,
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Colors.black),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.black54)),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: Colors.black45,
          size: 16,
        ),
        onTap: onTap,
      ),
    );
  }

  void _showTechnicalSupportDialog(BuildContext context) {
    final TextEditingController messageController = TextEditingController();

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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        S.of(context).supportTitle,
                        style: const TextStyle(
                          fontSize: 20,
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

                const SizedBox(height: 20),

                Text(
                  S.of(context).describeIssue,
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: messageController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: S.of(context).writeIssueHere,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFEC7A34),
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),

                const SizedBox(height: 20),

                Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (messageController.text.trim().isNotEmpty) {
                        await _sendSupportMessage(
                          messageController.text.trim(),
                        );
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(S.of(context).pleaseWriteIssue),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEC7A34),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      S.of(context).send,
                      style: TextStyle(
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

  Future<void> _sendSupportMessage(String message) async {
    try {
      final technicalIssue = await FirestoreService().createTechnicalIssue(
        _currentUser,
        message,
      );
      if (!mounted) return;
      if (technicalIssue != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.of(context).sendIssueSuccessfully),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.of(context).sendIssueFailed),
            backgroundColor: Colors.red,
          ),
        );
      }
      await Future.delayed(const Duration(seconds: 1));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.of(context).sendIssueFailed),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showMusicVolumeDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        double tempVolume = _musicVolume;

        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          insetPadding: const EdgeInsets.all(20),
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return Padding(
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
                        S.of(context).volume,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Slider(
                      value: tempVolume,
                      min: 0,
                      max: 1,
                      divisions: 10,
                      label: '${(tempVolume * 100).round()}%',
                      activeColor: const Color(0xFFEC7A34),
                      inactiveColor: Colors.orange.shade100,
                      onChanged: (value) {
                        setDialogState(() {
                          tempVolume = value;
                        });
                        if (widget.onVolumeChangedLive != null) {
                          widget.onVolumeChangedLive!(value);
                        }
                      },
                    ),

                    const SizedBox(height: 10),

                    Center(
                      child: ElevatedButton(
                        onPressed: () async {
                          await _saveMusicVolume(tempVolume);
                          if (!context.mounted) return;
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEC7A34),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          S.of(context).accept,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
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

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            S.of(context).signOut,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(S.of(context).signOutConfirmation),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                S.of(context).cancel,
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _signOut();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEC7A34),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(S.of(context).signOut),
            ),
          ],
        );
      },
    );
  }

  Future<void> _signOut() async {
    try {
      await AuthService().signOut();
      setState(() {
        _currentUser = null;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.of(context).signOutSuccessful),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.of(context).signOutFailed),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

void _showLanguageDialog(BuildContext context) {
  String selectedLanguage = 'Español';

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          S.of(context).languageSelect,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  RadioListTile<String>(
                    title: Text(S.of(context).languageEs),
                    value: 'Español',
                    groupValue: selectedLanguage,
                    activeColor: const Color(0xFFEC7A34),
                    onChanged:
                        (value) => setState(() => selectedLanguage = value!),
                  ),
                  RadioListTile<String>(
                    title: Text(S.of(context).languageEn),
                    value: 'Inglés',
                    groupValue: selectedLanguage,
                    activeColor: const Color(0xFFEC7A34),
                    onChanged:
                        (value) => setState(() => selectedLanguage = value!),
                  ),
                  RadioListTile<String>(
                    title: Text(S.of(context).languageFr),
                    value: 'Francés',
                    groupValue: selectedLanguage,
                    activeColor: const Color(0xFFEC7A34),
                    onChanged:
                        (value) => setState(() => selectedLanguage = value!),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      _changeLanguage(selectedLanguage, context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEC7A34),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(S.of(context).accept),
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

Future<void> _changeLanguage(
    String selectedLanguage,
    BuildContext context,
    ) async {
  Locale newLocale;
  switch (selectedLanguage) {
    case 'Inglés':
      newLocale = const Locale('en');
      break;
    case 'Francés':
      newLocale = const Locale('fr');
      break;
    default:
      newLocale = const Locale('es');
  }

  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('languageCode', newLocale.languageCode);

  if (!context.mounted) return;

  TekoplayApp.setLocale(context, newLocale);
  Navigator.of(context).pop();
}

