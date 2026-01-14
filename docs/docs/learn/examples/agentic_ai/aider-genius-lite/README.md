# Genius Lite - AI Coding Assistant

A simple Jac-based Streamlit application for AI-powered code generation with task planning and validation.

## Features

- Simple, clean interface for code generation requests
- Pre-built example requests for quick testing
- Real-time task progress and results display
- Easy code viewing with syntax highlighting
- AI feedback and validation results
- Separate Jac Streamlit frontend and backend

## Files

- `genius_lite.jac` - Backend with AI logic, task processing, and API endpoints
- `frontend.jac` - Streamlit frontend interface

## Setup

1. **Install dependencies:**

   ```bash
   pip install streamlit requests
   ```

2. **Start the backend server:**

   ```bash
   # Navigate to the jac-byllm directory
   cd /home/udith/jaseci/jac-byllm

   # Start the backend API server
   jac start genius_lite.jac
   ```

3. **Run the frontend:**

   ```bash
   # In a new terminal, navigate to the genius lite directory
   cd /home/udith/jaseci/jac-byllm/examples/agentic_ai/aider-genius-lite

   # Start the Jac Streamlit frontend
   jac streamlit frontend.jac
   ```

4. **Open your browser** to `http://localhost:8501`

## Usage

1. Enter your coding request in the text area (or use one of the example buttons)
2. Click "Generate Code"
3. Wait for the AI to process your request and generate code
4. View the results, including generated code and AI feedback
5. Use the generated code in your projects

## Example Requests

- "Create a Python calculator with basic math operations"
- "Make a simple number guessing game in Python"

## Architecture

- **Backend**: `genius_lite.jac` with AI logic and walker endpoints
- **Frontend**: `frontend.jac` with Jac Streamlit interface
- **AI Engine**: GPT-4o-mini for task planning, code generation, and validation
- **Task Processing**: Structured workflow with task nodes and result collection
- **Communication**: REST API calls with JWT authentication

The application uses Jac's built-in Streamlit integration to provide a seamless web interface for the AI coding assistant.
