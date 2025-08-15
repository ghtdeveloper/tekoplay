import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app.dart';
import '../../generated/l10n.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _appVersion = '';
  double _musicVolume = 0.5;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    _loadMusicVolume();
  }

  Future<void> _loadMusicVolume() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _musicVolume = prefs.getDouble('musicVolume') ?? 0.5;
    });
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = '${S.of(context).version}${info.version}';
    });
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
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildSettingsCard(
                  title: S.of(context).addAccount,
                  subtitle: S.of(context).signInAccount,
                  icon: Icons.account_circle_outlined,
                  onTap: () => _showLoginDialog(context),
                ),
                _buildSettingsCard(
                  title: S.of(context).gameMusic,
                  subtitle: S.of(context).adjustGameMusic,
                  icon: Icons.music_note,
                  onTap: () {
                    _showMusicVolumeDialog(context, _musicVolume, (
                      newVolume,
                    ) async {
                      setState(() {
                        _musicVolume = newVolume;
                      });
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setDouble('musicVolume', newVolume);
                    });
                  },
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
                  title: S.of(context).notifications,
                  subtitle: S.of(context).customNotifications,
                  icon: Icons.notification_important_sharp,
                  onTap: () {
                    _showNotificationsDialog(context);
                  },
                ),
                _buildSettingsCard(
                  title: S.of(context).privacyTitle,
                  subtitle: S.of(context).privacy,
                  icon: Icons.privacy_tip_outlined,
                  onTap: () {},
                ),
                _buildSettingsCard(
                  title: S.of(context).terms,
                  subtitle: S.of(context).termsCheck,
                  icon: Icons.description_outlined,
                  onTap: () {},
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
}

void _showLoginDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                  onTap: () {
                    Navigator.of(context).pop();
                    // TODO Aquí lógica de Google
                  },
                ),
              ),

              const SizedBox(height: 12),

              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                child: ListTile(
                  leading: const Icon(Icons.apple, size: 32),
                  title: Text(S.of(context).appleLogin),
                  onTap: () {
                    Navigator.of(context).pop();
                    //TODO Aquí lógica de Apple ID
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

void _showMusicVolumeDialog(
  BuildContext context,
  double currentVolume,
  Function(double) onVolumeChanged,
) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      double tempVolume = currentVolume;

      return Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.all(20),
        child: StatefulBuilder(
          builder: (context, setState) {
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
                      setState(() {
                        tempVolume = value;
                      });
                    },
                  ),

                  const SizedBox(height: 10),

                  Center(
                    child: ElevatedButton(
                      onPressed: () {
                        onVolumeChanged(tempVolume);
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

void _showNotificationsDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      bool reminderEnabled = true;
      bool messagesEnabled = true;

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
                          S.of(context).notifications,
                          style: TextStyle(
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
                  SwitchListTile(
                    title: Text(S.of(context).reminder),
                    value: reminderEnabled,
                    activeColor: Color(0xFFEC7A34),
                    onChanged: (bool value) {
                      setState(() {
                        reminderEnabled = value;
                      });
                    },
                  ),
                  SwitchListTile(
                    title: Text(S.of(context).messages),
                    value: messagesEnabled,
                    activeColor: Color(0xFFEC7A34),
                    onChanged: (bool value) {
                      setState(() {
                        messagesEnabled = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
