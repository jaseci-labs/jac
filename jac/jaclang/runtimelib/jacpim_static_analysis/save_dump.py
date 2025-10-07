"""Memory dump saving system for JacPIM executions.

This module provides functionality to save DPU memory dumps to disk
in a structured folder hierarchy for analysis.
"""

import shutil
from pathlib import Path

from jaclang.runtimelib.jacpim_perf_measure.cpu_run_ctx import DPUAllMemoryCtx


class JacPIMDumpSaver:
    """Saves JacPIM memory dumps to structured folders."""

    ROOT_FOLDER = "input_bins"

    @classmethod
    def clear_and_create_root_folder(cls) -> None:
        """Remove the entire input_bins/ folder and recreate an empty one."""
        root_path = Path(cls.ROOT_FOLDER)

        # Remove existing folder if it exists
        if root_path.exists():
            shutil.rmtree(root_path)
            print(f"Removed existing {cls.ROOT_FOLDER} folder")

        # Create new empty folder
        root_path.mkdir(exist_ok=True)
        print(f"Created new empty {cls.ROOT_FOLDER} folder")

    @classmethod
    def save_all_dumps(cls) -> None:
        """Save all memory dumps from DPUAllMemoryCtx.all_memory_dumps.

        Structure:
        input_bins/
        ├── execution_0/
        │   ├── core_0.bin
        │   ├── core_1.bin
        │   └── ...
        ├── execution_1/
        │   ├── core_0.bin
        │   ├── core_1.bin
        │   └── ...
        └── ...
        """
        # Clear and recreate root folder
        cls.clear_and_create_root_folder()

        all_dumps = DPUAllMemoryCtx.all_memory_dumps

        if not all_dumps:
            print("No memory dumps found to save")
            return

        print(f"Saving {len(all_dumps)} execution dumps...")

        for execution_idx, dpu_dumps in enumerate(all_dumps):
            execution_folder = Path(cls.ROOT_FOLDER) / f"execution_{execution_idx}"
            execution_folder.mkdir(exist_ok=True)

            print(
                f"  Saving execution_{execution_idx} with {len(dpu_dumps)} DPU cores..."
            )

            for core_idx, dpu_memory_ctx in enumerate(dpu_dumps):
                core_file = execution_folder / f"core_{core_idx}.bin"

                try:
                    # Get binary dump from DPUMemoryCtx
                    binary_data = dpu_memory_ctx.dump()

                    # Write binary data to file
                    with open(core_file, "wb") as f:
                        f.write(binary_data)

                    # print(f"    Saved {core_file} ({len(binary_data)} bytes)")

                except Exception as e:
                    print(f"    Error saving {core_file}: {e}")

        print(f"Memory dump saving complete! Saved to {cls.ROOT_FOLDER}/")

    @classmethod
    def save_single_execution(cls, execution_idx: int) -> bool:
        """Save a single execution's memory dumps.

        Args:
            execution_idx: Index of the execution to save

        Returns:
            True if successful, False if execution_idx is out of range
        """
        all_dumps = DPUAllMemoryCtx.all_memory_dumps

        if execution_idx >= len(all_dumps) or execution_idx < 0:
            print(
                f"Execution index {execution_idx} out of range (0-{len(all_dumps) - 1})"
            )
            return False

        # Ensure root folder exists
        root_path = Path(cls.ROOT_FOLDER)
        root_path.mkdir(exist_ok=True)

        dpu_dumps = all_dumps[execution_idx]
        execution_folder = root_path / f"execution_{execution_idx}"
        execution_folder.mkdir(exist_ok=True)

        print(f"Saving execution_{execution_idx} with {len(dpu_dumps)} DPU cores...")

        for core_idx, dpu_memory_ctx in enumerate(dpu_dumps):
            core_file = execution_folder / f"core_{core_idx}.bin"

            try:
                binary_data = dpu_memory_ctx.dump()

                with open(core_file, "wb") as f:
                    f.write(binary_data)

                # print(f"  Saved {core_file} ({len(binary_data)} bytes)")

            except Exception as e:
                print(f"  Error saving {core_file}: {e}")
                return False

        return True


# Convenience functions for easy access
def save_all_memory_dumps() -> None:
    """Save all memory dumps to input_bins/ folder structure."""
    JacPIMDumpSaver.save_all_dumps()


def save_execution_dump(execution_idx: int) -> bool:
    """Save a specific execution's memory dumps.

    Args:
        execution_idx: Index of execution to save

    Returns:
        True if successful, False otherwise
    """
    return JacPIMDumpSaver.save_single_execution(execution_idx)


def clear_dump_folder() -> None:
    """Clear and recreate the input_bins/ folder."""
    JacPIMDumpSaver.clear_and_create_root_folder()
