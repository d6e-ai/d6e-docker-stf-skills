# D6E Docker STF Development - API Reference

Complete technical reference for D6E Docker STF development.

## Input/Output Schemas

### Input Schema (TypeScript)

```typescript
interface STFInput {
  workspace_id: string;  // UUID of the workspace
  stf_id: string;        // UUID of the STF
  caller: string | null; // UUID of the user who triggered execution
  api_url: string;       // API URL reachable from inside the container
                         // (default "http://host.docker.internal:8080")
  api_token: string;     // Signed, short-lived per-execution token
  input: Record<string, any>;  // User-defined input parameters
  sources: Record<string, any>; // Resolved workflow input-step values,
                                // keyed by step name (NO {output} wrapper)
}
```

`sources` values depend on the input step's source type:

| Source type | Resolved value shape |
|-------------|----------------------|
| `Library` | `{ "code": string, "types": string, "version": string }` |
| `File` (JSON content type) | the parsed JSON value |
| `File` (text content type) | the file body as a string |
| `File` (binary) | `{ "filename", "content_type", "size", "data": "<base64>" }` |
| `Fetch` | the parsed JSON response body |

### Output Schema (TypeScript)

**Success:** exactly one JSON document on stdout, exit code 0.

```typescript
interface SuccessOutput {
  output: Record<string, any>;  // User-defined result data
}
```

The engine parses the **entire stdout** as one JSON document and requires
the top-level `output` key. Log lines mixed into stdout break parsing with
an `Invalid Docker output format` error — send all logs to stderr.

**Error:** there is no error JSON contract on stdout. Write the
human-readable failure reason to **stderr** and exit with a non-zero
code; d6e marks the step failed and surfaces the stderr text as the
error message.

## The `describe` Operation

Every Docker STF must implement a `describe` operation that returns the input schema and available operations. This enables discoverability and automation.

### Describe Request Schema (TypeScript)

```typescript
interface DescribeRequest {
  input: {
    operation: "describe";
  };
}
```

### Describe Response Schema (TypeScript)

```typescript
interface DescribeResponse {
  output: {
    status: "success";
    operation: "describe";
    data: {
      input_schema: {
        type: "object";
        properties: Record<string, {
          type: string;
          enum?: string[];
          description?: string;
          items?: Record<string, any>;
          properties?: Record<string, any>;
          required?: string[];
        }>;
        required: string[];
      };
      operations: Record<string, {
        description: string;
        required: string[];
        optional: string[];
      }>;
    };
  };
}
```

### Implementation Guidelines

1. **Handle `describe` before other validations** - The `describe` operation should not require any parameters other than `operation`
2. **Include all operations in the enum** - The `operation` property's `enum` should list all supported operations including `describe` itself
3. **Document every parameter** - Include `description` for each property in `input_schema`
4. **Specify required vs optional** - Each operation must clearly list its required and optional parameters
5. **Keep schema in sync** - Update the `describe` output whenever you add or modify operations

## SQL API Reference

### Endpoint

```
POST /api/v1/workspaces/{workspace_id}/sql
```

### Request Headers

| Header | Required | Description |
|--------|----------|-------------|
| `Authorization` | Yes | `Bearer {api_token}` |
| `X-Internal-Bypass` | Yes | Must be `"true"` |
| `X-Workspace-ID` | Yes | Workspace UUID |
| `X-STF-ID` | Yes | STF UUID |
| `Content-Type` | Yes | Must be `application/json` |

### Request Body

```json
{
  "sql": "SELECT * FROM users WHERE id = 'abc123'"
}
```

### Response Body

Fields are present only when applicable (SELECT returns `rows`,
INSERT/UPDATE/DELETE return `affected_rows`):

```json
// SELECT
{ "rows": [ {"id": "abc123", "name": "John"} ] }

// INSERT / UPDATE / DELETE
{ "affected_rows": 1 }
```

The response may also include `executed_sql` (the transformed SQL that
actually ran) for debugging.

