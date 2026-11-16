const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {getFirestore} = require("firebase-admin/firestore");
const logger = require("firebase-functions/logger");

/**
 * Reads only the verified caller's quest state.
 * No write operations or reward calls are available here.
 *
 * @param {string} verifiedUid UID from callable authentication.
 * @return {Promise<object>} The caller's quest state.
 */
async function readMyQuestState(verifiedUid) {
  const db = getFirestore();

  const challengeRef = db.doc("challenges/today");
  const progressRef = db.doc(
      `users/${verifiedUid}/progress/today`,
  );

  const [challenge, progress] = await db.getAll(
      challengeRef,
      progressRef,
  );

  if (!challenge.exists) {
    throw new HttpsError(
        "not-found",
        "Today's challenge is unavailable.",
    );
  }

  const challengeData = challenge.data();

  if (
    typeof challengeData.title !== "string" ||
    typeof challengeData.prompt !== "string"
  ) {
    throw new HttpsError(
        "failed-precondition",
        "The challenge is incomplete.",
    );
  }

  const progressData = progress.exists ? progress.data() : {};

  logger.info("readMyQuestState completed", {
    challengePath: challengeRef.path,
    progressPath: progressRef.path,
    readOnly: true,
  });

  return {
    title: challengeData.title,
    prompt: challengeData.prompt,
    completed: progressData.completed === true,
    points: progressData.points ?? 0,
    badgeId: progressData.badgeId ?? null,
  };
}

exports.askQuestCoach = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError(
        "unauthenticated",
        "Sign in before asking the coach.",
    );
  }

  const data = request.data;

  if (
    !data ||
    typeof data !== "object" ||
    Array.isArray(data) ||
    Object.keys(data).some((key) => key !== "question") ||
    typeof data.question !== "string"
  ) {
    throw new HttpsError(
        "invalid-argument",
        "Send only a question.",
    );
  }

  const question = data.question.trim();

  if (question.length === 0 || question.length > 300) {
    throw new HttpsError(
        "invalid-argument",
        "Enter a question between 1 and 300 characters.",
    );
  }

  // No model gateway has been supplied.
  // Never silently use a mock outside the local Functions emulator.
  if (process.env.FUNCTIONS_EMULATOR !== "true") {
    throw new HttpsError(
        "failed-precondition",
        "The course model gateway has not been configured.",
    );
  }

  // Every successful reply first reads the verified caller's state.
  const state = await readMyQuestState(request.auth.uid);

  // Explicit local failure case for testing the Flutter fallback.
  if (question === "__simulate_model_failure__") {
    throw new HttpsError(
        "unavailable",
        "Simulated local model failure.",
    );
  }

  const status = state.completed ?
    `Your quest is completed with ${state.points} points.` :
    "Your quest is not completed yet.";

  const reply = [
    "[LOCAL MOCK: no AI model connected]",
    `Quest: ${state.title}.`,
    `Prompt: ${state.prompt}`,
    status,
    "Hint: compare proving who someone is with deciding what",
    "that person is allowed to do.",
    "I cannot disclose another learner's data or change rewards.",
    "Only your separate Complete challenge action requests a reward.",
  ].join(" ");

  return {
    reply,
    mode: "local-mock",
    tool: "readMyQuestState",
  };
});
