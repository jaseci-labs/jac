import from jac_scale.utils { authenticate_or_fail }
import from jac_scale._optdeps.pymongo { PyMongoError }

"""Map an exception to the caller-facing TransportResponse.

PyMongoError → 503 STORAGE_UNAVAILABLE; anything else → 500 SCHEDULER_ERROR.
Single call site for the catch-block in every /jobs endpoint.
"""
def _err_response(e: Exception) -> TransportResponse {
    if isinstance(e, PyMongoError) {
        logger.error(f"Storage failure on /jobs: {type(e).__name__}: {e}");
        return TransportResponse.fail(
            code='STORAGE_UNAVAILABLE',
            message='Job store temporarily unavailable',
            meta=Meta(extra={'http_status': 503})
        );
    }
    logger.error(f"Scheduler endpoint error: {type(e).__name__}: {e}");
    return TransportResponse.fail(
        code='SCHEDULER_ERROR',
        message='Internal scheduler error',
        meta=Meta(extra={'http_status': 500})
    );
}

"""Authenticate the Authorization header and return (user_id, err).

Thin wrapper so every /jobs callback can do a one-line auth + early-return
instead of repeating header extraction + fail-shape assembly.
"""
def _require_auth(
    request: Any, user_manager: Any
) -> tuple[str | None, TransportResponse | None] {
    return authenticate_or_fail(request.headers.get('Authorization'), user_manager);
}

"""Return a 404 response if `job` is None or caller is neither creator nor admin.

Uses 404 for unauthorized access so existence of another user's job is not leaked.
"""
def _ensure_authorized(
    job: dict | None, user_id: str, user_manager: Any
) -> TransportResponse | None {
    not_found = TransportResponse.fail(
        code='NOT_FOUND', message='Job not found', meta=Meta(extra={'http_status': 404})
    );
    if job is None {
        return not_found;
    }
    if job.get('created_by') == user_id {
        return None;
    }
    if user_manager.get_user_role(user_id) == 'admin' {
        return None;
    }
    return not_found;
}

"""Build a TriggerSpec from the request body. Returns (spec, None) or (None, err)."""
def _build_spec(body: dict) -> tuple[TriggerSpec | None, TransportResponse | None] {
    trigger = body.get('trigger', '');
    if not trigger {
        return (
            None,
            TransportResponse.fail(
                code='INVALID_REQUEST',
                message='Field "trigger" is required',
                meta=Meta(extra={'http_status': 400})
            )
        );
    }
    interval = body.get('interval');
    try {
        spec = TriggerSpec.validate(
            trigger=trigger,
            interval=float(interval) if interval is not None else None,
            cron=body.get('cron'),
            date=body.get('date')
        );
        return (spec, None);
    } except (ValueError, TypeError) as e {
        return (
            None,
            TransportResponse.fail(
                code='INVALID_REQUEST',
                message=str(e),
                meta=Meta(extra={'http_status': 400})
            )
        );
    }
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
            request_model=CreateJobRequest,
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
            request_model=UpdateJobRequest,
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
    async def callback(
        request: Request, body_data: CreateJobRequest
    ) -> TransportResponse {
        (user_id, auth_err) = _require_auth(request, self.user_manager);
        if auth_err {
            return auth_err;
        }

        # body_data is already validated by Pydantic — required fields are
        # guaranteed present, types are coerced.
        body = body_data.model_dump(mode='python');
        walker_or_function = body.get('walker_or_function', '');

        (spec, spec_err) = _build_spec(body);
        if spec_err or spec is None {
            return spec_err;
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
            scheduler = JacScaleScheduler.instance();
            job = scheduler.create_job(
                name=walker_or_function, spec=spec, created_by=user_id
            );
            return TransportResponse.success(
                data=job, meta=Meta(extra={'http_status': 201})
            );
        } except Exception as e {
            return _err_response(e);
        }
    }
    return callback;
}

