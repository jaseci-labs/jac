<h1 style="color: orange; font-weight: bold; text-align: center;">Getting Started With Jac and Jaseci</h1>

# Installation

Firstly make sure that Python 3.12 or higher is installed in your environment, then simply install Jac using pip:

```bash
python -m pip install -U jaclang jac-client
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

## <span style="color: orange">Installing the VS Code Extension</span>

In addition to setting up JacLang itself, you may also want to take advantage of the JacLang language extension for Visual Studio Code (VSCode) or Cursor. This will give you enhanced code highlighting, autocomplete, and other useful language features within your editor environment.

**For VS Code users:**

- Visit the VS Code marketplace and install the [Jac Extension](https://marketplace.visualstudio.com/items?itemName=jaseci-labs.jaclang-extension)

**For Cursor users:**

1. Go to the [latest Jaseci release page](https://github.com/Jaseci-Labs/jaseci/releases/latest)
2. Download the latest `jaclang-extension-*.vsix` file from the release assets
3. Open Cursor
4. Press `Ctrl+Shift+P` (or `Cmd+Shift+P` on Mac)
5. Type `>install from vsix` and select the command
6. Select the downloaded VSIX file
7. The extension will be installed and ready to use

## Next Steps

- [Jac in a Flash](jac_in_a_flash.md) - See Jac's Syntax with a Toy
- [A Robust Example](examples/littleX/tutorial.md) - See something real in Jac
- [Jac Playground](../playground/index.html) - Experience Jac in Browser
