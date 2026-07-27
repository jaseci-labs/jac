# `jac ninja`

(You found the dojo.)

`jac ninja` opens a complete, jac-native code editor that is **already inside the `jac` binary**. There is nothing to install, nothing to configure, and no plugin manager to babysit -- the editor, the Jac parser, and the Jac language server are literally the same file on disk.

```bash
jac ninja main.jac
```

A hard-forked [Neovim](https://neovim.io/) is statically linked into the binary's launcher stub, so the editor boots in milliseconds without ever starting Python. Python spins up only when the editor needs a language server -- and the language server it spawns is `jac lsp`, the very binary you launched. Editor, compiler, and LSP never drift out of sync, because there is only one of them.

!!! note "One binary, the whole workflow"
    Everything `jac ninja` does -- syntax highlighting, completion, go-to-definition, running your file, type-checking it, and even the AI coding agent -- is served by the same `jac` executable. See [One Binary, Build Anything](../quick-guide/one-binary.md) for the philosophy behind this.

---

## Requirements

`jac ninja` ships in the **self-contained `jac` binary** (the release download, or a `zig build` of the repo). If you installed Jac as a plain Python package (`pip install jaclang`), there is no bundled editor and `jac ninja` will tell you so:

```
jac ninja is fused into the self-contained jac binary (the launcher
dispatches it before Python ever starts). This jaclang is running as a
plain Python package, which has no bundled editor -- install the jac
binary release to use it.
```

Grab the binary from [the install guide](../quick-guide/install.md) and you're set. If you'd rather stay in VS Code, Cursor, or another IDE, the [Jac Language Support extension](../quick-guide/install.md#ide-setup) speaks to the same `jac lsp` server.

---

## Launching

| Command | What it does |
|---|---|
| `jac ninja` | Opens the start screen (recent files + actions) |
| `jac ninja main.jac` | Opens a file |
| `jac ninja src/a.jac src/b.jac` | Opens several files as buffers |
| `jac ninja .` | Opens the file explorer at the current directory |

Arguments are passed straight through to the editor, so anything you'd normally hand a Neovim-style editor works.

The **leader key is `<Space>`**. Nearly every jac-specific action starts with it. If you press `<Space>` and pause for a moment, a hint window pops up showing every key that can follow -- you never need to memorize the table at the bottom of this page.

---

## Your first five minutes

Let's walk through a real edit-check-run loop. Create a project and open it:

```bash
jac create hello && cd hello
jac ninja
```

You'll land on the start screen. From here:

**1. Open a file.** Press `<Space>` `f` `f` (*find files*), type a few letters of the filename, and hit `<Enter>`. This is a fuzzy picker -- `mn` will find `main.jac`.

**2. Edit it.** The editor starts in **normal mode**, where keys are commands, not text. Press `i` to start typing, and `<Esc>` to stop. (If that's new to you, read [Modal editing in 60 seconds](#modal-editing-in-60-seconds) below before going further.)

Add a deliberate mistake so we have something to find:

```jac
def greet(name: str) -> str {
    return "Hello, " + nam;
}

with entry {
    print(greet("world"));
}
```

**3. Watch the diagnostics.** The moment you stop typing, `jac lsp` analyzes the buffer and flags `nam` in the sign column and inline. Put the cursor on it and press `<Space>` `d` to read the full message in a floating window.

**4. Fix it with language intelligence.** Fix the typo to `name`, then park the cursor on `greet` and press `K` to see its signature, or `g` `d` to jump to its definition. `<Space>` `l` `f` formats the whole buffer through `jac fmt`.

**5. Type-check the file.** Press `<Space>` `j` `c`. This runs `jac check` asynchronously and does two things: it drops the raw compiler output into a panel at the bottom, and it loads every error into the **quickfix list**. Jump between problems with `]` `q` and `[` `q`, or open the full list with `:copen`. A clean run just says `jac check: passed`.

**6. Run it.** Press `<Space>` `j` `r`. A terminal split opens at the bottom and runs `jac run` on the current file with the same binary. To leave the terminal, press `<Esc>` `<Esc>` (that's the escape hatch out of terminal mode), then `<C-w>` `q` to close the split.

**7. Ask the agent.** Press `<Space>` `a` `a` to open a `jac ai` session in a side panel, or `<Space>` `a` `d` to hand the current file's diagnostics straight to the agent and let it fix them.

That's the whole loop: **find, edit, check, run, ask** -- without leaving the editor and without a single external tool.

---

## Modal editing in 60 seconds

`jac ninja` is a modal editor: the keyboard means different things depending on the mode you're in. This is the one concept that trips up newcomers, and it takes about a minute to internalize.

| Mode | How you get there | What keys do |
|---|---|---|
| **Normal** | `<Esc>` (you start here) | Navigate and run commands |
| **Insert** | `i` | Type text, like any other editor |
| **Visual** | `v` | Select text |
| **Command** | `:` | Run an editor command, e.g. `:w` |

The survival kit -- enough to be productive today:

| Keys | Action |
|---|---|
| `i` / `<Esc>` | Start typing / stop typing |
| `h` `j` `k` `l` | Left, down, up, right (arrow keys also work) |
| `w` / `b` | Forward / back one word |
| `gg` / `G` | Top / bottom of file |
| `x` / `dd` / `yy` / `p` | Delete char / delete line / copy line / paste |
| `u` / `<C-r>` | Undo / redo |
| `/text` then `<Enter>` | Search; `n` for next, `<Esc>` to clear the highlight |
| `<Space>` `w` | Save |
| `<Space>` `q` | Quit (prompts if you have unsaved work) |

The mouse works too (`mouse=a` is on), so you can click, drag-select, and scroll while your fingers catch up.

!!! tip "Let the editor teach you"
    Press `<Space>` and wait -- a hint window lists every available follow-up key with a description. The same works for `g`, `[`, `]`, `"`, `'`, and `<C-w>`. It's the fastest way to learn the keymap without reading docs.

---

## Moving around a codebase

Pickers are fuzzy-matched, live-filtered lists. All of them use the same keys: type to filter, `<C-n>` / `<C-p>` to move, `<Enter>` to choose, `<C-v>` / `<C-s>` to open in a vertical/horizontal split, and `<Esc>` to cancel.

| Keys | Picker |
|---|---|
| `<Space>` `f` `f` | Find files |
| `<Space>` `f` `g` | Live grep across the project |
| `<Space>` `f` `b` | Open buffers |
| `<Space>` `f` `d` | Diagnostics |
| `<Space>` `f` `h` | Help topics |
| `<Space>` `f` `r` | Resume the last picker where you left it |

**The file explorer** opens with `<Space>` `e` (focused on the current file) or `-` (at the working directory). It is a *buffer*, not a widget -- you navigate it with `l` to enter a directory and `h` to go back up, and you create, rename, and delete files by **editing the text** and pressing `=` to apply your changes to disk. Press `g?` inside the explorer for its full key list, and `q` to close it.

**Tree-sitter text objects** understand Jac's grammar, so you can operate on structures rather than lines:

| Keys | Selects |
|---|---|
| `v` `a` `f` / `v` `i` `f` | A whole function / just its body |
| `v` `a` `c` / `v` `i` `c` | A whole object or node / just its body |
| `v` `a` `o` / `v` `i` `o` | A block / its contents |

They compose with operators, so `d` `a` `f` deletes a function and `y` `i` `c` copies an object's body. Folding is tree-sitter driven too (`z` `a` toggles a fold; `z` `M` folds everything).

---

## Language intelligence

The LSP client attaches automatically to every `.jac` buffer and is served by `jac lsp` from the same binary. Completion appears as you type (`<C-n>` / `<C-p>` to move through it, `<C-y>` to accept, `<C-e>` to dismiss).

| Keys | Action |
|---|---|
| `K` | Hover documentation |
| `g` `d` / `g` `D` | Go to definition / declaration |
| `g` `r` `r` | Find references |
| `g` `r` `i` | Go to implementation |
| `<Space>` `l` `r` (or `g` `r` `n`) | Rename symbol across the project |
| `<Space>` `l` `a` (or `g` `r` `a`) | Code actions |
| `<Space>` `l` `f` | Format buffer |
| `<Space>` `l` `s` / `<Space>` `l` `w` | Document symbols / workspace symbols |
| `<Space>` `d` | Show the diagnostics on this line |
| `]` `d` / `[` `d` | Next / previous diagnostic |

---

## Running Jac from inside the editor

These commands shell out to the same binary that's running the editor, in a terminal split at the bottom of the screen.

| Keys | Runs |
|---|---|
| `<Space>` `j` `r` | `jac run <current file>` |
| `<Space>` `j` `t` | `jac test <current file>` |
| `<Space>` `j` `d` | `jac dot <current file>` -- graph visualization |
| `<Space>` `j` `c` | `jac check <current file>` |
| `<Space>` `j` `C` | `jac check` on the whole project |
| `<Space>` `j` `o` | Toggle the last check-output panel |

The first four need a real `.jac` file in focus; from the start screen or the explorer they'll politely tell you to open one first.

### The check → quickfix loop

`<Space>` `j` `c` is worth calling out, because it turns the compiler into a worklist. It runs `jac check` in the background and, when it finishes:

- the **raw output panel** appears at the bottom, with the full diagnostic context -- inline code snippets, `^^^` markers, and the `jac guide` hints the compiler emits;
- the **quickfix list** is populated with one entry per diagnostic, so `]` `q` and `[` `q` walk you from error to error, jumping the cursor to the exact line and column;
- a **summary** is flashed as a notification: `jac check: 2 error(s), 1 warning(s)`.

Open the quickfix list as a navigable window with `:copen` (and `:cclose` to dismiss it). Toggle the raw output panel with `<Space>` `j` `o` at any time. Warnings are always included -- the editor runs `jac check --no-nowarn` so nothing is hidden from you.

---

## The coding agent

`<Space>` `a` opens the agent menu. It drives [`jac ai`](cli/index.md#jac-ai) -- the binary's own coding agent -- inside managed side panels.

The design is deliberate: the editor sends the agent **references, not code**. When you ask about a selection, it transmits the file path, the line range, and any diagnostics -- then `jac ai` reads the code itself with its own file tools. Nothing is pasted into a prompt, so the agent always sees the real, current file.

| Keys | Action |
|---|---|
| `<Space>` `a` `a` | Toggle the agent panel (starts a session on first use) |
| `<Space>` `a` `q` | Ask the agent anything |
| `<Space>` `a` `f` | Ask about the current file |
| `<Space>` `a` `d` | Send this buffer's diagnostics and ask for a fix |
| `<Space>` `a` `s` *(visual)* | Ask about the selected lines |
| `<Space>` `a` `e` *(visual)* | Explain the selected lines |
| `<Space>` `a` `n` | Start a new **named** session |
| `<Space>` `a` `l` | Pick from live sessions |
| `<Space>` `a` `m` | Set the model for new sessions |
| `<Space>` `a` `x` | Toggle `--safe` mode for new sessions |

Sessions are named and independent -- keep a `refactor` session and a `tests` session open side by side, each with its own history, and switch between them with `<Space>` `a` `l`.

!!! note "Model and safe-mode changes apply to *new* sessions"
    `<Space>` `a` `m` and `<Space>` `a` `x` set the flags used when the next agent process starts; they don't reconfigure a session that's already running. Toggle the panel closed and open a new session to pick them up. Leaving the model empty falls back to the default in your `jac.toml`.

You can also drive the agent from the command line: `:NinjaAgent [name]` toggles a session, and `:NinjaAgentSend <text>` sends a request into it.

---

## Themes

The stock look is `jac-ninja` -- a dark scheme with the Jaseci orange accent. Ten curated [base16](https://github.com/tinted-theming/schemes) schemes ship alongside it:

| Dark | Light |
|---|---|
| `catppuccin-mocha`, `dracula`, `gruvbox-dark-medium`, `everforest-dark-medium`, `nord`, `tokyo-night-storm`, `monokai` | `catppuccin-latte`, `one-light`, `solarized-light` |

Switch with the fuzzy picker (`<Space>` `t`) or by name:

```vim
:Theme dracula
```

Because every scheme goes through base16, your LSP diagnostics, tree-sitter highlights, and all the editor chrome recolor together. Themes apply to the current session; set one at the top of a [custom config](#customizing-the-editor) to make it stick.

---

## Where your state lives

`jac ninja` is **hermetic**. It launches with `-u <payload>/nvim/ninja/init.lua` and `NVIM_APPNAME=jac-ninja`, which means:

- your own Neovim configuration is **never read**, and can never break the jac experience;
- your own Neovim state is never touched;
- everything the editor persists -- undo history, recent files, logs -- is isolated under `~/.local/share/jac-ninja` and `~/.local/state/jac-ninja`.

Uninstalling is deleting the binary. Resetting the editor to factory state is deleting those two directories.

---

## Customizing the editor

The editor's entire configuration is one Lua layer in the jac source tree (`jac/editor/ninja/`), and it supports a live dev loop -- **no rebuild required**.

Point a project's `jac.toml` at a jac source checkout:

```toml
[dev]
jaclang_source = "/path/to/jaseci/jac"
```

Now `jac ninja` serves its config from `<source>/editor/ninja/init.lua` instead of the copy baked into the binary. Edit `init.lua` (or anything under `lua/ninja/`), relaunch, and your change is live. This is exactly the same linked-source mechanism the compiler uses, so if you already dev-link the compiler, the editor comes along for free.

Builds made with `zig build -Ddev` bake the link in directly, and take precedence over `jac.toml`. Set `JAC_NO_DEV_SOURCE=1` to force both off and use the binary's own copy.

A rebuild is only needed when the Neovim fork, the bundled parsers, or the pinned dependencies change.

---

## Environment variables

| Variable | Effect |
|---|---|
| `JAC_NINJA_ASCII=1` | Use plain ASCII for icons and diagnostic signs -- set this for terminals without a Nerd Font |
| `JAC_NO_DEV_SOURCE=1` | Ignore linked-source overrides; always use the config baked into the binary |

The launcher sets `JAC_BIN`, `JAC_NINJA_DIR`, `JAC_NINJA_BASE`, `VIMRUNTIME`, and `NVIM_APPNAME` for the editor and its children. You shouldn't need to touch them.

---

## Commands

| Command | Action |
|---|---|
| `:Theme <name>` | Switch color scheme (tab-completes) |
| `:NinjaAgent [name]` | Toggle an agent session |
| `:NinjaAgentSend <text>` | Send a request to the agent |
| `:JacCheckOutput` | Toggle the `jac check` output panel |
| `:copen` / `:cclose` | Open / close the quickfix list |
| `:w` / `:q` / `:wq` | Write / quit / write and quit |

---

## Keymap reference

Leader is `<Space>`.

### Editor

| Keys | Action |
|---|---|
| `<Space>` `w` | Write |
| `<Space>` `q` | Quit (confirms unsaved changes) |
| `<Esc>` | Clear search highlight |
| `<Esc>` `<Esc>` | Leave terminal mode |
| `<C-h>` `<C-j>` `<C-k>` `<C-l>` | Move focus between windows |

### Find

| Keys | Action |
|---|---|
| `<Space>` `f` `f` | Find files |
| `<Space>` `f` `g` | Live grep |
| `<Space>` `f` `b` | Buffers |
| `<Space>` `f` `d` | Diagnostics |
| `<Space>` `f` `h` | Help tags |
| `<Space>` `f` `r` | Resume last picker |
| `<Space>` `e` | File explorer, at the current file |
| `-` | File explorer, at the working directory |

### LSP

| Keys | Action |
|---|---|
| `K` | Hover |
| `g` `d` / `g` `D` | Definition / declaration |
| `g` `r` `r` / `g` `r` `i` | References / implementation |
| `<Space>` `l` `r` | Rename |
| `<Space>` `l` `a` | Code action |
| `<Space>` `l` `f` | Format |
| `<Space>` `l` `s` / `<Space>` `l` `w` | Document / workspace symbols |
| `<Space>` `d` | Line diagnostics |
| `]` `d` / `[` `d` | Next / previous diagnostic |

### Jac

| Keys | Action |
|---|---|
| `<Space>` `j` `r` | `jac run` this file |
| `<Space>` `j` `t` | `jac test` this file |
| `<Space>` `j` `d` | `jac dot` this file |
| `<Space>` `j` `c` | `jac check` this file |
| `<Space>` `j` `C` | `jac check` the project |
| `<Space>` `j` `o` | Toggle check output |

### Agent

| Keys | Action |
|---|---|
| `<Space>` `a` `a` | Toggle session |
| `<Space>` `a` `q` | Ask |
| `<Space>` `a` `f` | Ask about this file |
| `<Space>` `a` `d` | Fix diagnostics |
| `<Space>` `a` `s` / `a` `e` *(visual)* | Ask about / explain selection |
| `<Space>` `a` `n` / `a` `l` | New named session / pick session |
| `<Space>` `a` `m` / `a` `x` | Set model / toggle `--safe` |

### Theme

| Keys | Action |
|---|---|
| `<Space>` `t` | Pick a theme |

---

## Troubleshooting

**Icons render as boxes or question marks.** Your terminal font has no glyphs for them. Either install a [Nerd Font](https://www.nerdfonts.com/), or turn them off:

```bash
JAC_NINJA_ASCII=1 jac ninja
```

**`jac ninja` reports there's no bundled editor.** You're running Jac as a pip-installed Python package. Install the [self-contained binary](../quick-guide/install.md) instead.

**No completion or diagnostics in a `.jac` file.** The language server attaches at the project root, which it finds by looking for `jac.toml` or `.git`. Launch the editor from inside your project, and check that `:checkhealth lsp` lists a running `jac` client.

**I'm stuck in a mode and nothing works.** Press `<Esc>` a couple of times to get back to normal mode. From a terminal split, that's `<Esc>` `<Esc>`.

---

## See also

- [CLI Commands](cli/index.md) -- the full `jac` command surface
- [Install](../quick-guide/install.md) -- getting the binary, and IDE extensions for VS Code and friends
- [One Binary, Build Anything](../quick-guide/one-binary.md) -- why everything is fused into one file
- [`jac ai`](cli/index.md#jac-ai) -- the coding agent, on its own
