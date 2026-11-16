const {setGlobalOptions} = require("firebase-functions/v2");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");

initializeApp();

setGlobalOptions({
  region: "us-central1",
  maxInstances: 5,
});

const db = getFirestore();

exports.completeToday = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError(
        "unauthenticated",
        "Sign in before completing the challenge.",
    );
  }

  const data = request.data;

  if (
    !data ||
    typeof data !== "object" ||
    Array.isArray(data) ||
    data.challengeId !== "today" ||
    Object.keys(data).some((key) => key !== "challengeId")
  ) {
    throw new HttpsError(
        "invalid-argument",
        "Send only challengeId with the value today.",
    );
  }

  const uid = request.auth.uid;
  const challengeRef = db.doc("challenges/today");
  const progressRef = db.doc(`users/${uid}/progress/today`);

  return db.runTransaction(async (transaction) => {
    const challenge = await transaction.get(challengeRef);
    const progress = await transaction.get(progressRef);

    if (!challenge.exists) {
      throw new HttpsError(
          "not-found",
          "Today's challenge is not available.",
      );
    }

    if (progress.exists) {
      const saved = progress.data();

      if (
        saved.completed !== true ||
        saved.points !== 10 ||
        saved.badgeId !== "first-quest"
      ) {
        throw new HttpsError(
            "failed-precondition",
            "The saved progress needs an administrator check.",
        );
      }

      return {
        completed: true,
        points: saved.points,
        badgeId: saved.badgeId,
        alreadyCompleted: true,
      };
    }

    transaction.set(progressRef, {
      completed: true,
      points: 10,
      badgeId: "first-quest",
      completedAt: FieldValue.serverTimestamp(),
    });

    return {
      completed: true,
      points: 10,
      badgeId: "first-quest",
      alreadyCompleted: false,
    };
  });
});
exports.askQuestCoach = require("./questCoach").askQuestCoach;
