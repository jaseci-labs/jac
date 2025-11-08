# Jac Extension

This extension provides support for the [Jac](https://doc.jaseci.org) programming language. It provides syntax highlighting and leverages the LSP to provide a rich editing experience.

# Quick Start

All that is needed is to have jac installed (i.e. `pip install jaclang`) and the `jac` command line tool present in your environment.

## Installation

**For VS Code users:**


1. Open VS Code
2. Go to Extensions (Ctrl+Shift+X or Cmd+Shift+X on Mac)
3. Search for "Jac" in the marketplace
4. Install the official "Jac" extension by JaseciLabs

Alternatively, install directly from the [VS Code marketplace](https://marketplace.visualstudio.com/items?itemName=jaseci-labs.jaclang-extension).

**For Cursor users:**

1. Go to the [latest Jaseci release page](https://github.com/Jaseci-Labs/jaseci/releases/latest)
2. Download the latest `jaclang-extension-*.vsix` file from the release assets
3. Open Cursor
4. Press `Ctrl+Shift+P` (or `Cmd+Shift+P` on Mac)
5. Type `>install from vsix` and select the command
6. Select the downloaded VSIX file
7. The extension will be installed and ready to use

# Debugging Jaclang

Note that it'll install [python extention for vscode](https://marketplace.visualstudio.com/items?itemName=ms-python.python) as a dependecy as it is needed to debug the python bytecode that jaclang produce.

To debug a jac file a launch.json file needs to created with the debug configurations. This can simply generated with:
1. Goto the debug options at the left pannel.
2. click "create a launch.json file"
3. Select `Jac Debug` Option

This will create a debug configration to run and debug a single jac file, Here is the default sinppit, modify it as your
preference to debug different types of applications or modules.

```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "type": "debugpy",
            "request": "launch",
            "name": "Run a jac file",
            "program": "${command:extension.jaclang-extension.getJacPath}",
            "args": "run ${file}"
        }
    ]
}
```

This animated GIF bellow will demonstrate on the steps discuessed above.

![Animation](https://github.com/user-attachments/assets/dcf808a4-b54e-4079-9948-9e88e6b0559e)

To visualize the Jac graph while debugging, open the graph visualize view using the command `jacvis: Visualize Jac Graph` in the command palette, (shortcut for command palette is `ctrl+shift+p`)

<img src="https://github.com/user-attachments/assets/f763fe86-33b5-4254-bb72-34c069d0f0c8" width="100%">

# Features

- Code completion
- Syntax highlighting
- Snippets
- Go to definition
- Document symbols, workspace symbols
- Variables hint, and documentation on hover
- Diagnostics
- Diagnostics
