import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = 'Versión ${info.version}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEC7A34),
      appBar: AppBar(
        title: const Text(
          'Configuración',
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
                  title: 'Agregar cuenta',
                  subtitle: 'Iniciar sesión con tu cuenta',
                  icon: Icons.account_circle_outlined,
                  onTap: () => _showLoginDialog(context),
                ),
                _buildSettingsCard(
                  title: 'Música del juego',
                  subtitle: 'Ajusta el volumen de la música',
                  icon: Icons.music_note,
                  onTap: () {
                    _showMusicVolumeDialog(context, _musicVolume, (newVolume) {
                      setState(() {
                        _musicVolume = newVolume;
                      });
                      // TODO Aquí podrías aplicar el volumen a tu motor de audio
                    });
                  },
                ),
                _buildSettingsCard(
                  title: 'Idioma',
                  subtitle: 'Cambiar lenguaje del juego',
                  icon: Icons.language,
                  onTap: () {
                    _showLanguageDialog(context);
                  },
                ),
                _buildSettingsCard(
                  title: 'Notificaciones',
                  subtitle: 'Personaliza tus notificaciones',
                  icon: Icons.notification_important_sharp,
                  onTap: () {
                    _showNotificationsDialog(context);
                  },
                ),
                _buildSettingsCard(
                  title: 'Privacidad',
                  subtitle: 'Política de privacidad',
                  icon: Icons.privacy_tip_outlined,
                  onTap: () {},
                ),
                _buildSettingsCard(
                  title: 'Términos y condiciones',
                  subtitle: 'Consulta nuestros términos',
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

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  'Inicio de sesión',
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
                  title: const Text('Iniciar sesión con Google'),
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
                  title: const Text('Iniciar sesión con Apple ID'),
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

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      'Volumen de música',
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
                      child: const Text(
                        'Aceptar',
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
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      String selectedLanguage = 'Español';

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
                      const Expanded(
                        child: Text(
                          'Seleccionar idioma',
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
                  RadioListTile<String>(
                    title: const Text('Español'),
                    value: 'Español',
                    groupValue: selectedLanguage,
                    activeColor: Color(0xFFEC7A34),
                    onChanged: (value) {
                      setState(() {
                        selectedLanguage = value!;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('Inglés'),
                    value: 'Inglés',
                    groupValue: selectedLanguage,
                    activeColor: Color(0xFFEC7A34),
                    onChanged: (value) {
                      setState(() {
                        selectedLanguage = value!;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('Francés'),
                    value: 'Francés',
                    groupValue: selectedLanguage,
                    activeColor: Color(0xFFEC7A34),
                    onChanged: (value) {
                      setState(() {
                        selectedLanguage = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      //TODO CAMBIAR IDIOMA
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEC7A34),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Aceptar'),
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
                      const Expanded(
                        child: Text(
                          'Notificaciones',
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
                    title: const Text('Recordatorio de eventos'),
                    value: reminderEnabled,
                    activeColor: Color(0xFFEC7A34),
                    onChanged: (bool value) {
                      setState(() {
                        reminderEnabled = value;
                      });
                    },

                  ),
                  SwitchListTile(
                    title: const Text('Recibir nuevos mensajes'),
                    value: messagesEnabled,
                    activeColor: Color(0xFFEC7A34),
                    onChanged: (bool value) {
                      setState(() {
                        messagesEnabled = value;
                      });
                    },

                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Guardar los valores si es necesario
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEC7A34),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Aceptar'),
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
