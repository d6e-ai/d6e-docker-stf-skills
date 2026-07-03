---
name: d6e-docker-stf-development
description: Creates custom Docker-based State Transition Functions (STFs) for D6E platform workflows. Use when building containerized business logic for D6E, implementing data processing steps, or creating workflow functions that need database access. Handles JSON input/output, SQL API integration, and multi-language implementations (Python, Node.js, Go).
---

# D6E Docker STF Development

## Overview

Docker STFs are containerized applications that execute as workflow steps in D6E. They read JSON from stdin, process data with custom logic, access workspace databases via internal API, and output JSON to stdout.

## When to Use

Apply this skill when users request:

- "Create a D6E Docker STF that..."
- "Build a custom STF for D6E that..."
- "I need a Docker-based workflow step..."
- "Help me create a data processing function for D6E"

## Core Concepts

### Input Format

Docker STFs receive this JSON via stdin:

```json
{
  "workspace_id": "UUID",
  "stf_id": "UUID",
  "caller": "UUID | null",
  "api_url": "http://host.docker.internal:8080",
  "api_token": "<signed short-lived token generated per execution>",
  "input": {
    "operation": "...",
    ...user-defined parameters
  },
  "sources": {
    "step_name": <resolved input step value>
  }
}
```

Notes:

- `api_url` points back at the d6e API from inside the container. The
  default is `http://host.docker.internal:8080` (the d6e operator can
  override it with the `D6E_API_URL_FOR_DOCKER` env var). Never hardcode
  it — always read it from stdin.
- `api_token` is a signed, per-execution token scoped to this
  workspace + STF. Treat it as a secret; never log it.
- `sources` maps each workflow **input step name** directly to its
  resolved value — there is **no** `{"output": ...}` wrapper. The value
  shape depends on the input source type:
  - `Library` → `{ "code": "...", "types": "...", "version": "..." }`
  - `File` (JSON content type) → the parsed JSON value
  - `File` (text content type) → the file body as a string
  - `File` (binary) → `{ "filename", "content_type", "size", "data": "<base64>" }`
  - `Fetch` → the parsed JSON response body

### Output Format

**Success:** print exactly one JSON document to stdout and exit 0:

```json
{
  "output": {
    "status": "success",
    ...custom result data
  }
}
```

The engine parses the **entire stdout** as a single JSON document with
a top-level `output` key. Anything else on stdout (log lines, progress
messages, a second JSON document) causes an
`Invalid Docker output format` error. All logging must go to stderr.

**Error:** write a detailed message to **stderr** and exit non-zero:

```python
print(f"ValidationError: missing required field 'operation'", file=sys.stderr)
sys.exit(1)
```

On a non-zero exit code, d6e reports the workflow step as failed with
the container's **stderr** as the error message. A JSON body like
`{"error": ...}` printed to stdout is NOT parsed — put the
human-readable failure reason on stderr, because that is what the user
(and the calling AI agent) will see.

### SQL API Access

Execute SQL via internal API:

**Endpoint:** `POST {api_url}/api/v1/workspaces/{workspace_id}/sql`

**Headers:**

```
Authorization: Bearer {api_token}
X-Internal-Bypass: true
X-Workspace-ID: {workspace_id}
X-STF-ID: {stf_id}
```

`api_url`, `api_token`, `workspace_id`, and `stf_id` all come from the
stdin input — never hardcode them.

**Request:**

```json
{ "sql": "SELECT * FROM my_table LIMIT 10" }
```

**Response:**

- `SELECT` → `{ "rows": [ {...}, ... ] }`
- `INSERT` / `UPDATE` / `DELETE` → `{ "affected_rows": <number> }`

**Restrictions:**

- No DDL (CREATE, DROP, ALTER) — error code `DDL_FORBIDDEN`
- Policy-controlled access — without an allow policy for the table +
  operation, the call fails with error code `POLICY_DENIED`
- Workspace scope only. Use plain table names (`leads`, `messages`);
  d6e transparently rewrites them to the workspace's private schema.
  Table names must be **23 characters or less**.

## Quick Start

### Python Implementation

**main.py:**

