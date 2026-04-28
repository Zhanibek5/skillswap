import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRTCService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  Future<MediaStream> initLocalStream() async {
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {
        'facingMode': 'user',
        'mandatory': {
          'minWidth': '480',
          'minHeight': '640',
          'minFrameRate': '30',
        },
        'optional': [],
      }
    });
    return _localStream!;
  }

  void addRemoteStream(MediaStream stream) {
    _remoteStream = stream;
  }

  void muteAudio(bool mute) {
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = !mute;
    });
  }

  void toggleVideo(bool off) {
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = !off;
    });
  }

  void switchCamera() {
    _localStream?.getVideoTracks().forEach((track) {
      Helper.switchCamera(track);
    });
  }

  void dispose() {
    _localStream?.dispose();
    _peerConnection?.close();
  }

  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;
}