### Allowed SQL Operations

| Operation | Allowed | Example |
|-----------|---------|---------|
| SELECT | ✅ Yes | `SELECT * FROM table` |
| INSERT | ✅ Yes | `INSERT INTO table (col) VALUES ('val')` |
| UPDATE | ✅ Yes | `UPDATE table SET col = 'val' WHERE id = '123'` |
| DELETE | ✅ Yes | `DELETE FROM table WHERE id = '123'` |
| CREATE / DROP / ALTER | ❌ No | DDL is rejected for STF calls (`DDL_FORBIDDEN`) |
| BEGIN / COMMIT | ❌ No | Transactions are rejected (`TRANSACTION_NOT_ALLOWED`) |
| Multiple statements | ❌ No | One statement per request (`MULTIPLE_STATEMENTS`) |

Additional constraints:

- Table names must be **23 characters or less**; d6e rewrites them into
  the workspace's private schema (`INVALID_TABLE` on violation).
- Tables must be created beforehand (by a workspace member via the d6e
  console/agent), since STFs cannot run DDL.

### SQL API Error Responses

All errors share the shape `{ "error": string, "code": string }`.

| Code | HTTP | Meaning |
|------|------|---------|
| `POLICY_DENIED` | 403 | No allow policy for this table + operation (most common for new STFs) |
| `DDL_FORBIDDEN` | 403 | DDL statement from an STF |
| `PARSE_ERROR` | 400 | SQL could not be parsed |
| `INVALID_TABLE` | 400 | Table name too long or otherwise invalid |
| `TRANSACTION_NOT_ALLOWED` | 400 | BEGIN/COMMIT/ROLLBACK used |
| `MULTIPLE_STATEMENTS` | 400 | More than one statement in the request |
| `EXECUTION_ERROR` | 400 | Runtime database error (constraint violation, type mismatch, ...) |
| `WORKSPACE_MISMATCH` | 403 | Path workspace differs from the token's workspace |

Example:

```json
{
  "error": "Access denied by policy",
  "code": "POLICY_DENIED"
}
```

## STF Registration API Reference

### Docker config JSON (the `code` field)

```json
{
  "image": "ghcr.io/your-org/your-stf:v1.0.0",
  "command": ["python3", "main.py"],
  "env": { "LOG_LEVEL": "info", "EXTERNAL_API_KEY": "placeholder" },
  "secret_keys": ["EXTERNAL_API_KEY"]
}
```

- `image` (string, required): image reference pullable by the d6e host.
- `command` (array of strings, optional): overrides the container CMD.
- `env` (object, optional): environment variables injected at run time.
  Keys must match `[A-Za-z_][A-Za-z0-9_]*`.
- `secret_keys` (array of strings, optional): env keys whose real values
  come from the encrypted secrets store instead of the config JSON.

### Endpoints

| Endpoint | Method | Notes |
|----------|--------|-------|
| `/api/v1/stfs` | POST | Creates STF **and first version**. Body: `name`, `description`, `version`, `runtime: "docker"`, `code` (**base64** of config JSON) |
| `/api/v1/stfs/{id}/versions` | POST | Adds a new version (`version`, `runtime`, `code` base64) |
| `/api/v1/stfs/{id}/describe` | POST | Runs the container with `{"operation": "describe"}`; returns `{ success, data, error }` |
| `/api/v1/stfs/instant-run` | POST | Body `{ "stf_id", "input", "sources" }`; runs once without a workflow, returns `{ success, output, error }` |
| `/api/v1/stfs/{id}/secrets` | GET/POST | List key names / store `{ "env_key", "value" }` (encrypted at rest) |
| `/api/v1/stfs/{id}/secrets/{env_key}` | DELETE | Remove a stored secret |

All require `Authorization: Bearer {jwt}` + `X-Workspace-ID: {workspace_id}`.
MCP equivalents (`d6e_create_stf`, `d6e_create_stf_version`,
`d6e_describe_stf`, `d6e_instant_run_stf`) take the config JSON as a
plain string — no base64.

