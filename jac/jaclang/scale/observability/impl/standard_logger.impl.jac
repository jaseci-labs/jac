impl StandardLogger.init(self: StandardLogger, config: dict[str, any] = {}) {}

impl StandardLogger.info(
    self: StandardLogger, message: str, context: dict[str, any] = {}
) {
    if context {
        console.info(f"{message} | Context: {context}");
    } else {
        console.info(message);
    }
}

impl StandardLogger.error(
    self: StandardLogger, message: str, context: dict[str, any] = {}
) {
    if context {
        console.error(f"{message} | Context: {context}");
    } else {
        console.error(message);
    }
}

impl StandardLogger.warn(
    self: StandardLogger, message: str, context: dict[str, any] = {}
) {
    if context {
        console.warning(f"{message} | Context: {context}");
    } else {
        console.warning(message);
    }
}

impl StandardLogger.debug(
    self: StandardLogger, message: str, context: dict[str, any] = {}
) {
    if context {
        console.print(f"[DEBUG] {message} | Context: {context}", style="muted");
    } else {
        console.print(f"[DEBUG] {message}", style="muted");
    }
}
