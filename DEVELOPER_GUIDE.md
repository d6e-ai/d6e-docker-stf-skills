# Creating D6E Docker STFs with Claude/Cursor

A guide for developers using Claude or Cursor to create custom Docker STFs for D6E.

## 🎯 What You'll Learn

- How to use D6E Agent Skills with Claude/Cursor
- Examples of requesting custom D6E Docker STFs
- What to expect from AI-generated code
- How to test and deploy your Docker STFs

## 🚀 Quick Start

### Prerequisites

1. **Claude or Cursor** with access to this repository
2. **D6E instance** running (local or remote)
3. **Docker** installed for building/testing
4. **GitHub account** for publishing (optional)

### Step 1: Open Agent Skills in Claude/Cursor

```bash
# Clone the repository
git clone https://github.com/d6e-ai/agent-skills.git
cd agent-skills

# Open in Cursor or load in Claude Code
cursor .  # or your preferred method
```

### Step 2: Request a Docker STF

Simply ask Claude/Cursor in natural language. The AI will read the Agent Skills document and generate appropriate code.

## 📝 Example Requests

### Example 1: Data Validation Docker STF

**Your Request:**
```
Using the D6E Docker STF Development skill, create a data validation Docker STF that:
1. Accepts an array of records
2. Validates each record against predefined rules
3. Returns validation results with error details
```

**What You'll Get:**
- Complete Python/Node.js/Go implementation
- Input validation logic
- Error handling
- Dockerfile
- requirements.txt/package.json/go.mod
- Testing instructions
- Deployment guide

**Generated Files:**
```
data-validator/
├── main.py                 # or index.js / main.go
├── Dockerfile
├── requirements.txt        # or package.json / go.mod
└── README.md
```

### Example 2: External API Integration

**Your Request:**
```
Create a D6E Docker STF that fetches weather data from OpenWeatherMap API 
and stores it in the database. Include error handling for API failures.
```

**What You'll Get:**
```python
# main.py
import requests
import json
import sys
import logging

def process(user_input, sources, context):
    api_key = user_input.get("api_key")
    city = user_input.get("city")
    
    # Fetch weather data
    url = f"https://api.openweathermap.org/data/2.5/weather"
    response = requests.get(url, params={"q": city, "appid": api_key}, timeout=10)
    response.raise_for_status()
    weather = response.json()
    
    # Store in database
    sql = f"""
        INSERT INTO weather_data (city, temperature, description, fetched_at)
        VALUES ('{city}', {weather['main']['temp']}, '{weather['weather'][0]['description']}', NOW())
        RETURNING *
    """
    result = execute_sql(context["api_url"], context["api_token"], 
                        context["workspace_id"], context["stf_id"], sql)
    
    return {
        "status": "success",
        "city": city,
        "temperature": weather['main']['temp'],
        "stored_id": result["rows"][0]["id"]
    }
```

### Example 3: Data Transformation Pipeline

**Your Request:**
```
Build a D6E Docker STF that:
1. Reads data from a source table
2. Transforms column names (snake_case to camelCase)
3. Filters out null values
4. Writes to a destination table
Use the sources parameter to get table names from previous steps.
```

**What You'll Get:**
Complete implementation with:
- Reading from sources
- Data transformation logic
- Filtering
- Batch insertion
- Transaction handling

## 🎨 Request Patterns

### Pattern 1: Simple Processing

```
Create a D6E Docker STF that [does something simple]
```

Example:
```
Create a D6E Docker STF that converts timestamps to different timezones
```

### Pattern 2: Database Operations

```
Create a D6E Docker STF that [reads/writes data] with [specific conditions]
```

Example:
```
Create a D6E Docker STF that archives old records by moving them from 
the main table to an archive table if they're older than 90 days
```

### Pattern 3: External Integration

```
Create a D6E Docker STF that integrates with [external service] to [do something]
```

Example:
```
Create a D6E Docker STF that integrates with SendGrid to send email
notifications when certain conditions are met in the database
```

### Pattern 4: Complex Workflow

```
Create a D6E Docker STF that:
1. [Step 1]
2. [Step 2]
3. [Step 3]
Include [specific requirements]
```

Example:
```
Create a D6E Docker STF that:
1. Fetches user activity from the events table
2. Calculates engagement scores
3. Updates the users table with new scores
4. Sends a webhook to Slack for high-scoring users
Include proper error handling and logging
```

## ✅ What to Check

After Claude/Cursor generates your Docker STF:

### 1. Input/Output Format

Verify the JSON structure matches your needs:
```python
# Input
{
  "operation": "your_operation",
  "param1": "value1",
  ...
}

# Output
{
  "status": "success",
  "result": {...}
}
```

### 2. SQL Queries

Check for:
- Proper escaping of user input
- No DDL statements (CREATE/DROP/ALTER)
- Correct table names

