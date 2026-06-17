"""TUI palette — canonical RGB values and SGR attribute bitmasks.

Import these constants in rendering modules; use them in ansi_sgr() calls
inside function bodies (not at glob-init with libc). The hardcoded SGR string
globs in screen.na.jac are generated from these same values.

Palette inspiration: Dracula-ish dark with semantic accents.
"""

# ── Background ────────────────────────────────────────────────────────────────
glob TH_BG_R: int = 18,
     TH_BG_G: int = 18,
     TH_BG_B: int = 28;

# ── Chrome (borders, dim UI) ──────────────────────────────────────────────────
glob TH_BORDER_R: int = 70,
     TH_BORDER_G: int = 70,
     TH_BORDER_B: int = 100;

# ── User messages ─────────────────────────────────────────────────────────────
glob TH_USER_BG_R: int = 26,
     TH_USER_BG_G: int = 26,
     TH_USER_BG_B: int = 46;
glob TH_USER_R: int = 255,
     TH_USER_G: int = 255,
     TH_USER_B: int = 255;

# ── Assistant answer ──────────────────────────────────────────────────────────
glob TH_ANSWER_R: int = 220,
     TH_ANSWER_G: int = 220,
     TH_ANSWER_B: int = 220;

# ── Reasoning / thinking ──────────────────────────────────────────────────────
glob TH_REASON_R: int = 160,
     TH_REASON_G: int = 160,
     TH_REASON_B: int = 160;

# ── System / info ─────────────────────────────────────────────────────────────
glob TH_SYSTEM_R: int = 86,
     TH_SYSTEM_G: int = 182,
     TH_SYSTEM_B: int = 194;

# ── Error ─────────────────────────────────────────────────────────────────────
glob TH_ERROR_R: int = 255,
     TH_ERROR_G: int = 80,
     TH_ERROR_B: int = 80;

# ── Phase label ───────────────────────────────────────────────────────────────
glob TH_PHASE_R: int = 255,
     TH_PHASE_G: int = 210,
     TH_PHASE_B: int = 60;

# ── Tool call ─────────────────────────────────────────────────────────────────
glob TH_CALL_R: int = 204,
     TH_CALL_G: int = 119,
     TH_CALL_B: int = 255;

# ── Tool result ───────────────────────────────────────────────────────────────
glob TH_RESULT_R: int = 140,
     TH_RESULT_G: int = 140,
     TH_RESULT_B: int = 140;

# ── Header accents ────────────────────────────────────────────────────────────
glob TH_TITLE_R: int = 204,
     TH_TITLE_G: int = 0,
     TH_TITLE_B: int = 204;
glob TH_CWD_R: int = 86,
     TH_CWD_G: int = 182,
     TH_CWD_B: int = 194;
glob TH_MODEL_R: int = 120,
     TH_MODEL_G: int = 120,
     TH_MODEL_B: int = 120;

# ── Status indicator ──────────────────────────────────────────────────────────
glob TH_STATUS_IDLE_R: int = 140,
     TH_STATUS_IDLE_G: int = 140,
     TH_STATUS_IDLE_B: int = 140;
glob TH_STATUS_RUN_R: int = 255,
     TH_STATUS_RUN_G: int = 200,
     TH_STATUS_RUN_B: int = 50;
glob TH_STATUS_OK_R: int = 80,
     TH_STATUS_OK_G: int = 200,
     TH_STATUS_OK_B: int = 80;
glob TH_STATUS_STOP_R: int = 255,
     TH_STATUS_STOP_G: int = 80,
     TH_STATUS_STOP_B: int = 80;

# ── SGR attribute bitmasks (for ansi_sgr attrs parameter) ─────────────────────
# bit 0 = bold (1), bit 1 = dim (2), bit 2 = italic (4)
glob TH_NONE: int = 0,
     TH_BOLD: int = 1,
     TH_DIM: int = 2,
     TH_ITALIC: int = 4;
glob TH_DIM_ITALIC: int = 6;
