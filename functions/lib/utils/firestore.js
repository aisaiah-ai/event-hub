"use strict";
/**
 * Firestore instance and path helpers.
 * Uses the default Firestore database.
 * Schema: events, events/{eventId}/sessions, events/{eventId}/registrants,
 * events/{eventId}/sessions/{sessionId}/attendance, events/{eventId}/announcements.
 */
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.getDb = getDb;
exports.eventsRef = eventsRef;
exports.eventRef = eventRef;
exports.sessionsRef = sessionsRef;
exports.sessionRef = sessionRef;
exports.registrantsRef = registrantsRef;
exports.registrantRef = registrantRef;
exports.attendanceRef = attendanceRef;
exports.attendanceDocRef = attendanceDocRef;
exports.announcementsRef = announcementsRef;
exports.userRegistrationsRef = userRegistrationsRef;
exports.userRegistrationRef = userRegistrationRef;
const admin = __importStar(require("firebase-admin"));
function getDb() {
    return admin.firestore();
}
function eventsRef() {
    return getDb().collection("events");
}
function eventRef(eventId) {
    return eventsRef().doc(eventId);
}
function sessionsRef(eventId) {
    return eventRef(eventId).collection("sessions");
}
function sessionRef(eventId, sessionId) {
    return sessionsRef(eventId).doc(sessionId);
}
function registrantsRef(eventId) {
    return eventRef(eventId).collection("registrants");
}
function registrantRef(eventId, registrantId) {
    return registrantsRef(eventId).doc(registrantId);
}
function attendanceRef(eventId, sessionId) {
    return sessionRef(eventId, sessionId).collection("attendance");
}
function attendanceDocRef(eventId, sessionId, registrantId) {
    return attendanceRef(eventId, sessionId).doc(registrantId);
}
function announcementsRef(eventId) {
    return eventRef(eventId).collection("announcements");
}
/** Mirror for fast "my registrations": users/{uid}/registrations/{eventId} */
function userRegistrationsRef(uid) {
    return getDb().collection("users").doc(uid).collection("registrations");
}
function userRegistrationRef(uid, eventId) {
    return userRegistrationsRef(uid).doc(eventId);
}
//# sourceMappingURL=firestore.js.map