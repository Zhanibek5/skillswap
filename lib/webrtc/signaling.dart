import 'dart:convert';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

typedef void StreamStateCallback(MediaStream stream);

class Signaling {
  Map<String, dynamic> configuration = {
    'iceCandidatePoolSize': 10,
    'iceServers': [
      {
        'urls': [
          'stun:stun.l.google.com:19302',
          'stun:stun1.l.google.com:19302',
          'stun:stun2.l.google.com:19302',
          'stun:stun3.l.google.com:19302',
          'stun:stun4.l.google.com:19302',
        ]
      },
      {
        'urls': [
          'turn:openrelay.metered.ca:80',
          'turn:openrelay.metered.ca:80?transport=tcp',
          'turn:openrelay.metered.ca:443',
          'turn:openrelay.metered.ca:443?transport=tcp',
          'turns:openrelay.metered.ca:443?transport=tcp',
        ],
        'username': 'openrelayproject',
        'credential': 'openrelayproject'
      }
    ]
  };

  RTCPeerConnection? peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;
  String? roomId;
  String? currentRoomText;
  StreamStateCallback? onAddRemoteStream;
  void Function(String status)? onConnectionStatusChange;

  // Track this locally to avoid await calls in listeners
  bool _hasRemoteDescription = false;
  bool _isJoining = false;
  bool _isApplyingAnswer = false;
  final List<RTCIceCandidate> _pendingRemoteCandidates = [];
  StreamSubscription? _roomSub;
  StreamSubscription? _callerCandidateSub;
  StreamSubscription? _calleeCandidateSub;