```python
#!/usr/bin/env python3
import sys
import json
import requests
import logging

logging.basicConfig(stream=sys.stderr, level=logging.INFO)

def execute_sql(api_url, api_token, workspace_id, stf_id, sql):
    """Execute SQL via D6E internal API"""
    url = f"{api_url}/api/v1/workspaces/{workspace_id}/sql"
    headers = {
        "Authorization": f"Bearer {api_token}",
        "X-Internal-Bypass": "true",
        "X-Workspace-ID": workspace_id,
        "X-STF-ID": stf_id,
        "Content-Type": "application/json"
    }
    response = requests.post(url, json={"sql": sql}, headers=headers)
    response.raise_for_status()
    return response.json()

def process_describe():
    """Return the input schema and available operations."""
    return {
        "status": "success",
        "operation": "describe",
        "data": {
            "input_schema": {
                "type": "object",
                "properties": {
                    "operation": {
                        "type": "string",
                        "enum": ["your_operation", "describe"],
                        "description": "The operation to perform"
                    }
                },
                "required": ["operation"]
            },
            "operations": {
                "your_operation": {
                    "description": "Your operation description",
                    "required": [],
                    "optional": []
                },
                "describe": {
                    "description": "Returns the input schema and available operations",
                    "required": [],
                    "optional": []
                }
            }
        }
    }

def main():
    try:
        input_data = json.load(sys.stdin)
        user_input = input_data["input"]
        operation = user_input.get("operation")

        # Handle describe before any other validation
        if operation == "describe":
            result = process_describe()
        else:
            # Your business logic here
            result = {"status": "success", "message": "Processed"}

        print(json.dumps({"output": result}))
    except Exception as e:
        # The error message MUST go to stderr — d6e reports stderr as
        # the step's failure reason when the exit code is non-zero.
        logging.error(f"{type(e).__name__}: {str(e)}", exc_info=True)
        sys.exit(1)

if __name__ == "__main__":
    main()
```

**Dockerfile:**

```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY main.py .
RUN chmod +x main.py
ENTRYPOINT ["python3", "main.py"]
```

**requirements.txt:**

```
requests>=2.31.0
```

### Node.js Implementation

**index.js:**

```javascript
const axios = require("axios");

async function executeSql(apiUrl, apiToken, workspaceId, stfId, sql) {
  const response = await axios.post(
    `${apiUrl}/api/v1/workspaces/${workspaceId}/sql`,
    { sql },
    {
      headers: {
        Authorization: `Bearer ${apiToken}`,
        "X-Internal-Bypass": "true",
        "X-Workspace-ID": workspaceId,
        "X-STF-ID": stfId,
        "Content-Type": "application/json",
      },
    }
  );
  return response.data;
}

function processDescribe() {
  return {
    status: "success",
    operation: "describe",
    data: {
      input_schema: {
        type: "object",
        properties: {
          operation: {
            type: "string",
            enum: ["your_operation", "describe"],
            description: "The operation to perform",
          },
        },
        required: ["operation"],
      },
      operations: {
        your_operation: {
          description: "Your operation description",
          required: [],
          optional: [],
        },
        describe: {
          description: "Returns the input schema and available operations",
          required: [],
          optional: [],
        },
      },
    },
  };
}

async function main() {
  try {
    const input = await readStdin();
    const data = JSON.parse(input);
    const { operation } = data.input;

    // Handle describe before any other validation
    let result;
    if (operation === "describe") {
      result = processDescribe();
    } else {
      // Your business logic here
      result = { status: "success", message: "Processed" };
    }

    console.log(JSON.stringify({ output: result }));
  } catch (error) {
    // The error message MUST go to stderr — d6e reports stderr as
    // the step's failure reason when the exit code is non-zero.
    console.error(`${error.name}: ${error.message}`);
    process.exit(1);
  }
}

function readStdin() {
  return new Promise((resolve) => {
    let data = "";
    process.stdin.on("data", (chunk) => (data += chunk));
    process.stdin.on("end", () => resolve(data));
  });
}

main();
```

**Dockerfile:**

```dockerfile
FROM node:18-slim
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY index.js .
ENTRYPOINT ["node", "index.js"]
```

## Implementation Checklist

When creating a Docker STF, ensure:

