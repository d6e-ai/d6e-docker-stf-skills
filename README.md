# D6E Docker STF Skills

[![Skills](https://img.shields.io/badge/skills.sh-d6e--docker--stf--skills-blue)](https://skills.sh)
[![GitHub](https://img.shields.io/github/stars/d6e-ai/d6e-docker-stf-skills?style=social)](https://github.com/d6e-ai/d6e-docker-stf-skills)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Claude/Cursor Agent Skills for developing custom D6E Docker STFs.

## 📚 What is This?

This repository contains **Agent Skills** that teach Claude and Cursor how to help developers create custom Docker-based State Transition Functions (STFs) for the D6E platform.

### What are Agent Skills?

Agent Skills are Markdown documents that provide AI assistants with domain-specific knowledge and workflows. They enable Claude/Cursor to:

- Understand D6E's Docker STF architecture
- Generate correct implementation patterns
- Guide developers through the creation process
- Provide best practices and troubleshooting

## 🎯 Available Skills

### [D6E Docker STF Development](./skills/d6e-docker-stf-development/SKILL.md)

Teaches Claude/Cursor how to help developers create custom Docker-based STFs for D6E, including:

- Input/output JSON formats
- SQL API integration
- Multi-language implementations (Python, Node.js, Go)
- Best practices and security guidelines
- The `describe` operation for self-documenting STFs
- Common patterns and examples
- Troubleshooting guide

## 📦 Installation

### Quick Install (Recommended)

Install this skill using the skills.sh CLI:

```bash
npx skills add d6e-ai/d6e-docker-stf-skills
```

This will automatically set up the skill in your Cursor environment.

### Manual Installation

#### For Cursor

1. **Clone the repository:**
   ```bash
   git clone https://github.com/d6e-ai/d6e-docker-stf-skills.git
   ```

2. **Add to Cursor:**
   - Open Cursor Settings (Cmd/Ctrl + ,)
   - Navigate to "Features" → "Agent Skills"
   - Add skill directory: `/path/to/d6e-docker-stf-skills/skills/d6e-docker-stf-development`

3. **Verify installation:**
   - Open Composer (Cmd/Ctrl + I)
   - Type `@skills` to see available skills
   - You should see "d6e-docker-stf-development"

#### For Claude Code

1. **Clone the repository:**
   ```bash
   git clone https://github.com/d6e-ai/d6e-docker-stf-skills.git
   ```

2. **Reference the skill:**
   - In your project, reference `@skills/d6e-docker-stf-development/SKILL.md`
   - Claude will automatically load the skill content

## 🚀 How to Use

### Quick Start (5 minutes)

**New to D6E Docker STFs?** Start with the **[Quick Start Guide](./docs/QUICKSTART.md)** to create your first Docker STF in 5 minutes!

### For Cursor Users

1. **Open this repository in Cursor**

   ```bash
   git clone https://github.com/d6e-ai/d6e-docker-stf-skills.git
   cd d6e-docker-stf-skills
   cursor .
   ```

2. **Open Composer (Cmd/Ctrl + I)**

3. **Paste a prompt** (choose from [AI Prompts](./docs/AI-PROMPTS.md))

   ```
   Using the D6E Docker STF Development skill, create a Docker STF for data validation.

   Requirements:
   - Python implementation
   - Fetch data from database
   - Apply validation rules
   - Return results
   ```

4. **Review and test the generated code**

### For Claude Code Users

1. **Open the project**

2. **Reference the skill document**

   ```
   Using @skills/d6e-docker-stf-development/SKILL.md, create a simple Echo Docker STF.
   ```

3. **Review and test the generated code**

### For Developers

#### 📖 Documentation

- **[Quick Start](./docs/QUICKSTART.md)** - Create a Docker STF in 5 minutes
- **[Developer Guide](./docs/DEVELOPER_GUIDE.md)** - Detailed development guide
- **[AI Prompts](./docs/AI-PROMPTS.md)** - Copy-paste prompt collection
- **[Testing Guide](./docs/TESTING.md)** - Testing methods
- **[Publishing Guide](./docs/PUBLISHING.md)** - How to publish Docker images
- **[D6E Docker STF Development Skill](./skills/d6e-docker-stf-development/SKILL.md)** - Complete skill document

#### 🔄 Workflow

1. **Develop**: Generate code with Cursor/Claude Code
2. **Test**: Test locally with Docker
3. **Publish**: Publish to Container Registry
4. **Deploy**: Use in D6E

### For AI Assistants (Claude/Cursor)

When a user requests help with D6E Docker STFs:

1. Read the relevant skill document (`skills/d6e-docker-stf-development/SKILL.md`)
2. Apply the patterns and guidelines
3. Generate code that follows D6E conventions
4. **Always include the `describe` operation** in every generated STF
5. Include necessary files (Dockerfile, requirements.txt, etc.)
6. Provide testing and deployment instructions
7. When creating workflows, **run `describe` first** to discover input schema
8. Reference the appropriate documentation for more details

## 📖 What You'll Learn

- **D6E Architecture**: How Docker STFs fit into D6E workflows
- **Input/Output Formats**: Standard JSON schemas for communication
- **The `describe` Operation**: Self-documenting STFs that expose their input schema and available operations
- **SQL API**: Secure database access from Docker containers
- **Multi-Language Support**: Python, Node.js, and Go examples
- **Security**: Policy-based access control and best practices
- **Testing**: Local testing before deployment
- **Publishing**: Container registry setup and distribution

## 🛠️ Quick Example

### Example 1: Simple Echo STF

**Prompt:**

```
Using the D6E Docker STF Development skill, create a simple Echo Docker STF.

Requirements:
- Python implementation
- operation: "echo"
- Error handling
- Include Dockerfile, requirements.txt, and README.md
```

**Generated files:**

- `main.py` - Main logic
- `Dockerfile` - Container definition
- `requirements.txt` - Dependencies
- `README.md` - Usage instructions

### Example 2: Database Query STF

**Prompt:**

```
Using the D6E Docker STF Development skill, create a Docker STF that fetches data from the database.

Requirements:
- Node.js (TypeScript) implementation
- operation: "query_data"
- Use SQL API to fetch data
- Include policy configuration instructions
```

### Example 3: External API Integration

**Prompt:**

```
Using the D6E Docker STF Development skill, create a Docker STF that integrates with an external API.

Requirements:
- Python implementation
- Fetch data from external API
- Store in D6E database
- Error handling and retry logic
```

For more prompt examples, see **[AI Prompts](./docs/AI-PROMPTS.md)**.

### The `describe` Operation

Every Docker STF implements a `describe` operation that returns its input schema and available operations. This enables workflow builders and AI agents to discover capabilities before creating workflows.

```bash
# Discover what an STF supports
echo '{"workspace_id":"test","stf_id":"test","caller":null,"api_url":"http://localhost:8080","api_token":"test","input":{"operation":"describe"},"sources":{}}' \
  | docker run --rm -i echo-stf:latest
```

This returns the full input schema, including all operations, required parameters, and optional parameters. See the [skill document](./skills/d6e-docker-stf-development/SKILL.md#the-describe-operation) for details.

### Real Sample Code

**[examples/echo-stf](./examples/echo-stf/)** contains a working simple Docker STF example with the `describe` operation implemented.

```bash
cd examples/echo-stf
./test-local.sh  # Build & test (includes describe test)
```

## 🔗 Related Resources

### Documentation

- **[Quick Start Guide](./docs/QUICKSTART.md)** - 5-minute quick start
- **[AI Prompts Collection](./docs/AI-PROMPTS.md)** - Ready-to-use prompts
- **[Developer Guide](./docs/DEVELOPER_GUIDE.md)** - Detailed development guide
- **[Testing Guide](./docs/TESTING.md)** - Comprehensive testing methods
- **[Publishing Guide](./docs/PUBLISHING.md)** - How to publish images

### External Resources

- [skills.sh](https://skills.sh) - The Open Agent Skills Ecosystem
- [D6E Platform](https://github.com/d6e-ai/d6e) - D6E main repository
- [D6E Docker Runtime Guide](https://github.com/d6e-ai/d6e/blob/main/docs/08-stf-docker-runtime.md) - Docker Runtime details
- [d6e-test-docker-skill](https://github.com/Senna46/d6e-test-docker-skill) - Sample Docker STF
- [Claude Agent Skills Documentation](https://docs.claude.com/en/docs/agents-and-tools/agent-skills/overview) - Agent Skills overview
- [Model Context Protocol](https://modelcontextprotocol.io) - MCP specification

## 🤝 Contributing

Contributions are welcome! Help us add new skills or improve existing ones.

For detailed guidelines, see **[CONTRIBUTING.md](./docs/CONTRIBUTING.md)**.

### Simple Contribution Steps

1. **Fork the repository**
2. **Make changes** (documentation improvements, samples, bug fixes, etc.)
3. **Create a Pull Request**

### What You Can Contribute

- 📝 Documentation improvements (typo fixes, clarifications)
- 💡 New prompt examples
- 🐛 Bug reports and fixes
- 🎯 New Agent Skills
- 📚 Sample code

### Skill Document Format

New skills should include:

- **Overview**: Skill overview
- **When to Use**: When to use it
- **How to**: Step-by-step instructions
- **Best Practices**: Best practices
- **Examples**: Concrete code examples
- **Troubleshooting**: Troubleshooting
- **Reference**: Technical specifications

For details, see [CONTRIBUTING.md](./docs/CONTRIBUTING.md).

## 📝 License

MIT License - see [LICENSE](LICENSE) for details

## 🌟 Why Agent Skills for D6E?

Traditional documentation tells developers **what** to do. Agent Skills teach AI assistants **how** to help developers create D6E Docker STFs correctly. This means:

- ✅ **Faster Development**: Claude/Cursor generates correct code instantly
- ✅ **Fewer Errors**: Follows D6E conventions automatically
- ✅ **Self-Documenting STFs**: The `describe` operation eliminates guesswork when building workflows
- ✅ **Best Practices**: Security and performance baked in
- ✅ **Up-to-date**: Easy to update as D6E evolves
- ✅ **Accessible**: Developers don't need to memorize APIs

## 💻 Using with Cursor and Claude Code

### Using with Cursor

Cursor automatically recognizes `.md` files as Agent Skills.

1. **Open repository**

   ```bash
   cursor /path/to/agent-skills
   ```

2. **Use Composer (Cmd/Ctrl + I)**

   - Composer automatically loads skill documents
   - Paste prompts and get appropriate code generated

3. **Use @mention feature (optional)**

   ```
   Using @skills/d6e-docker-stf-development/SKILL.md, create an Echo Docker STF.
   ```

4. **Also available in Chat**
   - Regular chat can also reference skill documents

### Using with Claude Code

In Claude Code, you must explicitly reference skill documents.

1. **Open project**

2. **Reference skill document**

   ```
   Using @skills/d6e-docker-stf-development/SKILL.md, implement [your requirements].
   ```

3. **Or add skill document to context**
   - Open file to review content
   - Add to context

### Prompt Best Practices

#### ✅ Good Prompt

```
Using the D6E Docker STF Development skill, create a Docker STF with the following requirements:

Language: Python 3.11
Operation: "process_data"
Input format: { "data": [...], "operation_type": "validate" }
Output format: { "status": "success", "results": [...] }

Required files:
- main.py
- Dockerfile (use python:3.11-slim)
- requirements.txt
- README.md

Include error handling and logging.
```

#### ❌ Bad Prompt

```
Create a Docker STF
```

Reason: Lacks specificity and expected results are unclear

## 🎓 Learn More

### This Repository

- **[Quick Start](./docs/QUICKSTART.md)** - Get started in 5 minutes
- **[AI Prompts](./docs/AI-PROMPTS.md)** - Prompt examples
- **[Developer Guide](./docs/DEVELOPER_GUIDE.md)** - Detailed guide
- **[Testing Guide](./docs/TESTING.md)** - Testing methods
- **[Publishing Guide](./docs/PUBLISHING.md)** - Publishing methods

### External Resources

- [Agent Skills Overview](https://docs.claude.com/en/docs/agents-and-tools/agent-skills/overview) - Agent Skills overview
- [Creating Agent Skills](https://docs.claude.com/en/docs/agents-and-tools/agent-skills/creating) - How to create Agent Skills
- [D6E Documentation](https://github.com/d6e-ai/d6e) - D6E platform
- [d6e-test-docker-skill](https://github.com/Senna46/d6e-test-docker-skill) - Sample project
