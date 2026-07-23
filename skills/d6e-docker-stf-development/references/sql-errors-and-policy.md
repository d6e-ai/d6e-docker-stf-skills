# SQL errors, naming rules, and STF policy subjects

Docker STFs call workspace SQL through the container `api_token`
(`AuthContext::InternalStf`). Errors and naming rules match the platform SQL
API; policy evaluation uses the **STF** as subject, not the workflow caller.

For the full SQL API surface (preview vs execute, response shapes, proxy
checklists), see the workspace API client reference:

- [d6e-custom-frontend-skills — references/sql.md](https://github.com/d6e-ai/d6e-custom-frontend-skills/blob/main/skills/d6e-workspace-api-client/references/sql.md)

This document focuses on what Docker STF authors hit most often.

## Policy subject: STF, not caller

When the container posts to `POST {api_url}/api/v1/workspaces/{id}/sql` with
`api_token`, the executor evaluates policies as:

```
PolicySubject::Stf(stf_id)   // stf_id from stdin, must be non-nil UUID
```

The workflow user's identity (`caller` on stdin) does **not** substitute for
STF policies. Row-level conditions that reference `$var: user_id` apply in
the **user** subject context; STF execution uses the STF membership in policy
groups instead.

Setup pattern (MCP or REST):

1. Create or update a policy group with the STF in **`stf_ids`** (not only
   `user_ids`).
2. Add **allow** policies per `(table_name, operation)` for that group.
3. Re-run the workflow — `POLICY_DENIED` until both group membership and allow
   policies exist.

Instant-run with **JS code mode** is different (User subject) — see
[instant-run-vs-production.md](./instant-run-vs-production.md). Docker paths
always use Stf subject.

## Common SQL error codes

| Code | HTTP | Meaning for Docker STFs |
|------|------|-------------------------|
| **`POLICY_DENIED`** | 403 | No allow policy for this `stf_id` + table + operation, or row-level condition blocked the statement. **Not** an auth/login failure. |
| **`DDL_FORBIDDEN`** | 403 | DDL attempted without workspace admin or **`ddl_policy_group`** membership. Most STFs should avoid DDL entirely. |
| **`INVALID_TABLE`** | 4xx | Logical table name invalid or **longer than 23 characters**. |
| **`PARSE_ERROR`** | 4xx | SQL syntax rejected before execution. |
| **`EXECUTION_ERROR`** | 5xx / 4xx | Database runtime error after policy checks. |
| **`INVALID_STF_ID`** | 403 | Nil `stf_id` on internal token (should not happen for registered Docker STFs). |

Example error body (forward verbatim to users/agents):

```json
{
  "error": "Policy denied: no allow policy for select on invoices",
  "code": "POLICY_DENIED"
}
```

### `POLICY_DENIED` remediation

1. Confirm the STF uuid in policies matches stdin `stf_id` (registered STF, not
   a draft image-only test).
2. Add the STF to a policy group's **`stf_ids`** array.
3. Create allow policies: `{ table_name, operation: "select"|"insert"|"update"|"delete", mode: "allow" }`.
4. If using row-level conditions, verify they make sense for **Stf** subject
   (see modql below).

Do not retry the same SQL blindly after `POLICY_DENIED` — fix policy or SQL.

### `DDL_FORBIDDEN` remediation

DDL (`CREATE`, `ALTER`, `DROP`, …) requires:

- Workspace **admin** role, **or**
- Membership in the workspace's special policy group named exactly
  **`ddl_policy_group`**

Typical Docker STFs perform DML only. If an STF must create tables, document
that operators need admin or `ddl_policy_group` — or perform DDL in a separate
admin workflow step under a user token.

## Table naming: 23-character logical names

Logical names in SQL are rewritten to:

```
user_data.ws_{uuid_with_underscores}_{logical_name}
```

| Rule | Detail |
|------|--------|
| Max logical name length | **23 characters** |
| Prefix length | 40 characters (`ws_` + UUID with underscores) |
| PostgreSQL identifier cap | 63 → 40 + 23 |

Examples:

- `expense_line_items` (20 chars) ✓
- `expense_line_item_records` (24 chars) ✗ → `INVALID_TABLE`

Use short, stable logical names in STF SQL strings.

## Primary keys: use `uuidv7()`

```sql
CREATE TABLE invoices (
  id UUID PRIMARY KEY DEFAULT uuidv7(),
  amount NUMERIC NOT NULL
);
```

**Do not use `gen_random_uuid()`.** d6e standardizes on time-ordered UUIDv7 for
index locality. Inserts that rely on DB-generated ids should use `uuidv7()` in
DDL and `RETURNING id` on INSERT where needed.

## modql and row-level policies (brief)

Policy **conditions** are **modql** JSON objects (not raw SQL `WHERE` strings).
When the subject is an STF, variables resolve in the STF execution context.

Example allow policy with row filter (conceptual):

```json
{
  "table_name": "orders",
  "operation": "select",
  "mode": "allow",
  "condition": {
    "status": { "$eq": "open" }
  }
}
```

User-scoped conditions often reference context variables:

```json
{
  "owner_id": { "$eq": { "$var": "user_id" } }
}
```

For **`PolicySubject::Stf`**, `user_id` may not match the workflow caller —
design policies explicitly for STF access (e.g. status filters, tenant keys in
`input`, or broad allow for trusted STFs). Test with instant-run under the
registered STF, not only with your personal `d6e_sql` MCP tool (User subject).

Full policy patterns: [d6e-policy skill](https://github.com/d6e-ai/d6e/blob/main/packages/skills/d6e-policy/SKILL.md)
in the main d6e repository.

## Docker STF SQL request checklist

Headers (from stdin — never hardcode):

```
Authorization: Bearer {api_token}
X-Internal-Bypass: true
X-Workspace-ID: {workspace_id}
X-STF-ID: {stf_id}
Content-Type: application/json
```

Body:

```json
{ "sql": "SELECT id, amount FROM invoices WHERE status = 'open' LIMIT 100" }
```

Restrictions:

- Single statement per request
- No bind parameters — escape literals and validate identifiers in application
  code (see main skill SQL patterns)
- No DDL unless operator grants admin / `ddl_policy_group`
- DML/SELECT require STF allow policies

## Related docs

- `api_token` boundary (SQL-only): [external-apis.md](./external-apis.md)
- Instant-run User vs Stf policy: [instant-run-vs-production.md](./instant-run-vs-production.md)
- Platform SQL reference: [sql.md (custom-frontend-skills)](https://github.com/d6e-ai/d6e-custom-frontend-skills/blob/main/skills/d6e-workspace-api-client/references/sql.md)
- Granting policies in MCP: [SKILL.md](../SKILL.md) — "Granting SQL access (policies)"