"""Build GET /jobs callback — lists dynamic scheduled jobs with pagination + filters.

Query parameters:
  limit       - max items per page (default 50, max 500)
  offset      - items to skip (default 0)
  trigger     - filter by trigger type ('interval' | 'cron' | 'date')
  created_by  - filter by creator user_id (admin only; ignored for non-admins)
"""
impl JacAPIServerScheduler.list_jobs_callback -> Callable[..., TransportResponse] {
    async def callback(request: Request) -> TransportResponse {
        (user_id, auth_err) = _require_auth(request, self.user_manager);
        if auth_err {
            return auth_err;
        }

        params = request.query_params;
        try {
            limit = min(max(int(params.get('limit', '50')), 1), 500);
            offset = max(int(params.get('offset', '0')), 0);
        } except (ValueError, TypeError) {
            return TransportResponse.fail(
                code='INVALID_REQUEST',
                message='limit and offset must be integers',
                meta=Meta(extra={'http_status': 400})
            );
        }
        trigger_filter = params.get('trigger');
        creator_filter = params.get('created_by');

        try {
            is_admin = self.user_manager.get_user_role(user_id) == 'admin';
            # Non-admins only see their own jobs; creator_filter is admin-only.
            effective_creator = user_id if not is_admin else creator_filter;
            scheduler = JacScaleScheduler.instance();
            (page, total) = scheduler.list_jobs(
                limit=limit,
                offset=offset,
                trigger=trigger_filter,
                created_by=effective_creator
            );
            return TransportResponse.success(
                data={
                    'jobs': page,
                    'count': len(page),
                    'total': total,
                    'limit': limit,
                    'offset': offset
                },
                meta=Meta(extra={'http_status': 200})
            );
        } except Exception as e {
            return _err_response(e);
        }
    }
    return callback;
}

"""Build GET /jobs/{job_id} callback — retrieves a single dynamic job."""
impl JacAPIServerScheduler.get_job_callback -> Callable[..., TransportResponse] {
    async def callback(request: Request, job_id: str) -> TransportResponse {
        (user_id, auth_err) = _require_auth(request, self.user_manager);
        if auth_err {
            return auth_err;
        }

        try {
            scheduler = JacScaleScheduler.instance();
            job = scheduler.get_job(job_id);
            access_err = _ensure_authorized(job, user_id, self.user_manager);
            if access_err {
                return access_err;
            }
            return TransportResponse.success(
                data=job, meta=Meta(extra={'http_status': 200})
            );
        } except Exception as e {
            return _err_response(e);
        }
    }
    return callback;
}

"""Build PUT /jobs/{job_id} callback — updates an existing dynamic job's schedule."""
impl JacAPIServerScheduler.update_job_callback -> Callable[..., TransportResponse] {
    async def callback(
        request: Request, job_id: str, body_data: UpdateJobRequest
    ) -> TransportResponse {
        (user_id, auth_err) = _require_auth(request, self.user_manager);
        if auth_err {
            return auth_err;
        }

        # Pydantic has already validated the body — _build_spec runs the
        # trigger-specific field checks and the CronTrigger structural parse.
        (spec, spec_err) = _build_spec(body_data.model_dump(mode='python'));
        if spec_err or spec is None {
            return spec_err;
        }

        try {
            is_admin = self.user_manager.get_user_role(user_id) == 'admin';
            acting_as = None if is_admin else user_id;
            scheduler = JacScaleScheduler.instance();
            updated = scheduler.update_job(
                job_id=job_id, spec=spec, acting_as=acting_as
            );
            if updated is None {
                return TransportResponse.fail(
                    code='NOT_FOUND',
                    message='Job not found',
                    meta=Meta(extra={'http_status': 404})
                );
            }
            return TransportResponse.success(
                data=updated, meta=Meta(extra={'http_status': 200})
            );
        } except Exception as e {
            return _err_response(e);
        }
    }
    return callback;
}

"""Build DELETE /jobs/{job_id} callback — deletes a dynamic scheduled job."""
impl JacAPIServerScheduler.delete_job_callback -> Callable[..., TransportResponse] {
    async def callback(request: Request, job_id: str) -> TransportResponse {
        (user_id, auth_err) = _require_auth(request, self.user_manager);
        if auth_err {
            return auth_err;
        }

        try {
            is_admin = self.user_manager.get_user_role(user_id) == 'admin';
            acting_as = None if is_admin else user_id;
            scheduler = JacScaleScheduler.instance();
            deleted = scheduler.delete_job(job_id, acting_as=acting_as);
            if not deleted {
                return TransportResponse.fail(
                    code='NOT_FOUND',
                    message='Job not found',
                    meta=Meta(extra={'http_status': 404})
                );
            }
            return TransportResponse.success(
                data={'deleted': True, 'job_id': job_id},
                meta=Meta(extra={'http_status': 200})
            );
        } except Exception as e {
            return _err_response(e);
        }
    }
    return callback;
}
