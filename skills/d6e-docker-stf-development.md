# D6E Docker STF Development

## Overview

This skill teaches how to create custom Docker-based State Transition Functions (STFs) for the D6E platform. D6E Docker STFs are containerized business logic that can be executed within D6E workflows, with access to workspace databases through a secure internal API.

## When to Use This Skill

Use this skill when a user requests:

- "Create a D6E Docker STF that..."
- "Build a custom STF for D6E that does..."
- "I need a Docker-based workflow step for D6E that..."
- "Help me create a data processing function for D6E"

## Core Concepts

### What is a D6E Docker STF?

A Docker STF is a containerized application that:

- Reads JSON input from stdin
- Processes data using custom business logic
- Can query/modify workspace databases via internal API
- Outputs JSON results to stdout
- Runs within D6E workflows as a single step

### Input Format

Every Docker STF receives this JSON structure via stdin:

```json
{
  "workspace_id": "UUID",
  "stf_id": "UUID",
  "caller": "UUID | null",
  "api_url": "http://api:8080",
  "api_token": "internal_token",
  "input": {
    "operation": "...",
    ...user-defined parameters
  },
  "sources": {
    "step_name": {
      "output": {...previous step data}
    }
  }
}
```

### Output Format

The STF must output JSON to stdout:

**Success:**

```json
{
  "output": {
    "status": "success",
    ...custom result data
  }
}
```

**Error:**

```json
{
  "error": "Error message",
  "type": "ErrorType"
}
```

### SQL API Access

Docker STFs can execute SQL via the internal API:

**Endpoint:** `POST /api/v1/workspaces/{workspace_id}/sql`

**Headers:**

```
Authorization: Bearer {api_token}
X-Internal-Bypass: true
X-Workspace-ID: {workspace_id}
X-STF-ID: {stf_id}
Content-Type: application/json
```

**Request:**

```json
{
  "sql": "SELECT * FROM my_table LIMIT 10"
}
```

**Response:**

```json
{
  "rows": [
    {"id": "...", "name": "...", "value": ...}
  ],
  "affected_rows": 1
}
```

**Restrictions:**

- DDL statements (CREATE, DROP, ALTER) are forbidden
- Access is controlled by D6E policies
- Only tables within the same workspace are accessible

## How to Create a Docker STF

### Step 1: Choose Language and Structure

Create a new directory for the Docker STF:

```bash
mkdir my-d6e-stf
cd my-d6e-stf
```

### Step 2: Implement the Main Script

#### Python Example

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

def process(user_input, sources, context):
    """Main business logic"""
    operation = user_input.get("operation", "process")

    if operation == "query_data":
        table_name = user_input.get("table_name")
        result = execute_sql(
            context["api_url"],
            context["api_token"],
            context["workspace_id"],
            context["stf_id"],
            f"SELECT * FROM {table_name} LIMIT 10"
        )
        return {
            "status": "success",
            "rows": result.get("rows", [])
        }

    # Add more operations here
    return {"status": "success", "message": "Operation completed"}

def main():
    try:
        input_data = json.load(sys.stdin)

        context = {
            "workspace_id": input_data["workspace_id"],
            "stf_id": input_data["stf_id"],
            "api_url": input_data["api_url"],
            "api_token": input_data["api_token"]
        }

        result = process(input_data["input"], input_data["sources"], context)
        print(json.dumps({"output": result}))

    except Exception as e:
        logging.error(f"Error: {str(e)}", exc_info=True)
        print(json.dumps({"error": str(e), "type": type(e).__name__}))
        sys.exit(1)

if __name__ == "__main__":
    main()
```

**requirements.txt:**

```
requests==2.31.0
```

#### Node.js Example

**index.js:**

```javascript
#!/usr/bin/env node
const axios = require("axios");

