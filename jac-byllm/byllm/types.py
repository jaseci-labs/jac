"""Type definitions for LLM interactions.

This module defines the types used in the LLM interactions, including messages,
tools, and tool calls. It provides a structured way to represent messages,
tool calls, and tools that can be used in LLM requests and responses.
"""

from __future__ import annotations

import base64
import mimetypes
import os
from contextlib import suppress
from dataclasses import dataclass
from enum import StrEnum
from io import BytesIO
from typing import Callable, IO, TypeAlias, get_type_hints

from PIL.Image import Image as PILImageCls
from PIL.Image import open as open_image

from litellm.types.utils import Message as LiteLLMMessage

from pydantic import TypeAdapter

from .schema import tool_to_schema

# The message can be a jaclang defined message or what ever the llm
# returned object that was feed back to the llm as it was given (dict).
MessageType: TypeAlias = "Message | LiteLLMMessage"


class MessageRole(StrEnum):
    """Enum for message roles in LLM interactions."""

    SYSTEM = "system"
    USER = "user"
    ASSISTANT = "assistant"
    TOOL = "tool"


@dataclass
class Message:
    """Message class for LLM interactions."""

    role: MessageRole
    content: "str | list[Media]"

    def to_dict(self) -> dict[str, object]:
        """Convert the message to a dictionary."""
        if isinstance(self.content, str):
            return {
                "role": self.role.value,
                "content": self.content,
            }

        media_contents = []
        for media in self.content:
            media_contents.extend(media.to_dict())
        return {
            "role": self.role.value,
            "content": media_contents,
        }


@dataclass
class ToolCallResultMsg(Message):
    """Result of a tool call in LLM interactions."""

    tool_call_id: str
    name: str  # Function name.

    def __post_init__(self) -> None:
        """Post-initialization to set the role of the message."""
        self.role = MessageRole.TOOL  # Maybe this should be an assertion?

    def to_dict(self) -> dict[str, object]:
        """Convert the tool call result message to a dictionary."""
        return {
            "role": self.role.value,
            "content": self.content,
            "tool_call_id": self.tool_call_id,
            "name": self.name,
        }


@dataclass
class Tool:
    """Tool class for LLM interactions."""

    func: Callable
    description: str = ""
    params_desc: dict[str, str] = None  # type: ignore

    def __post_init__(self) -> None:
        """Post-initialization to validate the function."""
        annotations = get_type_hints(self.func)
        with suppress(Exception):
            self.func.__annotations__ = annotations

        self.description = Tool.get_func_description(self.func)
        if hasattr(self.func, "_jac_semstr_inner"):
            self.params_desc = self.func._jac_semstr_inner  # type: ignore
        else:
            self.params_desc = {name: str(type) for name, type in annotations.items()}

    def __call__(self, *args: list, **kwargs: dict) -> object:
        """Call the tool function with the provided arguments."""
        # If there is an error with the finish tool, we throw the exception.
        # Since it's the user's responsibility to handle it.
        if self.is_finish_tool():
            return self.func(*args, **kwargs)
        try:
            # TODO: Shoud I json serialize or this is fine?
            return self.func(*args, **kwargs)
        except Exception as e:
            # For the LLM if the tool failed, it'll see the error message
            # and make decision based on that.
            return str(e)

    def get_name(self) -> str:
        """Return the name of the tool function."""
        return self.func.__name__

    @staticmethod
    def get_func_description(func: Callable) -> str:
        """Get the description of the function."""
        if hasattr(func, "_jac_semstr"):
            return func._jac_semstr  # type: ignore
        return func.__doc__ or func.__name__

    @staticmethod
    def make_finish_tool(resp_type: type) -> Tool:
        """Create a finish tool that returns the final output."""

        def finish_tool(final_output: object) -> object:
            return TypeAdapter(resp_type).validate_python(final_output)

        finish_tool.__annotations__["return"] = resp_type
        finish_tool.__annotations__["final_output"] = resp_type
        return Tool(
            func=finish_tool,
            description="This tool is used to finish the tool calls and return the final output.",
            params_desc={
                "final_output": "The final output of the tool calls.",
            },
        )

    def is_finish_tool(self) -> bool:
        """Check if the tool is a finish tool."""
        return self.get_name() == "finish_tool"

    def get_json_schema(self) -> dict[str, object]:
        """Return the JSON schema for the tool function."""
        return tool_to_schema(self.func, self.description, self.params_desc)

    def parse_arguments(self, args_json: dict) -> dict:
        """Parse the arguments from JSON to the function's expected format."""
        args = {}

        annotations: dict = {}
        try:
            annotations = self.func.__annotations__
        except AttributeError:
            annotations = get_type_hints(self.func)

        for arg_name, arg_json in args_json.items():
            if arg_type := annotations.get(arg_name):
                args[arg_name] = TypeAdapter(arg_type).validate_python(arg_json)
        return args


