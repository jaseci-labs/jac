"""Wire-protocol vocabulary shared with the embed host (ai_tui/ipc_schema.jac).

Three families in one block: FIELD_* header keys on frame lines, FTYPE_*
values of the TYPE field (FTYPE_DELTA is host-emitted; no na module reads it
yet), and CMD_* command verbs sent back to the host. FRAME_SEP both frames
commands and terminates unlabelled bodies (see blob_reader).
"""
# FROZEN SHAPE: a CI parity test (jac/tests/cli/test_ai_tui_bridge.jac)
# regex-scrapes every typed quoted value in this file and diffs the set
# against the host's ipc_schema.jac. Keep each constant in exactly its
# current one-line form, and never add another line whose text looks like a
# typed string glob — comments and docstrings included — or the scraper
# will pick up phantom values.
glob FIELD_TYPE: str = "TYPE",
     FIELD_STATUS: str = "STATUS",
     FIELD_ACTIVE: str = "ACTIVE",
     FIELD_MODEL: str = "MODEL",
     FIELD_NEEDS_KEY: str = "NEEDS_KEY",
     FIELD_KEY_ENV: str = "KEY_ENV",
     FIELD_EV: str = "EV",
     FIELD_EVA: str = "EVA",
     FIELD_LEN: str = "L",
     FTYPE_FULL: str = "full",
     FTYPE_DELTA: str = "delta",
     FTYPE_HB: str = "hb",
     CMD_SEND: str = "SEND",
     CMD_STOP: str = "STOP",
     CMD_RESET: str = "RESET",
     CMD_QUIT: str = "QUIT",
     CMD_APPLY: str = "APPLY",
     FRAME_SEP: str = "---";