- [ ] Reads JSON from stdin
- [ ] Outputs exactly ONE JSON document to stdout (`{"output": {...}}`) — nothing else
- [ ] Logs to stderr (stdout is for the result only)
- [ ] On failure: writes the reason to stderr and exits non-zero (d6e surfaces stderr as the error)
- [ ] Uses small base images (e.g., `python:3.11-slim`)
- [ ] Validates input parameters
- [ ] Reads `api_url` / `api_token` / `workspace_id` / `stf_id` from stdin (never hardcoded)
- [ ] Uses environment variables for configuration; secrets are declared via `secret_keys` (see "Registering the STF in d6e")
- [ ] Implements the `describe` operation (returns input schema and available operations)
- [ ] Finishes within the execution timeout (default 5 minutes)

## Best Practices

### Security

- Never log sensitive data (tokens, passwords)
- Validate all user inputs
- Use parameterized SQL queries
- Keep dependencies up-to-date

### Performance

- Use multi-stage builds to reduce image size
- Minimize dependencies
- Add `.dockerignore` to exclude unnecessary files
- Cache pip/npm installations

### Error Handling

d6e decides success/failure from the **exit code** and reports the
container's **stderr** as the failure reason. So: successful runs print
the `{"output": ...}` JSON to stdout and exit 0; failed runs write a
descriptive message to stderr and exit non-zero.

```python
try:
    # Your logic
    result = process_data(input_data)
    print(json.dumps({"output": result}))
except ValueError as e:
    # Validation errors — the stderr text is what users will see
    logging.error(f"ValidationError: {str(e)} (input={user_input})")
    sys.exit(1)
except Exception as e:
    # Unexpected errors
    logging.error(f"{type(e).__name__}: {str(e)}", exc_info=True)
    sys.exit(1)
```

Recoverable, domain-level "failures" that the workflow should continue
from (e.g. "no matching rows") are not errors — return them inside
`output` with a status field and exit 0.

### Logging

```python
import logging

# Log to stderr
logging.basicConfig(
    stream=sys.stderr,
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

logging.info("Processing started")
logging.debug(f"Input: {input_data}")  # Detailed logs
logging.warning("Deprecated operation used")
logging.error("Failed to process", exc_info=True)
```

## The `describe` Operation

Every Docker STF **must** implement a `describe` operation. This operation returns the input schema and available operations, enabling workflow builders and AI agents to discover what parameters are needed before creating workflows.

### Why `describe` is Required

- **Discoverability**: Workflow builders can query the STF to understand its capabilities without reading source code
- **Automation**: AI agents can automatically generate correct `input_mappings` for workflows
- **Validation**: The schema enables pre-execution validation of workflow inputs
- **Documentation**: Acts as machine-readable, always up-to-date documentation

### `describe` Request

```json
{
  "input": {
    "operation": "describe"
  }
}
```

### `describe` Response Format

```json
{
  "output": {
    "status": "success",
    "operation": "describe",
    "data": {
      "input_schema": {
        "type": "object",
        "properties": {
          "operation": {
            "type": "string",
            "enum": ["op1", "op2", "describe"],
            "description": "The operation to perform"
          }
        },
        "required": ["operation"]
      },
      "operations": {
        "op1": {
          "description": "Description of operation 1",
          "required": ["param1", "param2"],
          "optional": ["param3"]
        },
        "op2": {
          "description": "Description of operation 2",
          "required": ["param1"],
          "optional": []
        },
        "describe": {
          "description": "Returns the input schema and available operations",
          "required": [],
          "optional": []
        }
      }
    }
  }
}
```

### Implementation Pattern (Python)

```python
def process_describe():
    """Return the input schema and available operations."""
    return {
        "status": "success",
        "operation": "describe",
        "data": {
            "input_schema": {
                "type": "object",
                "properties": {
                    "operation": {
                        "type": "string",
                        "enum": ["my_operation", "describe"],
                        "description": "The operation to perform"
                    },
                    "param1": {
                        "type": "string",
                        "description": "Description of param1"
                    }
                },
                "required": ["operation"]
            },
            "operations": {
                "my_operation": {
                    "description": "What this operation does",
                    "required": ["param1"],
                    "optional": []
                },
                "describe": {
                    "description": "Returns the input schema and available operations",
                    "required": [],
                    "optional": []
                }
            }
        }
    }

def main():
    input_data = json.load(sys.stdin)
    user_input = input_data["input"]
    operation = user_input.get("operation")

    # Handle describe before any other validation
    if operation == "describe":
        result = process_describe()
    else:
        # Validate and process other operations
        ...

    print(json.dumps({"output": result}))
```

### Best Practice: Workflow Creation with `describe`

