# JacStyle: CSS-Inspired Styling Language Integration for Jac

**Version:** 1.1
**Date:** 2025-10-18
**Author:** Claude (AI Assistant)
**Status:** Proposal

---

## Executive Summary

This document proposes **JacStyle**, a native CSS-inspired styling subsystem integrated directly into the Jac programming language grammar. JacStyle introduces a `style` keyword that creates named style blocks containing CSS-like declarations, while leveraging Jac's existing token system, semantic features, and language constructs.

**Key Features:**
- Native `style` keyword with block syntax (`style name { ... }`)
- SCSS-inspired features using Jac tokens and semantics
- **Optional `let` keyword** for variables (CSS-style or Jac-style)
- Nested selectors, mixins, variables, and conditionals
- Type-safe integration with Jac's type system
- First-class support in the language grammar and AST
- Seamless formatter integration

---

## Table of Contents

1. [Motivation](#1-motivation)
2. [Language Integration](#2-language-integration)
3. [Syntax Specification](#3-syntax-specification)
4. [Grammar Definition](#4-grammar-definition)
5. [Feature Set](#5-feature-set)
6. [Examples](#6-examples)
7. [Implementation Roadmap](#7-implementation-roadmap)
8. [Renderer Architecture](#8-renderer-architecture)
9. [Appendix](#9-appendix)

---

## 1. Motivation

### 1.1 Why Integrate Styling into Jac?

Modern application development increasingly blurs the line between logic and presentation. React popularized component-centric development with JSX; Jac already supports JSX elements. JacStyle completes this vision by:

1. **Unified Development Experience**: Define components, logic, and styles in one language
2. **Type Safety**: Leverage Jac's type system for style values
3. **Code Reusability**: Use Jac's imports, implementations, and modularity for styles
4. **Tooling Integration**: Native language support enables better IDE features, linting, and formatting
5. **Framework Agnostic**: Generate CSS for web, mobile, or custom renderers

### 1.2 Design Philosophy

JacStyle follows these principles:

- **Jac-First**: Use Jac tokens, operators, and semantics wherever possible
- **Familiar**: CSS/SCSS developers should feel at home
- **Powerful**: Support modern styling patterns (nesting, mixins, variables, conditionals)
- **Extensible**: Allow custom renderers and target platforms
- **Type-Safe**: Integrate with Jac's type system and validation

---

## 2. Language Integration

### 2.1 Top-Level Statement

JacStyle introduces `style` as a new top-level statement, similar to `obj`, `walker`, `test`, and `impl`:

```jac
module: (toplevel_stmt (tl_stmt_with_doc | toplevel_stmt)*)?

onelang_stmt: import_stmt
            | archetype
            | ability
            | global_var
            | free_code
            | test
            | impl_def
            | sem_def
            | style_def      # NEW
```

### 2.2 Token Additions

**New Keywords:**
- `KW_STYLE`: `"style"` - Primary keyword for style blocks
- `KW_MIXIN`: `"mixin"` - Define reusable style mixins
- `KW_INCLUDE`: `"include"` (reuse existing keyword) - Include a mixin
- `KW_EXTEND`: `"extend"` - Inherit from another selector

**New Operators:**
- `STYLE_AMPERSAND`: `"&"` - Parent selector reference (BW_AND already exists)
- `STYLE_INTERPOLATE`: `#{...}` - String interpolation for selectors/values

### 2.3 Access Control

Styles support Jac's access modifiers:
```jac
style :pub button_primary { ... }    # Public (exportable)
style :priv internal_mixin { ... }   # Private (module-only)
style :protect theme_base { ... }    # Protected (inherited only)
```

---

## 3. Syntax Specification

### 3.1 Basic Style Block

```jac
style style_name {
    selector {
        property: value;
        property: value;
    }
}
```

### 3.2 Selector Syntax

JacStyle supports standard CSS selectors with Jac string interpolation:

```jac
style my_theme {
    # Element selector
    button {
        background: #007bff;
    }

    # Class selector
    .primary-button {
        color: white;
    }

    # ID selector
    #header {
        height: 60px;
    }

    # Descendant combinator
    .container .item {
        margin: 10px;
    }

    # Child combinator
    ul > li {
        list-style: none;
    }

    # Attribute selector
    [data-active="true"] {
        border: 2px solid green;
    }

    # Pseudo-class
    button:hover {
        opacity: 0.8;
    }

    # Pseudo-element
    p::first-line {
        font-weight: bold;
    }
}
```

### 3.3 Property Declaration

Properties use CSS syntax with Jac value types:

```jac
style example {
    .box {
        # String values
        font-family: "Helvetica Neue", sans-serif;

        # Numeric values with units
        width: 100px;
        height: 50%;
        margin: 1.5em;

        # Color values
        color: #ff5733;
        background: rgb(255, 87, 51);
        border-color: rgba(0, 0, 0, 0.5);

        # Multiple values
        padding: 10px 20px 10px 20px;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1), 0 4px 8px rgba(0,0,0,0.1);

        # Functions
        transform: rotate(45deg) scale(1.2);
        background: linear-gradient(to right, #ff0000, #00ff00);
    }
}
```

### 3.4 Nested Selectors (SCSS-inspired)

```jac
style navigation {
    .navbar {
        background: #333;

        .nav-item {
            display: inline-block;
            padding: 10px;

            &:hover {
                background: #555;
            }

            a {
                color: white;
                text-decoration: none;

                &.active {
                    font-weight: bold;
                }
            }
        }
    }
}
```

**Generated CSS:**
```css
.navbar { background: #333; }
.navbar .nav-item { display: inline-block; padding: 10px; }
.navbar .nav-item:hover { background: #555; }
.navbar .nav-item a { color: white; text-decoration: none; }
.navbar .nav-item a.active { font-weight: bold; }
```

---

## 4. Grammar Definition

### 4.1 Lark Grammar Rules

Add to `jac.lark`:

```lark
# [Heading]: Style Definitions
style_def: decorators? KW_STYLE access_tag? named_ref style_block

style_block: LBRACE style_stmt* RBRACE

style_stmt: style_rule
          | style_variable
          | style_mixin_def
          | style_mixin_include
          | style_extend
          | style_conditional
          | comment_stmt

# Style rules (selector blocks)
style_rule: style_selector_list LBRACE style_declaration* RBRACE

style_selector_list: (style_selector COMMA)* style_selector

style_selector: style_selector_part+

style_selector_part: style_simple_selector
                   | style_combinator
                   | style_parent_ref

style_simple_selector: STYLE_SELECTOR_TEXT
                     | style_interpolation

style_combinator: STYLE_COMBINATOR  # > + ~ (space handled in lexer)

style_parent_ref: BW_AND  # & for parent reference

# Declarations (property: value)
style_declaration: style_property COLON style_value_list SEMI
                 | style_rule  # Allow nested rules

style_property: STYLE_PROPERTY_NAME
              | style_interpolation

style_value_list: (style_value COMMA?)* style_value

style_value: STYLE_VALUE_TEXT
           | STRING
           | INT
           | FLOAT
           | style_function
           | style_interpolation
           | expression  # Allow Jac expressions

style_function: STYLE_FUNCTION_NAME LPAREN style_value_list RPAREN

# Variables (let is optional for CSS familiarity)
style_variable: KW_LET? named_ref COLON expression SEMI

# Mixins
style_mixin_def: KW_MIXIN named_ref (LPAREN func_decl_params? RPAREN)? LBRACE style_declaration* RBRACE

style_mixin_include: KW_INCLUDE named_ref (LPAREN param_list? RPAREN)? SEMI

# Extend
style_extend: KW_EXTEND style_selector SEMI

# Conditionals
style_conditional: KW_IF expression LBRACE style_declaration* RBRACE
                 | KW_IF expression LBRACE style_declaration* RBRACE KW_ELSE LBRACE style_declaration* RBRACE

# Interpolation
style_interpolation: STYLE_INTERP_START expression STYLE_INTERP_END

# Terminals
KW_STYLE: "style"
KW_MIXIN: "mixin"
# KW_INCLUDE and KW_EXTEND reuse existing tokens

STYLE_SELECTOR_TEXT: /[.#]?[a-zA-Z_][\w\-]*/
                   | /\[[^\]]+\]/  # Attribute selectors
                   | /:[:a-z\-]+(\([^)]*\))?/  # Pseudo-classes/elements

STYLE_PROPERTY_NAME: /[a-z\-]+/

STYLE_VALUE_TEXT: /[^;,{}]+/

STYLE_FUNCTION_NAME: /[a-z\-]+/

STYLE_COMBINATOR: />|\+|~/

STYLE_INTERP_START: /#\{/
STYLE_INTERP_END: /}/
```

### 4.2 AST Node Definitions

Add to `unitree.py`:

```python
class StyleDef(ArchBlockStmt, CodeBlockStmt, ElementStmt):
    """Style definition block."""
    name: Name
    access: Optional[SubTag[Token]]
    body: StyleBlock
    decorators: Optional[Decorators]

class StyleBlock(AstNode):
    """Container for style statements."""
    statements: list[StyleStmt]

class StyleStmt(AstNode):
    """Base class for style statements."""
    pass

class StyleRule(StyleStmt):
    """Selector block with declarations."""
    selectors: list[StyleSelector]
    declarations: list[StyleDeclaration | StyleRule]  # Nested rules

class StyleSelector(AstNode):
    """CSS selector."""
    parts: list[StyleSelectorPart]

class StyleSelectorPart(AstNode):
    """Part of a selector (element, class, combinator, etc.)."""
    pass

class StyleSimpleSelector(StyleSelectorPart):
    """Simple selector (element, class, id, attribute, pseudo)."""
    value: str | StyleInterpolation

class StyleCombinator(StyleSelectorPart):
    """Combinator (>, +, ~, space)."""
    value: str

class StyleParentRef(StyleSelectorPart):
    """Parent selector reference (&)."""
    pass

class StyleDeclaration(AstNode):
    """Property: value declaration."""
    property: str | StyleInterpolation
    values: list[StyleValue]

class StyleValue(AstNode):
    """CSS value."""
    pass

class StyleValueText(StyleValue):
    """Text value."""
    value: str

class StyleValueFunction(StyleValue):
    """Function value (e.g., rgb(), calc())."""
    name: str
    args: list[StyleValue]

class StyleValueExpression(StyleValue):
    """Jac expression as value."""
    expr: Expr

class StyleInterpolation(AstNode):
    """#{expression} interpolation."""
    expr: Expr

class StyleVariable(StyleStmt):
    """Variable declaration: [let] name: value;"""
    name: Name
    value: Expr
    explicit: bool  # True if 'let' was used

class StyleMixinDef(StyleStmt):
    """mixin name(params) { ... }"""
    name: Name
    params: Optional[FuncDeclParams]
    body: list[StyleDeclaration]

class StyleMixinInclude(StyleStmt):
    """include mixin_name(args);"""
    name: Name
    args: Optional[ParamList]

class StyleExtend(StyleStmt):
    """extend .other-selector;"""
    selector: StyleSelector

class StyleConditional(StyleStmt):
    """if condition { ... } else { ... }"""
    condition: Expr
    if_body: list[StyleDeclaration]
    else_body: Optional[list[StyleDeclaration]]
```

---

## 5. Feature Set

### 5.1 Variables

Define style variables with or without the `let` keyword (both are supported):

```jac
style theme {
    # Define variables - 'let' is optional
    primary_color: "#007bff";        # Concise CSS-style
    let secondary_color: "#6c757d";  # Explicit Jac-style
    base_padding: 10;
    border_radius: 4;

    .button {
        background: primary_color;
        padding: f"{base_padding}px";
        border-radius: f"{border_radius}px";
    }

    .button-secondary {
        background: secondary_color;
        padding: f"{base_padding}px";
    }
}
```

**Note**: The `let` keyword is optional for style variables. Use it for consistency with Jac code, or omit it for CSS/SCSS familiarity. Both styles can be mixed in the same block.

### 5.2 Expressions and Calculations

Leverage Jac expressions directly:

```jac
style responsive {
    base_size: 16;
    scale: 1.5;

    h1 {
        font-size: f"{base_size * 2}px";
        margin: f"{base_size * scale}px";
    }

    .container {
        max-width: f"{1200 if responsive_mode else 960}px";
        padding: f"{base_size / 2}px";
    }
}
```

### 5.3 Mixins

Define reusable style fragments:

```jac
style utilities {
    # Define mixin with parameters
    mixin flex_center(direction: str = "row") {
        display: flex;
        justify-content: center;
        align-items: center;
        flex-direction: direction;
    }

    mixin button_base(bg_color: str, text_color: str) {
        background: bg_color;
        color: text_color;
        padding: 10px 20px;
        border: none;
        border-radius: 4px;
        cursor: pointer;

        &:hover {
            opacity: 0.9;
        }
    }

    # Use mixins
    .centered-row {
        include flex_center("row");
    }

    .primary-btn {
        include button_base("#007bff", "white");
    }

    .danger-btn {
        include button_base("#dc3545", "white");
    }
}
```

### 5.4 Extend/Inheritance

Inherit styles from other selectors:

```jac
style components {
    .button {
        padding: 10px 20px;
        border: none;
        border-radius: 4px;
        cursor: pointer;
    }

    .button-primary {
        extend .button;
        background: #007bff;
        color: white;
    }

    .button-large {
        extend .button-primary;
        padding: 15px 30px;
        font-size: 18px;
    }
}
```

### 5.5 Conditionals

Use Jac's control flow:

```jac
style adaptive {
    dark_mode: bool = true;
    high_contrast: bool = false;

    .card {
        if dark_mode {
            background: #1e1e1e;
            color: #ffffff;
            border: 1px solid #333;
        } else {
            background: #ffffff;
            color: #000000;
            border: 1px solid #ddd;
        }

        if high_contrast {
            border-width: 3px;
            font-weight: bold;
        }
    }
}
```

### 5.6 Loops and Iteration

Generate repetitive styles:

```jac
style grid {
    # Generate grid column classes
    for i in range(1, 13) {
        .col-{i} {
            flex: 0 0 f"{(i / 12) * 100}%";
            max-width: f"{(i / 12) * 100}%";
        }
    }

    # Generate spacing utilities
    spacings: list[int] = [0, 5, 10, 15, 20, 25, 30];
    for size in spacings {
        .m-{size} { margin: f"{size}px"; }
        .p-{size} { padding: f"{size}px"; }
    }
}
```

### 5.7 String Interpolation

Use `#{}` for dynamic selectors and values:

```jac
style dynamic {
    theme: str = "dark";
    prefix: str = "app";

    # Interpolated selector
    .#{prefix}-#{theme}-theme {
        background: #1e1e1e;
    }

    # Interpolated property
    .custom {
        #{f"background-{theme}"}: #333;
    }

    # Interpolated value
    .themed {
        color: #{theme == "dark" ? "#fff" : "#000"};
    }
}
```

### 5.8 Imports and Modularity

Use Jac's import system for styles:

```jac
# File: styles/colors.jac
style :pub colors {
    primary: "#007bff";
    secondary: "#6c757d";
    success: "#28a745";
    danger: "#dc3545";
}

# File: styles/mixins.jac
import from styles.colors { colors };

style :pub mixins {
    mixin button(bg: str) {
        background: bg;
        padding: 10px 20px;
        border-radius: 4px;
    }
}

# File: main.jac
import from styles.colors { colors };
import from styles.mixins { mixins };

style app {
    .primary-btn {
        include mixins.button(colors.primary);
    }
}
```

### 5.9 Media Queries

Support responsive design:

```jac
style responsive {
    .container {
        width: 100%;
        padding: 15px;

        # Media query using string selector
        "@media (min-width: 768px)" {
            max-width: 750px;
        }

        "@media (min-width: 992px)" {
            max-width: 970px;
        }

        "@media (min-width: 1200px)" {
            max-width: 1170px;
        }
    }
}
```

### 5.10 Animations and Keyframes

Define animations:

```jac
style animations {
    # Keyframe definition
    "@keyframes fadeIn" {
        "from" { opacity: 0; }
        "to" { opacity: 1; }
    }

    "@keyframes slideUp" {
        "0%" {
            transform: translateY(100%);
            opacity: 0;
        }
        "100%" {
            transform: translateY(0);
            opacity: 1;
        }
    }

    .fade-in {
        animation: fadeIn 0.3s ease-in;
    }

    .slide-up {
        animation: slideUp 0.5s cubic-bezier(0.4, 0, 0.2, 1);
    }
}
```

---

## 6. Examples

### 6.1 Complete Component with Styles

```jac
# File: components/button.jac

# Style definition
style :pub button_styles {
    primary_color: "#007bff";
    hover_darken: 0.1;

    mixin button_base {
        padding: 10px 20px;
        border: none;
        border-radius: 4px;
        cursor: pointer;
        font-size: 16px;
        transition: all 0.3s ease;

        &:hover {
            transform: translateY(-2px);
            box-shadow: 0 4px 8px rgba(0, 0, 0, 0.2);
        }

        &:active {
            transform: translateY(0);
        }

        &:disabled {
            opacity: 0.5;
            cursor: not-allowed;

            &:hover {
                transform: none;
                box-shadow: none;
            }
        }
    }

    .btn-primary {
        include button_base;
        background: primary_color;
        color: white;
    }

    .btn-secondary {
        include button_base;
        background: #6c757d;
        color: white;
    }

    .btn-outline {
        include button_base;
        background: transparent;
        border: 2px solid primary_color;
        color: primary_color;

        &:hover {
            background: primary_color;
            color: white;
        }
    }

    .btn-sm {
        extend .btn-primary;
        padding: 5px 10px;
        font-size: 14px;
    }

    .btn-lg {
        extend .btn-primary;
        padding: 15px 30px;
        font-size: 18px;
    }
}

# Component definition
obj Button {
    has text: str;
    has variant: str = "primary";
    has size: str = "md";
    has disabled: bool = false;
    has on_click: callable;

    def render() -> dict {
        let class_name: str = f"btn-{variant}";
        if size != "md" {
            class_name = f"{class_name} btn-{size}";
        }

        return <button
            class={class_name}
            disabled={disabled}
            onclick={on_click}
        >
            {text}
        </button>;
    }
}

with entry {
    let btn: Button = Button(
        text="Click Me",
        variant="primary",
        on_click=lambda: print("Clicked!")
    );

    print(btn.render());
}
```

### 6.2 Theming System

```jac
# File: themes/base.jac
style :pub theme_base {
    # Base variables
    font_family: "system-ui, -apple-system, sans-serif";
    base_size: 16;
    scale_ratio: 1.25;

    # Spacing
    spacing_unit: 8;

    # Colors (abstract - these will be implemented by themes)
    let color_primary: str;      # Use 'let' for abstract/uninitialized vars
    let color_secondary: str;
    let color_background: str;
    let color_text: str;
    let color_border: str;

    # Typography mixin
    mixin typography_base {
        font-family: font_family;
        font-size: f"{base_size}px";
        line-height: 1.5;
        color: color_text;
    }

    # Spacing utilities
    mixin spacing(size: int) {
        margin: f"{size * spacing_unit}px";
        padding: f"{size * spacing_unit}px";
    }
}

# File: themes/light.jac
import from themes.base { theme_base };

impl theme_base {
    color_primary: "#007bff";
    color_secondary: "#6c757d";
    color_background: "#ffffff";
    color_text: "#212529";
    color_border: "#dee2e6";
}

style :pub light_theme {
    extend theme_base;

    body {
        include theme_base.typography_base;
        background: theme_base.color_background;
    }

    .card {
        background: theme_base.color_background;
        border: 1px solid theme_base.color_border;
        border-radius: 4px;
        include theme_base.spacing(2);
    }
}

# File: themes/dark.jac
import from themes.base { theme_base };

impl theme_base {
    color_primary: "#0d6efd";
    color_secondary: "#6c757d";
    color_background: "#1e1e1e";
    color_text: "#f8f9fa";
    color_border: "#495057";
}

style :pub dark_theme {
    extend theme_base;

    body {
        include theme_base.typography_base;
        background: theme_base.color_background;
    }

    .card {
        background: #2d2d2d;
        border: 1px solid theme_base.color_border;
        border-radius: 4px;
        include theme_base.spacing(2);
    }
}
```

### 6.3 Utility-First Approach (Tailwind-like)

```jac
style :pub utilities {
    # Flexbox utilities
    .flex { display: flex; }
    .inline-flex { display: inline-flex; }
    .flex-row { flex-direction: row; }
    .flex-col { flex-direction: column; }
    .items-center { align-items: center; }
    .justify-center { justify-content: center; }
    .justify-between { justify-content: space-between; }
    .flex-1 { flex: 1; }

    # Spacing utilities (generated)
    sizes: list[int] = [0, 1, 2, 3, 4, 5, 6, 8, 10, 12, 16, 20, 24];

    for size in sizes {
        .m-{size} { margin: f"{size * 4}px"; }
        .mt-{size} { margin-top: f"{size * 4}px"; }
        .mr-{size} { margin-right: f"{size * 4}px"; }
        .mb-{size} { margin-bottom: f"{size * 4}px"; }
        .ml-{size} { margin-left: f"{size * 4}px"; }

        .p-{size} { padding: f"{size * 4}px"; }
        .pt-{size} { padding-top: f"{size * 4}px"; }
        .pr-{size} { padding-right: f"{size * 4}px"; }
        .pb-{size} { padding-bottom: f"{size * 4}px"; }
        .pl-{size} { padding-left: f"{size * 4}px"; }
    }

    # Color utilities
    colors: dict = {
        "primary": "#007bff",
        "secondary": "#6c757d",
        "success": "#28a745",
        "danger": "#dc3545",
        "warning": "#ffc107",
        "info": "#17a2b8"
    };

    for (name, color) in colors.items() {
        .text-{name} { color: color; }
        .bg-{name} { background-color: color; }
        .border-{name} { border-color: color; }
    }

    # Typography
    font_sizes: list[int] = [12, 14, 16, 18, 20, 24, 30, 36, 48];
    for (i, size) in enumerate(font_sizes) {
        .text-{i} { font-size: f"{size}px"; }
    }

    .font-bold { font-weight: bold; }
    .font-normal { font-weight: normal; }
    .font-light { font-weight: 300; }

    .text-center { text-align: center; }
    .text-left { text-align: left; }
    .text-right { text-align: right; }

    # Border utilities
    .border { border: 1px solid #dee2e6; }
    .border-0 { border: none; }
    .rounded { border-radius: 4px; }
    .rounded-full { border-radius: 9999px; }

    # Display utilities
    .block { display: block; }
    .inline-block { display: inline-block; }
    .inline { display: inline; }
    .hidden { display: none; }

    # Position utilities
    .relative { position: relative; }
    .absolute { position: absolute; }
    .fixed { position: fixed; }
    .sticky { position: sticky; }
}
```

### 6.4 Animation Library

```jac
style :pub animations {
    # Keyframes
    "@keyframes spin" {
        "from" { transform: rotate(0deg); }
        "to" { transform: rotate(360deg); }
    }

    "@keyframes pulse" {
        "0%, 100%" { opacity: 1; }
        "50%" { opacity: 0.5; }
    }

    "@keyframes bounce" {
        "0%, 100%" {
            transform: translateY(0);
            animation-timing-function: cubic-bezier(0.8, 0, 1, 1);
        }
        "50%" {
            transform: translateY(-25%);
            animation-timing-function: cubic-bezier(0, 0, 0.2, 1);
        }
    }

    "@keyframes fadeIn" {
        "from" { opacity: 0; }
        "to" { opacity: 1; }
    }

    "@keyframes slideInLeft" {
        "from" {
            transform: translateX(-100%);
            opacity: 0;
        }
        "to" {
            transform: translateX(0);
            opacity: 1;
        }
    }

    # Animation classes
    mixin animate(name: str, duration: str = "1s", timing: str = "ease") {
        animation-name: name;
        animation-duration: duration;
        animation-timing-function: timing;
    }

    .animate-spin {
        include animate("spin", "1s", "linear");
        animation-iteration-count: infinite;
    }

    .animate-pulse {
        include animate("pulse", "2s", "ease-in-out");
        animation-iteration-count: infinite;
    }

    .animate-bounce {
        include animate("bounce", "1s", "ease");
        animation-iteration-count: infinite;
    }

    .fade-in {
        include animate("fadeIn", "0.3s", "ease-in");
    }

    .slide-in-left {
        include animate("slideInLeft", "0.5s", "cubic-bezier(0.4, 0, 0.2, 1)");
    }

    # Transition utilities
    .transition-all {
        transition: all 0.3s ease;
    }

    .transition-colors {
        transition: background-color 0.3s ease, color 0.3s ease;
    }

    .transition-transform {
        transition: transform 0.3s ease;
    }
}
```

---

## 7. Implementation Roadmap

### Phase 1: Core Grammar and Parser (Weeks 1-2)

**Tasks:**
1. Add `KW_STYLE`, `KW_MIXIN` tokens to `constant.py`
2. Define grammar rules in `jac.lark`:
   - `style_def`, `style_block`, `style_stmt`
   - `style_rule`, `style_selector`, `style_declaration`
   - `style_variable`, `style_mixin_def`, `style_mixin_include`
3. Add AST nodes to `unitree.py`:
   - `StyleDef`, `StyleBlock`, `StyleStmt`, `StyleRule`
   - `StyleSelector`, `StyleDeclaration`, `StyleValue`
   - `StyleMixinDef`, `StyleMixinInclude`, `StyleVariable`
4. Update parser to handle style blocks
5. Write parser tests

**Deliverables:**
- Style blocks parse correctly
- AST structure validated
- 20+ parser tests passing

### Phase 2: Basic Renderer (Weeks 3-4)

**Tasks:**
1. Create `style_renderer_pass.py` in compiler passes
2. Implement CSS generation for:
   - Basic selectors and declarations
   - Nested selectors (flatten to CSS)
   - Variables (replace with values)
3. Handle parent selector (`&`) resolution
4. Generate valid CSS output
5. Write renderer tests

**Deliverables:**
- Basic style blocks render to CSS
- Nested selectors flatten correctly
- Variables resolve properly
- 30+ renderer tests passing

### Phase 3: Advanced Features (Weeks 5-6)

**Tasks:**
1. Implement mixins:
   - Mixin definition parsing
   - Mixin inclusion/expansion
   - Parameter support
2. Implement extend/inheritance:
   - Selector inheritance
   - Declaration merging
3. Add conditionals and loops:
   - `if`/`else` support in styles
   - `for` loop expansion
4. String interpolation:
   - `#{}` syntax parsing
   - Expression evaluation in selectors/values
5. Write advanced feature tests

**Deliverables:**
- Mixins work with parameters
- Extend creates proper inheritance
- Conditionals and loops generate correct CSS
- String interpolation resolves expressions
- 40+ advanced feature tests passing

### Phase 4: Formatter Integration (Week 7)

**Tasks:**
1. Add style formatting to `jac_formatter_pass.py`
2. Implement doc-IR for style blocks:
   - Selector formatting
   - Declaration alignment
   - Nested block indentation
3. Handle comments in styles
4. Preserve whitespace where appropriate
5. Write formatter tests

**Deliverables:**
- Styles format beautifully
- Nested structures indent properly
- Comments preserved
- 20+ formatter tests passing

### Phase 5: Tooling and IDE Support (Week 8)

**Tasks:**
1. Add semantic tokens for styles
2. Update LSP (Language Server Protocol) support:
   - Autocomplete for properties
   - Hover documentation
   - Syntax highlighting
3. Add style-specific linting rules
4. Create documentation and examples
5. Write tooling integration tests

**Deliverables:**
- IDE autocomplete works
- Syntax highlighting for styles
- Linting catches common errors
- Comprehensive documentation

### Phase 6: Import System and Modularity (Week 9)

**Tasks:**
1. Support importing styles across files
2. Implement style namespacing
3. Handle circular dependencies
4. Create standard library of common styles
5. Write import/module tests

**Deliverables:**
- Styles importable across files
- No namespace collisions
- Standard library available
- 25+ import tests passing

### Phase 7: Optimization and Production (Week 10)

**Tasks:**
1. Implement CSS minification
2. Add dead code elimination
3. Optimize selector specificity
4. Bundle styles efficiently
5. Create benchmarks
6. Write optimization tests

**Deliverables:**
- Minified CSS output option
- Unused styles removed
- Fast compilation times
- Production-ready renderer

### Phase 8: Documentation and Examples (Week 11-12)

**Tasks:**
1. Write comprehensive language guide
2. Create tutorial series
3. Build example applications:
   - Component library
   - Complete UI framework
   - Responsive website
4. Record demo videos
5. Create migration guide from CSS/SCSS

**Deliverables:**
- Full language documentation
- 5+ tutorials
- 3+ example projects
- Migration guide

---

## 8. Renderer Architecture

### 8.1 Overview

The JacStyle renderer transforms style AST into CSS output:

```
JacStyle AST → Style Renderer Pass → CSS AST → CSS Code Generator → CSS Text
```

### 8.2 Renderer Components

```python
# File: jac/jaclang/compiler/passes/style/style_renderer_pass.py

class StyleRendererPass(Pass):
    """Renders JacStyle AST to CSS."""

    def __init__(self, target: str = "css", minify: bool = False):
        self.target = target  # "css", "scss", "json"
        self.minify = minify
        self.variables: dict[str, Any] = {}
        self.mixins: dict[str, StyleMixinDef] = {}
        self.output: list[str] = []

    def enter_style_def(self, node: StyleDef) -> None:
        """Process style definition."""
        self.current_context = StyleContext(name=node.name.value)

    def exit_style_def(self, node: StyleDef) -> None:
        """Finalize style processing."""
        css = self.generate_css()
        self.output.append(css)

    def enter_style_variable(self, node: StyleVariable) -> None:
        """Register variable."""
        value = self.eval_expression(node.value)
        self.variables[node.name.value] = value

    def enter_style_mixin_def(self, node: StyleMixinDef) -> None:
        """Register mixin."""
        self.mixins[node.name.value] = node

    def enter_style_rule(self, node: StyleRule) -> None:
        """Process rule."""
        selectors = self.render_selectors(node.selectors)
        declarations = self.render_declarations(node.declarations)

        self.current_context.add_rule(
            selectors=selectors,
            declarations=declarations
        )

    def render_selectors(self, selectors: list[StyleSelector]) -> list[str]:
        """Render selectors with parent resolution."""
        result = []
        for selector in selectors:
            parts = []
            for part in selector.parts:
                if isinstance(part, StyleParentRef):
                    parts.append(self.current_context.parent_selector or "")
                elif isinstance(part, StyleSimpleSelector):
                    parts.append(self.resolve_interpolation(part.value))
                elif isinstance(part, StyleCombinator):
                    parts.append(f" {part.value} ")
            result.append("".join(parts))
        return result

    def render_declarations(self, declarations: list[StyleDeclaration | StyleRule]) -> dict[str, str]:
        """Render property: value declarations."""
        result = {}
        for decl in declarations:
            if isinstance(decl, StyleDeclaration):
                prop = self.resolve_interpolation(decl.property)
                values = [self.render_value(v) for v in decl.values]
                result[prop] = " ".join(values)
            elif isinstance(decl, StyleRule):
                # Nested rule - process recursively
                self.enter_style_rule(decl)
        return result

    def render_value(self, value: StyleValue) -> str:
        """Render CSS value."""
        if isinstance(value, StyleValueText):
            return value.value
        elif isinstance(value, StyleValueFunction):
            args = ", ".join(self.render_value(arg) for arg in value.args)
            return f"{value.name}({args})"
        elif isinstance(value, StyleValueExpression):
            return str(self.eval_expression(value.expr))
        elif isinstance(value, StyleInterpolation):
            return str(self.eval_expression(value.expr))

    def resolve_interpolation(self, value: str | StyleInterpolation) -> str:
        """Resolve #{} interpolations."""
        if isinstance(value, StyleInterpolation):
            return str(self.eval_expression(value.expr))
        return value

    def eval_expression(self, expr: Expr) -> Any:
        """Evaluate Jac expression to value."""
        # Use Jac's expression evaluator
        evaluator = ExpressionEvaluator(context=self.current_context)
        return evaluator.eval(expr)

    def expand_mixin(self, include: StyleMixinInclude) -> list[StyleDeclaration]:
        """Expand mixin inclusion."""
        mixin = self.mixins.get(include.name.value)
        if not mixin:
            raise StyleError(f"Mixin not found: {include.name.value}")

        # Bind parameters
        params = self.bind_parameters(mixin.params, include.args)

        # Evaluate declarations with bound parameters
        with self.scoped_context(params):
            return [self.eval_declaration(decl) for decl in mixin.body]

    def generate_css(self) -> str:
        """Generate final CSS output."""
        rules = []
        for rule in self.current_context.rules:
            selectors = ", ".join(rule.selectors)
            declarations = []
            for prop, value in rule.declarations.items():
                declarations.append(f"  {prop}: {value};")

            if self.minify:
                rules.append(f"{selectors}{{{';'.join(d.strip() for d in declarations)}}}")
            else:
                decls = "\n".join(declarations)
                rules.append(f"{selectors} {{\n{decls}\n}}")

        return "\n\n".join(rules)


class StyleContext:
    """Context for style rendering."""

    def __init__(self, name: str, parent: Optional["StyleContext"] = None):
        self.name = name
        self.parent = parent
        self.parent_selector: Optional[str] = None
        self.rules: list[StyleRuleOutput] = []
        self.variables: dict[str, Any] = {}

    def add_rule(self, selectors: list[str], declarations: dict[str, str]) -> None:
        self.rules.append(StyleRuleOutput(selectors, declarations))


@dataclass
class StyleRuleOutput:
    """Output CSS rule."""
    selectors: list[str]
    declarations: dict[str, str]
```

### 8.3 Output Formats

**CSS (Default):**
```css
.button {
  padding: 10px 20px;
  background: #007bff;
  color: white;
}

.button:hover {
  opacity: 0.9;
}
```

**Minified CSS:**
```css
.button{padding:10px 20px;background:#007bff;color:white}.button:hover{opacity:0.9}
```

**JSON (for programmatic use):**
```json
{
  "styles": [
    {
      "selector": ".button",
      "declarations": {
        "padding": "10px 20px",
        "background": "#007bff",
        "color": "white"
      }
    },
    {
      "selector": ".button:hover",
      "declarations": {
        "opacity": "0.9"
      }
    }
  ]
}
```

**SCSS (intermediate):**
```scss
.button {
  padding: 10px 20px;
  background: #007bff;
  color: white;

  &:hover {
    opacity: 0.9;
  }
}
```

### 8.4 CLI Integration

```bash
# Compile styles to CSS
jac style compile app.jac --output app.css

# Minify output
jac style compile app.jac --output app.min.css --minify

# Watch for changes
jac style watch app.jac --output app.css

# Generate JSON
jac style compile app.jac --output app.json --format json

# Extract styles from module
jac style extract app.jac --style-name theme --output theme.css
```

---

## 9. Appendix

### 9.1 Token Reference

| Token | Symbol | Description |
|-------|--------|-------------|
| `KW_STYLE` | `style` | Style definition keyword |
| `KW_MIXIN` | `mixin` | Mixin definition keyword |
| `KW_INCLUDE` | `include` | Mixin inclusion keyword |
| `KW_EXTEND` | `extend` | Selector inheritance keyword |
| `BW_AND` | `&` | Parent selector reference |
| `STYLE_INTERP_START` | `#{` | Interpolation start |
| `STYLE_INTERP_END` | `}` | Interpolation end |
| `COLON` | `:` | Property separator |
| `SEMI` | `;` | Statement terminator |
| `LBRACE` | `{` | Block start |
| `RBRACE` | `}` | Block end |
| `COMMA` | `,` | Value separator |

### 9.2 Selector Syntax Reference

| Selector | Example | Description |
|----------|---------|-------------|
| Element | `div` | Element type |
| Class | `.btn` | Class name |
| ID | `#header` | ID attribute |
| Attribute | `[disabled]` | Attribute presence |
| Attribute = | `[type="text"]` | Attribute value |
| Attribute ~= | `[class~="active"]` | Attribute contains word |
| Attribute \|= | `[lang\|="en"]` | Attribute starts with |
| Attribute ^= | `[href^="https"]` | Attribute prefix |
| Attribute $= | `[href$=".pdf"]` | Attribute suffix |
| Attribute *= | `[href*="example"]` | Attribute substring |
| Descendant | `.parent .child` | Descendant combinator |
| Child | `.parent > .child` | Child combinator |
| Adjacent | `h1 + p` | Adjacent sibling |
| Sibling | `h1 ~ p` | General sibling |
| Pseudo-class | `a:hover` | Pseudo-class |
| Pseudo-element | `p::first-line` | Pseudo-element |
| Multiple | `.btn.primary` | Multiple conditions |

### 9.3 Property Reference (Common)

**Layout:**
- `display`, `position`, `top`, `right`, `bottom`, `left`
- `width`, `height`, `max-width`, `min-height`, etc.
- `margin`, `padding`, `border`
- `overflow`, `z-index`, `float`, `clear`

**Flexbox:**
- `flex`, `flex-direction`, `flex-wrap`, `flex-flow`
- `justify-content`, `align-items`, `align-content`, `align-self`
- `order`, `flex-grow`, `flex-shrink`, `flex-basis`

**Grid:**
- `grid-template-columns`, `grid-template-rows`, `grid-template-areas`
- `grid-column`, `grid-row`, `grid-area`
- `gap`, `row-gap`, `column-gap`

**Typography:**
- `font-family`, `font-size`, `font-weight`, `font-style`
- `line-height`, `letter-spacing`, `text-align`, `text-decoration`
- `text-transform`, `white-space`, `word-wrap`

**Colors:**
- `color`, `background`, `background-color`, `background-image`
- `opacity`, `border-color`

**Transforms & Animations:**
- `transform`, `transition`, `animation`
- `transform-origin`, `transition-duration`, `animation-delay`

### 9.4 Function Reference (CSS)

**Colors:**
- `rgb(r, g, b)`, `rgba(r, g, b, a)`
- `hsl(h, s, l)`, `hsla(h, s, l, a)`
- `color-mix(method, color1, color2)`

**Gradients:**
- `linear-gradient(direction, color-stops)`
- `radial-gradient(shape, color-stops)`
- `conic-gradient(from angle, color-stops)`

**Transforms:**
- `translate(x, y)`, `translateX(x)`, `translateY(y)`, `translateZ(z)`
- `scale(x, y)`, `scaleX(x)`, `scaleY(y)`
- `rotate(angle)`, `rotateX(angle)`, `rotateY(angle)`, `rotateZ(angle)`
- `skew(x, y)`, `skewX(angle)`, `skewY(angle)`
- `matrix(a, b, c, d, e, f)`, `matrix3d(...)`

**Math:**
- `calc(expression)`
- `min(value1, value2, ...)`, `max(value1, value2, ...)`
- `clamp(min, val, max)`

**Filters:**
- `blur(radius)`, `brightness(amount)`, `contrast(amount)`
- `grayscale(amount)`, `hue-rotate(angle)`, `invert(amount)`
- `opacity(amount)`, `saturate(amount)`, `sepia(amount)`

**Other:**
- `url(path)`, `attr(attribute)`, `var(--custom-property)`

### 9.5 Comparison: CSS vs SCSS vs JacStyle

| Feature | CSS | SCSS | JacStyle |
|---------|-----|------|----------|
| Nesting | ❌ | ✅ | ✅ |
| Variables | Limited (`--var`) | ✅ (`$var`) | ✅ (`let var`) |
| Mixins | ❌ | ✅ (`@mixin`) | ✅ (`mixin`) |
| Extend | ❌ | ✅ (`@extend`) | ✅ (`extend`) |
| Conditionals | ❌ | ✅ (`@if`) | ✅ (`if`) |
| Loops | ❌ | ✅ (`@for`, `@each`) | ✅ (`for`) |
| Functions | Limited | ✅ (`@function`) | ✅ (Jac functions) |
| Imports | ✅ (`@import`) | ✅ (`@import`) | ✅ (`import`) |
| Math | `calc()` only | ✅ (operators) | ✅ (Jac expressions) |
| Type Safety | ❌ | ❌ | ✅ (Jac types) |
| Interpolation | ❌ | ✅ (`#{}`) | ✅ (`#{}`) |
| Parent Ref | ❌ | ✅ (`&`) | ✅ (`&`) |
| Namespacing | ❌ | Limited | ✅ (Jac modules) |
| IDE Support | ✅ | ✅ | ✅ (native) |

### 9.6 Best Practices

**1. When to Use `let` for Variables:**

```jac
style theme {
    # Omit 'let' for simple value assignments (CSS-style)
    primary_color: "#007bff";
    spacing: 10;
    font_size: 16;

    # Use 'let' for type-annotated variables without initialization
    let custom_property: str;  # Will be set elsewhere
    let computed_value: int;

    # Use 'let' for complex types when clarity helps
    let theme_config: dict = {
        "colors": {...},
        "spacing": {...}
    };

    # Mixing both is fine - choose what's clearest
    base_color: "#000";
    let derived_color: str = compute_color(base_color);
}
```

**Best practice**: Omit `let` for simple variables (most cases), use it when type annotation adds clarity or for uninitialized declarations.

**2. Organization:**
```jac
# Organize styles by concern
import from styles.variables { theme_vars };
import from styles.mixins { common_mixins };
import from styles.components { button, card, modal };
import from styles.layouts { grid, flex };
import from styles.utilities { spacing, colors };
```

**3. Naming Conventions:**
```jac
# Use kebab-case for selectors
.primary-button { ... }
.user-profile-card { ... }

# Use snake_case for variables and mixins
primary_color: "#007bff";
mixin flex_center() { ... }
```

**4. Specificity Management:**
```jac
# Prefer classes over IDs
.header { ... }  # Good
#header { ... }  # Avoid

# Keep nesting shallow (max 3 levels)
.card {
    .card-header {
        .card-title { ... }  # OK
    }
}
```

**5. Reusability:**
```jac
# Extract common patterns to mixins
mixin button_base {
    padding: 10px 20px;
    border-radius: 4px;
    cursor: pointer;
}

# Use variables for theming
colors: dict = {
    "primary": "#007bff",
    "secondary": "#6c757d"
};
```

**6. Performance:**
```jac
# Minimize output size
style :priv internal { ... }  # Won't be exported

# Use conditionals to reduce unused code
if enable_animations {
    .animate { ... }
}
```

### 9.7 Migration from SCSS

**SCSS:**
```scss
$primary-color: #007bff;
$border-radius: 4px;

@mixin button-base {
  padding: 10px 20px;
  border-radius: $border-radius;
  cursor: pointer;
}

.button {
  @include button-base;
  background: $primary-color;

  &:hover {
    opacity: 0.9;
  }

  &.large {
    padding: 15px 30px;
  }
}
```

**JacStyle (Option 1 - CSS-style, no `let`):**
```jac
primary_color: "#007bff";
border_radius: 4;

mixin button_base {
    padding: 10px 20px;
    border-radius: f"{border_radius}px";
    cursor: pointer;
}

.button {
    include button_base;
    background: primary_color;

    &:hover {
        opacity: 0.9;
    }

    &.large {
        padding: 15px 30px;
    }
}
```

**JacStyle (Option 2 - Explicit with `let`):**
```jac
let primary_color: "#007bff";
let border_radius: 4;

mixin button_base {
    padding: 10px 20px;
    border-radius: f"{border_radius}px";
    cursor: pointer;
}

.button {
    include button_base;
    background: primary_color;

    &:hover {
        opacity: 0.9;
    }

    &.large {
        padding: 15px 30px;
    }
}
```

**Key Differences:**
- `$variable` → `variable` or `let variable` (both work!)
- `@mixin` → `mixin`
- `@include` → `include`
- `@extend` → `extend`
- `@if/@else` → `if/else`
- `@for/@each` → `for`
- `#{}` interpolation → Same!
- `&` parent ref → Same!
- Units: SCSS has implicit units (4px), Jac uses f-strings: `f"{4}px"`

### 9.8 Future Extensions

**CSS Modules Integration:**
```jac
style :pub button :module {  # Generate scoped class names
    .primary { ... }  # → .button__primary__a8s9d
}
```

**CSS-in-JS Output:**
```jac
# Generate JavaScript objects
style button :export="js" {
    .primary { ... }
}

# Outputs:
# export const button_primary = {
#   background: '#007bff',
#   color: 'white'
# };
```

**Atomic CSS:**
```jac
style :atomic utilities {  # Generate minimal atomic classes
    .text-center { text-align: center; }
}
```

**Design Tokens:**
```jac
style :tokens theme {
    colors: dict = {
        "primary": "#007bff",
        "secondary": "#6c757d"
    };
}

# Export to JSON, YAML, or other formats
```

---

## Conclusion

JacStyle represents a significant enhancement to the Jac programming language, bringing native CSS-inspired styling capabilities directly into the language grammar. By leveraging Jac's existing token system, type safety, and modularity features, JacStyle provides a powerful, expressive, and developer-friendly way to manage styles alongside application logic.

The proposal outlined here provides:
- **Clear syntax** inspired by CSS/SCSS but using Jac semantics
- **Comprehensive features** including variables, mixins, nesting, conditionals, and loops
- **Type-safe integration** with Jac's type system
- **Practical examples** demonstrating real-world usage
- **Detailed implementation roadmap** for development
- **Extensible architecture** for future enhancements

With JacStyle, developers can build complete applications—components, logic, and styles—in a single, cohesive language, unlocking new possibilities for code reuse, tooling, and developer productivity.

---

**Next Steps:**
1. Review and refine this proposal with the Jac core team
2. Prototype grammar changes and AST nodes
3. Implement basic renderer for validation
4. Gather community feedback
5. Proceed with full implementation per roadmap

---

**Document Version History:**
- v1.0 (2025-10-18): Initial proposal
- v1.1 (2025-10-18): Made `let` keyword optional for style variables to improve CSS/SCSS familiarity