### 3. Error Handling

Ensure errors are caught and reported:
```python
try:
    result = execute_sql(...)
except Exception as e:
    logging.error(f"SQL failed: {str(e)}")
    return {"error": "Database operation failed", "details": str(e)}
```

### 4. Logging

Verify logs go to stderr:
```python
logging.basicConfig(stream=sys.stderr, level=logging.INFO)
```

## 🧪 Testing Your Docker STF

### Local Test

```bash
# Build
docker build -t my-skill:test .

# Test with sample input
echo '{"workspace_id":"test","stf_id":"test","caller":null,"api_url":"http://localhost:8080","api_token":"token","input":{"operation":"test","data":"sample"},"sources":{}}' | \
docker run --rm -i my-skill:test
```

### Integration Test with D6E

1. **Publish to registry:**
```bash
docker tag my-skill:test ghcr.io/username/my-skill:latest
docker push ghcr.io/username/my-skill:latest
```

2. **Register in D6E:**
Use D6E's MCP tools or API to create STF and workflow

3. **Execute:**
Run the workflow and verify results

## 🚀 Deployment

### Option 1: GitHub Container Registry

```bash
# Login
docker login ghcr.io -u your-username

# Tag and push
docker tag my-skill:latest ghcr.io/your-username/my-skill:latest
docker push ghcr.io/your-username/my-skill:latest

# Make public on GitHub
```

### Option 2: Docker Hub

```bash
# Login
docker login

# Tag and push
docker tag my-skill:latest your-username/my-skill:latest
docker push your-username/my-skill:latest
```

### Option 3: Private Registry

```bash
# Login to your registry
docker login registry.example.com

# Tag and push
docker tag my-skill:latest registry.example.com/my-skill:latest
docker push registry.example.com/my-skill:latest
```

## 💡 Tips & Tricks

### Tip 1: Iterative Development

Ask Claude/Cursor to refine the skill:
```
Add retry logic with exponential backoff to the API calls
```
```
Optimize the SQL queries for better performance
```
```
Add input validation for email addresses
```

### Tip 2: Language Selection

Specify your preferred language:
```
Create a D6E Docker STF in Go that...
```
```
Create a D6E Docker STF using Node.js with TypeScript that...
```

### Tip 3: Include Context

Provide context for better results:
```
Create a D6E Docker STF for an e-commerce platform that 
calculates shipping costs based on weight, destination,
and carrier. We use USPS, FedEx, and UPS.
```

### Tip 4: Request Examples

Ask for usage examples:
```
Also provide example input JSON for testing
```

### Tip 5: Multi-Operation Docker STFs

Create Docker STFs with multiple operations:
```
Create a D6E Docker STF with three operations:
1. 'validate' - validates data format
2. 'transform' - transforms data structure  
3. 'enrich' - adds external data
```

## 🐛 Troubleshooting

### Issue: Generated code doesn't match my needs

**Solution:** Be more specific in your request
```
❌ Create a data processing Docker STF
✅ Create a Docker STF that validates email addresses using regex,
   checks domain MX records, and returns validation status
```

### Issue: SQL queries look unsafe

**Solution:** Ask for improvements
```
Review the SQL queries for injection vulnerabilities and add
proper escaping
```

### Issue: Missing error handling

**Solution:** Request explicitly
```
Add comprehensive error handling with specific error messages
for different failure scenarios
```

### Issue: No logging

**Solution:** Ask for it
```
Add detailed logging to stderr for debugging
```

## 📚 Advanced Topics

### Custom Base Images

```
Create a D6E Docker STF using a custom base image with 
TensorFlow for ML inference
```

### Multi-Stage Builds

```
Create a D6E Docker STF with a multi-stage Dockerfile to 
minimize image size
```

### Environment Variables

```
Create a D6E Docker STF that uses environment variables for
configuration (API keys, endpoints, etc.)
```

### Batch Processing

```
Create a D6E Docker STF that processes data in batches of 
100 records to handle large datasets efficiently
```

## 🎓 Learning Path

1. **Start Simple:** Create a basic echo Docker STF
2. **Add Database:** Create a Docker STF that queries data
3. **Add Logic:** Create a Docker STF with business logic
4. **External API:** Integrate with external services
5. **Complex Workflow:** Multi-step processing

## 📖 Additional Resources

- [D6E Agent Skills Repository](https://github.com/d6e-ai/agent-skills)
- [D6E Documentation](https://github.com/d6e-ai/d6e)
- [Claude Agent Skills Guide](https://docs.claude.com/en/docs/agents-and-tools/agent-skills/overview)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)

---

**Happy Docker STF Building! 🎉**

Have questions? Open an issue on the [Agent Skills repository](https://github.com/d6e-ai/agent-skills/issues).
