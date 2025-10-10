# byLLM as a Library for Python

The byLLM module is a Jaclang plugin that provides AI functionality. Since Jaclang supersets Python, byLLM can be integrated into Python applications. This guide demonstrates how to use byLLM in Python.

byLLM is a Python package that needs to be installed using:

```bash
pip install byllm
```

## Importing byLLM in Python

byLLM functionality is accessed by importing the `byllm` module and using the `by` decorator on functions.

```python linenums="1"
import jaclang
from dataclasses import dataclass
from byllm import Model, Image, by

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
    Here byLLM can only use primitive types and dataclasses as input and output types. We are working to resolve this limitation.


## Model Hyper-parameters

In Jaclang, hyper-parameters are set by passing them to the LLM model:

```jac linenums="1"
import from byllm { Model }

glob llm = Model(model_name="gpt-4o")

def generate_joke() -> str by llm(temperature=0.3);
```

The `temperature` hyper-parameter controls the randomness of the output. Lower values produce more deterministic output, while higher values produce more random output.

In Python, hyper-parameters are passed as follows:

```python linenums="1"
import jaclang
from byllm import Model, by

llm = Model(model_name="gpt-4o")

@by(llm(temperature=0.3))
def generate_joke() -> str: ...
```

## Using Python Functions as Tools

Python functions can be used as tools in byLLM. Functions defined in Python are callable by the LLM to perform specific tasks:

```python linenums="1"
import jaclang
from byllm import Model
llm = Model(model_name="gpt-4o")


def get_weather(city: str) -> str:
    return f"The weather in {city} is sunny."

@by(llm(tools=[get_weather]))
def answer_question(question: str) -> str: ...
```

## Using Semstrings for Semantic Enrichment

In Jac we introduced the `sem` keyword as a means to attach additional semantics to code objects such as object attributes and function argument. The syntax in jac is as follows.

```jac
obj Person {
    has name:str;
    has age:int;
    has ssn: int;
}
sem Person.ssn = "last four digits of the Social Security number"
```

Using `sem` functionality in python is a bit diferent as the attachment is done using a `@sem` decorator.

```python
from jaclang import JacMachineInterface as Jac

@Jac.sem('<Person Semstring>', {
    'name' : '<name semstring>',
    'age' : '<age semstring>',
    'ssn' : "<ssn semstring>"
    }
)
@datclass
class Person:
    name: str
    age: int
    ssn: int
```

!!! note
    The `sem` implementation in Python is a work-in-progress. The Python way of adding semstrings may change in future releases of byLLM.