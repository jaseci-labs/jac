# Plugins Reference

Jac extends its capabilities through a plugin ecosystem. These plugins provide AI integration, full-stack web development, and cloud-native deployment features.

---

## Core Plugins

| Plugin | Description | Install |
|--------|-------------|---------|
| [byLLM](byllm.md) | AI/LLM integration with Meaning-Typed Programming | `pip install byllm` |
| [jac-client](jac-client.md) | Full-stack web development with React-style components | `pip install jac-client` |
| [jac-scale](jac-scale.md) | Cloud-native deployment and scaling | `pip install jac-scale` |

---

## Quick Installation

Install all plugins via the `jaseci` meta-package:

```bash
pip install jaseci
```

This bundles `jaclang` with all official plugins. Or install individually:

```bash
pip install byllm        # AI integration
pip install jac-client   # Frontend development
pip install jac-scale    # Production deployment
```

---

## Plugin Overview

### byLLM

Implements Meaning-Typed Programming (MTP) for seamless AI integration:

```jac
import from byllm.lib { Model }

glob llm = Model(model_name="gpt-4o");

"""Translate text to the target language."""
def translate(text: str, language: str) -> str by llm();
```

[Full byLLM Reference →](byllm.md)

---

### jac-client

Build React-style web applications in Jac:

```jac
cl {
    def:pub Counter() -> any {
        has count: int = 0;

        return <div>
            <p>Count: {count}</p>
            <button onClick={lambda -> None { count = count + 1; }}>
                Increment
            </button>
        </div>;
    }
}
```

[Full jac-client Reference →](jac-client.md)

---

### jac-scale

Deploy and scale Jac applications:

```bash
# Start API server
jac start app.jac

# Deploy to Kubernetes
jac scale deploy --replicas 3
```

[Full jac-scale Reference →](jac-scale.md)

---

## Plugin Architecture

Jac uses a pluggy-based plugin system that allows extending the compiler and runtime:

- **Compiler plugins** - Transform Jac code during compilation
- **Runtime plugins** - Add runtime capabilities (APIs, storage, etc.)
- **Bundler plugins** - Customize build and bundling behavior

---

## Creating Plugins

See the [Internals documentation](../../community/internals/) for information on creating custom plugins.
