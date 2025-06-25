"""
AOTT: Automated Operational Type Transformation.

This has all the necessary functions to perform the AOTT operations.
"""

from typing import Mapping

from PIL import Image as PILImage

from loguru import logger

from mtllm.llms.base import BaseLLM
from mtllm.semtable import SemRegistry
from mtllm.tools import finish_tool
from mtllm.types import (
    Image,
    Information,
    InputInformation,
    OutputHint,
    ReActOutput,
    Tool,
    TypeExplanation,
    Video,
)
from mtllm.utils import format_template_section


def aott_raise(
    model: BaseLLM,
    informations: list[Information],
    inputs_information: list[InputInformation],
    output_hint: OutputHint,
    type_explanations: list[TypeExplanation],
    action: str,
    context: str,
    method: str,
    is_custom: bool,
    tools: list[Tool],
    model_params: dict,
    _globals: dict,
    _locals: Mapping,
) -> str:
    """AOTT Raise uses the information (Meanings types values) provided to generate a prompt(meaning in)."""
    _globals[finish_tool.get_name()] = finish_tool
    contains_media: bool = any(
        isinstance(x.value, (Image, Video, PILImage.Image)) for x in inputs_information
    )
    informations_str = "\n".join([str(x) for x in informations])
    inputs_information_repr: list[dict] | str
    media = []
    if contains_media and not is_custom:
        inputs_information_repr = []
        for input_info in inputs_information:
            inputs_information_repr.extend(input_info.to_list_dict())
    elif is_custom:
        media = [x for x in inputs_information if isinstance(x.value, PILImage.Image)]
        inputs_information_repr = "\n".join([str(x) for x in inputs_information])
    else:
        inputs_information_repr = "\n".join([str(x) for x in inputs_information])

    type_explanations_str = "\n".join([str(x) for x in type_explanations])

    system_prompt = model.MTLLM_SYSTEM_PROMPT
    meaning_typed_input_list: list[str] | list[dict]
    is_react = method == "ReAct"
    tools.append(finish_tool)
    method_prompt = model.MTLLM_METHOD_PROMPTS[method]
    if isinstance(inputs_information_repr, str):
        all_values = {
            "information": informations_str,
            "inputs_information": inputs_information_repr,
            "output_information": str(output_hint),
            "type_explanations": type_explanations_str,
            "action": action,
            "context": context,
        }
        mtllm_prompt = format_template_section(model.MTLLM_PROMPT, all_values)
        if not is_react:
            meaning_typed_input_list = [system_prompt, mtllm_prompt, method_prompt]
        else:
            tool_prompt = "\n[Tools]\n" + "\n".join([str(tool) for tool in tools])
            meaning_typed_input_list = [
                system_prompt,
                mtllm_prompt,
                tool_prompt,
                method_prompt,
            ]
    else:
        upper_half, lower_half = model.MTLLM_PROMPT.split("{inputs_information}")
        upper_values = {
            "information": informations_str,
            "context": context,
        }
        lower_values = {
            "output_information": str(output_hint),
            "type_explanations": type_explanations_str,
            "action": action,
        }
        upper_half = format_template_section(upper_half, upper_values)
        lower_half = format_template_section(lower_half, lower_values)
        meaning_typed_input_list = [
            {"type": "text", "text": system_prompt},
            {"type": "text", "text": upper_half},
        ]
        meaning_typed_input_list.extend(inputs_information_repr)
        if is_react:
            tool_prompt = "[Teools]\n" + "\n".join([str(tool) for tool in tools])
            meaning_typed_input_list.append({"type": "text", "text": tool_prompt})
        meaning_typed_input_list.extend(
            [
                {"type": "text", "text": lower_half},
                {"type": "text", "text": method_prompt},
            ]
        )
    if is_react:
        result = execute_react(
            model,
            meaning_typed_input_list,
            contains_media,
            model_params,
            _globals,
            _locals,
            tool_prompt,
            type_explanations_str,
        )
        return f"[Output] {result}"
    meaning_typed_input = (
        "\n".join(meaning_typed_input_list)  # type: ignore
        if not (contains_media and not is_custom)
        else meaning_typed_input_list
    )
    if is_custom:
        try:
            # This is a temporary solution to enable passing in custom
            # parameters to custom models
            # custom model should override the __call__ method to
            # accept function_inputs parameter
            return model(
                meaning_typed_input,  # type: ignore
                media=media,  # type: ignore
                function_inputs=inputs_information,  # type: ignore
                **model_params,
            )
        except TypeError:
            # this is for backward compatibility,
            # for any existing custom models that do not have the
            # function_inputs parameter
            return model(
                meaning_typed_input, media=media, **model_params  # type: ignore
            )
    else:
        return model(meaning_typed_input, media=media, **model_params)  # type: ignore


