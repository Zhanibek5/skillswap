# coding=utf8
import sys
import re

# 1. UPDATE VIDEO_CALL_SCREEN
with open('F:/skillswap/lib/webrtc/video_call_screen.dart', 'r', encoding='utf-8') as f:
    vc = f.read()

vc = vc.replace(
'''  final String? specificRoomId;
  final bool isCaller;
  final String? otherUserId;

  const VideoCallScreen({
    super.key,
    this.specificRoomId,
    this.isCaller = false,
    this.otherUserId,
  });''',
'''  final String? specificRoomId;
  final bool isCaller;
  final String? otherUserId;
  final int expectedDurationMinutes;
  final String? role; // 'teach' or 'learn'

  const VideoCallScreen({
    super.key,
    this.specificRoomId,
    this.isCaller = false,
    this.otherUserId,
    this.expectedDurationMinutes = 60,
    this.role,
  });''')

vc = vc.replace(
'''class _VideoCallScreenState extends State<VideoCallScreen> {
  final Signaling signaling = Signaling();''',
'''class _VideoCallScreenState extends State<VideoCallScreen> {
  final Signaling signaling = Signaling();
  
  Timer? _callTimer;
  int _secondsRemaining = 0;
  int _secondsSpent = 0;
  bool _callActuallyStarted = false;
''')

# Wait, we want to start timer when IceConnectionStateConnected
vc = vc.replace(
'''        if (status.contains('IceConnectionStateConnected')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('?осылды / Participant joined'),''',
'''        if (status.contains('IceConnectionStateConnected')) {
          if (!_callActuallyStarted) {
             _callActuallyStarted = true;
             _secondsRemaining = widget.expectedDurationMinutes * 60;
             _secondsSpent = 0;
             _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
               if (!mounted) { timer.cancel(); return; }
               setState(() {
                 if (_secondsRemaining > 0) _secondsRemaining--;
                 _secondsSpent++;
               });
               
               if (_secondsRemaining == 5 * 60) {
                 _showWarning('5 минут ?алды / 5 minutes left');
               } else if (_secondsRemaining == 60) {
                 _showWarning('1 минут ?алды / 1 minute left');
               } else if (_secondsRemaining == 10) {
                 _showWarning('10 секунд ?алды / 10 seconds left');
               } else if (_secondsRemaining == 0) {
                 _leaveCall(callFinished: true);
                 timer.cancel();
               }
             });
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('?осылды / Participant joined'),''')


vc = vc.replace(
'''  Future<void> _leaveCall({bool callFinished = false}) async {
    if (_isLeaving) return;
    _isLeaving = true;''',
'''  void _showWarning(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        duration: const Duration(seconds: 3),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _leaveCall({bool callFinished = false}) async {
    if (_isLeaving) return;
    _isLeaving = true;
    _callTimer?.cancel();
    
    // Balance calculation
    if (_secondsSpent > 0 && widget.role != null) {
      int minutesSpent = (_secondsSpent / 60).ceil();
      if (minutesSpent > widget.expectedDurationMinutes) {
          minutesSpent = widget.expectedDurationMinutes;
      }
      if (minutesSpent > 0) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
          try {
            await FirebaseFirestore.instance.runTransaction((transaction) async {
              final snap = await transaction.get(userRef);
              if (snap.exists) {
                final data = snap.data()!;
                int bal = data['balance'] ?? 120;
                int earn = data['timeEarned'] ?? 0;
                int spent = data['timeSpent'] ?? 0;
                
                if (widget.role == 'teach') {
                  bal += minutesSpent;
                  earn += minutesSpent;
                } else if (widget.role == 'learn') {
                  bal -= minutesSpent;
                  spent += minutesSpent;
                }
                transaction.update(userRef, {
                  'balance': bal,
                  'timeEarned': earn,
                  'timeSpent': spent,
                });
              }
            });
          } catch(e) {
            print("Error updating balance: \");
          }
        }
      }
    }''')

vc = vc.replace(
'''            if (isVideoActive)
              Positioned(
                  top: 60,
                  left: 0,
                  right: 0,''',
'''            if (isVideoActive)
              Positioned(
                  top: 60,
                  left: 0,
                  right: 0,
                  child: Column(children: [
                    if (_callActuallyStarted)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "\:\",
                          style: TextStyle(
                            color: _secondsRemaining <= 60 ? Colors.redAccent : Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),''')

with open('F:/skillswap/lib/webrtc/video_call_screen.dart', 'w', encoding='utf-8') as f:
    f.write(vc)

print("Video updated")
