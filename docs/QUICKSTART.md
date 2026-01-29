# Quick Start: D6E Docker STF Development with AI

This guide shows you how to create and deploy your first D6E Docker STF **in 5 minutes** using Cursor or Claude Code.

## 📋 Prerequisites

- **Cursor** or **Claude Code** installed
- **D6E** instance running (local or remote)
- **Docker** installed
- This repository cloned

## 🚀 5-Minute Quick Start

### Step 1: Open Repository (30 seconds)

```bash
# Clone the repository
git clone https://github.com/d6e-ai/agent-skills.git
cd agent-skills

# Open in Cursor
cursor .

# Or open in Claude Code
```

### Step 2: Generate Docker STF (2 minutes)

**For Cursor:**

1. Open Composer (`Cmd/Ctrl + I`)
2. Paste this prompt:

```
Using the D6E Docker STF Development skill, create a simple Echo Docker STF.

Requirements:
- Python implementation
- Return input data as-is (operation: "echo")
- Include error handling
- Include Dockerfile, requirements.txt, and README.md

Location: ../examples/echo-stf/
```

**For Claude Code:**

1. Paste this in the chat window:

```
Using @skills/d6e-docker-stf-development.md, create a simple Echo Docker STF.

Requirements: same as above
```

3. Review generated files:
   - `examples/echo-stf/main.py`
   - `examples/echo-stf/Dockerfile`
   - `examples/echo-stf/requirements.txt`
   - `examples/echo-stf/README.md`

### Step 3: Build Docker Image (1 minute)

```bash
cd examples/echo-stf
docker build -t echo-stf:latest .
```

### Step 4: Local Test (30 seconds)

```bash
# Create test input
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

### Step 5: Deploy to D6E (1 minute)

**For Cursor:**

Paste this in Composer:

```
Deploy echo-stf to D6E.

Steps:
1. Create STF with d6e_create_stf
2. Register Docker image with d6e_create_stf_version (image: "echo-stf:latest")
3. Create workflow with d6e_create_workflow
4. Test execution with d6e_execute_workflow

Use D6E MCP tools.
```

**For Manual Deployment:**

In D6E web interface or MCP tools, execute:

```javascript
// 1. Create STF
d6e_create_stf({
  name: "echo-stf",
  description: "Simple echo Docker STF",
});
// → Note the stf_id

// 2. Create STF version
d6e_create_stf_version({
  stf_id: "{stf_id from above}",
  version: "1.0.0",
  runtime: "docker",
  code: '{"image":"echo-stf:latest"}',
});

// 3. Create workflow
d6e_create_workflow({
  name: "echo-workflow",
  stf_steps: [
    {
      stf_id: "{stf_id}",
      version: "1.0.0",
    },
  ],
});
// → Note the workflow_id

// 4. Execute
d6e_execute_workflow({
  workflow_id: "{workflow_id}",
  input: {
    operation: "echo",
    message: "Hello from D6E!",
  },
});
```

## 🎉 Done!

Congratulations! Your first D6E Docker STF is now running!

---

## 🔄 Next Steps

### 1. Add Database Operations (10 minutes)

```
Add database operations to the Echo STF.

New operations:
- "save_message" - Save message to database
- "list_messages" - Retrieve saved messages

