const { onSchedule } = require('firebase-functions/v2/scheduler')
const { onDocumentCreated } = require('firebase-functions/v2/firestore')
const admin = require('firebase-admin')
const fs = require('fs')
const path = require('path')

admin.initializeApp()

// Load locales for notification translation
const locales = {
	en: JSON.parse(
		fs.readFileSync(path.join(__dirname, 'locales', 'en.json'), 'utf8')
	),
	ru: JSON.parse(
		fs.readFileSync(path.join(__dirname, 'locales', 'ru.json'), 'utf8')
	),
	kk: JSON.parse(
		fs.readFileSync(path.join(__dirname, 'locales', 'kk.json'), 'utf8')
	),
}

function translateNotificationBody(key, langCode) {
	const code = langCode || 'en'
	const localeData = locales[code] || locales['en']
	return localeData[key] || key
}

function getChatSkill(chatData = {}) {
	const data = chatData || {}

	if (Array.isArray(data.selectedSkills)) {
		return data.selectedSkills
			.map(skill => String(skill || '').trim())
			.filter(Boolean)
			.join(', ')
	}

	return String(data.lastSkill || '').trim()
}

function buildSkillTitle(userName, chatData = {}) {
	const name = String(userName || '').trim()
	const skill = getChatSkill(chatData)

	if (!skill) return name
	if (!name) return skill

	return `${name}: ${skill}`
}

function getNameFromTitle(title, skill) {
	const rawTitle = String(title || '').trim()
	if (!rawTitle) return ''

	if (skill && rawTitle.endsWith(`: ${skill}`)) {
		return rawTitle.slice(0, -skill.length - 2).trim()
	}

	const lastColonIndex = rawTitle.lastIndexOf(':')
	if (lastColonIndex >= 0) {
		return rawTitle.slice(lastColonIndex + 1).trim()
	}

	return rawTitle
}

function normalizeNotificationTitle(title, senderData, chatData = {}) {
	const skill = getChatSkill(chatData)
	if (!skill) return String(title || '').trim()

	const name = senderData?.firstName || getNameFromTitle(title, skill)
	return buildSkillTitle(name, chatData)
}

exports.deleteUnverifiedUsers = onSchedule('every 24 hours', async () => {
	const result = await admin.auth().listUsers()
	const now = new Date()

	for (const user of result.users) {
		if (!user.emailVerified) {
			const createdAt = new Date(user.metadata.creationTime)

			if (now - createdAt > 24 * 60 * 60 * 1000) {
				await admin.auth().deleteUser(user.uid)
				await admin.firestore().collection('users').doc(user.uid).delete()

				console.log('Deleted:', user.uid)
			}
		}
	}
})

// 🔹 1. КЕЗДЕСУ ЖАСАЛҒАНДА (Тек кездесу хабарламасын өңдейді)
exports.onMeetingCreated = onDocumentCreated(
	'chats/{chatId}/messages/{messageId}',
	async event => {
		const data = event.data.data()
		if (!data || data.type !== 'system_meeting_created') return

		const chatId = event.params.chatId
		const senderId = data.senderId

		const chatDoc = await admin
			.firestore()
			.collection('chats')
			.doc(chatId)
			.get()
		if (!chatDoc.exists) return
		const chatData = chatDoc.data()

		const participants = chatData.participants || []
		const recipientId = participants.find(id => id !== senderId)

		if (!recipientId) return

		const senderDoc = await admin
			.firestore()
			.collection('users')
			.doc(senderId)
			.get()
		const senderData = senderDoc.exists ? senderDoc.data() : null
		const senderName = senderData?.firstName || 'Пайдаланушы'

		const finalTitle = buildSkillTitle(senderName, chatData)

		const chatRef = admin.firestore().collection('chats').doc(chatId)
		let shouldNotify = false

		await admin.firestore().runTransaction(async tx => {
			const currentChatDoc = await tx.get(chatRef)
			if (!currentChatDoc.exists) return
			const currentChatData = currentChatDoc.data()
			const activeUsers = currentChatData.activeUsers || {}

			let updateData = {}
			if (activeUsers[recipientId] === true) {
				updateData[`unreadCount.${recipientId}`] = 0
			} else {
				updateData[`unreadCount.${recipientId}`] =
					admin.firestore.FieldValue.increment(1)
				shouldNotify = true
			}

			if (Object.keys(updateData).length > 0) {
				tx.update(chatRef, updateData)
			}
		})

		if (shouldNotify) {
			await sendToUser(recipientId, chatId, {
				title: finalTitle,
				body: 'meeting_scheduled',
				type: 'meeting',
				senderData: senderData,
				chatData: chatData,
			})
		}
	}
)

