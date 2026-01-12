<h1 style="color: orange; font-weight: bold; text-align: center;">Introduction</h1>

## About Jac and Jaseci

The **Jac programming language** and **Jaseci runtime** build on Python (fully compatible), introducing **AI-first constructs**, **object-spatial programming (OSP)**, and **scale-native capabilities**. These features are designed to hide common development complexity, elevate AI to a first-class citizen, and automate categories of system and DevOps work that traditionally require extensive manual effort. The result is a dramatic reduction in development and deployment overhead, enabling teams to build modern applications faster and with far less complexity.

Although relatively new, Jac is already used in production environments across a range of real-world systems.

<!--The **Jac programming language** and **Jaseci runtime** build on Python, introducing **AI-first constructs**, **object-spatial programming (OSP)**, and **scale-native capabilities**. -->

## Key Features

### 1. Object-Spatial Programming (OSP)

Jac introduces a new programming model that lets developers articulate **relationships between objects** in a **graph-like structure** and express computation as **walkers** that traverse this graph. This model is particularly effective for applications involving **connected data**, such as social networks, knowledge graphs, or file systems, and can greatly reduce code complexity. OSP also provides the foundation for **agentic workflows** and enables **Jaseci’s scale-native execution**, reducing backend development and deployment overhead. [Learn more about OSP](https://docs.jaseci.org/learn/quickstart/).

<figure id="fig-features" style="text-align: center;">
    <img src="../assets/Features.svg" alt="Features illustration" style="width:65%; height:auto;">
    <figcaption><strong>Figure 1:</strong> Overview of Jac's key features and capabilities.</figcaption>
</figure>

---

### 2. Programming Abstractions for AI

Jac is designed from the ground up to integrate AI directly into the programming model to simplify development of AI-powered applications.

- **`by llm`**   - Jac introduces language-level constructs such as the `by()` keyword that automatically generate optimized prompts. This **removes the need for manual prompt engineering** and enables seamless model integration.  In production systems, this feature has reduced hundreds of lines of prompt code to a single line. This feature can be used alone as Python library, or natively in Jac. [Read more about byllm](https://docs.jaseci.org/learn/jac-byllm/with_llm/).

- **Native Agentic AI Workflows (enabled by OSP)** - By leveraging OSP’s graph-based semantics, Jac naturally supports the creation and articulation of **agentic workflows**, allowing developers to create flows of interacting agents that collaborate, share memory, and act on dynamic context.

As shown in shown in <a href="#fig-features">Figure 1</a>, ***together, OSP and `by llm` form a powerful foundation for rapid agentic AI development***.

---

### 3. Scale-Native Execution

Jac allows developers to **write code once and run it anywhere**: from local environments to distributed cloud deployments, without code modification.  Jac also automates the process of **generating APIs** and **managing data persistence**, simplifying FE/BE integration, deployment and scaling of your applications. [Read more about Scale-Native](https://docs.jaseci.org/jac-scale/README/).

---

### 4. Python Super-Set

Jac-lang is intentionally designed as an extension of Python.  It provides **Python-like syntax** while adding new capabilities for **graph-based** and **AI-first programming**.

Developers can freely mix **Jac** and **Python**:

- Import Python libraries and call Python functions from Jac
- Inline Python snippets inside Jac code
- Import Jac modules directly into Python programs

This tight interoperability enables teams to adopt Jac incrementally and integrate it seamlessly with existing Python ecosystems. [Read about how we super-setted Python](https://docs.jaseci.org/learn/superset_python/). [Read about using Jaseci as a Python library](https://docs.jaseci.org/learn/library_mode/)

## Who Jac/Jaseci Is For

Jac/Jaseci is designed for anyone who wants to build applications quickly and cleanly.

- **Startups**
Jac is perfect for rapid prototyping and iteration. One or two engineers can build features that normally require separate frontend, backend, ML, and infrastructure roles. Jac scales from prototype to production with the same code.

- **AI/ML Engineers**
Jac is AI-first: language-level constructs and runtime that use machine learning models seamlessly, reducing prompt engineering and making agent workflows natural. Ideal for building LLM agents, multimodal systems, and graph-based reasoning pipelines.

- **Experienced Developers and Large Teams**
For developers who want modern language features, such as optional type checking, cleaner syntax, structural modeling via OSP, and strong tooling, while keeping full access to Python’s ecosystem.

- **Frontend Engineers who want to expand to full-stack**
A great fit if you want to move into full-stack development without heavy backend or DevOps work. Jac lets developers build backend logic, manage state, integrate AI, and deploy, using a Python-like syntax.

- **Students**
Jac’s high-level abstractions hide much of the typical systems complexity, making it accessible for students while still exposing them to modern concepts like AI integration and scalable application design. It provides an approachable on-ramp to both Python and full-stack AI development.

## When to Use Jac

Jac is particularly well-suited when:

- **Your problem domain is inherently graph-like**, where relationships between objects matter.
- **You want LLMs and other AI models deeply integrated** into your application logic, such as Agentic AI systems where you may need   prompt engineering and aritculating agent workflows.
- **You need to move from prototype to scalable service seamlessly**, without rewriting your system for microservices, orchestration, or extensive dev-ops.
- **You already rely heavily on Python code or libraries** and want a smooth path to something more structured, graph-aware, and AI-centric.
