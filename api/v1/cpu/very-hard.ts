import { experimental_evaluate as evaluate } from "ai";
import { gateway } from "@ai-sdk/gateway";
import { checkRateLimit } from "@vercel/firewall";
import { z } from "zod";

export const SCHEMA_VERSION = 1;
export const PROMPT_VERSION = "very-hard-jev-v1";
export const FIXED_MODEL = "typesafe-ai/jev";
export const MAX_BODY_BYTES = 256 * 1024;
export const MAX_SUBJECTS = 2;
export const MAX_CANDIDATES_PER_SUBJECT = 133;
export const DECISION_PROVIDER_TIMEOUT_MS = 1_100;
export const PREFLIGHT_PROVIDER_TIMEOUT_MS = 2_800;
export const MAX_ISLANDS = 12;
export const MAX_MOVING_FORCES = 132;
export const RATE_LIMIT_RULE_ID = "conquest-very-hard-v1";

const SYSTEM_PROMPT = [
  `Conquest Very Hard CPU selector. Prompt contract ${PROMPT_VERSION}.`,
  "Choose exactly one candidateId from the supplied candidates.",
  "Maximize the controlled faction final win probability.",
  "Prefer winning play over human-like play, mercy, or decorative variety.",
  "Use only the current state and supplied candidate descriptions.",
  "Never invent an action, island ID, force count, or candidateId.",
  "The wait candidate is legal and may be selected when it is best.",
].join(" ");

const factionSchema = z.enum(["player", "cpu", "neutral"]);
const decisionFactionSchema = z.enum(["player", "cpu"]);
const islandSchema = z
  .object({
    id: z.number().int().min(0).max(11),
    x: z.number().finite().min(-1).max(1),
    y: z.number().finite().min(-1).max(1),
    size: z.enum(["small", "medium", "large", "headquarters"]),
    faction: factionSchema,
    currentForces: z.number().int().min(0).max(1_000_000),
    durability: z.number().int().min(0).max(1_000_000),
    capacity: z.number().int().min(1).max(1_000_000),
  })
  .strict();

const movingForceSchema = z
  .object({
    faction: factionSchema,
    sourceIslandId: z.number().int().min(0).max(11),
    destinationIslandId: z.number().int().min(0).max(11),
    strength: z.number().int().min(1).max(1_000_000),
    remainingMs: z.number().int().min(0).max(86_400_000),
  })
  .strict();

const boardSchema = z
  .object({
    elapsedMs: z.number().int().min(0).max(86_400_000),
    islands: z.array(islandSchema).min(1).max(MAX_ISLANDS),
    movingForces: z.array(movingForceSchema).max(MAX_MOVING_FORCES),
  })
  .strict();

const dispatchCandidateSchema = z
  .object({
    id: z
      .string()
      .min(1)
      .max(128)
      .regex(/^[A-Za-z0-9_-]+$/),
    action: z.literal("dispatch"),
    sourceIslandId: z.number().int().min(0).max(11),
    destinationIslandId: z.number().int().min(0).max(11),
    sourceForcesBefore: z.number().int().min(2).max(1_000_000),
    strength: z.number().int().min(1).max(1_000_000),
    travelTimeMs: z.number().int().min(0).max(86_400_000),
  })
  .strict();

const waitCandidateSchema = z
  .object({
    id: z
      .string()
      .min(1)
      .max(128)
      .regex(/^[A-Za-z0-9_-]+$/),
    action: z.literal("wait"),
  })
  .strict();

const candidateSchema = z.union([dispatchCandidateSchema, waitCandidateSchema]);
const subjectSchema = z
  .object({
    faction: decisionFactionSchema,
    candidates: z.array(candidateSchema).min(1).max(MAX_CANDIDATES_PER_SUBJECT),
  })
  .strict();

const preflightRequestSchema = z
  .object({
    schemaVersion: z.literal(SCHEMA_VERSION),
    kind: z.literal("preflight"),
    matchId: z.string().min(1).max(128),
    requestId: z.string().min(1).max(128),
  })
  .strict();

