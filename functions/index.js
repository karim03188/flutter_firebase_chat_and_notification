const { onValueCreated } = require("firebase-functions/v2/database");
const { initializeApp } = require("firebase-admin/app");
const { getDatabase } = require("firebase-admin/database");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

// Triggers when a new message is created under /room1/{messageId}
exports.sendMessageNotification = onValueCreated(
  {
    ref: "/room1/{messageId}",
    instance: "chat-app-a746d-default-rtdb",
  },
  async (event) => {
    const messageData = event.data.val();
    if (!messageData) return;

    const sender = messageData.sender || "Unknown";
    const text = messageData.text || "";

    // Get all saved FCM tokens
    const tokensSnapshot = await getDatabase()
      .ref("fcm_tokens")
      .once("value");

    if (!tokensSnapshot.exists()) return;

    const tokensData = tokensSnapshot.val();
    const tokens = [];
    const tokenUserMap = {};

    // Collect all tokens except the sender's
    for (const [uid, data] of Object.entries(tokensData)) {
      if (data.email !== sender && data.token) {
        tokens.push(data.token);
        tokenUserMap[data.token] = uid;
      }
    }

    if (tokens.length === 0) return;

    // Send FCM to all other users
    const message = {
      notification: {
        title: sender,
        body: text,
      },
      data: {
        sender: sender,
        text: text,
        chatRoom: "room1",
      },
      android: {
        notification: {
          channelId: "chat_messages",
          priority: "high",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    try {
      const response = await getMessaging().sendEachForMulticast({
        ...message,
        tokens: tokens,
      });

      // Clean up invalid tokens
      const failedTokens = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          failedTokens.push(tokens[idx]);
        }
      });

      // Remove invalid tokens from database
      if (failedTokens.length > 0) {
        const updates = {};
        for (const token of failedTokens) {
          const uid = tokenUserMap[token];
          if (uid) {
            updates[`fcm_tokens/${uid}`] = null;
          }
        }
        await getDatabase().ref().update(updates);
      }
    } catch (error) {
      // Error sending notification
    }
  }
);
