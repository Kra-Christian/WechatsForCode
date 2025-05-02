import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:provider/provider.dart';
import '../../services/call_service.dart';
import '../../services/auth_service.dart';

class VideoCallScreen extends StatefulWidget {
  final String callId;
  final String userId;
  final String otherUserId;
  final String otherUserName;
  final String otherUserPhoto;
  final bool isIncoming;
  final bool isVideoCall;

  const VideoCallScreen({
    Key? key,
    required this.callId,
    required this.userId,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserPhoto,
    required this.isIncoming,
    required this.isVideoCall,
  }) : super(key: key);

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final CallService _callService = CallService();
  bool _joined = false;
  bool _otherUserJoined = false;
  int? _remoteUid;
  bool _muted = false;
  bool _speakerOn = true;
  bool _cameraOff = false;
  bool _showControls = true;
  DateTime? _callStartTime;

  @override
  void initState() {
    super.initState();

    if (widget.isIncoming) {
      _acceptCall();
    } else {
      _startCall();
    }

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _showControls = false);
      }
    });
  }

  @override
  void dispose() {
    _callService.endCall();
    super.dispose();
  }

  Future<void> _startCall() async {
    final success = await _callService.startCall(
      callId: widget.callId,
      callerId: widget.userId,
      receiverId: widget.otherUserId,
      callerName: Provider.of<AuthService>(context, listen: false).currentUser!.displayName ?? '',
      callerPhoto: Provider.of<AuthService>(context, listen: false).currentUser!.photoURL ?? '',
      isVideoCall: widget.isVideoCall,
      onUserJoined: (uid) {
          print("Utilisateur distant rejoint: $uid");
          setState(() {
            _remoteUid = uid;
            _otherUserJoined = true;
            if (_callStartTime == null) {
              _callStartTime = DateTime.now();
            }
          });
        },
      onUserOffline: (uid) {
        setState(() {
          _remoteUid = null;
          _otherUserJoined = false;
        });
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted && !_otherUserJoined) {
            Navigator.pop(context);
          }
        });
      },
      onJoinChannelSuccess: () {
        setState(() => _joined = true);
      },
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Échec de l\'appel. Veuillez réessayer.')),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _acceptCall() async {
    final success = await _callService.acceptCall(
      callId: widget.callId,
      userId: widget.userId,
      isVideoCall: widget.isVideoCall,
      onUserJoined: (uid) {
          print("Utilisateur distant rejoint: $uid");
          setState(() {
            _remoteUid = uid;
            _otherUserJoined = true;
            if (_callStartTime == null) {
              _callStartTime = DateTime.now();
            }
          });
        },
      onUserOffline: (uid) {
        setState(() {
          _remoteUid = null;
          _otherUserJoined = false;
        });
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted && !_otherUserJoined) {
            Navigator.pop(context);
          }
        });
      },
      onJoinChannelSuccess: () {
        setState(() => _joined = true);
      },
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Échec de l\'appel. Veuillez réessayer.')),
      );
      Navigator.pop(context);
    }
  }

  void _endCall() {
    _callService.endCall();
    Navigator.pop(context);
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _callService.muteLocalAudioStream(_muted);
  }

  void _toggleSpeaker() {
    setState(() => _speakerOn = !_speakerOn);
    _callService.setEnableSpeakerphone(_speakerOn);
  }

  void _toggleCamera() {
    if (widget.isVideoCall) {
      setState(() => _cameraOff = !_cameraOff);
      _callService.enableLocalVideo(!_cameraOff);
    }
  }

  void _switchCamera() {
    if (widget.isVideoCall) {
      _callService.switchCamera();
    }
  }

  String _formatDuration() {
    if (_callStartTime == null) return '00:00';

    final duration = DateTime.now().difference(_callStartTime!);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    if (duration.inHours > 0) {
      final hours = duration.inHours.toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds';
    }

    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          children: [
            if (!widget.isVideoCall || _cameraOff)
              Container(color: Colors.black),

            if (widget.isVideoCall && _otherUserJoined && _remoteUid != null)
              Center(
                child: _remoteView(),
              ),

            if (widget.isVideoCall && !_cameraOff && _joined)
              Positioned(
                right: 20,
                top: 50,
                width: 120,
                height: 180,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _localView(),
                  ),
                ),
              ),

            if (!_otherUserJoined || !widget.isVideoCall || _cameraOff)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: widget.otherUserPhoto.isNotEmpty
                          ? NetworkImage(widget.otherUserPhoto)
                          : const AssetImage('assets/images/default_avatar.png') as ImageProvider,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      widget.otherUserName,
                      style: const TextStyle(color: Colors.white, fontSize: 24),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _otherUserJoined
                          ? _formatDuration()
                          : 'En attente...',
                      style: TextStyle(color: Colors.grey[300], fontSize: 16),
                    ),
                  ],
                ),
              ),

            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                color: Colors.black54,
                child: SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: _endCall,
                            ),
                            if (_otherUserJoined)
                              Text(
                                _formatDuration(),
                                style: const TextStyle(color: Colors.white),
                              ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 50),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildControlButton(
                              icon: _muted ? Icons.mic_off : Icons.mic,
                              label: _muted ? 'Unmute' : 'Mute',
                              onPressed: _toggleMute,
                            ),
                            _buildControlButton(
                              icon: Icons.call_end,
                              label: 'End',
                              color: Colors.red,
                              onPressed: _endCall,
                            ),
                            _buildControlButton(
                              icon: _speakerOn ? Icons.volume_up : Icons.volume_off,
                              label: _speakerOn ? 'Speaker' : 'Earpiece',
                              onPressed: _toggleSpeaker,
                            ),
                            if (widget.isVideoCall)
                              _buildControlButton(
                                icon: _cameraOff ? Icons.videocam_off : Icons.videocam,
                                label: _cameraOff ? 'Camera On' : 'Camera Off',
                                onPressed: _toggleCamera,
                              ),
                            if (widget.isVideoCall && !_cameraOff)
                              _buildControlButton(
                                icon: Icons.flip_camera_ios,
                                label: 'Switch',
                                onPressed: _switchCamera,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    Color color = Colors.white,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 25,
          backgroundColor: color == Colors.red ? color : Colors.black45,
          child: IconButton(
            icon: Icon(icon, color: Colors.white),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ],
    );
  }

  Widget _localView() {
  if (_callService.engine == null) {
    return const Center(child: CircularProgressIndicator());
  }
  
  return AgoraVideoView(
    controller: VideoViewController(
      rtcEngine: _callService.engine!,
      canvas: const VideoCanvas(uid: 0),
      useFlutterTexture: true,
    ),
  );
}

Widget _remoteView() {
  if (_remoteUid == null || _callService.engine == null) {
    return const Center(
      child: Text(
        "En attente de l'interlocuteur...",
        style: TextStyle(color: Colors.white, fontSize: 16),
      ),
    );
  }

  return AgoraVideoView(
    controller: VideoViewController.remote(
      rtcEngine: _callService.engine!,
      canvas: VideoCanvas(uid: _remoteUid),
      connection: RtcConnection(channelId: widget.callId),
      useFlutterTexture: true,
    ),
  );
}

}