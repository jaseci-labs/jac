<div align="left">
    <img src="/assets/byLLM_name_logo.png" height="150" width="400">
</div>

# **Coding, Less Prompting**

<!-- [![PyPI version](https://img.shields.io/pypi/v/byllm.svg)](https://pypi.org/project/byllm/) [![tests](https://github.com/jaseci-labs/jaseci/actions/workflows/test-jaseci.yml/badge.svg?branch=main)](https://github.com/jaseci-labs/jaseci/actions/workflows/test-jaseci.yml) -->

byLLM is an innovative AI integration framework built for the Jaseci ecosystem, implementing the cutting-edge Meaning Typed Programming (MTP) paradigm. MTP revolutionizes AI integration by embedding prompt engineering directly into code semantics, making AI interactions more natural and maintainable. While primarily designed to complement the Jac programming language, byLLM also provides a powerful Python library interface.


<!-- ## What is MTP?

Meaning-Typed Programming (MTP) is a programming paradigm that automates LLM integration through language-level abstractions. MTP extracts semantic meaning from code to automatically generate prompts and handle response conversion, reducing the need for manual prompt engineering. These abstractions enable seamless LLM integration by automatically generating prompts from code semantics, making it easier to build agentic AI applications. Additional research details are available on arxiv.org.

The MTP concept is implemented in Jac-lang through the **byLLM** plugin, which is available as a PyPI package. -->


<div align="left" style="margin-top: 1em;">
    <a href="https://arxiv.org/abs/2405.08965" class="md-button" style="display: inline-block; margin-right: 10px;">MTP Research</a>
    <a href="./quickstart.md" class="md-button" style="display: inline-block; margin-right: 10px;">Get Started with MTP</a>
    <a href="https://github.com/jaseci-labs/jaseci/tree/main/jac-byllm" class="md-button" style="display: inline-block;">GitHub</a>
</div>

<!-- ![](./assets/byLLM_name_logo.png) -->

<!-- **Quick Links:**

- [About byLLM](https://www.jac-lang.org/learn/jac-byllm/with_llm/)
- [Get started](https://www.jac-lang.org/learn/jac-byllm/quickstart/)
- [Usage docs](https://www.jac-lang.org/learn/jac-byllm/usage/)
- [Research Paper](https://arxiv.org/abs/2405.08965) -->


Installation is simple via PyPI:

```bash
pip install byllm
```

## Basic Example

Consider building an application that translates english to other languages using an LLM. This can be simply built as follows:
=== "Jac"
    ```jac linenums="1"
    import from byllm { Model }

    glob llm = Model(model_name="gpt-4o");

    def translate_to(language: str, phrase: str) -> str by llm();

    with entry {
        output = translate_to(language="Welsh", phrase="Hello world");
        print(output);
    }
    ```
=== "python"
    ```python linenums="1"
    from byllm import Model, by

    llm = Model(model_name="gpt-4o")

    @by(llm)
    def translate_to(language: str, phrase: str) -> str: ...

    output = translate_to(language="Welsh", phrase="Hello world")
    print(output)
    ```

This simple piece of code replaces traditional prompt engineering without introducing additional complexity.

## Power of Types with LLMs

Consider a program that detects the personality type of a historical figure from their name. This can eb built in a way that LLM picks from an enum and the output strictly adhere this type.

=== "Jac"
    ```jac linenums="1"
    import from byllm { Model }
    glob llm = Model(model_name="gemini/gemini-2.0-flash");

    enum Personality {
        INTROVERT,
        EXTROVERT,
        AMBIVERT
    }

    def get_personality(name: str) -> Personality by llm();

    with entry {
        name = "Albert Einstein";
        result = get_personality(name);
        print(f"{result} personality detected for {name}");
    }
    ```
=== "Python"
    ```python linenums="1"
    from byllm import Model, by
    from enum import Enum
    llm =  Model(model_name="gemini/gemini-2.0-flash")

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

Similarly, custom types can be used as output types which force the LLM to adhere to the specified type and produce a valid result.

## Control! Control! Control!

Even if we are elimination prompt engineering entierly, we allow specific ways to enrich code semantics through **docstrings** and **semstrings**.

=== "Jac"
    ```jac linenums="1"
    import from byllm { Model }
    glob llm = Model(model_name="gemini/gemini-2.0-flash");

    """Represents the personal record of a person"""
    obj Person {
        has name: str;
        has dob: str;
        has ssn: str;
    }

    sem Person.name = "Full name of the person";
    sem Person.dob = "Date of Birth";
    sem Person.ssn = "Last four digits of the Social Security Number of a person";

    """Calculate eligibility for various services based on person's data."""
    def check_eligibility(person: Person, service_type: str) -> bool by llm();
    ```
=== "Python"
    ```python linenums="1"
    from jaclang import JacMachineInterface as Jac
    from dataclasses import dataclass
    from byllm import Model, by
    llm =  Model(model_name="gemini/gemini-2.0-flash")

    @Jac.sem('', {  'name': 'Full name of the person',
                    'dob': 'Date of Birth',
                    'ssn': 'Last four digits of the Social Security Number of a person'
                    })
    @dataclass
    class Person():
        name: str
        dob: str
        ssn: str

    @by(llm)
    def check_eligibility(person: Person, service_type: str) -> bool: ...
        """Calculate eligibility for various services based on person's data."""
    ```

Docstrings naturally enhance the semantics of their associated code constructs, while the `sem` keyword provides an elegant way to enrich the meaning of class attributes and function arguments. Our research shows these concise semantic strings are more effective than traditional multi-line prompts.

**📚 Full Documentation**: [Jac byLLM Documentation](https://www.jac-lang.org/learn/jac-byllm/with_llm/)

**🎮 Code Examples**: [Jac byLLM Examples](https://www.jac-lang.org/learn/jac-byllm/examples/)

<!-- - [Fantasy Trading Game](https://www.jac-lang.org/learn/examples/mtp_examples/fantasy_trading_game/) - Interactive RPG with AI-generated characters
- [RPG Level Generator](https://www.jac-lang.org/learn/examples/mtp_examples/rpg_game/) - AI-powered game level creation
- [RAG Chatbot Tutorial](https://www.jac-lang.org/learn/examples/rag_chatbot/Overview/) - Building chatbots with document retrieval -->

**🔬 Research**: The research paper of byLLM is available on [Arxiv](https://arxiv.org/abs/2405.08965) and accepted for OOPSLA 2025.

## Quick Links

- [Getting Started Guide](https://www.jac-lang.org/learn/jac-byllm/quickstart/)
- [Jac Language Documentation](https://www.jac-lang.org/)
- [GitHub Repository](https://github.com/jaseci-labs/jaseci)

## Contributing

We welcome contributions to byLLM! Whether you're fixing bugs, improving documentation, or adding new features, your help is appreciated.

Areas we actively seek contributions:
- 🐛 Bug fixes and improvements
- 📚 Documentation enhancements
- ✨ New examples and tutorials
- 🧪 Test cases and benchmarks

Please see our [Contributing Guide](https://www.jac-lang.org/internals/contrib/) for detailed instructions.

If you find a bug or have a feature request, please [open an issue](https://github.com/jaseci-labs/jaseci/issues/new/choose).

## Community

Join our vibrant community:
- [Discord Server](https://discord.gg/6j3QNdtcN6) - Chat with the team and community

## License

This project is licensed under the MIT License.

### Third-Party Dependencies

byLLM integrates with various LLM providers (OpenAI, Anthropic, Google, etc.) through [LiteLLM](https://litellm.ai/).

## Cite our research


> Jayanaka L. Dantanarayana, Yiping Kang, Kugesan Sivasothynathan, Christopher Clarke, Baichuan Li, Savini Kashmira, Krisztian Flautner, Lingjia Tang, and Jason Mars. 2025. MTP: A Meaning-Typed Language Abstraction for AI-Integrated Programming. Proc. ACM Program. Lang. 9, OOPSLA2, Article 314 (October 2025), 29 pages. https://doi.org/10.1145/3763092