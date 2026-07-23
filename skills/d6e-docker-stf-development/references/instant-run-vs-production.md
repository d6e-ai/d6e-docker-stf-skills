# Instant-run, describe, and production policy differences

Docker STFs are always executed as **registered STFs** with a real `stf_id`.
Policy and auth behavior diverges mainly between **how you invoke** the STF
(instant-run / describe / workflow) and between **Docker** vs **JS code mode**
instant-run (JS-only).

## Execution modes compared

| Mode | API / tool | STF identity | SQL policy subject | Stdin `caller` |
|------|------------|--------------|-------------------|----------------|
| **Workflow step** | `d6e_execute_workflow` | Registered `stf_version_id` | `PolicySubject::Stf(stf_id)` via container `api_token` | Executing user's UUID, or `null` if anonymous |
| **Instant-run (stf_ref)** | `POST …/stfs/instant-run` with `stf_id` / `stf_version_id` | Registered STF | `PolicySubject::Stf(stf_id)` via `api_token` | Authenticated user's UUID |
| **Instant-run (code mode, JS only)** | `d6e_instant_run_stf` with `runtime` + `code` | Ephemeral (nil sentinel `stf_id`) | **`PolicySubject::User(user_id)`** — user's SQL policies | Authenticated user's UUID |
| **Describe** | `POST …/stfs/{id}/describe` / `d6e_describe_stf` | Registered STF, **latest version only** | `PolicySubject::Stf(stf_id)` if describe touches SQL | **`null` always** |

Docker STFs **cannot** use JS code mode. Smoke-testing a Docker image always
goes through **stf_ref** instant-run or a workflow step after
`d6e_create_stf`.

## Code mode (JS) vs registered Docker STF — SQL policies

### JS instant-run code mode → User policies

When instant-run receives inline JavaScript (`runtime` + `code`, no
`stf_id`), the engine uses a temporary version with `stf_id = nil` and
evaluates SQL as the **authenticated user** (`PolicySubject::User`).

Implications:

- Policies attached to **users** and their policy groups apply.
- Policies that only grant the **saved STF** (`stf_ids` in a policy group)
  do **not** apply in code mode.
- Useful for admin iteration; **not** representative of production Docker
  behavior.

### Registered Docker STF (workflow, stf_ref instant-run, describe) → STF policies

When a Docker container runs, SQL calls use `api_token`
(`AuthContext::InternalStf`). The SQL endpoint evaluates
**`PolicySubject::Stf(stf_id)`** — the registered STF must appear in a
policy group's `stf_ids` with allow policies for each table + operation.

Implications:

- User-only policies do **not** satisfy container SQL unless the same access
  is granted to the STF (or a group containing it).
- A smoke test that passes under your personal user SQL access can still
  fail with `POLICY_DENIED` in the container until STF policies exist.
- See [sql-errors-and-policy.md](./sql-errors-and-policy.md) and the main
  skill section "Granting SQL access (policies)".

```
JS code-mode instant-run          Docker STF (workflow / stf_ref / describe)
────────────────────────          ─────────────────────────────────────────
sql() → User policies             api_token → Stf(stf_id) policies
stf_id nil (sentinel)             real stf_id from registration
Good for drafting JS              Production path for Docker images
```

## Describe-specific behavior

`POST /api/v1/stfs/{id}/describe` (and MCP `d6e_describe_stf`):

1. **Latest version only** — loads the most recently created version for that
   `stf_id`. There is no request body to pin an older semver; publishing a new
   version changes describe output immediately.
2. **`caller: null` in stdin** — the engine passes `None` as caller to the
   container. Do not implement describe logic that depends on `$caller` or
   stdin `caller` being set.
3. **Empty `sources`** — describe runs with `{"operation":"describe"}` and
   `{}` sources regardless of workflow input steps.
4. **Docker runtime only** — non-Docker STFs return an error from the describe
   endpoint.

### Safe describe implementation

```python
def process_describe():
    # Do not branch on caller — it is null for describe runs
    return {
        "status": "success",
        "operation": "describe",
        "data": {
            "input_schema": { ... },
            "operations": { ... },
        },
    }
```

If an operation needs the executing user at runtime, read `caller` from stdin
**only in non-describe operations** during workflow or instant-run — and remember
SQL still uses STF policies, not user row filters tied to `caller`.

## Instant-run version selection

| Parameter | Version used |
|-----------|--------------|
| `stf_version_id` | Exact pinned version |
| `stf_id` only | Latest version (`created_at DESC`, same as describe) |
| Workflow step | `stf_version_id` on the step (or latest-resolve rules if unpinned — see d6e workflow skill) |

For reproducible CI, pass **`stf_version_id`** explicitly in instant-run rather
than relying on latest.

## Testing checklist

Before declaring a Docker STF production-ready:

1. **`d6e_describe_stf`** — schema discovery; expect `caller: null` behavior.
2. **`d6e_instant_run_stf` with `stf_id`** — real container path with **STF**
   SQL policies (not your user policies alone).
3. **Workflow execution** — full `input_mappings`, `$steps[n]` → `input`, input
   steps → `sources` (see [stdin-sources-vs-steps.md](./stdin-sources-vs-steps.md)).
4. **Policy setup** — STF in `stf_ids` with allow policies for every table the
   container touches.

## Related docs

- Stdin `sources` vs `$steps[n]`: [stdin-sources-vs-steps.md](./stdin-sources-vs-steps.md)
- SQL errors and STF policy setup: [sql-errors-and-policy.md](./sql-errors-and-policy.md)
- MCP / REST instant-run: [SKILL.md](../SKILL.md) — "Verifying with describe / instant run"
- JS code-mode instant-run (User policies): [d6e-plugin-skills local AI development](https://github.com/d6e-ai/d6e-plugin-skills/blob/main/docs/local-ai-development.md)
