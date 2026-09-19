import { beforeEach, describe, expect, it, vi } from "vitest";
import { checkRateLimit } from "@vercel/firewall";

import {
  FIXED_MODEL,
  MAX_BODY_BYTES,
  PROMPT_VERSION,
  RATE_LIMIT_RULE_ID,
  SCHEMA_VERSION,
  VercelGatewayJevProvider,
  createVeryHardHandler,
  type JevChoiceInput,
  type JevProvider,
} from "../api/v1/cpu/very-hard.js";

const aiSdkMocks = vi.hoisted(() => ({
  evaluate: vi.fn(),
  generateObject: vi.fn(),
}));
const gatewayMocks = vi.hoisted(() => ({
  evaluationModel: vi.fn(),
  legacyModel: vi.fn(),
}));

vi.mock("ai", () => ({
  experimental_evaluate: aiSdkMocks.evaluate,
  generateObject: aiSdkMocks.generateObject,
}));
vi.mock("@ai-sdk/gateway", () => ({
  gateway: Object.assign(gatewayMocks.legacyModel, {
    evaluationModel: gatewayMocks.evaluationModel,
  }),
}));

vi.mock("@vercel/firewall", () => ({
  checkRateLimit: vi.fn(async () => ({ rateLimited: false })),
}));

const board = {
  elapsedMs: 1_500,
  islands: [
    {
      id: 0,
      x: -0.8,
      y: 0.2,
      size: "headquarters",
      faction: "cpu",
      currentForces: 20,
      durability: 0,
      capacity: 30,
    },
    {
      id: 1,
      x: 0.8,
      y: 0.6,
      size: "small",
      faction: "player",
      currentForces: 8,
      durability: 0,
      capacity: 30,
    },
  ],
  movingForces: [],
} as const;

const subject = {
  faction: "cpu",
  candidates: [
    {
      id: "cpu-c0",
      action: "dispatch",
      sourceIslandId: 0,
      destinationIslandId: 1,
      sourceForcesBefore: 20,
      strength: 10,
      travelTimeMs: 1_000,
    },
    { id: "cpu-wait", action: "wait" },
  ],
} as const;

function decisionBody(overrides: Record<string, unknown> = {}) {
  return {
    schemaVersion: SCHEMA_VERSION,
    kind: "decision",
    matchId: "match-1",
    requestId: "request-1",
    elapsedMs: board.elapsedMs,
    board,
    subjects: [subject],
    ...overrides,
  };
}

function request(body: unknown, init: RequestInit = {}) {
  const method = init.method ?? "POST";
  return new Request("https://example.test/api/v1/cpu/very-hard", {
    method,
    headers: { "content-type": "application/json" },
    body:
      method === "GET" || method === "HEAD" ? undefined : JSON.stringify(body),
    ...init,
  });
}

function providerReturning(
  choice: (
    input: JevChoiceInput,
    options?: { signal?: AbortSignal },
  ) => Promise<{ candidateId: string }>,
): JevProvider {
  return { choose: choice };
}

beforeEach(() => {
  vi.clearAllMocks();
  vi.mocked(checkRateLimit).mockResolvedValue({ rateLimited: false });
});

describe("VercelGatewayJevProvider", () => {
  it("selects a legal candidate through the Jev evaluation choice contract", async () => {
    const evaluationModel = { modelId: FIXED_MODEL };
    const signal = new AbortController().signal;
    gatewayMocks.evaluationModel.mockReturnValue(evaluationModel);
    aiSdkMocks.evaluate.mockResolvedValue({
      answers: {
        candidateId: {
          type: "choice",
          choice: "cpu-wait",
          probabilities: { "cpu-c0": 0.25, "cpu-wait": 0.75 },
        },
      },
      response: { modelId: FIXED_MODEL },
    });
    const provider = new VercelGatewayJevProvider();

    const result = await provider.choose(
      {
        kind: "decision",
        model: FIXED_MODEL,
        promptVersion: PROMPT_VERSION,
        system: "Select the strongest legal action.",
        prompt: "legacy prompt that must not be sent as a generation request",
        board: structuredClone(board) as unknown as JevChoiceInput["board"],
        subject: structuredClone(
          subject,
        ) as unknown as JevChoiceInput["subject"],
      },
      { signal },
    );

    expect(gatewayMocks.evaluationModel).toHaveBeenCalledWith(FIXED_MODEL);
    expect(aiSdkMocks.evaluate).toHaveBeenCalledWith({
      model: evaluationModel,
      state: {
        kind: "decision",
        promptVersion: PROMPT_VERSION,
        board,
        faction: "cpu",
      },
      questions: {
        candidateId: {
          type: "choice",
          instructions: "Select the strongest legal action.",
          criteria: {
            "cpu-c0": JSON.stringify(subject.candidates[0]),
            "cpu-wait": JSON.stringify(subject.candidates[1]),
          },
        },
      },
      maxRetries: 0,
      abortSignal: signal,
    });
    expect(aiSdkMocks.generateObject).not.toHaveBeenCalled();
    expect(gatewayMocks.legacyModel).not.toHaveBeenCalled();
    expect(result).toEqual({
      candidateId: "cpu-wait",
      resolvedModel: FIXED_MODEL,
    });
  });
});