const decisionRequestSchema = z
  .object({
    schemaVersion: z.literal(SCHEMA_VERSION),
    kind: z.literal("decision"),
    matchId: z.string().min(1).max(128),
    requestId: z.string().min(1).max(128),
    elapsedMs: z.number().int().min(0).max(86_400_000),
    board: boardSchema,
    subjects: z.array(subjectSchema).min(1).max(MAX_SUBJECTS),
  })
  .strict();

const requestSchema = z.discriminatedUnion("kind", [
  preflightRequestSchema,
  decisionRequestSchema,
]);

type Faction = "player" | "cpu";
type Candidate = z.infer<typeof candidateSchema>;
type DecisionSubject = z.infer<typeof subjectSchema>;
type Board = z.infer<typeof boardSchema>;
type DecisionRequest = z.infer<typeof decisionRequestSchema>;
type PreflightRequest = z.infer<typeof preflightRequestSchema>;
export type VeryHardRequest = DecisionRequest | PreflightRequest;

export interface JevChoiceInput {
  kind: "preflight" | "decision";
  model: typeof FIXED_MODEL;
  promptVersion: typeof PROMPT_VERSION;
  system: typeof SYSTEM_PROMPT;
  prompt: string;
  board: Board;
  subject: DecisionSubject;
}

export interface JevChoice {
  candidateId: string;
  resolvedModel?: string;
}

export interface JevProvider {
  choose(
    input: JevChoiceInput,
    options?: { signal?: AbortSignal },
  ): Promise<JevChoice>;
}

export class VercelGatewayJevProvider implements JevProvider {
  async choose(input: JevChoiceInput, options: { signal?: AbortSignal } = {}) {
    const criteria = Object.fromEntries(
      input.subject.candidates.map((candidate) => [
        candidate.id,
        JSON.stringify(candidate),
      ]),
    );
    const result = await evaluate({
      model: gateway.evaluationModel(FIXED_MODEL),
      state: {
        kind: input.kind,
        promptVersion: input.promptVersion,
        board: input.board,
        faction: input.subject.faction,
      },
      questions: {
        candidateId: {
          type: "choice",
          instructions: input.system,
          criteria,
        },
      },
      maxRetries: 0,
      abortSignal: options.signal,
    });
    return {
      candidateId: result.answers.candidateId.choice,
      resolvedModel: result.response.modelId,
    };
  }
}

export type RateLimitCheck = (
  request: Request,
) => ReturnType<typeof checkRateLimit>;

export interface VeryHardHandlerOptions {
  provider?: JevProvider;
  rateLimitCheck?: RateLimitCheck;
  logger?: (event: Record<string, unknown>) => void;
  now?: () => number;
  decisionTimeoutMs?: number;
  preflightTimeoutMs?: number;
}

interface ParsedRequest {
  request: VeryHardRequest;
  bodyBytes: number;
}

type Handler = (request: Request) => Promise<Response>;

