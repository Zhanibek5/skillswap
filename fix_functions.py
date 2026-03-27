import sys

with open('F:\skillswap\functions\index.js', 'r', encoding='utf-8') as f:
    content = f.read()

old_10min = '''await messagesRef.add({
senderId: 'system',
type: 'system_meeting_10min',
meetingTime: meetingData.meetingTime,
timestamp: admin.firestore.FieldValue.serverTimestamp(),
readBy: [],
})'''
new_10min = '''await messagesRef.add({
senderId: 'system',
type: 'system_meeting_10min',
meetingTime: meetingData.meetingTime,
duration: meetingData.duration || 60,
timestamp: admin.firestore.FieldValue.serverTimestamp(),
readBy: [],
})'''

old_started = '''await messagesRef.add({
senderId: 'system',
type: 'system_meeting_started',
meetingTime: meetingData.meetingTime,
timestamp: admin.firestore.FieldValue.serverTimestamp(),
readBy: [],
})'''
new_started = '''await messagesRef.add({
senderId: 'system',
type: 'system_meeting_started',
meetingTime: meetingData.meetingTime,
duration: meetingData.duration || 60,
timestamp: admin.firestore.FieldValue.serverTimestamp(),
readBy: [],
})'''

content = content.replace(old_10min, new_10min)
content = content.replace(old_started, new_started)

with open('F:\skillswap\functions\index.js', 'w', encoding='utf-8') as f:
    f.write(content)
print("Done")
