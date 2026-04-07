"""Smoke test: verify lazy graph creation via walkers — Orchestrator-Worker Architecture."""

import from jac_coder.nodes { Session, MainAgent }
import from jac_coder.walkers { new_session, ensure_main_agent }
import from jac_coder.config { llm }
import from jac_coder.permission { permission_engine }


with entry {
    permission_engine.init_defaults();

    # 1. Ensure MainAgent creates graph lazily
    agent = ensure_main_agent();
    agents = [root()-->][?:MainAgent];
    assert len(agents) == 1 , "Expected 1 MainAgent";
    print("MainAgent: OK (lazy-created)");

    # 2. Create a session and verify MainAgent connection
    root() spawn new_session(title="Test Session", directory="/tmp/test");
    sessions = [root()-->][?:Session];
    assert len(sessions) == 1 , "Expected 1 Session";
    session = sessions[0];
    print("Session: OK (id=" + session.id + ")");

    # 3. Verify Session ──> MainAgent edge
    session_agents = [session-->[?:MainAgent]];
    assert len(session_agents) == 1 , "Expected Session connected to MainAgent";
    print("Session->MainAgent edge: OK");

    # 4. Second call to ensure_main_agent returns the SAME agent (idempotent)
    agent2 = ensure_main_agent();
    assert len([root()-->][?:MainAgent]) == 1 , "ensure_main_agent must be idempotent";
    print("ensure_main_agent idempotent: OK");

    print("\n=== All graph tests passed! ===");
}