export function createVeryHardHandler(
  options: VeryHardHandlerOptions = {},
): Handler {
  const provider = options.provider ?? new VercelGatewayJevProvider();
  const rateLimitCheck =
    options.rateLimitCheck ??
    ((request) => checkRateLimit(RATE_LIMIT_RULE_ID, { request }));
  const logger =
    options.logger ?? ((event) => console.info(JSON.stringify(event)));
  const now = options.now ?? Date.now;
  const decisionTimeoutMs =
    options.decisionTimeoutMs ?? DECISION_PROVIDER_TIMEOUT_MS;
  const preflightTimeoutMs =
    options.preflightTimeoutMs ?? PREFLIGHT_PROVIDER_TIMEOUT_MS;

  return async (request) => {
    if (request.method !== "POST") {
      return errorResponse(
        405,
        "method_not_allowed",
        "Only POST is supported.",
      );
    }
    if (!isJsonContentType(request.headers.get("content-type"))) {
      return errorResponse(
        415,
        "unsupported_media_type",
        "Content-Type must be application/json.",
      );
    }
    let rateLimitResult: Awaited<ReturnType<typeof checkRateLimit>>;
    try {
      rateLimitResult = await rateLimitCheck(request);
    } catch {
      logger({
        event: "very_hard_jev",
        kind: "rate_limit",
        outcome: "rate_limiter_unavailable",
      });
      return errorResponse(
        503,
        "rate_limiter_unavailable",
        "Rate limiter is unavailable.",
      );
    }
    if (rateLimitResult.error !== undefined) {
      logger({
        event: "very_hard_jev",
        kind: "rate_limit",
        outcome: "rate_limiter_unavailable",
      });
      return errorResponse(
        503,
        "rate_limiter_unavailable",
        "Rate limiter is unavailable.",
      );
    }
    if (rateLimitResult.rateLimited) {
      return errorResponse(429, "rate_limited", "Too many requests.");
    }

    let parsed: ParsedRequest;
    try {
      parsed = await parseRequest(request);
    } catch (error) {
      if (error instanceof BodyTooLargeError) {
        return errorResponse(
          413,
          "body_too_large",
          "Request body is too large.",
        );
      }
      return errorResponse(
        400,
        "invalid_request",
        "Request does not match the Very Hard contract.",
      );
    }

    const startedAt = now();
    if (parsed.request.kind === "preflight") {
      return runPreflight(
        parsed.request,
        provider,
        logger,
        now,
        startedAt,
        preflightTimeoutMs,
      );
    }

    try {
      const choice = await chooseDecisions(
        parsed.request,
        provider,
        decisionTimeoutMs,
      );
      const latencyMs = Math.max(0, now() - startedAt);
      const diagnostics = {
        model: FIXED_MODEL,
        promptVersion: PROMPT_VERSION,
        latencyMs,
        ...(choice.resolvedModel === undefined
          ? {}
          : { resolvedModel: choice.resolvedModel }),
      };
      const response = {
        schemaVersion: SCHEMA_VERSION,
        requestId: parsed.request.requestId,
        decisions: choice.decisions,
        diagnostics,
      };
      logger({
        event: "very_hard_jev",
        kind: "decision",
        requestId: parsed.request.requestId,
        model: FIXED_MODEL,
        ...(choice.resolvedModel === undefined
          ? {}
          : { resolvedModel: choice.resolvedModel }),
        promptVersion: PROMPT_VERSION,
        latencyMs,
        outcome: "success",
        subjectCount: parsed.request.subjects.length,
        candidateCounts: parsed.request.subjects.map(
          (subject) => subject.candidates.length,
        ),
      });
      return jsonResponse(response);
    } catch (error) {
      const normalized = normalizeProviderError(error);
      logger({
        event: "very_hard_jev",
        kind: "decision",
        requestId: parsed.request.requestId,
        model: FIXED_MODEL,
        promptVersion: PROMPT_VERSION,
        latencyMs: Math.max(0, now() - startedAt),
        outcome: normalized.code,
        subjectCount: parsed.request.subjects.length,
        candidateCounts: parsed.request.subjects.map(
          (subject) => subject.candidates.length,
        ),
      });
      return errorResponse(
        502,
        normalized.code,
        "Jev provider did not return a usable choice.",
      );
    }
  };
}

