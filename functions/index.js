const { onSchedule } = require('firebase-functions/v2/scheduler')
const admin = require('firebase-admin')

admin.initializeApp()

/**
 * MAIN SCHEDULED FUNCTION
 */
exports.sendMeetingNotifications = onSchedule(
	{
		schedule: 'every 1 minutes',
		timeZone: 'Asia/Almaty',
	},
	async () => {
		const now = new Date()

		const chatsSnapshot = await admin.firestore().collection('chats').get()

		for (const chatDoc of chatsSnapshot.docs) {
			const chatId = chatDoc.id

			const messagesRef = admin
				.firestore()
				.collection('chats')
				.doc(chatId)
				.collection('messages')

			const meetingSnapshot = await messagesRef
				.where('type', '==', 'system_meeting_created')
				.get()

			for (const meetingDoc of meetingSnapshot.docs) {
				const meetingData = meetingDoc.data()

				if (!meetingData.meetingTime) continue

				const meetingTime = meetingData.meetingTime.toDate()
				const diffMs = meetingTime - now

				// =========================
				// 🔔 10 MINUTES BEFORE
				// =========================
				if (diffMs <= 10 * 60 * 1000 && diffMs > 0) {
					const exists = await messagesRef
						.where('type', '==', 'system_meeting_10min')
						.where('meetingTime', '==', meetingData.meetingTime)
						.limit(1)
						.get()

					if (exists.empty) {
						await messagesRef.add({
							senderId: 'system',
							type: 'system_meeting_10min',
							meetingTime: meetingData.meetingTime,
							timestamp: admin.firestore.FieldValue.serverTimestamp(),
							readBy: [],
						})

						await updateChatLastMessage(
							chatId,
							'⏰ Кездесу басталуына 10 минут қалды',
							'system_meeting_10min'
						)

						await sendNotification(chatId, {
							title: '⏰ 10 минут қалды',
							body: 'Кездесу басталуына 10 минут қалды',
						})
					}
				}

				// =========================
				// 🚀 MEETING STARTED
				// =========================
				if (diffMs <= 0) {
					const startedExists = await messagesRef
						.where('type', '==', 'system_meeting_started')
						.where('meetingTime', '==', meetingData.meetingTime)
						.limit(1)
						.get()

					if (startedExists.empty) {
						await messagesRef.add({
							senderId: 'system',
							type: 'system_meeting_started',
							meetingTime: meetingData.meetingTime,
							timestamp: admin.firestore.FieldValue.serverTimestamp(),
							readBy: [],
						})

						await updateChatLastMessage(
							chatId,
							'🔔 Кездесу басталды',
							'system_meeting_started'
						)

						await sendNotification(chatId, {
							title: '🔔 Кездесу басталды',
							body: 'Енді кездесу басталды!',
						})
					}
				}
			}
		}
	}
)

// ===================================
// 📌 UPDATE CHAT LAST MESSAGE
// ===================================
async function updateChatLastMessage(chatId, lastMessage, lastType) {
	await admin.firestore().collection('chats').doc(chatId).update({
		lastMessage: lastMessage,
		lastTimestamp: admin.firestore.FieldValue.serverTimestamp(),
		lastType: lastType,
	})
}

// ===================================
// 📌 SEND NOTIFICATION
// ===================================
async function sendNotification(chatId, notification) {
	const participantsSnapshot = await admin
		.firestore()
		.collection('chats')
		.doc(chatId)
		.collection('participants')
		.get()

	const tokens = []

	for (const doc of participantsSnapshot.docs) {
		const userTokens = doc.data().fcmTokens || []
		tokens.push(...userTokens)
	}

	if (tokens.length === 0) return

	await admin.messaging().sendEachForMulticast({
		tokens,
		notification,
	})
}
