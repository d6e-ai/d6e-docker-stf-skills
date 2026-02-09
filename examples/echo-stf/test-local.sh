#!/bin/bash
# Local test script for echo-stf

set -e

IMAGE_NAME="echo-stf:latest"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log_success() {
  echo -e "${GREEN}✅ $1${NC}"
}

log_error() {
  echo -e "${RED}❌ $1${NC}"
}

echo "Building Docker image..."
docker build -t ${IMAGE_NAME} .

echo ""
echo "Running tests..."
echo ""

# Test 1: Echo operation
echo "Test 1: Echo operation"
OUTPUT=$(echo '{
  "workspace_id": "test",
  "stf_id": "test",
  "caller": null,
  "api_url": "http://localhost:8080",
  "api_token": "test",
  "input": {
    "operation": "echo",
    "message": "Hello, World!"
  },
  "sources": {}
}' | docker run --rm -i ${IMAGE_NAME})

if echo "$OUTPUT" | jq -e '.output.status == "success" and .output.message == "Hello, World!"' > /dev/null; then
  log_success "Test 1 passed"
else
  log_error "Test 1 failed"
  echo "Output: $OUTPUT"
  exit 1
fi

# Test 2: Uppercase operation
echo "Test 2: Uppercase operation"
OUTPUT=$(echo '{
  "workspace_id": "test",
  "stf_id": "test",
  "caller": null,
  "api_url": "http://localhost:8080",
  "api_token": "test",
  "input": {
    "operation": "uppercase",
    "message": "hello world"
  },
  "sources": {}
}' | docker run --rm -i ${IMAGE_NAME})

if echo "$OUTPUT" | jq -e '.output.message == "HELLO WORLD"' > /dev/null; then
  log_success "Test 2 passed"
else
  log_error "Test 2 failed"
  echo "Output: $OUTPUT"
  exit 1
fi

# Test 3: Lowercase operation
echo "Test 3: Lowercase operation"
OUTPUT=$(echo '{
  "workspace_id": "test",
  "stf_id": "test",
  "caller": null,
  "api_url": "http://localhost:8080",
  "api_token": "test",
  "input": {
    "operation": "lowercase",
    "message": "HELLO WORLD"
  },
  "sources": {}
}' | docker run --rm -i ${IMAGE_NAME})

if echo "$OUTPUT" | jq -e '.output.message == "hello world"' > /dev/null; then
  log_success "Test 3 passed"
else
  log_error "Test 3 failed"
  echo "Output: $OUTPUT"
  exit 1
fi

# Test 4: Error handling - invalid operation
echo "Test 4: Error handling (invalid operation)"
OUTPUT=$(echo '{
  "workspace_id": "test",
  "stf_id": "test",
  "caller": null,
  "api_url": "http://localhost:8080",
  "api_token": "test",
  "input": {
    "operation": "invalid",
    "message": "test"
  },
  "sources": {}
}' | docker run --rm -i ${IMAGE_NAME} 2>/dev/null || true)

if echo "$OUTPUT" | jq -e '.error' > /dev/null; then
  log_success "Test 4 passed (error handled correctly)"
else
  log_error "Test 4 failed (error not handled)"
  echo "Output: $OUTPUT"
  exit 1
fi

# Test 5: Error handling - missing message
echo "Test 5: Error handling (missing message)"
OUTPUT=$(echo '{
  "workspace_id": "test",
  "stf_id": "test",
  "caller": null,
  "api_url": "http://localhost:8080",
  "api_token": "test",
  "input": {
    "operation": "echo"
  },
  "sources": {}
}' | docker run --rm -i ${IMAGE_NAME} 2>/dev/null || true)

if echo "$OUTPUT" | jq -e '.error' > /dev/null; then
  log_success "Test 5 passed (error handled correctly)"
else
  log_error "Test 5 failed (error not handled)"
  echo "Output: $OUTPUT"
  exit 1
fi

# Test 6: Describe operation
echo "Test 6: Describe operation"
OUTPUT=$(echo '{
  "workspace_id": "test",
  "stf_id": "test",
  "caller": null,
  "api_url": "http://localhost:8080",
  "api_token": "test",
  "input": {
    "operation": "describe"
  },
  "sources": {}
}' | docker run --rm -i ${IMAGE_NAME})

if echo "$OUTPUT" | jq -e '.output.status == "success" and .output.operation == "describe" and .output.data.input_schema and .output.data.operations' > /dev/null; then
  log_success "Test 6 passed"
else
  log_error "Test 6 failed"
  echo "Output: $OUTPUT"
  exit 1
fi

echo ""
log_success "All tests passed!"