When creating workflows that use Docker STFs, always follow this process:

1. **Run `describe` first** to get the input schema
2. **Map all required parameters** in `input_mappings` based on the schema
3. **Include optional parameters** where appropriate

```bash
# Step 1: Discover the STF's capabilities
echo '{"workspace_id":"...","stf_id":"...","caller":null,"api_url":"...","api_token":"...","input":{"operation":"describe"},"sources":{}}' \
  | docker run --rm -i my-stf:latest

# Step 2: Use the returned schema to build the workflow input_mappings
```

## Common Patterns

### Data Validation Pattern

```python
def validate_input(user_input):
    required_fields = ["operation", "table_name"]
    for field in required_fields:
        if field not in user_input:
            raise ValueError(f"Missing required field: {field}")

    if user_input["operation"] not in ["query", "insert", "update"]:
        raise ValueError(f"Invalid operation: {user_input['operation']}")

    return True

# Usage
try:
    validate_input(input_data["input"])
except ValueError as e:
    print(f"ValidationError: {e}", file=sys.stderr)
    sys.exit(1)
```

### Database Query Pattern

```python
def safe_query(api_context, table_name, filters):
    """Execute a safe parameterized query"""
    # Build WHERE clause safely
    where_conditions = []
    for key, value in filters.items():
        # Simple validation
        if not key.isidentifier():
            raise ValueError(f"Invalid column name: {key}")
        where_conditions.append(f"{key} = '{value}'")

    where_clause = " AND ".join(where_conditions) if where_conditions else "1=1"
    sql = f"SELECT * FROM {table_name} WHERE {where_clause} LIMIT 100"

    return execute_sql(
        api_context["api_url"],
        api_context["api_token"],
        api_context["workspace_id"],
        api_context["stf_id"],
        sql
    )
```

### External API Pattern

```python
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

def create_session():
    """Create session with retry logic"""
    session = requests.Session()
    retry = Retry(
        total=3,
        backoff_factor=0.3,
        status_forcelist=[500, 502, 503, 504]
    )
    adapter = HTTPAdapter(max_retries=retry)
    session.mount('http://', adapter)
    session.mount('https://', adapter)
    return session

def call_external_api(url, params):
    """Call external API with error handling"""
    session = create_session()
    try:
        response = session.get(url, params=params, timeout=10)
        response.raise_for_status()
        return response.json()
    except requests.Timeout:
        raise Exception("External API timeout")
    except requests.RequestException as e:
        raise Exception(f"External API error: {str(e)}")
```

## Testing Locally

### Build and Test

```bash
# Build image
docker build -t my-stf:latest .

# Test describe operation first (always start with describe)
echo '{
  "workspace_id": "test-id",
  "stf_id": "test-stf-id",
  "caller": null,
  "api_url": "http://localhost:8080",
  "api_token": "test-token",
  "input": {
    "operation": "describe"
  },
  "sources": {}
}' | docker run --rm -i my-stf:latest

# Test with sample input
echo '{
  "workspace_id": "test-id",
  "stf_id": "test-stf-id",
  "caller": null,
  "api_url": "http://localhost:8080",
  "api_token": "test-token",
  "input": {
    "operation": "test"
  },
  "sources": {}
}' | docker run --rm -i my-stf:latest
```

### Debug Mode

```bash
# Run with interactive shell
docker run --rm -it --entrypoint /bin/bash my-stf:latest

# Check image size
docker images my-stf:latest

# Inspect logs
docker run --rm -i my-stf:latest < input.json 2>&1 | tee output.log
```

## Registering and Running in d6e

### Credentials you need first

Everything below needs a **workspace id** and a **Bearer token** for the
d6e REST API (or an AI-agent session inside d6e, where the MCP tools
handle auth for you). Any workspace member can obtain both — no
d6e-auth admin involvement:

- **Workspace ID**: the UUID in every d6e console URL
  (`{D6E_BASE_URL}/{locale}/workspaces/{uuid}/...`); the workspace
  settings page's Integration section also shows it with a copy button
  (admin view).
- **Bearer token**: copy the `auth-token` cookie from a logged-in d6e
  console session (~1 h lifetime), or mint a long-lived API key with it
  (`POST /api/v1/api-keys` `{"name":"dev"}` → returns a `d6e_...` key
  that works as the Bearer value). For scripts, the `auth-refresh`
  cookie can be exchanged at `POST /api/v1/auth/token`
  (`{"grant_type":"refresh_token","refresh_token":"..."}`) — it rotates
  on each use.

