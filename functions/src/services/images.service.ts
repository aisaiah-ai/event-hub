/**
 * Images service: upload event photos and list event images.
 * Collection: events/{eventId}/images
 * Storage: events/{eventId}/images/{imageId}.jpg
 *
 * Approval workflow:
 *   - Uploaded images start with status "pending"
 *   - Public list only returns "approved" images
 *   - Admins can approve/reject via PATCH endpoint
 *   - Uploaders can see their own pending images
 *
 * Supports both authenticated (app) and web (QR code) uploads.
 */

import * as admin from "firebase-admin";
import { eventRef, imagesRef } from "../utils/firestore";
import { timestampToIso, serverTimestamp } from "../utils/now";
import { ImageDto, ImageStatus } from "../models/dto";
import { notFound, invalidArgument, forbidden, internal } from "../models/errors";

const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10 MB
const ALLOWED_MIME_TYPES = ["image/jpeg", "image/png", "image/webp", "image/heic", "image/heif"];
const DEFAULT_LIMIT = 20;
const MAX_LIMIT = 100;

function toDto(doc: admin.firestore.DocumentSnapshot): ImageDto {
  const d = doc.data() ?? {};
  const createdAt = d.createdAt as admin.firestore.Timestamp | undefined;
  return {
    id: doc.id,
    eventId: (d.eventId as string) ?? "",
    url: (d.url as string) ?? "",
    thumbnailUrl: (d.thumbnailUrl as string) ?? undefined,
    uploadedBy: (d.uploadedBy as string) ?? "",
    uploaderName: (d.uploaderName as string) ?? undefined,
    status: (d.status as ImageStatus) ?? "pending",
    createdAt: timestampToIso(createdAt) ?? new Date().toISOString(),
  };
}

/**
 * List approved images for an event, ordered by createdAt DESC.
 * Public endpoint — only returns images with status "approved".
 * Supports cursor-based pagination via `startAfter` (image ID).
 */
