# DebtFold Engine API

Isolated, stateless Cloudflare Worker for explainable debt simulations. Flutter remains local-first; this worker does not access auth, sync, website, or a database.

## Local development
`npm install && npm test && npm run typecheck && npm run dev`

Supports `GET /health`, `POST /v1/simulations`, and `POST /v1/simulations/compare`. Configure `ALLOWED_ORIGIN` for deployment; local development defaults to `http://localhost:4321`. No request data is logged or persisted. Limits: 20 debts, 5 comparison strategies, 1 MB body, and 600 simulation months. Mario can deploy with `npm run deploy` after configuring the route; deployment is intentionally not performed here.
