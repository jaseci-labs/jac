# 🎨 Introduce jacpretty - A New Console Library for Jac

## What is this?

This PR introduces **jacpretty**, a brand new lightweight console library built specifically for the Jac CLI. It provides beautiful, colorful terminal output with a simple, intuitive API.

## What does jacpretty bring to Jac?

jacpretty is our **own purpose-built console library** designed to make Jac's CLI output:

- **Beautiful** - Colorful, styled text that's easy to read
- **Fast** - Lightweight with zero external dependencies
- **Smart** - Automatically adapts to different terminal environments
- **Consistent** - Unified styling across all Jac commands

## What can it do?

### 🌈 Colors & Styles

Write styled text using simple markup:

- `[bold]text[/]` - Make text **bold**
- `[red]text[/]` - Add colors (red, green, blue, yellow, cyan, magenta, and bright variants)
- `[bold green]text[/]` - Combine styles
- `[dim]text[/]` - Subtle, dimmed text

### 📋 Helper Functions

Built-in helpers for common CLI patterns:

- **Success messages** with green checkmarks ✓
- **Error messages** in red with optional hints
- **Warnings** in yellow with warning symbols ⚠
- **Info messages** in cyan
- **Tables** - Display data in clean, formatted tables
- **Headers** - Section titles with decorative rules
- **Lists** - Bulleted lists with colored symbols

### 🧠 Smart Behavior

jacpretty automatically:

- Detects if colors are supported in your terminal
- Disables colors in CI/CD environments or when piping output
- Respects `NO_COLOR` and `NO_EMOJI` environment variables
- Works great on Windows Terminal, macOS, and Linux

## Simple Example

```jac
import from jaclang.cli.impl.console { _print, console }

// Print with style
_print("[bold]Building project...[/]");
_print("[green]✓[/] Success!");
_print("[red]✗[/] Error occurred");

// Use helper methods
console.success("Compilation complete");
console.error("File not found", hint="Check the file path");
console.warning("Deprecated syntax used");
```

## Library Components

**Three core modules:**

- **`jacpretty.jac`** - Core rendering engine with ANSI color/style generation
- **`console.impl.jac`** - High-level wrapper with helper methods
- **`console.jac`** - Clean public API for easy importing

**Key Features:**

- Type-safe enums for colors and styles
- Simple markup parser (`[bold]text[/]`)
- Smart environment detection
- Works everywhere - Windows, macOS, Linux

## Why jacpretty?

✅ **Zero dependencies** - Built entirely in Jac, no external packages needed
✅ **Lightweight & Fast** - Quick imports, faster CLI startup
✅ **Built for Jac** - Designed specifically for Jac CLI needs
✅ **Easy to use** - Simple markup syntax, intuitive helper methods
✅ **Production ready** - Handles all terminal types and environments

## What's New in This PR

This is the **initial release** of jacpretty. It includes:

- Complete color and style markup system
- 10+ helper methods for common CLI patterns
- Smart environment detection (terminals, CI/CD, pipes)
- Full integration with Jac CLI
- Comprehensive documentation and examples

---

**Ready to make Jac's output beautiful!** ✨
