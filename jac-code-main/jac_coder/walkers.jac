import from http { HTTPMethod }
import from datetime { datetime }
import from jac_coder.util.tool_output { tool_end }
import from jac_coder.util.sandbox { set_sandbox_root }
import from jac_coder.config { llm, get_config }
import from jaclang.runtimelib.builtin { restspec }
import from jac_coder.context { build_context, ContextConfig }
import from jac_coder.events { reset_steps, start_turn, emit_turn_summary, emit_event, clear_abort, is_abort_requested }
import from byllm.types { StreamEvent }
import from jac_coder.memory {
    find_or_create_memory,
    _init_memory,
    update_memory_from_session
}
import from jac_coder.nodes { Session, MainAgent }


def ensure_main_agent() -> MainAgent;
def _find_session(session_id: str) -> Session | None;
def _persist_response(
    session_id: str,
    response: str,
    agent_mode: str,
    tools_used: list[str] = [],
    files_modified: list[str] = []
) -> None;
def _respond_and_persist(agent: MainAgent, ctx: interact) -> None;
def _consume_llm_stream(event_stream: Any) -> dict;


walker:pub new_session {
    has title: str = "New Session";
    has directory: str = "";

    can create with Root entry;
}


@restspec(method=HTTPMethod.GET)
walker:pub list_sessions {
    can list with Root entry;
}


walker:pub get_session {
    has session_id: str;

    can fetch with Root entry;
}

walker:pub close_session {
    has session_id: str;

    can close with Root entry;
}


walker:pub interact {
    has message: str;
    has session_id: str;
    has chat_history: list[dict] = [];
    has agent_context: str = "";

    can init_session with Root entry;
    can enter_session with Session entry;
    can respond with MainAgent entry;
}
