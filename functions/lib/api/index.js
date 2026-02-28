"use strict";
/**
 * Express app for /v1 API. Mount at root so Cloud Function URL is .../api and /v1/... routes apply.
 */
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const routes_1 = __importDefault(require("./v1/routes"));
const app = (0, express_1.default)();
app.use(express_1.default.json());
// Health / discovery
app.get("/", (_req, res) => {
    res.json({
        ok: true,
        data: {
            name: "Events Hub API",
            version: "1",
            v1: "/v1",
            endpoints: {
                events: "GET /v1/events, GET /v1/events/:eventId",
                sessions: "GET /v1/events/:eventId/sessions",
                announcements: "GET /v1/events/:eventId/announcements",
                register: "POST /v1/events/:eventId/register",
                myRegistrations: "GET /v1/me/registrations",
                myRegistration: "GET /v1/events/:eventId/my-registration",
                checkinMain: "POST /v1/events/:eventId/checkin/main",
                checkinSession: "POST /v1/events/:eventId/checkin/sessions/:sessionId",
                checkinStatus: "GET /v1/events/:eventId/checkin/status",
            },
        },
    });
});
app.use("/v1", routes_1.default);
// 404
app.use((_req, res) => {
    res.status(404).json({ ok: false, error: { code: "not_found", message: "Not found" } });
});
exports.default = app;
//# sourceMappingURL=index.js.map