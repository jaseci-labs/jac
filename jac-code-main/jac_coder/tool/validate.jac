import os;
import re;
import subprocess;

import from jac_coder.util.tool_output { tool_status, tool_end }
import from jac_coder.events { track_file, track_error }

"""Batch validate and auto-fix all modified .jac files in a project."""
def validate_project(directory: str = "") -> str;
sem validate_project = "Run full type-check on all modified .jac files, auto-fix mechanical patterns (root()->root(), deprecated syntax), and return a structured error report with fix hints. Call this AFTER writing all files — not during.";
sem validate_project.directory = "Project directory to validate. If empty, uses current working directory.";
