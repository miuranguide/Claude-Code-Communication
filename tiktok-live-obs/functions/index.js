const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Reset a user's password to their loginId (default password).
 * Only callable by admin users.
 */
exports.resetPassword = functions.https.onCall(async (data, context) => {
  // Verify caller is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "ログインが必要です"
    );
  }

  // Verify caller is admin
  const callerDoc = await admin
    .firestore()
    .collection("users")
    .doc(context.auth.uid)
    .get();

  if (!callerDoc.exists || callerDoc.data().role !== "admin") {
    throw new functions.https.HttpsError(
      "permission-denied",
      "管理者権限が必要です"
    );
  }

  const { uid, loginId } = data;
  if (!uid || !loginId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "UIDとログインIDが必要です"
    );
  }

  try {
    // Reset password to loginId (default password)
    await admin.auth().updateUser(uid, { password: loginId });

    // Log the action
    await admin.firestore().collection("logs").add({
      action: "password_reset",
      actorUid: context.auth.uid,
      targetUid: uid,
      detail: `Password reset for ${loginId}`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true };
  } catch (error) {
    throw new functions.https.HttpsError(
      "internal",
      `パスワードリセットに失敗しました: ${error.message}`
    );
  }
});
