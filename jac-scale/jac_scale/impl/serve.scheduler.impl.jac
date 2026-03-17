"""Extract Bearer token from request and validate. Returns (username, None) or (None, error_response)."""
def _authenticate_request(
    request: Request, user_manager: Any
) -> tuple[str | None, TransportResponse | None] {
    authorization = request.headers.get('Authorization');
    token: (str | None) = None;
    if (
        authorization
        and isinstance(authorization, str)
        and authorization.startswith('Bearer ')
    ) {
        token = authorization[7:];
    }
    username = user_manager.validate_jwt_token(token) if token else None;
    if not username {
        return (
            None,
            TransportResponse.fail(
                code='UNAUTHORIZED',
                message='Authorization required',
                meta=Meta(extra={'http_status': 401})
            )
        );
    }
    return (username, None);
}

"""Validate trigger type and trigger-specific fields. Returns error response or None."""
def _validate_trigger(
    trigger: str, interval: Any, cron: Any, date: Any
) -> TransportResponse | None {
    valid_triggers = ['interval', 'cron', 'date'];
    if trigger not in valid_triggers {
        return TransportResponse.fail(
            code='INVALID_REQUEST',
            message=f'trigger must be one of: {valid_triggers}',
            meta=Meta(extra={'http_status': 400})
        );
    }
    if trigger == 'interval' and interval is None {
        return TransportResponse.fail(
            code='INVALID_REQUEST',
            message='Field "interval" (seconds) is required for trigger="interval"',
            meta=Meta(extra={'http_status': 400})
        );
    }
    if trigger == 'cron' and not cron {
        return TransportResponse.fail(
            code='INVALID_REQUEST',
            message='Field "cron" (5-field cron string) is required for trigger="cron"',
            meta=Meta(extra={'http_status': 400})
        );
    }
    if trigger == 'date' and not date {
        return TransportResponse.fail(
            code='INVALID_REQUEST',
            message='Field "date" (ISO datetime string) is required for trigger="date"',
            meta=Meta(extra={'http_status': 400})
        );
    }
    return None;
}

"""Register all /jobs REST endpoints on the server."""
impl JacAPIServerScheduler.register_scheduler_endpoints -> None {
    # POST /jobs — create a new dynamic scheduled job
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.POST,
            path='/jobs',
            callback=self.create_job_callback(),
            parameters=[],
            response_model=None,
            tags=['Scheduler'],
            summary='Create scheduled job',
            description=(
                'Schedule a walker or function decorated with '
                '@schedule(trigger=ScheduleTrigger.DYNAMIC). '
                'Requires Authorization header.'
            )
        )
    );

    # GET /jobs — list all dynamic scheduled jobs
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/jobs',
            callback=self.list_jobs_callback(),
            parameters=[],
            response_model=None,
            tags=['Scheduler'],
            summary='List scheduled jobs',
            description='List all active dynamic scheduled jobs. Requires Authorization header.'
        )
    );

    # GET /jobs/{job_id} — get a single job
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/jobs/{job_id}',
            callback=self.get_job_callback(),
            parameters=[
                APIParameter(
                    name='job_id',
                    data_type='str',
                    required=True,
                    default=None,
                    description='Job ID',
                    type=ParameterType.PATH
                )
            ],
            response_model=None,
            tags=['Scheduler'],
            summary='Get scheduled job',
            description='Retrieve a specific scheduled job by ID. Requires Authorization header.'
        )
    );

    # PUT /jobs/{job_id} — update an existing job's schedule
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.PUT,
            path='/jobs/{job_id}',
            callback=self.update_job_callback(),
            parameters=[
                APIParameter(
                    name='job_id',
                    data_type='str',
                    required=True,
                    default=None,
                    description='Job ID',
                    type=ParameterType.PATH
                )
            ],
            response_model=None,
            tags=['Scheduler'],
            summary='Update scheduled job',
            description='Update the schedule of an existing dynamic job. Requires Authorization header.'
        )
    );

    # DELETE /jobs/{job_id} — delete a job
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.DELETE,
            path='/jobs/{job_id}',
            callback=self.delete_job_callback(),
            parameters=[
                APIParameter(
                    name='job_id',
                    data_type='str',
                    required=True,
                    default=None,
                    description='Job ID',
                    type=ParameterType.PATH
                )
            ],
            response_model=None,
            tags=['Scheduler'],
            summary='Delete scheduled job',
            description='Delete a dynamic scheduled job. Requires Authorization header.'
        )
    );
}

