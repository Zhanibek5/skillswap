import sys
import re

with open('F:/skillswap/functions/index.js', 'r', encoding='utf-8') as f:
    content = f.read()

content = re.sub(r"(type: 'system_meeting_10min',\s*meetingTime: meetingData\.meetingTime,)", r"\1\n\t\t\t\t\t\t\tduration: meetingData.duration || 60,", content)
content = re.sub(r"(type: 'system_meeting_started',\s*meetingTime: meetingData\.meetingTime,)", r"\1\n\t\t\t\t\t\t\tduration: meetingData.duration || 60,", content)

with open('F:/skillswap/functions/index.js', 'w', encoding='utf-8') as f:
    f.write(content)
print("Done regex")
