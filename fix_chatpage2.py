import sys
import re

with open('F:\skillswap\lib\MainPage\chat\chatPage.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = re.sub(
    r'(final callDone =\s*await Navigator\.push\(\s*context,\s*MaterialPageRoute\(\s*builder: \(_\) => importWebrtc\s*\.VideoCallScreen\(\s*specificRoomId:\s*widget\.chatId,\s*isCaller:\s*shouldInitiateVideoCall,\s*otherUserId: otherUserId,\s*\),\s*\),\s*\);)',
    r'''int duration = data['duration'] ?? 60;
                                                final callDone = await Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => importWebrtc.VideoCallScreen(
                                                      specificRoomId: widget.chatId,
                                                      isCaller: shouldInitiateVideoCall,
                                                      otherUserId: otherUserId,
                                                      expectedDurationMinutes: duration,
                                                      role: widget.mode,
                                                    ),
                                                  ),
                                                );''',
    content
)

with open('F:\skillswap\lib\MainPage\chat\chatPage.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Done regex2")
