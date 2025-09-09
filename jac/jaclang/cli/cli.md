# **Jac Language Command Line Interface (CLI)**

git Jac Language CLI provides a variety of commands to facilitate users. Additionally, Jac language offers users the ability to define custom CLI commands through plugins. This document aims to provide an overview of each command along with clear usage instructions.

> [!TIP]
> Use `jac --help` to see available commands and usage.

### Click one of the default commands below and see the usage.
- [tool](#tool) , [run](#run) , [clean](#clean) , [format](#format) , [check](#check) , [build](#build) , [enter](#enter) , [test](#test)



# 1. Command `tool`:
### tool
Jac Language offers language tools to perform various tasks efficiently. The `tool` command is utilized to execute specific language tools along with any optional arguments as needed. This command enables users to interact with language-specific command line tools designed to manage the language effectively.
### Usage:
```bash
$ jac tool <jac_tool> <args>
```
Parameters to execute the tool command:
- `jac_tool`: The name of the language tool to execute.
    - `ir`, `pass_template`, `py_uni_nodes`,  `md_doc`, `automate_ref` are the jac_tools used to handle (Usage instruction is below)
- `args`: Optional arguments for the specific language tool.


    ## 1. jac_tool `ir`:
     `ir` tool generates an Abstract Syntax Tree (AST) and SymbolTable tree for a .jac file, or a Python AST for a .py file. `ir` tool is used with `tool` cli command.
    ### Usage
    ```bash
    $ jac tool ir <output_type> <file_path>
    ```

    ### Parameters to use the ir tool:
  - `output_type`: Choose one of the following options:
    - `sym`: Provides the symbol table of the specified .jac file.
    - `sym.`: Generates a dot graph representation of the symbol table for the specified .jac file.
    - `ast`: Displays the Abstract Syntax Tree (AST) of the specified .jac file.
    - `ast.`: Generates a dot graph representation of the AST for the specified .jac file.
    - `cfg.`: Generates a dot graph representatuin of the CFG(Control Flow Graph) for a specific .jac file
    - `pyast`: Generates the Python AST for a .py file or the relevant Python AST for the generated Python code from a .jac file.
    - `py`: Displays the relevant generated Python code for the respective Jac code in a .jac file.
  - `file_path`: Path to the .jac or .py file.

    ### Examples
    >To get the symbol table tree of a Jac file:
    >```bash
    >$ jac tool ir sym <file_path>
    >```
    >To generate a dot graph of the symbol table tree for a Jac file:
    >```bash
    >$ jac tool ir sym. <file_path>
    >```
    >To view the AST tree of a Jac file:
    >```bash
    >$ jac tool ir ast <file_path>
    >```


    ## 2. jac_tool `pass_template`:
     `pass_template` tool generates pass template for jac.
    ```bash
    $ jac tool pass_template
    ```
    No Parameters needed to use the pass_template tool


    ## 3. jac_tool `py_uni_nodes`:
     `py_uni_nodes` tool lists python ast nodes.
    ```bash
    $ jac tool py_uni_nodes
    ```
    No Parameters needed to use the py_uni_nodes tool


    ## 4. jac_tool `md_doc`:
     `md_doc` tool generate mermaid markdown doc.
    ```bash
    $ jac tool md_doc
    ```
    No Parameters needed to use the md_doc tool


    ## 5. jac_tool `automate_ref`:
     `automate_ref` tool automates the reference guide generation.
    ```bash
    $ jac tool automate_ref
    ```
    No Parameters needed to use the automate_ref tool



# 2. Command `run`:
### run
The `run` command is utilized to run the specified .jac or .jir file.
### Usage:
```bash
$ jac run <file_path> [main] [cache]
```
  Parameters to execute the run command:
  - `file_path`: Path of .jac or .jir file to run.
  - `main`: (Optional, bool) A flag indicating whether the module being executed is the main module. Defaults to True
  - `cache` :The cache flag to cache
  ### Examples
  >To run file_path Jac file:
  >```bash
  >$ jac run <file_path>
  >```



# 3. Command `clean`:
### clean
The `clean` command is utilized to remove the __jac_gen__ , __pycache__ folders from the current directory recursively.
### Usage:
```bash
$ jac clean
```
No Parameters needed to execute the clean command



# 4. Command `format`:
### format
The `format` command is utilized to run the specified .jac file or format all .jac files in a given directory.
### Usage:
```bash
$ jac format <file_path/directory_path> [outfile] [debug]
```
  Parameters to execute the format command:
  - `file_path/directory_path`: The path to the .jac file or directory containing .jac files.
  - `outfile`: (Optional) The output file path (only applies when formatting a single file).
  - `debug` :(Optional) If True, print debug information.  Defaults to False
  ### Examples
  >To format all .jac files from walking through current located directory:
  >```bash
  >$ jac format .
  >```



# 5. Command `check`:
### check
The `check` command is utilized to run type checker for a specified .jac file.
### Usage:
```bash
$ jac check <file_path>
```
Parameters to execute the check command:
- `file_path`: Path of .jac file to run type checker.



# 6. Command `build`:
### build
The `build` command is utilized to build the specified .jac file.
### Usage:
```bash
$ jac build <file_path>
```
  Parameters to execute the build command:
  - `file_path`: Path of .jac file to build.



# 7. Command `enter`:
### enter
The `enter` command is utilized to run the specified entrypoint function in the given .jac file.
### Usage:
```bash
$ jac enter <file_path> <entrypoint> <args>
```
Parameters to execute the enter command:
- `file_path`: The path to the .jac file.
- `entrypoint`: The name of the entrypoint function.
- `args`: Arguments to pass to the entrypoint function.
### Examples
>To enter file_path Jac file
>```bash
>$ jac enter <file_path>
>```



# 8. Command `test`:
### test
The `test` command is utilized to run the test suite in the specified .jac file.
```bash
$ jac test <file_path>
```
Parameters to execute the test command:
- `file_path`: The path to the .jac file.
