# Echo Docker STF Example

A simple Echo Docker STF implementation demonstrating the basic structure of a D6E Docker STF.

## Features

This Docker STF supports the following operations:

- **echo**: Return input message as-is
- **uppercase**: Convert message to uppercase
- **lowercase**: Convert message to lowercase

## File Structure

```
echo-stf/
├── main.py          # Main Python script
├── Dockerfile       # Docker image definition
└── README.md        # This file
```

## Build

```bash
cd examples/echo-stf
docker build -t echo-stf:latest .
```

## Local Testing

### 1. Echo Operation

```bash
echo '{
  "workspace_id": "01234567-89ab-cdef-0123-456789abcdef",
  "stf_id": "01234567-89ab-cdef-0123-456789abcdef",
  "caller": null,
  "api_url": "http://localhost:8080",
  "api_token": "test-token",
  "input": {
    "operation": "echo",
    "message": "Hello, D6E!"
  },
  "sources": {}
}' | docker run --rm -i echo-stf:latest
```

**Expected output:**

```json
{
  "output": {
    "status": "success",
    "operation": "echo",
    "message": "Hello, D6E!"
  }
}
```

### 2. Uppercase Operation

```bash
echo '{
  "workspace_id": "01234567-89ab-cdef-0123-456789abcdef",
  "stf_id": "01234567-89ab-cdef-0123-456789abcdef",
  "caller": null,
  "api_url": "http://localhost:8080",
  "api_token": "test-token",
  "input": {
    "operation": "uppercase",
    "message": "hello world"
  },
  "sources": {}
}' | docker run --rm -i echo-stf:latest
```

**Expected output:**

```json
{
  "output": {
    "status": "success",
    "operation": "uppercase",
    "message": "HELLO WORLD"
  }
}
```

### 3. Lowercase Operation

```bash
echo '{
  "workspace_id": "01234567-89ab-cdef-0123-456789abcdef",
  "stf_id": "01234567-89ab-cdef-0123-456789abcdef",
  "caller": null,
  "api_url": "http://localhost:8080",
  "api_token": "test-token",
  "input": {
    "operation": "lowercase",
    "message": "HELLO WORLD"
  },
  "sources": {}
}' | docker run --rm -i echo-stf:latest
```

**Expected output:**

```json
{
  "output": {
    "status": "success",
    "operation": "lowercase",
    "message": "hello world"
  }
}
```

### 4. Error Handling

```bash
echo '{
  "workspace_id": "01234567-89ab-cdef-0123-456789abcdef",
  "stf_id": "01234567-89ab-cdef-0123-456789abcdef",
  "caller": null,
  "api_url": "http://localhost:8080",
  "api_token": "test-token",
  "input": {
    "operation": "invalid_operation",
    "message": "test"
  },
  "sources": {}
}' | docker run --rm -i echo-stf:latest
```

**Expected output:**

```json
{
  "error": "Unknown operation: invalid_operation",
  "type": "ValueError"
}
```

## Using with D6E

### 1. Create STF

```javascript
d6e_create_stf({
  name: "echo-stf",
  description: "Simple echo Docker STF"
});
// → Note the stf_id
```

### 2. Create STF Version

```javascript
d6e_create_stf_version({
  stf_id: "{stf_id}",
  version: "1.0.0",
  runtime: "docker",
  code: '{"image":"echo-stf:latest"}'
});
```

### 3. Create Workflow

```javascript
d6e_create_workflow({
  name: "echo-workflow",
  stf_steps: [{
    stf_id: "{stf_id}",
    version: "1.0.0"
  }]
});
// → Note the workflow_id
```

### 4. Execute Workflow

```javascript
// Echo operation
d6e_execute_workflow({
  workflow_id: "{workflow_id}",
  input: {
    operation: "echo",
    message: "Hello from D6E!"
  }
});

// Uppercase operation
d6e_execute_workflow({
  workflow_id: "{workflow_id}",
  input: {
    operation: "uppercase",
    message: "hello d6e"
  }
});
```

## Code Explanation

### main.py

```python
def main():
    """Main entry point"""
    try:
        # 1. Read JSON input from stdin
        input_data = json.load(sys.stdin)
        
        # 2. Extract user input
        user_input = input_data.get("input", {})
        operation = user_input.get("operation", "echo")
        message = user_input.get("message", "")
        
        # 3. Execute operation
        result = process_operation(operation, message)
        
        # 4. Output JSON result to stdout
        print(json.dumps({"output": result}))
        
    except Exception as e:
        # Error handling
        print(json.dumps({"error": str(e), "type": type(e).__name__}))
        sys.exit(1)
```

### Key Points

1. **Input**: Read JSON from stdin
2. **Output**: Write JSON to stdout (`{"output": {...}}` format)
3. **Logging**: Log to stderr (stdout is reserved for results)
4. **Errors**: Catch exceptions appropriately and return JSON errors

## Customization

Build your own Docker STF based on this example:

1. **Add new operations**
   ```python
   def process_reverse(message):
       """Reverse operation - reverses the message"""
       return {
           "status": "success",
           "operation": "reverse",
           "message": message[::-1]
       }
   ```

2. **Add database operations**
   ```python
   import requests
   
   def execute_sql(api_url, api_token, workspace_id, stf_id, sql):
       """Execute SQL via D6E internal API"""
       # SQL API call logic
       pass
   ```

3. **Add external API integration**
   ```python
   def call_external_api(url, params):
       """Call external API"""
       response = requests.get(url, params=params, timeout=10)
       return response.json()
   ```

## Related Documentation

- [Quick Start Guide](../../docs/QUICKSTART.md) - 5-minute quick start
- [Developer Guide](../../docs/DEVELOPER_GUIDE.md) - Detailed development guide
- [D6E Docker STF Development Skill](../../skills/d6e-docker-stf-development.md) - Complete skill document
- [Testing Guide](../../docs/TESTING.md) - Testing methods
- [Publishing Guide](../../docs/PUBLISHING.md) - How to publish

## License

MIT License - feel free to use and modify.