Where the Bearer token comes from (any workspace member works; no
d6e-auth admin needed):

- **Console session JWT** — log in to the d6e console and copy the
  `auth-token` cookie from dev tools (expires in ~1 hour).
- **Refresh flow** — copy the `auth-refresh` cookie once, then POST
  `{"grant_type":"refresh_token","refresh_token":"..."}` to
  `{api_url}/api/v1/auth/token` whenever you need a fresh
  `access_token` (the refresh token rotates on each use).
- **API key** — with a session JWT, `POST /api/v1/api-keys`
  `{"name":"dev"}` returns a long-lived `d6e_...` key usable as the
  Bearer value. API keys are created via this endpoint only (no console
  UI yet).

The workspace UUID is visible in every d6e console URL
(`/workspaces/{uuid}/...`) and on the workspace settings page's
Integration section.

### Execution limits

| Limit | Default | Operator override |
|-------|---------|-------------------|
| Execution time | 5 minutes | `STF_DOCKER_TIMEOUT_SECS` |
| stdout/stderr size | 10 MB | `STF_DOCKER_MAX_OUTPUT_BYTES` |

Containers run with `--rm -i --network=bridge` and
`--add-host=host.docker.internal:host-gateway`.

## Complete Language Implementations

### Python (with Type Hints)

