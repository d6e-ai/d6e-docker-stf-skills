# D6E Agent Skills

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

### [D6E Docker STF Development](./d6e-docker-stf-development.md)

Teaches how to create custom Docker-based STFs for D6E, including:
- Input/output JSON formats
- SQL API integration
- Multi-language implementations (Python, Node.js, Go)
- Best practices and security guidelines
- Common patterns and examples
- Troubleshooting guide

## 🚀 How to Use

### For Developers

1. **Open this repository in Claude/Cursor**
2. **Reference the skill** when asking for help:
   ```
   Using the D6E Docker STF Development skill,
   create a data validation skill that checks...
   ```
3. **Claude/Cursor will generate** appropriate code following D6E patterns

### For Claude/Cursor

When a user requests help with D6E Docker STFs:
1. Read the relevant skill document
2. Apply the patterns and guidelines
3. Generate code that follows D6E conventions
4. Include necessary files (Dockerfile, requirements.txt, etc.)
5. Provide testing and deployment instructions

## 📖 What You'll Learn

- **D6E Architecture**: How Docker STFs fit into D6E workflows
- **Input/Output Formats**: Standard JSON schemas for communication
- **SQL API**: Secure database access from Docker containers
- **Multi-Language Support**: Python, Node.js, and Go examples
- **Security**: Policy-based access control and best practices
- **Testing**: Local testing before deployment
- **Publishing**: Container registry setup and distribution

## 🛠️ Quick Example

With this Agent Skill loaded, you can ask Claude/Cursor:

```
Create a D6E skill that:
1. Fetches data from an external API
2. Validates the data
3. Stores it in a D6E database table
```

And you'll get a complete implementation including:
- Python/Node.js/Go source code
- Dockerfile
- Dependencies file
- Testing instructions
- Deployment guide

## 🔗 Related Resources

- [D6E Platform](https://github.com/KimuraYu45z/d6e)
- [D6E Docker Runtime Guide](https://github.com/KimuraYu45z/d6e/blob/main/docs/08-stf-docker-runtime.md)
- [Claude Agent Skills Documentation](https://docs.claude.com/en/docs/agents-and-tools/agent-skills/overview)
- [Model Context Protocol](https://modelcontextprotocol.io)

## 🤝 Contributing

Contributions are welcome! To add new skills or improve existing ones:

1. Fork this repository
2. Create a new skill document following the format
3. Submit a pull request

### Skill Document Format

Each skill should include:
- **Overview**: What the skill teaches
- **When to Use**: Scenarios where the skill applies
- **How to**: Step-by-step instructions
- **Best Practices**: Guidelines and recommendations
- **Examples**: Concrete code samples
- **Troubleshooting**: Common issues and solutions
- **Reference**: Technical specifications

## 📝 License

MIT License - see [LICENSE](LICENSE) for details

## 🌟 Why Agent Skills for D6E?

Traditional documentation tells developers **what** to do. Agent Skills teach AI assistants **how** to help developers do it correctly. This means:

- ✅ **Faster Development**: Claude/Cursor generates correct code instantly
- ✅ **Fewer Errors**: Follows D6E conventions automatically
- ✅ **Best Practices**: Security and performance baked in
- ✅ **Up-to-date**: Easy to update as D6E evolves
- ✅ **Accessible**: Developers don't need to memorize APIs

## 🎓 Learn More

- [Agent Skills Overview](https://docs.claude.com/en/docs/agents-and-tools/agent-skills/overview)
- [Creating Agent Skills](https://docs.claude.com/en/docs/agents-and-tools/agent-skills/creating)
- [D6E Documentation](https://github.com/KimuraYu45z/d6e)
