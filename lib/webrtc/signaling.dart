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

  // Track this locally to avoid await calls in listeners
  bool _hasRemoteDescription = false;
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
    final candidate = RTCIceCandidate(
      data['candidate'],
      data['sdpMid'],
      data['sdpMLineIndex'],
    );

    if (peerConnection == null || !_hasRemoteDescription) {
      _pendingRemoteCandidates.add(candidate);
      return;
    }

    await peerConnection!.addCandidate(candidate);
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
      await peerConnection!.addCandidate(candidate);
    }
  }

  Future<String> createRoom(RTCVideoRenderer remoteRenderer,
      {String? specificRoomId}) async {
    FirebaseFirestore db = FirebaseFirestore.instance;
    DocumentReference roomRef;

    _hasRemoteDescription = false;
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

    localStream?.getTracks().forEach((track) {
      peerConnection?.addTrack(track, localStream!);
    });

    var callerCandidatesCollection = roomRef.collection('callerCandidates');

    peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      print('Got candidate: ${candidate.toMap()}');
      callerCandidatesCollection.add(candidate.toMap());
    };

    RTCSessionDescription offer = await peerConnection!.createOffer();
    await peerConnection!.setLocalDescription(offer);
    print('Created offer: $offer');

    Map<String, dynamic> roomWithOffer = {'offer': offer.toMap()};

    await roomRef.set(roomWithOffer);
    print('New room created with SDK offer. Room ID: $roomId');
    currentRoomText = 'Current room is $roomId - You are the caller!';

    peerConnection?.onTrack = (RTCTrackEvent event) {
      if (event.streams.isEmpty) return;

      print('Got remote track: ${event.streams[0]}');
      event.streams[0].getTracks().forEach((track) {
        print('Add a track to the remoteStream $track');
        remoteStream?.addTrack(track);
      });
      if (remoteStream != null) {
        onAddRemoteStream?.call(remoteStream!);
      }
    };

    _roomSub = roomRef.snapshots().listen((snapshot) async {
      print('Got updated room: ${snapshot.data()}');

      if (!snapshot.exists) return;
      var data = snapshot.data() as Map<String, dynamic>;
      if (!_hasRemoteDescription && data['answer'] != null) {
        var answer = RTCSessionDescription(
          data['answer']['sdp'],
          data['answer']['type'],
        );

        print("Someone tried to connect");
        await peerConnection?.setRemoteDescription(answer);
        _hasRemoteDescription = true;
        await _flushPendingRemoteCandidates();
      }
    });

    _calleeCandidateSub =
        roomRef.collection('calleeCandidates').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data != null) {
            print('Got new remote ICE candidate: ${jsonEncode(data)}');
            _enqueueOrAddRemoteCandidate(data);
          }
        }
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
    _pendingRemoteCandidates.clear();

    // Wait until the room actually has an offer, in case we joined slightly before caller created it
    _roomSub = roomRef.snapshots().listen((snapshot) async {
      if (!snapshot.exists) return;

      var data = snapshot.data() as Map<String, dynamic>?;
      if (data == null || data['offer'] == null) return;

      // Only initialize connection once
      if (peerConnection != null) return;

      print(
          'Create PeerConnection for join with configuration: $configuration');
      peerConnection = await createPeerConnection(configuration);
      registerPeerConnectionListeners();

      localStream?.getTracks().forEach((track) {
        peerConnection?.addTrack(track, localStream!);
      });

      var calleeCandidatesCollection = roomRef.collection('calleeCandidates');
      peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        print('onIceCandidate: ${candidate.toMap()}');
        calleeCandidatesCollection.add(candidate.toMap());
      };

      peerConnection?.onTrack = (RTCTrackEvent event) {
        if (event.streams.isEmpty) return;

        print('Got remote track: ${event.streams[0]}');
        event.streams[0].getTracks().forEach((track) {
          print('Add a track to the remoteStream: $track');
          remoteStream?.addTrack(track);
        });
        if (remoteStream != null) {
          onAddRemoteStream?.call(remoteStream!);
        }
      };

      var offer = data['offer'];
      await peerConnection?.setRemoteDescription(
        RTCSessionDescription(offer['sdp'], offer['type']),
      );
      _hasRemoteDescription = true;
      var answer = await peerConnection!.createAnswer();
      print('Created Answer $answer');

      await peerConnection!.setLocalDescription(answer);

      Map<String, dynamic> roomWithAnswer = {
        'answer': {'type': answer.type, 'sdp': answer.sdp}
      };

      await roomRef.update(roomWithAnswer);

      _callerCandidateSub =
          roomRef.collection('callerCandidates').snapshots().listen((snapshot) {
        for (var document in snapshot.docChanges) {
          if (document.type == DocumentChangeType.added) {
            final docData = document.doc.data();
            if (docData != null) {
              print('Got new remote ICE candidate: $docData');
              _enqueueOrAddRemoteCandidate(docData);
            }
          }
        }
      });

      await _flushPendingRemoteCandidates();
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
        var calleeCandidates =
            await roomRef.collection('calleeCandidates').get();
        for (var document in calleeCandidates.docs) {
          document.reference.delete();
        }

        var callerCandidates =
            await roomRef.collection('callerCandidates').get();
        for (var document in callerCandidates.docs) {
          document.reference.delete();
        }

        await roomRef.delete();
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
    _pendingRemoteCandidates.clear();
  }

  void registerPeerConnectionListeners() {
    peerConnection?.onIceGatheringState = (RTCIceGatheringState state) {
      print('ICE gathering state changed: $state');
    };

    peerConnection?.onConnectionState = (RTCPeerConnectionState state) {
      print('Connection state change: $state');
    };

    peerConnection?.onSignalingState = (RTCSignalingState state) {
      print('Signaling state change: $state');
    };

    peerConnection?.onAddStream = (MediaStream stream) {
      print("Add remote stream");
      onAddRemoteStream?.call(stream);
      remoteStream = stream;
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
