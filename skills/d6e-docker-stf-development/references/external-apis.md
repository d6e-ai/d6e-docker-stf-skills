# External APIs and the `api_token` boundary

## Critical rule: `api_token` is SQL-only

Each Docker STF execution receives a signed, short-lived `api_token` on stdin.
The d6e API authenticates this token as `AuthContext::InternalStf` — an
internal execution context scoped to one workspace and one STF.

**That token can call the workspace SQL endpoint only.** It cannot access
endpoints that require a human user, workspace membership, or editor
permission.

| Endpoint | Works with `api_token`? | Why |
|----------|-------------------------|-----|
| `POST /api/v1/workspaces/{id}/sql` | **Yes** | Purpose-built for Docker STF execution |
| `POST /api/v1/saas-proxy` | **No** | Requires workspace membership (`user_id`) |
| `POST /api/v1/saas-proxy-download` | **No** | Requires membership + editor permission |
| `GET/POST/DELETE /api/v1/workspaces/{id}/files/*` | **No** | Requires editor permission on `StorageFile` |

Attempting to reuse `api_token` against saas-proxy or files APIs fails with
403 (membership/permission checks use `auth.user_id()`, which is nil for
`InternalStf`).

Do **not** design STFs that call saas-proxy or files download from inside the
container. Those APIs exist for session JWTs, API keys, MCP tools, and custom
frontend server routes — not for container callbacks.

## Required headers for SQL

All SQL calls from a Docker STF must include these headers. Values come from
the stdin JSON — never hardcode them.

```
Authorization: Bearer {api_token}
X-Internal-Bypass: true
X-Workspace-ID: {workspace_id}
X-STF-ID: {stf_id}
```

**Endpoint:**

```
POST {api_url}/api/v1/workspaces/{workspace_id}/sql
```

**Request body:**

```json
{ "sql": "SELECT * FROM my_table LIMIT 10" }
```

**Response shapes:**

- `SELECT` → `{ "rows": [ {...}, ... ] }`
- `INSERT` / `UPDATE` / `DELETE` → `{ "affected_rows": <number> }`

**Restrictions:**

- No DDL (`CREATE`, `DROP`, `ALTER`) — error code `DDL_FORBIDDEN`
- Policy-controlled access — without an allow policy for the table + operation,
  the call fails with `POLICY_DENIED`
- Workspace scope only; use plain table names (≤ 23 characters)

See [limits-and-timeouts.md](./limits-and-timeouts.md) for execution time and
output size limits.

## How to reach external SaaS from a workflow

Because `api_token` cannot proxy SaaS credentials, use one of these patterns
instead:

### 1. Separate workflow steps (Effect / MCP / other STFs)

Run SaaS calls **before or after** the Docker STF as distinct workflow steps:

- **Effect steps** — platform-managed integrations with server-held credentials
- **MCP tool steps** — e.g. `d6e_call_external_api` / `d6e_download_external_file`
  (MCP runs outside the container with a user/session token)
- **Other STF types** that are allowed to call saas-proxy from the platform layer

Pass results into the Docker STF via workflow **input sources** (`sources` on
stdin). See [storage-and-files.md](./storage-and-files.md) for file/binary
inputs.

**To put SaaS binaries into a Docker STF, use a File input step (pre-uploaded
or downloaded into workspace storage) — not `api_token`.** The container cannot
call `saas-proxy-download` or files download APIs. Cross-package recipes:

| Step | Skill / doc |
|------|-------------|
| Download SaaS file into storage (MCP / REST) | [d6e-plugin-skills — saas-and-downloads.md](https://github.com/d6e-ai/d6e-plugin-skills/blob/main/skills/d6e-plugin-development/references/saas-and-downloads.md) |
| End-to-end binary → Docker STF wiring | [d6e-plugin-skills — cross-package-recipes.md](https://github.com/d6e-ai/d6e-plugin-skills/blob/main/skills/d6e-plugin-development/references/cross-package-recipes.md) |
| `saas-proxy-download` REST details | [d6e-custom-frontend-skills — saas-proxy-download.md](https://github.com/d6e-ai/d6e-custom-frontend-skills/blob/main/skills/d6e-workspace-api-client/references/saas-proxy-download.md) |
| File storage + proxy patterns | [d6e-custom-frontend-skills](https://github.com/d6e-ai/d6e-custom-frontend-skills) — `d6e-workspace-api-client` skill |

Typical flow: upstream MCP/Effect/custom-frontend step persists the file →
workflow **File** input step → base64 envelope in Docker stdin `sources` (see
[storage-and-files.md](./storage-and-files.md)). Previous STF JSON output does
**not** substitute for File sources — see
[stdin-sources-vs-steps.md](./stdin-sources-vs-steps.md).

### 2. Direct outbound HTTP from the container

Containers run with `--network=bridge`, so the STF may call **public** external
APIs directly (third-party REST endpoints, public datasets, etc.) using keys
from `secret_keys` / environment variables — **not** via d6e saas-proxy.

Keep secrets in STF encrypted secrets (`secret_keys`); never log `api_token`.

### 3. Custom frontend (out of scope for Docker STF)

A custom frontend's server-side proxy (session JWT or API key) can call
`saas-proxy`, `saas-proxy-download`, and files APIs. That path is documented in
the d6e workspace API client skill — it is not available from inside a Docker
STF container.

## Security reminders

- Treat `api_token` as a secret; never log it or the full stdin JSON
- The token is signed and bound to `{workspace_id, stf_id}`; header values must
  match or the API returns 403
- SQL has no bind parameters — escape string literals and validate identifiers
  (see the main skill's SQL patterns)
