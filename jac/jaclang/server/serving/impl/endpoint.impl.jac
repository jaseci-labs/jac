impl JEndPoint.declared_parameters -> list[APIParameter] {
    if self.parameter_source is not None {
        self.parameters = self.parameter_source();
        self.parameter_source = None;
    }
    return self.parameters or [];
}
