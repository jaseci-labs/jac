impl studio(
    action: str = "",
    args: list[str] = [],
    agent: str = "",
    session: str = "",
    as_json: bool = False,
    directory: str = ""
) -> int {
    return run_studio(action, args, agent, session, as_json, directory);
}
