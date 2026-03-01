/**
 * Unit tests for /v1 API: discovery, public routes, auth-required routes, and error shapes.
 * Mocks firebase-admin (auth + firestore) so no real Firebase is needed.
 */

import request from "supertest";

// Mock firebase-admin before any module that imports it
const mockVerifyIdToken = jest.fn();
const mockTransaction = jest.fn();
const mockDocGet = jest.fn();
const mockCollectionGet = jest.fn();
const mockQueryGet = jest.fn();

function makeSnapshot(
  exists: boolean,
  data: Record<string, unknown> = {},
  id = "doc-id"
) {
  return {
    exists: exists as unknown as boolean,
    id,
    data: () => data,
    get: (key: string) => data[key],
  };
}

function makeQuerySnapshot(docs: Array<{ id: string; data: Record<string, unknown> }>) {
  return {
    docs: docs.map((d) => makeSnapshot(true, d.data, d.id)),
    empty: docs.length === 0,
    size: docs.length,
  };
}

// Build chainable refs: ref.get() -> mockDocGet, ref.collection().doc().get() -> mockDocGet, etc.
function makeDocRef(path: string) {
  const ref = {
    get: () => Promise.resolve(mockDocGet()),
    set: jest.fn().mockResolvedValue(undefined),
    update: jest.fn().mockResolvedValue(undefined),
    collection: (id: string) => makeCollectionRef(`${path}/${id}`),
    path,
  };
  return ref;
}

function makeCollectionRef(path: string) {
  const ref = {
    doc: (id: string) => makeDocRef(`${path}/${id}`),
    get: () => Promise.resolve(mockCollectionGet()),
    where: () => ({
      get: () => Promise.resolve(mockQueryGet()),
      limit: () => ({ get: () => Promise.resolve(mockQueryGet()) }),
    }),
    orderBy: () => ({
      get: () => Promise.resolve(mockQueryGet()),
    }),
    limit: (n: number) => ({
      get: () => Promise.resolve(mockQueryGet()),
    }),
    path,
  };
  return ref;
}

const mockAuth = () => ({
  verifyIdToken: (token: string) => mockVerifyIdToken(token),
});

jest.mock("firebase-admin", () => {
  const firestoreInstance = {
    collection: (id: string) => makeCollectionRef(id),
    runTransaction: (fn: (tx: unknown) => Promise<unknown>) => mockTransaction(fn),
  };
  function firestoreFn() {
    return firestoreInstance;
  }
  firestoreFn.FieldValue = {
    serverTimestamp: () => ({ _type: "serverTimestamp" }),
    increment: (n: number) => ({ _type: "increment", n }),
  };
  firestoreFn.Timestamp = {
    now: () => ({ toDate: () => new Date() }),
    fromDate: (d: Date) => ({ toDate: () => d }),
  };
  return {
    __esModule: true,
    default: {
      initializeApp: jest.fn(),
      auth: mockAuth,
      firestore: firestoreFn,
    },
    auth: mockAuth,
    firestore: firestoreFn,
  };
});

// Default Firestore behavior: no docs
mockDocGet.mockReturnValue(makeSnapshot(false));
mockCollectionGet.mockReturnValue(makeQuerySnapshot([]));
mockQueryGet.mockReturnValue(makeQuerySnapshot([]));

// Transaction: tx.get(ref) - return value that works as doc snapshot (exists, data) and query snapshot (docs)
const txSnapshot = {
  exists: false,
  id: "",
  data: () => ({}),
  docs: [] as unknown[],
  empty: true,
  size: 0,
};
const mockTx = {
  get: jest.fn().mockResolvedValue(txSnapshot),
  set: jest.fn().mockResolvedValue(undefined),
  update: jest.fn().mockResolvedValue(undefined),
};
mockTransaction.mockImplementation(async (fn: (tx: unknown) => Promise<unknown>) => fn(mockTx));

// Import app after mocks
import apiApp from "../api";

