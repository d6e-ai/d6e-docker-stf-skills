# AI Agent Prompts for D6E Docker STF Development

A collection of ready-to-use prompts for Cursor and Claude Code.

## 📋 Table of Contents

- [Basic Usage](#basic-usage)
- [Creating Simple Docker STFs](#creating-simple-docker-stfs)
- [Docker STFs with Database Operations](#docker-stfs-with-database-operations)
- [Docker STFs with External API Integration](#docker-stfs-with-external-api-integration)
- [Complex Workflows](#complex-workflows)
- [Troubleshooting](#troubleshooting)

---

## Basic Usage

### Using with Cursor

1. Open this repository in Cursor
2. Open Composer (Cmd/Ctrl + I)
3. Paste one of the prompts below
4. Add requirements as needed
5. Review the generated code

### Using with Claude Code

1. Launch Claude Code
2. Open the project folder
3. Paste one of the prompts below
4. Reference `@skills/d6e-docker-stf-development.md` in your prompt
5. Review the generated code

---

## Creating Simple Docker STFs

### Prompt 1: Echo Docker STF

```
Using the D6E Docker STF Development skill, create a simple Docker STF that echoes input back.

Requirements:
- Python implementation
- Return input data as-is
- Include error handling
- Log to stderr
- Include Dockerfile, requirements.txt, and README.md

Operations:
- operation: "echo" - Return input data unchanged
```

### Prompt 2: Data Transformation Docker STF

```
Using the D6E Docker STF Development skill, create a Docker STF that performs data transformations.

Requirements:
- Node.js (TypeScript) implementation
- Support the following operations:
  - "uppercase": Convert string to uppercase
  - "lowercase": Convert string to lowercase
  - "reverse": Reverse the string
- Input format: { "operation": "uppercase", "text": "hello" }
- Include error handling

Required files:
- index.ts
- Dockerfile (multi-stage build recommended)
- package.json
- tsconfig.json
- README.md
```

---

## Docker STFs with Database Operations

### Prompt 3: Data Validation Docker STF

```
Using the D6E Docker STF Development skill, create a Docker STF that fetches data from the database and validates it.

Requirements:
- Python implementation
- Use SQL API to fetch data from database
- Apply data validation rules
- Return validation results

Operations:
- operation: "validate"
- input: { "table_name": "users", "rules": { "email": "email_format", "age": "positive_number" } }

Validation rules:
- email_format: Check email address format
- positive_number: Check for positive numbers
- required: Check required fields

Output format:
{
  "status": "valid" | "invalid",
  "total_records": 100,
  "valid_records": 95,
  "invalid_records": 5,
  "errors": [
    { "row": 1, "field": "email", "error": "Invalid email format" }
  ]
}

Required files:
- main.py
- Dockerfile
- requirements.txt
- README.md (including usage examples and policy setup)
```

### Prompt 4: Data Aggregation Docker STF

```
Using the D6E Docker STF Development skill, create a Docker STF that performs database aggregations.

Requirements:
- Go implementation
- Use SQL API
- Support the following aggregation operations:
  - "sum": Calculate sum
  - "avg": Calculate average
  - "count": Count records
  - "group_by": Group by column

Input format:
{
  "operation": "aggregate",
  "table_name": "sales",
  "aggregate_type": "sum",
  "column": "amount",
  "group_by": "category"
}

Output format:
{
  "status": "success",
  "results": [
    { "category": "Electronics", "total": 50000 },
    { "category": "Clothing", "total": 30000 }
  ]
}

Required files:
- main.go
- go.mod
- Dockerfile
- README.md
```

---

## Docker STFs with External API Integration

### Prompt 5: Weather API Integration

```
Using the D6E Docker STF Development skill, create a Docker STF that fetches data from an external Weather API and stores it in the D6E database.

Requirements:
- Python implementation
- Use OpenWeatherMap API (API key received as input parameter)
- Store fetched data in D6E database
- Error handling (API timeout, rate limiting, etc.)
- Retry logic (max 3 attempts, exponential backoff)

Operations:
- operation: "fetch_weather"
- input: { "api_key": "...", "city": "Tokyo", "country_code": "JP" }

Database schema:
CREATE TABLE weather_data (
  id UUID PRIMARY KEY DEFAULT uuidv7(),
  city TEXT NOT NULL,
  country_code TEXT,
  temperature NUMERIC,
  humidity INTEGER,
  description TEXT,
  fetched_at TIMESTAMPTZ DEFAULT NOW()
);

Output format:
{
  "status": "success",
  "city": "Tokyo",
  "temperature": 15.5,
  "humidity": 65,
  "description": "Clear sky",
  "stored_id": "uuid"
}

Required files:
- main.py
- Dockerfile
- requirements.txt
- README.md (including API key setup and policy configuration)
- .env.example (sample environment variables)
```

### Prompt 6: Webhook Notification Docker STF

```
Using the D6E Docker STF Development skill, create a Docker STF that sends webhook notifications to external services when database changes occur.

Requirements:
- Node.js implementation
- Fetch data from database based on specific conditions
- Send notifications to external webhook URLs (Slack, Discord, etc.)
- Retry logic and timeout handling
- Record sending history in database

Operations:
- operation: "send_webhook"
- input: {
    "webhook_url": "https://hooks.slack.com/...",
    "table_name": "events",
    "condition": "status = 'pending'",
    "message_template": "New event: {{name}}"
  }

Required files:
- index.js
- Dockerfile
- package.json
- README.md (including webhook URL configuration)
```

---

## Complex Workflows

### Prompt 7: Data Pipeline

```
Using the D6E Docker STF Development skill, create a Docker STF that constructs a multi-step data pipeline.

Requirements:
- Python implementation
- Retrieve results from previous steps via sources parameter
- Perform data transformation, filtering, and aggregation
- Pass results to next step

Operations:
1. "extract" - Extract data from database
2. "transform" - Transform data (snake_case → camelCase)
3. "filter" - Extract only data matching conditions
4. "load" - Save transformed data to another table

Input formats (for each operation):
- extract: { "operation": "extract", "source_table": "raw_data" }
- transform: { "operation": "transform", "field_mapping": {...} }
- filter: { "operation": "filter", "conditions": [...] }
- load: { "operation": "load", "target_table": "processed_data" }

Workflow example:
1. Extract STF → Data extraction
2. Transform STF → Transformation (retrieve previous step results from sources)
3. Filter STF → Filtering
4. Load STF → Save

Required files:
- main.py
- Dockerfile
- requirements.txt
- README.md (including workflow construction examples)
- WORKFLOW-EXAMPLE.md (D6E workflow creation procedure)
```

### Prompt 8: Report Generation Docker STF

```
Using the D6E Docker STF Development skill, create a Docker STF that fetches data from the database and generates reports.

Requirements:
- Python implementation
- Fetch data from multiple tables
- Aggregate and analyze data
- Output reports in JSON, CSV, HTML formats
- Generate charts (using matplotlib) and return as Base64 encoded

Operations:
- operation: "generate_report"
- input: {
    "report_type": "sales_summary",
    "start_date": "2024-01-01",
    "end_date": "2024-12-31",
    "format": "json" | "csv" | "html",
    "include_charts": true
  }

Report types:
- sales_summary: Sales summary
- user_activity: User activity
- inventory_status: Inventory status

Required files:
- main.py
- report_generator.py (report generation logic)
- Dockerfile
- requirements.txt (including pandas, matplotlib)
- templates/ (HTML templates)
- README.md (including report type descriptions)
```

---

## Troubleshooting

### Prompt 9: Debug Docker STF

```
Using the D6E Docker STF Development skill, create a Docker STF for debugging and troubleshooting.

Requirements:
- Python implementation
- Provide the following debug features:
  - Display detailed input data
  - Test SQL API connection
  - Dry run database queries
  - Check environment variables
  - Dynamically change log levels

Operations:
- "inspect_input" - Display detailed input data
- "test_connection" - Test SQL API connection
- "dry_run_query" - Validate query without execution
- "check_env" - Check environment variables
- "check_permissions" - Check policy permissions

Required files:
- main.py
- debug_utils.py
- Dockerfile
- requirements.txt
- README.md (debugging instructions)
```

### Prompt 10: Test Docker STF

```
Using the D6E Docker STF Development skill, create a Docker STF with comprehensive test suite.

Requirements:
- Python implementation (using pytest)
- Unit tests, integration tests, end-to-end tests
- Mock SQL API server
- Test coverage report
- CI/CD pipeline configuration (GitHub Actions)

Test items:
- Input validation
- SQL API calls
- Error handling
- Log output
- JSON output format

Required files:
- main.py
- tests/
  - test_input_validation.py
  - test_sql_api.py
  - test_error_handling.py
  - conftest.py (pytest configuration)
- mock_api_server.py
- Dockerfile
- Dockerfile.test (for testing)
- requirements.txt
- requirements-dev.txt
- .github/workflows/test.yml
- README.md (test execution instructions)
```

---

## Template

### Prompt Template

```
Using the D6E Docker STF Development skill, create a Docker STF that performs [feature description].

Requirements:
- [Language] implementation
- [Main feature 1]
- [Main feature 2]
- [Main feature 3]

Operations:
- operation: "[operation_name]"
- input: { [parameters] }

Input format:
{
  [input schema]
}

Output format:
{
  [output schema]
}

Required files:
- [file list]
```

---

## Advanced Use Cases

### Prompt 11: Multi-Tenant Docker STF

```
Using the D6E Docker STF Development skill, create a Docker STF that operates in a multi-tenant environment.

Requirements:
- Python implementation
- Isolate data based on tenant ID
- Apply tenant-specific configuration
- Prevent cross-tenant access
- Record audit logs

Operations:
- Require tenant_id as mandatory parameter for all operations
- Automatically add tenant_id condition to database queries
- Prevent data leaks between tenants

Security requirements:
- SQL injection prevention
- Tenant ID validation
- Access permission checks
- Audit log recording

Required files:
- main.py
- tenant_manager.py
- security_utils.py
- Dockerfile
- requirements.txt
- SECURITY.md (security guidelines)
- README.md
```

### Prompt 12: Batch Processing Docker STF

```
Using the D6E Docker STF Development skill, create a Docker STF that efficiently processes large amounts of data in batches.

Requirements:
- Python implementation
- Fetch data using pagination
- Configurable batch size (default 100 records)
- Parallel processing (multi-threading)
- Progress reporting
- Retry and rollback on failure

Operations:
- operation: "batch_process"
- input: {
    "table_name": "large_table",
    "batch_size": 100,
    "parallel_workers": 4,
    "process_type": "transform" | "validate" | "export"
  }

Output format:
{
  "status": "success",
  "total_records": 10000,
  "processed_records": 10000,
  "failed_records": 0,
  "processing_time_seconds": 45.2,
  "batches_completed": 100
}

Required files:
- main.py
- batch_processor.py
- Dockerfile
- requirements.txt
- README.md (performance tuning guide)
```

---

## Usage Tips

### Efficient Use with Cursor

1. **Leverage Composer mode**: Generate multiple files at once
2. **Use @mentions**: Reference `@skills/d6e-docker-stf-development.md`
3. **Iterative improvement**: Start with simple implementation, add features gradually
4. **Code review**: Verify generated code for security and best practices

### Efficient Use with Claude Code

1. **Add context**: Load the entire project
2. **Reference skill documents**: Always reference skill documents in prompts
3. **Test-driven development**: Start from test code generation
4. **Iteration**: Apply small improvements repeatedly

---

## Customizing Prompts

The prompts above can be customized to fit your requirements. Adjust the following points:

- **Language**: Python, Node.js, Go, Rust, etc.
- **Features**: Add required operations and functionality
- **Input/Output format**: Modify to project-specific schemas
- **Error handling**: Adjust according to project requirements
- **Test level**: Adjust based on required test coverage

---

## Feedback and Improvements

This prompt collection is continuously being improved. Please provide feedback through:

- GitHub Issues: https://github.com/d6e-ai/agent-skills/issues
- Pull Requests: Add new prompt examples
- Discussions: Share best practices

Happy Docker STF Development! 🚀
