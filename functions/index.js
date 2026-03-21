const { onSchedule } = require('firebase-functions/v2/scheduler')
const { onDocumentCreated } = require('firebase-functions/v2/firestore')
const admin = require('firebase-admin')

admin.initializeApp()

/**
 * 1. КЕЗДЕСУ ЖАСАЛҒАНДА (Meeting Created)
 * Бұл функция тек 'system_meeting_created' типіндегі хабарламаларды ұстайды.
 */
exports.onMeetingCreated = onDocumentCreated(
	'chats/{chatId}/messages/{messageId}',
	async event => {
		const data = event.data.data()
		if (!data || data.type !== 'system_meeting_created') return

		const chatId = event.params.chatId
		if (!chatId) return

		await sendNotification(chatId, {
			title: '📅 Жаңа кездесу',
			body: 'Кездесу жоспарланды',
			type: 'meeting',
		})
	}
)

/**
 * 2. ЖАЙ ХАБАРЛАМАЛАР ҮШІН (Text, Audio, Image)
 * Пайдаланушы біреуге хат жазғанда іске қосылады.
 */
exports.onMessageCreated = onDocumentCreated(
	'chats/{chatId}/messages/{messageId}',
	async event => {
		const data = event.data.data()
		if (!data) return

		// Егер бұл жүйелік (meeting) хабарлама болса, оны өткізіп жібереміз
		if (data.type && data.type.startsWith('system_')) return

		const chatId = event.params.chatId
		const senderId = data.senderId

		// Жіберушінің атын алу
		const senderDoc = await admin
			.firestore()
			.collection('users')
			.doc(senderId)
			.get()
		const senderName = senderDoc.exists
			? senderDoc.data().firstName
			: 'Хабарлама'

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
			default:
				bodyText = 'Сізге жаңа хабарлама келді'
		}

		// Хабарламаны тек алушыға жіберу үшін senderId-ді excludeUserId ретінде береміз
		await sendNotification(
			chatId,
			{
				title: senderName,
				body: bodyText,
				type: 'chat',
			},
			senderId
		)
	}
)

/**
 * 3. ЖОСПАРЛЫ ТЕКСЕРУ (Scheduler - Every 1 Minute)
 * 10 минут қалғанда және басталғанда уведомление жібереді.
 */
exports.sendMeetingNotifications = onSchedule(
	{
		schedule: 'every 1 minutes',
		timeZone: 'Asia/Almaty',
	},
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

				// ⏰ 10 минут қалғанда
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
							body: 'Кездесу жақын арада басталады',
							type: 'meeting',
						})
					}
				}

				// 🔔 Басталғанда
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

/**
 * КӨМЕКШІ ФУНКЦИЯЛАР
 */
async function updateChatLastMessage(chatId, lastMessage, lastType) {
	await admin.firestore().collection('chats').doc(chatId).update({
		lastMessage,
		lastTimestamp: admin.firestore.FieldValue.serverTimestamp(),
		lastType,
	})
}

async function sendNotification(chatId, notification, excludeUserId = null) {
	const chatDoc = await admin.firestore().collection('chats').doc(chatId).get()
	if (!chatDoc.exists) return

	const chatData = chatDoc.data()
	const participants = chatData.participants || []
	const lastSkill = chatData.lastSkill || ''

	for (const userId of participants) {
		if (excludeUserId && userId === excludeUserId) continue

		const userDoc = await admin
			.firestore()
			.collection('users')
			.doc(userId)
			.get()
		if (!userDoc.exists) continue

		const userData = userDoc.data()
		const isEnabled =
			userData.notificationsEnabled === undefined
				? true
				: userData.notificationsEnabled === true
		if (!isEnabled) continue

		const otherUserIdForReceiver = participants.find(id => id !== userId) || ''

		if (Array.isArray(userData.fcmTokens)) {
			const messages = userData.fcmTokens.map(token => ({
				token: token,
				notification: { title: notification.title, body: notification.body },
				data: {
					type: notification.type, // 'meeting' немесе 'chat'
					chatId: chatId,
					otherUserId: String(otherUserIdForReceiver),
					selectedSkills: String(lastSkill),
				},
				android: {
					priority: 'high',
					notification: { channelId: 'skillswap_channel', sound: 'default' },
				},
			}))

			if (messages.length > 0) {
				await Promise.all(
					messages.map(msg =>
						admin
							.messaging()
							.send(msg)
							.catch(e => console.error('FCM Error', e))
					)
				)
			}
		}
	}
}
