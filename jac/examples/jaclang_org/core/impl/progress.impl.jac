import from core.timefmt { now_iso }

impl JobProgress.begin(phase: str) {
    self.active = True;
    self.phase = phase;
    self.detail = "";
    self.steps = [];
    self.log = [];
    self.updated_at = now_iso();
}

impl JobProgress.note(detail: str) {
    self.detail = detail;
    self.log.append(detail);
    if len(self.log) > LOG_DEPTH {
        self.log = self.log[-LOG_DEPTH:];
    }
    self.updated_at = now_iso();
}

impl JobProgress.mark(label: str, state: str, detail: str) {
    for s in self.steps {
        if s.label == label {
            s.state = state;
            s.detail = detail;
            self.updated_at = now_iso();
            return;
        }
    }
    self.steps.append(JobStep(label=label, state=state, detail=detail));
    self.updated_at = now_iso();
}

impl JobProgress.finish{
    self.phase = "done";
    self.active = False;
    self.updated_at = now_iso();
}

impl JobProgress.fail(detail: str) {
    self.phase = "error";
    self.active = False;
    self.note(detail);
}