describe("POST /api/v1/cpu/very-hard", () => {
  it("uses the shared Vercel Firewall rule before calling Jev", async () => {
    const handler = createVeryHardHandler({
      provider: providerReturning(async (input) => ({
        candidateId: input.subject.candidates[0].id,
      })),
    });

    const input = request(decisionBody());
    const response = await handler(input);

    expect(response.status).toBe(200);
    expect(checkRateLimit).toHaveBeenCalledWith(RATE_LIMIT_RULE_ID, {
      request: input,
    });
  });

  it("rejects a shared Firewall rate limit without calling Jev", async () => {
    vi.mocked(checkRateLimit).mockResolvedValue({ rateLimited: true });
    const choose = vi.fn();
    const handler = createVeryHardHandler({
      provider: providerReturning(choose),
    });

    const response = await handler(request(decisionBody()));

    expect(response.status).toBe(429);
    expect(await response.json()).toMatchObject({
      error: { code: "rate_limited" },
    });
    expect(choose).not.toHaveBeenCalled();
  });

  it("fails closed when the shared Firewall check errors", async () => {
    vi.mocked(checkRateLimit).mockRejectedValue(new Error("WAF unavailable"));
    const choose = vi.fn();
    const handler = createVeryHardHandler({
      provider: providerReturning(choose),
    });

    const response = await handler(request(decisionBody()));

    expect(response.status).toBe(503);
    expect(await response.json()).toMatchObject({
      error: { code: "rate_limiter_unavailable" },
    });
    expect(choose).not.toHaveBeenCalled();
  });

  it("fails closed when Firewall reports a missing rule", async () => {
    vi.mocked(checkRateLimit).mockResolvedValue({
      rateLimited: false,
      error: "not-found",
    });
    const choose = vi.fn();
    const handler = createVeryHardHandler({
      provider: providerReturning(choose),
    });

    const response = await handler(request(decisionBody()));

    expect(response.status).toBe(503);
    expect(await response.json()).toMatchObject({
      error: { code: "rate_limiter_unavailable" },
    });
    expect(choose).not.toHaveBeenCalled();
  });

  it("returns an independent candidate choice for one subject", async () => {
    const calls: JevChoiceInput[] = [];
    const handler = createVeryHardHandler({
      provider: providerReturning(async (input) => {
        calls.push(input);
        return { candidateId: input.subject.candidates[0].id };
      }),
    });

    const response = await handler(request(decisionBody()));

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({
      schemaVersion: SCHEMA_VERSION,
      requestId: "request-1",
      decisions: [{ faction: "cpu", candidateId: "cpu-c0" }],
      diagnostics: {
        model: FIXED_MODEL,
        promptVersion: PROMPT_VERSION,
        latencyMs: expect.any(Number),
      },
    });
    expect(calls).toHaveLength(1);
    expect(calls[0].model).toBe(FIXED_MODEL);
    expect(calls[0].promptVersion).toBe(PROMPT_VERSION);
  });

  it("asks two factions independently within one decision request", async () => {
    const secondSubject = {
      ...subject,
      faction: "player",
      candidates: [
        { ...subject.candidates[0], id: "player-c0" },
        { id: "player-wait", action: "wait" },
      ],
    };
    const calls: JevChoiceInput[] = [];
    const handler = createVeryHardHandler({
      provider: providerReturning(async (input) => {
        calls.push(input);
        return { candidateId: input.subject.candidates[0].id };
      }),
    });

    const response = await handler(
      request(decisionBody({ subjects: [subject, secondSubject] })),
    );

    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({
      schemaVersion: SCHEMA_VERSION,
      requestId: "request-1",
      decisions: [
        { faction: "cpu", candidateId: "cpu-c0" },
        { faction: "player", candidateId: "player-c0" },
      ],
    });
    expect(calls.map((call) => call.subject.faction).sort()).toEqual([
      "cpu",
      "player",
    ]);
    expect(calls[0].prompt).not.toBe(calls[1].prompt);
  });

  it("runs the fixed Jev preflight without accepting client model or prompt data", async () => {
    const calls: JevChoiceInput[] = [];
    const handler = createVeryHardHandler({
      provider: providerReturning(async (input) => {
        calls.push(input);
        return { candidateId: "preflight-wait" };
      }),
    });

    const response = await handler(
      request({
        schemaVersion: SCHEMA_VERSION,
        kind: "preflight",
        matchId: "match-1",
        requestId: "preflight-match-1",
      }),
    );

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({
      schemaVersion: SCHEMA_VERSION,
      kind: "preflight",
      requestId: "preflight-match-1",
      available: true,
      diagnostics: {
        model: FIXED_MODEL,
        promptVersion: PROMPT_VERSION,
        latencyMs: expect.any(Number),
      },
    });
    expect(calls).toHaveLength(1);
    expect(calls[0].model).toBe(FIXED_MODEL);
    expect(calls[0].subject.faction).toBe("cpu");
    expect(calls[0].subject.candidates).toEqual([
      { id: "preflight-wait", action: "wait" },
    ]);
  });

  it.each([
    [
      "missing content type",
      new Request("https://example.test/api/v1/cpu/very-hard", {
        method: "POST",
        body: "{}",
      }),
    ],
    [
      "wrong content type",
      request(decisionBody(), { headers: { "content-type": "text/plain" } }),
    ],
    ["wrong method", request(decisionBody(), { method: "GET" })],
    [
      "invalid json",
      new Request("https://example.test/api/v1/cpu/very-hard", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: "{",
      }),
    ],
  ])("rejects %s before calling Jev", async (_name, input) => {
    const choose = vi.fn();
    const handler = createVeryHardHandler({
      provider: providerReturning(choose),
    });

    const response = await handler(input);

    expect(response.status).toBeGreaterThanOrEqual(400);
    expect(choose).not.toHaveBeenCalled();
  });

  it("rejects extra model, prompt, and free-question fields", async () => {
    const choose = vi.fn();
    const handler = createVeryHardHandler({
      provider: providerReturning(choose),
    });

    for (const field of ["model", "prompt", "question"]) {
      const response = await handler(
        request(decisionBody({ [field]: "client supplied" })),
      );
      expect(response.status).toBe(400);
    }
    expect(choose).not.toHaveBeenCalled();
  });

  it("rejects more than two factions and more than 133 candidates", async () => {
    const choose = vi.fn();
    const handler = createVeryHardHandler({
      provider: providerReturning(choose),
    });
    const third = { ...subject, faction: "neutral" };
    const tooMany = Array.from({ length: 134 }, (_, index) => ({
      id: `cpu-${index}`,
      action: "wait",
    }));

    expect(
      (
        await handler(
          request(
            decisionBody({
              subjects: [subject, { ...subject, faction: "player" }, third],
            }),
          ),
        )
      ).status,
    ).toBe(400);
    expect(
      (
        await handler(
          request(
            decisionBody({ subjects: [{ ...subject, candidates: tooMany }] }),
          ),
        )
      ).status,
    ).toBe(400);
    expect(choose).not.toHaveBeenCalled();
  });

  it("rejects inconsistent board timestamps and duplicate island IDs", async () => {
    const choose = vi.fn();
    const handler = createVeryHardHandler({
      provider: providerReturning(choose),
    });

    const timestampMismatch = await handler(
      request(
        decisionBody({ board: { ...board, elapsedMs: board.elapsedMs + 1 } }),
      ),
    );
    const duplicateIsland = await handler(
      request(
        decisionBody({
          board: { ...board, islands: [board.islands[0], board.islands[0]] },
        }),
      ),
    );

    expect(timestampMismatch.status).toBe(400);
    expect(duplicateIsland.status).toBe(400);
    expect(choose).not.toHaveBeenCalled();
  });

  it("rejects a body over the small request limit before calling Jev", async () => {
    const choose = vi.fn();
    const handler = createVeryHardHandler({
      provider: providerReturning(choose),
    });

    const response = await handler(
      request({
        schemaVersion: SCHEMA_VERSION,
        kind: "preflight",
        matchId: "match-1",
        requestId: "request-1",
        padding: "x".repeat(MAX_BODY_BYTES),
      }),
    );

    expect(response.status).toBe(413);
    expect(choose).not.toHaveBeenCalled();
  });

  it("normalizes provider timeout, 402, 429, 5xx, and invalid choice errors", async () => {
    for (const error of [
      Object.assign(new Error("timeout"), { code: "ETIMEDOUT" }),
      Object.assign(new Error("budget"), { status: 402 }),
      Object.assign(new Error("limited"), { status: 429 }),
      Object.assign(new Error("downstream"), { status: 503 }),
      Object.assign(new Error("invalid"), { code: "AI_InvalidResponseError" }),
    ]) {
      const handler = createVeryHardHandler({
        provider: providerReturning(async () => {
          throw error;
        }),
      });

      const response = await handler(request(decisionBody()));
      expect(response.status).toBe(502);
      expect(await response.json()).toMatchObject({
        error: { code: expect.stringMatching(/^provider_/) },
      });
    }
  });

  it("logs only bounded provider error metadata for runtime diagnosis", async () => {
    const logger = vi.fn();
    const error = Object.assign(new Error("secret response body"), {
      name: "GatewayInvalidRequestError",
      type: "invalid_request_error",
      code: "AI_GATEWAY_INVALID_REQUEST",
      statusCode: 400,
      response: { body: "private provider payload" },
    });
    const handler = createVeryHardHandler({
      logger,
      provider: providerReturning(async () => {
        throw error;
      }),
    });

    const response = await handler(request(decisionBody()));

    expect(response.status).toBe(502);
    expect(logger).toHaveBeenCalledWith(
      expect.objectContaining({
        outcome: "provider_error",
        providerErrorName: "GatewayInvalidRequestError",
        providerErrorType: "invalid_request_error",
        providerErrorCode: "AI_GATEWAY_INVALID_REQUEST",
        providerStatus: 400,
      }),
    );
    const logged = JSON.stringify(logger.mock.calls);
    expect(logged).not.toContain("secret response body");
    expect(logged).not.toContain("private provider payload");
  });

  it("classifies provider policy errors without logging their message", async () => {
    const logger = vi.fn();
    const error = Object.assign(
      new Error(
        "Your team has restricted access to this provider. Contact the owner of the account for more details.",
      ),
      {
        name: "GatewayInternalServerError",
        type: "internal_server_error",
        statusCode: 403,
      },
    );
    const handler = createVeryHardHandler({
      logger,
      provider: providerReturning(async () => {
        throw error;
      }),
    });

    const response = await handler(request(decisionBody()));

    expect(response.status).toBe(502);
    expect(logger).toHaveBeenCalledWith(
      expect.objectContaining({ providerErrorCategory: "provider_blocked" }),
    );
    const logged = JSON.stringify(logger.mock.calls);
    expect(logged).not.toContain("restricted access");
    expect(logged).not.toContain("Contact the owner");
  });

  it("aborts a provider request when the decision timeout expires", async () => {
    let aborted = false;
    const handler = createVeryHardHandler({
      decisionTimeoutMs: 5,
      provider: providerReturning(
        async (_input, options) =>
          new Promise((_resolve, reject) => {
            options?.signal?.addEventListener("abort", () => {
              aborted = true;
              reject(
                Object.assign(new Error("aborted"), { code: "ABORT_ERR" }),
              );
            });
          }),
      ),
    });

    const response = await handler(request(decisionBody()));

    expect(response.status).toBe(502);
    expect(await response.json()).toMatchObject({
      error: { code: "provider_timeout" },
    });
    expect(aborted).toBe(true);
  });

  it("normalizes a provider HTTP 504 to a timeout", async () => {
    const handler = createVeryHardHandler({
      provider: providerReturning(async () => {
        throw Object.assign(new Error("gateway timeout"), { status: 504 });
      }),
    });

    const response = await handler(request(decisionBody()));

    expect(response.status).toBe(502);
    expect(await response.json()).toMatchObject({
      error: { code: "provider_timeout" },
    });
  });

  it("never logs board or candidate payload and records only anonymous diagnostics", async () => {
    const info = vi.spyOn(console, "info").mockImplementation(() => undefined);
    const handler = createVeryHardHandler({
      provider: providerReturning(async (input) => ({
        candidateId: input.subject.candidates[0].id,
      })),
    });

    await handler(request(decisionBody()));

    const logs = info.mock.calls.map(([value]) => String(value)).join("\n");
    expect(logs).toContain(PROMPT_VERSION);
    expect(logs).toContain(FIXED_MODEL);
    expect(logs).toContain("request-1");
    expect(logs).not.toContain("currentForces");
    expect(logs).not.toContain("cpu-c0");
    expect(logs).not.toContain("sourceIslandId");
    expect(logs).not.toContain("Authorization");
    info.mockRestore();
  });
});
