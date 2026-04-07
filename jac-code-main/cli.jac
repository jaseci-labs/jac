"""JacCoder CLI — Interactive terminal interface for the coding agent."""

import os;
import sys;
import from datetime { datetime }
import from jac_coder.nodes { Session, MainAgent }
import from jac_coder.walkers {
    new_session,
    list_sessions,
    get_session,
    close_session,
    interact,
    ensure_main_agent
}
import from jac_coder.config { llm, model_name, get_config, set_model, get_model }
import from jac_coder.permission { permission_engine }
import from jac_coder.events { register_event_callback, get_agent_prefix }
import from jac_coder.tool.todo { get_todos }
import from jac_coder.util.colors {
    RESET,
    BOLD,
    DIM,
    CYAN,
    GREEN,
    YELLOW,
    RED,
    MAGENTA,
    WHITE,
    AGENT_COLORS
}


def print_banner;
def print_help;
def print_error(msg: str);
def print_info(msg: str);
def print_success(msg: str);

def find_session(session_id: str) -> Session | None;
def create_new_session(directory: str) -> str;
def find_session_by_prefix(prefix: str) -> Session | None;

def cmd_sessions;
def cmd_history(session_id: str);
def cmd_agent_switch(mode: str, session_id: str);
def cmd_config;
def cmd_todo;

def run_noninteractive(prompt: str);
def show_sessions;
def start_repl(session_id: str);
def _cli_event_handler(event_type: str, data: dict) -> None;


with entry {
    # Suppress litellm debug spam
    import litellm;
    litellm.suppress_debug_info = True;
    os.environ["LITELLM_LOG"] = "ERROR";

    register_event_callback(_cli_event_handler);
    argv = sys.argv[1:] if len(sys.argv) > 1 else [];

    if argv {
        subcmd = str(argv[0]).lower();

        if subcmd == "run" {
            if len(argv) < 2 {
                print_error("Usage: jac run cli.jac run \"your prompt\"");
            } else {
                prompt = str(argv[1]);
                run_noninteractive(prompt);
            }
        } elif subcmd == "config" {
            cmd_config();
        } elif subcmd == "sessions" {
            show_sessions();
        } elif subcmd == "session" {
            if len(argv) < 2 {
                print_error("Usage: jac run cli.jac session <id-prefix>");
                print_info(
                    "  Use 'jac run cli.jac sessions' to see available sessions."
                );
            } else {
                resume_prefix = str(argv[1]).strip();
                ensure_main_agent();
                permission_engine.init_defaults();
                target = find_session_by_prefix(resume_prefix);
                if not target {
                    target = find_session(resume_prefix);
                }
                if not target {
                    print_error(f"No session found matching '{resume_prefix}'");
                    print_info(
                        "  Use 'jac run cli.jac sessions' to see available sessions."
                    );
                } else {
                    start_repl(target.id);
                }
            }
        } elif subcmd == "--help" or subcmd == "-h" {
            print("Usage: jac run cli.jac [command]");
            print("");
            print("Commands:");
            print("  (none)            Interactive REPL (new session)");
            print("  session <id>      Resume an existing session by ID prefix");
            print("  run \"prompt\"      Non-interactive mode");
            print("  config            Show configuration");
            print("  sessions          List saved sessions");
        } else {
            print_error(f"Unknown command: {subcmd}. Use --help for usage.");
        }
    } else {
        ensure_main_agent();
        permission_engine.init_defaults();
        session_id = create_new_session(os.getcwd());
        start_repl(session_id);
    }
}
