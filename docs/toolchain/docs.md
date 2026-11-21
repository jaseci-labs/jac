---
description: jac docs and jac skills - the map of the pages, a section, a page, what a word names, search, the pages served to a browser with --serve, --json, --path and --check, where the pages are, and listing, printing and installing skills.
keywords: documentation, jac docs, docs search, skill, skills install, SKILL.md, nav.json
---
# docs and skills

`jac docs` prints this documentation. The pages ship with jac, for its own version, so what they say is what the jac you run does, and reading them needs no network. `jac skills` prints playbooks for common tasks, written for agents, and installs them into a project.

```sh
jac docs                     # the map: every section and its pages
jac docs section basics      # a section's pages, each with what it covers
jac docs language/walkers    # one page
jac docs visit               # the page that defines a word
jac docs E1307               # what an error code means, and the fix
jac docs search edge filter  # the pages that mention a text
jac docs --serve             # the pages, in a browser
jac skills                   # the skills
```

An answer goes to stdout with exit status 0. A question with no answer goes to stderr with status 1, with the nearest word that has one.

## The map

`jac docs` alone prints how to look things up, then every section of the pages under its heading, a section within another a level below it, and under each heading the section's pages, each by its path and title. It is Markdown, and small enough to read at once (about 10 KB):

```text
# jac documentation

240 pages, in /Users/me/.jac/0.3.2/docs. Under each section's heading below are its pages, each by its path and title.

- `jac docs <page>` prints a page: `jac docs start/primer`.
- `jac docs section <heading>` prints a section's pages, each with what it covers: `jac docs section basics`.
- `jac docs <word>` prints what defines a word: a keyword or operator (`visit`, `++>`), a diagnostic code (`E1307`), a module (`os.path`), a `jac.toml` key (`check.lint.select`), a command (`build`), a rule of the grammar (`archetype`).
- `jac docs search <text>` finds the pages and sections that mention a text.
- `jac docs --path` prints the directory these files are in, for `grep`.
- `jac skills` lists playbooks for common tasks.
- `--json` after any of them prints the same as data.

## Start here

- `start/index`: What jac is
- `start/install`: Install
...

## Language

- `language/principles`: Principles

### Basics

- `language/lexical-structure`: Lexical structure
...
```

Two kinds of page have a lookup of their own, so the map says how to reach them instead of listing them: the pages of diagnostic codes, which it counts, since `jac docs E1307` prints a code's entry, and the skills, which it names, since `jac skills` lists them.

A page is named by its path under the documentation's directory, without `.md`: `start/index`, `language/walkers`, `toolchain/docs`.

## A section

`jac docs section <heading>` prints a section of the map with what each page covers, its front matter's `description`: the section whose heading it is given, in upper or lower case, and the sections under it. Every page is in a section, so every page is in the map or one `section` away from it.

```sh
jac docs section compile time
```

```text
# Compile time

- `language/compile-time`: The comptime keyword in every position it may appear (globals, locals, functions, if, for, assert, parameters, members, imports) and what each form does as the program compiles.
...

`jac docs <page>` prints one of them.
```

Several words are one heading, so no quoting is needed. A heading no section has is an error, with the nearest that one has:

```text
jac docs: there is no section 'basic' (did you mean 'basics'?)

Run `jac docs` for the map, which heads each section with its title.
```

The sections are `nav.json`'s, in its order. A page it names outside every section heads a section of its own, and the pages it leaves out are in a last section, "Other pages".

## A page or a word

`jac docs <word>` takes one word and prints what it names. The word may be:

| Word | Answered with | Example |
|---|---|---|
| A page's path | The page | `jac docs toolchain/build` |
| A diagnostic code, in any case | The code's entry: the compiler's message, what it means, a program that raises it, the fix, and the page it is on | `jac docs E1307`, `jac docs e1307` |
| A keyword of a page | The page that defines it. Keywords are the language's keywords and operators, builtins, modules, `jac.toml` keys in dotted form, environment variables, lint rules and concepts | `jac docs visit`, `jac docs ++>`, `jac docs print`, `jac docs check.lint.select`, `jac docs NO_COLOR` |
| A command | What `jac help <command>` prints, which ends with the command's guide page | `jac docs build` |
| A rule of the grammar | The rule in EBNF, and the pages that explain it | `jac docs archetype` |
| The last part of a page's path, or a skill's name | That page | `jac docs walkers`, `jac docs first-program` |

A page is printed as its Markdown, without the lines of front matter at its top.

Several words are one name with spaces in it, so no quoting is needed: `jac docs flow for` looks up `flow for`. An operator the shell would read is quoted: `jac docs '-->'`.

When a word names several things, the first in the order of the table is printed, after a note of the others:

```sh
jac docs install
```