export async function listImages(
  eventId: string,
  opts?: { limit?: number; startAfter?: string }
): Promise<{ images: ImageDto[]; hasMore: boolean }> {
  const eventSnap = await eventRef(eventId).get();
  if (!eventSnap.exists) {
    throw notFound("Event not found");
  }

  const limit = Math.min(opts?.limit ?? DEFAULT_LIMIT, MAX_LIMIT);
  let query = imagesRef(eventId)
    .where("status", "==", "approved")
    .orderBy("createdAt", "desc")
    .limit(limit + 1);

  if (opts?.startAfter) {
    const cursorDoc = await imagesRef(eventId).doc(opts.startAfter).get();
    if (cursorDoc.exists) {
      query = imagesRef(eventId)
        .where("status", "==", "approved")
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
 * List all images for an event (any status) — for admin review.
 * Optionally filter by status.
 */
export async function listAllImages(
  eventId: string,
  opts?: { limit?: number; startAfter?: string; status?: ImageStatus }
): Promise<{ images: ImageDto[]; hasMore: boolean }> {
  const eventSnap = await eventRef(eventId).get();
  if (!eventSnap.exists) {
    throw notFound("Event not found");
  }

  const limit = Math.min(opts?.limit ?? DEFAULT_LIMIT, MAX_LIMIT);
  let baseQuery: admin.firestore.Query = imagesRef(eventId);

  if (opts?.status) {
    baseQuery = baseQuery.where("status", "==", opts.status);
  }

  let query = baseQuery.orderBy("createdAt", "desc").limit(limit + 1);

  if (opts?.startAfter) {
    const cursorDoc = await imagesRef(eventId).doc(opts.startAfter).get();
    if (cursorDoc.exists) {
      query = baseQuery
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
 * List images uploaded by a specific user (any status).
 * Lets uploaders see their own pending/rejected images.
 */
export async function listMyImages(
  eventId: string,
  userId: string,
  opts?: { limit?: number }
): Promise<ImageDto[]> {
  const limit = Math.min(opts?.limit ?? DEFAULT_LIMIT, MAX_LIMIT);
  const snap = await imagesRef(eventId)
    .where("uploadedBy", "==", userId)
    .orderBy("createdAt", "desc")
    .limit(limit)
    .get();

  return snap.docs.map((doc) => toDto(doc));
}

/**
 * Get a single image by ID.
 */
export async function getImage(eventId: string, imageId: string): Promise<ImageDto> {
  const doc = await imagesRef(eventId).doc(imageId).get();
  if (!doc.exists) {
    throw notFound("Image not found");
  }
  return toDto(doc);
}

/**
 * Upload an image: save to Firebase Storage, write metadata to Firestore.
 * Status is set to "pending" — requires admin approval before appearing publicly.
 */
export async function uploadImage(
  eventId: string,
  user: { uid: string; name?: string | null },
  file: { buffer: Buffer; mimetype: string; originalname: string }
): Promise<ImageDto> {
  // Validate event exists
  const eventSnap = await eventRef(eventId).get();
  if (!eventSnap.exists) {
    throw notFound("Event not found");
  }

  // Validate file
  if (!file.buffer || file.buffer.length === 0) {
    throw invalidArgument("No file provided");
  }
  if (file.buffer.length > MAX_FILE_SIZE) {
    throw invalidArgument(`File too large. Maximum size is ${MAX_FILE_SIZE / 1024 / 1024}MB`);
  }
  if (!ALLOWED_MIME_TYPES.includes(file.mimetype)) {
    throw invalidArgument(`Invalid file type: ${file.mimetype}. Allowed: ${ALLOWED_MIME_TYPES.join(", ")}`);
  }

  // Generate image ID
  const imageDocRef = imagesRef(eventId).doc();
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

    // Build a Firebase Storage download URL using the token-less public
    // format. This works because Firebase Storage rules allow read access.
    const encodedPath = encodeURIComponent(storagePath);
    const url = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodedPath}?alt=media`;

    // Write metadata to Firestore with pending status
    const imageData = {
      eventId,
      url,
      storagePath,
      uploadedBy: user.uid,
      uploaderName: user.name ?? null,
      mimetype: file.mimetype,
      sizeBytes: file.buffer.length,
      status: "pending" as ImageStatus,
      createdAt: serverTimestamp(),
    };

    await imageDocRef.set(imageData);

    return {
      id: imageId,
      eventId,
      url,
      uploadedBy: user.uid,
      uploaderName: user.name ?? undefined,
      status: "pending",
      createdAt: new Date().toISOString(),
    };
  } catch (err) {
    // Clean up storage if Firestore write failed
    try {
      const bucket = admin.storage().bucket();
      await bucket.file(storagePath).delete();
    } catch {
      // Ignore cleanup errors
    }
    if (err instanceof Error && err.name === "ApiError") throw err;
    throw internal(`Failed to upload image: ${err instanceof Error ? err.message : "Unknown error"}`);
  }
}

/**
 * Update image status (approve or reject).
 * Only event admins should call this (enforced at route level).
 */
export async function updateImageStatus(
  eventId: string,
  imageId: string,
  status: ImageStatus,
  reviewedBy: string
): Promise<ImageDto> {
  const docRef = imagesRef(eventId).doc(imageId);
  const doc = await docRef.get();
  if (!doc.exists) {
    throw notFound("Image not found");
  }

  await docRef.update({
    status,
    reviewedBy,
    reviewedAt: serverTimestamp(),
  });

  const updated = await docRef.get();
  return toDto(updated);
}

/**
 * Bulk approve/reject multiple images at once.
 */
export async function bulkUpdateImageStatus(
  eventId: string,
  imageIds: string[],
  status: ImageStatus,
  reviewedBy: string
): Promise<{ updated: number }> {
  if (imageIds.length === 0) {
    throw invalidArgument("No image IDs provided");
  }
  if (imageIds.length > 50) {
    throw invalidArgument("Maximum 50 images per bulk operation");
  }

  const batch = admin.firestore().batch();
  let count = 0;

  for (const imageId of imageIds) {
    const docRef = imagesRef(eventId).doc(imageId);
    const doc = await docRef.get();
    if (doc.exists) {
      batch.update(docRef, {
        status,
        reviewedBy,
        reviewedAt: serverTimestamp(),
      });
      count++;
    }
  }

  await batch.commit();
  return { updated: count };
}

/**
 * Delete an image (only the uploader can delete their own).
 */
export async function deleteImage(
  eventId: string,
  imageId: string,
  userId: string
): Promise<void> {
  const docRef = imagesRef(eventId).doc(imageId);
  const doc = await docRef.get();
  if (!doc.exists) {
    throw notFound("Image not found");
  }

  const data = doc.data() ?? {};
  if (data.uploadedBy !== userId) {
    throw forbidden("You can only delete your own images");
  }

  // Delete from Storage
  const storagePath = data.storagePath as string | undefined;
  if (storagePath) {
    try {
      const bucket = admin.storage().bucket();
      await bucket.file(storagePath).delete();
    } catch {
      // File may already be deleted; continue with Firestore cleanup
    }
  }

  // Delete Firestore document
  await docRef.delete();
}

/**
 * Admin delete — can remove any image regardless of uploader.
 */
export async function adminDeleteImage(
  eventId: string,
  imageId: string
): Promise<void> {
  const docRef = imagesRef(eventId).doc(imageId);
  const doc = await docRef.get();
  if (!doc.exists) {
    throw notFound("Image not found");
  }

  const data = doc.data() ?? {};
  const storagePath = data.storagePath as string | undefined;
  if (storagePath) {
    try {
      const bucket = admin.storage().bucket();
      await bucket.file(storagePath).delete();
    } catch {
      // Ignore
    }
  }

  await docRef.delete();
}

function mimeToExt(mimetype: string): string {
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
