impl _validate_trigger_fields(data: dict[str, any], allowed: set[str]) {
    extra = [
        k
        for k in data.keys()
        if k not in allowed
    ];
    if extra {
        raise ValueError(f"unexpected fields: {sorted(extra)}");
    }
    trigger = require_str(data, 'trigger');
    if trigger not in TRIGGER_KINDS {
        raise ValueError("trigger must be one of 'interval', 'cron', or 'date'");
    }
    interval = data.get('interval');
    if interval is not None {
        if not isinstance(interval, (int, float)) or float(interval) <= 0 {
            raise ValueError('interval must be a number greater than 0');
        }
    }
    cron = data.get('cron');
    if cron is not None and not isinstance(cron, str) {
        raise ValueError('cron must be a string');
    }
    date = data.get('date');
    if date is not None and not isinstance(date, str) {
        raise ValueError('date must be a string');
    }
}

impl CreateJobRequest.from_dict(data: any) -> CreateJobRequest {
    if not isinstance(data, dict) {
        raise ValueError('request body must be an object');
    }

    comptime allowed: set[str] = {f.name for f in fields(CreateJobRequest)};
    _validate_trigger_fields(data, allowed);
    return CreateJobRequest(
        walker_or_function=require_str(data, 'walker_or_function'),
        trigger=str(data.get('trigger')),
        interval=float(data['interval']) if data.get('interval') is not None else None,
        cron=data.get('cron'),
        date=data.get('date')
    );
}

impl UpdateJobRequest.from_dict(data: any) -> UpdateJobRequest {
    if not isinstance(data, dict) {
        raise ValueError('request body must be an object');
    }

    comptime allowed: set[str] = {f.name for f in fields(UpdateJobRequest)};
    _validate_trigger_fields(data, allowed);
    return UpdateJobRequest(
        trigger=str(data.get('trigger')),
        interval=float(data['interval']) if data.get('interval') is not None else None,
        cron=data.get('cron'),
        date=data.get('date')
    );
}