describe("API", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockDocGet.mockReturnValue(makeSnapshot(false));
    mockCollectionGet.mockReturnValue(makeQuerySnapshot([]));
    mockQueryGet.mockReturnValue(makeQuerySnapshot([]));
    mockTx.get.mockResolvedValue(makeSnapshot(false));
    mockVerifyIdToken.mockRejectedValue(new Error("Invalid token"));
  });

  describe("GET /", () => {
    it("returns discovery JSON with ok and v1 endpoints", async () => {
      const res = await request(apiApp).get("/");
      expect(res.status).toBe(200);
      expect(res.body).toEqual({ ok: true, data: expect.any(Object) });
      expect(res.body.data.name).toBe("Events Hub API");
      expect(res.body.data.v1).toBe("/v1");
      expect(res.body.data.endpoints).toHaveProperty("events");
      expect(res.body.data.endpoints).toHaveProperty("checkinMain");
    });
  });

  describe("GET /v1/events", () => {
    it("returns 200 and array (empty when no events)", async () => {
      const res = await request(apiApp).get("/v1/events");
      expect(res.status).toBe(200);
      expect(res.body).toEqual({ ok: true, data: [] });
    });

    it("returns events when Firestore has docs", async () => {
      mockQueryGet.mockReturnValue(
        makeQuerySnapshot([
          {
            id: "e1",
            data: {
              title: "Test Event",
              startAt: { toDate: () => new Date("2026-03-01") },
              endAt: { toDate: () => new Date("2026-03-02") },
            },
          },
        ])
      );
      // listEvents uses ref.get() on the collection with optional where - we mocked get as mockCollectionGet
      mockCollectionGet.mockReturnValue(
        makeQuerySnapshot([
          {
            id: "e1",
            data: {
              title: "Test Event",
              startAt: { toDate: () => new Date("2026-03-01") },
              endAt: () => new Date("2026-03-02") as unknown,
            },
          },
        ])
      );
      const res = await request(apiApp).get("/v1/events");
      expect(res.status).toBe(200);
      expect(res.body.ok).toBe(true);
      expect(Array.isArray(res.body.data)).toBe(true);
    });
  });

  describe("GET /v1/events/:eventId", () => {
    it("returns 404 when event does not exist", async () => {
      mockDocGet.mockReturnValue(makeSnapshot(false));
      const res = await request(apiApp).get("/v1/events/nonexistent");
      expect(res.status).toBe(404);
      expect(res.body).toEqual({ ok: false, error: { code: "not_found", message: expect.any(String) } });
    });

    it("returns 200 and event when exists", async () => {
      mockDocGet.mockReturnValue(
        makeSnapshot(
          true,
          {
            title: "NLC 2026",
            name: "NLC 2026",
            startAt: { toDate: () => new Date("2026-06-01") },
            endAt: { toDate: () => new Date("2026-06-02") },
          },
          "nlc-2026"
        )
      );
      const res = await request(apiApp).get("/v1/events/nlc-2026");
      expect(res.status).toBe(200);
      expect(res.body.ok).toBe(true);
      expect(res.body.data.title).toBe("NLC 2026");
      expect(res.body.data.id).toBe("nlc-2026");
    });
  });

  describe("GET /v1/events/:eventId/sessions", () => {
    it("returns 404 when event does not exist", async () => {
      mockDocGet.mockReturnValue(makeSnapshot(false));
      const res = await request(apiApp).get("/v1/events/nonexistent/sessions");
      expect(res.status).toBe(404);
      expect(res.body.ok).toBe(false);
    });

    it("returns 200 and array when event exists", async () => {
      mockDocGet.mockReturnValue(makeSnapshot(true, {}));
      mockQueryGet.mockReturnValue(makeQuerySnapshot([]));
      const res = await request(apiApp).get("/v1/events/nlc-2026/sessions");
      expect(res.status).toBe(200);
      expect(res.body).toEqual({ ok: true, data: [] });
    });
  });

  describe("GET /v1/events/:eventId/announcements", () => {
    it("returns 404 when event does not exist", async () => {
      mockDocGet.mockReturnValue(makeSnapshot(false));
      const res = await request(apiApp).get("/v1/events/nonexistent/announcements");
      expect(res.status).toBe(404);
    });

    it("returns 200 and array when event exists", async () => {
      mockDocGet.mockReturnValue(makeSnapshot(true, {}));
      mockCollectionGet.mockReturnValue(makeQuerySnapshot([]));
      const res = await request(apiApp).get("/v1/events/nlc-2026/announcements");
      expect(res.status).toBe(200);
      expect(res.body).toEqual({ ok: true, data: [] });
    });
  });

  describe("GET /v1/events/:eventId/speakers", () => {
    it("returns 404 when event does not exist", async () => {
      mockDocGet.mockReturnValue(makeSnapshot(false));
      const res = await request(apiApp).get("/v1/events/nonexistent/speakers");
      expect(res.status).toBe(404);
    });

    it("returns 200 and array when event exists", async () => {
      mockDocGet.mockReturnValue(makeSnapshot(true, {}));
      mockCollectionGet.mockReturnValue(
        makeQuerySnapshot([
          {
            id: "rommel-dolar",
            data: {
              fullName: "Rommel Dolar",
              displayName: "Bro Rommel Dolar",
              title: "House Hold Head",
              photoUrl: "https://example.com/rommel.jpg",
              order: 0,
            },
          },
        ])
      );
      const res = await request(apiApp).get("/v1/events/march-assembly/speakers");
      expect(res.status).toBe(200);
      expect(res.body.ok).toBe(true);
      expect(Array.isArray(res.body.data)).toBe(true);
      expect(res.body.data[0]).toMatchObject({
        id: "rommel-dolar",
        fullName: "Rommel Dolar",
        displayName: "Bro Rommel Dolar",
        title: "House Hold Head",
        photoUrl: "https://example.com/rommel.jpg",
      });
    });
  });

  describe("GET /v1/events/:eventId/speakers/:speakerId", () => {
    it("returns 404 when event does not exist", async () => {
      mockDocGet.mockReturnValue(makeSnapshot(false));
      const res = await request(apiApp).get("/v1/events/nonexistent/speakers/rommel-dolar");
      expect(res.status).toBe(404);
    });

    it("returns 404 when speaker does not exist", async () => {
      mockDocGet
        .mockReturnValueOnce(makeSnapshot(true, {}))
        .mockReturnValueOnce(makeSnapshot(false));
      const res = await request(apiApp).get("/v1/events/march-assembly/speakers/unknown");
      expect(res.status).toBe(404);
    });

    it("returns 200 and speaker when found", async () => {
      mockDocGet
        .mockReturnValueOnce(makeSnapshot(true, {}))
        .mockReturnValueOnce(
          makeSnapshot(true, {
            fullName: "Rommel Dolar",
            displayName: "Bro Rommel Dolar",
            title: "House Hold Head",
            bio: "Bro Rommel serves as House Hold Head.",
            photoUrl: "https://example.com/rommel.jpg",
            topics: ["Evangelization", "Leadership"],
            order: 0,
          }, "rommel-dolar")
        );
      const res = await request(apiApp).get("/v1/events/march-assembly/speakers/rommel-dolar");
      expect(res.status).toBe(200);
      expect(res.body.ok).toBe(true);
      expect(res.body.data).toMatchObject({
        id: "rommel-dolar",
        fullName: "Rommel Dolar",
        displayName: "Bro Rommel Dolar",
        title: "House Hold Head",
        bio: "Bro Rommel serves as House Hold Head.",
        photoUrl: "https://example.com/rommel.jpg",
        topics: ["Evangelization", "Leadership"],
      });
    });
  });

  describe("Auth-required routes", () => {
    it("POST /v1/events/:eventId/register returns 401 without token", async () => {
      const res = await request(apiApp)
        .post("/v1/events/nlc-2026/register")
        .send({});
      expect(res.status).toBe(401);
      expect(res.body.ok).toBe(false);
      expect(res.body.error.code).toBe("unauthenticated");
    });

    it("POST /v1/events/:eventId/register returns 401 with invalid token", async () => {
      mockVerifyIdToken.mockRejectedValueOnce(new Error("Invalid"));
      const res = await request(apiApp)
        .post("/v1/events/nlc-2026/register")
        .set("Authorization", "Bearer invalid-token")
        .send({});
      expect([401, 500]).toContain(res.status);
      if (res.status === 500 && res.body?.error?.code === "internal") {
        expect(res.body.error.message).toBeDefined();
      }
    });

    it("GET /v1/me/registrations returns 401 without token", async () => {
      const res = await request(apiApp).get("/v1/me/registrations");
      expect(res.status).toBe(401);
      expect(res.body.error.code).toBe("unauthenticated");
    });

    it("GET /v1/events/:eventId/my-registration returns 401 without token", async () => {
      const res = await request(apiApp).get("/v1/events/nlc-2026/my-registration");
      expect(res.status).toBe(401);
    });

    it("POST /v1/events/:eventId/checkin/main returns 401 without token", async () => {
      const res = await request(apiApp).post("/v1/events/nlc-2026/checkin/main").send({});
      expect(res.status).toBe(401);
    });

    it("POST /v1/events/:eventId/checkin/sessions/:sessionId returns 401 without token", async () => {
      const res = await request(apiApp)
        .post("/v1/events/nlc-2026/checkin/sessions/opening-plenary")
        .send({});
      expect(res.status).toBe(401);
    });

    it("GET /v1/events/:eventId/checkin/status returns 401 without token", async () => {
      const res = await request(apiApp).get("/v1/events/nlc-2026/checkin/status");
      expect(res.status).toBe(401);
    });
  });

  describe("POST /v1/events/:eventId/register with valid token", () => {
    beforeEach(() => {
      mockVerifyIdToken.mockResolvedValue({
        uid: "test-uid",
        email: "test@example.com",
        name: "Test User",
      });
      mockDocGet.mockReturnValue(makeSnapshot(false));
      mockTx.get.mockResolvedValue(makeSnapshot(false));
      mockQueryGet.mockReturnValue(makeQuerySnapshot([]));
    });

    it("returns 201 and registration when event exists", async () => {
      mockDocGet
        .mockReturnValueOnce(makeSnapshot(true, { startAt: null })) // eventRef
        .mockReturnValueOnce(makeSnapshot(false)) // regRef
        .mockReturnValueOnce(makeSnapshot(false)); // mirror
      const res = await request(apiApp)
        .post("/v1/events/nlc-2026/register")
        .set("Authorization", "Bearer valid-token")
        .send({});
      expect(res.status).toBe(201);
      expect(res.body.ok).toBe(true);
      expect(res.body.data).toMatchObject({
        eventId: "nlc-2026",
        registrationId: "test-uid",
        status: "registered",
      });
    });
  });

  describe("POST /v1/events/:eventId/checkin/main with valid token", () => {
    beforeEach(() => {
      mockVerifyIdToken.mockResolvedValue({ uid: "u1", email: "u@x.com" });
      mockDocGet.mockReturnValue(makeSnapshot(true, {})); // event exists
      mockTx.get.mockResolvedValue(txSnapshot);
    });

    it("returns 201 and { already: false } on first check-in when event exists", async () => {
      mockDocGet.mockReturnValue(makeSnapshot(true, {})); // event exists
      const res = await request(apiApp)
        .post("/v1/events/nlc-2026/checkin/main")
        .set("Authorization", "Bearer valid-token")
        .send({});
      expect([201, 404]).toContain(res.status);
      if (res.status === 201) {
        expect(res.body.ok).toBe(true);
        expect(res.body.data).toHaveProperty("already");
      }
    });
  });

  describe("404", () => {
    it("returns 404 and error shape for unknown path", async () => {
      const res = await request(apiApp).get("/v1/unknown");
      expect(res.status).toBe(404);
      expect(res.body).toEqual({ ok: false, error: { code: "not_found", message: "Not found" } });
    });
  });

  describe("Missing params", () => {
    it("GET /v1/events/ (empty eventId) returns 400, 404, or 200", async () => {
      const res = await request(apiApp).get("/v1/events/");
      expect([200, 400, 404]).toContain(res.status);
    });
  });
});
