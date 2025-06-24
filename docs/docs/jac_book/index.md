# Jac Programming Language Book

Welcome to the comprehensive guide to the Jac programming language. This book will take you from a complete beginner to an advanced Jac developer, covering everything from basic syntax to building scalable, cloud-native applications.

!!! info "About This Book"
    Jac is a revolutionary programming language that introduces **Object-Spatial Programming (OSP)**, a paradigm that inverts the traditional relationship between data and computation. Instead of moving data to computation, Jac moves computation to data through spatially-aware constructs like nodes, edges, and walkers.

    This book is structured to provide both theoretical understanding and practical experience, with extensive code examples and real-world applications throughout.

---

## Table of Contents

### Part I: Getting Started
*Master the fundamentals and get your development environment ready*

#### Chapter 1: Introduction to Jac
- What is Jac and why it exists
- Object-Spatial Programming paradigm overview
- Scale-agnostic programming concept
- Comparison with Python and traditional languages

!!! example "Code Focus"
    Simple friend network with 3 people connected by friendship edges

#### Chapter 2: Environment Setup and First Program
- Installation and IDE setup
- Project structure conventions
- Hello World in Jac
- Entry blocks and basic execution

!!! example "Code Focus"
    Hello World and basic calculator program

---

### Part II: Core Language Features
*Learn Jac's syntax, type system, and functional programming capabilities*

#### Chapter 3: Variables, Types, and Basic Syntax
- Variable declarations with mandatory typing
- Basic data types and type inference
- Lists, dicts, sets, tuples with type safety
- Collection comprehensions
- Control flow (if/else, loops with curly braces)
- Pattern matching
- Exception Handling
- Walrus Operation

!!! example "Code Focus"
    Simple grade book system with student scores and basic operations

#### Chapter 4: Functions, AI Functions, and Decorators
- Function definitions
- Parameter types and return annotations
- Built-in AI function calls
- Decorators in Jac context
- Lambda functions and functional programming
- Async functions

!!! example "Code Focus"
    Math functions library with timing decorator and AI integration

#### Chapter 5: Advanced AI Operations
- MTLLM variations and basic usage
- Model declaration and configuration
- Semantic strings and prompt engineering
- Multimodality support (vision, audio)

!!! example "Code Focus"
    Simple image captioning tool

#### Chapter 6: Imports System and File Operations
- Import statements and module organization
- Implementation separation (.impl.jac files)
- Package structure and well-typed codebases
- File operations

!!! example "Code Focus"
    Simple config file reader across multiple modules

---

### Part III: Object Spatial Programming (OSP)
*Dive into the revolutionary paradigm that makes Jac unique*

#### Chapter 7: Enhanced OOP - Objects and Classes
- Python `class` to Jac `obj`
- Automatic constructors with `has`
- Access control (`:pub`, `:priv`, `:protect`)
- Inheritance and composition

!!! example "Code Focus"
    Simple pet shop with different animal types

#### Chapter 8: OSP Introduction and Paradigm Shift
- From "data to computation" to "computation to data"
- Data Spatial Programming foundation
- Graph thinking vs object thinking

!!! example "Code Focus"
    Family tree with 3 generations

#### Chapter 9: Nodes and Edges
- Node creation and properties
- Edge types and relationships
- Graph creation syntax
- Filtering

!!! example "Code Focus"
    Simple classroom with students and teacher connections

#### Chapter 10: Walkers and Abilities
- Walker creation
- Ability definitions and triggers
- Entry/exit behaviors
- Walker spawn and visit

!!! example "Code Focus"
    Message delivery walker in the classroom graph

#### Chapter 11: Advanced Object Spatial Operations
- Visit patterns
- Advanced Filtering
- Complex traversal patterns

!!! example "Code Focus"
    Find all friends of friends in a social network

---

### Part IV: Scale-Agnostic Features
*Coming Soon - Learn how Jac automatically scales from single-user to distributed systems*

!!! warning "Under Development"
    The following chapters are currently being written and will be available soon.

#### Chapter 12: Walkers as API Endpoints
- Automatic API generation
- Request/response handling
- Parameter validation
- REST patterns with walkers

!!! example "Planned Code Focus"
    Simple shared notebook with user permissions

#### Chapter 13: Persistence and the Root Node
- Automatic persistence
- Root node concept
- State consistency