Table schema:
CREATE TABLE messages (
  id UUID PRIMARY KEY DEFAULT uuidv7(),
  message TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

Include policy configuration.
```

### 2. Add External API Integration (15 minutes)

```
Add external API calls to the Echo STF.

New operations:
- "translate" - Translate with Google Translate API (mock implementation OK)
- "sentiment" - Analyze sentiment with API (mock implementation OK)

Include error handling and retry logic.
```

### 3. Support Multiple Operations (20 minutes)

```
Expand Echo STF to a multi-function STF.

Operations:
- "echo" - Echo
- "uppercase" - Convert to uppercase
- "lowercase" - Convert to lowercase
- "reverse" - Reverse string
- "word_count" - Count words

Include tests for each operation.
```

---

## 📚 Learn More

### Basic Guides

- **[Developer Guide](./DEVELOPER_GUIDE.md)** - Detailed development guide
- **[D6E Docker STF Development Skill](../skills/d6e-docker-stf-development.md)** - Complete skill document
- **[AI Prompts](./AI-PROMPTS.md)** - Copy-paste prompt collection

### Advanced Topics

- **[Testing Guide](./TESTING.md)** - Testing procedures
- **[Publishing Guide](./PUBLISHING.md)** - How to publish Docker images
- **[Best Practices](../skills/d6e-docker-stf-development.md#best-practices)** - Best practices

### Sample Projects

Real Docker STF examples:

- **[d6e-test-docker-skill](https://github.com/Senna46/d6e-test-docker-skill)** - Test Docker STF

---

## 🔧 Troubleshooting

### Q: Docker image build fails

```bash
# Check Docker daemon is running
docker ps

# Check error message
docker build -t echo-stf:latest . --no-cache
```

### Q: Image not found in D6E

```bash
# Check if image is visible from D6E API server
docker exec d6e-api-1 docker images | grep echo-stf

# Check if using same Docker daemon as D6E API server
```

Solutions:

1. If using Docker Compose, check volume mounts
2. Publish image to Docker Registry (see [PUBLISHING.md](./PUBLISHING.md))

### Q: Policy errors occur

For Docker STFs with database operations, policy configuration is required:

```javascript
// Create policy group
d6e_create_policy_group({ name: "echo-stf-group" });

// Add STF to group
d6e_add_member_to_policy_group({
  policy_group_id: "{policy_group_id}",
  member_type: "stf",
  member_id: "{stf_id}",
});

// Create policy
d6e_create_policy({
  policy_group_id: "{policy_group_id}",
  table_name: "messages",
  operation: "select",
  mode: "allow",
});
```

### Q: Cursor/Claude Code doesn't generate expected code

Use more specific prompts:

❌ **Bad:**

```
Create a Docker STF
```

✅ **Good:**

```
Using the D6E Docker STF Development skill, create a Docker STF with the following requirements:

Language: Python 3.11
Operation: "process_data"
Input: { "data": [...], "operation_type": "validate" }
Output: { "status": "success", "results": [...] }

Required files:
- main.py
- Dockerfile (use python:3.11-slim)
- requirements.txt
- README.md

Include error handling and logging.
```

---

## 💡 Pro Tips

### 1. Always Reference Agent Skills

In Cursor, mentioning `@skills/d6e-docker-stf-development.md` helps the AI reference the skill document.

### 2. Develop Incrementally

1. Start with simple implementation
2. Add basic features
3. Improve error handling
4. Add tests
5. Enrich documentation

### 3. Use Copy-Paste Prompts

[AI-PROMPTS.md](./AI-PROMPTS.md) has many ready-to-use prompts.

### 4. Test Thoroughly Locally

Always test locally before deploying to D6E:

```bash
./test-local.sh  # Create test script
```

### 5. Optimize Image Size

Use multi-stage builds to reduce image size:

```dockerfile
FROM python:3.11 AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

FROM python:3.11-slim
WORKDIR /app
COPY --from=builder /root/.local /root/.local
COPY main.py .
ENV PATH=/root/.local/bin:$PATH
ENTRYPOINT ["python3", "main.py"]
```

---

## 📖 More Details

### Using Agent Skills with Cursor

Cursor automatically recognizes `.md` files in the `.cursor/rules/` directory and root. This repository includes:

- `d6e-docker-stf-development.md` - Docker STF development skill

These are automatically loaded and can be referenced by the AI assistant.

### Using Skills with Claude Code

In Claude Code, you must explicitly reference skill documents:

```
Using @skills/d6e-docker-stf-development.md, implement [your requirements].
```

---

## 🤝 Support

For questions or issues:

- **GitHub Issues**: https://github.com/d6e-ai/agent-skills/issues
- **GitHub Discussions**: https://github.com/d6e-ai/agent-skills/discussions
- **D6E Documentation**: https://github.com/d6e-ai/d6e

---

**Happy Coding! 🚀**

Next, check the [Developer Guide](./DEVELOPER_GUIDE.md) to learn more advanced features!
