const { onSchedule } = require('firebase-functions/v2/scheduler')
const { onDocumentCreated } = require('firebase-functions/v2/firestore')
const admin = require('firebase-admin')

admin.initializeApp()

// 🔹 1. КЕЗДЕСУ ЖАСАЛҒАНДА (Тек кездесу хабарламасын өңдейді)
exports.onMeetingCreated = onDocumentCreated(
	'chats/{chatId}/messages/{messageId}',
	async event => {
		const data = event.data.data()
		if (!data || data.type !== 'system_meeting_created') return

		await sendNotification(event.params.chatId, {
			title: '📅 Жаңа кездесу',
			body: 'Кездесу жоспарланды',
			type: 'meeting',
		})
	}
)

// 🔹 2. ЖАЙ ХАБАРЛАМАЛАР (Тек текст, аудио, сурет үшін)
exports.onMessageCreated = onDocumentCreated(
	'chats/{chatId}/messages/{messageId}',
	async event => {
		const data = event.data.data()
		if (!data) return

		const userMessageTypes = ['text', 'audio', 'image']
		// Егер бұл жай хабарлама болмаса, тоқтатамыз (дубликат болмауы үшін)
		if (!userMessageTypes.includes(data.type)) return

		const chatId = event.params.chatId
		const senderId = data.senderId

		const senderDoc = await admin
			.firestore()
			.collection('users')
			.doc(senderId)
			.get()
		const senderData = senderDoc.data()
		const senderName = senderDoc.exists ? senderData.firstName : 'Хабарлама'

		// Скриншоттағыдай "Zhanibek • Flutter" форматында шығару үшін:
		const chatDoc = await admin
			.firestore()
			.collection('chats')
			.doc(chatId)
			.get()
		const skill = chatDoc.data()?.lastSkill
			? ` • ${chatDoc.data().lastSkill}`
			: ''

		let bodyText = ''
		switch (data.type) {
			case 'text':
				bodyText = data.text
				break
			case 'audio':
				bodyText = '🎤 Дауыстық хабарлама'
				break
			case 'image':
				bodyText = '📷 Сурет жіберілді'
				break
		}

		await sendNotification(
			chatId,
			{
				title: `${senderName}${skill}`,
				body: bodyText,
				type: 'chat',
			},
			senderId
		) // Жіберушіні алып тастаймыз
	}
)

// 🔹 3. SCHEDULER (Бұрынғыша қалдырамыз)
exports.sendMeetingNotifications = onSchedule(
	{ schedule: 'every 1 minutes', timeZone: 'Asia/Almaty' },
	async () => {
		const now = Date.now()
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

				const meetingTime = meetingData.meetingTime.toDate().getTime()
				const diffMs = meetingTime - now

				if (diffMs > 0 && diffMs <= 10 * 60 * 1000) {
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
							'⏰ Кездесуге 10 минут қалды',
							'system_meeting_10min'
						)
						await sendNotification(chatId, {
							title: '⏰ 10 минут қалды',
							body: 'Кездесу басталуына аз қалды',
							type: 'meeting',
						})
					}
				}
				if (diffMs <= 0 && diffMs > -60 * 1000) {
					const exists = await messagesRef
						.where('type', '==', 'system_meeting_started')
						.where('meetingTime', '==', meetingData.meetingTime)
						.limit(1)
						.get()
					if (exists.empty) {
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
							body: 'Кездесу уақыты келді!',
							type: 'meeting',
						})
					}
				}
			}
		}
	}
)

async function updateChatLastMessage(chatId, lastMessage, lastType) {
	await admin.firestore().collection('chats').doc(chatId).update({
		lastMessage,
		lastTimestamp: admin.firestore.FieldValue.serverTimestamp(),
		lastType,
	})
}

// 🔹 БІРЫҢҒАЙ ХАБАРЛАМА ЖІБЕРУ ФУНКЦИЯСЫ
async function sendNotification(chatId, notification, excludeUserId = null) {
	const chatDoc = await admin.firestore().collection('chats').doc(chatId).get()
	const chatData = chatDoc.data()
	const participants = chatData.participants || []

	for (const userId of participants) {
		if (excludeUserId && userId === excludeUserId) continue

		const userDoc = await admin
			.firestore()
			.collection('users')
			.doc(userId)
			.get()
		if (!userDoc.exists) continue
		const userData = userDoc.data()

		if (userData.notificationsEnabled === false) continue

		if (Array.isArray(userData.fcmTokens)) {
			for (const token of userData.fcmTokens) {
				await admin
					.messaging()
					.send({
						token: token,
						notification: {
							title: notification.title,
							body: notification.body,
						},
						data: {
							type: notification.type,
							chatId: chatId,
							otherUserId: String(participants.find(id => id !== userId) || ''),
							selectedSkills: String(chatData.lastSkill || ''),
						},
						android: {
							priority: 'high',
							notification: {
								channelId: 'skillswap_channel',
								sound: 'default',
							},
						},
					})
					.catch(e => console.error('FCM Send Error', e))
			}
		}
	}
}
