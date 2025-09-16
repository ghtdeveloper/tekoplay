
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tekoplay/core/service/firestore_service.dart';
import '../../../core/service/profile_image_service.dart';


class ProfileImageEditor extends StatefulWidget {
  final String userId;
  final String? currentImageUrl;
  final bool isEmailLogin;
  final Function(String?) onImageUpdated;

  const ProfileImageEditor({
    super.key,
    required this.userId,
    this.currentImageUrl,
    required this.isEmailLogin,
    required this.onImageUpdated,
  });

  @override
  State<ProfileImageEditor> createState() => _ProfileImageEditorState();
}

class _ProfileImageEditorState extends State<ProfileImageEditor> {
  bool _isUploading = false;

  Future<void> _showImageSourceDialog() async {
    if (!widget.isEmailLogin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Solo disponible para cuentas con email'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Seleccionar imagen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.camera_alt, color: Color(0xFFEC7A34)),
                title: Text('Cámara'),
                onTap: () {
                  Navigator.of(context).pop();
                  _updateProfileImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library, color: Color(0xFFEC7A34)),
                title: Text('Galería'),
                onTap: () {
                  Navigator.of(context).pop();
                  _updateProfileImage(ImageSource.gallery);
                },
              ),
              if (widget.currentImageUrl != null && widget.currentImageUrl!.isNotEmpty)
                ListTile(
                  leading: Icon(Icons.delete, color: Colors.red),
                  title: Text('Eliminar foto'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _removeProfileImage();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _updateProfileImage(ImageSource source) async {
    setState(() {
      _isUploading = true;
    });

    try {
      final String? imageUrl = await ProfileImageService()
          .selectAndUploadImage(context, widget.userId, source);

      if (imageUrl != null) {
        final bool success = await FirestoreService()
            .updateUserProfilePhoto(widget.userId, imageUrl);

        if (success) {
          widget.onImageUpdated(imageUrl);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Foto de perfil actualizada'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          throw Exception('Error actualizando en base de datos');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _removeProfileImage() async {
    setState(() {
      _isUploading = true;
    });

    try {
      await ProfileImageService().deleteProfileImage(widget.userId);

      final bool success = await FirestoreService()
          .updateUserProfilePhoto(widget.userId, null);

      if (success) {
        widget.onImageUpdated(null);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Foto de perfil eliminada'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error eliminando foto: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.isEmailLogin ? _showImageSourceDialog : null,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: const Color(0xFFEC7A34),
            backgroundImage: widget.currentImageUrl != null &&
                widget.currentImageUrl!.isNotEmpty
                ? NetworkImage(widget.currentImageUrl!)
                : null,
            child: widget.currentImageUrl == null ||
                widget.currentImageUrl!.isEmpty
                ? const Icon(Icons.person, color: Colors.white, size: 30)
                : null,
          ),
          if (widget.isEmailLogin)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Color(0xFFEC7A34),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.camera_alt,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          if (_isUploading)
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}