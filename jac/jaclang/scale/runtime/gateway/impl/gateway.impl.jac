impl Gateway.postinit {
    self.middleware = MiddlewareRegistry();
}

impl Gateway.setup {
    raise NotImplementedError("setup() must be implemented by a Gateway");
}

impl Gateway.serve(on_ready: any = None) {
    raise NotImplementedError("serve() must be implemented by a Gateway");
}
