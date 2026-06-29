import from jac_scale.runtime.middleware.middleware { MiddlewareRegistry }


obj Gateway {
    has middleware: MiddlewareRegistry by postinit;

    def postinit {
        self.middleware = MiddlewareRegistry();
    }

    def setup {
        raise NotImplementedError("setup() must be implemented by a Gateway");
    }

    def serve {
        raise NotImplementedError("serve() must be implemented by a Gateway");
    }
}
