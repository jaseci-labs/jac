def _is_complete_csi(data: str) -> str;


def _is_complete_osc(data: str) -> str;


def sequence_status(data: str) -> str;


def extract_sequences(buffer: str) -> dict[str, list[str] | str];


glob LEGACY_KEYS: dict[str, str] = {
         "\x1b[A": "up",
         "\x1bOA": "up",
         "\x1b[B": "down",
         "\x1bOB": "down",
         "\x1b[C": "right",
         "\x1bOC": "right",
         "\x1b[D": "left",
         "\x1bOD": "left",
         "\x1b[H": "home",
         "\x1bOH": "home",
         "\x1b[F": "end",
         "\x1bOF": "end",
         "\x1b[3~": "delete",
         "\x1b[2~": "insert",
         "\x1b[5~": "page_up",
         "\x1b[6~": "page_down",
         "\x1bOP": "f1",
         "\x1bOQ": "f2",
         "\x1bOR": "f3",
         "\x1bOS": "f4",
         "\x1b[15~": "f5",
         "\x1b[17~": "f6",
         "\x1b[18~": "f7",
         "\x1b[19~": "f8",
         "\x1b[20~": "f9",
         "\x1b[21~": "f10",
         "\x1b[23~": "f11",
         "\x1b[24~": "f12",

     };


def _parse_sgr_mouse(seq: str) -> MouseEvent | None;


glob MODIFIER_NAMES: dict[int, str] = {
         2: "shift",
         3: "alt",
         4: "alt+shift",
         5: "ctrl",
         6: "ctrl+shift",

     };


def _modified_key(modifier: int, base: str) -> str | None;


glob CSI_LETTER_KEYS: dict[str, str] = {
         "A": "up",
         "B": "down",
         "C": "right",
         "D": "left",
         "H": "home",
         "F": "end",

     };


def _parse_modified_csi(seq: str) -> KeyEvent | None;


def decode_sequence(seq: str) -> HostEvent;

def _parse_int_seq(text: str, start: int) -> list[int] | None;


def _match_sgr_mouse_body(payload: str) -> bool;


def _parse_sgr_mouse_native(seq: str) -> MouseEvent | None;


def _parse_modified_letter_csi(seq: str) -> tuple[int, str] | None;

def _parse_modified_digit_csi(seq: str) -> tuple[int, int] | None;

impl _is_complete_csi(data: str) -> str {
    if not data.startswith(ESC + "[") {
        return "complete";
    }
    if len(data) < 3 {
        return "incomplete";
    }
    payload = data[2:];
    last = payload[len(payload) - 1];
    code = ord(last);
    if code >= 64 and code <= 126 {
        if payload.startswith("<") {
            if _match_sgr_mouse_body(payload) {
                return "complete";
            }
            if last == "M" or last == "m" {
                return "incomplete";
            }
            return "incomplete";
        }
        return "complete";
    }
    return "incomplete";
}


impl _is_complete_osc(data: str) -> str {
    if not data.startswith(ESC + "]") {
        return "complete";
    }
    if data.endswith(ESC + "\\") or data.endswith("\x07") {
        return "complete";
    }
    return "incomplete";
}


impl sequence_status(data: str) -> str {
    if not data.startswith(ESC) {
        return "not-escape";
    }
    if len(data) == 1 {
        return "incomplete";
    }
    after = data[1:];
    if after.startswith("[") {
        if after.startswith("[M") {
            return "complete" if len(data) >= 6 else "incomplete";
        }
        return _is_complete_csi(data);
    }
    if after.startswith("]") {
        return _is_complete_osc(data);
    }
    if after.startswith("P") or after.startswith("_") {
        if data.endswith(ESC + "\\") or data.endswith("\x07") {
            return "complete";
        }
        return "incomplete";
    }
    if after.startswith("O") {
        return "complete" if len(after) >= 2 else "incomplete";
    }
    if len(after) == 1 {
        return "complete";
    }
    return "complete";
}


impl extract_sequences(buffer: str) -> dict[str, list[str] | str] {
    sequences: list[str] = [];
    pos = 0;
    while pos < len(buffer) {
        remaining = buffer[pos:];
        if remaining.startswith(ESC) {
            seq_end = 1;
            while seq_end <= len(remaining) {
                candidate = remaining[0:seq_end];
                status = sequence_status(candidate);
                if status == "complete" {
                    sequences.append(candidate);
                    pos += seq_end;
                    break;
                } elif status == "incomplete" {
                    seq_end += 1;
                } else {
                    sequences.append(candidate);
                    pos += seq_end;
                    break;
                }
            }
            if seq_end > len(remaining) {
                return {"sequences": sequences, "remainder": remaining};
            }
        } else {
            sequences.append(remaining[0]);
            pos += 1;
        }
    }
    return {"sequences": sequences, "remainder": ""};
}


impl _parse_sgr_mouse(seq: str) -> MouseEvent | None {
    return _parse_sgr_mouse_native(seq);
}


impl _modified_key(modifier: int, base: str) -> str | None {
    prefix = MODIFIER_NAMES.get(modifier);
    if prefix is None {
        return None;
    }
    return prefix + "+" + base;
}


impl _parse_modified_csi(seq: str) -> KeyEvent | None {
    lr = _parse_modified_letter_csi(seq);
    if lr is not None {
        (modifier, base) = lr;
        key_name = _modified_key(modifier, base);
        if key_name is not None {
            return KeyEvent(key=key_name);
        }
        return None;
    }
    dr = _parse_modified_digit_csi(seq);
    if dr is not None {
        (digit, modifier) = dr;
        plain = "\x1b[" + str(digit) + "~";
        if plain in LEGACY_KEYS {
            key_name = _modified_key(modifier, LEGACY_KEYS[plain]);
            if key_name is not None {
                return KeyEvent(key=key_name);
            }
        }
    }
    return None;
}