def execute_react(
    model: BaseLLM,
    meaning_typed_input_list: list[dict] | list[str],
    contains_media: bool,
    model_params: dict,
    _globals: dict,
    _locals: Mapping,
    tool_prompt: str,
    type_explanations_str: str,
) -> str:
    """Execute the ReAct method."""
    max_react_iterations = model_params.pop("max_react_iterations", 10)
    max_prev_react_outputs = model_params.pop("max_prev_react_outputs", 3)
    prev_react_outputs: list[ReActOutput] = []
    added_prev_react_input = False
    reached_max_iterations = False
    while True:
        if len(prev_react_outputs) >= max_react_iterations:
            reached_max_iterations = True
        prev_react_input = process_prev_react(
            prev_react_outputs[-max_prev_react_outputs:]
            if len(prev_react_outputs) > max_prev_react_outputs
            else prev_react_outputs
        )
        if prev_react_input:
            if added_prev_react_input:
                meaning_typed_input_list.pop(-2)
            meaning_typed_input_list.insert(
                -1,
                (
                    prev_react_input  # type: ignore
                    if not contains_media
                    else {"type": "text", "text": prev_react_input}
                ),
            )
            added_prev_react_input = True
        if reached_max_iterations:
            meaning_typed_input_list.insert(
                -1,
                (
                    "[Reached Max Iterations] PLEASE FINALIZE using the finish tool."  # type: ignore
                    if not contains_media
                    else {
                        "type": "text",
                        "text": "[Reached Max Iterations] PLEASE FINALIZE using the finish tool.",
                    }
                ),
            )
        meaning_typed_input = (
            "\n".join(meaning_typed_input_list)  # type: ignore
            if not contains_media
            else meaning_typed_input_list
        )
        if "media" not in model_params:
            model_params["media"] = None
        meaning_out = model(meaning_typed_input, **model_params)  # type: ignore
        react_output: ReActOutput = model.resolve_react_output(
            meaning_out, _globals, _locals, tool_prompt, type_explanations_str
        )
        if model.verbose:
            logger.info(f"React Output\n{react_output}")
        # FIXME: This is brittle but after litellm this will be gone.
        if react_output.action.startswith("finish"):
            return react_output.observation
        if reached_max_iterations:
            raise Exception("Reached max iterations.")
        prev_react_outputs.append(react_output)


def process_prev_react(prev_react_outputs: list[ReActOutput]) -> str:
    """Process the previous ReAct outputs."""
    prev_react_input = ""
    for i, prev_react_output in enumerate(prev_react_outputs):
        prev_react_input += f"{i + 1}.\n"
        prev_react_input += f"[Thought] {prev_react_output.thought}\n"
        prev_react_input += f"[Tool Usage] {prev_react_output.action}\n"
        prev_react_input += f"[Observation] {prev_react_output.observation}\n\n"
    if prev_react_input:
        prev_react_input = (
            f"\n[Previous Thoughts, Actions & Observations]\n{prev_react_input}"
        )
    return prev_react_input


def get_all_type_explanations(
    type_list: list, mod_registry: SemRegistry
) -> list[TypeExplanation]:
    """Get all type explanations from the input type list."""
    collected_type_explanations = {}
    for type_item in type_list:
        type_explanation = TypeExplanation(type_item, mod_registry)
        if str(type_explanation) and type_item not in collected_type_explanations:
            collected_type_explanations[type_item] = type_explanation
        if type_explanation.nested_types:
            nested_collected_type_explanations = get_all_type_explanations(
                list(type_explanation.nested_types), mod_registry
            )
            for nested_type_explanation in nested_collected_type_explanations:
                if nested_type_explanation.type_item not in collected_type_explanations:
                    collected_type_explanations[nested_type_explanation.type_item] = (
                        nested_type_explanation
                    )
    return list(collected_type_explanations.values())
