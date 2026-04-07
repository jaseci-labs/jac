import os;
import sys;

import from datetime { datetime }
import from jac_coder.nodes { ProjectMemory }
import from jac_coder.tool.jac_analyzer { _analyze_project, _find_jac_files }


def find_or_create_memory(project_dir: str) -> ProjectMemory | None;

def _init_memory(memory: ProjectMemory, project_dir: str) -> None;

def update_memory_from_session(
    memory: ProjectMemory, files_modified: list[str], session_summary: str
) -> None;
