#-------------------------------------------------------------------------------
# Media Implementations
#-------------------------------------------------------------------------------
"""Convert the content to a dictionary. Subclasses must implement."""
impl Media.to_dict -> list[dict] {
    raise NotImplementedError("Subclasses must implement this method.") ;
}

#-------------------------------------------------------------------------------
# Text
#-------------------------------------------------------------------------------
"""Convert the text content to a dictionary."""
impl Text.to_dict -> list[dict] {
    return [{"type": "text", "text": self.text}];
}

#-------------------------------------------------------------------------------
# Image
#-------------------------------------------------------------------------------
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
impl Image.postinit -> None {
    value = self.url;
    # Handle path-like inputs by converting to string
    if isinstance(value, os.PathLike) {
        value = os.fspath(value);
    }
    # Remote or data URLs: keep as-is (trim whitespace)
    if isinstance(value, str) {
        s = value.strip();
        if s.startswith(("http://", "https://", "gs://", "data:")) {
            self.url = s;
            return;
        }
        # Treat as local file path
        if not os.path.exists(s) {
            raise ValueError(f"Image file does not exist: {s}") ;
        }
        image = open_image(s);
        fmt = image.format or "PNG";
        # Determine MIME type with WEBP special-case for py<3.13
        self.mime_type = self._format_to_mime(fmt);
        with BytesIO() as buffer {
            image.save(buffer, format=fmt);
            data = buffer.getvalue();
            self.url = self._data_url_from_bytes(data, fmt);
            return;
        }
    }
    # PIL Image instance
    if isinstance(value, PILImageCls) {
        fmt = value.format or "PNG";
        with BytesIO() as buffer {
            value.save(buffer, format=fmt);
            data = buffer.getvalue();
            self.url = self._data_url_from_bytes(data, fmt);
            return;
        }
    }
    # Bytes-like object
    if isinstance(value, (bytes, bytearray, memoryview)) {
        raw = bytes(value);
        # Probe format via PIL to set correct MIME
        img = open_image(BytesIO(raw));
        fmt = img.format or "PNG";
        # Use bytes as-is (avoid re-encode) if PIL detects same format as content
        # Otherwise, re-encode to the detected format to be safe.
        try {
            self.url = self._data_url_from_bytes(raw, fmt);
        } except Exception {
            with BytesIO() as buffer {
                img.save(buffer, format=fmt);
                self.url = self._data_url_from_bytes(buffer.getvalue(), fmt);
            }
        }
        return;
    }
    # File-like object (e.g., BytesIO, IO[bytes])
    if value?.read and callable(value?.read) {
        # Safely read without permanently moving the cursor
        stream: IO[bytes] = value;  # type: ignore[assignment]
        pos = None;
        try {
            pos = stream.tell();  # type: ignore[attr-defined]
        } except Exception {
            pos = None;
        }
        try {
            # Prefer getvalue if available (e.g., BytesIO)
            if stream?.getvalue and callable(stream?.getvalue) {
                raw = stream.getvalue();  # type: ignore[call-arg]
            } else {
                if stream?.seek {
                    with suppress(Exception) {
                        stream.seek(0);
                    }
                }
                raw = stream.read();
            }
            img = open_image(BytesIO(raw));
            fmt = img.format or "PNG";
            self.url = self._data_url_from_bytes(raw, fmt);
        } finally {
            if pos is not None and stream?.seek {
                with suppress(Exception) {
                    stream.seek(pos);
                }
            }
        }
        return;
    }
    # If we reach here, the input type isn't supported
    raise TypeError(
        "Unsupported Image input type. Provide a URL/path string, data URL, bytes, "
        "BytesIO, file-like object, os.PathLike, or PIL.Image.Image."
    ) ;
}

"""Map a PIL format name to a MIME type with sensible fallbacks."""
impl Image._format_to_mime(fmt: str | None) -> str {
    fmt = (fmt or "PNG").upper();
    if fmt == "WEBP" {
        return "image/webp";
    }
    if fmt == "JPEG" or fmt == "JPG" {
        return "image/jpeg";
    }
    if fmt == "PNG" {
        return "image/png";
    }
    # Try mimetypes (uses extension mapping)
    mime = mimetypes.types_map.get("." + fmt.lower());
    return mime or "image/png";
}

"""Create a data URL from raw bytes with the appropriate MIME type."""
impl Image._data_url_from_bytes(data: bytes, fmt: str | None) -> str {
    mime = self.mime_type or self._format_to_mime(fmt);
    # Ensure mime_type is set on the instance for downstream usage
    self.mime_type = mime;
    b64 = base64.b64encode(data).decode("utf-8");
    return f"data:{mime};base64,{b64}";
}

"""Convert the image to a dictionary for LLM API calls."""
impl Image.to_dict -> list[dict] {
    image_url = {"url": self.url};
    if self.mime_type {
        image_url["format"] = self.mime_type;
    }
    return [{"type": "image_url", "image_url": image_url,}];
}

#-------------------------------------------------------------------------------
# Video
#-------------------------------------------------------------------------------
"""Validate that the video path exists."""
impl Video.postinit -> None {
    if not os.path.exists(self.path) {
        raise ValueError(f"Video file does not exist: {self.path}") ;
    }
}

"""Load video frames as base64-encoded images at the specified FPS."""
impl Video.load_frames -> None {
    try {
        import cv2;
    } except ImportError {
        raise ImportError(
            "OpenCV is required to process video files. "
            "Install `pip install byllm[video]` for video capabilities."
        ) ;
    }
    self._base64frames = [];
    video = cv2.VideoCapture(self.path);
    total_frames = int(video.get(cv2.CAP_PROP_FRAME_COUNT));
    target_fps = self.fps;
    source_fps = video.get(cv2.CAP_PROP_FPS);
    frames_to_skip = (
        int(source_fps / target_fps) - 1 if target_fps < source_fps else 1
    );
    curr_frame = 0;
    while curr_frame < total_frames - 1 {
        video.set(cv2.CAP_PROP_POS_FRAMES, curr_frame);
        (success, frame) = video.read();
        if not success {
            raise ValueError("Failed to read video frame.") ;
        }
        (_, buffer) = cv2.imencode(".jpg", frame);
        self._base64frames.append(base64.b64encode(buffer).decode("utf-8"));
        curr_frame += frames_to_skip;
    }
}

"""Convert the video frames to a list of image dictionaries."""
impl Video.to_dict -> list[dict] {
    if self._base64frames is None {
        self.load_frames();
    }
    assert (self._base64frames is not None) , "Frames must be loaded before conversion.";
    return [
        {"type": "image_url", "image_url": f"data:image/jpeg;base64,{frame}",}
        for frame in self._base64frames
    ];
}