@dataclass
class ToolCall:
    """Tool call class for LLM interactions."""

    call_id: str
    tool: Tool
    args: dict

    def __call__(self) -> ToolCallResultMsg:
        """Call the tool with the provided arguments."""
        result = self.tool(**self.args)
        return ToolCallResultMsg(
            role=MessageRole.TOOL,
            content=str(result),
            tool_call_id=self.call_id,
            name=self.tool.get_name(),
        )

    def __str__(self) -> str:
        """Return the string representation of the tool call."""
        params = ", ".join(f"{k}={v}" for k, v in self.args.items())
        return f"{self.tool.get_name()}({params})"

    def is_finish_call(self) -> bool:
        """Check if the tool is a finish tool."""
        return self.tool.is_finish_tool()

    def get_output(self) -> object:
        """Get the output from the finish tool call."""
        assert (
            self.is_finish_call()
        ), "This method should only be called for finish tools."
        return self.tool(**self.args)


@dataclass
class MockToolCall:
    """Mock tool call for testing purposes."""

    tool: Callable
    args: dict

    def to_tool_call(self) -> ToolCall:
        """Convert the mock tool call to a ToolCall."""
        return ToolCall(
            call_id="",  # Call ID is not used in mock calls.
            tool=Tool(self.tool),
            args=self.args,
        )


@dataclass
class CompletionResult:
    """Result of the completion from the LLM."""

    output: object
    tool_calls: list[ToolCall]


# -----------------------------------------------------------------------------
# Media content types
# -----------------------------------------------------------------------------


@dataclass
class Media:
    """Base class for message content."""

    def to_dict(self) -> list[dict]:
        """Convert the content to a dictionary."""
        raise NotImplementedError("Subclasses must implement this method.")


@dataclass
class Text(Media):
    """Class representing text content in a message."""

    text: str

    def to_dict(self) -> list[dict]:
        """Convert the text content to a dictionary."""
        return [{"type": "text", "text": self.text}]


