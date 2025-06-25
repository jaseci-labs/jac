"""Type classes for the mtllm package."""

import base64
import importlib
import importlib.util
import inspect
from io import BytesIO
from typing import Any, Callable

from mtllm.semtable import SemInfo, SemRegistry, SemScope
from mtllm.utils import extract_non_primary_type, get_object_string, get_type_annotation

cv2 = importlib.import_module("cv2") if importlib.util.find_spec("cv2") else None
PILImage = (
    importlib.import_module("PIL.Image") if importlib.util.find_spec("PIL") else None
)


class Video:
    """Represent a video."""

    def __init__(self, file_path: str, seconds_per_frame: int = 2) -> None:
        """Initialize the Video class."""
        assert (
            cv2 is not None
        ), "Please install the required dependencies by running `pip install mtllm[video]`."
        self.file_path = file_path
        self.seconds_per_frame = seconds_per_frame

    def process(
        self,
    ) -> list:
        """Process the video and return a list of base64 encoded frames."""
        assert (
            cv2 is not None
        ), "Please install the required dependencies by running `pip install mtllm[video]`."

        assert self.seconds_per_frame > 0, "Seconds per frame must be greater than 0"

        base64_frames = []

        video = cv2.VideoCapture(self.file_path)
        total_frames = int(video.get(cv2.CAP_PROP_FRAME_COUNT))
        fps = video.get(cv2.CAP_PROP_FPS)
        video_total_seconds = total_frames / fps
        assert (
            video_total_seconds > self.seconds_per_frame
        ), "Video is too short for the specified seconds per frame"
        assert (
            video_total_seconds < 4
        ), "Video is too long. Please use a video less than 4 seconds long."

        frames_to_skip = int(fps * self.seconds_per_frame)
        curr_frame = 0
        while curr_frame < total_frames - 1:
            video.set(cv2.CAP_PROP_POS_FRAMES, curr_frame)
            success, frame = video.read()
            if not success:
                break
            _, buffer = cv2.imencode(".jpg", frame)
            base64_frames.append(base64.b64encode(buffer).decode("utf-8"))
            curr_frame += frames_to_skip
        video.release()
        return base64_frames


class Image:
    """Represent an image."""

    def __init__(self, file_path: str) -> None:
        """Initialize the Image class."""
        assert (
            PILImage is not None
        ), "Please install the required dependencies by running `pip install mtllm[image]`."
        self.file_path = file_path

    def process(self) -> tuple[str, str]:
        """Process the image and return a base64 encoded image and its format."""
        assert (
            PILImage is not None
        ), "Please install the required dependencies by running `pip install mtllm[image]`."
        image = PILImage.open(self.file_path)
        img_format = image.format
        with BytesIO() as buffer:
            image.save(buffer, format=img_format, quality=100)
            return (
                base64.b64encode(buffer.getvalue()).decode("utf-8"),
                img_format.lower(),
            )


class TypeExplanation:
    """Represent a type explanation."""

    def __init__(self, type_item: str, mod_registry: SemRegistry) -> None:
        """Initialize the TypeExplanation class."""
        self.type_item = type_item
        self.explanation, self._nested_types = self.get_type_explanation(mod_registry)

    def get_type_explanation(self, mod_registry: SemRegistry) -> tuple[str, set[str]]:
        """Get the type explanation of the input type string."""
        # print(f"Type Item: {self.type_item}")
        # print(f"Mod Registry: {mod_registry}")
        scope, sem_info = mod_registry.lookup(name=self.type_item)
        # print(f"Scope: {scope}, SemInfo: {sem_info}")
        if isinstance(sem_info, SemInfo) and sem_info.type:
            sem_info_scope = SemScope(sem_info.name, sem_info.type, scope)
            _, type_info = mod_registry.lookup(scope=sem_info_scope)
            type_info_types = []
            type_example_list = []
            type_example: str = ""
            if sem_info.type == "Enum" and isinstance(type_info, list):
                for enum_item in type_info:
                    (
                        type_example_list.append(
                            f'{sem_info.name}.{enum_item.name} : "{enum_item.semstr}"'
                            if enum_item.semstr
                            else f"{sem_info.name}.{enum_item.name}"
                        )
                    )
                type_example = ", ".join(type_example_list)
            elif sem_info.type in [
                "object",
                "class",
                "node",
                "edge",
                "walker",
            ] and isinstance(type_info, list):
                for arch_item in type_info:
                    if arch_item.type in ["object", "class", "node", "edge", "walker"]:
                        continue
                    type_example_list.append(
                        f'{arch_item.name}="{arch_item.semstr}":{arch_item.type}'
                        if arch_item.semstr
                        else f"{arch_item.name}={arch_item.type}"
                    )
                    if arch_item.type and extract_non_primary_type(arch_item.type):
                        type_info_types.extend(extract_non_primary_type(arch_item.type))
                type_example = f"{sem_info.name}({', '.join(type_example_list)})"
            return (
                f"{sem_info.semstr} ({sem_info.name}) ({sem_info.type}) eg:- {type_example}".strip(),  # noqa: E501
                set(type_info_types),
            )
        return "", set()

    def __str__(self) -> str:
        """Return the string representation of the TypeExplanation class."""
        return self.explanation

    @property
    def nested_types(self) -> set[str]:
        """Get the nested types of the type."""
        return self._nested_types