  Future<void> _deleteCollection(CollectionReference collection) async {
    final snapshot = await collection.get();
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  Future<void> _clearRoom(DocumentReference roomRef) async {
    await _deleteCollection(roomRef.collection('callerCandidates'));
    await _deleteCollection(roomRef.collection('calleeCandidates'));

    final roomSnapshot = await roomRef.get();
    if (roomSnapshot.exists) {
      await roomRef.delete();
    }
  }

  Future<void> _enqueueOrAddRemoteCandidate(Map<String, dynamic> data) async {
    try {
      final sdpMLineIndex = data['sdpMLineIndex'];
      final parsedIndex = sdpMLineIndex is int
          ? sdpMLineIndex
          : (sdpMLineIndex != null
              ? int.tryParse(sdpMLineIndex.toString())
              : null);

      final candidate = RTCIceCandidate(
        data['candidate']?.toString(),
        data['sdpMid']?.toString(),
        parsedIndex,
      );

      if (peerConnection == null || !_hasRemoteDescription) {
        _pendingRemoteCandidates.add(candidate);
        return;
      }

      await peerConnection!.addCandidate(candidate);
    } catch (e) {
      print('Error adding remote candidate: $e');
      onConnectionStatusChange?.call('Candidate error: $e');
    }
  }

  Future<void> _flushPendingRemoteCandidates() async {
    if (peerConnection == null ||
        !_hasRemoteDescription ||
        _pendingRemoteCandidates.isEmpty) {
      return;
    }

    final pendingCandidates = List<RTCIceCandidate>.from(
      _pendingRemoteCandidates,
    );
    _pendingRemoteCandidates.clear();

    for (final candidate in pendingCandidates) {
      try {
        await peerConnection!.addCandidate(candidate);
      } catch (e) {
        print('Error flushing remote candidate: $e');
        onConnectionStatusChange?.call('Candidate flush error: $e');
      }
    }
  }

  Future<void> _attachLocalStream() async {
    if (peerConnection == null || localStream == null) return;
    await peerConnection!.addStream(localStream!);
  }

  void _handleIncomingRemoteMedia({
    MediaStream? stream,
    MediaStreamTrack? track,
  }) {
    if (stream != null) {
      remoteStream = stream;
      onAddRemoteStream?.call(stream);
      return;
    }

    if (track == null || remoteStream == null) return;

    final hasTrack = remoteStream!.getTracks().any(
          (existingTrack) => existingTrack.id == track.id,
        );
    if (!hasTrack) {
      remoteStream!.addTrack(track);
    }
    onAddRemoteStream?.call(remoteStream!);
  }

  Future<String> createRoom(RTCVideoRenderer remoteRenderer,
      {String? specificRoomId}) async {
    FirebaseFirestore db = FirebaseFirestore.instance;
    DocumentReference roomRef;

    _hasRemoteDescription = false;
    _isJoining = false;
    _isApplyingAnswer = false;
    _pendingRemoteCandidates.clear();

    if (specificRoomId != null) {
      roomRef = db.collection('rooms').doc(specificRoomId);
      await _clearRoom(roomRef);
    } else {
      roomRef = db.collection('rooms').doc();
    }

    roomId = roomRef.id;

    print('Create PeerConnection with configuration: $configuration');

    peerConnection = await createPeerConnection(configuration);

    registerPeerConnectionListeners();

    await _attachLocalStream();

    var callerCandidatesCollection = roomRef.collection('callerCandidates');

    peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      try {
        print('Got candidate: ${candidate.toMap()}');
        callerCandidatesCollection.add(candidate.toMap());
      } catch (e) {
        print('Error sending caller candidate: $e');
        onConnectionStatusChange?.call('Local candidate error: $e');
      }
    };

    RTCSessionDescription offer = await peerConnection!.createOffer({
      'offerToReceiveAudio': 1,
      'offerToReceiveVideo': 1,
    });
    await peerConnection!.setLocalDescription(offer);
    print('Created offer: $offer');

    Map<String, dynamic> roomWithOffer = {'offer': offer.toMap()};

    await roomRef.set(roomWithOffer);
    print('New room created with SDK offer. Room ID: $roomId');
    currentRoomText = 'Current room is $roomId - You are the caller!';

    _roomSub = roomRef.snapshots().listen((snapshot) async {
      try {
        print('Got updated room: ${snapshot.data()}');

        if (!snapshot.exists) return;
        var data = snapshot.data() as Map<String, dynamic>;
        if (!_hasRemoteDescription &&
            data['answer'] != null &&
            !_isApplyingAnswer) {
          _isApplyingAnswer = true;
          var answer = RTCSessionDescription(
            data['answer']['sdp'],
            data['answer']['type'],
          );

          print("Someone tried to connect");
          await peerConnection?.setRemoteDescription(answer);
          _hasRemoteDescription = true;
          await _flushPendingRemoteCandidates();
        }
      } catch (e) {
        print('Error handling room updates: $e');
        onConnectionStatusChange?.call('Room update error: $e');
      }
    });

    _calleeCandidateSub =
        roomRef.collection('calleeCandidates').snapshots().listen((snapshot) {
      try {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data();
            if (data != null) {
              print('Got new remote ICE candidate: ${jsonEncode(data)}');
              _enqueueOrAddRemoteCandidate(data);
            }
          }
        }
      } catch (e) {
        print('Error listening callee candidates: $e');
        onConnectionStatusChange?.call('Callee candidate error: $e');
      }
    });

    return roomId!;
  }

  Future<void> joinRoom(String roomId, RTCVideoRenderer remoteVideo) async {
    FirebaseFirestore db = FirebaseFirestore.instance;
    print("Joining room: $roomId");
    DocumentReference roomRef = db.collection('rooms').doc(roomId);
    this.roomId = roomId;
    _hasRemoteDescription = false;
    _isJoining = false;
    _isApplyingAnswer = false;
    _pendingRemoteCandidates.clear();

    // Wait until the room actually has an offer, in case we joined slightly before caller created it
    _roomSub = roomRef.snapshots().listen((snapshot) async {
      try {
        if (!snapshot.exists) return;

        var data = snapshot.data() as Map<String, dynamic>?;
        if (data == null || data['offer'] == null) return;

        // Only initialize connection once
        if (peerConnection != null || _isJoining) return;
        _isJoining = true;

        print(
            'Create PeerConnection for join with configuration: $configuration');
        peerConnection = await createPeerConnection(configuration);
        registerPeerConnectionListeners();

        await _attachLocalStream();

        var calleeCandidatesCollection = roomRef.collection('calleeCandidates');
        peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
          try {
            print('onIceCandidate: ${candidate.toMap()}');
            calleeCandidatesCollection.add(candidate.toMap());
          } catch (e) {
            print('Error sending callee candidate: $e');
            onConnectionStatusChange?.call('Local candidate error: $e');
          }
        };

        var offer = data['offer'];
        await peerConnection?.setRemoteDescription(
          RTCSessionDescription(offer['sdp'], offer['type']),
        );
        _hasRemoteDescription = true;
        var answer = await peerConnection!.createAnswer({
          'offerToReceiveAudio': 1,
          'offerToReceiveVideo': 1,
        });
        print('Created Answer $answer');

        await peerConnection!.setLocalDescription(answer);

        Map<String, dynamic> roomWithAnswer = {
          'answer': {'type': answer.type, 'sdp': answer.sdp}
        };

        await roomRef.update(roomWithAnswer);

        _callerCandidateSub =
            roomRef.collection('callerCandidates').snapshots().listen(
          (snapshot) {
            try {
              for (var document in snapshot.docChanges) {
                if (document.type == DocumentChangeType.added) {
                  final docData = document.doc.data();
                  if (docData != null) {
                    print('Got new remote ICE candidate: $docData');
                    _enqueueOrAddRemoteCandidate(docData);
                  }
                }
              }
            } catch (e) {
              print('Error listening caller candidates: $e');
              onConnectionStatusChange?.call('Caller candidate error: $e');
            }
          },
        );

        await _flushPendingRemoteCandidates();
      } catch (e) {
        print('Error joining room: $e');
        onConnectionStatusChange?.call('Join error: $e');
      }
    });
  }

  Future<void> openUserMedia(
    RTCVideoRenderer localVideo,
    RTCVideoRenderer remoteVideo,
  ) async {
    var stream = await navigator.mediaDevices
        .getUserMedia({'video': true, 'audio': true});

    localVideo.srcObject = stream;
    localStream = stream;

    remoteStream = await createLocalMediaStream('key');
    remoteVideo.srcObject = remoteStream;
  }

  Future<void> hangUp(RTCVideoRenderer localVideo) async {
    await stopScreenShare(localVideo);

    _roomSub?.cancel();
    _callerCandidateSub?.cancel();
    _calleeCandidateSub?.cancel();

    List<MediaStreamTrack>? tracks = localVideo.srcObject?.getTracks();
    if (tracks != null) {
      for (var track in tracks) {
        track.stop();
      }
    }

    if (remoteStream != null) {
      for (var track in remoteStream!.getTracks()) {
        track.stop();
      }
    }

    if (peerConnection != null) {
      peerConnection!.close();
    }

    if (roomId != null) {
      var db = FirebaseFirestore.instance;
      var roomRef = db.collection('rooms').doc(roomId);

      try {
        await _clearRoom(roomRef);
      } catch (e) {
        print("Could not clean up DB on hangup: ");
      }
    }

    localStream?.dispose();
    remoteStream?.dispose();
    peerConnection?.dispose();
    peerConnection = null;
    roomId = null;
    _hasRemoteDescription = false;
    _isJoining = false;
    _isApplyingAnswer = false;
    _pendingRemoteCandidates.clear();
  }

  void registerPeerConnectionListeners() {
    peerConnection?.onIceGatheringState = (RTCIceGatheringState state) {
      print('ICE gathering state changed: $state');
      onConnectionStatusChange?.call('ICE: $state');
    };

    peerConnection?.onIceConnectionState = (RTCIceConnectionState state) {
      print('ICE connection state changed: $state');
      onConnectionStatusChange?.call('ICE connection: $state');
    };

    peerConnection?.onConnectionState = (RTCPeerConnectionState state) {
      print('Connection state change: $state');
      onConnectionStatusChange?.call('Connection: $state');
    };

    peerConnection?.onSignalingState = (RTCSignalingState state) {
      print('Signaling state change: $state');
      onConnectionStatusChange?.call('Signaling: $state');
    };

    peerConnection?.onAddStream = (MediaStream stream) {
      print("Add remote stream");
      _handleIncomingRemoteMedia(stream: stream);
    };

    peerConnection?.onAddTrack = (
      MediaStream stream,
      MediaStreamTrack track,
    ) {
      print("Add remote track: ${track.kind}");
      _handleIncomingRemoteMedia(stream: stream, track: track);
    };

    peerConnection?.onTrack = (RTCTrackEvent event) {
      print(
        'Track event: kind=${event.track.kind}, streams=${event.streams.length}',
      );
      if (event.streams.isNotEmpty) {
        _handleIncomingRemoteMedia(
          stream: event.streams.first,
          track: event.track,
        );
        return;
      }

      _handleIncomingRemoteMedia(track: event.track);
    };
  }

  bool isMicOn = true;
  bool isCameraOn = true;

  void toggleMic() {
    if (localStream != null) {
      bool enabled = localStream!.getAudioTracks()[0].enabled;
      localStream!.getAudioTracks()[0].enabled = !enabled;
      isMicOn = !enabled;
    }
  }

  void toggleCamera() {
    if (localStream != null) {
      bool enabled = localStream!.getVideoTracks()[0].enabled;
      localStream!.getVideoTracks()[0].enabled = !enabled;
      isCameraOn = !enabled;
    }
  }

  bool isScreenSharing = false;
  MediaStream? displayStream;

  Future<void> toggleScreenShare(RTCVideoRenderer localVideo) async {
    if (peerConnection == null) return;

    if (!isScreenSharing) {
      try {
        final Map<String, dynamic> mediaConstraints = {
          'audio': false,
          'video': true,
        };

        displayStream =
            await navigator.mediaDevices.getDisplayMedia(mediaConstraints);
        var displayTrack = displayStream!.getVideoTracks()[0];

        var senders = await peerConnection!.getSenders();
        var videoSender =
            senders.firstWhere((sender) => sender.track?.kind == 'video');
        await videoSender.replaceTrack(displayTrack);

        localVideo.srcObject = displayStream;
        isScreenSharing = true;

        displayTrack.onEnded = () async {
          await stopScreenShare(localVideo);
        };
      } catch (e) {
        print("Error sharing screen: ");
      }
    } else {
      await stopScreenShare(localVideo);
    }
  }

  Future<void> stopScreenShare(RTCVideoRenderer localVideo) async {
    if (!isScreenSharing) return;

    if (localStream != null && peerConnection != null) {
      var cameraTrack = localStream!.getVideoTracks().isNotEmpty
          ? localStream!.getVideoTracks()[0]
          : null;
      if (cameraTrack != null) {
        var senders = await peerConnection!.getSenders();
        try {
          var videoSender =
              senders.firstWhere((sender) => sender.track?.kind == 'video');
          await videoSender.replaceTrack(cameraTrack);
        } catch (e) {
          print("Error replacing screen share track back to camera: $e");
        }
        localVideo.srcObject = localStream;
      }
    }

    displayStream?.getTracks().forEach((track) => track.stop());
    displayStream?.dispose();
    displayStream = null;
    isScreenSharing = false;
  }
}