**main.py:**
```python
#!/usr/bin/env python3
"""
D6E Docker STF - Python Implementation

Complete example with type hints, error handling, and logging.
"""

import sys
import json
import logging
from typing import Dict, Any, Optional
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

# Configure logging
logging.basicConfig(
    stream=sys.stderr,
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class STFContext:
    """Context for STF execution"""
    def __init__(self, workspace_id: str, stf_id: str, api_url: str, api_token: str):
        self.workspace_id = workspace_id
        self.stf_id = stf_id
        self.api_url = api_url
        self.api_token = api_token


class D6EAPIClient:
    """Client for D6E internal API"""
    
    def __init__(self, context: STFContext):
        self.context = context
        self.session = self._create_session()
    
    def _create_session(self) -> requests.Session:
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
    
    def execute_sql(self, sql: str) -> Dict[str, Any]:
        """Execute SQL via D6E internal API"""
        url = f"{self.context.api_url}/api/v1/workspaces/{self.context.workspace_id}/sql"
        headers = {
            "Authorization": f"Bearer {self.context.api_token}",
            "X-Internal-Bypass": "true",
            "X-Workspace-ID": self.context.workspace_id,
            "X-STF-ID": self.context.stf_id,
            "Content-Type": "application/json"
        }
        
        try:
            logger.debug(f"Executing SQL: {sql}")
            response = self.session.post(
                url,
                json={"sql": sql},
                headers=headers,
                timeout=30
            )
            response.raise_for_status()
            result = response.json()
            logger.debug(f"SQL result: {len(result.get('rows', []))} rows")
            return result
        except requests.RequestException as e:
            logger.error(f"SQL execution failed: {str(e)}")
            raise Exception(f"Database error: {str(e)}")


class ValidationError(Exception):
    """Custom validation error"""
    pass


def process_describe() -> Dict[str, Any]:
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
                        "enum": ["query_data", "insert_data", "process_data", "describe"],
                        "description": "The operation to perform"
                    },
                    "table_name": {
                        "type": "string",
                        "description": "Target table name for query or insert operations"
                    },
                    "data": {
                        "type": "array",
                        "items": {"type": "object"},
                        "description": "Array of data objects to insert"
                    }
                },
                "required": ["operation"]
            },
            "operations": {
                "query_data": {
                    "description": "Query data from a table",
                    "required": ["table_name"],
                    "optional": []
                },
                "insert_data": {
                    "description": "Insert data into a table",
                    "required": ["table_name", "data"],
                    "optional": []
                },
                "process_data": {
                    "description": "Process data with custom logic",
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


def validate_input(user_input: Dict[str, Any]) -> None:
    """Validate user input"""
    if "operation" not in user_input:
        raise ValidationError("Missing required field: operation")
    
    operation = user_input["operation"]
    if operation not in ["query_data", "insert_data", "process_data", "describe"]:
        raise ValidationError(f"Invalid operation: {operation}")


def process(
    user_input: Dict[str, Any],
    sources: Dict[str, Any],
    api_client: D6EAPIClient
) -> Dict[str, Any]:
    """Main business logic"""
    operation = user_input.get("operation")
    
    if operation == "query_data":
        table_name = user_input.get("table_name")
        if not table_name:
            raise ValidationError("Missing required field: table_name")
        
        result = api_client.execute_sql(
            f"SELECT * FROM {table_name} LIMIT 100"
        )
        return {
            "status": "success",
            "operation": operation,
            "rows": result.get("rows", []),
            "count": len(result.get("rows", []))
        }
    
    elif operation == "insert_data":
        table_name = user_input.get("table_name")
        data = user_input.get("data", [])
        
        if not table_name or not data:
            raise ValidationError("Missing required fields: table_name, data")
        
        inserted = 0
        for item in data:
            # Build INSERT statement (simplified - use proper escaping in production)
            columns = ", ".join(item.keys())
            values = ", ".join([f"'{v}'" for v in item.values()])
            sql = f"INSERT INTO {table_name} ({columns}) VALUES ({values})"
            api_client.execute_sql(sql)
            inserted += 1
        
        return {
            "status": "success",
            "operation": operation,
            "inserted_count": inserted
        }
    
    else:
        raise ValidationError(f"Unsupported operation: {operation}")


def main():
    """Main entry point"""
    try:
        logger.info("STF execution started")
        
        # Read input
        input_data = json.load(sys.stdin)
        logger.debug(f"Input: {json.dumps(input_data, indent=2)}")
        
        # Create context
        context = STFContext(
            workspace_id=input_data["workspace_id"],
            stf_id=input_data["stf_id"],
            api_url=input_data["api_url"],
            api_token=input_data["api_token"]
        )
        
        # Handle describe operation before validation
        if input_data["input"].get("operation") == "describe":
            result = process_describe()
            print(json.dumps({"output": result}))
            logger.info("Describe operation completed")
            return
        
        # Validate input
        validate_input(input_data["input"])
        
        # Process
        api_client = D6EAPIClient(context)
        result = process(
            input_data["input"],
            input_data.get("sources", {}),
            api_client
        )
        
        # Output result
        output = {"output": result}
        print(json.dumps(output))
        logger.info("STF execution completed successfully")
        
    except ValidationError as e:
        # stderr + non-zero exit: d6e surfaces stderr as the failure reason
        logger.error(f"ValidationError: {str(e)}")
        sys.exit(1)
    
    except Exception as e:
        logger.error(f"{type(e).__name__}: {str(e)}", exc_info=True)
        sys.exit(1)


if __name__ == "__main__":
    main()
```

**requirements.txt:**
```
requests>=2.31.0
urllib3>=2.0.0
```

**Dockerfile:**
```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY main.py .
RUN chmod +x main.py

# Run as non-root user
RUN useradd -m -u 1000 stf && chown -R stf:stf /app
USER stf

ENTRYPOINT ["python3", "main.py"]
```

### Node.js (TypeScript)