impl decode_sequence(seq: str) -> HostEvent {
    if not seq {
        return TextEvent(text="");
    }
    if seq in LEGACY_KEYS {
        return KeyEvent(key=LEGACY_KEYS[seq]);
    }
    mouse = _parse_sgr_mouse(seq);
    if mouse is not None {
        return mouse;
    }
    modified = _parse_modified_csi(seq);
    if modified is not None {
        return modified;
    }
    if seq == "\r" or seq == "\n" {
        return KeyEvent(key="enter");
    }
    if seq == "\t" {
        return KeyEvent(key="tab");
    }
    if seq == "\x1b[Z" {
        return KeyEvent(key="shift+tab");
    }
    if seq == "\x7f" or seq == "\b" {
        return KeyEvent(key="backspace");
    }
    if seq == "\x1b" {
        return KeyEvent(key="escape");
    }
    if seq == "\x03" {
        return KeyEvent(key="ctrl+c");
    }
    if seq == "\x04" {
        return KeyEvent(key="ctrl+d");
    }
    if seq == "\x01" {
        return KeyEvent(key="ctrl+a");
    }
    if seq == "\x05" {
        return KeyEvent(key="ctrl+e");
    }
    if seq == "\x15" {
        return KeyEvent(key="ctrl+u");
    }
    if seq == "\x0b" {
        return KeyEvent(key="ctrl+k");
    }
    if seq == "\x17" {
        return KeyEvent(key="ctrl+w");
    }
    if seq == "\x00" {
        return KeyEvent(key="ctrl+space");
    }
    if len(seq) == 1 and 1 <= ord(seq) <= 26 {
        return KeyEvent(key="ctrl+" + chr(ord(seq) + 96));
    }
    if seq == "\x1f" {
        return KeyEvent(key="ctrl+/");
    }

    if len(seq) == 2 and seq[0] == ESC and seq[1] != "[" and seq[1] != "O" {
        return KeyEvent(key="alt+" + seq[1]);
    }
    if len(seq) == 1 and ord(seq[0]) >= 32 {
        return TextEvent(text=seq);
    }

    if seq.startswith(ESC) {
        return KeyEvent(key="unknown:" + repr(seq));
    }
    return TextEvent(text=seq);
}

impl _parse_int_seq(text: str, start: int) -> list[int] | None {
    out: list[int] = [];
    i = start;
    n = len(text);
    expect_int = True;
    while i < n {
        if expect_int {
            j = i;
            while j < n and text[j] >= "0" and text[j] <= "9" {
                j += 1;
            }
            if j == i {
                return None;
            }
            out.append(int(text[i:j]));
            i = j;
            expect_int = False;
        } else {
            if text[i] != ";" {
                return None;
            }
            i += 1;
            expect_int = True;
        }
    }
    if expect_int {
        return None;
    }
    return out;
}


impl _match_sgr_mouse_body(payload: str) -> bool {
    if not payload.startswith("<") or len(payload) < 5 {
        return False;
    }
    last = payload[len(payload) - 1];
    if last != "M" and last != "m" {
        return False;
    }
    parts = _parse_int_seq(payload[0:len(payload) - 1], 1);
    if parts is None or len(parts) != 3 {
        return False;
    }
    return True;
}


impl _parse_sgr_mouse_native(seq: str) -> MouseEvent | None {
    if not seq.startswith("\x1b[<") or len(seq) < 8 {
        return None;
    }
    last = seq[len(seq) - 1];
    if last != "M" and last != "m" {
        return None;
    }
    parts = _parse_int_seq(seq[0:len(seq) - 1], 3);
    if parts is None or len(parts) != 3 {
        return None;
    }
    button = parts[0];
    x = parts[1];
    y = parts[2];
    pressed = last == "M";
    motion = (button & 32) != 0;
    return MouseEvent(button=button & ~32, x=x, y=y, pressed=pressed, motion=motion,);
}


impl _parse_modified_letter_csi(seq: str) -> tuple[int, str] | None {
    if not seq.startswith("\x1b[") {
        return None;
    }
    inner = seq[2:];
    semi = inner.find(";");
    if semi < 0 or semi + 2 >= len(inner) {
        return None;
    }
    head = inner[:semi];
    tail = inner[semi + 1:];
    if head != "" and head != "1" {
        return None;
    }
    if len(tail) != 2 {
        return None;
    }
    for ch in tail[0:1] {
        if ch < "0" or ch > "9" {
            return None;
        }
    }
    base = CSI_LETTER_KEYS.get(tail[1]);
    if base is None {
        return None;
    }
    mod_str = tail[0:1];
    return (int(mod_str), base);
}

impl _parse_modified_digit_csi(seq: str) -> tuple[int, int] | None {
    if not seq.startswith("\x1b[") or len(seq) < 6 {
        return None;
    }
    if seq[len(seq) - 1] != "~" {
        return None;
    }
    semi = seq.find(";", 2);
    if semi < 0 {
        return None;
    }
    n_str = seq[2:semi];
    m_str = seq[semi + 1:len(seq) - 1];
    if not n_str or not m_str {
        return None;
    }
    for ch in n_str {
        if ch < "0" or ch > "9" {
            return None;
        }
    }
    for ch in m_str {
        if ch < "0" or ch > "9" {
            return None;
        }
    }
    return (int(n_str), int(m_str));
}
