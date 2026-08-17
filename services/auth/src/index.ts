interface Env {
	WORKOS_CLIENT_ID: string;
	WORKOS_API_KEY: string;
	ALLOWED_ORIGIN?: string;
}

type AuthCallbackRequest = {
	code?: unknown;
	redirect_uri?: unknown;
};

type AuthRefreshRequest = {
	refresh_token?: unknown;
};

const workosAuthenticateUrl = "https://api.workos.com/user_management/authenticate";

export default {
	async fetch(request, env): Promise<Response> {
		const url = new URL(request.url);

		if (request.method === "OPTIONS") {
			return new Response(null, { status: 204, headers: corsHeaders(env) });
		}

		if (url.pathname === "/health") {
			return json({ ok: true }, 200, env);
		}

		if (url.pathname === "/auth/workos/callback" && request.method === "POST") {
			return exchangeWorkosCode(request, env);
		}

		if (url.pathname === "/auth/workos/refresh" && request.method === "POST") {
			return refreshWorkosSession(request, env);
		}

		return json({ error: "Not found" }, 404, env);
	},
} satisfies ExportedHandler<Env>;

async function exchangeWorkosCode(request: Request, env: Env): Promise<Response> {
	if (!env.WORKOS_CLIENT_ID || !env.WORKOS_API_KEY) {
		return json({ error: "WorkOS environment variables are missing" }, 500, env);
	}

	let body: AuthCallbackRequest;
	try {
		body = (await request.json()) as AuthCallbackRequest;
	} catch {
		return json({ error: "Request body must be JSON" }, 400, env);
	}

	if (typeof body.code !== "string" || body.code.length === 0) {
		return json({ error: "Missing authorization code" }, 400, env);
	}
	if (typeof body.redirect_uri !== "string" || body.redirect_uri.length === 0) {
		return json({ error: "Missing redirect URI" }, 400, env);
	}

	const workosResponse = await fetch(workosAuthenticateUrl, {
		method: "POST",
		headers: { "content-type": "application/json" },
		body: JSON.stringify({
			client_id: env.WORKOS_CLIENT_ID,
			client_secret: env.WORKOS_API_KEY,
			grant_type: "authorization_code",
			code: body.code,
			redirect_uri: body.redirect_uri,
			ip_address: clientIp(request),
			user_agent: request.headers.get("user-agent") ?? undefined,
		}),
	});

	const responseBody = await workosResponse.json().catch(() => null);
	if (!workosResponse.ok) {
		return json(
			{
				error: "WorkOS authentication failed",
				status: workosResponse.status,
				details: responseBody,
			},
			workosResponse.status,
			env,
		);
	}

	return json(responseBody, 200, env);
}

async function refreshWorkosSession(request: Request, env: Env): Promise<Response> {
	if (!env.WORKOS_CLIENT_ID || !env.WORKOS_API_KEY) {
		return json({ error: "WorkOS environment variables are missing" }, 500, env);
	}

	let body: AuthRefreshRequest;
	try {
		body = (await request.json()) as AuthRefreshRequest;
	} catch {
		return json({ error: "Request body must be JSON" }, 400, env);
	}

	if (typeof body.refresh_token !== "string" || body.refresh_token.length === 0) {
		return json({ error: "Missing refresh token" }, 400, env);
	}

	const workosResponse = await fetch(workosAuthenticateUrl, {
		method: "POST",
		headers: { "content-type": "application/json" },
		body: JSON.stringify({
			client_id: env.WORKOS_CLIENT_ID,
			client_secret: env.WORKOS_API_KEY,
			grant_type: "refresh_token",
			refresh_token: body.refresh_token,
			ip_address: clientIp(request),
			user_agent: request.headers.get("user-agent") ?? undefined,
		}),
	});

	const responseBody = await workosResponse.json().catch(() => null);
	if (!workosResponse.ok) {
		return json(
			{
				error: "WorkOS session refresh failed",
				status: workosResponse.status,
				details: responseBody,
			},
			workosResponse.status,
			env,
		);
	}

	return json(responseBody, 200, env);
}

function clientIp(request: Request): string | undefined {
	return (
		request.headers.get("cf-connecting-ip") ??
		request.headers.get("x-forwarded-for")?.split(",")[0]?.trim()
	);
}

function json(body: unknown, status: number, env: Env): Response {
	return new Response(JSON.stringify(body), {
		status,
		headers: {
			"content-type": "application/json",
			...corsHeaders(env),
		},
	});
}

function corsHeaders(env: Env): HeadersInit {
	return {
		"access-control-allow-origin": env.ALLOWED_ORIGIN ?? "*",
		"access-control-allow-methods": "GET,POST,OPTIONS",
		"access-control-allow-headers": "content-type,authorization",
	};
}
