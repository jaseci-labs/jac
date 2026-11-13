glob TRIGGER_KINDS: set[str] = {'interval', 'cron', 'date'};


def _validate_trigger_fields(data: dict[str, any], allowed: set[str]);

obj CreateJobRequest(ApiModel) {
    has walker_or_function: str,
        trigger: str,
        interval: (float | None) = None,
        cron: (str | None) = None,
        date: (str | None) = None;

    static def from_dict(data: any) -> CreateJobRequest;
}

obj UpdateJobRequest(ApiModel) {
    has trigger: str,
        interval: (float | None) = None,
        cron: (str | None) = None,
        date: (str | None) = None;

    static def from_dict(data: any) -> UpdateJobRequest;
}
