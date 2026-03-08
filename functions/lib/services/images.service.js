"use strict";
/**
 * Images service: upload event photos and list event images.
 * Collection: events/{eventId}/images
 * Storage: events/{eventId}/images/{imageId}.jpg
 *
 * Supports both authenticated (app) and web (QR code) uploads.
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
exports.listImages = listImages;
exports.getImage = getImage;
exports.uploadImage = uploadImage;
exports.deleteImage = deleteImage;
const admin = __importStar(require("firebase-admin"));
const firestore_1 = require("../utils/firestore");
const now_1 = require("../utils/now");
const errors_1 = require("../models/errors");
const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10 MB
const ALLOWED_MIME_TYPES = ["image/jpeg", "image/png", "image/webp", "image/heic", "image/heif"];
const DEFAULT_LIMIT = 20;
const MAX_LIMIT = 100;
function toDto(doc) {
    var _a, _b, _c, _d, _e, _f, _g;
    const d = (_a = doc.data()) !== null && _a !== void 0 ? _a : {};
    const createdAt = d.createdAt;
    return {
        id: doc.id,
        eventId: (_b = d.eventId) !== null && _b !== void 0 ? _b : "",
        url: (_c = d.url) !== null && _c !== void 0 ? _c : "",
        thumbnailUrl: (_d = d.thumbnailUrl) !== null && _d !== void 0 ? _d : undefined,
        uploadedBy: (_e = d.uploadedBy) !== null && _e !== void 0 ? _e : "",
        uploaderName: (_f = d.uploaderName) !== null && _f !== void 0 ? _f : undefined,
        createdAt: (_g = (0, now_1.timestampToIso)(createdAt)) !== null && _g !== void 0 ? _g : new Date().toISOString(),
    };
}
/**
 * List images for an event, ordered by createdAt DESC.
 * Supports cursor-based pagination via `startAfter` (image ID).
 */
async function listImages(eventId, opts) {
    var _a;
    const eventSnap = await (0, firestore_1.eventRef)(eventId).get();
    if (!eventSnap.exists) {
        throw (0, errors_1.notFound)("Event not found");
    }
    const limit = Math.min((_a = opts === null || opts === void 0 ? void 0 : opts.limit) !== null && _a !== void 0 ? _a : DEFAULT_LIMIT, MAX_LIMIT);
    let query = (0, firestore_1.imagesRef)(eventId)
        .orderBy("createdAt", "desc")
        .limit(limit + 1); // fetch one extra to determine hasMore
    if (opts === null || opts === void 0 ? void 0 : opts.startAfter) {
        const cursorDoc = await (0, firestore_1.imagesRef)(eventId).doc(opts.startAfter).get();
        if (cursorDoc.exists) {
            query = (0, firestore_1.imagesRef)(eventId)
                .orderBy("createdAt", "desc")
                .startAfter(cursorDoc)
                .limit(limit + 1);
        }
    }
    const snap = await query.get();
    const docs = snap.docs;
    const hasMore = docs.length > limit;
    const images = docs.slice(0, limit).map((doc) => toDto(doc));
    return { images, hasMore };
}
/**
 * Get a single image by ID.
 */
async function getImage(eventId, imageId) {
    const doc = await (0, firestore_1.imagesRef)(eventId).doc(imageId).get();
    if (!doc.exists) {
        throw (0, errors_1.notFound)("Image not found");
    }
    return toDto(doc);
}
/**
 * Upload an image: save to Firebase Storage, write metadata to Firestore.
 * Accepts raw file buffer (from multipart upload or base64 decode).
 */
async function uploadImage(eventId, user, file) {
    var _a, _b;
    // Validate event exists
    const eventSnap = await (0, firestore_1.eventRef)(eventId).get();
    if (!eventSnap.exists) {
        throw (0, errors_1.notFound)("Event not found");
    }
    // Validate file
    if (!file.buffer || file.buffer.length === 0) {
        throw (0, errors_1.invalidArgument)("No file provided");
    }
    if (file.buffer.length > MAX_FILE_SIZE) {
        throw (0, errors_1.invalidArgument)(`File too large. Maximum size is ${MAX_FILE_SIZE / 1024 / 1024}MB`);
    }
    if (!ALLOWED_MIME_TYPES.includes(file.mimetype)) {
        throw (0, errors_1.invalidArgument)(`Invalid file type: ${file.mimetype}. Allowed: ${ALLOWED_MIME_TYPES.join(", ")}`);
    }
    // Generate image ID
    const imageDocRef = (0, firestore_1.imagesRef)(eventId).doc();
    const imageId = imageDocRef.id;
    // Determine file extension from mime type
    const ext = mimeToExt(file.mimetype);
    const storagePath = `events/${eventId}/images/${imageId}.${ext}`;
    try {
        // Upload to Firebase Storage
        const bucket = admin.storage().bucket();
        const fileRef = bucket.file(storagePath);
        await fileRef.save(file.buffer, {
            metadata: {
                contentType: file.mimetype,
                metadata: {
                    eventId,
                    uploadedBy: user.uid,
                    originalName: file.originalname,
                },
            },
        });
        // Make the file publicly readable
        await fileRef.makePublic();
        // Get the public URL
        const url = `https://storage.googleapis.com/${bucket.name}/${storagePath}`;
        // Write metadata to Firestore
        const imageData = {
            eventId,
            url,
            storagePath,
            uploadedBy: user.uid,
            uploaderName: (_a = user.name) !== null && _a !== void 0 ? _a : null,
            mimetype: file.mimetype,
            sizeBytes: file.buffer.length,
            createdAt: (0, now_1.serverTimestamp)(),
        };
        await imageDocRef.set(imageData);
        return {
            id: imageId,
            eventId,
            url,
            uploadedBy: user.uid,
            uploaderName: (_b = user.name) !== null && _b !== void 0 ? _b : undefined,
            createdAt: new Date().toISOString(),
        };
    }
    catch (err) {
        // Clean up storage if Firestore write failed
        try {
            const bucket = admin.storage().bucket();
            await bucket.file(storagePath).delete();
        }
        catch (_c) {
            // Ignore cleanup errors
        }
        if (err instanceof Error && err.name === "ApiError")
            throw err;
        throw (0, errors_1.internal)(`Failed to upload image: ${err instanceof Error ? err.message : "Unknown error"}`);
    }
}
/**
 * Delete an image (only the uploader or an admin can delete).
 */
async function deleteImage(eventId, imageId, userId) {
    var _a;
    const docRef = (0, firestore_1.imagesRef)(eventId).doc(imageId);
    const doc = await docRef.get();
    if (!doc.exists) {
        throw (0, errors_1.notFound)("Image not found");
    }
    const data = (_a = doc.data()) !== null && _a !== void 0 ? _a : {};
    if (data.uploadedBy !== userId) {
        // Only the uploader can delete their own image
        const { forbidden } = await Promise.resolve().then(() => __importStar(require("../models/errors")));
        throw forbidden("You can only delete your own images");
    }
    // Delete from Storage
    const storagePath = data.storagePath;
    if (storagePath) {
        try {
            const bucket = admin.storage().bucket();
            await bucket.file(storagePath).delete();
        }
        catch (_b) {
            // File may already be deleted; continue with Firestore cleanup
        }
    }
    // Delete Firestore document
    await docRef.delete();
}
function mimeToExt(mimetype) {
    switch (mimetype) {
        case "image/jpeg":
            return "jpg";
        case "image/png":
            return "png";
        case "image/webp":
            return "webp";
        case "image/heic":
        case "image/heif":
            return "heic";
        default:
            return "jpg";
    }
}
//# sourceMappingURL=images.service.js.map