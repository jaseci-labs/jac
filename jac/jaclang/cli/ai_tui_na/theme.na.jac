"""Color palette and precomposed SGR styles for the TUI.

Colors are Rgb records (terminal.na.jac owns the Rgb type and the escape
composers). The TH_SGR_* globs are fully composed escape strings for the
fixed fg/bg/attr combinations the widgets paint with; they are composed
HERE, in theme's own glob init, because an imported obj glob is still None
while another module's glob init runs (na cross-module init-order hazard).
Consumers must only touch the Rgb globs at function scope.
"""

import from .terminal { Rgb, ansi_sgr, ansi_bg }

# --- attribute bitflags (wire values frozen; ansi_sgr maps 1->;1 2->;2 4->;3) ---

glob TH_NONE: int = 0,
     TH_BOLD: int = 1,
     TH_DIM: int = 2,
     TH_ITALIC: int = 4;
glob TH_DIM_ITALIC: int = 6;  # TH_DIM | TH_ITALIC, precomputed literal

# --- palette ---

glob TH_BG: Rgb = Rgb(r=18, g=18, b=28),
     TH_BORDER: Rgb = Rgb(r=70, g=70, b=100),
     TH_USER_BG: Rgb = Rgb(r=26, g=26, b=46),
     TH_USER: Rgb = Rgb(r=255, g=255, b=255),
     TH_ANSWER: Rgb = Rgb(r=220, g=220, b=220),
     TH_REASON: Rgb = Rgb(r=160, g=160, b=160),
     TH_SYSTEM: Rgb = Rgb(r=86, g=182, b=194),
     TH_LOGO: Rgb = Rgb(r=86, g=182, b=194),
     TH_ERROR: Rgb = Rgb(r=255, g=80, b=80),
     TH_PHASE: Rgb = Rgb(r=255, g=210, b=60),
     TH_CALL: Rgb = Rgb(r=204, g=119, b=255),
     TH_RESULT: Rgb = Rgb(r=140, g=140, b=140);

glob TH_TITLE: Rgb = Rgb(r=204, g=0, b=204),
     TH_CWD: Rgb = Rgb(r=86, g=182, b=194),
     TH_MODEL: Rgb = Rgb(r=120, g=120, b=120);

glob TH_AC_SEL_BG: Rgb = Rgb(r=36, g=36, b=60),
     TH_AC_SEL_DESC: Rgb = Rgb(r=180, g=180, b=220),
     TH_AC_DESC: Rgb = Rgb(r=100, g=100, b=100);

glob TH_STATUS_IDLE: Rgb = Rgb(r=140, g=140, b=140),
     TH_STATUS_RUN: Rgb = Rgb(r=255, g=200, b=50),
     TH_STATUS_OK: Rgb = Rgb(r=80, g=200, b=80),
     TH_STATUS_STOP: Rgb = Rgb(r=255, g=80, b=80);

glob TH_MD_H1: Rgb = Rgb(r=255, g=215, b=100),
     TH_MD_H2: Rgb = Rgb(r=130, g=200, b=255),
     TH_MD_H3: Rgb = Rgb(r=150, g=220, b=180),
     TH_MD_CODE: Rgb = Rgb(r=190, g=190, b=210),
     TH_MD_CODE_BG: Rgb = Rgb(r=28, g=28, b=45),
     TH_MD_FENCE: Rgb = Rgb(r=100, g=100, b=140),
     TH_MD_BQ: Rgb = Rgb(r=170, g=190, b=210),
     TH_MD_BQ_BAR: Rgb = Rgb(r=80, g=120, b=160),
     TH_MD_HR: Rgb = Rgb(r=70, g=70, b=100);

# --- precomposed SGR styles (escape bytes frozen — see module docstring) ---

glob TH_SGR_BG: str = ansi_bg(TH_BG),
     TH_SGR_BORDER: str = ansi_sgr(TH_BORDER, TH_BG, TH_NONE),
     TH_SGR_BORDER_DIM: str = ansi_sgr(TH_BORDER, TH_BG, TH_DIM),
     TH_SGR_TITLE: str = ansi_sgr(TH_TITLE, TH_BG, TH_BOLD),
     TH_SGR_CWD: str = ansi_sgr(TH_CWD, TH_BG, TH_NONE),
     TH_SGR_MODEL_DIM: str = ansi_sgr(TH_MODEL, TH_BG, TH_DIM),
     TH_SGR_USER_PROMPT: str = ansi_sgr(TH_USER, TH_BG, TH_BOLD),
     TH_SGR_USER_MSG: str = ansi_sgr(TH_USER, TH_USER_BG, TH_BOLD),
     TH_SGR_ANSWER: str = ansi_sgr(TH_ANSWER, TH_BG, TH_NONE),
     TH_SGR_PHASE: str = ansi_sgr(TH_PHASE, TH_BG, TH_NONE),
     TH_SGR_ERROR: str = ansi_sgr(TH_ERROR, TH_BG, TH_NONE),
     TH_SGR_ERROR_BOLD: str = ansi_sgr(TH_ERROR, TH_BG, TH_BOLD),
     TH_SGR_RESULT: str = ansi_sgr(TH_RESULT, TH_BG, TH_NONE),
     TH_SGR_CALL_BOLD: str = ansi_sgr(TH_CALL, TH_BG, TH_BOLD),
     TH_SGR_REASON_DIM: str = ansi_sgr(TH_REASON, TH_BG, TH_DIM),
     TH_SGR_OK_BOLD: str = ansi_sgr(TH_STATUS_OK, TH_BG, TH_BOLD);

glob TH_SGR_AC_SEL: str = ansi_sgr(TH_USER, TH_AC_SEL_BG, TH_BOLD),
     TH_SGR_AC_SEL_DESC: str = ansi_sgr(TH_AC_SEL_DESC, TH_AC_SEL_BG, TH_NONE),
     TH_SGR_AC_DESC_DIM: str = ansi_sgr(TH_AC_DESC, TH_BG, TH_DIM);

glob TH_SGR_MD_H1: str = ansi_sgr(TH_MD_H1, TH_BG, TH_BOLD),
     TH_SGR_MD_H2: str = ansi_sgr(TH_MD_H2, TH_BG, TH_BOLD),
     TH_SGR_MD_H3: str = ansi_sgr(TH_MD_H3, TH_BG, TH_BOLD),
     TH_SGR_MD_CODE: str = ansi_sgr(TH_MD_CODE, TH_MD_CODE_BG, TH_NONE),
     TH_SGR_MD_FENCE: str = ansi_sgr(TH_MD_FENCE, TH_BG, TH_DIM),
     TH_SGR_MD_BQ: str = ansi_sgr(TH_MD_BQ, TH_BG, TH_ITALIC),
     TH_SGR_MD_BQ_BAR: str = ansi_sgr(TH_MD_BQ_BAR, TH_BG, TH_NONE),
     TH_SGR_MD_HR: str = ansi_sgr(TH_MD_HR, TH_BG, TH_DIM);
