# Jaseci Agentic Framework

## Overview
The **Jaseci Agentic Framework** is a modular, scalable, and graph-native ecosystem for building, orchestrating, deploying, and sharing intelligent agents using the Jaseci platform. Inspired by **LangGraph, Autogen, and Semantic Kernel**, this framework provides a unified set of tools and libraries to empower both developers and non-technical users to compose, deploy, and manage intelligent agent workflows.

---

## Architecture Overview
The framework is composed of **four main subsystems**:

1. **Agentic Core (Backend SDK)**
2. **Agentic Client (Consumer SDK)**
3. **Agent Studio (Visual Builder)**
4. **Agentic Marketplace(Currently JPR in JIVAS)**

---

## 1. Agentic Core

### Responsibilities
- Define and register agents, walkers, tools, and graphs.
- Host and orchestrate graph-based agent workflows.
- Enable deterministic agent execution.

### Core Concepts
- **Agent** = Walker + logic + memory + endpoint.
- **Graph Node** = Modular computation/decision/action unit.
- **Action** = Externally defined walkers with functionalities.
- **Toolbox** = Group of reusable tools/actions.

### Enhancements
- Decorator-based registration.
- Auto-generated OpenAPI for hosted agents.
- Guardrails, timeout, fallback logic at graph node level.

---

## 2. Agentic Client

### Responsibilities
- Interface for apps and users to interact with hosted agents.
- Supports async, retries, tracing, and caching.

### Features
- Dynamic agent discovery.
- Typing + introspection (`client.get_agent("planner").call("plan", ...)`).
- Embedded context, memory state, and authentication.

---

## 3. Agent Studio (Visual Builder)

### Responsibilities
- Low-code/no-code interface for building and editing agents.
- Graph composition with drag-and-drop.
- Agent simulation, debugging, visualization.

### Features
- Template library (chatbot, planner, summarizer, etc.).
- Live visual tracing and memory preview.
- Import/export `.jpr` packages.

---

## 4. Agentic Registry

### Responsibilities
- Centralized package hub for agents and tools.
- Public/private packages with semantic versioning.

### Package Format (`jpr`)
```toml
name = "calendar_assistant"
version = "1.2.0"
author = "jane_doe"
dependencies = ["date_parser", "google_calendar_tool"]
main = "main.jac"
```

### CLI Tools
- `jpr install <name>`
- `jpr publish`
- `jpr update`

---

## Execution Flow
```
[User Input]
   ↓
[Client SDK] → (calls)
   ↓
[Hosted Agent (via Runner)]
   ↙        ↓       ↘
[Toolbox] [Memory] [Decision Walker]
   ↓         ↓          ↓
[GraphNode] — → [Action] → [Output]
```

---

## Competitive Advantages
| Compared To     | Jaseci Offers...                                      |
|------------------|-------------------------------------------------------|
| LangGraph        | Graph-native execution + deterministic agent control |
| Autogen          | Real agent memory/state + modular walker logic       |
| Semantic Kernel  | Graph orchestration beyond linear pipelines          |
| CrewAI           | Production-ready graph + tool modularity             |
| HF Hub           | Agent/tool sharing hub, not just model sharing       |

---

## Conclusion
This framework is designed to be **the most elegant, extensible, and powerful agent platform**, blending the graph-native benefits of Jaseci with modular orchestration and accessible tooling for all user levels.

---
