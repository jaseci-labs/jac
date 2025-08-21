# MTLLM as a Library for Python

The MTLLM module is a Jaclang plugin that provides AI functionality. Since Jaclang supersets Python, MTLLM can be integrated into Python applications. This guide demonstrates how to use MTLLM in Python.

MTLLM is a Python package that needs to be installed using:

```bash
pip install mtllm
```

## Importing MTLLM in Python

MTLLM functionality is accessed by importing the `mtllm` module and using the `by` decorator on functions.

```python linenums="1"
import jaclang
from jaclang import JacMachineInterface as Jac
from dataclasses import dataclass
from mtllm import Model, Image, by

llm = Model(model_name="gpt-4o")

@dataclass
class Person:
    full_name: str
    description: str
    year_of_birth: int


@by(llm)
def get_person_info(img: Image) -> Person: ...

img = Image("https://bricknellschool.co.uk/wp-content/uploads/2024/10/einstein3.webp")

person = get_person_info(img)
print(f"Name: {person.full_name}, Description: {person.description}, Year of Birth: {person.year_of_birth}")
```
??? example "NOTE:"
    Here MTLLM can only use primitive types and dataclasses as input and output types. We are working to resolve this limitation.


## Model Hyper-parameters

In Jaclang, hyper-parameters are set by passing them to the LLM model:

```jac linenums="1"
import from mtllm { Model }

glob llm = Model(model_name="gpt-4o")

def generate_joke() -> str by llm(temperature=0.3);
```

The `temperature` hyper-parameter controls the randomness of the output. Lower values produce more deterministic output, while higher values produce more random output.

In Python, hyper-parameters are passed similarly:

```python linenums="1"
from mtllm import Model, by

llm = Model(model_name="gpt-4o")

@by(llm(temperature=0.3))
def generate_joke() -> str: ...
```

## Using Python Functions as Tools

Python functions can be used as tools in MTLLM. Functions defined in Python are callable by the LLM to perform specific tasks:

```python linenums="1"
from mtllm.llm import Model
llm = Model(model_name="gpt-4o")


def get_weather(city: str) -> str:
    return f"The weather in {city} is sunny."

@by(llm(tools=[get_weather]))
def answer_question(question: str) -> str: ...
```
