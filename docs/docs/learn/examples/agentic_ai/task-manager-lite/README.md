# Task Manager Lite

A lightweight AI-powered task management system that intelligently routes user requests to specialized handlers for task management, email writing, and general conversation.

## Features

### Intelligent Routing

- Automatically determines the best handler for your request
- Routes to specialized nodes: TaskHandling, EmailHandling, or GeneralChat
- Uses AI-powered classification for accurate routing

### Task Management

- **Add Tasks**: Create tasks with dates and times
- **Task Summarization**: Get summaries of all scheduled tasks
- **Smart Extraction**: Automatically extracts task details from natural language

### Email Writing

- Generate professional emails for various purposes
- Context-aware email content creation
- Support for different email types (meetings, follow-ups, etc.)

### General Chat

- Ask questions and get intelligent responses
- Get advice on productivity and time management
- General AI assistance for various topics

## Architecture

### Nodes

- **TaskHandling**: Manages task creation, scheduling, and summarization
- **EmailHandling**: Handles email content generation
- **GeneralChat**: Provides general AI conversation capabilities

### Walker

- **task_manager**: Main walker that routes requests and coordinates responses

## Usage

1. Start the Jac Cloud server:

   ```bash
   jac start task_manager.jac
   ```

2. Run the frontend:

   ```bash
   jac streamlit frontend.jac
   ```

## Example Requests

### Task Management

- "Add a task to buy groceries tomorrow at 3 PM"
- "Schedule a meeting with the team for Friday at 10 AM"
- "Summarize all my tasks"

### Email Writing

- "Write an email to schedule a meeting with my team"
- "Create a follow-up email for the project update"
- "Write a professional email to request a deadline extension"

### General Chat

- "What are the best practices for time management?"
- "How can I be more productive at work?"
- "What was the most popular programming language in 2020?"

## Frontend Features

### ️ Web Interface

- Clean, intuitive Streamlit-based UI
- Example request buttons for quick access
- Real-time processing with loading indicators

### Activity History

- View recent requests and responses
- Color-coded node type indicators
- Copy functionality for responses

### Visual Feedback

- **Blue**: Task Management operations
- **Green**: Email Writing operations
- **Orange**: General Chat operations

## Requirements

- Python 3.8+
- JAC (Jaseci Action Circuit)
- Streamlit (for frontend)
- OpenAI API key (for GPT-4)

## Configuration

The system uses GPT-4 by default. You can modify the model in `task_manager.jac`:

```jac
glob llm = Model(model_name="gpt-4o");
```

## File Structure

```
task-manager-lite/
├── task_manager.jac    # Main application logic
├── frontend.jac        # Streamlit web interface
└── README.md          # This file
```

## Getting Started

1. **Install Dependencies**:

   ```bash
   pip install jaclang jac-streamlit
   ```

2. **Set OpenAI API Key**:

   ```bash
   export OPENAI_API_KEY="your-api-key-here"
   ```

3. **Run the Application**:

   ```bash
   jac start task_manager.jac
   jac streamlit frontend.jac
   ```

## Technical Details

### AI Methods Used

- **ReAct**: Reasoning and Acting for tool-based interactions
- **Classification**: For intelligent request routing
- **Tool Integration**: Seamless function calling capabilities

### Data Flow

1. User input received by `task_manager` walker
2. AI routing determines appropriate node
3. Specialized node processes request using relevant tools
4. Response generated and returned to user
5. Results reported to frontend (if used)

## Contributing

Feel free to extend the system by:

- Adding new node types for specialized tasks
- Implementing additional tools and capabilities
- Enhancing the frontend interface
- Adding data persistence features

## License

This project is part of the Jaseci ecosystem and follows the same licensing terms.