"""Build POST /jobs callback — creates a new dynamic scheduled job."""
impl JacAPIServerScheduler.create_job_callback -> Callable[..., TransportResponse] {
    async def callback(request: Request) -> TransportResponse {
        (username, auth_err) = _authenticate_request(request, self.user_manager);
        if auth_err {
            return auth_err;
        }

        # Parse request body
        try {
            body = await request.json();
        } except Exception {
            return TransportResponse.fail(
                code='INVALID_REQUEST',
                message='Request body must be valid JSON',
                meta=Meta(extra={'http_status': 400})
            );
        }

        walker_or_function = body.get('walker_or_function', '');
        trigger = body.get('trigger', '');
        interval = body.get('interval');
        cron_expr = body.get('cron');
        date_str = body.get('date');

        if not walker_or_function or not trigger {
            return TransportResponse.fail(
                code='INVALID_REQUEST',
                message='Fields "walker_or_function" and "trigger" are required',
                meta=Meta(extra={'http_status': 400})
            );
        }

        # Validate trigger type and trigger-specific fields
        trigger_err = _validate_trigger(trigger, interval, cron_expr, date_str);
        if trigger_err {
            return trigger_err;
        }

        # Verify the walker/function exists and has @schedule(trigger=DYNAMIC)
        introspector = self.introspector;
        target_obj = (introspector._walkers or {}).get(walker_or_function)
        or (introspector._functions or {}).get(walker_or_function);

        if target_obj is None {
            return TransportResponse.fail(
                code='NOT_FOUND',
                message=f'Walker or function "{walker_or_function}" not found',
                meta=Meta(extra={'http_status': 404})
            );
        }

        schedule_spec = target_obj.schedule_spec if target_obj?.schedule_spec else None;
        if schedule_spec is None {
            return TransportResponse.fail(
                code='INVALID_REQUEST',
                message=(
                    f'"{walker_or_function}" does not have a @schedule decorator. '
                    'Add @schedule(trigger=ScheduleTrigger.DYNAMIC) to enable dynamic scheduling.'
                ),
                meta=Meta(extra={'http_status': 400})
            );
        }

        if schedule_spec.trigger != ScheduleTrigger.DYNAMIC {
            return TransportResponse.fail(
                code='INVALID_REQUEST',
                message=(
                    f'"{walker_or_function}" uses trigger={schedule_spec.trigger.value!r}, '
                    'but only DYNAMIC-trigger walkers/functions can be scheduled via /jobs. '
                    'Use @schedule(trigger=ScheduleTrigger.DYNAMIC) to enable this.'
                ),
                meta=Meta(extra={'http_status': 400})
            );
        }

        try {
            root_id = self.user_manager.get_root_id(username);
            scheduler = JacScaleScheduler.instance();
            job = scheduler.create_job(
                name=walker_or_function,
                trigger=trigger,
                interval=float(interval) if interval is not None else None,
                cron=cron_expr,
                date=date_str,
                created_by=username,
                root_id=root_id
            );
            return TransportResponse.success(
                data=job, meta=Meta(extra={'http_status': 201})
            );
        } except Exception as e {
            return TransportResponse.fail(
                code='SCHEDULER_ERROR',
                message=str(e),
                meta=Meta(extra={'http_status': 500})
            );
        }
    }
    return callback;
}

"""Build GET /jobs callback — lists all dynamic scheduled jobs."""
impl JacAPIServerScheduler.list_jobs_callback -> Callable[..., TransportResponse] {
    async def callback(request: Request) -> TransportResponse {
        (username, auth_err) = _authenticate_request(request, self.user_manager);
        if auth_err {
            return auth_err;
        }

        try {
            scheduler = JacScaleScheduler.instance();
            jobs = scheduler.list_jobs();
            return TransportResponse.success(
                data={'jobs': jobs, 'count': len(jobs)},
                meta=Meta(extra={'http_status': 200})
            );
        } except Exception as e {
            return TransportResponse.fail(
                code='SCHEDULER_ERROR',
                message=str(e),
                meta=Meta(extra={'http_status': 500})
            );
        }
    }
    return callback;
}

