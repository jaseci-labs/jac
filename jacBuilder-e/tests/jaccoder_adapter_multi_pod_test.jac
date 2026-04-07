"""Tests for multi-pod state fixes in jaccoder_adapter.

Simulates cross-pod scenarios by clearing in-memory dicts between operations,
forcing fallback to graph state. Uses unique IDs per test to avoid collisions."""

import time;
import from services.ideServer {
    Project
}
import from services.jaccoder_adapter {
    is_ai_processing,
    drain_events,
    clear_session,
    _session_map,
    _ai_processing,
    _event_queues
}


test "is_ai_processing falls back to graph when local dict empty" {
    uid = "mp-test-user-1";
    pid = "mp-test-proj-1";
    key = f"{uid}::{pid}";

    proj = Project(
        id=pid,
        name="Test Project 1",
        ai_processing=True
    );

    _ai_processing.pop(key, None);
    result = is_ai_processing(uid, pid, project_node=proj);
    assert result == True, "Should fall back to graph node ai_processing=True";

    proj.ai_processing = False;
    result2 = is_ai_processing(uid, pid, project_node=proj);
    assert result2 == False, "Should fall back to graph node ai_processing=False";
}


test "is_ai_processing prefers local dict over graph" {
    uid = "mp-test-user-2";
    pid = "mp-test-proj-2";
    key = f"{uid}::{pid}";

    proj = Project(
        id=pid,
        name="Test Project 2",
        ai_processing=True
    );

    _ai_processing[key] = False;
    result = is_ai_processing(uid, pid, project_node=proj);
    assert result == False, "Local dict False should override graph True";

    _ai_processing.pop(key, None);
}


test "is_ai_processing returns False when no local dict and no project_node" {
    uid = "mp-test-user-3";
    pid = "mp-test-proj-3";
    key = f"{uid}::{pid}";

    _ai_processing.pop(key, None);
    result = is_ai_processing(uid, pid);
    assert result == False, "Should return False with no data source";
}


test "drain_events returns synthetic event when agent on another pod" {
    uid = "mp-test-user-4";
    pid = "mp-test-proj-4";
    key = f"{uid}::{pid}";

    proj = Project(
        id=pid,
        name="Test Project 4",
        ai_processing=True
    );

    _event_queues.pop(key, None);
    events = drain_events(uid, pid, project_node=proj);
    assert len(events) == 1, "Should return one synthetic event";
    assert events[0]["type"] == "agent_activity";
    assert "another instance" in events[0]["detail"];
}


test "drain_events returns empty when no queue and not processing" {
    uid = "mp-test-user-5";
    pid = "mp-test-proj-5";
    key = f"{uid}::{pid}";

    proj = Project(
        id=pid,
        name="Test Project 5",
        ai_processing=False
    );

    _event_queues.pop(key, None);
    events = drain_events(uid, pid, project_node=proj);
    assert len(events) == 0, "Should return empty list";
}


test "drain_events returns empty with no queue and no project_node" {
    uid = "mp-test-user-6";
    pid = "mp-test-proj-6";
    key = f"{uid}::{pid}";

    _event_queues.pop(key, None);
    events = drain_events(uid, pid);
    assert len(events) == 0, "Should return empty list with no context";
}


test "clear_session resets graph ai_processing flag" {
    uid = "mp-test-user-7";
    pid = "mp-test-proj-7";
    key = f"{uid}::{pid}";

    proj = Project(
        id=pid,
        name="Test Project 7",
        ai_processing=True
    );

    _session_map[key] = "fake-session";
    _ai_processing[key] = True;

    clear_session(uid, pid, project_node=proj);
    assert proj.ai_processing == False, "Graph flag should be cleared";
    assert key not in _session_map, "Local session map should be cleared";
    assert key not in _ai_processing, "Local processing dict should be cleared";
}


test "clear_session works without project_node" {
    uid = "mp-test-user-8";
    pid = "mp-test-proj-8";
    key = f"{uid}::{pid}";

    _session_map[key] = "fake-session-2";
    _ai_processing[key] = True;

    clear_session(uid, pid);
    assert key not in _session_map;
    assert key not in _ai_processing;
}


test "Project node has ai_processing field defaulting to False" {
    proj = Project(
        id="mp-test-proj-9",
        name="Default Test"
    );
    assert proj.ai_processing == False, "ai_processing should default to False";
}
