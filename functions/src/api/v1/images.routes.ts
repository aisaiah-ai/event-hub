/**
 * Image routes:
 *   GET    /v1/events/:eventId/images              — list approved images (public)
 *   GET    /v1/events/:eventId/images/mine          — list my uploads, any status (auth)
 *   GET    /v1/events/:eventId/images/review         — list all images for admin review (auth)
 *   GET    /v1/events/:eventId/images/:imageId       — get single image (public)
 *   POST   /v1/events/:eventId/images               — upload image, status=pending (auth)
 *   PATCH  /v1/events/:eventId/images/:imageId       — approve/reject (auth, admin)
 *   PATCH  /v1/events/:eventId/images/bulk-status     — bulk approve/reject (auth, admin)
 *   DELETE /v1/events/:eventId/images/:imageId       — delete image (auth, owner or admin)
 *
 * Upload accepts:
 *   - multipart/form-data with field "image" (for web/QR uploads)
 *   - application/json with base64-encoded "image" field (for app uploads)
 */

import { Request, Response } from "express";
import { RequestUser, ImageStatus } from "../../models/dto";
import { ApiError, invalidArgument } from "../../models/errors";
import * as imagesService from "../../services/images.service";

/** List approved images (public). */
export function list(req: Request, res: Response): void {
  const eventId = req.params.eventId as string;
  const limit = req.query.limit ? parseInt(req.query.limit as string, 10) : undefined;
  const startAfter = req.query.startAfter as string | undefined;

  imagesService
    .listImages(eventId, { limit, startAfter })
    .then((data) => res.json({ ok: true, data }))
    .catch((err) => sendError(res, err));
}

/** List my uploads (any status) — so uploaders can see their pending images. */
export function listMine(req: Request, res: Response): void {
  const eventId = req.params.eventId as string;
  const user = (req as Request & { user: RequestUser }).user;
  const limit = req.query.limit ? parseInt(req.query.limit as string, 10) : undefined;

  imagesService
    .listMyImages(eventId, user.uid, { limit })
    .then((images) => res.json({ ok: true, data: { images } }))
    .catch((err) => sendError(res, err));
}

/** List all images for admin review — optionally filter by status. */
export function listForReview(req: Request, res: Response): void {
  const eventId = req.params.eventId as string;
  const limit = req.query.limit ? parseInt(req.query.limit as string, 10) : undefined;
  const startAfter = req.query.startAfter as string | undefined;
  const status = req.query.status as ImageStatus | undefined;

  imagesService
    .listAllImages(eventId, { limit, startAfter, status })
    .then((data) => res.json({ ok: true, data }))
    .catch((err) => sendError(res, err));
}

/** Get single image. */
export function getById(req: Request, res: Response): void {
  const eventId = req.params.eventId as string;
  const imageId = req.params.imageId as string;

  imagesService
    .getImage(eventId, imageId)
    .then((data) => res.json({ ok: true, data }))
    .catch((err) => sendError(res, err));
}

/** Upload image — status set to "pending". */
export function upload(req: Request, res: Response): void {
  const eventId = req.params.eventId as string;
  const user = (req as Request & { user: RequestUser }).user;

  parseUploadedFile(req)
    .then((file) => imagesService.uploadImage(eventId, user, file))
    .then((data) => res.status(201).json({ ok: true, data }))
    .catch((err) => sendError(res, err));
}

/** Approve or reject a single image. */
export function updateStatus(req: Request, res: Response): void {
  const eventId = req.params.eventId as string;
  const imageId = req.params.imageId as string;
  const user = (req as Request & { user: RequestUser }).user;
  const body = req.body as Record<string, unknown>;
  const status = body.status as ImageStatus | undefined;

  if (!status || !["approved", "rejected"].includes(status)) {
    sendError(res, invalidArgument("Status must be 'approved' or 'rejected'"));
    return;
  }

  imagesService
    .updateImageStatus(eventId, imageId, status, user.uid)
    .then((data) => res.json({ ok: true, data }))
    .catch((err) => sendError(res, err));
}