**index.ts:**
```typescript
#!/usr/bin/env node
import axios, { AxiosInstance } from 'axios';

interface STFInput {
  workspace_id: string;
  stf_id: string;
  caller: string | null;
  api_url: string;
  api_token: string;
  input: Record<string, any>;
  sources: Record<string, any>; // resolved values, no {output} wrapper
}

interface STFContext {
  workspaceId: string;
  stfId: string;
  apiUrl: string;
  apiToken: string;
}

interface SQLResult {
  rows?: Record<string, any>[];
  affected_rows?: number;
}

class D6EAPIClient {
  private client: AxiosInstance;
  private context: STFContext;

  constructor(context: STFContext) {
    this.context = context;
    this.client = axios.create({
      timeout: 30000,
      headers: {
        'Content-Type': 'application/json',
      },
    });
  }

  async executeSql(sql: string): Promise<SQLResult> {
    const url = `${this.context.apiUrl}/api/v1/workspaces/${this.context.workspaceId}/sql`;
    
    try {
      console.error(`[DEBUG] Executing SQL: ${sql}`);
      const response = await this.client.post<SQLResult>(
        url,
        { sql },
        {
          headers: {
            'Authorization': `Bearer ${this.context.apiToken}`,
            'X-Internal-Bypass': 'true',
            'X-Workspace-ID': this.context.workspaceId,
            'X-STF-ID': this.context.stfId,
          },
        }
      );
      console.error(`[DEBUG] SQL result: ${response.data.rows?.length || 0} rows`);
      return response.data;
    } catch (error: any) {
      console.error(`[ERROR] SQL execution failed: ${error.message}`);
      throw new Error(`Database error: ${error.message}`);
    }
  }
}

class ValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ValidationError';
  }
}

function processDescribe(): Record<string, any> {
  return {
    status: 'success',
    operation: 'describe',
    data: {
      input_schema: {
        type: 'object',
        properties: {
          operation: {
            type: 'string',
            enum: ['query_data', 'insert_data', 'process_data', 'describe'],
            description: 'The operation to perform',
          },
          table_name: {
            type: 'string',
            description: 'Target table name for query or insert operations',
          },
        },
        required: ['operation'],
      },
      operations: {
        query_data: {
          description: 'Query data from a table',
          required: ['table_name'],
          optional: [],
        },
        insert_data: {
          description: 'Insert data into a table',
          required: ['table_name', 'data'],
          optional: [],
        },
        process_data: {
          description: 'Process data with custom logic',
          required: [],
          optional: [],
        },
        describe: {
          description: 'Returns the input schema and available operations',
          required: [],
          optional: [],
        },
      },
    },
  };
}

function validateInput(userInput: Record<string, any>): void {
  if (!userInput.operation) {
    throw new ValidationError('Missing required field: operation');
  }

  const validOperations = ['query_data', 'insert_data', 'process_data', 'describe'];
  if (!validOperations.includes(userInput.operation)) {
    throw new ValidationError(`Invalid operation: ${userInput.operation}`);
  }
}

async function process(
  userInput: Record<string, any>,
  sources: Record<string, any>,
  apiClient: D6EAPIClient
): Promise<Record<string, any>> {
  const { operation } = userInput;

  if (operation === 'query_data') {
    const { table_name } = userInput;
    if (!table_name) {
      throw new ValidationError('Missing required field: table_name');
    }

    const result = await apiClient.executeSql(
      `SELECT * FROM ${table_name} LIMIT 100`
    );

    return {
      status: 'success',
      operation,
      rows: result.rows || [],
      count: result.rows?.length || 0,
    };
  }

  throw new ValidationError(`Unsupported operation: ${operation}`);
}

async function readStdin(): Promise<string> {
  return new Promise((resolve) => {
    let data = '';
    process.stdin.on('data', (chunk) => (data += chunk));
    process.stdin.on('end', () => resolve(data));
  });
}

async function main() {
  try {
    console.error('[INFO] STF execution started');

    // Read input
    const inputStr = await readStdin();
    const input: STFInput = JSON.parse(inputStr);
    console.error(`[DEBUG] Input: ${JSON.stringify(input, null, 2)}`);

    // Create context
    const context: STFContext = {
      workspaceId: input.workspace_id,
      stfId: input.stf_id,
      apiUrl: input.api_url,
      apiToken: input.api_token,
    };

    // Handle describe operation before validation
    if (input.input.operation === 'describe') {
      const result = processDescribe();
      console.log(JSON.stringify({ output: result }));
      console.error('[INFO] Describe operation completed');
      return;
    }

    // Validate input
    validateInput(input.input);

    // Process
    const apiClient = new D6EAPIClient(context);
    const result = await process(input.input, input.sources || {}, apiClient);

    // Output result
    console.log(JSON.stringify({ output: result }));
    console.error('[INFO] STF execution completed successfully');
  } catch (error: any) {
    // stderr + non-zero exit: d6e surfaces stderr as the failure reason
    const errorType = error instanceof ValidationError
      ? 'ValidationError'
      : error.name || 'Error';
    console.error(`[ERROR] ${errorType}: ${error.message}`);
    process.exit(1);
  }
}

main();
```