exports.onMessageCreated = onDocumentCreated(
	'chats/{chatId}/messages/{messageId}',
	async event => {
		const data = event.data.data()
		if (!data || data.senderId === 'system') return

		const userMessageTypes = ['text', 'audio', 'image']
		if (!userMessageTypes.includes(data.type)) return

		const chatId = event.params.chatId
		const senderId = data.senderId

		const chatRef = admin.firestore().collection('chats').doc(chatId)

		// 🔹 Sender info
		const senderDoc = await admin
			.firestore()
			.collection('users')
			.doc(senderId)
			.get()
		const senderData = senderDoc.data()
		const senderName = senderData?.firstName || 'Пайдаланушы'

		// 🔹 Message text
		let bodyText = ''
		switch (data.type) {
			case 'text':
				bodyText = data.text
				break
			case 'audio':
				bodyText = 'voice_message'
				break
			case 'image':
				bodyText = 'image_sent'
				break
			default:
				bodyText = 'new_message'
		}

		let recipientId = null
		let chatData = null
		let shouldNotify = false

		try {
			await admin.firestore().runTransaction(async tx => {
				const chatDoc = await tx.get(chatRef)
				if (!chatDoc.exists) return

				chatData = chatDoc.data()
				if (!chatData) return

				const participants = chatData.participants || []

				// 🔹 кімге жіберіледі
				recipientId = participants.find(id => id !== senderId)
				if (!recipientId) return

				const activeUsers = chatData.activeUsers || {}

				const isRecipientActive = activeUsers[recipientId] === true

				let updateData = {
					lastMessage: bodyText,
					lastTimestamp: admin.firestore.FieldValue.serverTimestamp(),
					lastType: data.type,
				}

				if (isRecipientActive) {
					// ✅ ONLINE → always 0
					updateData[`unreadCount.${recipientId}`] = 0
				} else {
					// ❌ OFFLINE → increment
					updateData[`unreadCount.${recipientId}`] =
						admin.firestore.FieldValue.increment(1)

					shouldNotify = true
				}

				tx.update(chatRef, updateData)
			})

			// 🔔 Notification тек offline кезде
			if (shouldNotify && recipientId && chatData) {
				const finalTitle = buildSkillTitle(senderName, chatData)

				await sendToUser(recipientId, chatId, {
					title: finalTitle,
					body: bodyText,
					type: 'chat',
					senderData: senderData,
					chatData: chatData,
				})
			}
		} catch (error) {
			console.error('Transaction failed:', error)
		}
	}
)

