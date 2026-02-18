# Frequently Asked Questions

Common questions and answers. If you don't see your question below and couldn't find a solution in the docs, ask your question in our [Discord Community](https://discord.gg/6j3QNdtcN6) (We try to answer within 2hrs.)

---

??? "Getting Started & Setup"

    ??? question "I updated to the latest Jaseci PyPI packages and my project won't `jac start` properly."
        Run `jac purge` to clear the global bytecode cache. This is the recommended approach after upgrading packages:
        ```bash
        jac purge
        ```

        This command works even when the cache is corrupted. If `jac purge` is not available (older versions), manually clear the cache:
        ```
        Linux:   rm -rf ~/.cache/jac/bytecode/
        macOS:   rm -rf ~/Library/Caches/jac/bytecode/
        Windows: rmdir /s /q %LOCALAPPDATA%\jac\cache\bytecode
        ```

    ??? question "What do I need to install to get started with Jac?"
        See the [Installation Guide](https://docs.jaseci.org/quick-guide/install/)

    ??? question "What are good first projects to build with Jac?"
        Check out the [To-Do App Tutorial](https://docs.jaseci.org/tutorials/first-app/part1-todo-app/)

??? "Language & Concepts"

    ??? question "What's the difference between Jac, Jaclang, and Jaseci?"
        - Jac: The language
        - Jaclang: The compiler/runtime
        - Jaseci: The full framework and ecosystem including plugins (byllm, jac-client, jac-scale, etc.)

    ??? question "Do I need to know graph theory to use Jaseci?"
        No. Learn OSP: [OSP Guide](https://docs.jaseci.org/tutorials/language/osp/)

    ??? question "Can I use Python libraries (PyPI) in Jac?"
        Yes. Jac integrates seamlessly with Python libraries.

    ??? question "What's the learning curve coming from Python? How is Jac different from just using Python?"
        Jac supersets Python. It adds graph-based architecture and AI-native features.[Learn Jac Basics - from Python](https://docs.jaseci.org/tutorials/language/basics/)

    ??? question "Can ____ be done in Jac? Is ____ compatible with Jac?"
        **Yes**, if the answer to any of these questions is yes:

        - Can it be done in Python with any PyPI package?
        - Can it be done in TypeScript/JavaScript with any Node.js package?
        - Can it be done in C with any C-compatible library?

        Jac compiles to Python (server), JavaScript (client), and native binaries (C ABI), so any library or tool compatible with those ecosystems is compatible with Jac.

        **If you find something that works in Python/Node.js/C but doesn't work in Jac, that's a bug!** Please [file an issue](https://github.com/Jaseci-Labs/jaseci/issues) or let us know in the [Discord](https://discord.gg/6j3QNdtcN6).

??? "AI & LLM Integration"

    ??? question "How does byLLM differ from calling OpenAI/Anthropic directly?"
        - Standardized interface across AI providers
        - Integrated model management in Jac
        - Simplified prompt engineering
        See [API key setup](https://docs.jaseci.org/tutorials/first-app/part2-ai-features/#set-up-your-api-key)

    ??? question "How do I structure by llm() functions so that the output is deterministic and parseable?"
        Use structured prompts and response templates.[AI Integration Reference](https://docs.jaseci.org/reference/language/ai-integration/)

??? "Production & Deployment"

    ??? question "How do I deploy a Jac app to production?"
        - [Local Deployment](https://docs.jaseci.org/tutorials/production/local/): `jac start` creates an HTTP API server.
        - [Kubernetes Deployment](https://docs.jaseci.org/tutorials/production/kubernetes/): Deploy with a single command.

    ??? question "Do I need Docker/Kubernetes knowledge to use jac-scale?"
        No. jac-scale handles containerization and orchestration automatically.

    ??? question "What does jac-scale do automatically?"
        - Containerizes Jac application
        - Sets up Kubernetes deployment
        - Manages scaling and load balancing
        [Kubernetes Deployment Reference](https://docs.jaseci.org/reference/language/deployment/#kubernetes-deployment)

??? "Debugging & Support"

    ??? question "Where's the best place to get help?"
        Join the [Jaseci Discord Community](https://discord.gg/6j3QNdtcN6) and use the #get-help channel

    ??? question "What debugging tools are available for Jac?"
        - VS Code debugger support: [Debugging Guide](https://docs.jaseci.org/tutorials/language/debugging/)
        - Writing and running tests: [Testing Reference](https://docs.jaseci.org/reference/testing/)

    ??? question "How do I debug graph state visually and trace execution flow?"
        Use the graph visualization tool in the debugger: [Graph Visualization](https://docs.jaseci.org/tutorials/language/debugging/#graph-visualization)

    ??? question "How do I test Jac walkers and nodes?"
        [Testing Guide for Nodes and Walkers](https://docs.jaseci.org/tutorials/language/testing/#testing-nodes-and-walkers)

??? "Project Structure & Best Practices"

    ??? question "Can I build a complete app in one .jac file?"
        Technically yes, but not recommended. Use modular structure for scalability:
        - [File System Organization](https://docs.jaseci.org/jac-client/file-system/intro/)
        - [Frontend/Backend Separation](https://docs.jaseci.org/jac-client/file-system/backend-frontend/)

    ??? question "Can I use Jac with React/frontend frameworks?"
        Yes. Jac supports:
        - [React component style](https://docs.jaseci.org/tutorials/fullstack/components/)
        - [Import npm packages](https://docs.jaseci.org/jac-client/imports/#working-with-third-party-node-modules)

    ??? question "How do I structure multi-agent AI systems in Jac?"
        - [Use project template](https://docs.jaseci.org/reference/cli/#jac-create)
        `jac create <project_name> --use <template_name>`
        - Organize files by purpose:
          - .jac: Core logic
          - .cl.jac: Client-side code
          - .impl.jac: Implementation details

    ??? question "How do I handle authentication and authorization in Jac walkers?"
        Use built-in authentication functions: [Authentication Functions](https://docs.jaseci.org/jac-client/imports/#jaclogin-user-login)

??? "Community & Contributing"

    ??? question "How active is the Jaseci community?"
        Very active! Join the [Jaseci Discord Community](https://discord.gg/6j3QNdtcN6) for support and discussions with fellow contributors.

    ??? question "How often is Jac updated?"
        Check the [GitHub Releases](https://docs.jaseci.org/community/release_notes/jaclang/) for the latest updates and versions.
    ??? question "How do I contribute to Jaseci?"
        - [Discord contributors channel](https://discord.gg/6j3QNdtcN6)
        - Read the [Contributing Guide](https://docs.jaseci.org/community/contributing/)
