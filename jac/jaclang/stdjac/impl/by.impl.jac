impl ByUsage.add(more: ByUsage) {
    self.requests += more.requests;
    self.input_tokens += more.input_tokens;
    self.output_tokens += more.output_tokens;
    self.cache_read_tokens += more.cache_read_tokens;
    self.cache_write_tokens += more.cache_write_tokens;
    self.seconds += more.seconds;
    if more.model != "" {
        self.model = more.model;
    }
}
