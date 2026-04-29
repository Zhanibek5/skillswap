const { onSchedule } = require('firebase-functions/v2/scheduler')
const { onDocumentCreated } = require('firebase-functions/v2/firestore')
const admin = require('firebase-admin')

admin.initializeApp()

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

		let finalTitle = senderName;
		if (chatData.chatType === 'contract' && chatData.lastSkill) {
			if (chatData.teacherId === senderId) {
				finalTitle = `📚 Учит ${chatData.lastSkill}: ${senderName}`;
			} else if (chatData.learnerId === senderId) {
				finalTitle = `🎓 Изучает ${chatData.lastSkill}: ${senderName}`;
			}
		} else if (chatData.lastSkill) {
			finalTitle = `${senderName} • ${chatData.lastSkill}`;
		}

		await sendToUser(recipientId, chatId, {
			title: finalTitle,
			body: 'Кездесу жоспарланды',
			type: 'meeting',
			senderData: senderData,
			chatData: chatData,
		})
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
				bodyText = '🎤 Дауыстық хабарлама'
				break
			case 'image':
				bodyText = '📷 Сурет жіберілді'
				break
			default:
				bodyText = 'Жаңа хабарлама'
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
				let finalTitle = senderName;
				if (chatData.chatType === 'contract' && chatData.lastSkill) {
					if (chatData.teacherId === senderId) {
						finalTitle = `📚 Учит ${chatData.lastSkill}: ${senderName}`;
					} else if (chatData.learnerId === senderId) {
						finalTitle = `🎓 Изучает ${chatData.lastSkill}: ${senderName}`;
					}
				} else if (chatData.lastSkill) {
					finalTitle = `${senderName} • ${chatData.lastSkill}`;
				}

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

				const meetingTime = meetingData.meetingTime.toDate().getTime()
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
							meetingTime: meetingData.meetingTime,
							duration: meetingData.duration || 60,
							timestamp: admin.firestore.FieldValue.serverTimestamp(),
							readBy: [],
						})
						await updateChatLastMessage(
							chatId,
							'⏰ Кездесуге 10 минут қалды',
							'system_meeting_10min'
						)

						for (const userId of participants) {
							const otherUserId = participants.find(id => id !== userId) || userId
							const otherUserDoc = await admin.firestore().collection('users').doc(otherUserId).get()
							const otherUserName = otherUserDoc.exists ? otherUserDoc.data().firstName || 'Пайдаланушы' : 'Пайдаланушы'
							const otherUserData = otherUserDoc.exists ? otherUserDoc.data() : null

							let finalTitle = `⏰ ${otherUserName}`;
							if (chatData.chatType === 'contract' && chatData.lastSkill) {
								if (chatData.teacherId === otherUserId) {
									finalTitle = `📚 Учит ${chatData.lastSkill}: ${otherUserName}`;
								} else if (chatData.learnerId === otherUserId) {
									finalTitle = `🎓 Изучает ${chatData.lastSkill}: ${otherUserName}`;
								}
							} else if (chatData.lastSkill) {
								finalTitle = `⏰ ${otherUserName} • ${chatData.lastSkill}`;
							}

							await sendToUser(userId, chatId, {
								title: finalTitle,
								body: 'Кездесу басталуына аз қалды',
								type: 'meeting',
								senderData: otherUserData,
								chatData: chatData
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
							meetingTime: meetingData.meetingTime,
							duration: meetingData.duration || 60,
							timestamp: admin.firestore.FieldValue.serverTimestamp(),
							readBy: [],
						})
						await updateChatLastMessage(
							chatId,
							'🔔 Кездесу басталды',
							'system_meeting_started'
						)

						for (const userId of participants) {
							const otherUserId = participants.find(id => id !== userId) || userId
							const otherUserDoc = await admin.firestore().collection('users').doc(otherUserId).get()
							const otherUserName = otherUserDoc.exists ? otherUserDoc.data().firstName || 'Пайдаланушы' : 'Пайдаланушы'
							const otherUserData = otherUserDoc.exists ? otherUserDoc.data() : null

							let finalTitle = `🔔 ${otherUserName}`;
							if (chatData.chatType === 'contract' && chatData.lastSkill) {
								if (chatData.teacherId === otherUserId) {
									finalTitle = `📚 Учит ${chatData.lastSkill}: ${otherUserName}`;
								} else if (chatData.learnerId === otherUserId) {
									finalTitle = `🎓 Изучает ${chatData.lastSkill}: ${otherUserName}`;
								}
							} else if (chatData.lastSkill) {
								finalTitle = `🔔 ${otherUserName} • ${chatData.lastSkill}`;
							}

							await sendToUser(userId, chatId, {
								title: finalTitle,
								body: 'Кездесу уақыты келді!',
								type: 'meeting',
								senderData: otherUserData,
								chatData: chatData
							})
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
	if (userData.notificationsEnabled === false || !userData.fcmTokens) return

	// Дубликат болмас үшін соңғы активті токенді ғана аламыз
	const token = userData.fcmTokens[userData.fcmTokens.length - 1]

	try {
		await admin.messaging().send({
			token: token,
			notification: {
				title: payload.title,
				body: payload.body,
			},
			data: {
				title: payload.title,
				body: payload.body,
				userImage: payload.senderData?.photoUrl || '',
				type: payload.type,
				chatId: chatId,
				otherUserId: String(
					payload.chatData.participants.find(id => id !== userId) || ''
				),
				selectedSkills: JSON.stringify(payload.chatData.selectedSkills || []),
			},
		})
	} catch (e) {
		console.error('FCM Error:', e)
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

			for (const token of lastToken) {
				try {
					await admin.messaging().send({
						token: token,
						notification: {
							title: notification.title,
							body: notification.body,
						},
						data: {
							title: notification.title,
							body: notification.body,
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
