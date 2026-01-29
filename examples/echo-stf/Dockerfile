FROM python:3.11-slim

WORKDIR /app

# Copy the main script
COPY main.py .

# Make script executable
RUN chmod +x main.py

# Run the script
ENTRYPOINT ["python3", "main.py"]
