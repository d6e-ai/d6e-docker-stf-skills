# Quick Start: D6E Docker STF Development with AI

This guide shows you how to create and deploy your first D6E Docker STF **in 5 minutes** using Cursor or Claude Code.

## 📋 Prerequisites

- **Cursor** or **Claude Code** installed
- **D6E** instance running (local or remote), and a workspace you are a
  member of. Note your **workspace ID** — it is the UUID in every d6e
  console URL (`/workspaces/{uuid}/...`)
- **Docker** installed
- This repository cloned

For deployment steps that hit the d6e REST API directly you also need a
Bearer token: copy the `auth-token` cookie from a logged-in d6e console
session, or mint a long-lived API key via `POST /api/v1/api-keys` (see
[TESTING.md](./TESTING.md#end-to-end-testing) for the exact commands).
When you work through an AI agent chatting *inside* d6e, the MCP tools
authenticate automatically and no token is needed.

## 🚀 5-Minute Quick Start

### Step 1: Open Repository (30 seconds)

```bash
# Clone the repository
git clone https://github.com/d6e-ai/d6e-docker-stf-skills.git
cd d6e-docker-stf-skills

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
Using @skills/d6e-docker-stf-development/SKILL.md, create a simple Echo Docker STF.

Requirements: same as above
```

2. Review generated files:
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
1. Create STF + first version with d6e_create_stf
   (version: "1.0.0", runtime: "docker", code: '{"image":"echo-stf:latest"}')
2. Verify with d6e_describe_stf and d6e_instant_run_stf
3. Create workflow with d6e_create_workflow (stf_steps use stf_version_id)
4. Test execution with d6e_execute_workflow

Use D6E MCP tools.
```

**For Manual Deployment:**

In D6E web interface or MCP tools, execute:

```javascript
// 1. Create STF (one call creates the STF and its first version)
d6e_create_stf({
  name: "echo-stf",
  description: "Simple echo Docker STF",
  version: "1.0.0",
  runtime: "docker",
  code: '{"image":"echo-stf:latest"}',
});
// → Note the stf_id (and stf_version_id)

// 2. Verify: schema + one-off run (no workflow needed)
d6e_describe_stf({ id: "{stf_id}" });
d6e_instant_run_stf({
  stf_id: "{stf_id}",
  input: { operation: "echo", message: "Hello from D6E!" },
});

// 3. Create workflow (reference the version, map the inputs)
d6e_create_workflow({
  name: "echo-workflow",
  input_steps: [],
  stf_steps: [
    {
      stf_version_id: "{stf_version_id}",
      input_mappings: [
        { source: { type: "Variable", value: "$input.operation" }, target: "operation" },
        { source: { type: "Variable", value: "$input.message" }, target: "message" },
      ],
    },
  ],
  effect_steps: [],
});
// → Note the workflow_id

// 4. Execute
d6e_execute_workflow({
  id: "{workflow_id}",
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
- **[D6E Docker STF Development Skill](../skills/d6e-docker-stf-development/SKILL.md)** - Complete skill document
- **[AI Prompts](./AI-PROMPTS.md)** - Copy-paste prompt collection

### Advanced Topics

- **[Testing Guide](./TESTING.md)** - Testing procedures
- **[Publishing Guide](./PUBLISHING.md)** - How to publish Docker images
- **[Best Practices](../skills/d6e-docker-stf-development/SKILL.md#best-practices)** - Best practices

### Sample Projects

Real Docker STF examples:

- **[examples/echo-stf](../examples/echo-stf/)** - Working echo STF in this repository (build & test with `./test-local.sh`)

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

### Q: Policy errors occur (POLICY_DENIED)

For Docker STFs with database operations, policy configuration is required.
Membership is passed directly via `stf_ids` (there is no separate
"add member" tool):

```javascript
// Create policy group with the STF as a member
d6e_create_policy_group({
  name: "echo-stf-group",
  user_ids: [],
  stf_ids: ["{stf_id}"],
});

// Create policy (name is required)
d6e_create_policy({
  name: "echo-stf select messages",
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

In Cursor, mentioning `@skills/d6e-docker-stf-development/SKILL.md` helps the AI reference the skill document.

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

Install the skill once with the skills.sh CLI and Cursor picks it up
automatically:

```bash
npx skills add d6e-ai/d6e-docker-stf-skills --skill d6e-docker-stf-development
```

Alternatively, open this repository directly and reference
`skills/d6e-docker-stf-development/SKILL.md` in your prompt.

### Using Skills with Claude Code

In Claude Code, you must explicitly reference skill documents:

```
Using @skills/d6e-docker-stf-development/SKILL.md, implement [your requirements].
```

---

## 🤝 Support

For questions or issues:

- **GitHub Issues**: https://github.com/d6e-ai/d6e-docker-stf-skills/issues
- **D6E Documentation**: https://github.com/d6e-ai/d6e

---

**Happy Coding! 🚀**

Next, check the [Developer Guide](./DEVELOPER_GUIDE.md) to learn more advanced features!
