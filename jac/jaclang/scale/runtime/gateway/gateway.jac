obj Gateway {
    has middleware: MiddlewareRegistry postinit;

    def postinit {
        self.middleware = MiddlewareRegistry();
    }

    def setup {
        raise NotImplementedError("setup() must be implemented by a Gateway");
    }

    def serve(on_ready: any = None) {
        raise NotImplementedError("serve() must be implemented by a Gateway");
    }
}
