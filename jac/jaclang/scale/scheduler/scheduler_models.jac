import from jaclang.runtimelib.serving.model { ApiModel, require_str }


glob TRIGGER_KINDS: set[str] = {'interval', 'cron', 'date'};


def _validate_trigger_fields(data: dict, allowed: set[str]) {
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

obj CreateJobRequest(ApiModel) {
    has walker_or_function: str,
        trigger: str,
        interval: (float | None) = None,
        cron: (str | None) = None,
        date: (str | None) = None;

    static def from_dict(data: any) -> CreateJobRequest {
        if not isinstance(data, dict) {
            raise ValueError('request body must be an object');
        }
        _validate_trigger_fields(
            data, {'walker_or_function', 'trigger', 'interval', 'cron', 'date'}
        );
        return CreateJobRequest(
            walker_or_function=require_str(data, 'walker_or_function'),
            trigger=str(data.get('trigger')),
            interval=float(data['interval'])
                if data.get('interval') is not None
                else None,
            cron=data.get('cron'),
            date=data.get('date')
        );
    }
}

obj UpdateJobRequest(ApiModel) {
    has trigger: str,
        interval: (float | None) = None,
        cron: (str | None) = None,
        date: (str | None) = None;

    static def from_dict(data: any) -> UpdateJobRequest {
        if not isinstance(data, dict) {
            raise ValueError('request body must be an object');
        }
        _validate_trigger_fields(data, {'trigger', 'interval', 'cron', 'date'});
        return UpdateJobRequest(
            trigger=str(data.get('trigger')),
            interval=float(data['interval'])
                if data.get('interval') is not None
                else None,
            cron=data.get('cron'),
            date=data.get('date')
        );
    }
}