async function runPreflight(
  request: PreflightRequest,
  provider: JevProvider,
  logger: (event: Record<string, unknown>) => void,
  now: () => number,
  startedAt: number,
  timeoutMs: number,
): Promise<Response> {
  const subject: DecisionSubject = {
    faction: "cpu",
    candidates: [{ id: "preflight-wait", action: "wait" }],
  };
  const board: Board = {
    elapsedMs: 0,
    islands: [
      {
        id: 0,
        x: 0.5,
        y: 0.5,
        size: "small",
        faction: "cpu",
        currentForces: 2,
        durability: 0,
        capacity: 30,
      },
    ],
    movingForces: [],
  };
  try {
    const choice = await withProviderTimeout(
      provider,
      buildChoiceInput("preflight", board, subject),
      timeoutMs,
    );
    if (choice.candidateId !== "preflight-wait")
      throw new ProviderInvalidResponseError();
    const latencyMs = Math.max(0, now() - startedAt);
    logger({
      event: "very_hard_jev",
      kind: "preflight",
      requestId: request.requestId,
      model: FIXED_MODEL,
      ...(choice.resolvedModel === undefined
        ? {}
        : { resolvedModel: choice.resolvedModel }),
      promptVersion: PROMPT_VERSION,
      latencyMs,
      outcome: "success",
      subjectCount: 1,
      candidateCounts: [1],
    });
    return jsonResponse({
      schemaVersion: SCHEMA_VERSION,
      kind: "preflight",
      requestId: request.requestId,
      available: true,
      diagnostics: {
        model: FIXED_MODEL,
        promptVersion: PROMPT_VERSION,
        latencyMs,
        ...(choice.resolvedModel === undefined
          ? {}
          : { resolvedModel: choice.resolvedModel }),
      },
    });
  } catch (error) {
    const normalized = normalizeProviderError(error);
    logger({
      event: "very_hard_jev",
      kind: "preflight",
      requestId: request.requestId,
      model: FIXED_MODEL,
      promptVersion: PROMPT_VERSION,
      latencyMs: Math.max(0, now() - startedAt),
      outcome: normalized.code,
      subjectCount: 1,
      candidateCounts: [1],
    });
    return jsonResponse({
      schemaVersion: SCHEMA_VERSION,
      kind: "preflight",
      requestId: request.requestId,
      available: false,
      reason: normalized.code,
      diagnostics: {
        model: FIXED_MODEL,
        promptVersion: PROMPT_VERSION,
        latencyMs: Math.max(0, now() - startedAt),
      },
    });
  }
}

async function chooseDecisions(
  request: DecisionRequest,
  provider: JevProvider,
  timeoutMs: number,
): Promise<{
  decisions: Array<{ faction: Faction; candidateId: string }>;
  resolvedModel?: string;
}> {
  const results = await Promise.all(
    request.subjects.map(async (subject) => {
      const choice = await withProviderTimeout(
        provider,
        buildChoiceInput("decision", request.board, subject),
        timeoutMs,
      );
      const candidate = subject.candidates.find(
        (item) => item.id === choice.candidateId,
      );
      if (candidate === undefined) throw new ProviderInvalidResponseError();
      return {
        faction: subject.faction,
        candidateId: candidate.id,
        resolvedModel: choice.resolvedModel,
      };
    }),
  );
  const resolvedModels = [
    ...new Set(
      results
        .map((result) => result.resolvedModel)
        .filter((model): model is string => model !== undefined),
    ),
  ];
  return {
    decisions: results.map(({ faction, candidateId }) => ({
      faction,
      candidateId,
    })),
    ...(resolvedModels.length === 0
      ? {}
      : { resolvedModel: resolvedModels.join(",") }),
  };
}

function buildChoiceInput(
  kind: JevChoiceInput["kind"],
  board: Board,
  subject: DecisionSubject,
): JevChoiceInput {
  const prompt = JSON.stringify({
    kind,
    board,
    subject,
    instruction: "Return only the candidateId of the best legal choice.",
  });
  return {
    kind,
    model: FIXED_MODEL,
    promptVersion: PROMPT_VERSION,
    system: SYSTEM_PROMPT,
    prompt,
    board,
    subject,
  };
}

