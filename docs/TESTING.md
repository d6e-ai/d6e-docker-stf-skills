# Testing D6E Docker STFs

This guide explains comprehensive testing methods for D6E Docker STFs.

## 📋 Table of Contents

- [Testing Strategy](#testing-strategy)
- [Local Testing](#local-testing)
- [Integration Testing](#integration-testing)
- [End-to-End Testing](#end-to-end-testing)
- [Automated Testing](#automated-testing)
- [Performance Testing](#performance-testing)
- [Troubleshooting](#troubleshooting)

---

## Testing Strategy

D6E Docker STF testing follows these layers:

```
┌─────────────────────────────────────┐
│    End-to-End Tests (E2E)          │  ← Complete workflow in D6E
├─────────────────────────────────────┤
│    Integration Tests                │  ← Docker + Mock API
├─────────────────────────────────────┤
│    Unit Tests                       │  ← Business logic testing
└─────────────────────────────────────┘
```

### Test Pyramid

- **Unit Tests (70%)**: Business logic, data transformation, validation
- **Integration Tests (20%)**: Docker execution, SQL API calls
- **E2E Tests (10%)**: Complete workflow in D6E environment

---

## Local Testing

### 1. Basic Docker Testing

The simplest testing method.

#### test-local.sh Script

```bash
#!/bin/bash
# Local Docker test script

set -e

IMAGE_NAME="${IMAGE_NAME:-my-stf}"
IMAGE_TAG="${IMAGE_TAG:-latest}"

# Colored logging
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Build
log_info "Building Docker image..."
docker build -t ${IMAGE_NAME}:${IMAGE_TAG} . || {
  log_error "Build failed"
  exit 1
}

# Test 1: Basic echo test
log_info "Test 1: Basic Echo Test"
OUTPUT=$(echo '{
  "workspace_id": "01234567-89ab-cdef-0123-456789abcdef",
  "stf_id": "01234567-89ab-cdef-0123-456789abcdef",
  "caller": null,
  "api_url": "http://localhost:8080",
  "api_token": "test-token",
  "input": {
    "operation": "test",
    "message": "Hello, World!"
  },
  "sources": {}
}' | docker run --rm -i ${IMAGE_NAME}:${IMAGE_TAG})

if echo "$OUTPUT" | jq -e '.output.status == "success"' > /dev/null; then
  log_info "✅ Test 1 passed"
else
  log_error "❌ Test 1 failed"
  echo "Output: $OUTPUT"
  exit 1
fi

# Test 2: Error handling
log_info "Test 2: Error Handling"
OUTPUT=$(echo '{
  "workspace_id": "01234567-89ab-cdef-0123-456789abcdef",
  "stf_id": "01234567-89ab-cdef-0123-456789abcdef",
  "caller": null,
  "api_url": "http://localhost:8080",
  "api_token": "test-token",
  "input": {
    "operation": "unknown_operation"
  },
  "sources": {}
}' | docker run --rm -i ${IMAGE_NAME}:${IMAGE_TAG})

if echo "$OUTPUT" | jq -e '.error' > /dev/null || \
   echo "$OUTPUT" | jq -e '.output.status == "error"' > /dev/null; then
  log_info "✅ Test 2 passed (error handled correctly)"
else
  log_error "❌ Test 2 failed (error not handled)"
  echo "Output: $OUTPUT"
  exit 1
fi

log_info "✅ All local tests passed!"
```

Usage:

```bash
chmod +x test-local.sh
./test-local.sh
```

### 2. Test Case Files

Create `tests/test-cases.json`:

```json
{
  "test_cases": [
    {
      "name": "Basic Echo Test",
      "input": {
        "workspace_id": "01234567-89ab-cdef-0123-456789abcdef",
        "stf_id": "01234567-89ab-cdef-0123-456789abcdef",
        "caller": null,
        "api_url": "http://localhost:8080",
        "api_token": "test-token",
        "input": {
          "operation": "echo",
          "message": "Hello"
        },
        "sources": {}
      },
      "expected": {
        "output": {
          "status": "success",
          "message": "Hello"
        }
      }
    },
    {
      "name": "Error Handling Test",
      "input": {
        "workspace_id": "01234567-89ab-cdef-0123-456789abcdef",
        "stf_id": "01234567-89ab-cdef-0123-456789abcdef",
        "caller": null,
        "api_url": "http://localhost:8080",
        "api_token": "test-token",
        "input": {
          "operation": "invalid"
        },
        "sources": {}
      },
      "expected_error": true
    }
  ]
}
```

Test runner `run-tests.sh`:

```bash
#!/bin/bash

IMAGE_NAME="${1:-my-stf:latest}"
TEST_FILE="${2:-tests/test-cases.json}"

if [ ! -f "$TEST_FILE" ]; then
  echo "Test file not found: $TEST_FILE"
  exit 1
fi

PASSED=0
FAILED=0

# Run each test case
for i in $(seq 0 $(jq '.test_cases | length - 1' $TEST_FILE)); do
  NAME=$(jq -r ".test_cases[$i].name" $TEST_FILE)
  INPUT=$(jq -c ".test_cases[$i].input" $TEST_FILE)

  echo "Running: $NAME"

  OUTPUT=$(echo "$INPUT" | docker run --rm -i $IMAGE_NAME 2>/dev/null)

  if [ $? -eq 0 ]; then
    echo "  ✅ Passed"
    ((PASSED++))
  else
    echo "  ❌ Failed"
    echo "  Output: $OUTPUT"
    ((FAILED++))
  fi
done

echo ""
echo "Results: $PASSED passed, $FAILED failed"
[ $FAILED -eq 0 ] && exit 0 || exit 1
```

### 3. Mock SQL API Server

Mock server for testing SQL API.

`tests/mock-api-server.py`:

```python
"""
Mock D6E SQL API server for testing Docker STFs
"""

from flask import Flask, request, jsonify
import logging

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)

# Mock database
mock_db = {
    "test_data": [
        {"id": "id-1", "name": "Test 1", "value": 100},
        {"id": "id-2", "name": "Test 2", "value": 200},
    ]
}

@app.route("/api/v1/workspaces/<workspace_id>/sql", methods=["POST"])
def execute_sql(workspace_id):
    """SQL execution endpoint"""
    data = request.json
    sql = data.get("sql", "")

    logging.info(f"Executing SQL: {sql}")

    # Simple SQL parser (not a real parser)
    sql_lower = sql.lower()

    if "select" in sql_lower:
        # SELECT query
        table_name = "test_data"
        return jsonify({
            "rows": mock_db.get(table_name, []),
            "affected_rows": 0
        })

    elif "insert" in sql_lower:
        # INSERT query
        return jsonify({
            "rows": [{"id": "new-id", "name": "New Record"}],
            "affected_rows": 1
        })

    elif "update" in sql_lower:
        # UPDATE query
        return jsonify({
            "rows": [],
            "affected_rows": 1
        })

    elif "delete" in sql_lower:
        # DELETE query
        return jsonify({
            "rows": [],
            "affected_rows": 1
        })

    else:
        return jsonify({"error": "Unsupported SQL operation"}), 400

@app.route("/health", methods=["GET"])
def health():
    """Health check"""
    return jsonify({"status": "healthy"})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080, debug=True)
```

Usage:

```bash
# Install dependencies
pip install flask

# Start mock server
python tests/mock-api-server.py

# Run tests in another terminal
echo '{
  "workspace_id": "test",
  "stf_id": "test",
  "caller": null,
  "api_url": "http://host.docker.internal:8080",
  "api_token": "test-token",
  "input": {
    "operation": "sql_select",
    "table_name": "test_data"
  },
  "sources": {}
}' | docker run --rm -i \
  --add-host=host.docker.internal:host-gateway \
  my-stf:latest
```

---

## Integration Testing

### Docker Compose Test Environment

`docker-compose.test.yml`:

```yaml
version: "3.8"

services:
  mock-api:
    build:
      context: ./tests
      dockerfile: Dockerfile.mock-api
    ports:
      - "8080:8080"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 5s
      timeout: 3s
      retries: 3

  stf-under-test:
    build:
      context: .
      dockerfile: Dockerfile
    depends_on:
      mock-api:
        condition: service_healthy
    environment:
      - API_URL=http://mock-api:8080
    stdin_open: true
    tty: true
```

Run tests:

```bash
# Start test environment
docker compose -f docker-compose.test.yml up -d

# Run tests
./run-integration-tests.sh

# Cleanup
docker compose -f docker-compose.test.yml down
```

### Pytest Integration Tests

`tests/integration/test_stf.py`:

```python
"""
Integration tests for Docker STF
"""

import json
import subprocess
import pytest

IMAGE_NAME = "my-stf:latest"

def run_stf(input_data):
    """Run STF in Docker container and return output"""
    input_json = json.dumps(input_data)

    result = subprocess.run(
        ["docker", "run", "--rm", "-i",
         "--add-host=host.docker.internal:host-gateway",
         IMAGE_NAME],
        input=input_json.encode(),
        capture_output=True,
        timeout=30
    )

    if result.returncode != 0:
        stderr = result.stderr.decode()
        raise Exception(f"STF failed: {stderr}")

    return json.loads(result.stdout.decode())

def test_basic_echo():
    """Test basic echo operation"""
    input_data = {
        "workspace_id": "test",
        "stf_id": "test",
        "caller": None,
        "api_url": "http://host.docker.internal:8080",
        "api_token": "test-token",
        "input": {
            "operation": "echo",
            "message": "Hello"
        },
        "sources": {}
    }

    output = run_stf(input_data)

    assert "output" in output
    assert output["output"]["status"] == "success"
    assert output["output"]["message"] == "Hello"

def test_sql_select(mock_api_server):
    """Test SQL SELECT operation"""
    input_data = {
        "workspace_id": "test",
        "stf_id": "test",
        "caller": None,
        "api_url": "http://host.docker.internal:8080",
        "api_token": "test-token",
        "input": {
            "operation": "sql_select",
            "table_name": "test_data"
        },
        "sources": {}
    }

    output = run_stf(input_data)

    assert "output" in output
    assert output["output"]["status"] == "success"
    assert "rows" in output["output"]
    assert len(output["output"]["rows"]) > 0

def test_error_handling():
    """Test error handling"""
    input_data = {
        "workspace_id": "test",
        "stf_id": "test",
        "caller": None,
        "api_url": "http://host.docker.internal:8080",
        "api_token": "test-token",
        "input": {
            "operation": "invalid_operation"
        },
        "sources": {}
    }

    output = run_stf(input_data)

    assert "error" in output or \
           (output.get("output", {}).get("status") == "error")

@pytest.fixture(scope="session")
def mock_api_server():
    """Start mock API server for tests"""
    # Start mock server
    process = subprocess.Popen(
        ["python", "tests/mock-api-server.py"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )

    # Wait for server to start
    import time
    time.sleep(2)

    yield

    # Cleanup
    process.terminate()
    process.wait()
```

Run tests:

```bash
# Install dependencies
pip install pytest

# Run tests
pytest tests/integration/ -v
```

---

## End-to-End Testing

Testing with real D6E environment.

### E2E Test Script

`tests/e2e/test-e2e.sh`:

```bash
#!/bin/bash
# End-to-End test with real D6E environment

set -e

# Configuration
D6E_API_URL="${D6E_API_URL:-http://localhost:8080}"
D6E_TOKEN="${D6E_TOKEN}"
WORKSPACE_ID="${WORKSPACE_ID}"
IMAGE_NAME="${IMAGE_NAME:-ghcr.io/user/my-stf:latest}"

if [ -z "$D6E_TOKEN" ] || [ -z "$WORKSPACE_ID" ]; then
  echo "Error: D6E_TOKEN and WORKSPACE_ID must be set"
  exit 1
fi

echo "🚀 Starting E2E test..."

# 1. Create STF
echo "Creating STF..."
STF_RESPONSE=$(curl -s -X POST "$D6E_API_URL/api/v1/workspaces/$WORKSPACE_ID/stfs" \
  -H "Authorization: Bearer $D6E_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "test-stf-e2e",
    "description": "E2E Test STF"
  }')

STF_ID=$(echo "$STF_RESPONSE" | jq -r '.id')
echo "STF created: $STF_ID"

# 2. Create STF version
echo "Creating STF version..."
VERSION_RESPONSE=$(curl -s -X POST "$D6E_API_URL/api/v1/workspaces/$WORKSPACE_ID/stfs/$STF_ID/versions" \
  -H "Authorization: Bearer $D6E_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"version\": \"1.0.0\",
    \"runtime\": \"docker\",
    \"code\": \"{\\\"image\\\":\\\"$IMAGE_NAME\\\"}\"
  }")

echo "STF version created"

# 3. Create workflow
echo "Creating workflow..."
WORKFLOW_RESPONSE=$(curl -s -X POST "$D6E_API_URL/api/v1/workspaces/$WORKSPACE_ID/workflows" \
  -H "Authorization: Bearer $D6E_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"test-workflow-e2e\",
    \"stf_steps\": [{
      \"stf_id\": \"$STF_ID\",
      \"version\": \"1.0.0\"
    }]
  }")

WORKFLOW_ID=$(echo "$WORKFLOW_RESPONSE" | jq -r '.id')
echo "Workflow created: $WORKFLOW_ID"

# 4. Execute workflow
echo "Executing workflow..."
EXECUTION_RESPONSE=$(curl -s -X POST "$D6E_API_URL/api/v1/workspaces/$WORKSPACE_ID/workflows/$WORKFLOW_ID/execute" \
  -H "Authorization: Bearer $D6E_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "input": {
      "operation": "test",
      "message": "E2E Test"
    }
  }')

EXECUTION_ID=$(echo "$EXECUTION_RESPONSE" | jq -r '.id')
echo "Execution started: $EXECUTION_ID"

# 5. Wait for execution to complete
echo "Waiting for execution to complete..."
for i in {1..30}; do
  sleep 2

  STATUS_RESPONSE=$(curl -s "$D6E_API_URL/api/v1/workspaces/$WORKSPACE_ID/workflow-executions/$EXECUTION_ID" \
    -H "Authorization: Bearer $D6E_TOKEN")

  STATUS=$(echo "$STATUS_RESPONSE" | jq -r '.status')

  if [ "$STATUS" == "completed" ]; then
    echo "✅ Execution completed successfully"
    echo "Output:"
    echo "$STATUS_RESPONSE" | jq '.output'
    exit 0
  elif [ "$STATUS" == "failed" ]; then
    echo "❌ Execution failed"
    echo "$STATUS_RESPONSE" | jq '.error'
    exit 1
  fi

  echo "  Status: $STATUS (attempt $i/30)"
done

echo "❌ Execution timeout"
exit 1
```

Usage:

```bash
export D6E_TOKEN="your_token"
export WORKSPACE_ID="your_workspace_id"
export IMAGE_NAME="ghcr.io/user/my-stf:latest"

chmod +x tests/e2e/test-e2e.sh
./tests/e2e/test-e2e.sh
```

---

## Automated Testing

### GitHub Actions

`.github/workflows/test.yml`:

```yaml
name: Test Docker STF

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: "3.11"

      - name: Install dependencies
        run: |
          pip install pytest pytest-cov

      - name: Run unit tests
        run: |
          pytest tests/unit/ -v --cov

  integration-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build Docker image
        run: |
          docker build -t test-stf:latest .

      - name: Run local tests
        run: |
          chmod +x test-local.sh
          IMAGE_NAME=test-stf IMAGE_TAG=latest ./test-local.sh

      - name: Start mock API
        run: |
          pip install flask
          python tests/mock-api-server.py &
          sleep 3

      - name: Run integration tests
        run: |
          pytest tests/integration/ -v

  docker-tests:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        platform: [linux/amd64, linux/arm64]
    steps:
      - uses: actions/checkout@v4

      - name: Set up QEMU
        uses: docker/setup-qemu-action@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Build for ${{ matrix.platform }}
        run: |
          docker buildx build \
            --platform ${{ matrix.platform }} \
            -t test-stf:${{ matrix.platform }} \
            --load \
            .
```

---

## Performance Testing

### Benchmark Script

`tests/benchmark.sh`:

```bash
#!/bin/bash
# Performance benchmark for Docker STF

IMAGE_NAME="${1:-my-stf:latest}"
ITERATIONS="${2:-100}"

echo "Running performance benchmark..."
echo "Image: $IMAGE_NAME"
echo "Iterations: $ITERATIONS"

START_TIME=$(date +%s)

for i in $(seq 1 $ITERATIONS); do
  echo '{
    "workspace_id": "test",
    "stf_id": "test",
    "caller": null,
    "api_url": "http://localhost:8080",
    "api_token": "test",
    "input": {"operation": "test"},
    "sources": {}
  }' | docker run --rm -i $IMAGE_NAME > /dev/null 2>&1

  if [ $((i % 10)) -eq 0 ]; then
    echo "  Progress: $i/$ITERATIONS"
  fi
done

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
AVG_TIME=$((DURATION * 1000 / ITERATIONS))

echo ""
echo "Results:"
echo "  Total time: ${DURATION}s"
echo "  Average time: ${AVG_TIME}ms per execution"
echo "  Throughput: $((ITERATIONS / DURATION)) executions/second"
```

---

## Troubleshooting

### Debug Mode

```bash
# Enable logging
docker run --rm -i \
  -e LOG_LEVEL=DEBUG \
  my-stf:latest < input.json

# Interactive shell
docker run --rm -it \
  --entrypoint /bin/bash \
  my-stf:latest
```

### Investigate Failed Tests

```bash
# Detailed log output
docker run --rm -i my-stf:latest < input.json 2>&1 | tee output.log

# Check errors
cat output.log | grep ERROR
```

---

## Summary

Comprehensive testing strategy:

1. ✅ **Unit Tests**: Test business logic
2. ✅ **Local Docker Tests**: Verify basic operation
3. ✅ **Integration Tests**: Test with Mock API
4. ✅ **E2E Tests**: Test in real D6E environment
5. ✅ **Performance Tests**: Verify performance
6. ✅ **Automated Tests**: Automate with CI/CD pipeline

---

**Happy Testing! 🧪**

Next, check [PUBLISHING.md](./PUBLISHING.md) to publish your tested images!
