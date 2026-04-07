"""Smoke test: verify interact walker traversal and LLM integration.

Test 1: Graph traversal (no API key needed)
Test 2: Full LLM flow (requires OPENAI_API_KEY in .env)
"""

import os;
import from jac_coder.nodes { Session, MainAgent }
import from jac_coder.walkers { new_session, interact, ensure_main_agent }
import from jac_coder.config { llm }
import from jac_coder.permission { permission_engine }

with entry {
    # 0. Initialize graph
    permission_engine.init_defaults();
    ensure_main_agent();
    print("Graph initialized for test.");

    # 1. Create a session
    root() spawn new_session(title="Interact Test", directory=".");
    sessions = [root()-->][?:Session];
    session = sessions[0];
    session_id = session.id;
    print("Session created:", session_id);

    # 2. Verify graph connectivity
    session_agents = [session-->[?:MainAgent]];
    print("Session->MainAgent edges:", len(session_agents));
    assert len(session_agents) == 1 , "Session must be connected to MainAgent";

    print("\n=== Graph structure: OK ===");

    # 3. Test interact walker (requires API key for LLM)
    has_key = bool(os.environ.get("OPENAI_API_KEY", ""));
    if has_key and os.environ.get("OPENAI_API_KEY") != "your-api-key-here" {
        print("\n--- Running interact walker with LLM ---");
        root() spawn interact(
            message="List all .jac files in the current directory",
            session_id=session_id
        );

        # Check chat history was updated
        for s in [root()-->][?:Session] {
            if s.id == session_id {
                print("\nChat history length:", len(s.chat_history));
                for msg in s.chat_history {
                    role = msg["role"];
                    content = str(msg["content"])[:100];
                    print(f"  [{role}] {content}");
                }
                break;
            }
        }
        print("\n=== Full LLM flow: OK ===");
    } else {
        print("\n--- Skipping LLM test (no OPENAI_API_KEY set) ---");
        print("To test full flow, set OPENAI_API_KEY in .env");
        print("\n=== Graph traversal validated. Set API key for full test. ===");
    }
}