async function executeSql(apiUrl, apiToken, workspaceId, stfId, sql) {
  const url = `${apiUrl}/api/v1/workspaces/${workspaceId}/sql`;
  const response = await axios.post(
    url,
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

async function process(userInput, sources, context) {
  const operation = userInput.operation || "process";

  if (operation === "query_data") {
    const result = await executeSql(
      context.apiUrl,
      context.apiToken,
      context.workspaceId,
      context.stfId,
      `SELECT * FROM ${userInput.table_name} LIMIT 10`
    );
    return {
      status: "success",
      rows: result.rows,
    };
  }

  return { status: "success", message: "Operation completed" };
}

async function main() {
  try {
    let inputData = "";
    for await (const chunk of process.stdin) {
      inputData += chunk;
    }

    const input = JSON.parse(inputData);
    const context = {
      workspaceId: input.workspace_id,
      stfId: input.stf_id,
      apiUrl: input.api_url,
      apiToken: input.api_token,
    };

    const result = await process(input.input, input.sources, context);
    console.log(JSON.stringify({ output: result }));
  } catch (error) {
    console.error(error.message);
    console.log(
      JSON.stringify({
        error: error.message,
        type: error.name,
      })
    );
    process.exit(1);
  }
}

main();
```

**package.json:**

```json
{
  "name": "my-d6e-skill",
  "version": "1.0.0",
  "dependencies": {
    "axios": "^1.6.0"
  }
}
```

### Step 3: Create Dockerfile

**Python:**

```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .
RUN chmod +x main.py

ENTRYPOINT ["python3", "main.py"]
```

**Node.js:**

```dockerfile
FROM node:18-slim

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY index.js ./

ENTRYPOINT ["node", "index.js"]
```

### Step 4: Build and Test Locally

```bash
# Build
docker build -t my-d6e-skill:latest .

# Test locally
echo '{"workspace_id":"test","stf_id":"test","caller":null,"api_url":"http://localhost:8080","api_token":"token","input":{"operation":"test"},"sources":{}}' | \
docker run --rm -i my-d6e-skill:latest
```

### Step 5: Publish to Container Registry

```bash
# Tag for GitHub Container Registry
docker tag my-d6e-stf:latest ghcr.io/username/my-d6e-stf:latest

# Login to GHCR
docker login ghcr.io -u username

# Push
docker push ghcr.io/username/my-d6e-stf:latest

# Make package public on GitHub
```

### Step 6: Register in D6E

To use the Docker STF in D6E, users need to:

1. **Create STF:**

```
Use d6e_create_stf tool with:
- name: "my-stf"
- description: "My custom Docker STF"
```

2. **Create STF Version:**

```
Use d6e_create_stf_version tool with:
- stf_id: (from step 1)
- version: "1.0.0"
- runtime: "docker"
- code: {"image":"ghcr.io/username/my-d6e-stf:latest"}
```

3. **Set Policies (if SQL access needed):**

```
- Create policy group
- Add STF to group
- Grant table permissions (select/insert/update/delete)
```

4. **Create Workflow:**

```
Use d6e_create_workflow tool with:
- stf_steps: [{stf_id, version: "1.0.0"}]
```

5. **Execute:**

```
Use d6e_execute_workflow tool with:
- workflow_id: (from step 4)
- input: {operation: "...", ...}
```

## Best Practices

### Security

1. **Input Validation:** Always validate user input before processing
2. **SQL Injection Prevention:** Escape user-provided values in SQL queries
3. **Error Handling:** Never expose sensitive information in error messages
4. **Logging:** Log to stderr (not stdout) to avoid corrupting JSON output

### Performance

1. **Timeout Awareness:** Operations should complete within workspace timeout (default 30s)
2. **Batch Processing:** For large datasets, process in batches
3. **Resource Limits:** Design for constrained environments

### Code Quality

1. **Single Responsibility:** Each Docker STF should do one thing well
2. **Stateless Design:** Don't rely on persistent state between executions
3. **Clear Error Messages:** Provide actionable error information
4. **Comprehensive Logging:** Log important processing steps to stderr

### Testing

1. **Unit Tests:** Test business logic independently
2. **Integration Tests:** Test with mock D6E API
3. **Local Docker Tests:** Verify container behavior before publishing

## Common Patterns

### Pattern 1: Data Transformation

```python
def process(user_input, sources, context):
    data = user_input.get("data", [])

    # Transform data
    transformed = [
        transform_item(item)
        for item in data
    ]

    return {
        "status": "success",
        "transformed": transformed,
        "count": len(transformed)
    }
```

### Pattern 2: Database Query with Aggregation

```python
def process(user_input, sources, context):
    table_name = user_input["table_name"]
    group_by = user_input["group_by"]

    sql = f"""
        SELECT {group_by}, COUNT(*) as count, SUM(value) as total
        FROM {table_name}
        GROUP BY {group_by}
    """

    result = execute_sql(context["api_url"], ...)

    return {
        "status": "success",
        "aggregation": result["rows"]
    }
```

### Pattern 3: Multi-Step Processing with Sources

```python
def process(user_input, sources, context):
    # Get data from previous workflow step
    previous_data = sources.get("data_fetcher", {}).get("output", {})
    items = previous_data.get("items", [])

    # Process items
    processed = process_items(items)

    # Store results in database
    for item in processed:
        sql = f"INSERT INTO results (data) VALUES ('{json.dumps(item)}')"
        execute_sql(context["api_url"], ...)

    return {
        "status": "success",
        "processed_count": len(processed)
    }
```

## Troubleshooting

### Issue: SQL execution fails with "Permission denied"

**Cause:** STF doesn't have policy permissions for the table

**Solution:** Ensure policies are set up:

1. Create policy group
2. Add STF as member
3. Grant permissions to required tables

### Issue: "DDL operations are not allowed"

**Cause:** Attempting to execute CREATE/DROP/ALTER statements

**Solution:** Docker STFs cannot modify database schema. Use DML (SELECT/INSERT/UPDATE/DELETE) only.

### Issue: Container logs not appearing

**Cause:** Writing logs to stdout instead of stderr

**Solution:** Configure logging to stderr:

```python
logging.basicConfig(stream=sys.stderr, level=logging.INFO)
```

### Issue: Timeout errors

**Cause:** Processing takes too long

**Solution:**

- Optimize queries (add indexes, limit results)
- Process data in smaller batches
- Reduce external API calls

## Examples

### Example 1: Data Validator

Creates a Docker STF that validates data against rules:

```python
def process(user_input, sources, context):
    data = user_input.get("data", [])
    rules = user_input.get("rules", {})

    errors = []
    for i, item in enumerate(data):
        for field, rule in rules.items():
            if field not in item:
                errors.append(f"Row {i}: Missing field '{field}'")
            elif rule.get("type") == "number" and not isinstance(item[field], (int, float)):
                errors.append(f"Row {i}: Field '{field}' must be a number")

    return {
        "status": "valid" if not errors else "invalid",
        "errors": errors,
        "valid_count": len(data) - len(errors)
    }
```

### Example 2: Report Generator

Creates a Docker STF that generates reports from database data:

```python
def process(user_input, sources, context):
    report_type = user_input.get("report_type")
    start_date = user_input.get("start_date")
    end_date = user_input.get("end_date")

    if report_type == "sales_summary":
        sql = f"""
            SELECT
                DATE(created_at) as date,
                COUNT(*) as orders,
                SUM(amount) as total
            FROM orders
            WHERE created_at BETWEEN '{start_date}' AND '{end_date}'
            GROUP BY DATE(created_at)
            ORDER BY date
        """

        result = execute_sql(context["api_url"], context["api_token"],
                           context["workspace_id"], context["stf_id"], sql)

        return {
            "status": "success",
            "report_type": report_type,
            "period": {"start": start_date, "end": end_date},
            "data": result["rows"]
        }
```

### Example 3: External API Integration

Creates a Docker STF that fetches data from external API and stores in D6E:

```python
import requests

def process(user_input, sources, context):
    api_url = user_input.get("api_url")
    table_name = user_input.get("table_name", "external_data")

    # Fetch from external API
    response = requests.get(api_url, timeout=10)
    response.raise_for_status()
    data = response.json()

    # Store in D6E database
    inserted = 0
    for item in data:
        sql = f"""
            INSERT INTO {table_name} (external_id, data, fetched_at)
            VALUES ('{item['id']}', '{json.dumps(item)}', NOW())
        """
        execute_sql(context["api_url"], context["api_token"],
                   context["workspace_id"], context["stf_id"], sql)
        inserted += 1

    return {
        "status": "success",
        "fetched_count": len(data),
        "inserted_count": inserted
    }
```

## Reference

### Input Schema

```typescript
{
  workspace_id: string(UUID);
  stf_id: string(UUID);
  caller: string(UUID) | null;
  api_url: string;
  api_token: string;
  input: Record<string, any>;
  sources: Record<string, { output: any }>;
}
```

### Output Schema

```typescript
// Success
{
  output: Record<string, any>
}

// Error
{
  error: string
  type?: string
  details?: Record<string, any>
}
```

### SQL API Response Schema

```typescript
{
  rows?: Array<Record<string, any>>
  affected_rows?: number
}
```

## Related Documentation

### Documentation in This Repository

Guides and resources for developers:

- **[Quick Start Guide](./QUICKSTART.md)** - Steps to create your first Docker STF in 5 minutes
- **[Developer Guide](./DEVELOPER_GUIDE.md)** - Detailed development guide with practical examples
- **[AI Prompts Collection](./AI-PROMPTS.md)** - Copy-paste ready prompt collection
- **[Testing Guide](./TESTING.md)** - Local tests, integration tests, and E2E tests
- **[Publishing Guide](./PUBLISHING.md)** - Publishing steps to GitHub Container Registry and Docker Hub

### D6E Official Documentation

- [D6E Docker Runtime Guide](https://github.com/d6e-ai/d6e/blob/main/docs/08-stf-docker-runtime.md) - Docker Runtime details
- [D6E Testing Guide](https://github.com/d6e-ai/d6e/blob/main/docs/09-testing-docker-runtime.md) - Testing methods
- D6E Policy System - Policy-based access control

### Sample Projects

Working Docker STF examples:

- [d6e-test-docker-skill](https://github.com/Senna46/d6e-test-docker-skill) - Test Docker STF (includes SQL operations)

### Other Resources

- [Model Context Protocol](https://modelcontextprotocol.io) - MCP specification
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/) - Docker best practices
- [Claude Agent Skills](https://docs.claude.com/en/docs/agents-and-tools/agent-skills/overview) - Agent Skills overview

---

## Usage Notes for AI Assistants

**Note:** This skill is designed for Claude/Cursor AI assistants to help developers create D6E Docker STFs.

**When a user requests a custom D6E Docker STF:**

1. Read and understand this skill document
2. Use the patterns and examples provided
3. Generate appropriate code following D6E conventions
4. Include all necessary files (Dockerfile, dependencies, README)
5. Provide clear testing instructions
6. Reference the appropriate documentation for more details:
   - For quick examples: [Quick Start Guide](./QUICKSTART.md)
   - For detailed guidance: [Developer Guide](./DEVELOPER_GUIDE.md)
   - For testing: [Testing Guide](./TESTING.md)
   - For publishing: [Publishing Guide](./PUBLISHING.md)
