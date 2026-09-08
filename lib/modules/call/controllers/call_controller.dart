import 'dart:async';
import 'dart:convert';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/snackbar_service.dart';
import '../../../core/services/websocket_service.dart';
import '../models/call_session_model.dart';
import '../views/call_view.dart';
import '../views/incoming_call_dialog.dart';

class CallController extends GetxController {
  final WebSocketService wsService;

  CallController({required this.wsService});

  final currentCall = Rxn<CallSessionModel>();
  final isMuted = false.obs;
  final isVideoEnabled = true.obs;
  final isSpeakerOn = false.obs;

  final localRenderer = RTCVideoRenderer();
  final remoteRenderer = RTCVideoRenderer();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  Timer? _durationTimer;
  StreamSubscription? _signalingSub;
  Map<String, dynamic>? _pendingOfferSDP;

  Map<String, dynamic> get _rtcConfig {
    final rawStunUrl = AppConstants.stunUrl;
    final rawTurnUrl = AppConstants.turnUrl;
    final turnUsername = AppConstants.turnUsername;
    final turnCredential = AppConstants.turnCredential;

    final stunUrl = rawStunUrl.isNotEmpty
        ? (rawStunUrl.startsWith('stun:') ? rawStunUrl : 'stun:$rawStunUrl')
        : 'stun:stun.l.google.com:19302';

    final iceServers = <Map<String, dynamic>>[
      {'urls': stunUrl},
      {'urls': 'stun:stun.l.google.com:19302'},
    ];

    if (rawTurnUrl.isNotEmpty && turnUsername.isNotEmpty && turnCredential.isNotEmpty) {
      final cleanTurn = rawTurnUrl.replaceFirst('turn:', '').replaceFirst('turns:', '');
      iceServers.add({
        'urls': [
          'turn:$cleanTurn?transport=udp',
          'turn:$cleanTurn?transport=tcp',
          'turn:$cleanTurn',
        ],
        'username': turnUsername,
        'credential': turnCredential,
      });
    }

    return {
      'iceServers': iceServers,
      'sdpSemantics': 'unified-plan',
    };
  }

  @override
  void onInit() {
    super.onInit();
    _initRenderers();
    _listenSignaling();
  }

  Future<void> _initRenderers() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  void _listenSignaling() {
    _signalingSub = wsService.onCallSignaling.listen(_handleSignalingEvent);
  }

  Future<void> _handleSignalingEvent(Map<String, dynamic> message) async {
    final type = message['type'] as String? ?? '';
    final data = message['data'] as Map<String, dynamic>? ?? {};
    final senderId = data['sender_id'] as int? ?? 0;
    final senderName = data['sender_name'] as String? ?? 'Pengguna';
    final callId = data['call_id'] as String? ?? '';

    LoggerService.i(
      'Received Call Signaling: $type from $senderName',
      tag: 'CallController',
    );

    switch (type) {
      case 'call:offer':
        if (currentCall.value != null &&
            currentCall.value!.state != CallState.idle) {
          // User is busy on another call
          wsService.sendCallSignaling(
            type: 'call:reject',
            targetUserId: senderId,
            data: {'call_id': callId, 'reason': 'busy'},
          );
          return;
        }

        final mediaTypeStr = data['media_type'] as String? ?? 'audio';
        final callType = mediaTypeStr == 'video'
            ? CallType.video
            : CallType.audio;

        _pendingOfferSDP = data['sdp'] as Map<String, dynamic>?;

        currentCall.value = CallSessionModel(
          callId: callId,
          targetUserId: senderId,
          targetUserName: senderName,
          callType: callType,
          isCaller: false,
          state: CallState.incoming,
        );

        // Show Incoming Call Dialog
        Get.dialog(const IncomingCallDialog(), barrierDismissible: false);
        break;

      case 'call:answer':
        if (currentCall.value != null && currentCall.value!.isCaller) {
          final sdpData = data['sdp'] as Map<String, dynamic>?;
          if (sdpData != null && _peerConnection != null) {
            final desc = RTCSessionDescription(sdpData['sdp'], sdpData['type']);
            await _peerConnection!.setRemoteDescription(desc);
            currentCall.value!.state = CallState.connected;
            currentCall.refresh();
            _startDurationTimer();
            LoggerService.i(
              'Call connected with remote peer',
              tag: 'CallController',
            );
          }
        }
        break;

      case 'call:ice_candidate':
        final candData = data['candidate'] as Map<String, dynamic>?;
        if (candData != null && _peerConnection != null) {
          final candidate = RTCIceCandidate(
            candData['candidate'],
            candData['sdpMid'],
            candData['sdpMLineIndex'],
          );
          await _peerConnection!.addCandidate(candidate);
        }
        break;

      case 'call:reject':
        SnackbarService.info(
          '${currentCall.value?.targetUserName ?? "Pengguna"} menolak panggilan.',
        );
        _endCallCleanup();
        break;

      case 'call:hangup':
        SnackbarService.info('Panggilan telah berakhir.');
        _endCallCleanup();
        break;

      case 'call:unavailable':
        SnackbarService.warning(
          'Pengguna sedang tidak aktif atau tidak dapat dihubungi.',
        );
        _endCallCleanup();
        break;

      case 'call:already_answered':
      case 'call:answered_elsewhere':
        // Silently close incoming dialog
        _endCallCleanup(notifyRemote: false);
        break;
    }
  }

