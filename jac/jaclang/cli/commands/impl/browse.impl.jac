"""Implementation of the `jac browse` command.

Dispatches the action positional to the matching engine command. Output is
printed raw (so it pipes cleanly); errors go to the console and return exit 1.
The session can also be set via the JACBROWSER_SESSION env var.
"""

import os;
import sys;
import json;
import from jaclang.cli.console { console }
import from jaclang.cli.browser_engine {
    cmd_open,
    cmd_navigate,
    cmd_eval,
    cmd_click,
    cmd_type,
    cmd_fill,
    cmd_press,
    cmd_get,
    cmd_snapshot,
    cmd_screenshot,
    cmd_state,
    cmd_sessions,
    cmd_close
}

impl browse(action: str, args: list = [], session: str = "default") -> int {
    sess = os.environ.get("JACBROWSER_SESSION", session);
    out: any = "";
    try {
        if action == "open" {
            out = cmd_open(sess, args[0] if args else None);
        } elif action == "navigate" or action == "goto" {
            out = cmd_navigate(sess, args[0]);
        } elif action == "eval" {
            out = cmd_eval(sess, args[0]);
        } elif action == "click" {
            out = cmd_click(sess, args[0]);
        } elif action == "type" {
            out = cmd_type(sess, args[0], args[1]);
        } elif action == "fill" {
            out = cmd_fill(sess, args[0], args[1]);
        } elif action == "press" {
            out = cmd_press(sess, args[0]);
        } elif action == "get" {
            out = cmd_get(sess, args[0], args[1] if len(args) > 1 else None);
        } elif action == "snapshot" {
            out = cmd_snapshot(sess);
        } elif action == "screenshot" {
            out = cmd_screenshot(sess, args[0] if args else None);
        } elif action == "state" {
            out = cmd_state(sess, args[0], args[1]);
        } elif action == "sessions" {
            out = cmd_sessions(sess);
        } elif action == "close" {
            out = cmd_close(sess);
        } else {
            console.error(f"unknown browser action: {action}");
            return 1;
        }
    } except Exception as e {
        console.error(f"browser error: {e}");
        return 1;
    }
    sys.stdout.write((out if isinstance(out, str) else json.dumps(out)) + "\n");
    return 0;
}
