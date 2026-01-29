# Contributing to D6E Agent Skills

We welcome contributions to this project! This guide explains how to contribute.

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Types of Contributions](#types-of-contributions)
- [Development Environment Setup](#development-environment-setup)
- [Contribution Process](#contribution-process)
- [Creating Skill Documents](#creating-skill-documents)
- [Code Style](#code-style)
- [Review Process](#review-process)

---

## Code of Conduct

This project expects all participants to treat each other with respect.

- Provide constructive feedback
- Respect other contributors' opinions
- Maintain an open and cooperative attitude

---

## Types of Contributions

We welcome the following types of contributions:

### 1. Documentation Improvements

- Typo fixes
- Clarifying explanations
- Adding new examples
- Translation improvements

### 2. Adding New Agent Skills

- New D6E-related skills
- Extending existing skills
- New prompt examples

### 3. Adding Sample Code

- Working Docker STF examples
- Adding test cases
- Best practice implementation examples

### 4. Bug Reports

- Documentation errors
- Broken links
- Code example issues

### 5. Feature Requests

- Proposing new guides
- Proposing new prompt patterns
- Tool and script suggestions

---

## Development Environment Setup

### Prerequisites

- Git
- GitHub account
- Text editor (Cursor, VS Code, etc.)
- Markdown preview tool (optional)

### Setup Steps

1. **Fork the repository**

   - Open [d6e-docker-stf-skills](https://github.com/d6e-ai/d6e-docker-stf-skills) on GitHub
   - Click the "Fork" button in the top right

2. **Clone**

   ```bash
   git clone https://github.com/YOUR_USERNAME/agent-skills.git
   cd agent-skills
   ```

3. **Add upstream**

   ```bash
   git remote add upstream https://github.com/d6e-ai/d6e-docker-stf-skills.git
   ```

4. **Fetch latest changes**
   ```bash
   git fetch upstream
   git checkout main
   git merge upstream/main
   ```

---

## Contribution Process

### 1. Create an Issue (Optional but Recommended)

Before making large changes, we recommend creating an Issue to discuss.

```
Title: [TYPE] Brief description

Examples:
- [Docs] Fix typo in Quick Start Guide
- [Skill] Add new skill for X
- [Example] Add example for Y
```

### 2. Create a Branch

```bash
# Create a new branch
git checkout -b feature/your-feature-name

# or
git checkout -b fix/your-fix-name
```

Branch naming conventions:

- `feature/` - New features
- `fix/` - Bug fixes
- `docs/` - Documentation changes
- `refactor/` - Refactoring

### 3. Make Changes

#### Documentation Changes

- Check Markdown syntax
- Verify links work correctly
- Check display in preview

#### Adding Code Examples

- Verify it actually works
- Add appropriate comments
- Update README.md

#### Creating Skill Documents

Include the following sections:

```markdown
# Skill Name

## Overview

[Overview of the skill]

## When to Use This Skill

[When to use it]

## How to [Task]

[Specific steps]

## Best Practices

[Best practices]

## Examples

[Code examples]

## Troubleshooting

[Troubleshooting]

## Reference

[Technical specifications]
```

### 4. Commit

Write commit messages in English, clearly and concisely:

```bash
git add .
git commit -m "Add example for data validation Docker STF"
```

Commit message guidelines:

- Use present tense ("Add" not "Added")
- Be concise (ideally under 50 characters)
- Add body for details if needed

Example:

```
Add data validation example to AI prompts

- Add prompt for creating validation Docker STF
- Include input/output schemas
- Add error handling examples
```

### 5. Push

```bash
git push origin feature/your-feature-name
```

### 6. Create a Pull Request

1. Open your forked repository on GitHub
2. Click "Compare & pull request"
3. Describe your changes:

```markdown
## Summary

[Summary of changes]

## Changes

- [ ] Add/update documentation
- [ ] Add code examples
- [ ] Fix bugs
- [ ] Other

## Details

[Detailed description]

## Testing

[Testing method or verified content]

## Related Issue

Closes #XXX
```

---

## Creating Skill Documents

Guidelines for creating new Agent Skills.

### File Structure

```
skill-name.md          # Main skill document
examples/              # Sample code (optional)
  skill-name-example/
    main.py
    Dockerfile
    README.md
```

### Skill Document Template

````markdown
# [Skill Name]

## Overview

[Brief description of what this skill teaches and achieves]

## When to Use This Skill

Scenarios for using this skill:

- "User says X..."
- "When user needs to..."
- "For tasks involving..."

## Core Concepts

### Concept 1

[Explanation of important concepts]

### Concept 2

[Explanation of important concepts]

## How to [Main Task]

### Step 1: [Task Name]

[Specific steps]

```language
[Code example]
```
````

### Step 2: [Task Name]

[Specific steps]

## Best Practices

### 1. [Practice Name]

[Description]

### 2. [Practice Name]

[Description]

## Common Patterns

### Pattern 1: [Pattern Name]

[Pattern description]

```language
[Code example]
```

## Troubleshooting

### Issue: [Issue Name]

**Cause:** [Cause]

**Solution:** [Solution]

## Examples

### Example 1: [Example Name]

[Example description]

```language
[Complete code example]
```

## Reference

### [Reference Section]

[Technical specifications, APIs, schemas, etc.]

## Related Documentation

- [Related Doc 1]
- [Related Doc 2]

````

### Skill Document Checklist

- [ ] Has clear overview
- [ ] States when to use it
- [ ] Has step-by-step instructions
- [ ] Has working code examples
- [ ] Includes best practices
- [ ] Has troubleshooting section
- [ ] Links to related documentation

---

## Code Style

### Markdown

- Use heading levels appropriately
- Specify language for code blocks
- Use consistent list formatting
- Use relative paths for links (when possible)

Example:
```markdown
## Heading 2

### Heading 3

- List item 1
- List item 2

```python
# Code example
print("Hello")
````

[Relative link](./QUICKSTART.md)

````

### Code Examples

- **Working code**: All code examples must actually work
- **Comments**: Add comments to important parts of code
- **Error handling**: Include appropriate error handling
- **Logging**: Include appropriate logging

Example:
```python
"""
Simple echo Docker STF for D6E

This STF demonstrates the basic structure and requirements
for a D6E Docker STF.
"""

import sys
import json
import logging

# Configure logging to stderr
logging.basicConfig(stream=sys.stderr, level=logging.INFO)

def main():
    """Main entry point"""
    try:
        # Read input from stdin
        input_data = json.load(sys.stdin)

        # Extract required fields
        user_input = input_data.get("input", {})

        # Process
        result = {
            "status": "success",
            "message": user_input.get("message", "")
        }

        # Output to stdout
        print(json.dumps({"output": result}))

    except Exception as e:
        logging.error(f"Error: {str(e)}", exc_info=True)
        print(json.dumps({
            "error": str(e),
            "type": type(e).__name__
        }))
        sys.exit(1)

if __name__ == "__main__":
    main()
````

---

## Review Process

### Review Criteria

Pull Requests are reviewed based on:

1. **Accuracy**: Information is accurate and up-to-date
2. **Clarity**: Explanations are easy to understand
3. **Completeness**: All necessary information is included
4. **Consistency**: Consistent with existing documentation
5. **Usefulness**: Actually helpful content

### After Review

- Respond to feedback
- Ask questions without hesitation
- Commit and push changes
- Continue discussion as needed

### Merging

- When review is approved, it will be merged
- Branch will be deleted after merge
- You will be added to the contributors list (if desired)

---

## Questions and Support

### How to Ask Questions

- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: General questions and discussions
- **Pull Requests**: Questions about specific changes

### If You Need Support

- Check documentation: [README.md](./README.md), [Quick Start](./QUICKSTART.md)
- Search Issues: Check if the same problem has been reported
- Create new Issue: For new problems

---

## License

Contributed code will be published under the same license as this project (MIT License).

---

## Acknowledgements

Thank you to all contributors!

Your contributions help the entire D6E community.

---

**Happy Contributing! 🎉**

If you have any questions, feel free to create an [Issue](https://github.com/d6e-ai/d6e-docker-stf-skills/issues)!