Send the workspace as an `X-Workspace-ID: {workspace_id}` header on
every request; STF endpoints are **not** nested under
`/workspaces/{id}/` in the URL.

### Docker config JSON (the STF `code` field)

A Docker STF's "code" is not source code — it is a JSON configuration
that tells d6e which image to run:

```json
{
  "image": "ghcr.io/your-org/your-stf:v1.0.0",
  "command": ["python3", "main.py"],
  "env": {
    "LOG_LEVEL": "info",
    "EXTERNAL_API_KEY": "placeholder"
  },
  "secret_keys": ["EXTERNAL_API_KEY"]
}
```

| Field         | Type          | Required | Description                                                                                                          |
| ------------- | ------------- | -------- | -------------------------------------------------------------------------------------------------------------------- |
| `image`       | String        | ✓        | Docker image reference. Must be pullable by the d6e host (public registry, or pre-pulled on the same Docker daemon). |
| `command`     | Array[String] | -        | Override the container CMD. Must be an **array of strings**, not a single string.                                     |
| `env`         | Object        | -        | Environment variables injected at `docker run` time. Keys must match `[A-Za-z_][A-Za-z0-9_]*`.                        |
| `secret_keys` | Array[String] | -        | Keys from `env` whose real values are stored encrypted (see below). The `env` value for these keys is a placeholder.  |

### Encrypted secrets for API keys

Never put real API keys in the config JSON — it is stored (and often
version-controlled) in plain text. Instead:

1. List the key name in both `env` (with a placeholder value) and
   `secret_keys`.
2. Store the real value via the secrets API (workspace admin only):

```
POST {D6E_BASE_URL}/api/v1/stfs/{stf_id}/secrets
Authorization: Bearer {jwt}
X-Workspace-ID: {workspace_id}

{ "env_key": "EXTERNAL_API_KEY", "value": "sk-real-value" }
```

`GET /api/v1/stfs/{stf_id}/secrets` lists key names only (values are
never returned); `DELETE /api/v1/stfs/{stf_id}/secrets/{env_key}`
removes one. At runtime d6e decrypts the stored value and injects it as
the environment variable; a key listed in `secret_keys` without a
stored value fails the execution with a clear error.

If the STF is installed as part of a d6e Plugin (`template.yaml`), the
install dialog in the d6e console asks the installing admin for these
values and stores them as secrets automatically — see the
`d6e-plugin-development` skill.

### Creating the STF

**Via MCP tools (AI agent inside d6e):** `d6e_create_stf` creates the
STF *and* its first version in one call:

```javascript
d6e_create_stf({
  name: "my-stf",
  description: "What this STF does",
  version: "1.0.0",            // plain semver, no "v" prefix
  runtime: "docker",
  code: '{"image":"ghcr.io/your-org/your-stf:v1.0.0"}',  // config JSON as a string
});
// → returns the created STF; note its id and version id
```

Ship an updated image under a new tag with `d6e_create_stf_version`:

```javascript
d6e_create_stf_version({
  stf_id: "{stf_id}",
  version: "1.1.0",
  runtime: "docker",
  code: '{"image":"ghcr.io/your-org/your-stf:v1.1.0"}',
});
```

**Via REST API:** `POST /api/v1/stfs` with the same fields, except
`code` must be **base64-encoded**:

```
POST {D6E_BASE_URL}/api/v1/stfs
Authorization: Bearer {jwt}
X-Workspace-ID: {workspace_id}

{
  "name": "my-stf",
  "description": "What this STF does",
  "version": "1.0.0",
  "runtime": "docker",
  "code": "<base64 of the config JSON>"
}
```

### Verifying with describe / instant run

Before wiring the STF into a workflow, verify it end-to-end:

```javascript
// Runs the container with {"operation": "describe"} and returns the schema
d6e_describe_stf({ id: "{stf_id}" });

// Runs the STF once with arbitrary input — no workflow needed.
// input must be a JSON value, NOT an escaped JSON string.
d6e_instant_run_stf({
  stf_id: "{stf_id}",
  input: { operation: "your_operation", param1: "value1" },
});
```

