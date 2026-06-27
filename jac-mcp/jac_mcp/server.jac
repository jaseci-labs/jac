obj JacMcpServer {
    has transport: str = "stdio",
        port: int = 3001,
        host: str = "127.0.0.1";

    def start -> None;
    def stop -> None;
}
