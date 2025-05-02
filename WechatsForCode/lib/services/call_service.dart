import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';

class CallService {
  static final CallService _instance = CallService._internal();
  factory CallService() => _instance;
  CallService._internal();

  static const String appId = 'a1cf0c0d00c244b99997769e9c730540';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  RtcEngine? _engine;
  
  RtcEngine? get engine => _engine;
  
  Future<void> muteLocalAudioStream(bool muted) async {
    await _engine?.muteLocalAudioStream(muted);
  }
  
  Future<void> setEnableSpeakerphone(bool enabled) async {
    await _engine?.setEnableSpeakerphone(enabled);
  }
  
  Future<void> enableLocalVideo(bool enabled) async {
    await _engine?.enableLocalVideo(enabled);
  }
  
  Future<void> switchCamera() async {
    await _engine?.switchCamera();
  }

  String? _currentCallId;
  int? _remoteUid;
  bool _localUserJoined = false;
  StreamSubscription? _callStatusSubscription;

  int? get remoteUid => _remoteUid;
  bool get localUserJoined => _localUserJoined;

  Future<void> initializeEngine() async {
    if (_engine != null) return;

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(const RtcEngineContext(
      appId: appId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));
  }

  void _setupEventHandlers({
    required Function(int uid) onUserJoined,
    required Function(int uid) onUserOffline,
    required Function() onJoinChannelSuccess,
  }) {
    _engine!.registerEventHandler(RtcEngineEventHandler(
      onUserJoined: (connection, uid, elapsed) {
        _remoteUid = uid;
        onUserJoined(uid);
      },
      onUserOffline: (connection, uid, reason) {
        _remoteUid = null;
        onUserOffline(uid);
      },
      onJoinChannelSuccess: (connection, elapsed) {
        _localUserJoined = true;
        onJoinChannelSuccess();
      },
    ));
  }

  Future<bool> startCall({
    required String callId,
    required String callerId,
    required String receiverId,
    required String callerName,
    required String callerPhoto,
    required bool isVideoCall,
    required Function(int uid) onUserJoined,
    required Function(int uid) onUserOffline,
    required Function() onJoinChannelSuccess,
  }) async {
    if (isVideoCall) {
      if (!await Permission.camera.request().isGranted) return false;
    }
    if (!await Permission.microphone.request().isGranted) return false;

    try {
      await initializeEngine();

      _setupEventHandlers(
        onUserJoined: onUserJoined,
        onUserOffline: onUserOffline,
        onJoinChannelSuccess: onJoinChannelSuccess,
      );

      await _engine!.enableAudio();
      if (isVideoCall) {
        await _engine!.enableVideo();
        await _engine!.setVideoEncoderConfiguration(
          VideoEncoderConfiguration(
            dimensions: const VideoDimensions(width: 640, height: 360),
            frameRate: 15, 
            bitrate: 800,
          ),
        );
      }

      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

      await _firestore.collection('calls').doc(callId).set({
        'callId': callId,
        'callerId': callerId,
        'receiverId': receiverId,
        'callerName': callerName,
        'callerPhoto': callerPhoto,
        'isVideoCall': isVideoCall,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      _currentCallId = callId;

      _listenForCallStatusChanges(callId, callerId);

      await _engine!.joinChannel(
        token: '007eJxTYNi2wOTAqdMaetu27tqw5K3KyeRwr4C1NyRj634FJ3yJlipRYEg0TE4zSDZIMTBINjIxSbIEAnNzM8tUy2RzYwNTEwO3j4IZDYGMDGv+JzMzMkAgiM/GUJ6anJ+SysAAAPorITw=',
        channelId: callId,
        uid: callerId.hashCode,
        options: const ChannelMediaOptions(),
      );

      return true;
    } catch (e) {
      print('Error starting call: $e');
      return false;
    }
  }

  Future<bool> acceptCall({
    required String callId,
    required String userId,
    required Function(int uid) onUserJoined,
    required Function(int uid) onUserOffline,
    required Function() onJoinChannelSuccess,
    required bool isVideoCall,
  }) async {
    try {
      if (isVideoCall) {
        if (!await Permission.camera.request().isGranted) return false;
      }
      if (!await Permission.microphone.request().isGranted) return false;

      await initializeEngine();

      _setupEventHandlers(
        onUserJoined: onUserJoined,
        onUserOffline: onUserOffline,
        onJoinChannelSuccess: onJoinChannelSuccess,
      );

      await _engine!.enableAudio();
      if (isVideoCall) {
        await _engine!.enableVideo();
      }

      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

      await _firestore.collection('calls').doc(callId).update({
        'status': 'accepted',
      });

      _currentCallId = callId;

      _listenForCallStatusChanges(callId, userId);

      await _engine!.joinChannel(
        token: '007eJxTYNi2wOTAqdMaetu27tqw5K3KyeRwr4C1NyRj634FJ3yJlipRYEg0TE4zSDZIMTBINjIxSbIEAnNzM8tUy2RzYwNTEwO3j4IZDYGMDGv+JzMzMkAgiM/GUJ6anJ+SysAAAPorITw=',
        channelId: callId,
        uid: userId.hashCode,
        options: const ChannelMediaOptions(),
      );

      return true;
    } catch (e) {
      print('Error accepting call: $e');
      return false;
    }
  }

  Future<void> declineCall(String callId) async {
    await _firestore.collection('calls').doc(callId).update({
      'status': 'declined',
    });
  }

  Future<void> endCall() async {
    if (_currentCallId != null) {
      try {
        await _firestore.collection('calls').doc(_currentCallId).update({
          'status': 'ended',
          'endTimestamp': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        print('Error updating call status: $e');
      }
    }

    _cleanupResources();
  }

  void _listenForCallStatusChanges(String callId, String currentUserId) {
    _callStatusSubscription = _firestore
        .collection('calls')
        .doc(callId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      final status = data['status'] as String;

      if ((status == 'declined' || status == 'ended') &&
          data['callerId'] != currentUserId) {
        _cleanupResources();
      }
    });
  }

  Future<void> _cleanupResources() async {
    _localUserJoined = false;
    _remoteUid = null;
    _currentCallId = null;

    _callStatusSubscription?.cancel();
    _callStatusSubscription = null;

    try {
      if (_engine != null) {
        await _engine!.leaveChannel();
      }
    } catch (e) {
      print('Error leaving channel: $e');
    }
  }

  Future<void> dispose() async {
    await _cleanupResources();
    if (_engine != null) {
      await _engine!.release();
      _engine = null;
    }
  }

  Stream<QuerySnapshot> getIncomingCallsStream(String userId) {
    return _firestore
        .collection('calls')
        .where('receiverId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }
}