In Jac, a module is analogous to a Python module, serving as a container for various elements such as functions, classes (referred to as "archetypes" later in this document), global variables, and other constructs that facilitate code organization and reusability. Each module begins with an optional module-level docstring, which provides a high-level overview of the module's purpose and functionality. This docstring, if present, is positioned at the very start of the module, before any other elements.

???+ Note "Docstrings"

    Jac adopts a stricter approach to docstring usage compared to Python. It mandates the inclusion of a single docstring at the module level and permits individual docstrings for each element within the module. This ensures that both the module itself and its constituent elements are adequately documented. If only one docstring precedes the first element, it is automatically designated as the module-level docstring.

    Also Note, that Jac enforces type annotations in function signatures and class fields to promote type safety and ultimately more readable and scalable codebases.

Elements within a Jac module encompass familiar constructs from Python, including functions and classes, with the addition of some unique elements that will be discussed in further detail. Below is a table of module elements in Jac. These constructs are described in detail later in this document.

| Module Item           | Description       |
|----------------|-------------------|
| [**Import Statements**](#importinclude-statements)    |   Same as python with slightly different syntax, works with both `.jac` and `.py` files (in addition to packages)                |
| [**Archetypes**](#archetypes)       |    Includes traditional python `class` construct with equiviant semantics, and additionaly introduces a number of new class-like constructs including `obj`, `node`, `edge`, and `walker` to enable the object-spatial programming paradigmn               |
| [**Function Abilities**](#abilities) | Equivalent to traditional python function semantics with change of keyword `def` to `can`. Type hints are required in parameters and returns |
| [**Object-Spatial Abilities**](#abilities)         |  A function like construct that is triggered by types of `node`s or `walker`s in the object-spatial paradigm            |
| [**Free Floating Code**](#free-code)      |  Construct (`with entry {...}`) to express presence of free floating code within a module that is not part of a function or class-like object. Primarily for code cleanliness, readability, and maintainability.    |
| [**Global Variables**](#global-variables)    |   Module level construct to express global module level variables without using `with entry` syntax. (`glob x=5` is equivalent to `with entry {x=5;}`)                |
| [**Test**](#tests)           |   A language level construct for testing, functionality realized with `test` and `check` keywords.                |
| [**Inline Python**](#inline-python)  |  Native python code can be inlined alongside jac code at arbitrary locations in a Jac program using `::py::` directive                 |


Moreover, Jac requires that any standalone, module-level code be encapsulated within a `with entry {}` block. This design choice aims to enhance the clarity and cleanliness of Jac codebase.
