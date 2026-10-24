obj Gateway {
    has middleware: MiddlewareRegistry postinit;

    def postinit;
    def setup;
    def serve(on_ready: any = None);
}
