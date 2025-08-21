<h1 style="color: orange; font-weight: bold; text-align: center;">Getting Started With Jac and Jaseci</h1>

# Installation

Firstly make sure that Python 3.12 or higher is installed in your environment, then simply install Jac using pip:

```bash
python -m pip install -U jaclang
```

Once you've got Jaclang installed, just give the Jac CLI a try to make sure everything's up and running smoothly.

- Start the Jac CLI:
    ```bash
    jac --version
    ```
- Run a .jac file
    ```bash
    jac run <file_name>.jac
    ```
- To test run a 'Hello World' Program
    ```bash
    echo "with entry { print('Hello world'); }" > test.jac;
    jac run test.jac;
    rm test.jac;
    ```
> **Note**
>
> If these commands prints ```Hello world``` you are good to go.

## <span style="color: orange">Installing the VS Code Extention
</span>

In addition to setting up JacLang itself, you may also want to take advantage of the JacLang language extension for Visual Studio Code (VSCode). This will give you enhanced code highlighting, autocomplete, and other useful language features within your VSCode environment.

- To install just visit the VS Code marketplace and install,
    - [Jac Extension](https://marketplace.visualstudio.com/items?itemName=jaseci-labs.jaclang-extension)

## Next Steps

<div class="grid cards" markdown>

-   __Jac in a Flash__

    ---

    *See Jac's Syntax with a Toy*

    [Jac in a Flash](jac_in_a_flash.md){ .md-button .md-button--primary }

-   __A Real World Example__

    ---

    *See somthing real in Jac*

    <!-- [:octicons-arrow-right-24: Getting started](#) -->

    [A Robust Example](examples/littleX/tutorial.md){ .md-button }

-   __Experience Jac in Browser__

    ---

    *Hit the Playground*

    [Jac Playground](../playground/index.html){ .md-button .md-button--primary }

</div>

