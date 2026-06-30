"""Request/response models for the /jobs scheduler endpoints.

These power the auto-generated OpenAPI / Swagger schema — giving users a
concrete body example instead of an empty schema placeholder.
"""
import from typing { Literal }
import from pydantic { BaseModel, ConfigDict, Field }


class CreateJobRequest(BaseModel) {
    has walker_or_function: str = Field(
        ...,
        min_length=1,
        description='Name of the walker or function decorated with '
        '@schedule(trigger=ScheduleTrigger.DYNAMIC).'
    ),
        trigger: Literal['interval', 'cron', 'date'] = Field(
            ...,
            description='How the job is triggered: '
            "'interval' (every N seconds), 'cron' (5-field crontab, UTC), "
            "or 'date' (single fire at an ISO-8601 UTC datetime)."
        ),
        interval: float | None = Field(
            None,
            gt=0,
            description='Seconds between executions. Required when trigger="interval".'
        ),
        cron: str | None = Field(
            None,
            description='5-field cron expression interpreted in UTC. '
            'Required when trigger="cron".'
        ),
        date: str | None = Field(
            None,
            description='ISO-8601 datetime (UTC) to fire once. '
            'Required when trigger="date".'
        ),
        model_config: ConfigDict = ConfigDict(
            extra='forbid',
            json_schema_extra={
                "examples": [
                    {
                        "walker_or_function": "MyScheduledWalker",
                        "trigger": "interval",
                        "interval": 60
                    },
                    {
                        "walker_or_function": "daily_report",
                        "trigger": "cron",
                        "cron": "0 9 * * *"
                    },
                    {
                        "walker_or_function": "OneShotCleanup",
                        "trigger": "date",
                        "date": "2026-12-31 09:00:00"
                    }
                ]
            }
        );
}


class UpdateJobRequest(BaseModel) {
    has trigger: Literal['interval', 'cron', 'date'] = Field(
        ..., description='New trigger type for this job.'
    ),
        interval: float | None = Field(
            None,
            gt=0,
            description='Seconds between executions. Required when trigger="interval".'
        ),
        cron: str | None = Field(
            None,
            description='5-field cron expression interpreted in UTC. '
            'Required when trigger="cron".'
        ),
        date: str | None = Field(
            None, description='ISO-8601 datetime (UTC). Required when trigger="date".'
        ),
        model_config: ConfigDict = ConfigDict(
            extra='forbid',
            json_schema_extra={
                "examples": [
                    {"trigger": "interval", "interval": 120},
                    {"trigger": "cron", "cron": "*/15 * * * *"},
                    {"trigger": "date", "date": "2027-01-01 00:00:00"}
                ]
            }
        );
}
