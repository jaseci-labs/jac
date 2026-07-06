# Contributing to Documentation @ jac-lang.org

## How to find, add and change the documentation architecture

When adding content to the documentations maintain the document structure used in [docs](./docs/) folder. To include a new file or content into the documentation, edit the [mkdocs.yml](./mkdocs.yml) file.

As an example consider adding a new 'example.md' file residing in file path './docs/learn' in to the [mkdocs.yml](./mkdocs.yml) file, under the 'for_contributors' subsection. The file should change as following.

```yaml
...
nav:
    ...
    - ~/learn$:
      ...
      - ~/for_contributors:
        ...
        - 'learn/example.md'
      ...
...
```

## Running a local preview instance of the documentation

To open a preview of the mkdocs server locally, following steps should be followed.

1. Install the docs tooling (MkDocs plus the `jac-highlighter` Pygments lexer for Jac syntax highlighting). This is the standalone docs-preview package -- it does not install jaclang.

    ```bash
    cd docs
    pip install -e .
    ```

2. Bash the following lines to initiate the server.

    ```bash
    mkdocs serve
    ```

3. When prompted open the server from a web browser or the VS Code editor itself.
