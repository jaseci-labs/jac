import os;
import sys;
import time;

import from jaclang.jac0core { unitree as uni }
import from jaclang.jac0core.program { JacProgram }


"""Analyze a Jac project via compiler AST."""
def analyze_project(directory: str) -> str;

sem analyze_project = "Compiler-level analysis of an entire Jac project. Returns all nodes (with fields and types), walkers (with entry points showing which nodes they visit), edges, client .cl.jac components (with state), objects, import map, and export map. Use this to understand a project before writing code — gives accurate structural knowledge in one call instead of reading files manually.";
sem analyze_project.directory = "Root directory of the Jac project to analyze";


"""Find a symbol's definition and usages."""
def find_symbol(name: str, directory: str = "") -> str;

sem find_symbol = "Look up any Jac symbol (node, walker, edge, obj, enum, component) by name. Returns: definition file and line, all fields with types, all abilities (including which use by llm()), every file that imports or references it, walker entry points that visit it, and the exact import statement to use. Use this when you need details about a specific type or need to know the correct import path.";
sem find_symbol.name = "The symbol name to look up (e.g. 'User', 'create_post', 'LoginForm')";
sem find_symbol.directory = "Root directory of the Jac project to search";