**package.json:**
```json
{
  "name": "d6e-docker-stf",
  "version": "1.0.0",
  "main": "dist/index.js",
  "scripts": {
    "build": "tsc",
    "start": "node dist/index.js"
  },
  "dependencies": {
    "axios": "^1.6.0"
  },
  "devDependencies": {
    "@types/node": "^20.0.0",
    "typescript": "^5.0.0"
  }
}
```

**tsconfig.json:**
```json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules"]
}
```

**Dockerfile:**
```dockerfile
FROM node:18-slim AS builder

WORKDIR /app

COPY package*.json tsconfig.json ./
RUN npm ci

COPY src/ ./src/
RUN npm run build

FROM node:18-slim

WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev

COPY --from=builder /app/dist ./dist

USER node

ENTRYPOINT ["node", "dist/index.js"]
```

### Go Implementation

**main.go:**
```go
package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
)

type STFInput struct {
	WorkspaceID string                 `json:"workspace_id"`
	StfID       string                 `json:"stf_id"`
	Caller      *string                `json:"caller"`
	APIUrl      string                 `json:"api_url"`
	APIToken    string                 `json:"api_token"`
	Input       map[string]interface{} `json:"input"`
	Sources     map[string]interface{} `json:"sources"`
}

type SQLRequest struct {
	SQL string `json:"sql"`
}

type SQLResponse struct {
	Rows         []map[string]interface{} `json:"rows"`
	AffectedRows int                      `json:"affected_rows"`
}

type ValidationError struct {
	Message string
}

func (e *ValidationError) Error() string {
	return e.Message
}

type APIClient struct {
	context *STFContext
	client  *http.Client
}

type STFContext struct {
	WorkspaceID string
	StfID       string
	APIUrl      string
	APIToken    string
}

func NewAPIClient(context *STFContext) *APIClient {
	return &APIClient{
		context: context,
		client:  &http.Client{},
	}
}

func (c *APIClient) ExecuteSQL(sql string) (*SQLResponse, error) {
	url := fmt.Sprintf("%s/api/v1/workspaces/%s/sql",
		c.context.APIUrl, c.context.WorkspaceID)

	reqBody, err := json.Marshal(SQLRequest{SQL: sql})
	if err != nil {
		return nil, err
	}

	req, err := http.NewRequest("POST", url, bytes.NewBuffer(reqBody))
	if err != nil {
		return nil, err
	}

	req.Header.Set("Authorization", "Bearer "+c.context.APIToken)
	req.Header.Set("X-Internal-Bypass", "true")
	req.Header.Set("X-Workspace-ID", c.context.WorkspaceID)
	req.Header.Set("X-STF-ID", c.context.StfID)
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("SQL execution failed: %s", string(body))
	}

	var sqlResp SQLResponse
	if err := json.NewDecoder(resp.Body).Decode(&sqlResp); err != nil {
		return nil, err
	}

	return &sqlResp, nil
}

func processDescribe() map[string]interface{} {
	return map[string]interface{}{
		"status":    "success",
		"operation": "describe",
		"data": map[string]interface{}{
			"input_schema": map[string]interface{}{
				"type": "object",
				"properties": map[string]interface{}{
					"operation": map[string]interface{}{
						"type":        "string",
						"enum":        []string{"query_data", "insert_data", "process_data", "describe"},
						"description": "The operation to perform",
					},
					"table_name": map[string]interface{}{
						"type":        "string",
						"description": "Target table name for query or insert operations",
					},
				},
				"required": []string{"operation"},
			},
			"operations": map[string]interface{}{
				"query_data": map[string]interface{}{
					"description": "Query data from a table",
					"required":    []string{"table_name"},
					"optional":    []string{},
				},
				"insert_data": map[string]interface{}{
					"description": "Insert data into a table",
					"required":    []string{"table_name", "data"},
					"optional":    []string{},
				},
				"process_data": map[string]interface{}{
					"description": "Process data with custom logic",
					"required":    []string{},
					"optional":    []string{},
				},
				"describe": map[string]interface{}{
					"description": "Returns the input schema and available operations",
					"required":    []string{},
					"optional":    []string{},
				},
			},
		},
	}
}

func validateInput(userInput map[string]interface{}) error {
	operation, ok := userInput["operation"].(string)
	if !ok {
		return &ValidationError{Message: "Missing required field: operation"}
	}

	validOps := map[string]bool{
		"query_data":   true,
		"insert_data":  true,
		"process_data": true,
		"describe":     true,
	}

	if !validOps[operation] {
		return &ValidationError{
			Message: fmt.Sprintf("Invalid operation: %s", operation),
		}
	}

	return nil
}

func process(userInput map[string]interface{}, sources map[string]interface{},
	apiClient *APIClient) (map[string]interface{}, error) {

	operation := userInput["operation"].(string)

	if operation == "query_data" {
		tableName, ok := userInput["table_name"].(string)
		if !ok {
			return nil, &ValidationError{
				Message: "Missing required field: table_name",
			}
		}

		sql := fmt.Sprintf("SELECT * FROM %s LIMIT 100", tableName)
		result, err := apiClient.ExecuteSQL(sql)
		if err != nil {
			return nil, err
		}

		return map[string]interface{}{
			"status":    "success",
			"operation": operation,
			"rows":      result.Rows,
			"count":     len(result.Rows),
		}, nil
	}

	return nil, &ValidationError{
		Message: fmt.Sprintf("Unsupported operation: %s", operation),
	}
}

func main() {
	// Configure logger to stderr
	log.SetOutput(os.Stderr)
	log.SetPrefix("[STF] ")

	log.Println("STF execution started")

	// Read input from stdin
	var input STFInput
	if err := json.NewDecoder(os.Stdin).Decode(&input); err != nil {
		log.Printf("ParseError: failed to parse input: %s", err.Error())
		os.Exit(1)
	}

	// Create context
	context := &STFContext{
		WorkspaceID: input.WorkspaceID,
		StfID:       input.StfID,
		APIUrl:      input.APIUrl,
		APIToken:    input.APIToken,
	}

	// Handle describe operation before validation
	if operation, ok := input.Input["operation"].(string); ok && operation == "describe" {
		result := processDescribe()
		output := map[string]interface{}{"output": result}
		json.NewEncoder(os.Stdout).Encode(output)
		log.Println("Describe operation completed")
		return
	}

	// Validate input
	// (stderr + non-zero exit: d6e surfaces stderr as the failure reason)
	if err := validateInput(input.Input); err != nil {
		log.Printf("ValidationError: %s", err.Error())
		os.Exit(1)
	}

	// Process
	apiClient := NewAPIClient(context)
	result, err := process(input.Input, input.Sources, apiClient)
	if err != nil {
		log.Printf("ProcessingError: %s", err.Error())
		os.Exit(1)
	}

	// Output result
	output := map[string]interface{}{"output": result}
	if err := json.NewEncoder(os.Stdout).Encode(output); err != nil {
		log.Printf("Failed to encode output: %s", err.Error())
		os.Exit(1)
	}

	log.Println("STF execution completed successfully")
}
```

