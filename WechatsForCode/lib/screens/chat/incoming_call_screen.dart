import 'package:flutter/material.dart';
import '../../services/call_service.dart';
import 'video_call_screen.dart';

class IncomingCallScreen extends StatelessWidget {
  final String callId;
  final String callerId;
  final String callerName;
  final String callerPhoto;
  final String currentUserId;
  final bool isVideoCall;

  const IncomingCallScreen({
    Key? key,
    required this.callId,
    required this.callerId,
    required this.callerName,
    required this.callerPhoto,
    required this.currentUserId,
    required this.isVideoCall,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 50),
            Text(
              isVideoCall ? 'Appel vidéo entrant' : 'Appel entrant',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 50),
            CircleAvatar(
              radius: 70,
              backgroundImage: callerPhoto.isNotEmpty
                  ? NetworkImage(callerPhoto)
                  : const AssetImage('assets/images/default_avatar.png') as ImageProvider,
            ),
            const SizedBox(height: 20),
            Text(
              callerName,
              style: const TextStyle(color: Colors.white, fontSize: 26),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 50),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  buildCallButton(
                    icon: Icons.call_end,
                    color: Colors.red,
                    label: 'Refuser',
                    onPressed: () {
                      CallService().declineCall(callId);
                      Navigator.pop(context);
                    },
                  ),
                  buildCallButton(
                    icon: isVideoCall ? Icons.videocam : Icons.call,
                    color: Colors.green,
                    label: 'Accepter',
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VideoCallScreen(
                            callId: callId,
                            userId: currentUserId,
                            otherUserId: callerId,
                            otherUserName: callerName,
                            otherUserPhoto: callerPhoto,
                            isIncoming: true,
                            isVideoCall: isVideoCall,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildCallButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        FloatingActionButton(
          onPressed: onPressed,
          backgroundColor: color,
          child: Icon(icon, color: Colors.white, size: 30),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ],
    );
  }
}