```text
> `install` names more than one thing. What follows is the command `jac install`. The others:
> - `jac docs start/install`: Installing a jac release with the installer, its options, where it puts things, checking that it works, and uninstalling.

Install the project's Python packages.

Usage: jac install [--pypi <package>...] [--frozen]
...
Its guide: `jac docs interop/python`.
```

A code no page has an entry for yet is still answered, with the compiler's message for it.

A word that names nothing is an error that offers the nearest word that does:

```text
jac docs: nothing is named 'walkrs' (did you mean 'walkers'?)

Run `jac docs search walkrs` to search the pages for it, or `jac docs` for the map.
```

## Search

`jac docs search <text>` finds the pages that mention the text's words, best first. Each word is matched on its own, ignoring case, anywhere in a word of the page: `search build cache` finds the pages that hold both `build` and `cache`, and when no page holds every word, those that hold any. A word weighs most in a page's title or path, then in its keywords, then in its description, then in its text.

```sh
jac docs search build cache -n 3
```

```text
toolchain/cache: The build cache
    line 3: A build compiles each module on its own and keeps what it compiles in the build cache: a directory of your own, shared by every build you run. A rebuild compiles only what an edit changed, and a build with nothing changed does nothing at all.
toolchain/build: build
    line 24 (under "What a build does"): 3. Generates code, compiles each module on its own (reusing what the [build cache](cache.md) holds), and links.

`jac docs <page>` prints one of them.
```

Each result is the page, its title, and the line that holds most of the words, with its number in the page and the heading it is under. `-n <count>` sets how many pages are shown (default 10). A search that finds nothing is an error (`no page mentions '<text>'`), and so is one with no text.

## In a browser

`jac docs --serve` serves the same pages to a browser, and prints where:

```text
The documentation is at http://127.0.0.1:8091/
```

- **A page reads as it is written.** Its headings, tables, lists and code are HTML, and a link to another page, or to a heading of one, goes there.
- **Jac code is colored by jac's own lexer.** A keyword, a string, a number and a comment are what the compiler takes them for. An example that shows a lexical error is left plain.
- **The map is beside the page**, by `nav.json`'s sections, with the page being read marked.
- **One box searches and looks up.** Typing shows the pages that mention the text, as `docs search` finds them, each at the heading it matched. When the text is a word `jac docs <word>` answers with a page (a code, a keyword, a command's guide, a rule), what defines it is the first result. Enter goes to the first result, and Escape clears the box.
- **The page loads nothing from anywhere else.** Its code is a Jac program, compiled for the browser when jac is built, and it is served from the same address as the pages.

`jac docs <page | word> --serve` opens at that page, or at what defines the word: `jac docs E1307 --serve` prints the address of that code's entry. A word that names nothing is the error it is without `--serve`.

`--listen <address>` says where it serves (`127.0.0.1:8091` when not given; port 0 is any free port). It serves until it is interrupted, and opens no browser: open the address in one, or have [`jac browse`](browse.md) do it. The pages are read once, when it starts.

## --json

`--json`, after any form, prints the same answer as JSON, for a program to read:

| Form | JSON |
|---|---|
| `jac docs --json` | `{"path", "sections": [{"title", "level", "pages": [{"page", "title"}]}]}`: the map's sections in order, `level` 1 for a section and 2 for one under it, each with all its pages, those the map counts too |
| `jac docs section <heading> --json` | A list of `{"title", "level", "pages"}`, the section and those under it, each page as below without its text |
| `jac docs <word> --json` | `{"word", "kind", "text", "also", "page", "title", "description", "keywords", "grammar"}`. `kind` is `page`, `code`, `keyword`, `command` or `rule`; `text` is what the plain form prints; `also` lists the other things the word names. The page's fields are absent for a command with no guide page |
| `jac docs search <text> --json` | A list of `{"page", "title", "description", "heading", "line", "excerpt"}` |
| `jac skills --json` | A list of `{"name", "description", "page"}` |
| `jac skills <name> --json` | `{"page", "title", "description", "keywords", "grammar", "text", "name"}` |

```sh
jac docs E1030 --json
```

```text
{
  "word": "E1030",
  "kind": "code",
  "text": "## E1030\n\n```text\n{owner} has no {kind} '{name}'\n```\n\n...",
  "also": [],
  "page": "reference/diagnostics/e10-1",
  "title": "E1001 to E1041: values and their types",
  "description": "Diagnostics E1001 to E1041, ...",
  "keywords": [],
  "grammar": []
}
```

## Where the pages are

The pages are Markdown files in a directory `docs/`, which jac finds as it finds its runtime: beside its own executable's directory, or in the nearest directory above it that has one holding a `nav.json`. Links to jac are followed first, so a jac installed as `~/.local/bin/jac` reads its release's pages.

| jac | Its pages |
|---|---|
| An installed release, `<prefix>/bin/jac` | `<prefix>/docs/` |
| Built in a checkout, `build/bin/jac` | The checkout's `docs/` |

`jac docs --path` prints the directory, for tools that read the files themselves:

```sh
grep -rl "flow for" "$(jac docs --path)"
```

A jac with no `docs/` stops with:

```text
jac: no documentation found: no docs/nav.json in /opt/jac/bin or a directory above it (a release has docs/ beside bin/)
```

`nav.json` in that directory gives the sections, their titles and their pages' order. Each page starts with front matter: `description` (the line `jac docs section` shows for it), `keywords` (the words the page is the definition of) and `grammar` (the grammar's rules it explains). The same files are what the documentation's web reader shows.

