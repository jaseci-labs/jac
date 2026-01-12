# Friendzone Lite

An AI-powered memory capture and organization system that helps you extract, refine, and structure memories from images through intelligent conversation.

## Features

### ️ Image-Based Memory Extraction

- Upload images via URL to start memory capture sessions
- AI analyzes visual content to understand the context
- Extracts initial memory details from image content

### Interactive Memory Refinement

- Conversational interface to gather missing details
- AI asks targeted follow-up questions
- Progressive refinement of memory information

### Structured Memory Organization

- **When**: Date information (YYYY-MM-DD format)
- **Who**: People involved in the memory
- **Where**: Locations relevant to the memory
- **What**: Description of what the memory is about

### Completion Tracking

- Real-time progress indication
- Summary generation when details are complete
- Clear completion status with final memory summary

## Architecture

### Core Components

- **Memory Processing Function**: `update_memory_details()` - AI-powered memory extraction and refinement
- **Session Node**: Maintains persistent memory state across interactions
- **Update Walker**: Handles user interactions and memory updates

### Data Structure

```jac
obj Response {
    has follow_up_questions: str;    # Next question to ask
    has summary: str;                # Concise memory summary
    has when: str;                   # Date in YYYY-MM-DD format
    has who: List[str];              # Names of people involved
    has what: str;                   # What the memory is about
    has where: List[str];            # Relevant locations
    has terminate_conversation: bool; # Completion flag
    has show_summary: bool;          # Display summary flag
}
```

## Usage

1. Start the Jac Cloud server:

   ```bash
   jac start friendzone_lite.jac
   ```

2. Run the frontend:

   ```bash
   jac streamlit frontend.jac
   ```

## Frontend Features

### ️ Web Interface

- Clean Streamlit-based UI
- Image URL input with validation
- Real-time conversation interface

### Memory Progress Tracking

- Visual display of memory details (When, Who, Where, What)
- Progress indicators for memory completion
- Structured information layout

### Interactive Chat

- Chat-style conversation interface
- Message history display
- User-friendly input controls

### Session Management

- Start new memory sessions
- Reset current session
- Persistent conversation history

## Example Workflow

1. **Start Session**: Enter an image URL containing a memory
2. **Initial Analysis**: AI analyzes the image and provides initial details
3. **Conversation**: AI asks follow-up questions to fill missing information
4. **Refinement**: Provide additional details through natural conversation
5. **Completion**: Receive final structured memory summary

## Sample Interactions

### Initial Input

```
Image URL: https://example.com/vacation-beach.jpg
```

### AI Follow-up Questions

- "When was this photo taken? Can you provide the date?"
- "Who else was with you during this trip?"
- "What specific location or beach is this?"
- "What were you doing or celebrating?"

### Final Output

```
 Final Memory Summary:
When: 2024-07-15
Who: [John, Sarah, Mike]
Where: [Santa Monica Beach, California]
What: Summer vacation beach trip with college friends
Summary: A memorable summer vacation at Santa Monica Beach with college friends John, Sarah, and Mike on July 15, 2024, enjoying beach activities and celebrating our graduation.
```

## Requirements

- Python 3.8+
- JAC (Jaseci Action Circuit)
- Streamlit (for frontend)
- OpenAI API key (for GPT-4.1)

## Configuration

The system uses GPT-4.1 by default for enhanced image understanding:

```jac
glob llm = Model(model_name="gpt-4.1");
```

## File Structure

```
friendzone-lite/
├── friendzone_lite.jac # Main application logic
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

   jac start friendzone_lite.jac
   jac streamlit frontend.jac
   ```

## Technical Details

### AI Capabilities

- **Image Analysis**: Vision-language model for image understanding
- **Semantic Annotations**: Structured data extraction with semantic meaning
- **Conversational AI**: Natural language interaction for memory refinement
- **Memory Organization**: Intelligent categorization and summarization

### Memory Fields

- **follow_up_questions**: Contextual questions to gather missing information
- **summary**: Comprehensive memory description
- **when**: Temporal information extraction
- **who**: Person identification and recognition
- **where**: Location and place identification
- **what**: Activity and event description
- **terminate_conversation**: Completion detection
- **show_summary**: Display control for memory summary

### Session Management

- Persistent session state across interactions
- Conversation history tracking
- Image URL persistence
- Progress state management

## Use Cases

- **Personal Memory Archiving**: Organize photos with detailed context
- **Event Documentation**: Capture important moments with structured data
- **Family History**: Build detailed records of family gatherings and events
- **Travel Journaling**: Document trips with precise details and context
- **Social Memory**: Keep track of social events and gatherings

## Contributing

Enhance the system by:

- Adding support for local image uploads
- Implementing memory search and retrieval
- Adding export functionality for memory data
- Creating memory visualization features
- Integrating with cloud storage services

## License

This project is part of the Jaseci ecosystem and follows the same licensing terms.
