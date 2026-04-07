"""Phase 2 tests: event system timing and turn summary."""

import time;

import from jac_coder.events {
    register_event_callback,
    clear_event_callbacks,
    start_turn,
    emit_turn_summary,
    track_file,
    track_error,
    reset_steps,
    emit_event
}
import from jac_coder.util.tool_output { tool_status, tool_end }


glob collected_events: list = [];


def collector(event_type: str, data: dict) -> None {
    collected_events.append({"type": event_type, "data": dict(data)});
}


def reset_collector() {
    global collected_events;
    collected_events = [];
}


with entry {
    clear_event_callbacks();
    register_event_callback(collector);

    # Test 1: tool_status + tool_end emit events with timing
    reset_collector();
    reset_steps();
    tool_status("read", "test.jac");
    time.sleep(0.01);
    tool_end("-> 10 lines");

    assert len(collected_events) == 2 , "Should emit tool_start + tool_end";
    assert collected_events[0]["type"] == "tool_start";
    assert collected_events[0]["data"]["tool"] == "read";
    assert collected_events[0]["data"]["step"] == 1;
    assert collected_events[1]["type"] == "tool_end";
    assert collected_events[1]["data"]["duration_ms"] >= 0;
    assert collected_events[1]["data"]["status"] == "done";
    print("tool_status + tool_end events: OK");

    # Test 2: tool_end with error flag
    reset_collector();
    reset_steps();
    tool_status("jac_check", "broken.jac");
    tool_end("-> errors found", error=True);

    end_event = collected_events[1];
    assert end_event["data"]["status"] == "error";
    print("tool_end error flag: OK");

    # Test 3: auto-close on next tool_status
    reset_collector();
    reset_steps();
    tool_status("read", "a.jac");
    tool_status("write", "b.jac");
    tool_end("-> written");

    assert len(collected_events) == 4;
    assert collected_events[0]["type"] == "tool_start";
    assert collected_events[1]["type"] == "tool_end";
    assert collected_events[2]["type"] == "tool_start";
    assert collected_events[3]["type"] == "tool_end";
    print("auto-close previous tool: OK");

    # Test 4: turn summary with tracking
    reset_collector();
    reset_steps();
    start_turn();
    tool_status("read", "file.jac");
    tool_end("-> 5 lines");
    tool_status("write", "output.jac");
    tool_end("-> 10 lines");
    tool_status("jac_check", "output.jac");
    tool_end("-> errors", error=True);
    track_file("output.jac");

    summary = emit_turn_summary();
    assert summary["tools_count"] == 3 , "Should count 3 tools: " + str(summary);
    assert summary["errors"] == 1 , "Should have 1 error: " + str(summary);
    assert "output.jac" in summary["files_modified"];
    assert summary["duration_s"] >= 0.0;
    print("turn summary: OK");

    # Test 5: turn summary event emitted
    summary_events = [
        e
        for e in collected_events
        if e["type"] == "turn_summary"
    ];
    assert len(summary_events) == 1 , "Should emit exactly 1 turn_summary event";
    assert summary_events[0]["data"]["tools_count"] == 3;
    print("turn summary event emission: OK");

    # Test 6: empty turn summary (no tools called)
    reset_collector();
    reset_steps();
    start_turn();
    summary = emit_turn_summary();
    assert summary["tools_count"] == 0;
    assert summary["files_modified"] == [];
    assert summary["errors"] == 0;
    print("empty turn summary: OK");

    clear_event_callbacks();
    print("\n=== All event tests passed! ===");
}
