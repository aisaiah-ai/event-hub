import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const db = admin.firestore();
const FUNCTION_SERVICE_ACCOUNT = "aisaiah-event-hub@appspot.gserviceaccount.com";

export const onSessionCheckIn = functions
  .runWith({serviceAccount: FUNCTION_SERVICE_ACCOUNT})
  .firestore
  .document("events/{eventId}/sessions/{sessionId}/attendance/{registrantId}")
  .onCreate(async (_snap, context) => {
    const { eventId, sessionId } = context.params;

    const sessionRef = db
      .collection("events")
      .doc(eventId)
      .collection("sessions")
      .doc(sessionId);

    const analyticsRef = db
      .collection("events")
      .doc(eventId)
      .collection("analytics")
      .doc("summary");

    await sessionRef.set(
      {
        checkInCount: admin.firestore.FieldValue.increment(1),
      },
      { merge: true },
    );

    await analyticsRef.set(
      {
        totalCheckIns: admin.firestore.FieldValue.increment(1),
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    return null;
  });