class InputInformation:
    """Represent the input information."""

    def __init__(self, semstr: str, name: str, value: Any) -> None:  # noqa: ANN401
        """Initialize the InputInformation class."""
        self.semstr = semstr
        self.name = name
        self.value = value

    def __str__(self) -> str:
        """Return the string representation of the InputInformation class."""
        type_anno = get_type_annotation(self.value)
        return f"{self.semstr if self.semstr else ''} ({self.name}) ({type_anno}) = {get_object_string(self.value)}".strip()  # noqa: E501

    def to_list_dict(self) -> list[dict]:
        """Return the list of dictionaries representation of the InputInformation class."""
        input_type = get_type_annotation(self.value)
        if input_type == "Image":
            img_base64, img_type = self.value.process()
            return [
                {
                    "type": "text",
                    "text": f"{self.semstr if self.semstr else ''} ({self.name}) (Image) = ".strip(),
                },
                {
                    "type": "image_url",
                    "image_url": {"url": f"data:image/{img_type};base64,{img_base64}"},
                },
            ]
        elif input_type == "Video":
            video_frames = self.value.process()
            return [
                {
                    "type": "text",
                    "text": f"{self.semstr if self.semstr else ''} ({self.name}) (Video) = ".strip(),
                },
                *(
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": f"data:image/jpeg;base64,{frame}",
                            "detail": "low",
                        },
                    }
                    for frame in video_frames
                ),
            ]
        return [
            {
                "type": "text",
                "text": str(self),
            }
        ]

    def get_types(self) -> list:
        """Get the types of the input."""
        return extract_non_primary_type(get_type_annotation(self.value))


class OutputHint:
    """Represent the output hint."""

    def __init__(self, semstr: str, type: str) -> None:  # noqa: ANN401
        """Initialize the OutputHint class."""
        self.semstr = semstr
        self.type = type

    def __str__(self) -> str:
        """Return the string representation of the OutputHint class."""
        return f"{self.semstr if self.semstr else ''} ({self.type})".strip()

    def get_types(self) -> list:
        """Get the types of the output."""
        return extract_non_primary_type(self.type)


class Information:
    """Represent the information."""

    def __init__(
        self, filtered_registry: SemRegistry, name: str, value: Any  # noqa: ANN401
    ) -> None:
        """Initialize the Information class."""
        self.name = name
        self.value = value
        self.registry = filtered_registry

    @property
    def semstr(self) -> str:
        """Get the semantic string of the information."""
        _, sem_info = self.registry.lookup(name=self.name)
        return sem_info.semstr if sem_info and isinstance(sem_info, SemInfo) else ""

    @property
    def type(self) -> str:
        """Get the type of the information."""
        _, sem_info = self.registry.lookup(name=self.name)
        return (
            sem_info.type
            if sem_info and isinstance(sem_info, SemInfo)
            else get_type_annotation(self.value)
        ) or ""

    def __str__(self) -> str:
        """Return the string representation of the Information class."""
        type_anno = get_type_annotation(self.value)
        return f"{self.semstr} ({self.name}) ({type_anno}) = {get_object_string(self.value)}".strip()

    def get_types(self) -> list:
        """Get the types of the information."""
        return extract_non_primary_type(self.type)


class Tool:
    """Base class for tools."""

    def __init__(self, func: Callable) -> None:
        """Initialize the tool."""
        self.func = func
        self.semstr: str = ""
        self.semstr_params: dict[str, str] = {}

        if hasattr(func, "_jac_semstr"):
            self.semstr = func._jac_semstr  # type: ignore[attr-defined]
        else:
            self.semstr = func.__doc__ or ""

        if hasattr(func, "_jac_semstr_inner"):
            self.semstr_params = func._jac_semstr_inner  # type: ignore[attr-defined]

    def get_name(self) -> str:
        """Get the name of the tool."""
        return self.func.__name__

    def __call__(self, *args, **kwargs) -> str:  # noqa
        """Forward function of the tool."""
        return self.func(*args, **kwargs)

    def get_usage_example(self) -> str:
        """Get the usage example of the tool."""
        params_example: list[str] = []
        sig = inspect.signature(self.func)
        for name, param in sig.parameters.items():
            if param_semstr := self.semstr_params.get(name, ""):
                params_example.append(f'{name}="{param_semstr}":{param.annotation}')
            else:
                params_example.append(f"{name}={param.annotation}")
        return f"{self.func.__name__}({', '.join(params_example)})"

    def __str__(self) -> str:
        """Return a string representation of the tool."""
        tool_str = f"tool_name={self.func.__name__}\n"
        tool_str += f"tool_description={self.semstr}\n"
        tool_str += f"usage_example={self.get_usage_example()}\n"
        return tool_str


class ReActOutput:
    """Represent the ReAct output."""

    def __init__(self, thought: str, action: str, observation: str) -> None:
        """Initialize the ReActOutput class."""
        self.thought = thought
        self.action = action
        self.observation = observation

    def __repr__(self) -> str:
        """Return the string representation of the ReActOutput class."""
        return f"ReActOutput(thought={self.thought}, action={self.action}, observation={self.observation})"
