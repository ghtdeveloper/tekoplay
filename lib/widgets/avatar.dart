import 'package:flutter/material.dart';

class UserAvatarWidget extends StatelessWidget {
  final String userName;
  final String? avatarUrl;

  const UserAvatarWidget({
    super.key,
    required this.userName,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundImage: avatarUrl != null
              ? NetworkImage(avatarUrl!)
              : AssetImage('assets/images/default_avatar.png') as ImageProvider,
          backgroundColor: Colors.grey.shade200,
        ),
        const SizedBox(height: 8),
        Text(
          userName,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
