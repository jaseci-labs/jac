obj InputNormalizer {
    has buffer: str = "",
        paste_mode: bool = False,
        paste_buffer: str = "",
        pending_resize: ResizeEvent | None = None,
        pending_mouse: MouseEvent | None = None,
        pending_stream: str = "",
        esc_timeout_ms: int = 50,
        esc_armed_at_ms: float = -1.0;

    def feed(data: str) -> list[HostEvent];
    def arm_esc(now_ms: float);
    def flush_esc_timeout(now_ms: float) -> list[HostEvent];
    def feed_resize(width: int, height: int);
    def feed_stream(text: str);
    def flush_buffer -> list[HostEvent];
    def flush_coalesced -> list[HostEvent];
    def clear;
}


def coalesce_events(events: list[HostEvent]) -> list[HostEvent];

impl InputNormalizer.feed(data: str) -> list[HostEvent] {
    if not data and not self.buffer {
        return [];
    }
    out: list[HostEvent] = [];
    pending = data;

    while True {
        self.buffer += pending;
        if self.paste_mode {
            self.paste_buffer += self.buffer;
            self.buffer = "";
            end_idx = self.paste_buffer.find(BRACKETED_PASTE_END);
            if end_idx != -1 {
                pasted = self.paste_buffer[0:end_idx];
                remaining = self.paste_buffer[end_idx + len(BRACKETED_PASTE_END):];
                self.paste_mode = False;
                self.paste_buffer = "";
                out.append(PasteEvent(text=pasted));
                if remaining {
                    pending = remaining;
                    continue;
                }
            }
            return out;
        }
        start_idx = self.buffer.find(BRACKETED_PASTE_START);
        if start_idx != -1 {
            if start_idx > 0 {
                before = self.buffer[0:start_idx];
                extracted = extract_sequences(before);
                for seq in extracted["sequences"] {
                    out.append(decode_sequence(str(seq)));
                }
            }
            self.buffer = self.buffer[start_idx + len(BRACKETED_PASTE_START):];
            self.paste_mode = True;
            self.paste_buffer = self.buffer;
            self.buffer = "";
            end_idx = self.paste_buffer.find(BRACKETED_PASTE_END);
            if end_idx != -1 {
                pasted = self.paste_buffer[0:end_idx];
                remaining = self.paste_buffer[end_idx + len(BRACKETED_PASTE_END):];
                self.paste_mode = False;
                self.paste_buffer = "";
                out.append(PasteEvent(text=pasted));
                if remaining {
                    pending = remaining;
                    continue;
                }
            }
            return out;
        }
        break;
    }
    extracted = extract_sequences(self.buffer);
    self.buffer = str(extracted["remainder"]);
    for seq in extracted["sequences"] {
        event = decode_sequence(str(seq));
        if isinstance(event, MouseEvent) and event.motion {
            self.pending_mouse = event;
        } else {
            out.append(event);
        }
    }

    if self.buffer == ESC {
        if self.esc_armed_at_ms < 0.0 {
            self.esc_armed_at_ms = 0.0;
        }
    } else {
        self.esc_armed_at_ms = -1.0;
    }
    return out;
}

impl InputNormalizer.arm_esc(now_ms: float) {
    if self.buffer == ESC {
        self.esc_armed_at_ms = now_ms;
    }
}

impl InputNormalizer.flush_esc_timeout(now_ms: float) -> list[HostEvent] {
    if self.buffer != ESC {
        return [];
    }
    if self.esc_armed_at_ms < 0.0 {
        return [];
    }
    if now_ms - self.esc_armed_at_ms < float(self.esc_timeout_ms) {
        return [];
    }
    self.buffer = "";
    self.esc_armed_at_ms = -1.0;
    return [KeyEvent(key="escape")];
}

impl InputNormalizer.feed_resize(width: int, height: int) {
    self.pending_resize = ResizeEvent(width=width, height=height);
}

impl InputNormalizer.feed_stream(text: str) {
    if text {
        self.pending_stream += text;
    }
}

impl InputNormalizer.flush_buffer -> list[HostEvent] {
    out: list[HostEvent] = [];
    if self.buffer {
        out.append(decode_sequence(self.buffer));
        self.buffer = "";
    }
    self.esc_armed_at_ms = -1.0;
    if self.paste_mode and self.paste_buffer {
        out.append(PasteEvent(text=self.paste_buffer));
        self.paste_mode = False;
        self.paste_buffer = "";
    }
    return out;
}

impl InputNormalizer.flush_coalesced -> list[HostEvent] {
    out: list[HostEvent] = [];
    if self.pending_resize is not None {
        out.append(self.pending_resize as HostEvent);
        self.pending_resize = None;
    }
    if self.pending_mouse is not None {
        out.append(self.pending_mouse as HostEvent);
        self.pending_mouse = None;
    }
    if self.pending_stream {
        out.append(StreamChunkEvent(text=self.pending_stream));
        self.pending_stream = "";
    }
    return out;
}

impl InputNormalizer.clear {
    self.buffer = "";
    self.paste_mode = False;
    self.paste_buffer = "";
    self.pending_resize = None;
    self.pending_mouse = None;
    self.pending_stream = "";
    self.esc_armed_at_ms = -1.0;
}


impl coalesce_events(events: list[HostEvent]) -> list[HostEvent] {
    out: list[HostEvent] = [];
    last_resize: ResizeEvent | None = None;
    last_mouse: MouseEvent | None = None;
    stream_acc = "";
    for event in events {
        if isinstance(event, ResizeEvent) {
            last_resize = event;
            continue;
        }
        if isinstance(event, MouseEvent) and event.motion {
            last_mouse = event;
            continue;
        }
        if isinstance(event, StreamChunkEvent) {
            stream_acc += event.text;
            continue;
        }

        if last_resize is not None {
            out.append(last_resize as HostEvent);
            last_resize = None;
        }
        if last_mouse is not None {
            out.append(last_mouse as HostEvent);
            last_mouse = None;
        }
        if stream_acc {
            out.append(StreamChunkEvent(text=stream_acc));
            stream_acc = "";
        }
        out.append(event);
    }
    if last_resize is not None {
        out.append(last_resize as HostEvent);
    }
    if last_mouse is not None {
        out.append(last_mouse as HostEvent);
    }
    if stream_acc {
        out.append(StreamChunkEvent(text=stream_acc));
    }
    return out;
}