## --check

`jac docs --check` lists what is wrong with the pages, one problem to a line, on stderr, with exit status 1, then `N problems in <dir>`. With nothing wrong it prints nothing and exits 0. It is for people who write the pages. It reports:

- a page with no description or no `# ` title, or that `nav.json` leaves out, and a page `nav.json` names that is not there;
- a section of `nav.json` with no title, and two sections with one title, since `jac docs section` takes a section by its title;
- a keyword two pages claim;
- a diagnostic code with no entry, an entry whose first `text` block is not the compiler's message for the code, and an entry for a code there is not;
- a rule of the grammar no page's `grammar:` names, and a name there that is no rule;
- a keyword of the language or a lint rule no page claims;
- a command whose guide page is not there;
- a link between pages that leads to no page, and a link to a heading its page does not have.

### Writing pages

A page is Markdown with front matter:

```text
---
description: One line saying what the page covers.
keywords: walker, spawn
grammar: archetype, archetype_member
---
# Walkers
```

- `description` is required; `keywords` and `grammar` are lists separated by commas. A keyword belongs to one page in the whole tree.
- The page has one `# ` title, and links to other pages by relative links to their `.md` files.
- Every `jac` block is a whole module that jac takes as the page says, which jac's own tests check: one whose first line is `# expect: <code>[ x<count>], ...` is refused by `jac check` with exactly those errors; one followed by an `output` block is built and run, and prints exactly that; any other passes `jac check`. A block after the line `<!-- example: not checked: <reason> -->` is left alone.
- Two pages are generated from the compiler: `reference/commands.md` by `jac help --markdown`, and `reference/grammar.md` by `jac grammar compiler/parsing/parser.jac --page` ([Inspect](inspect.md#grammar)).

## Skills

A skill is a playbook for one task, written for an agent: when to use it, the steps, the commands, and what a correct result looks like. Skills are pages too, each a directory under `docs/skills/` holding a `SKILL.md`, whose front matter names the skill (`name:`) and says when to use it (`description:`).

```sh
jac skills                  # list them, each with when to use it
jac skills writing-jac      # print one
jac skills install          # copy every skill into .agents/skills/ here
```

`jac skills <name>` prints the skill's `SKILL.md`, without its front matter. `jac docs <name>` prints it too.

### skills install

`jac skills install` copies skills where an agent loads them from: each skill's whole directory, `SKILL.md` and what is beside it, to `.agents/skills/<name>/` in the directory it is run in. It prints the path of each `SKILL.md` it wrote:

```sh
jac skills install writing-jac
```

```text
.agents/skills/writing-jac/SKILL.md
```

- With no names it installs every skill; with names, those.
- `--to <dir>` writes to `<dir>/<name>/` instead of `.agents/skills/<name>/`.
- A skill already there is replaced whole, so installing again after upgrading jac brings the skills to that release's.

A name that is no skill is an error (`there is no skill '<name>'`), with the nearest that is, and nothing is installed. `--to` with no directory after it is an error.

## What goes wrong

| Message | Cause |
|---|---|
| `nothing is named '<word>'` | No page, code, keyword, command or rule is that word. Try `jac docs search <word>` |
| `search needs the text to look for` | `jac docs search` with nothing after it |
| `no page mentions '<text>'` | No page holds any of the words |
| `section needs a section's heading, as the map has it: section basics` | `jac docs section` with nothing after it |
| `there is no section '<heading>'` | No section of the map has that heading. `jac docs` prints them |
| `it has no option '--jsn' (did you mean '--json'?)` | A mistyped option |
| `no documentation found: ...` | This jac has no `docs/` beside its `bin/` or above it |
| `--json is an option of the pages printed, and --serve serves them` | `--serve` with `--json`, `--path`, `--check` or `-n` |
| `--serve opens at a page or a word: the page it serves has the search` | `jac docs search <text> --serve` |
| `--listen is where --serve serves the pages` | `--listen` without `--serve` |
| `cannot serve at <address>: ...; name another with --listen` | The address is taken, or is not this machine's |
| `the toolchain at <lib> has no page for the viewer` | This jac's `lib/` has no `viewers/docs/`: it is not a whole install |
| `there is no skill '<name>'` | `jac skills <name>` or `skills install <name>` with a name no skill has |