@dataclass
class Image(Media):
    """Class representing an image."""

    url: (
        "str | bytes | bytearray | memoryview | BytesIO | IO[bytes] | "
        "os.PathLike[str] | os.PathLike[bytes] | PILImageCls"
    )  # type: ignore[name-defined]
    mime_type: str | None = None

    def __post_init__(self) -> None:
        """Normalize input into a data URL or leave remote/data URLs as-is.

        Supported inputs:
        - HTTP(S)/GS URLs (left as-is)
        - Data URLs (data:...)
        - Local file paths (opened and encoded to data URL)
        - Bytes / bytearray / memoryview
        - File-like objects (BytesIO or any IO[bytes])
        - os.PathLike
        - PIL.Image.Image instances
        """
        value = self.url

        # Handle path-like inputs by converting to string
        if isinstance(value, os.PathLike):
            value = os.fspath(value)

        # Remote or data URLs: keep as-is (trim whitespace)
        if isinstance(value, str):
            s = value.strip()
            if s.startswith(("http://", "https://", "gs://", "data:")):
                self.url = s
                return
            # Treat as local file path
            if not os.path.exists(s):
                raise ValueError(f"Image file does not exist: {s}")
            image = open_image(s)
            fmt = image.format or "PNG"
            # Determine MIME type with WEBP special-case for py<3.13
            self.mime_type = self._format_to_mime(fmt)
            with BytesIO() as buffer:
                image.save(buffer, format=fmt)
                data = buffer.getvalue()
            self.url = self._data_url_from_bytes(data, fmt)
            return

        # PIL Image instance
        if isinstance(value, PILImageCls):
            fmt = value.format or "PNG"
            with BytesIO() as buffer:
                value.save(buffer, format=fmt)
                data = buffer.getvalue()
            self.url = self._data_url_from_bytes(data, fmt)
            return

        # Bytes-like object
        if isinstance(value, (bytes, bytearray, memoryview)):
            raw = bytes(value)
            # Probe format via PIL to set correct MIME
            img = open_image(BytesIO(raw))
            fmt = img.format or "PNG"
            # Use bytes as-is (avoid re-encode) if PIL detects same format as content
            # Otherwise, re-encode to the detected format to be safe.
            try:
                self.url = self._data_url_from_bytes(raw, fmt)
            except Exception:
                with BytesIO() as buffer:
                    img.save(buffer, format=fmt)
                    self.url = self._data_url_from_bytes(buffer.getvalue(), fmt)
            return

        # File-like object (e.g., BytesIO, IO[bytes])
        if hasattr(value, "read") and callable(value.read):
            # Safely read without permanently moving the cursor
            stream: IO[bytes] = value  # type: ignore[assignment]
            pos = None
            try:
                pos = stream.tell()  # type: ignore[attr-defined]
            except Exception:
                pos = None
            try:
                # Prefer getvalue if available (e.g., BytesIO)
                if hasattr(stream, "getvalue") and callable(stream.getvalue):
                    raw = stream.getvalue()  # type: ignore[call-arg]
                else:
                    if hasattr(stream, "seek"):
                        with suppress(Exception):
                            stream.seek(0)
                    raw = stream.read()
                img = open_image(BytesIO(raw))
                fmt = img.format or "PNG"
                self.url = self._data_url_from_bytes(raw, fmt)
            finally:
                if pos is not None and hasattr(stream, "seek"):
                    with suppress(Exception):
                        stream.seek(pos)
            return

        # If we reach here, the input type isn't supported
        raise TypeError(
            "Unsupported Image input type. Provide a URL/path string, data URL, bytes, "
            "BytesIO, file-like object, os.PathLike, or PIL.Image.Image."
        )

    def _format_to_mime(self, fmt: str | None) -> str:
        """Map a PIL format name to a MIME type with sensible fallbacks."""
        fmt = (fmt or "PNG").upper()
        if fmt == "WEBP":
            return "image/webp"
        if fmt == "JPEG" or fmt == "JPG":
            return "image/jpeg"
        if fmt == "PNG":
            return "image/png"
        # Try mimetypes (uses extension mapping)
        mime = mimetypes.types_map.get("." + fmt.lower())
        return mime or "image/png"

    def _data_url_from_bytes(self, data: bytes, fmt: str | None) -> str:
        mime = self.mime_type or self._format_to_mime(fmt)
        # Ensure mime_type is set on the instance for downstream usage
        self.mime_type = mime
        b64 = base64.b64encode(data).decode("utf-8")
        return f"data:{mime};base64,{b64}"

    def to_dict(self) -> list[dict]:
        """Convert the image to a dictionary."""
        image_url = {"url": self.url}
        if self.mime_type:
            image_url["format"] = self.mime_type
        return [
            {
                "type": "image_url",
                "image_url": image_url,
            }
        ]


# Ref: https://cookbook.openai.com/examples/gpt_with_vision_for_video_understanding
@dataclass
class Video(Media):
    """Class representing a video."""

    path: str
    fps: int = 1
    _base64frames: list[str] | None = None

    def __post_init__(self) -> None:
        """Post-initialization to ensure the path is a string."""
        if not os.path.exists(self.path):
            raise ValueError(f"Video file does not exist: {self.path}")

    def load_frames(self) -> None:
        """Load video frames as base64-encoded images."""
        try:
            import cv2
        except ImportError:
            raise ImportError(
                "OpenCV is required to process video files."
                "Install `pip install byllm[video]` for video capabilities."
            )

        self._base64frames = []
        video = cv2.VideoCapture(self.path)
        total_frames = int(video.get(cv2.CAP_PROP_FRAME_COUNT))

        target_fps = self.fps
        source_fps = video.get(cv2.CAP_PROP_FPS)
        frames_to_skip = (
            int(source_fps / target_fps) - 1 if target_fps < source_fps else 1
        )

        curr_frame = 0
        while curr_frame < total_frames - 1:
            video.set(cv2.CAP_PROP_POS_FRAMES, curr_frame)
            success, frame = video.read()
            if not success:
                raise ValueError("Failed to read video frame.")
            _, buffer = cv2.imencode(".jpg", frame)
            self._base64frames.append(base64.b64encode(buffer).decode("utf-8"))
            curr_frame += frames_to_skip

    def to_dict(self) -> list[dict]:
        """Convert the video to a dictionary."""
        if self._base64frames is None:
            self.load_frames()
        assert (
            self._base64frames is not None
        ), "Frames must be loaded before conversion."

        return [
            {
                "type": "image_url",
                "image_url": f"data:image/jpeg;base64,{frame}",
            }
            for frame in self._base64frames
        ]
