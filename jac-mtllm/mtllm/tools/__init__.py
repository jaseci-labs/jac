"""Pre-made tools for the mtllm package."""

from jaclang import JacMachineInterface as _

from mtllm.types import Tool


@_.sem(
    "A tool that finishes the Thought process by providing the output.",
    {
        "output": "The final output of the Thought process.",
    },
)
def finish(output: str) -> str:
    """Finishes the prompt with the given output."""
    return output


finish_tool = Tool(finish)
