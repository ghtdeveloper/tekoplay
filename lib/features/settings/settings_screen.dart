import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _appVersion = '';

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
                  onTap: () {},
                ),
                _buildSettingsCard(
                  title: 'Música del juego',
                  subtitle: 'Ajusta el volumen de la música',
                  icon: Icons.music_note,
                  onTap: () {},
                ),
                _buildSettingsCard(
                  title: 'Idioma',
                  subtitle: 'Cambiar lenguaje del juego',
                  icon: Icons.language,
                  onTap: () {},
                ),
                _buildSettingsCard(
                  title: 'Notificaciones',
                  subtitle: 'Personaliza tus notificaciones',
                  icon: Icons.notification_important_sharp,
                  onTap: () {},
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
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
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
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.black54)),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.black45, size: 16),
        onTap: onTap,
      ),
    );
  }
}
