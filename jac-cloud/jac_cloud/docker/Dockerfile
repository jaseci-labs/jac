# Common Dockerfile for all FastAPI apps

FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Copy requirements dynamically later
COPY requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code (main.py and others)
COPY . .

# Run FastAPI app
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
