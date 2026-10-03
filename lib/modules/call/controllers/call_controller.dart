import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/services/snackbar_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/websocket_service.dart';
import '../../../routes/app_routes.dart';
import '../models/call_log_model.dart';
import '../models/call_session_model.dart';
import '../views/incoming_call_dialog.dart';

class CallController extends GetxController {
  final WebSocketService wsService;

  CallController({required this.wsService});

  final currentCall = Rxn<CallSessionModel>();
  final isMuted = false.obs;
  final isVideoEnabled = true.obs;
  final isSpeakerOn = false.obs;
  final isScreenSharing = false.obs;

  final localRenderer = RTCVideoRenderer();
  final remoteRenderer = RTCVideoRenderer();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _screenStream;
  Timer? _durationTimer;
  StreamSubscription? _signalingSub;
  RTCSessionDescription? _pendingOfferSDP;
  final _pendingCandidates = <RTCIceCandidate>[];
  final _recordedCallIds = <String>{};
  bool _isCleaningUp = false;

  RTCSessionDescription? _parseSessionDescription(dynamic raw) {
    if (raw == null) return null;
    if (raw is RTCSessionDescription) return raw;
    if (raw is Map) {
      final inner = raw['sdp'];
      if (inner is Map) {
        return RTCSessionDescription(
          inner['sdp']?.toString() ?? '',
          inner['type']?.toString() ?? 'answer',
        );
      }
      final sdpStr = raw['sdp']?.toString() ?? raw['description']?.toString() ?? '';
      final typeStr = raw['type']?.toString() ?? 'answer';
      return RTCSessionDescription(sdpStr, typeStr);
    }
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        return _parseSessionDescription(decoded);
      } catch (_) {
        return RTCSessionDescription(raw, 'answer');
      }
    }
    return null;
  }

  String _preferCodec(String sdp, String codecName) {
    final delimiter = sdp.contains('\r\n') ? '\r\n' : '\n';
    final lines = sdp.split(delimiter);
    final mVideoIndex = lines.indexWhere((l) => l.startsWith('m=video '));
    if (mVideoIndex == -1) return sdp;

    // Find all payload types for the requested codec (e.g. VP8)
    final codecPayloads = <String>[];
    final rtpmapRegex = RegExp(
      r'^a=rtpmap:(\d+)\s+' + RegExp.escape(codecName) + r'/90000',
      caseSensitive: false,
    );
    for (final line in lines) {
      final match = rtpmapRegex.firstMatch(line);
      if (match != null) {
        codecPayloads.add(match.group(1)!);
      }
    }

    if (codecPayloads.isEmpty) return sdp;

    // m=video <port> <proto> <payloadType1> <payloadType2> ...
    final mLineTokens = lines[mVideoIndex].split(' ');
    if (mLineTokens.length < 4) return sdp;

    final header = mLineTokens.sublist(0, 3);
    final originalPayloads = mLineTokens.sublist(3);

    final otherPayloads = originalPayloads.where((pt) => !codecPayloads.contains(pt)).toList();
    final newPayloads = [...codecPayloads, ...otherPayloads];

    lines[mVideoIndex] = '${header.join(' ')} ${newPayloads.join(' ')}';
    return lines.join(delimiter);
  }

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

        _pendingOfferSDP = _parseSessionDescription(data['sdp']);

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
          final desc = _parseSessionDescription(data['sdp']);
          if (desc != null && _peerConnection != null) {
            await _peerConnection!.setRemoteDescription(desc);

            // Flush pending ICE candidates
            for (final candidate in _pendingCandidates) {
              await _peerConnection!.addCandidate(candidate);
            }
            _pendingCandidates.clear();

            // Ensure all local tracks are unmuted and active
            if (_localStream != null) {
              for (final track in _localStream!.getTracks()) {
                track.enabled = true;
              }
            }

            currentCall.value!.state = CallState.connected;
            currentCall.refresh();
            _startDurationTimer();
            LoggerService.i(
              'Call connected with remote peer',
              tag: 'CallController',
            );
          } else {
            LoggerService.w('Unable to process call:answer, invalid SDP: ${data['sdp']}', tag: 'CallController');
          }
        }
        break;

      case 'call:ice_candidate':
        final rawCand = data['candidate'];
        if (rawCand is Map) {
          final candidateStr = rawCand['candidate']?.toString();
          final sdpMid = rawCand['sdpMid']?.toString();
          final sdpMLineIndexRaw = rawCand['sdpMLineIndex'];
          final sdpMLineIndex = sdpMLineIndexRaw is int
              ? sdpMLineIndexRaw
              : int.tryParse('$sdpMLineIndexRaw');

          if (candidateStr != null && candidateStr.isNotEmpty) {
            final candidate = RTCIceCandidate(candidateStr, sdpMid, sdpMLineIndex);
            if (_peerConnection != null) {
              final remoteDesc = await _peerConnection!.getRemoteDescription();
              if (remoteDesc != null && remoteDesc.sdp != null) {
                await _peerConnection!.addCandidate(candidate);
              } else {
                _pendingCandidates.add(candidate);
              }
            } else {
              _pendingCandidates.add(candidate);
            }
          }
        }
        break;

      case 'call:reject':
        SnackbarService.info(
          '${currentCall.value?.targetUserName ?? "Pengguna"} menolak panggilan.',
        );
        _endCallCleanup(status: 'declined');
        break;

      case 'call:hangup':
        SnackbarService.info('Panggilan telah berakhir.');
        _endCallCleanup(status: 'completed');
        break;

      case 'call:unavailable':
        SnackbarService.warning(
          'Pengguna sedang tidak aktif atau tidak dapat dihubungi.',
        );
        _endCallCleanup(status: 'missed');
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
      _pendingOfferSDP = _parseSessionDescription(sdpOffer);
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

  Future<bool> _checkAndRequestPermissions(CallType callType) async {
    return await PermissionService.requestCallPermissions(
      isVideo: callType == CallType.video,
    );
  }

  Future<void> startCall({
    required int targetUserId,
    required String targetUserName,
    required CallType callType,
    int? chatId,
  }) async {
    final hasPermission = await _checkAndRequestPermissions(callType);
    if (!hasPermission) return;

    final callId = const Uuid().v4();

    currentCall.value = CallSessionModel(
      callId: callId,
      targetUserId: targetUserId,
      targetUserName: targetUserName,
      callType: callType,
      isCaller: true,
      chatId: chatId,
      state: CallState.calling,
    );

    try {
      await _initLocalMedia(callType);
      await _createPeerConnection(targetUserId, callId);

      // Create SDP Offer
      var offer = await _peerConnection!.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': callType == CallType.video,
      });

      if (callType == CallType.video && offer.sdp != null) {
        final mungedSdp = _preferCodec(offer.sdp!, 'VP8');
        offer = RTCSessionDescription(mungedSdp, offer.type);
      }

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

      Get.toNamed(Routes.call);
    } catch (e) {
      LoggerService.e('Failed to start call: $e', tag: 'CallController');
      SnackbarService.error('Gagal memulai panggilan: $e');
      _endCallCleanup(notifyRemote: false, status: 'failed');
    }
  }

  Future<void> acceptCall() async {
    final call = currentCall.value;
    if (call == null || _pendingOfferSDP == null) return;

    final hasPermission = await _checkAndRequestPermissions(call.callType);
    if (!hasPermission) {
      rejectCall();
      return;
    }

    Get.back(); // Dismiss dialog
    call.state = CallState.connected;
    currentCall.refresh();

    try {
      await _initLocalMedia(call.callType);
      await _createPeerConnection(call.targetUserId, call.callId);

      // Set remote offer SDP
      final remoteDesc = _parseSessionDescription(_pendingOfferSDP);
      if (remoteDesc == null) {
        throw Exception('Invalid offer SDP');
      }
      await _peerConnection!.setRemoteDescription(remoteDesc);

      // Flush queued candidates that arrived before setRemoteDescription
      for (final candidate in _pendingCandidates) {
        await _peerConnection!.addCandidate(candidate);
      }
      _pendingCandidates.clear();

      // Ensure transceivers are configured to SendRecv for active call media
      try {
        final transceivers = await _peerConnection!.getTransceivers();
        for (final transceiver in transceivers) {
          final kind = transceiver.sender.track?.kind ?? transceiver.receiver.track?.kind;
          if (kind == 'video' && call.callType == CallType.video) {
            await transceiver.setDirection(TransceiverDirection.SendRecv);
          } else if (kind == 'audio') {
            await transceiver.setDirection(TransceiverDirection.SendRecv);
          }
        }
      } catch (e) {
        LoggerService.w('Transceiver direction update warning: $e', tag: 'CallController');
      }

      // Create SDP Answer
      var answer = await _peerConnection!.createAnswer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': call.callType == CallType.video,
      });

      if (call.callType == CallType.video && answer.sdp != null) {
        final mungedSdp = _preferCodec(answer.sdp!, 'VP8');
        answer = RTCSessionDescription(mungedSdp, answer.type);
      }

      await _peerConnection!.setLocalDescription(answer);

      // Ensure local tracks are active and unmuted
      if (_localStream != null) {
        for (final track in _localStream!.getTracks()) {
          track.enabled = true;
        }
      }

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
      Get.toNamed(Routes.call);
    } catch (e) {
      LoggerService.e('Failed to accept call: $e', tag: 'CallController');
      SnackbarService.error('Gagal menerima panggilan: $e');
      _endCallCleanup(notifyRemote: true, status: 'failed');
    }
  }

  void rejectCall() {
    if (_isCleaningUp) return;
    final call = currentCall.value;
    if (call != null && call.state != CallState.ended) {
      wsService.sendCallSignaling(
        type: 'call:reject',
        targetUserId: call.targetUserId,
        data: {'call_id': call.callId},
      );
    }
    if (Get.isDialogOpen ?? false) {
      Get.back(); // Dismiss dialog
    }
    _endCallCleanup(notifyRemote: false, status: 'declined');
  }

  void hangup() {
    if (_isCleaningUp) return;
    final call = currentCall.value;
    if (call != null && call.state != CallState.ended) {
      wsService.sendCallSignaling(
        type: 'call:hangup',
        targetUserId: call.targetUserId,
        data: {'call_id': call.callId},
      );
    }
    final status = (currentCall.value?.duration ?? 0) > 0
        ? 'completed'
        : (currentCall.value?.isCaller ?? false ? 'canceled' : 'declined');
    _endCallCleanup(notifyRemote: false, status: status);
  }

  Future<void> _initLocalMedia(CallType callType) async {
    // Ensure native video renderers are fully initialized before assigning stream
    if (localRenderer.textureId == null) {
      await localRenderer.initialize();
    }
    if (remoteRenderer.textureId == null) {
      await remoteRenderer.initialize();
    }

    final mediaConstraints = <String, dynamic>{
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': callType == CallType.video
          ? {
              'mandatory': {
                'minWidth': '640',
                'minHeight': '480',
                'minFrameRate': '15',
                'maxFrameRate': '30',
              },
              'facingMode': 'user',
              'optional': [],
            }
          : false,
    };

    try {
      _localStream = await rtc.navigator.mediaDevices.getUserMedia(
        mediaConstraints,
      );
      // Ensure all tracks in the acquired local stream are enabled
      for (final track in _localStream!.getTracks()) {
        track.enabled = true;
      }
      localRenderer.srcObject = _localStream;
      isVideoEnabled.value = callType == CallType.video;
      isMuted.value = false;
      LoggerService.i(
        'getUserMedia success: ${_localStream?.getAudioTracks().length} audio, ${_localStream?.getVideoTracks().length} video',
        tag: 'CallController',
      );
    } catch (e) {
      LoggerService.e('getUserMedia failed: $e', tag: 'CallController');
      rethrow;
    }
  }

  Future<void> _createPeerConnection(int targetUserId, String callId) async {
    _peerConnection = await createPeerConnection(_rtcConfig);

    // Default to loudspeaker so caller and receiver hear voice clearly
    Helper.setSpeakerphoneOn(true);
    isSpeakerOn.value = true;

    // Add local tracks and await each addition so they are registered before SDP generation
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        track.enabled = true;
        await _peerConnection!.addTrack(track, _localStream!);
        LoggerService.i(
          'Added local ${track.kind} track to peerConnection: trackId=${track.id}',
          tag: 'CallController',
        );
      }
    }

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
    _peerConnection?.onTrack = (RTCTrackEvent event) async {
      LoggerService.i(
        'onTrack: kind=${event.track.kind}, id=${event.track.id}, streams=${event.streams.length}',
        tag: 'CallController',
      );
      event.track.enabled = true;

      if (event.track.kind == 'video') {
        if (event.streams.isNotEmpty) {
          remoteRenderer.srcObject = event.streams[0];
        } else {
          try {
            final stream = await createLocalMediaStream('remote_stream_video');
            await stream.addTrack(event.track);
            remoteRenderer.srcObject = stream;
          } catch (e) {
            LoggerService.e('Failed to create fallback remote video stream: $e', tag: 'CallController');
          }
        }
        currentCall.refresh();
      }
    };

    // Handle connection state
    _peerConnection?.onConnectionState = (state) {
      LoggerService.d('RTCPeerConnection state: $state', tag: 'CallController');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        if (currentCall.value != null && currentCall.value!.state != CallState.connected) {
          currentCall.value!.state = CallState.connected;
          currentCall.refresh();
          _startDurationTimer();
        }
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        if (!_isCleaningUp && currentCall.value != null && currentCall.value!.state != CallState.ended) {
          hangup();
        }
      }
    };

    // Handle ICE connection state
    _peerConnection?.onIceConnectionState = (state) {
      LoggerService.d('RTCIceConnectionState: $state', tag: 'CallController');
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        if (currentCall.value != null && currentCall.value!.state != CallState.connected) {
          currentCall.value!.state = CallState.connected;
          currentCall.refresh();
          _startDurationTimer();
        }
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

  Future<void> toggleScreenShare() async {
    if (isScreenSharing.value) {
      await stopScreenShare();
    } else {
      await startScreenShare();
    }
  }

  Future<void> startScreenShare() async {
    try {
      final screenStream = await rtc.navigator.mediaDevices.getDisplayMedia(<String, dynamic>{
        'video': true,
        'audio': false,
      });

      _screenStream = screenStream;
      final screenTrack = screenStream.getVideoTracks().firstOrNull;
      if (screenTrack != null) {
        screenTrack.onEnded = () {
          stopScreenShare();
        };

        if (_peerConnection != null) {
          final senders = await _peerConnection!.getSenders();
          for (final sender in senders) {
            if (sender.track?.kind == 'video') {
              await sender.replaceTrack(screenTrack);
            }
          }
        }

        localRenderer.srcObject = screenStream;
        isScreenSharing.value = true;
        LoggerService.i('Screen sharing started', tag: 'CallController');
      }
    } catch (e) {
      LoggerService.e('Failed to start screen share: $e', tag: 'CallController');
      SnackbarService.error('Gagal memulai bagikan layar: $e');
    }
  }

  Future<void> stopScreenShare() async {
    try {
      _screenStream?.getTracks().forEach((t) => t.stop());
      await _screenStream?.dispose();
      _screenStream = null;

      if (_localStream != null) {
        final localVideoTrack = _localStream!.getVideoTracks().firstOrNull;
        if (_peerConnection != null && localVideoTrack != null) {
          final senders = await _peerConnection!.getSenders();
          for (final sender in senders) {
            if (sender.track?.kind == 'video') {
              await sender.replaceTrack(localVideoTrack);
            }
          }
        }
        localRenderer.srcObject = _localStream;
      }
      isScreenSharing.value = false;
      LoggerService.i('Screen sharing stopped', tag: 'CallController');
    } catch (e) {
      LoggerService.e('Failed to stop screen share: $e', tag: 'CallController');
    }
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

  Future<void> _endCallCleanup({bool notifyRemote = true, String status = 'completed'}) async {
    if (_isCleaningUp) return;
    _isCleaningUp = true;

    _durationTimer?.cancel();
    _durationTimer = null;

    final call = currentCall.value;
    if (call != null) {
      call.state = CallState.ended;
      call.endReason = status;
      currentCall.refresh();

      if (call.isCaller && call.chatId != null) {
        final int duration = call.duration;
        final effectiveStatus = duration > 0 ? 'completed' : status;
        _recordCallLog(
          chatId: call.chatId!,
          callId: call.callId,
          callType: call.callType == CallType.video ? 'video' : 'audio',
          status: effectiveStatus,
          duration: duration,
          receiverId: call.targetUserId,
        );
      }
    }

    // 1. Immediately detach callbacks from peer connection so closing does not trigger listeners
    if (_peerConnection != null) {
      _peerConnection!.onConnectionState = null;
      _peerConnection!.onIceCandidate = null;
      _peerConnection!.onTrack = null;
      _peerConnection!.onIceConnectionState = null;
      _peerConnection!.onSignalingState = null;
    }

    // 2. Detach renderers BEFORE disposing native stream textures to avoid GPU/Metal deadlock
    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;

    // 3. Reset loudspeaker safely
    try {
      Helper.setSpeakerphoneOn(false);
      isSpeakerOn.value = false;
    } catch (_) {}

    // 4. Safely stop and dispose screen stream
    if (_screenStream != null) {
      try {
        for (final track in _screenStream!.getTracks()) {
          try {
            track.stop();
          } catch (_) {}
        }
        await _screenStream!.dispose();
      } catch (_) {}
      _screenStream = null;
    }
    isScreenSharing.value = false;

    // 5. Safely stop and dispose local mic/camera stream
    if (_localStream != null) {
      try {
        for (final track in _localStream!.getTracks()) {
          try {
            track.stop();
          } catch (_) {}
        }
        await _localStream!.dispose();
      } catch (_) {}
      _localStream = null;
    }

    // 6. Close and dispose peer connection safely
    if (_peerConnection != null) {
      try {
        await _peerConnection!.close();
      } catch (_) {}
      try {
        await _peerConnection!.dispose();
      } catch (_) {}
      _peerConnection = null;
    }

    _pendingOfferSDP = null;
    _pendingCandidates.clear();

    // 7. Safely close any active call dialog or CallView on the next frame so gesture dispatch completes cleanly
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      if (Get.currentRoute == Routes.call ||
          Get.currentRoute.contains('call') ||
          Get.currentRoute.contains('CallView')) {
        Get.back();
      }
      // Wait for pop transition to finish before wiping session model
      Future.delayed(const Duration(milliseconds: 300), () {
        currentCall.value = null;
        _isCleaningUp = false;
      });
    });
  }

  void closeCallView() {
    if (Get.isDialogOpen ?? false) {
      Get.back();
    }
    if (Get.currentRoute == Routes.call ||
        Get.currentRoute.contains('call') ||
        Get.currentRoute.contains('CallView')) {
      Get.back();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      currentCall.value = null;
    });
  }

  Future<void> redial() async {
    final call = currentCall.value;
    if (call == null) return;
    final targetUserId = call.targetUserId;
    final targetUserName = call.targetUserName;
    final callType = call.callType;
    final chatId = call.chatId;

    currentCall.value = null;

    await startCall(
      targetUserId: targetUserId,
      targetUserName: targetUserName,
      callType: callType,
      chatId: chatId,
    );
  }

  Future<void> _recordCallLog({
    required int chatId,
    required String callId,
    required String callType,
    required String status,
    required int duration,
    required int receiverId,
  }) async {
    if (callId.isEmpty || _recordedCallIds.contains(callId)) {
      LoggerService.w('Call log already recorded for callId: $callId', tag: 'CallController');
      return;
    }
    _recordedCallIds.add(callId);

    try {
      final storageService = Get.find<StorageService>();
      final profile = storageService.userProfile;
      final callerId = (profile?['id'] as int?) ?? 0;
      final callerName = (profile?['name'] as String?) ?? 'User';

      final payload = formatCallLogPayload(
        callId: callId,
        callType: callType,
        status: status,
        duration: duration,
        callerId: callerId,
        callerName: callerName,
        receiverId: receiverId,
      );

      final apiClient = Get.find<ApiClient>();
      await apiClient.post(
        ApiEndpoints.messages,
        data: {
          'chat_id': chatId,
          'content': payload,
          'message_type': 'text',
        },
      );
      LoggerService.i('Call log recorded: $status', tag: 'CallController');
    } catch (e) {
      LoggerService.w('Failed to record call log: $e', tag: 'CallController');
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
