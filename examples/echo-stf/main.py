#!/usr/bin/env python3
"""
Simple Echo Docker STF for D6E

This is a minimal example of a D6E Docker STF that demonstrates:
- Reading JSON input from stdin
- Processing user input
- Outputting JSON to stdout
- Error handling
- Logging to stderr
- Self-describing input schema via the describe operation

Operations:
- echo: Returns the input message as-is
- uppercase: Converts message to uppercase
- lowercase: Converts message to lowercase
- describe: Returns the input schema and available operations
"""

import sys
import json
import logging

# Configure logging to stderr (stdout is reserved for JSON output)
logging.basicConfig(
    stream=sys.stderr,
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

def process_echo(message):
    """Echo operation - returns message as-is"""
    logging.info(f"Echo operation: {message}")
    return {
        "status": "success",
        "operation": "echo",
        "message": message
    }

def process_uppercase(message):
    """Uppercase operation - converts message to uppercase"""
    logging.info(f"Uppercase operation: {message}")
    return {
        "status": "success",
        "operation": "uppercase",
        "message": message.upper()
    }

def process_lowercase(message):
    """Lowercase operation - converts message to lowercase"""
    logging.info(f"Lowercase operation: {message}")
    return {
        "status": "success",
        "operation": "lowercase",
        "message": message.lower()
    }

def process_describe():
    """Describe operation - returns the input schema and available operations"""
    logging.info("Describe operation")
    return {
        "status": "success",
        "operation": "describe",
        "data": {
            "input_schema": {
                "type": "object",
                "properties": {
                    "operation": {
                        "type": "string",
                        "enum": ["echo", "uppercase", "lowercase", "describe"],
                        "description": "The operation to perform"
                    },
                    "message": {
                        "type": "string",
                        "description": "The message to process"
                    }
                },
                "required": ["operation"]
            },
            "operations": {
                "echo": {
                    "description": "Returns the input message as-is",
                    "required": ["message"],
                    "optional": []
                },
                "uppercase": {
                    "description": "Converts message to uppercase",
                    "required": ["message"],
                    "optional": []
                },
                "lowercase": {
                    "description": "Converts message to lowercase",
                    "required": ["message"],
                    "optional": []
                },
                "describe": {
                    "description": "Returns the input schema and available operations",
                    "required": [],
                    "optional": []
                }
            }
        }
    }

def main():
    """Main entry point"""
    try:
        # Read input from stdin
        logging.info("Reading input from stdin")
        input_data = json.load(sys.stdin)
        
        # Log received data (excluding sensitive information)
        logging.info(f"Workspace ID: {input_data.get('workspace_id')}")
        logging.info(f"STF ID: {input_data.get('stf_id')}")
        logging.info(f"Caller: {input_data.get('caller')}")
        
        # Extract user input
        user_input = input_data.get("input", {})
        operation = user_input.get("operation", "echo")
        
        # Handle describe operation first (no message required)
        if operation == "describe":
            result = process_describe()
        else:
            # Validate message for other operations
            message = user_input.get("message", "")
            if not message:
                raise ValueError("Message is required")
            
            # Process based on operation
            if operation == "echo":
                result = process_echo(message)
            elif operation == "uppercase":
                result = process_uppercase(message)
            elif operation == "lowercase":
                result = process_lowercase(message)
            else:
                raise ValueError(f"Unknown operation: {operation}")
        
        # Output result to stdout
        output = {"output": result}
        print(json.dumps(output))
        logging.info("Processing completed successfully")
        
    except json.JSONDecodeError as e:
        error_msg = f"Invalid JSON input: {str(e)}"
        logging.error(error_msg)
        print(json.dumps({
            "error": error_msg,
            "type": "JSONDecodeError"
        }))
        sys.exit(1)
        
    except ValueError as e:
        error_msg = str(e)
        logging.error(error_msg)
        print(json.dumps({
            "error": error_msg,
            "type": "ValueError"
        }))
        sys.exit(1)
        
    except Exception as e:
        error_msg = f"Unexpected error: {str(e)}"
        logging.error(error_msg, exc_info=True)
        print(json.dumps({
            "error": error_msg,
            "type": type(e).__name__
        }))
        sys.exit(1)

if __name__ == "__main__":
    main()
