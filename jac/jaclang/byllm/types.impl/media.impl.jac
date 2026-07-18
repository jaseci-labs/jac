impl Media.to_dict -> list[dict] {
    raise NotImplementedError("Subclasses must implement this method.");
}

impl Text.to_dict -> list[dict] {
    return [{"type": "text", "text": self.text}];
}

impl Image.postinit -> None {
    value = self.url;

    if isinstance(value, os.PathLike) {
        value = os.fspath(value);
    }

    if isinstance(value, str) {
        s = value.strip();
        if s.startswith(("http://", "https://", "gs://", "data:")) {
            self.url = s;
            return;
        }

        if not os.path.exists(s) {
            raise ValueError(f"Image file does not exist: {s}");
        }
        image = open_image(s);
        fmt = image.format or "PNG";

        self.mime_type = self._format_to_mime(fmt);
        with BytesIO() as buffer {
            image.save(buffer, format=fmt);
            data = buffer.getvalue();
            self.url = self._data_url_from_bytes(data, fmt);
            return;
        }
    }

    if isinstance(value, PILImageCls) {
        fmt = value.format or "PNG";
        with BytesIO() as buffer {
            value.save(buffer, format=fmt);
            data = buffer.getvalue();
            self.url = self._data_url_from_bytes(data, fmt);
            return;
        }
    }

    if isinstance(value, (bytes, bytearray, memoryview)) {
        raw = bytes(value);

        img = open_image(BytesIO(raw));
        fmt = img.format or "PNG";

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

    if value?.read and callable(value?.read) {
        stream: IO[bytes] = value;
        pos = None;
        try {
            pos = stream.tell();
        } except Exception {
            pos = None;
        }
        try {
            if stream?.getvalue and callable(stream?.getvalue) {
                raw = stream.getvalue();
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

    raise TypeError(
        "Unsupported Image input type. Provide a URL/path string, data URL, bytes, "
        "BytesIO, file-like object, os.PathLike, or PIL.Image.Image."
    );
}

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

    mime = mimetypes.types_map.get("." + fmt.lower());
    return mime or "image/png";
}

impl Image._data_url_from_bytes(data: bytes, fmt: str | None) -> str {
    mime = self.mime_type or self._format_to_mime(fmt);

    self.mime_type = mime;
    b64 = base64.b64encode(data).decode("utf-8");
    return f"data:{mime};base64,{b64}";
}

impl Image.to_dict -> list[dict] {
    image_url = {"url": self.url};
    if self.mime_type {
        image_url["format"] = self.mime_type;
    }
    return [{"type": "image_url", "image_url": image_url,}];
}

impl Video.postinit -> None {
    if not os.path.exists(self.path) {
        raise ValueError(f"Video file does not exist: {self.path}");
    }
}

impl Video.load_frames -> None {
    try {
        import cv2;
    } except ImportError {
        raise ImportError(
            "OpenCV is required to process video files. "
            "Install `jac install 'byllm[video]'` for video capabilities."
        );
    }
    self._base64frames = [];
    video = cv2.VideoCapture(self.path);
    total_frames = int(video.get(cv2.CAP_PROP_FRAME_COUNT));
    target_fps = self.fps;
    source_fps = video.get(cv2.CAP_PROP_FPS);
    frames_to_skip = int(source_fps / target_fps) - 1 if target_fps < source_fps else 1;
    curr_frame = 0;
    while curr_frame < total_frames - 1 {
        video.set(cv2.CAP_PROP_POS_FRAMES, curr_frame);
        (success, frame) = video.read();
        if not success {
            raise ValueError("Failed to read video frame.");
        }
        (_, buffer) = cv2.imencode(".jpg", frame);
        self._base64frames.append(base64.b64encode(buffer).decode("utf-8"));
        curr_frame += frames_to_skip;
    }
}

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
