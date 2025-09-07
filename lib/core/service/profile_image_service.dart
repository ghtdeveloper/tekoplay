import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

class ProfileImageService {
  static final ProfileImageService _instance = ProfileImageService._internal();
  factory ProfileImageService() => _instance;
  ProfileImageService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  Future<bool> _requestPermissions() async {
    try {
      List<Permission> permissions = [];

      if (Platform.isAndroid) {
        permissions = [
          Permission.camera,
          Permission.photos,
          Permission.storage,
        ];
      } else if (Platform.isIOS) {
        permissions = [
          Permission.camera,
          Permission.photos,
        ];
      }

      Map<Permission, PermissionStatus> statuses = await permissions.request();


      bool cameraGranted = statuses[Permission.camera]?.isGranted ?? false;
      bool photosGranted = statuses[Permission.photos]?.isGranted ?? false;
      bool storageGranted = statuses[Permission.storage]?.isGranted ?? true;

      return cameraGranted && (photosGranted || storageGranted);

    } catch (e) {
      print('Error requesting permissions: $e');
      return false;
    }
  }

  Future<bool> _checkPermissions() async {
    bool cameraGranted = await Permission.camera.isGranted;
    bool photosGranted = await Permission.photos.isGranted;

    return cameraGranted && photosGranted;
  }

  Future<bool> _showPermissionDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Permisos requeridos'),
          content: Text(
              'Para cambiar tu foto de perfil necesitamos acceso a:\n\n'
                  '📷 Cámara - Para tomar fotos\n'
                  '🖼️ Galería - Para seleccionar fotos existentes\n\n'
                  '¿Deseas continuar?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Permitir'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFEC7A34),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    ) ?? false;
  }

  Future<void> _handlePermanentlyDenied(BuildContext context) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Permisos denegados'),
          content: Text(
              'Los permisos han sido denegados permanentemente. '
                  'Para usar esta función, ve a Configuración y habilita '
                  'los permisos de Cámara y Fotos para esta aplicación.'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: Text('Ir a Configuración'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFEC7A34),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<bool> requestPermissionsWithDialog(BuildContext context) async {
    if (await _checkPermissions()) {
      return true;
    }

    bool userAccepted = await _showPermissionDialog(context);
    if (!userAccepted) {
      return false;
    }

    bool granted = await _requestPermissions();

    if (!granted) {
      bool cameraPermanentlyDenied = await Permission.camera.isPermanentlyDenied;
      bool photosPermanentlyDenied = await Permission.photos.isPermanentlyDenied;

      if (cameraPermanentlyDenied || photosPermanentlyDenied) {
        await _handlePermanentlyDenied(context);
      }
    }

    return granted;
  }

  Future<XFile?> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 80,
      );
      return image;
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }

  Future<String?> uploadProfileImage(String userId, XFile imageFile) async {
    try {
      final File file = File(imageFile.path);
      final String path = 'profiles/$userId/image/profile_pict.png';

      final Reference ref = _storage.ref().child(path);
      final UploadTask uploadTask = ref.putFile(file);

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  Future<bool> deleteProfileImage(String userId) async {
    try {
      final String path = 'profiles/$userId/image/profile_pict.png';
      final Reference ref = _storage.ref().child(path);
      await ref.delete();
      return true;
    } catch (e) {
      print('Error deleting image: $e');
      return false;
    }
  }

  Future<String?> selectAndUploadImage(
      BuildContext context,
      String userId,
      ImageSource source
      ) async {
    // Verificar permisos con diálogo explicativo
    bool hasPermissions = await requestPermissionsWithDialog(context);
    if (!hasPermissions) {
      throw Exception('Permisos de cámara y galería requeridos');
    }

    // Seleccionar imagen
    final XFile? imageFile = await _pickImage(source);
    if (imageFile == null) return null;

    // Subir imagen
    return await uploadProfileImage(userId, imageFile);
  }
}