!!! example "Planned Code Focus"
    Simple counter that remembers its value between runs

#### Chapter 14: Jac Cloud Introduction
- What is Jac Cloud and benefits
- Quick setup and deployment
- Walker endpoints as APIs
- Local to Cloud

!!! example "Planned Code Focus"
    Simple weather API endpoint

#### Chapter 15: Multi-User Architecture and Permissions
- User isolation and permission systems
- Shared data patterns
- Security considerations
- Access control strategies

!!! example "Planned Code Focus"
    Simple shared notebook with user permissions

---

### Part V: Advanced Scale-Agnostic Features
*Coming Soon - Master advanced distributed programming patterns*

#### Chapter 16: Advanced Jac Cloud Features
- Environment variables and configuration
- Webhook integration
- WebSocket communication
- Logging and monitoring
- Task scheduling and cron jobs

!!! example "Planned Code Focus"
    Simple chat room with WebSocket connections

---

### Part VI: Advanced Topics
*Coming Soon - Deep dive into advanced language features*

#### Chapter 17: Type System Deep Dive
- Advanced generics
- Type constraints
- Graph type checking
- Runtime type validation

!!! example "Planned Code Focus"
    Generic list operations with type safety

#### Chapter 18: Testing and Debugging
- Test block syntax
- Walker behavior testing
- Distributed debugging

!!! example "Planned Code Focus"
    Tests for the classroom graph system

---

### Part VII: Deployment and Production
*Coming Soon - Take your applications to production*

#### Chapter 19: Deployment Strategies
- Local vs cloud deployment
- Kubernetes deployment
- Configuration management
- Monitoring and observability
- CI/CD patterns

!!! example "Planned Code Focus"
    Deploy the weather API to production

#### Chapter 20: Performance Optimization
- Graph structure optimization
- Traversal efficiency
- Memory management
- Distributed performance

!!! example "Planned Code Focus"
    Optimize the friend-finding algorithm

---

### Part VIII: Real-World Applications
*Coming Soon - Build complete applications using Jac*

#### Chapter 21: Complete Application: LittleX Social Platform
- Architecture design using data spatial concepts
- User profile creation and management
- Creating posts and content sharing
- Following users and social connections
- Viewing personalized feeds
- Real-time features with WebSockets

!!! example "Planned Code Focus"
    Full social media platform (based on LittleX tutorial)

#### Chapter 22: Complete Application: RAG Chatbot
- Building intelligent chatbots
- Retrieval-augmented generation patterns
- Knowledge base integration
- Context management

!!! example "Planned Code Focus"
    Simple FAQ chatbot for a school

#### Chapter 23: Complete Application: Workflow Engine
- Business process modeling
- State machine implementation
- Task assignment and tracking
- Integration patterns

!!! example "Planned Code Focus"
    Simple homework assignment workflow

---

### Part IX: Migration and Best Practices
*Coming Soon - Learn how to migrate from Python and follow best practices*

#### Chapter 24: Python to Jac Migration
- Migration strategies
- Incremental adoption
- Python integration patterns
- Common pitfalls

!!! example "Planned Code Focus"
    Convert a simple Python class to Jac objects

#### Chapter 25: Best Practices and Patterns
- Code organization
- Naming conventions
- Documentation standards
- Team collaboration

!!! example "Planned Code Focus"
    Clean code examples and project structure

#### Chapter 26: Big Features and Future of Jac
- Roadmap and evolution
- Upcoming features in development
- Research directions
- Community resources
- Contributing guidelines

!!! example "Planned Code Focus"
    Simple community contribution example

---

## Learning Paths

!!! tip "Choose Your Path"
    **Quick Start (Chapters 1-3, 7-11)**: Get productive with Jac quickly
    **Full Migration**: Complete journey from Python to Jac mastery
    **Specific Use Cases**: Focus on web services, data processing, or distributed systems

## Getting Help

- **[Documentation](https://www.jac-lang.org/)**: Comprehensive guides and API references
- **[Community](https://discord.gg/6j3QNdtcN6https://discord.gg/6j3QNdtcN6)**: Join our Discord for discussions and support
- **[Issues](https://github.com/jaseci-labs/jaseci/issues)**: Report bugs and request features on GitHub

---

*Ready to revolutionize how you think about programming? Let's begin with [Chapter 1: Introduction to Jac](chapter_1.md)!*