exports.sendMeetingNotifications = onSchedule(
	{ schedule: 'every 1 minutes', timeZone: 'Asia/Almaty' },
	async () => {
		console.log('🔥 FUNCTION ENTERED')
		const now = Date.now()
		const chatsSnapshot = await admin.firestore().collection('chats').get()
		console.log('📦 Chats count:', chatsSnapshot.size)

		for (const chatDoc of chatsSnapshot.docs) {
			const chatId = chatDoc.id
			const chatData = chatDoc.data()
			const messagesRef = admin
				.firestore()
				.collection('chats')
				.doc(chatId)
				.collection('messages')

			const meetingSnapshot = await messagesRef
				.where('type', '==', 'system_meeting_created')
				.get()
			console.log('📅 Meetings found:', meetingSnapshot.size)

			for (const meetingDoc of meetingSnapshot.docs) {
				const meetingData = meetingDoc.data()
				if (!meetingData.meetingTime) continue

				const meetingId = meetingData.meetingId || meetingDoc.id
				const meetingTime = meetingData.meetingTime.toDate().getTime()
				const joinDeadline = meetingTime + 10 * 60 * 1000
				const diffMs = meetingTime - now

				const participants = chatData.participants || []

				// 🔹 10 минут қалғанда хабарлау
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
							meetingId,
							meetingTime: meetingData.meetingTime,
							joinDeadline: admin.firestore.Timestamp.fromMillis(joinDeadline),
							duration: meetingData.duration || 60,
							timestamp: admin.firestore.FieldValue.serverTimestamp(),
							readBy: [],
						})
						await updateChatLastMessageAndUnread(
							chatId,
							'reminder_10_min',
							'system_meeting_10min'
						)

						// Use fresh chat data for active users check
						const currentChatDoc = await admin
							.firestore()
							.collection('chats')
							.doc(chatId)
							.get()
						const activeUsers = currentChatDoc.exists
							? currentChatDoc.data().activeUsers || {}
							: {}

						for (const userId of participants) {
							if (activeUsers[userId] === true) continue

							const otherUserId =
								participants.find(id => id !== userId) || userId
							const otherUserDoc = await admin
								.firestore()
								.collection('users')
								.doc(otherUserId)
								.get()
							const otherUserName = otherUserDoc.exists
								? otherUserDoc.data().firstName || 'Пайдаланушы'
								: 'Пайдаланушы'
							const otherUserData = otherUserDoc.exists
								? otherUserDoc.data()
								: null

							let finalTitle = `⏰ ${otherUserName}`
							if (getChatSkill(chatData)) {
								finalTitle = buildSkillTitle(otherUserName, chatData)
							}

							await sendToUser(userId, chatId, {
								title: finalTitle,
								body: 'soon_start',
								type: 'meeting',
								senderData: otherUserData,
								chatData: chatData,
							})
						}
					}
				}

				// 🔹 Кездесу басталған кезде хабарлау
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
							meetingId,
							meetingStatus: 'started',
							meetingTime: meetingData.meetingTime,
							joinDeadline: admin.firestore.Timestamp.fromMillis(joinDeadline),
							duration: meetingData.duration || 60,
							timestamp: admin.firestore.FieldValue.serverTimestamp(),
							readBy: [],
						})
						await updateChatLastMessageAndUnread(
							chatId,
							'meeting_started',
							'system_meeting_started'
						)

						// Use fresh chat data for active users check
						const currentChatDoc = await admin
							.firestore()
							.collection('chats')
							.doc(chatId)
							.get()
						const activeUsers = currentChatDoc.exists
							? currentChatDoc.data().activeUsers || {}
							: {}

						for (const userId of participants) {
							if (activeUsers[userId] === true) continue

							const otherUserId =
								participants.find(id => id !== userId) || userId
							const otherUserDoc = await admin
								.firestore()
								.collection('users')
								.doc(otherUserId)
								.get()
							const otherUserName = otherUserDoc.exists
								? otherUserDoc.data().firstName || 'Пайдаланушы'
								: 'Пайдаланушы'
							const otherUserData = otherUserDoc.exists
								? otherUserDoc.data()
								: null

							let finalTitle = `🔔 ${otherUserName}`
							if (getChatSkill(chatData)) {
								finalTitle = buildSkillTitle(otherUserName, chatData)
							}

							await sendToUser(userId, chatId, {
								title: finalTitle,
								body: 'time_to_meet',
								type: 'meeting',
								senderData: otherUserData,
								chatData: chatData,
							})
						}
					}
				}

				if (now >= joinDeadline) {
					const expiredExists = await messagesRef
						.where('type', '==', 'system_meeting_expired')
						.where('meetingId', '==', meetingId)
						.limit(1)
						.get()
					const completedExists = await messagesRef
						.where('type', '==', 'system_meeting_completed')
						.where('meetingId', '==', meetingId)
						.limit(1)
						.get()

					if (expiredExists.empty && completedExists.empty) {
						const roomRef = admin.firestore().collection('rooms').doc(chatId)
						const roomDoc = await roomRef.get()
						const roomData = roomDoc.exists ? roomDoc.data() : null
						const roomMeetingId = roomData?.meetingId
						const sameMeeting = roomMeetingId
							? roomMeetingId === meetingId
							: roomData?.meetingTime?.toMillis?.() === meetingTime
						const roomStatus = sameMeeting ? roomData?.status : null

						if (roomStatus !== 'active' && roomStatus !== 'completed') {
							await roomRef.set(
								{
									status: 'expired',
									meetingId,
									meetingTime: meetingData.meetingTime,
									joinDeadline:
										admin.firestore.Timestamp.fromMillis(joinDeadline),
									expiredAt: admin.firestore.FieldValue.serverTimestamp(),
									preserveRoom: true,
								},
								{ merge: true }
							)

							await messagesRef.doc(`system_meeting_expired_${meetingId}`).set(
								{
									senderId: 'system',
									type: 'system_meeting_expired',
									meetingId,
									meetingStatus: 'expired',
									meetingTime: meetingData.meetingTime,
									joinDeadline:
										admin.firestore.Timestamp.fromMillis(joinDeadline),
									duration: meetingData.duration || 60,
									timestamp: admin.firestore.FieldValue.serverTimestamp(),
									readBy: [],
								},
								{ merge: true }
							)

							await updateChatLastMessageAndUnread(
								chatId,
								'meeting_expired',
								'system_meeting_expired'
							)
						}
					}
				}
			}
		}
	}
)