REST equivalents: `POST /api/v1/stfs/{id}/describe` (no body) and
`POST /api/v1/stfs/instant-run` with
`{ "stf_id": "...", "input": {...}, "sources": {} }`. Both return
`{ success, output | data, error }` — a failed container run comes back
as `success: false` with the stderr text in `error` instead of an HTTP
error.

### Wiring into a workflow

Workflow STF steps reference a **specific STF version** by
`stf_version_id` (not by name or stf_id):

```javascript
d6e_create_workflow({
  name: "my-stf-workflow",
  input_steps: [],
  stf_steps: [
    {
      stf_version_id: "{version id from d6e_create_stf / d6e_list_stf_versions}",
      input_mappings: [
        { source: { type: "Variable", value: "$input.operation" }, target: "operation" },
        { source: { type: "Variable", value: "$input.param1" }, target: "param1" },
      ],
    },
  ],
  effect_steps: [],
});

d6e_execute_workflow({
  id: "{workflow_id}",
  input: { operation: "your_operation", param1: "value1" },
});
```

Variable paths must start with `$input` (workflow input),
`$sources.{step_name}` (input step results), or `$steps[n]` (0-based
output of a previous STF step). A path that resolves to a missing field
maps to `null` rather than failing.

### Granting SQL access (policies)

A Docker STF has **no table access by default** — SQL calls fail with
`POLICY_DENIED` until the STF is added to a policy group that has allow
policies. Membership is set through the `stf_ids` array (there is no
separate "add member" tool):

```javascript
// Create a policy group with the STF as a member
d6e_create_policy_group({
  name: "my-stf-policies",
  user_ids: [],
  stf_ids: ["{stf_id}"],
});

// Or add the STF to an existing group
d6e_update_policy_group({
  id: "{policy_group_id}",
  stf_ids: ["{stf_id}", "...existing ids"],
});

// Grant one policy per table x operation
d6e_create_policy({
  name: "my-stf can read my_table",
  policy_group_id: "{policy_group_id}",
  table_name: "my_table",
  operation: "select",       // select | insert | update | delete
  mode: "allow",             // allow | deny
});
```

Row-level restrictions use the optional `condition` field (a modql JSON
object, e.g. `{"owner_id": {"$eq": {"$var": "user_id"}}}`), not a SQL
`WHERE` string.

### Execution limits

| Limit          | Default   | Operator override            |
| -------------- | --------- | ----------------------------- |
| Execution time | 5 minutes | `STF_DOCKER_TIMEOUT_SECS`     |
| stdout/stderr  | 10 MB     | `STF_DOCKER_MAX_OUTPUT_BYTES` |

Containers run with `--rm -i --network=bridge` and
`--add-host=host.docker.internal:host-gateway`, so outbound network
access is available for external API calls.

## Troubleshooting

### Issue: "POLICY_DENIED" error on SQL calls

**Cause:** The STF is not a member of any policy group with an allow
policy for that table + operation.

