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
    cmd_wait,
    cmd_scroll,
    cmd_console,
    cmd_snapshot,
    cmd_screenshot,
    cmd_state,
    cmd_sessions,
    cmd_close
}

def _need(args: list, n: int, usage: str) {
    if len(args) < n {
        raise ValueError(f"usage: jac browse {usage}");
    }
}

impl browse(
    action: str, args: list = [], session: str = "default", viewport: str = "1280x720"
) -> int {
    sess = os.environ.get("JACBROWSER_SESSION", session);
    out: any = "";
    try {
        if action == "open" {
            out = cmd_open(sess, args[0] if args else None, viewport);
        } elif action == "navigate" or action == "goto" {
            _need(args, 1, "navigate <url>");
            out = cmd_navigate(sess, args[0]);
        } elif action == "eval" {
            _need(args, 1, "eval <expression>");
            out = cmd_eval(sess, args[0]);
        } elif action == "click" {
            _need(args, 1, "click <selector|@ref>");
            out = cmd_click(sess, args[0]);
        } elif action == "type" {
            _need(args, 2, "type <selector|@ref> <text>");
            out = cmd_type(sess, args[0], args[1]);
        } elif action == "fill" {
            _need(args, 2, "fill <selector|@ref> <text>");
            out = cmd_fill(sess, args[0], args[1]);
        } elif action == "press" {
            _need(args, 1, "press <key>");
            out = cmd_press(sess, args[0]);
        } elif action == "get" {
            _need(args, 1, "get <title|url|text|html|value> [selector]");
            out = cmd_get(sess, args[0], args[1] if len(args) > 1 else None);
        } elif action == "wait" {
            _need(args, 1, "wait <selector|@ref>");
            out = cmd_wait(sess, args[0]);
        } elif action == "scroll" {
            _need(args, 1, "scroll <up|down|top|bottom|selector> [amount]");
            out = cmd_scroll(sess, args[0], int(args[1]) if len(args) > 1 else None);
        } elif action == "scrollintoview" {
            _need(args, 1, "scrollintoview <selector|@ref>");
            out = cmd_scroll(sess, args[0]);
        } elif action == "console" {
            out = cmd_console(sess, "--clear" in args or "clear" in args);
        } elif action == "snapshot" {
            out = cmd_snapshot(sess);
        } elif action == "screenshot" {
            out = cmd_screenshot(sess, args[0] if args else None);
        } elif action == "state" {
            _need(args, 2, "state <save|load> <path>");
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