/** Bulk approve or reject images. */
export function bulkUpdateStatus(req: Request, res: Response): void {
  const eventId = req.params.eventId as string;
  const user = (req as Request & { user: RequestUser }).user;
  const body = req.body as Record<string, unknown>;
  const status = body.status as ImageStatus | undefined;
  const imageIds = body.imageIds as string[] | undefined;

  if (!status || !["approved", "rejected"].includes(status)) {
    sendError(res, invalidArgument("Status must be 'approved' or 'rejected'"));
    return;
  }
  if (!imageIds || !Array.isArray(imageIds) || imageIds.length === 0) {
    sendError(res, invalidArgument("imageIds must be a non-empty array"));
    return;
  }

  imagesService
    .bulkUpdateImageStatus(eventId, imageIds, status, user.uid)
    .then((data) => res.json({ ok: true, data }))
    .catch((err) => sendError(res, err));
}

/** Delete image (owner only for regular users). */
export function remove(req: Request, res: Response): void {
  const eventId = req.params.eventId as string;
  const imageId = req.params.imageId as string;
  const user = (req as Request & { user: RequestUser }).user;

  imagesService
    .deleteImage(eventId, imageId, user.uid)
    .then(() => res.json({ ok: true, data: { deleted: true } }))
    .catch((err) => sendError(res, err));
}

/**
 * Parse the uploaded file from the request.
 *
 * Supports:
 *   - multipart/form-data with file field (for web/QR uploads)
 *   - application/json with base64 "image" field (for app uploads)
 */
async function parseUploadedFile(
  req: Request
): Promise<{ buffer: Buffer; mimetype: string; originalname: string }> {
  const contentType = req.headers["content-type"] ?? "";

  // JSON body with base64 image
  if (contentType.includes("application/json")) {
    const body = req.body as Record<string, unknown>;
    const base64 = body.image as string | undefined;
    if (!base64) {
      throw invalidArgument("Missing 'image' field in request body");
    }
    const mimetype = (body.mimetype as string) || "image/jpeg";
    const filename = (body.filename as string) || "photo.jpg";
    const buffer = Buffer.from(base64, "base64");
    return { buffer, mimetype, originalname: filename };
  }

  // Multipart form data
  if (contentType.includes("multipart/form-data")) {
    return parseMultipart(req);
  }

  throw invalidArgument("Unsupported content type. Use multipart/form-data or application/json with base64");
}

/**
 * Parse multipart form data from Cloud Functions request.
 * Cloud Functions populates req.rawBody for HTTP functions.
 */
function parseMultipart(
  req: Request
): Promise<{ buffer: Buffer; mimetype: string; originalname: string }> {
  return new Promise((resolve, reject) => {
    const Busboy = require("busboy");
    const busboy = Busboy({ headers: req.headers });

    let fileBuffer: Buffer | null = null;
    let fileMimetype = "image/jpeg";
    let fileOriginalname = "photo.jpg";

    busboy.on(
      "file",
      (
        _fieldname: string,
        file: NodeJS.ReadableStream,
        info: { filename: string; encoding: string; mimeType: string }
      ) => {
        const chunks: Buffer[] = [];
        fileMimetype = info.mimeType;
        fileOriginalname = info.filename;

        file.on("data", (chunk: Buffer) => chunks.push(chunk));
        file.on("end", () => {
          fileBuffer = Buffer.concat(chunks);
        });
      }
    );

    busboy.on("finish", () => {
      if (!fileBuffer) {
        reject(invalidArgument("No image file found in multipart upload"));
        return;
      }
      resolve({ buffer: fileBuffer, mimetype: fileMimetype, originalname: fileOriginalname });
    });

    busboy.on("error", (err: Error) => reject(err));

    // Cloud Functions provides rawBody for HTTP functions
    const rawBody = (req as Request & { rawBody?: Buffer }).rawBody;
    if (rawBody) {
      busboy.end(rawBody);
    } else {
      req.pipe(busboy);
    }
  });
}

function sendError(res: Response, err: unknown): void {
  if (err instanceof ApiError) {
    res.status(err.statusCode).json(err.toJson());
    return;
  }
  res.status(500).json({
    ok: false,
    error: { code: "internal", message: err instanceof Error ? err.message : "Internal error" },
  });
}
