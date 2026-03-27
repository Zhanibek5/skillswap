import sys
import re

with open('F:/skillswap/lib/webrtc/video_call_screen.dart', 'r', encoding='utf-8') as f:
    vc = f.read()

vc = re.sub(
    r'class VideoCallScreen extends StatefulWidget {\n  final String\? specificRoomId;\n  final bool isCaller;\n  final String\? otherUserId;\n\n  const VideoCallScreen\({.*?}\);',
    r'''class VideoCallScreen extends StatefulWidget {
  final String? specificRoomId;
  final bool isCaller;
  final String? otherUserId;
  final int expectedDurationMinutes;
  final String? role;

  const VideoCallScreen({
    super.key,
    this.specificRoomId,
    this.isCaller = false,
    this.otherUserId,
    this.expectedDurationMinutes = 60,
    this.role,
  });''',
    vc,
    flags=re.DOTALL
)

vc = re.sub(
    r'class _VideoCallScreenState extends State<VideoCallScreen> {\n  final Signaling signaling = Signaling\(\);',
    r'''class _VideoCallScreenState extends State<VideoCallScreen> {
  Timer? _callTimer;
  int _secondsRemaining = 0;
  int _secondsSpent = 0;
  bool _callActuallyStarted = false;

  final Signaling signaling = Signaling();''',
    vc
)

vc = re.sub(
    r'''if \(status\.contains\('IceConnectionStateConnected'\)\) {\n\s*ScaffoldMessenger\.of\(context\)\.showSnackBar\(''',
    r'''if (status.contains('IceConnectionStateConnected')) {
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
          ScaffoldMessenger.of(context).showSnackBar(''',
    vc
)

vc = re.sub(
    r'''Future<void> _leaveCall\(\{bool callFinished = false\}\) async {\n\s*if \(_isLeaving\) return;\n\s*_isLeaving = true;''',
    r'''void _showWarning(String msg) {
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
    }''',
    vc
)

vc = re.sub(
    r'''(if \(isVideoActive\)\n\s*Positioned\(\n\s*top: 60,\n\s*left: 0,\n\s*right: 0,\n\s*child: Column\(children: \[)''',
    r'''\1
                    if (_callActuallyStarted)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          ":",
                          style: TextStyle(
                            color: _secondsRemaining <= 60 ? Colors.redAccent : Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),''',
    vc
)

with open('F:/skillswap/lib/webrtc/video_call_screen.dart', 'w', encoding='utf-8') as f:
    f.write(vc)

print("Video updated with regex 2")