  void handleIncomingCallFromFCM({
    required String callId,
    required int callerId,
    required String callerName,
    required String mediaType,
    String? sdpOffer,
  }) {
    if (currentCall.value != null &&
        currentCall.value!.state != CallState.idle) {
      return;
    }

    final callType = mediaType == 'video' ? CallType.video : CallType.audio;
    if (sdpOffer != null) {
      try {
        final decoded = jsonDecode(sdpOffer);
        if (decoded is Map<String, dynamic>) {
          _pendingOfferSDP = decoded;
        }
      } catch (_) {}
    }

    currentCall.value = CallSessionModel(
      callId: callId,
      targetUserId: callerId,
      targetUserName: callerName,
      callType: callType,
      isCaller: false,
      state: CallState.incoming,
    );

    if (!(Get.isDialogOpen ?? false)) {
      Get.dialog(const IncomingCallDialog(), barrierDismissible: false);
    }
  }

  void handleCallDismissFromFCM(String callId) {
    if (currentCall.value?.callId == callId) {
      _endCallCleanup(notifyRemote: false);
    }
  }

  Future<void> startCall({
    required int targetUserId,
    required String targetUserName,
    required CallType callType,
  }) async {
    final callId = const Uuid().v4();

    currentCall.value = CallSessionModel(
      callId: callId,
      targetUserId: targetUserId,
      targetUserName: targetUserName,
      callType: callType,
      isCaller: true,
      state: CallState.calling,
    );

    await _initLocalMedia(callType);
    await _createPeerConnection(targetUserId, callId);

    // Create SDP Offer
    final offer = await _peerConnection!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': callType == CallType.video,
    });
    await _peerConnection!.setLocalDescription(offer);

    // Send offer to remote user via WebSocket
    wsService.sendCallSignaling(
      type: 'call:offer',
      targetUserId: targetUserId,
      data: {
        'call_id': callId,
        'media_type': callType == CallType.video ? 'video' : 'audio',
        'sdp': {'sdp': offer.sdp, 'type': offer.type},
      },
    );

    Get.to(() => const CallView());
  }

  Future<void> acceptCall() async {
    final call = currentCall.value;
    if (call == null || _pendingOfferSDP == null) return;

    Get.back(); // Dismiss dialog
    call.state = CallState.connected;
    currentCall.refresh();

    await _initLocalMedia(call.callType);
    await _createPeerConnection(call.targetUserId, call.callId);

    // Set remote offer SDP
    final remoteDesc = RTCSessionDescription(
      _pendingOfferSDP!['sdp'],
      _pendingOfferSDP!['type'],
    );
    await _peerConnection!.setRemoteDescription(remoteDesc);

    // Create SDP Answer
    final answer = await _peerConnection!.createAnswer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': call.callType == CallType.video,
    });
    await _peerConnection!.setLocalDescription(answer);

    // Send answer via WebSocket
    wsService.sendCallSignaling(
      type: 'call:answer',
      targetUserId: call.targetUserId,
      data: {
        'call_id': call.callId,
        'sdp': {'sdp': answer.sdp, 'type': answer.type},
      },
    );

    _startDurationTimer();
    Get.to(() => const CallView());
  }

  void rejectCall() {
    final call = currentCall.value;
    if (call != null) {
      wsService.sendCallSignaling(
        type: 'call:reject',
        targetUserId: call.targetUserId,
        data: {'call_id': call.callId},
      );
    }
    Get.back(); // Dismiss dialog
    _endCallCleanup(notifyRemote: false);
  }

  void hangup() {
    final call = currentCall.value;
    if (call != null) {
      wsService.sendCallSignaling(
        type: 'call:hangup',
        targetUserId: call.targetUserId,
        data: {'call_id': call.callId},
      );
    }
    _endCallCleanup(notifyRemote: false);
  }

  Future<void> _initLocalMedia(CallType callType) async {
    final mediaConstraints = {
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': callType == CallType.video
          ? {
              'facingMode': 'user',
              'width': {'ideal': 640},
              'height': {'ideal': 480},
            }
          : false,
    };

    _localStream = await rtc.navigator.mediaDevices.getUserMedia(
      mediaConstraints,
    );
    localRenderer.srcObject = _localStream;
  }

  Future<void> _createPeerConnection(int targetUserId, String callId) async {
    _peerConnection = await createPeerConnection(_rtcConfig);

    // Default to loudspeaker so caller and receiver hear voice clearly
    Helper.setSpeakerphoneOn(true);
    isSpeakerOn.value = true;

    // Add local tracks
    _localStream?.getTracks().forEach((track) {
      _peerConnection?.addTrack(track, _localStream!);
    });

    // Handle ICE Candidates
    _peerConnection?.onIceCandidate = (candidate) {
      if (candidate.candidate != null) {
        wsService.sendCallSignaling(
          type: 'call:ice_candidate',
          targetUserId: targetUserId,
          data: {
            'call_id': callId,
            'candidate': {
              'candidate': candidate.candidate,
              'sdpMid': candidate.sdpMid,
              'sdpMLineIndex': candidate.sdpMLineIndex,
            },
          },
        );
      }
    };

    // Handle Remote Track
    _peerConnection?.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        remoteRenderer.srcObject = event.streams[0];
      }
    };

    // Handle connection state
    _peerConnection?.onConnectionState = (state) {
      LoggerService.d('RTCPeerConnection state: $state', tag: 'CallController');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        hangup();
      }
    };
  }

  void toggleMute() {
    if (_localStream != null) {
      final audioTracks = _localStream!.getAudioTracks();
      if (audioTracks.isNotEmpty) {
        final enabled = audioTracks[0].enabled;
        audioTracks[0].enabled = !enabled;
        isMuted.value = enabled; // if was enabled, now muted
      }
    }
  }

  void toggleVideo() {
    if (_localStream != null) {
      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        final enabled = videoTracks[0].enabled;
        videoTracks[0].enabled = !enabled;
        isVideoEnabled.value = !enabled;
      }
    }
  }

  Future<void> switchCamera() async {
    if (_localStream != null) {
      final videoTrack = _localStream!.getVideoTracks().firstOrNull;
      if (videoTrack != null) {
        await Helper.switchCamera(videoTrack);
      }
    }
  }

  void toggleSpeaker() {
    isSpeakerOn.toggle();
    Helper.setSpeakerphoneOn(isSpeakerOn.value);
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (currentCall.value != null) {
        currentCall.value!.duration++;
        currentCall.refresh();
      }
    });
  }

  void _endCallCleanup({bool notifyRemote = true}) {
    _durationTimer?.cancel();
    _durationTimer = null;

    try {
      _localStream?.getTracks().forEach((t) => t.stop());
      _localStream?.dispose();
    } catch (_) {}
    _localStream = null;

    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;

    try {
      _peerConnection?.close();
    } catch (_) {}
    _peerConnection = null;

    _pendingOfferSDP = null;
    currentCall.value = null;

    // Navigate back to chat if CallView is open
    if (Get.isDialogOpen ?? false) {
      Get.back();
    }
    if (Get.currentRoute.contains('CallView') ||
        (Get.key.currentState?.canPop() ?? false)) {
      try {
        Get.back();
      } catch (_) {}
    }
  }

  @override
  void onClose() {
    _signalingSub?.cancel();
    _endCallCleanup(notifyRemote: false);
    localRenderer.dispose();
    remoteRenderer.dispose();
    super.onClose();
  }
}