async function parseRequest(request: Request): Promise<ParsedRequest> {
  const declaredLength = request.headers.get("content-length");
  if (declaredLength !== null) {
    const numericLength = Number(declaredLength);
    if (!Number.isSafeInteger(numericLength) || numericLength < 0)
      throw new Error("invalid content length");
    if (numericLength > MAX_BODY_BYTES) throw new BodyTooLargeError();
  }
  const body = await readBody(request);
  let value: unknown;
  try {
    value = JSON.parse(body);
  } catch {
    throw new Error("invalid json");
  }
  const parsed = requestSchema.safeParse(value);
  if (!parsed.success) throw new Error("invalid schema");
  if (parsed.data.kind === "decision") {
    if (parsed.data.board.elapsedMs !== parsed.data.elapsedMs) {
      throw new Error("board and request timestamps do not match");
    }
    validateDecisionReferences(parsed.data);
  }
  return {
    request: parsed.data,
    bodyBytes: new TextEncoder().encode(body).byteLength,
  };
}

function validateDecisionReferences(request: DecisionRequest): void {
  const islandIds = new Set(request.board.islands.map((island) => island.id));
  if (islandIds.size !== request.board.islands.length) {
    throw new Error("duplicate island id");
  }
  const factions = new Set<Faction>();
  const allCandidateIds = new Set<string>();
  for (const subject of request.subjects) {
    if (factions.has(subject.faction)) throw new Error("duplicate faction");
    factions.add(subject.faction);
    for (const candidate of subject.candidates) {
      if (allCandidateIds.has(candidate.id))
        throw new Error("duplicate candidate id");
      allCandidateIds.add(candidate.id);
      if (candidate.action !== "dispatch") continue;
      if (candidate.sourceIslandId === candidate.destinationIslandId)
        throw new Error("same source and destination");
      if (
        !islandIds.has(candidate.sourceIslandId) ||
        !islandIds.has(candidate.destinationIslandId)
      ) {
        throw new Error("candidate island is not on board");
      }
      if (candidate.strength > candidate.sourceForcesBefore)
        throw new Error("candidate strength exceeds source forces");
    }
  }
}

async function readBody(request: Request): Promise<string> {
  if (request.body === null) return "";
  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      if (!(value instanceof Uint8Array)) throw new Error("invalid body chunk");
      total += value.byteLength;
      if (total > MAX_BODY_BYTES) throw new BodyTooLargeError();
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return new TextDecoder("utf-8", { fatal: true }).decode(bytes);
}

function isJsonContentType(value: string | null): boolean {
  return value?.split(";", 1)[0]?.trim().toLowerCase() === "application/json";
}

function jsonResponse(body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status: 200,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
    },
  });
}

function errorResponse(
  status: number,
  code: string,
  message: string,
): Response {
  return new Response(JSON.stringify({ error: { code, message } }), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
    },
  });
}

class BodyTooLargeError extends Error {}
class ProviderInvalidResponseError extends Error {}

interface NormalizedProviderError {
  code: string;
}

function normalizeProviderError(error: unknown): NormalizedProviderError {
  if (
    error instanceof ProviderInvalidResponseError ||
    hasCode(error, "AI_InvalidResponseError")
  ) {
    return { code: "provider_invalid_response" };
  }
  if (
    error instanceof TimeoutError ||
    hasCode(error, "ETIMEDOUT") ||
    hasCode(error, "ABORT_ERR")
  ) {
    return { code: "provider_timeout" };
  }
  const status = providerStatus(error);
  if (status === 408 || status === 504) return { code: "provider_timeout" };
  if (status === 402) return { code: "provider_budget_exhausted" };
  if (status === 429) return { code: "provider_rate_limited" };
  if (status !== undefined && status >= 500)
    return { code: "provider_unavailable" };
  return { code: "provider_error" };
}

function providerStatus(error: unknown): number | undefined {
  if (!error || typeof error !== "object") return undefined;
  const candidate = error as {
    status?: unknown;
    statusCode?: unknown;
    response?: { status?: unknown };
  };
  for (const value of [
    candidate.status,
    candidate.statusCode,
    candidate.response?.status,
  ]) {
    if (typeof value === "number" && Number.isInteger(value)) return value;
  }
  return undefined;
}