"""Build GET /jobs/{job_id} callback — retrieves a single dynamic job."""
impl JacAPIServerScheduler.get_job_callback -> Callable[..., TransportResponse] {
    async def callback(request: Request, job_id: str) -> TransportResponse {
        (username, auth_err) = _authenticate_request(request, self.user_manager);
        if auth_err {
            return auth_err;
        }

        try {
            scheduler = JacScaleScheduler.instance();
            job = scheduler.get_job(job_id);
            if job is None {
                return TransportResponse.fail(
                    code='NOT_FOUND',
                    message=f'Job "{job_id}" not found',
                    meta=Meta(extra={'http_status': 404})
                );
            }
            return TransportResponse.success(
                data=job, meta=Meta(extra={'http_status': 200})
            );
        } except Exception as e {
            return TransportResponse.fail(
                code='SCHEDULER_ERROR',
                message=str(e),
                meta=Meta(extra={'http_status': 500})
            );
        }
    }
    return callback;
}

"""Build PUT /jobs/{job_id} callback — updates an existing dynamic job's schedule."""
impl JacAPIServerScheduler.update_job_callback -> Callable[..., TransportResponse] {
    async def callback(request: Request, job_id: str) -> TransportResponse {
        (username, auth_err) = _authenticate_request(request, self.user_manager);
        if auth_err {
            return auth_err;
        }

        try {
            body = await request.json();
        } except Exception {
            return TransportResponse.fail(
                code='INVALID_REQUEST',
                message='Request body must be valid JSON',
                meta=Meta(extra={'http_status': 400})
            );
        }

        trigger = body.get('trigger', '');
        interval = body.get('interval');
        cron_expr = body.get('cron');
        date_str = body.get('date');

        if not trigger {
            return TransportResponse.fail(
                code='INVALID_REQUEST',
                message='Field "trigger" is required',
                meta=Meta(extra={'http_status': 400})
            );
        }

        # Validate trigger type and trigger-specific fields
        trigger_err = _validate_trigger(trigger, interval, cron_expr, date_str);
        if trigger_err {
            return trigger_err;
        }

        try {
            scheduler = JacScaleScheduler.instance();
            updated = scheduler.update_job(
                job_id=job_id,
                trigger=trigger,
                interval=float(interval) if interval is not None else None,
                cron=cron_expr,
                date=date_str
            );
            if updated is None {
                return TransportResponse.fail(
                    code='NOT_FOUND',
                    message=f'Job "{job_id}" not found',
                    meta=Meta(extra={'http_status': 404})
                );
            }
            return TransportResponse.success(
                data=updated, meta=Meta(extra={'http_status': 200})
            );
        } except Exception as e {
            return TransportResponse.fail(
                code='SCHEDULER_ERROR',
                message=str(e),
                meta=Meta(extra={'http_status': 500})
            );
        }
    }
    return callback;
}

"""Build DELETE /jobs/{job_id} callback — deletes a dynamic scheduled job."""
impl JacAPIServerScheduler.delete_job_callback -> Callable[..., TransportResponse] {
    async def callback(request: Request, job_id: str) -> TransportResponse {
        (username, auth_err) = _authenticate_request(request, self.user_manager);
        if auth_err {
            return auth_err;
        }

        try {
            scheduler = JacScaleScheduler.instance();
            deleted = scheduler.delete_job(job_id);
            if not deleted {
                return TransportResponse.fail(
                    code='NOT_FOUND',
                    message=f'Job "{job_id}" not found',
                    meta=Meta(extra={'http_status': 404})
                );
            }
            return TransportResponse.success(
                data={'deleted': True, 'job_id': job_id},
                meta=Meta(extra={'http_status': 200})
            );
        } except Exception as e {
            return TransportResponse.fail(
                code='SCHEDULER_ERROR',
                message=str(e),
                meta=Meta(extra={'http_status': 500})
            );
        }
    }
    return callback;
}
