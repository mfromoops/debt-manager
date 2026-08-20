import { createExecutionContext, env, waitOnExecutionContext } from "cloudflare:test";
import { beforeEach, describe, expect, it, vi } from "vitest";
import worker from "../src/index";

const IncomingRequest = Request<unknown, IncomingRequestCfProperties>;

describe("debt-manager-auth worker", () => {
	beforeEach(() => {
		vi.restoreAllMocks();
	});

	it("responds to health checks", async () => {
		const request = new IncomingRequest("http://example.com/health");
		const ctx = createExecutionContext();
		const response = await worker.fetch(request, env, ctx);
		await waitOnExecutionContext(ctx);

		expect(response.status).toBe(200);
		expect(await response.json()).toEqual({ ok: true });
	});

	it("exchanges a WorkOS callback code", async () => {
		const fetchMock = vi.fn(async () =>
			Response.json({
				access_token: "access-token",
				refresh_token: "refresh-token",
				user: {
					id: "user_123",
					email: "person@example.com",
					first_name: "Person",
					last_name: "Example",
				},
			}),
		);
		vi.stubGlobal(
			"fetch",
			fetchMock,
		);

		const request = new IncomingRequest("http://example.com/auth/workos/callback", {
			method: "POST",
			headers: { "content-type": "application/json" },
			body: JSON.stringify({
				code: "auth-code",
				redirect_uri: "com.debtfold.app://auth/callback",
			}),
		});
		const ctx = createExecutionContext();
		const response = await worker.fetch(
			request,
			{
				...env,
				WORKOS_CLIENT_ID: "client_123",
				WORKOS_API_KEY: "sk_test_123",
			},
			ctx,
		);
		await waitOnExecutionContext(ctx);

		expect(response.status).toBe(200);
		expect(await response.json()).toMatchObject({
			access_token: "access-token",
			user: { email: "person@example.com" },
		});
		expect(JSON.parse(fetchMock.mock.calls[0][1].body)).toMatchObject({
			code: "auth-code",
			redirect_uri: "com.debtfold.app://auth/callback",
		});
	});
});