function hasCode(error: unknown, code: string): boolean {
  return Boolean(
    error &&
      typeof error === "object" &&
      "code" in error &&
      (error as { code?: unknown }).code === code,
  );
}

class TimeoutError extends Error {}

async function withTimeout<T>(
  promise: Promise<T>,
  timeoutMs: number,
  onTimeout?: () => void,
): Promise<T> {
  let timer: ReturnType<typeof setTimeout> | undefined;
  try {
    return await Promise.race([
      promise,
      new Promise<T>((_, reject) => {
        timer = setTimeout(() => {
          onTimeout?.();
          reject(new TimeoutError());
        }, timeoutMs);
      }),
    ]);
  } finally {
    if (timer !== undefined) clearTimeout(timer);
  }
}

async function withProviderTimeout(
  provider: JevProvider,
  input: JevChoiceInput,
  timeoutMs: number,
): Promise<JevChoice> {
  const controller = new AbortController();
  return withTimeout(
    provider.choose(input, { signal: controller.signal }),
    timeoutMs,
    () => controller.abort(),
  );
}

interface NodeRequestLike extends AsyncIterable<Uint8Array | string> {
  method?: string;
  headers?: Record<string, string | string[] | undefined>;
  body?: unknown;
}

interface NodeResponseLike {
  statusCode: number;
  setHeader(name: string, value: string): void;
  end(body?: string): void;
}

async function readNodeBody(request: NodeRequestLike): Promise<string> {
  if (request.body !== undefined) {
    const body =
      typeof request.body === "string"
        ? request.body
        : (JSON.stringify(request.body) ?? "");
    if (new TextEncoder().encode(body).byteLength > MAX_BODY_BYTES) {
      throw new BodyTooLargeError();
    }
    return body;
  }
  const chunks: Uint8Array[] = [];
  let total = 0;
  for await (const chunk of request) {
    const bytes =
      typeof chunk === "string" ? new TextEncoder().encode(chunk) : chunk;
    total += bytes.byteLength;
    if (total > MAX_BODY_BYTES) throw new BodyTooLargeError();
    chunks.push(bytes);
  }
  const body = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    body.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return new TextDecoder("utf-8", { fatal: true }).decode(body);
}

function nodeHeaders(request: NodeRequestLike): Headers {
  const headers = new Headers();
  for (const [name, value] of Object.entries(request.headers ?? {})) {
    if (value === undefined) continue;
    headers.set(name, Array.isArray(value) ? value.join(",") : value);
  }
  return headers;
}

const handler = createVeryHardHandler();

export default async function vercelHandler(
  request: NodeRequestLike,
  response: NodeResponseLike,
): Promise<void> {
  let body: string;
  try {
    body = await readNodeBody(request);
  } catch (error) {
    const result =
      error instanceof BodyTooLargeError
        ? errorResponse(413, "body_too_large", "Request body is too large.")
        : errorResponse(
            400,
            "invalid_request",
            "Request body could not be read.",
          );
    response.statusCode = result.status;
    response.setHeader("content-type", "application/json; charset=utf-8");
    response.setHeader("cache-control", "no-store");
    response.end(await result.text());
    return;
  }
  const method = request.method ?? "GET";
  const webRequest = new Request(
    "https://vercel.invalid/api/v1/cpu/very-hard",
    {
      method,
      headers: nodeHeaders(request),
      body: method === "GET" || method === "HEAD" ? undefined : body,
    },
  );
  const result = await handler(webRequest);
  response.statusCode = result.status;
  response.setHeader(
    "content-type",
    result.headers.get("content-type") ?? "application/json; charset=utf-8",
  );
  response.setHeader(
    "cache-control",
    result.headers.get("cache-control") ?? "no-store",
  );
  response.end(await result.text());
}
