import pygls.server;

obj ServerWrapper {
    def init(file: str);
    def get_server(server_ip: str, port: int) -> pygls.server.LanguageServer;
}

impl ServerWrapper.init(file: str) {
    self.file = file;
}

impl ServerWrapper.get_server{
    return pygls.server.LanguageServer("test_server", "1");
}
