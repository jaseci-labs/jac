# Quick Start Guide

> This guide provides a quick introduction to installing and using byLLM. For detailed usage instructions, click the button below.

[Full byLLM Usage Guide](https://www.jac-lang.org/learn/jac-byllm/usage/){: .md-button }

## Installation

To get started with byLLM, install the base package:

```bash
pip install byllm
```

## AI-Integrated Function Example

Let's consider an example program where we attempt to categorize a person by their personality using an LLM. For simplicity we will be using names of historical figures.

### Standard Implementation

Traditional implementation of this program with a manual algorithm:

```jac linenums="1"

enum Personality {
    INTROVERT,
    EXTROVERT,
    AMBIVERT
}

def get_personality(name: str) -> Personality {
    # Traditional approach: manual algorithm, prompt-engineered LLM call, etc.
}

with entry {
    name = "Albert Einstein";
    result = get_personality(name);
    print(f"{result} personality detected for {name}");
}
```

**Limitations**: Defining an algorithm in code for this problem is difficult, while integrating an LLM to perform the task would require manual prompt engineering, response parsing, and type conversion to be implemented by the developer.

### byLLM Implementation

The `by` keyword abstraction enables functions to process inputs of any type and generate contextually appropriate outputs of the specified type:

#### Step 1: Configure LLM Model

```jac linenums="1"
import from byllm.lib {Model}

glob llm = Model(model_name="gemini/gemini-2.0-flash");
```

#### Step 2: Implement LLM-Integrated Function

Add `by llm` to enable LLM integration:

```jac linenums="1"
def get_personality(name: str) -> Personality by llm();
```

This will auto-generate a prompt for performing the task and provide an output that strictly adheres to the type `Personality`.

#### Step 3: Execute the Application

Set your API key and run:

```bash
export GEMINI_API_KEY="your-api-key-here"
jac run personality.jac
```

For complete usage methodologies of the `by` abstraction, refer to the [Usage Guide](./usage.md) for documentation on object methods, object instantiation, and multi-agent workflows.


### byLLM Usage in Python

As byLLM is a python package, it can be natively used in jac. The following code show the above example application built in native python with byLLM.

```python linenums="1"
import jaclang
from byllm.lib import Model, by
from enum import Enum

llm = Model(model_name="gemini/gemini-2.0-flash")

class Personality(Enum):
    INTROVERT
    EXTROVERT
    AMBIVERT

@by(model=llm)
def get_personality(name: str) -> Personality: ...

name = "Albert Einstein"
result = get_personality(name)
print(f"{result} personality detected for {name}")
```

[Full byLLM Usage Guide](https://www.jac-lang.org/learn/jac-byllm/usage/){: .md-button }

To learn more about usage of `by` in python, please refer to [byLLM python Interface](./python_integration.md).