**go.mod:**
```go
module github.com/example/d6e-stf

go 1.21
```

**Dockerfile:**
```dockerfile
FROM golang:1.21-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY *.go ./
RUN CGO_ENABLED=0 GOOS=linux go build -o /stf

FROM alpine:latest

RUN apk --no-cache add ca-certificates
WORKDIR /root/

COPY --from=builder /stf ./

RUN adduser -D -u 1000 stf && chown stf:stf stf
USER stf

ENTRYPOINT ["./stf"]
```

## Policy Configuration

### Policy System Overview

D6E uses a policy-based access control system. Docker STFs must be granted explicit permissions to access database tables.

### Creating Policies

**Step 1: Create Policy Group with the STF as a member**

Membership is passed directly as `stf_ids` / `user_ids` arrays — there
is no separate "add member" tool:

```javascript
const group = await d6e_create_policy_group({
  name: "my-stf-policies",
  user_ids: [],
  stf_ids: [stfId],  // The STF ID from d6e_create_stf
});
const policyGroupId = group.id;

// To change membership later:
// d6e_update_policy_group({ id: policyGroupId, stf_ids: [...] })
```

**Step 2: Grant Table Permissions**

Every policy requires a `name`:

```javascript
// Allow SELECT
await d6e_create_policy({
  name: "my-stf select users",
  policy_group_id: policyGroupId,
  table_name: "users",
  operation: "select",
  mode: "allow"
});

// Allow INSERT
await d6e_create_policy({
  name: "my-stf insert logs",
  policy_group_id: policyGroupId,
  table_name: "logs",
  operation: "insert",
  mode: "allow"
});

// Allow UPDATE with a row-level condition (modql JSON, not SQL text)
await d6e_create_policy({
  name: "my-stf update pending records",
  policy_group_id: policyGroupId,
  table_name: "records",
  operation: "update",
  mode: "allow",
  condition: { "status": { "$eq": "pending" } }
});

// Allow DELETE
await d6e_create_policy({
  name: "my-stf delete temp_data",
  policy_group_id: policyGroupId,
  table_name: "temp_data",
  operation: "delete",
  mode: "allow"
});
```

