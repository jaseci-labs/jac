# Debugging in VS Code

Debug your Jac programs with breakpoints, variable inspection, and graph visualization.

> **Prerequisites**
>
> - Python 3.12+
> - jaclang installed
> - VS Code with Jac extension
> - Time: ~15 minutes

---

## Quick Start

If you're already familiar with debuggers:

1. Install Python 3.12+ and jaclang
2. Install VS Code + Jac extension
3. Create launch.json (Debug and Run > Create launch.json > Jac Debug)
4. Open VS Code Command Palette and run `jacvis` for graph visualization
5. Set a breakpoint > Run Debugger > Inspect variables

---

## What is the Jac Debugger?

The Jac Debugger helps you find and fix issues in Jac programs. It supports:

- **Breakpoints** - Pause execution at specific lines
- **Step-through execution** - Execute code line by line
- **Variable inspection** - View local and global variable values
- **Graph visualization** - Unique to Jac: see your nodes and edges visually

---

## One-Time Setup

Complete these steps once per computer.

### Requirements

| Requirement | How to Check |
|-------------|--------------|
| Python 3.12+ | `python --version` |
| jaclang | `jac --version` |
| VS Code | [Download](https://code.visualstudio.com/) |
| Jac Extension | Extensions tab > search "Jac" |

### Enable Breakpoints in VS Code

To set breakpoints in Jac files:

1. Open VS Code Settings
2. Search for **"breakpoints"**
3. Enable **Debug: Allow Breakpoints Everywhere**

### Install Jac Extension

1. Open VS Code **Extensions** panel
2. Search for **"Jac"**
3. Click **Install**

---

## Project Setup

Do this for each new Jac project.

### Create launch.json

`launch.json` tells VS Code how to run the debugger.

1. Open the **Run and Debug** panel (Ctrl+Shift+D / Cmd+Shift+D)
2. Click **Create a launch.json file**
3. Select **Jac Debug**
4. VS Code generates the configuration automatically

Your `.vscode/launch.json` will look like:

```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "type": "jac",
            "request": "launch",
            "name": "Jac Debug",
            "program": "${file}"
        }
    ]
}
```

---

## Using Breakpoints

Breakpoints pause execution so you can inspect program state.

### Setting a Breakpoint

Click in the gutter (left of the line number) to set a breakpoint:

```jac
def complex_calculation(x: int, y: int) -> int {
    result = x * 2;          # <- Set breakpoint here
    result = result + y;
    result = result ** 2;
    return result;
}

with entry {
    answer = complex_calculation(5, 3);
    print(answer);
}
```

### Running the Debugger

1. Set your breakpoint
2. Press **F5** or click **Run and Debug**
3. The program pauses at the breakpoint

### Debugger Controls

| Action | Shortcut | Description |
|--------|----------|-------------|
| **Continue** | F5 | Run until next breakpoint |
| **Step Over** | F10 | Execute line, skip into functions |
| **Step Into** | F11 | Execute line, enter functions |
| **Step Out** | Shift+F11 | Run until current function returns |
| **Restart** | Ctrl+Shift+F5 | Restart from beginning |
| **Stop** | Shift+F5 | Stop debugging |

### Inspecting Variables

When paused, the **Variables** panel shows:

- **Local Variables** - Variables in the current function scope
- **Global Variables** - Variables defined at module level

---

## Graph Visualization

Jac's debugger includes a visual tool to see your graph structure in real time.

### Example Graph Program

```jac
node Person {
    has age: int;
}

with entry {
    # Create people nodes
    jonah = Person(16);
    sally = Person(17);
    teacher = Person(42);
    jonah_mom = Person(45);

    # Connect Jonah to root
    root ++> jonah;

    # Create Jonah's relationships
    jonah ++> jonah_mom;
    jonah ++> teacher;
    jonah ++> sally;
}
```

### Opening the Graph Visualizer

1. Open the VS Code Command Palette:
    - **Windows/Linux:** Ctrl+Shift+P
    - **macOS:** Cmd+Shift+P
2. Type `jacvis`
3. Select **jacvis: Visualize Jaclang Graph**

A side panel opens showing your graph.

### Watching the Graph Build

1. Open the graph visualizer panel
2. Set a breakpoint in your code
3. Start debugging (F5)
4. Step through the code - watch nodes and edges appear in real time

You can drag nodes around to better visualize the structure.

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Breakpoints are grey / don't trigger | Enable **Debug: Allow Breakpoints Everywhere** in VS Code settings |
| "No Jac debugger found" | Reload VS Code window after installing Jac extension |
| Program runs but debugger doesn't stop | Use **Run and Debug** (F5), not the terminal |
| Graph doesn't update | Open `jacvis` **before** starting the debugger |

---

## Next Steps

- [Testing Your Code](testing.md) - Write and run tests
- [Object-Spatial Programming](osp.md) - Learn about nodes, edges, and walkers
