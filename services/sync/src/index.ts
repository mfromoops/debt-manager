import { createRemoteJWKSet, jwtVerify } from "jose";

interface Env {
	SYNC_STATE: DurableObjectNamespace;
	WORKOS_CLIENT_ID: string;
	ALLOWED_ORIGIN?: string;
}

type SyncDocument = {
	loans: unknown[];
	updatedAt: string;
	rev: string;
	deviceId?: string;
};


export class SyncState {
	constructor(
		private readonly state: DurableObjectState,
		private readonly env: Env,
	) {}

	async fetch(request: Request): Promise<Response> {
		const url = new URL(request.url);
		console.log(url)
		if (url.pathname === "/state" && request.method === "GET") {
			const document = await this.state.storage.get<SyncDocument>("document");
			return json(document ?? null, 200);
		}

		if (url.pathname === "/state" && request.method === "PUT") {
			let body: SyncDocument;
			try {
				body = (await request.json()) as SyncDocument;
			} catch {
				return json({ error: "Request body must be JSON" }, 400);
			}

			if (!Array.isArray(body.loans) || !body.updatedAt || !body.rev) {
				return json({ error: "Invalid sync document" }, 400);
			}

			const current = await this.state.storage.get<SyncDocument>("document");
			if (current && current.updatedAt > body.updatedAt) {
				return json(current, 409);
			}

			await this.state.storage.put("document", body);
			return json(body, 200);
		}

		return json({ error: "Not found" }, 404);
	}
}

export default {
	async fetch(request, env): Promise<Response> {
		const url = new URL(request.url);

		if (request.method === "OPTIONS") {
			return new Response(null, { status: 204, headers: corsHeaders(env) });
		}

		if (url.pathname === "/health") {
			return json({ ok: true }, 200, env);
		}

		if (url.pathname !== "/sync/state") {
			return json({ error: "Not found" }, 404, env);
		}

		const userId = await authenticate(request, env);
		if (userId instanceof Response) {
			return userId;
		}

		console.log("checking do")
		const objectId = env.SYNC_STATE.idFromName(userId);
		const stub = env.SYNC_STATE.get(objectId);
		const objectUrl = new URL(request.url);
		objectUrl.pathname = "/state";

		const response = await stub.fetch(new Request(objectUrl, request));
		return withCors(response, env);
	},
} satisfies ExportedHandler<Env>;

async function authenticate(request: Request, env: Env): Promise<string | Response> {
	const authorization = request.headers.get("authorization");
	const token = authorization?.match(/^Bearer\s+(.+)$/i)?.[1];
	if (!token) {
		return json({ error: "Missing bearer token" }, 401, env);
	}
	if (!env.WORKOS_CLIENT_ID) {
		return json({ error: "WorkOS client ID is not configured" }, 500, env);
	}

	try {
		const jwks = createRemoteJWKSet(
			new URL(`https://api.workos.com/sso/jwks/${env.WORKOS_CLIENT_ID}`),
		);
		const { payload } = await jwtVerify(token, jwks);
		if (typeof payload.sub !== "string" || payload.sub.length === 0) {
			return json({ error: "Session token is missing a user id" }, 401, env);
		}
		if (payload.client_id !== env.WORKOS_CLIENT_ID) {
			return json({ error: "Session token is for a different client" }, 401, env);
		}
		return payload.sub;
	} catch (error) {
		return json(
			{
				error: "Invalid session",
				details: error instanceof Error ? error.message : String(error),
			},
			401,
			env,
		);
	}
}

function json(body: unknown, status: number, env?: Env): Response {
	return new Response(JSON.stringify(body), {
		status,
		headers: {
			"content-type": "application/json",
			...(env ? corsHeaders(env) : {}),
		},
	});
}

function withCors(response: Response, env: Env): Response {
	const headers = new Headers(response.headers);
	for (const [key, value] of Object.entries(corsHeaders(env))) {
		headers.set(key, value);
	}
	return new Response(response.body, {
		status: response.status,
		statusText: response.statusText,
		headers,
	});
}

function corsHeaders(env: Env): HeadersInit {
	return {
		"access-control-allow-origin": env.ALLOWED_ORIGIN ?? "*",
		"access-control-allow-methods": "GET,PUT,OPTIONS",
		"access-control-allow-headers": "content-type,authorization",
	};
}
