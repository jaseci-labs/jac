"""Generated Python as source text, for the tools that print it.

The kernel hands the generated Python out as an `ast.Module` object; the host
unparses it with the interpreter's own `ast` module."""
import ast;

def generated_python(module: uni.Module) -> str;