async function sendToUser(userId, chatId, payload) {
	const userDoc = await admin.firestore().collection('users').doc(userId).get()
	if (!userDoc.exists) return

	const userData = userDoc.data()
	if (userData.notificationsEnabled === false) return

	if (!Array.isArray(userData.fcmTokens) || userData.fcmTokens.length === 0) {
		return
	}

	const tokens = [...new Set(userData.fcmTokens)].filter(Boolean)
	const selectedSkills = getChatSkill(payload.chatData)
	const notificationTitle = normalizeNotificationTitle(
		payload.title,
		payload.senderData,
		payload.chatData
	)

	const translatedBody = translateNotificationBody(
		payload.body,
		userData.language
	)

	for (const token of tokens) {
		try {
			await admin.messaging().send({
				token: token,
				notification: {
					title: notificationTitle,
					body: String(translatedBody || ''),
				},
				data: {
					title: notificationTitle,
					body: String(translatedBody || ''),
					userImage: String(payload.senderData?.photoUrl || ''),
					type: String(payload.type || ''),
					chatId: String(chatId),
					otherUserId: String(
						payload.chatData.participants.find(id => id !== userId) || ''
					),
					selectedSkills: selectedSkills,
				},
			})
		} catch (e) {
			console.error('FCM Error:', e)

			if (
				e.code === 'messaging/registration-token-not-registered' ||
				e.code === 'messaging/invalid-registration-token'
			) {
				await admin
					.firestore()
					.collection('users')
					.doc(userId)
					.update({
						fcmTokens: admin.firestore.FieldValue.arrayRemove(token),
					})
			}
		}
	}
}

