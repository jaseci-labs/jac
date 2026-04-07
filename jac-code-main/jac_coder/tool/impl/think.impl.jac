impl think(thought: str) -> str {
    tool_status("think", thought[:80] + "..." if len(thought) > 80 else thought);
    return thought;
}
