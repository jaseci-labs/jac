"""ToolBlock renderer: pi-tui tool-execution.ts visual intent in Jac NA.

Produces pre-styled ANSI rows for `call` and `tool_result` events.
Each row is padded to `width` visible columns and ends with ESC[0m so the
diff engine can repaint it independently.

  call:        ⚙  bold-purple tool_name   dim-gray args (inline, truncated)
  tool_result: ✓  bold-green first-line   dim-gray continuation lines
               ✗  bold-red   (empty)      when result text is empty
"""

import from .terminal { ansi_sgr }
import from .width { visible_width, ansi_trunc, ansi_pad }
import from .state { DisplayRow }

# Tool call accent: purple (matches TH_CALL_R/G/B in theme.na.jac)
glob _TC_R: int = 204,
     _TC_G: int = 119,
     _TC_B: int = 255;
# Result success: green
glob _TR_OK_R: int = 80,
     _TR_OK_G: int = 200,
     _TR_OK_B: int = 80;
# Result error: red
glob _TR_ERR_R: int = 255,
     _TR_ERR_G: int = 80,
     _TR_ERR_B: int = 80;
# Dim args/continuation: gray
glob _TC_ARG_R: int = 160,
     _TC_ARG_G: int = 160,
     _TC_ARG_B: int = 160;
# Base background
glob _TB_BG_R: int = 18,
     _TB_BG_G: int = 18,
     _TB_BG_B: int = 28;
# SGR attribute bitmasks
glob _TB_BOLD: int = 1,
     _TB_DIM: int = 2;

def tool_call_rows(tool_name: str, text: str, width: int, out: list[DisplayRow]) {
    # ⚙ tool_name  {args inline, truncated to remaining width}
    name = tool_name;
    if len(name) == 0 {
        name = "tool";
    }

    # Both icon and name: bold purple; args spacer + content: dim gray.
    name_sgr = ansi_sgr(_TC_R, _TC_G, _TC_B, _TB_BG_R, _TB_BG_G, _TB_BG_B, _TB_BOLD);
    arg_sgr = ansi_sgr(
        _TC_ARG_R, _TC_ARG_G, _TC_ARG_B, _TB_BG_R, _TB_BG_G, _TB_BG_B, _TB_DIM
    );

    # "⚙ " = 2 vis cols (⚙ is 3-byte UTF-8 = 1 col); name = visible_width(name); "  " spacer = 2.
    name_vis = visible_width(name);
    header_vis = 2 + name_vis + 2;

    args_avail = width - header_vis;
    args_line: str = "";
    if args_avail > 2 {
        if len(text) > 0 {
            args_line = ansi_trunc(text, args_avail);
        }
    }

    # Build row: last active SGR before ansi_pad is arg_sgr (bg=dark) so padding
    # spaces get the correct dark background without a trailing reset.
    row = name_sgr + "⚙ " + name + arg_sgr + "  " + args_line;
    row = ansi_pad(row, width);
    row = row + "\033[0m";
    out.append(
        DisplayRow(text=row, kind="call", is_continuation=False, pre_styled=True)
    );
}

def tool_result_rows(tool_name: str, text: str, width: int, out: list[DisplayRow]) {
    # Row 0: ✓/✗ + first content line; rows 1+: "  " indent + continuation.
    is_err = len(text) == 0;

    icon_str: str = "✓ ";
    icon_r: int = _TR_OK_R;
    icon_g: int = _TR_OK_G;
    icon_b: int = _TR_OK_B;
    if is_err {
        icon_str = "✗ ";
        icon_r = _TR_ERR_R;
        icon_g = _TR_ERR_G;
        icon_b = _TR_ERR_B;
    }

    icon_sgr = ansi_sgr(icon_r, icon_g, icon_b, _TB_BG_R, _TB_BG_G, _TB_BG_B, _TB_BOLD);
    cont_sgr = ansi_sgr(
        _TC_ARG_R, _TC_ARG_G, _TC_ARG_B, _TB_BG_R, _TB_BG_G, _TB_BG_B, _TB_DIM
    );

    body = text;
    if len(body) == 0 {
        body = "(empty)";
    }

    # "✓ " = 2 vis cols; continuation indent "  " = 2 vis cols.
    parts = body.split("\n");
    np = len(parts);
    i: int = 0;
    while i < np {
        line = parts[i];
        avail = width - 2;
        if avail < 1 {
            avail = 1;
        }
        content = ansi_trunc(line, avail);
        if i == 0 {
            row = icon_sgr + icon_str + cont_sgr + content;
            row = ansi_pad(row, width);
            row = row + "\033[0m";
            out.append(
                DisplayRow(
                    text=row, kind="tool_result", is_continuation=False, pre_styled=True
                )
            );
        } else {
            row = cont_sgr + "  " + content;
            row = ansi_pad(row, width);
            row = row + "\033[0m";
            out.append(
                DisplayRow(
                    text=row, kind="tool_result", is_continuation=True, pre_styled=True
                )
            );
        }
        i = i + 1;
    }
}
