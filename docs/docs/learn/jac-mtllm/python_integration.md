# MTLLM as a library for python

As Jaclang is a language that supersets Python, you can easily integrate it into your existing Python application. This guide will show you how to do that by integrating a AI feature into a simple Task Manager application build using Python.

The MTLLM module itself is written as a Jaclang plugin which can also be used in Python applications. You can install the MTLLM module using pip:

```bash
pip install mtllm
```

## Importing MTLLM in Python

To use MTLLM in your Python application, you need to import the `mtllm` module. Here is how you can do that:

```python linenums="1"
from dataclasses import dataclass
from mtllm.llm import Model, Image, by
from jaclang import JacMachineInterface as Jac

llm = Model(model_name="gpt-4o")

@dataclass
class Person:
    full_name: str
    description: str
    year_of_birth: int

@Jac.sem("Create a Person object based on the image provided.")
def get_person_info(img: Image) -> Person:
    return llm.invoke(get_person_info, { "img": img })
```

??? example "NOTE:
    "The above example will be changed to use an easier-to-use API in the future. The current example is a low-level API that requires you to define the function and its parameters manually. The easier-to-use API will allow you to define the function and its parameters in a more user-friendly way."

## Invoke parameters

In jaclang setting a invoke parameter is done by calling the llm with the all the invoke parameters. Here is an example of how you can do that:

```jac linenums="1"
import from mtllm.llm { Model }

glob llm = Model(model_name="gpt-4o")

def generate_joke() -> str by llm(temperature=0.3);
```

The `temperature` parameter is used to control the randomness of the output. A lower value will result in more deterministic output, while a higher value will result in more random output.

The same can be done in Python as well. Here is how you can do that:

```python linenums="1"
from mtllm.llm import Model

llm = Model(model_name="gpt-4o")

def generate_joke() -> str:
    return llm(temperature=0.3).invoke(generate_joke)
```

## Using python function as tools

You can use Python functions as tools directly in MTLLM. This allows you to define functions that can be used by the LLM to perform specific tasks. Here is an example of how you can do that:

```python linenums="1"
from mtllm.llm import Model
llm = Model(model_name="gpt-4o")


def get_weather(city: str) -> str:
    return f"The weather in {city} is sunny."

def answer_question(question: str) -> str:
    return llm( tools=[get_weather]).invoke(
        answer_question, {"question": question}
    )
```
