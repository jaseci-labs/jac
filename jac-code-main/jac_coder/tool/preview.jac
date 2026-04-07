import os;

import from jac_coder.util.tool_output { truncate_output, tool_status, tool_end }


"""Set the preview URL for the current thread/request."""
def set_preview_url(url: str) -> None;


"""Open the browser and navigate to a URL (defaults to the preview URL).
Starts the agent-browser daemon if not running.
Returns the page snapshot with element refs (@e1, @e2, ...).
Call this once before using browser_do or browser_state."""
def browser_open(url: str = "") -> str;


"""Execute a browser action via agent-browser CLI.
Commands and examples:
  'click @e1'                    — click element by ref
  'fill @e2 "Buy milk"'         — clear input and type text
  'type @e2 "extra"'            — type into element (appends)
  'press Enter'                  — press a key
  'select @e3 "option1"'        — select dropdown value
  'check @e4' / 'uncheck @e4'   — toggle checkbox
  'scroll down' / 'scroll up'   — scroll page
  'hover @e5'                   — hover over element
  'screenshot'                   — take screenshot
  'screenshot --annotate'        — labeled screenshot for debugging
  'get text @e1'                 — get text content of element
  'get value @e2'                — get input value
  'wait 2000'                    — wait 2 seconds
  'wait @e1'                     — wait for element to appear
  'back' / 'forward' / 'reload' — navigation
  'eval "document.title"'       — run JavaScript
Returns the command output."""
def browser_do(command: str) -> str;


"""Get the current page snapshot as an accessibility tree with element refs.
Returns semantic page structure with refs (@e1, @e2, ...) for use with
browser_do commands. Use 'snapshot -i' internally for interactive elements only.
Very token-efficient (~200-400 tokens vs full DOM)."""
def browser_state() -> str;


"""Close the browser session and stop the daemon.
Call when done testing. Sessions auto-close on timeout."""
def browser_close() -> str;