**Solution:** Create a policy group with the STF in `stf_ids` and add
policies (see [Granting SQL access](#granting-sql-access-policies)):

```javascript
d6e_create_policy_group({
  name: "my-stf-group",
  user_ids: [],
  stf_ids: ["{stf_id}"],
});

d6e_create_policy({
  name: "my-stf select my_table",
  policy_group_id: "{group_id}",
  table_name: "my_table",
  operation: "select",
  mode: "allow",
});
```

Note: there is no `d6e_add_member_to_policy_group` tool — membership
is the `stf_ids` / `user_ids` arrays on
`d6e_create_policy_group` / `d6e_update_policy_group`.

### Issue: "Invalid Docker output format" / output not appearing in D6E

**Cause:** stdout is not a single `{"output": ...}` JSON document.

**Solution:** Always use `{"output": {...}}` format and keep every log
line on stderr:

```python
# ✅ Correct
print(json.dumps({"output": {"status": "success"}}))

# ❌ Wrong: missing the "output" wrapper
print(json.dumps({"status": "success"}))

# ❌ Wrong: extra stdout noise breaks JSON parsing
print("Processing started...")
print(json.dumps({"output": {"status": "success"}}))
```

### Issue: "Image not found" in D6E

**Cause:** Image not accessible from D6E API server.

**Solution:**

1. Publish to container registry (GitHub, Docker Hub)
2. Or ensure same Docker daemon as D6E API server

### Issue: Large image size

**Solution:** Use multi-stage builds:

```dockerfile
# Build stage
FROM python:3.11 AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

# Runtime stage
FROM python:3.11-slim
WORKDIR /app
COPY --from=builder /root/.local /root/.local
COPY main.py .
ENV PATH=/root/.local/bin:$PATH
ENTRYPOINT ["python3", "main.py"]
```

## File Requirements

Every Docker STF should include:

```
my-stf/
├── main.py (or index.js, main.go)  # Entry point
├── Dockerfile                       # Container definition
├── requirements.txt (or package.json, go.mod)  # Dependencies
├── .dockerignore                    # Exclude files
└── README.md                        # Documentation
```

**.dockerignore:**

```
.git
.gitignore
*.md
tests/
__pycache__/
*.pyc
node_modules/
.env
```

## README Template for D6E AI Agent Users

When publishing a Docker STF, include a comprehensive README that enables D6E AI agents to automatically create and execute workflows. The README should follow this structure:

### Required README Sections

1. **Title and Description** - Clear name and purpose of the STF
2. **Docker Image URL** - Full path (e.g., `ghcr.io/d6e-ai/stf-xxx:latest`)
3. **LLM/AI Agent Usage Instructions** - Step-by-step STF creation guide
4. **Supported Operations** - Table of available operations with parameters
5. **Input/Output Examples** - Concrete JSON examples for each operation
6. **AI Agent Prompts** - Ready-to-use prompts for common tasks
7. **Troubleshooting** - Common issues and solutions
8. **Local Build and Test** - Commands for local development

### README Template

Use the following template for your Docker STF README:

````markdown
# {STF Name}

{Brief description of what this STF does}

**Docker Image**: `ghcr.io/{org}/{stf-name}:latest`

## Usage for LLM/AI Agents

To use this Docker image from a D6E AI agent, follow these steps to create and execute the STF.

### Step 1: Create the STF (with its first version)

`d6e_create_stf` creates the STF and its first version in a single call:

```javascript
d6e_create_stf({
  name: "{stf-name}",
  description: "{Description of the STF functionality}",
  version: "1.0.0",
  runtime: "docker",
  code: '{"image":"ghcr.io/{org}/{stf-name}:latest"}',
});
// → note the returned STF id
```

**Important**: Always set `runtime` to `"docker"` and format the `code` field as a JSON string: `{"image":"ghcr.io/{org}/{stf-name}:latest"}`.

### Step 2: Discover the STF's Capabilities (describe)

Run `describe` to get the full input schema before creating any workflow:

```javascript
d6e_describe_stf({ id: "{stf_id}" });
```

Use the returned schema to confirm required/optional parameters for each operation.

### Step 3: Smoke-Test with Instant Run (optional but recommended)

```javascript
d6e_instant_run_stf({
  stf_id: "{stf_id}",
  input: { operation: "{operation_name}", param1: "value1" },
});
```

### Step 4: Create the Workflow

Look up the version id (`d6e_list_stf_versions({ stf_id })` or the create response), then reference it via `stf_version_id`:

```javascript
d6e_create_workflow({
  name: "{stf-name}-workflow",
  input_steps: [],
  stf_steps: [
    {
      stf_version_id: "{stf_version_id}",
      input_mappings: [
        { source: { type: "Variable", value: "$input.operation" }, target: "operation" },
        { source: { type: "Variable", value: "$input.param1" }, target: "param1" },
      ],
    },
  ],
  effect_steps: [],
});
```

### Step 5: Execute the Workflow

```javascript
d6e_execute_workflow({
  id: "{workflow_id}",
  input: {
    operation: "{operation_name}",
    // ...operation-specific parameters (based on describe output)
  },
});
```

## Supported Operations

| Operation       | Required Parameters | Optional    | DB Required | Description                                   |
| --------------- | ------------------- | ----------- | ----------- | --------------------------------------------- |
| `describe`      | -                   | -           | ❌          | Returns input schema and available operations |
| `{operation_1}` | `param1`, `param2`  | `optional1` | ❌/✅       | {Description}                                 |
| `{operation_2}` | `param1`            | -           | ❌/✅       | {Description}                                 |

## Input/Output Examples

### {Operation Name}

**Input**:

```json
{
  "operation": "{operation_name}",
  "param1": "value1",
  "param2": "value2"
}
```

**Output**:

```json
{
  "output": {
    "status": "success",
    "operation": "{operation_name}",
    "data": {
      // ... result data
    }
  }
}
```

## 🤖 Prompts for AI Agents

### Basic Prompt

```
Use the Docker skill for {task description} in D6E.

Docker Image: ghcr.io/{org}/{stf-name}:latest

Steps:
1. Create STF with d6e_create_stf (one call creates STF + first version):
   - name: "{stf-name}"
   - version: "1.0.0"
   - runtime: "docker"
   - code: "{\"image\":\"ghcr.io/{org}/{stf-name}:latest\"}"
2. Run d6e_describe_stf to discover the input schema
3. Smoke-test with d6e_instant_run_stf
4. Create workflow with d6e_create_workflow (stf_steps reference stf_version_id)
5. Execute with d6e_execute_workflow

Supported operations:
- "describe": Returns input schema and available operations (run this first)
- "{operation_1}": {description} (required: {required_params})
- "{operation_2}": {description} (required: {required_params})

Start with describe to verify the setup and discover parameters.
```

### Task-Specific Prompt

```
{Specific task description}

Skill to use:
- Docker Image: ghcr.io/{org}/{stf-name}:latest
- Operation: {operation_name}

Parameters:
- param1: "value1"
- param2: "value2"

Include the following in the results:
- {Expected output item 1}
- {Expected output item 2}
```

### Complete Execution Prompt

```
{Complete workflow description}

Docker Image: ghcr.io/{org}/{stf-name}:latest

Execution steps:
1. Create STF (name: "{stf-name}", version: "1.0.0", runtime: "docker",
   code: JSON string with the image reference)

2. Run d6e_describe_stf to discover available operations and parameters

3. {First operation description}:
   - operation: "{operation_1}"
   - param1: value1
   - param2: value2

4. {Second operation description}:
   - operation: "{operation_2}"
   - param1: value1

5. Display results:
   - {Output item 1}
   - {Output item 2}

{Additional instructions or requests}
```

## Troubleshooting

### {Common Issue 1}

{Description and solution}

### {Common Issue 2}

{Description and solution}

## Local Build and Test

```bash
# Build
docker build -t {stf-name}:latest .

# Test describe first (verify input schema)
echo '{
  "workspace_id": "test-ws",
  "stf_id": "test-stf",
  "caller": null,
  "api_url": "http://localhost:8080",
  "api_token": "test-token",
  "input": {
    "operation": "describe"
  },
  "sources": {}
}' | docker run --rm -i {stf-name}:latest

# Test operation
echo '{
  "workspace_id": "test-ws",
  "stf_id": "test-stf",
  "caller": null,
  "api_url": "http://localhost:8080",
  "api_token": "test-token",
  "input": {
    "operation": "{operation_name}",
    "param1": "value1"
  },
  "sources": {}
}' | docker run --rm -i {stf-name}:latest
```

## Related Documentation

- [Project README](../../README.md)
- {Additional documentation links}
````

### Key Points for README Creation

1. **Explicit Docker Registration Instructions**

   - Always specify `runtime: "docker"`
   - Format `code` as JSON string: `'{"image":"..."}'`
   - Include the full image path with tag

2. **Always Include the `describe` Operation**

   - List `describe` as the first operation in the Supported Operations table
   - Show a describe test in the Local Build and Test section
   - Recommend running `describe` first in all prompts

3. **AI-Friendly Operation Tables**

   - Use consistent table format
   - Clearly mark database requirements (❌/✅)
   - List all required and optional parameters

4. **Ready-to-Use Prompts**

   - Provide multiple prompt examples (basic, specific, complete)
   - Include all necessary parameters in prompts
   - Always suggest `describe` as the first operation to verify setup

5. **Clear Input/Output Examples**

   - Show complete JSON structures
   - Include both success and error response examples
   - Document all possible output fields

6. **Self-Contained Instructions**
   - Users should be able to copy the README and prompt to an AI agent
   - The AI agent should be able to execute without additional context
   - All steps should be clearly numbered and ordered

## Additional Resources

For detailed information:

- Complete API reference: [reference.md](reference.md)
- More implementation examples: [examples.md](examples.md)
- Quick start guide: [../docs/QUICKSTART.md](../../docs/QUICKSTART.md)
- Testing guide: [../docs/TESTING.md](../../docs/TESTING.md)
- Publishing guide: [../docs/PUBLISHING.md](../../docs/PUBLISHING.md)
