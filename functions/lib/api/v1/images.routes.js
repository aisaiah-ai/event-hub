"use strict";
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
exports.list = list;
exports.listMine = listMine;
exports.listForReview = listForReview;
exports.getById = getById;
exports.upload = upload;
exports.updateStatus = updateStatus;
exports.bulkUpdateStatus = bulkUpdateStatus;
exports.remove = remove;
const errors_1 = require("../../models/errors");
const imagesService = __importStar(require("../../services/images.service"));
/** List approved images (public). */
function list(req, res) {
    const eventId = req.params.eventId;
    const limit = req.query.limit ? parseInt(req.query.limit, 10) : undefined;
    const startAfter = req.query.startAfter;
    imagesService
        .listImages(eventId, { limit, startAfter })
        .then((data) => res.json({ ok: true, data }))
        .catch((err) => sendError(res, err));
}
/** List my uploads (any status) — so uploaders can see their pending images. */
function listMine(req, res) {
    const eventId = req.params.eventId;
    const user = req.user;
    const limit = req.query.limit ? parseInt(req.query.limit, 10) : undefined;
    imagesService
        .listMyImages(eventId, user.uid, { limit })
        .then((images) => res.json({ ok: true, data: { images } }))
        .catch((err) => sendError(res, err));
}
/** List all images for admin review — optionally filter by status. */
function listForReview(req, res) {
    const eventId = req.params.eventId;
    const limit = req.query.limit ? parseInt(req.query.limit, 10) : undefined;
    const startAfter = req.query.startAfter;
    const status = req.query.status;
    imagesService
        .listAllImages(eventId, { limit, startAfter, status })
        .then((data) => res.json({ ok: true, data }))
        .catch((err) => sendError(res, err));
}
/** Get single image. */
function getById(req, res) {
    const eventId = req.params.eventId;
    const imageId = req.params.imageId;
    imagesService
        .getImage(eventId, imageId)
        .then((data) => res.json({ ok: true, data }))
        .catch((err) => sendError(res, err));
}
/** Upload image — status set to "pending". */
function upload(req, res) {
    const eventId = req.params.eventId;
    const user = req.user;
    parseUploadedFile(req)
        .then((file) => imagesService.uploadImage(eventId, user, file))
        .then((data) => res.status(201).json({ ok: true, data }))
        .catch((err) => sendError(res, err));
}
/** Approve or reject a single image. */
function updateStatus(req, res) {
    const eventId = req.params.eventId;
    const imageId = req.params.imageId;
    const user = req.user;
    const body = req.body;
    const status = body.status;
    if (!status || !["approved", "rejected"].includes(status)) {
        sendError(res, (0, errors_1.invalidArgument)("Status must be 'approved' or 'rejected'"));
        return;
    }
    imagesService
        .updateImageStatus(eventId, imageId, status, user.uid)
        .then((data) => res.json({ ok: true, data }))
        .catch((err) => sendError(res, err));
}
/** Bulk approve or reject images. */
function bulkUpdateStatus(req, res) {
    const eventId = req.params.eventId;
    const user = req.user;
    const body = req.body;
    const status = body.status;
    const imageIds = body.imageIds;
    if (!status || !["approved", "rejected"].includes(status)) {
        sendError(res, (0, errors_1.invalidArgument)("Status must be 'approved' or 'rejected'"));
        return;
    }
    if (!imageIds || !Array.isArray(imageIds) || imageIds.length === 0) {
        sendError(res, (0, errors_1.invalidArgument)("imageIds must be a non-empty array"));
        return;
    }
    imagesService
        .bulkUpdateImageStatus(eventId, imageIds, status, user.uid)
        .then((data) => res.json({ ok: true, data }))
        .catch((err) => sendError(res, err));
}
/** Delete image (owner only for regular users). */
function remove(req, res) {
    const eventId = req.params.eventId;
    const imageId = req.params.imageId;
    const user = req.user;
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
async function parseUploadedFile(req) {
    var _a;
    const contentType = (_a = req.headers["content-type"]) !== null && _a !== void 0 ? _a : "";
    // JSON body with base64 image
    if (contentType.includes("application/json")) {
        const body = req.body;
        const base64 = body.image;
        if (!base64) {
            throw (0, errors_1.invalidArgument)("Missing 'image' field in request body");
        }
        const mimetype = body.mimetype || "image/jpeg";
        const filename = body.filename || "photo.jpg";
        const buffer = Buffer.from(base64, "base64");
        return { buffer, mimetype, originalname: filename };
    }
    // Multipart form data
    if (contentType.includes("multipart/form-data")) {
        return parseMultipart(req);
    }
    throw (0, errors_1.invalidArgument)("Unsupported content type. Use multipart/form-data or application/json with base64");
}
/**
 * Parse multipart form data from Cloud Functions request.
 * Cloud Functions populates req.rawBody for HTTP functions.
 */
function parseMultipart(req) {
    return new Promise((resolve, reject) => {
        const Busboy = require("busboy");
        const busboy = Busboy({ headers: req.headers });
        let fileBuffer = null;
        let fileMimetype = "image/jpeg";
        let fileOriginalname = "photo.jpg";
        busboy.on("file", (_fieldname, file, info) => {
            const chunks = [];
            fileMimetype = info.mimeType;
            fileOriginalname = info.filename;
            file.on("data", (chunk) => chunks.push(chunk));
            file.on("end", () => {
                fileBuffer = Buffer.concat(chunks);
            });
        });
        busboy.on("finish", () => {
            if (!fileBuffer) {
                reject((0, errors_1.invalidArgument)("No image file found in multipart upload"));
                return;
            }
            resolve({ buffer: fileBuffer, mimetype: fileMimetype, originalname: fileOriginalname });
        });
        busboy.on("error", (err) => reject(err));
        // Cloud Functions provides rawBody for HTTP functions
        const rawBody = req.rawBody;
        if (rawBody) {
            busboy.end(rawBody);
        }
        else {
            req.pipe(busboy);
        }
    });
}
function sendError(res, err) {
    if (err instanceof errors_1.ApiError) {
        res.status(err.statusCode).json(err.toJson());
        return;
    }
    res.status(500).json({
        ok: false,
        error: { code: "internal", message: err instanceof Error ? err.message : "Internal error" },
    });
}
//# sourceMappingURL=images.routes.js.map