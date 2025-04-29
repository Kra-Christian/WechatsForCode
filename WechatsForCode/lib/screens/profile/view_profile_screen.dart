import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/user_model.dart';

class ViewProfileScreen extends StatelessWidget {
  final UserModel user;
  const ViewProfileScreen({ Key? key, required this.user }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(user.displayName),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 24.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 60,
              backgroundImage: user.photoUrl.isNotEmpty
                  ? NetworkImage(user.photoUrl)
                  : const AssetImage('assets/images/default_avatar.png')
                      as ImageProvider,
            ),
            const SizedBox(height: 24),
            Text(
              user.displayName,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              user.status,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  user.isOnline ? Icons.circle : Icons.circle_outlined,
                  color: user.isOnline ? Colors.green : Colors.grey,
                  size: 12,
                ),
                const SizedBox(width: 6),
                Text(
                  user.isOnline
                    ? 'En ligne'
                    : 'Vu ${timeago.format(user.lastSeen, locale: 'fr')}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