### Policy Operations

| Operation | Description | Example |
|-----------|-------------|---------|
| `select` | Allow SELECT queries | Read data from table |
| `insert` | Allow INSERT queries | Add new records |
| `update` | Allow UPDATE queries | Modify existing records |
| `delete` | Allow DELETE queries | Remove records |

### Policy Modes

| Mode | Effect |
|------|--------|
| `allow` | Grant permission |
| `deny` | Explicitly deny permission (overrides allow) |

## Advanced Patterns

### Multi-Tenant Data Isolation

```python
def get_tenant_data(api_client, user_id, table_name):
    """Fetch data filtered by tenant"""
    # Use caller ID for tenant isolation
    sql = f"""
        SELECT * FROM {table_name} 
        WHERE tenant_id = (
            SELECT tenant_id FROM users WHERE id = '{user_id}'
        )
    """
    return api_client.execute_sql(sql)
```

### Batch Processing with Progress

```python
def process_batch(api_client, items, batch_size=100):
    """Process large datasets in batches"""
    total = len(items)
    processed = 0
    
    for i in range(0, total, batch_size):
        batch = items[i:i + batch_size]
        
        # Process batch
        for item in batch:
            # Your processing logic
            pass
        
        processed += len(batch)
        progress = (processed / total) * 100
        logger.info(f"Progress: {progress:.1f}% ({processed}/{total})")
    
    return {"processed": processed, "total": total}
```

### Caching with Sources

```python
def process_with_cache(user_input, sources, api_client):
    """Use a workflow input step's value as pre-fetched data"""
    cache_key = f"data_{user_input['table_name']}"
    
    # sources maps step names directly to resolved values (no "output" wrapper)
    if cache_key in sources:
        logger.info("Using data provided by the workflow input step")
        return sources[cache_key]
    
    # Fetch fresh data
    logger.info("Fetching fresh data")
    result = api_client.execute_sql(
        f"SELECT * FROM {user_input['table_name']}"
    )
    
    return {"rows": result["rows"]}
```