async function getChatTitle(chatId, currentUserId = null) {
	const chatDoc = await admin.firestore().collection('chats').doc(chatId).get()
	if (!chatDoc.exists) return 'Чат'

	const chatData = chatDoc.data()
	const participants = chatData.participants || []

	// 🔹 Егер currentUserId берілсе, оны шығарып тастап, қалған қатысушылардың атын аламыз
	let otherParticipants = participants
	if (currentUserId) {
		otherParticipants = participants.filter(id => id !== currentUserId)
	}

	// 🔹 Әр қатысушының атын аламыз
	const namesPromises = otherParticipants.map(async userId => {
		const userDoc = await admin
			.firestore()
			.collection('users')
			.doc(userId)
			.get()
		return userDoc.exists
			? userDoc.data().firstName || 'Пайдаланушы'
			: 'Пайдаланушы'
	})

	const names = await Promise.all(namesPromises)

	if (names.length === 0) return 'Чат'
	if (names.length === 1) return names[0]
	if (names.length === 2) return `${names[0]} & ${names[1]}`

	const othersCount = names.length - 2
	return `${names[0]}, ${names[1]} & ${othersCount} басқа`
}

async function updateChatLastMessage(chatId, lastMessage, lastType) {
	await admin.firestore().collection('chats').doc(chatId).update({
		lastMessage,
		lastTimestamp: admin.firestore.FieldValue.serverTimestamp(),
		lastType,
	})
}

async function updateChatLastMessageAndUnread(chatId, lastMessage, lastType) {
	const chatRef = admin.firestore().collection('chats').doc(chatId)
	await admin.firestore().runTransaction(async tx => {
		const chatDoc = await tx.get(chatRef)
		if (!chatDoc.exists) return

		const chatData = chatDoc.data()
		const activeUsers = chatData.activeUsers || {}
		const participants = chatData.participants || []

		let updateData = {
			lastMessage,
			lastTimestamp: admin.firestore.FieldValue.serverTimestamp(),
			lastType,
		}

		for (const userId of participants) {
			if (activeUsers[userId] === true) {
				updateData[`unreadCount.${userId}`] = 0
			} else {
				updateData[`unreadCount.${userId}`] =
					admin.firestore.FieldValue.increment(1)
			}
		}

		tx.update(chatRef, updateData)
	})
}

async function sendNotification(
	chatId,
	notification,
	excludeUserId = null,
	senderData = null
) {
	const chatDoc = await admin.firestore().collection('chats').doc(chatId).get()
	const chatData = chatDoc.data()
	const participants = chatData.participants || []

	for (const userId of participants) {
		// ✅ 1. Өзіне хабарлама жібермеу (Double notification fix)
		if (excludeUserId && userId === excludeUserId) {
			console.log(`🚫 Skipping notification for sender: ${userId}`)
			continue
		}

		const userDoc = await admin
			.firestore()
			.collection('users')
			.doc(userId)
			.get()
		if (!userDoc.exists) continue
		const userData = userDoc.data()

		if (userData.notificationsEnabled === false) continue

		if (Array.isArray(userData.fcmTokens) && userData.fcmTokens.length > 0) {
			const uniqueTokens = [...new Set(userData.fcmTokens)]

			// Көбінесе соңғы активті токенді қолданған дұрыс
			const lastToken = uniqueTokens.slice(-1)

			const translatedBody = translateNotificationBody(
				notification.body,
				userData.language
			)

			for (const token of lastToken) {
				try {
					await admin.messaging().send({
						token: token,
						notification: {
							title: notification.title,
							body: String(translatedBody || ''),
						},
						data: {
							title: notification.title,
							body: String(translatedBody || ''),
							userImage: senderData?.photoUrl || '',
							type: notification.type,
							chatId: chatId,
							otherUserId: String(participants.find(id => id !== userId) || ''),
							selectedSkills: String(chatData.lastSkill || ''),
						},
					})
				} catch (e) {
					console.error('❌ FCM ERROR:', e)
				}
			}
		}
	}
}
