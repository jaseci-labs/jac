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
