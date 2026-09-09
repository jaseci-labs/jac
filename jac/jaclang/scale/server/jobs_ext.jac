import asyncio;
import logging;
import from jaclang.data.pgwire { PgWireError }
import from jaclang.runtime.builtin { ScheduleTrigger }
import from jaclang.server.identity.user_manager { SYSTEM_USER, UserRole }
import from jaclang.server.middleware { require_user }
import from jaclang.server.server { JacAPIServer, ServerExtension }
import from jaclang.server.serving.datatypes { Request }
import from jaclang.server.serving.endpoint {
    APIParameter,
    HTTPMethod,
    JEndPoint,
    ParameterType
}
import from jaclang.server.transport { Meta, TransportResponse }
import from jaclang.scale.config.config_loader { get_scale_config }
import from jaclang.scale.scheduler.scheduler { JacScaleScheduler, TriggerSpec }
import from jaclang.scale.scheduler.scheduler_models {
    CreateJobRequest,
    UpdateJobRequest
}

glob logger: logging.Logger = logging.getLogger(__name__);


def _fail(code: str, message: str, status: int) -> TransportResponse {
    return TransportResponse.fail(
        code=code, message=message, meta=Meta(extra={'http_status': status})
    );
}


def _err_response(e: Exception) -> TransportResponse {
    if isinstance(e, (PgWireError, OSError)) {
        logger.error(f"Storage failure on /jobs: {type(e).__name__}: {e}");
        return _fail('STORAGE_UNAVAILABLE', 'Job store temporarily unavailable', 503);
    }
    logger.error(f"Scheduler endpoint error: {type(e).__name__}: {e}");
    return _fail('SCHEDULER_ERROR', 'Internal scheduler error', 500);
}


def _build_spec(body: dict) -> tuple[(TriggerSpec | None), (TransportResponse | None)] {
    trigger = body.get('trigger', '');
    if not trigger {
        return (None, _fail('INVALID_REQUEST', 'Field "trigger" is required', 400));
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
        return (None, _fail('INVALID_REQUEST', str(e), 400));
    }
}


obj JobsExtension(ServerExtension) {
    def register(server: JacAPIServer) {
        users = server.user_manager;
        scheduler_cfg = get_scale_config().get_scheduler_config();
        system_user = users.find_user_by_identity(SYSTEM_USER);
        system_user_id = str(system_user.get('user_id', SYSTEM_USER))
            if system_user
            else SYSTEM_USER;
        jobs = JacScaleScheduler.instance();
        jobs.setup(system_user_id=system_user_id, server=server);
        jobs.register_dynamic_tasks_from_db();
        timeout_sec = int(scheduler_cfg.get('shutdown_timeout', 10));

        async def _shutdown {
            try {
                await asyncio.wait_for(
                    asyncio.to_thread(JacScaleScheduler.instance().stop, drain=True),
                    timeout=float(timeout_sec)
                );
            } except asyncio.TimeoutError {
                logger.warning(
                    f"Scheduler drain exceeded {timeout_sec}s; forcing shutdown"
                );
                JacScaleScheduler.instance().stop(drain=False);
            }
        }
        server.add_shutdown_hook(_shutdown);

        def _is_admin(user_id: str) -> bool {
            return users.get_user_role(user_id) == UserRole.ADMIN.value;
        }

        def _ensure_authorized(
            job: (dict | None), user_id: str
        ) -> (TransportResponse | None) {
            if job is None {
                return _fail('NOT_FOUND', 'Job not found', 404);
            }
            if job.get('created_by') == user_id or _is_admin(user_id) {
                return None;
            }
            return _fail('NOT_FOUND', 'Job not found', 404);
        }

        async def create_job(
            request: Request, body_data: CreateJobRequest
        ) -> TransportResponse {
            (user_id, auth_err) = require_user(request);
            if auth_err is not None {
                return auth_err;
            }
            body = body_data.model_dump(mode='python');
            name = body.get('walker_or_function', '');
            (spec, spec_err) = _build_spec(body);
            if spec is None {
                return spec_err or _fail('INVALID_REQUEST', 'Invalid schedule', 400);
            }
            target: any = server.get_walkers().get(name)
                or server.get_functions().get(name);
            if target is None {
                return _fail(
                    'NOT_FOUND', f'Walker or function "{name}" not found', 404
                );
            }
            schedule_spec: any = target.schedule_spec
                if target?.schedule_spec
                else None;
            if schedule_spec is None {
                return _fail(
                    'INVALID_REQUEST',
                    f'"{name}" has no @schedule decorator. Add '
                    '@schedule(trigger=ScheduleTrigger.DYNAMIC) to enable dynamic scheduling.',
                    400
                );
            }
            if schedule_spec.trigger != ScheduleTrigger.DYNAMIC {
                return _fail(
                    'INVALID_REQUEST',
                    f'"{name}" uses trigger={schedule_spec.trigger.value!r}; only DYNAMIC '
                    'targets can be scheduled through /jobs.',
                    400
                );
            }
            try {
                job = JacScaleScheduler.instance().create_job(
                    name=name, spec=spec, created_by=str(user_id)
                );
                return TransportResponse.success(
                    data=job, meta=Meta(extra={'http_status': 201})
                );
            } except Exception as e {
                return _err_response(e);
            }
        }

        async def list_jobs(request: Request) -> TransportResponse {
            (user_id, auth_err) = require_user(request);
            if auth_err is not None {
                return auth_err;
            }
            params = request.query_params;
            try {
                limit = min(max(int(params.get('limit', '50')), 1), 500);
                offset = max(int(params.get('offset', '0')), 0);
            } except (ValueError, TypeError) {
                return _fail(
                    'INVALID_REQUEST', 'limit and offset must be integers', 400
                );
            }
            try {
                creator = params.get('created_by')
                    if _is_admin(str(user_id))
                    else str(user_id);
                (page, total) = JacScaleScheduler.instance().list_jobs(
                    limit=limit,
                    offset=offset,
                    trigger=params.get('trigger'),
                    created_by=creator
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

        async def get_job(request: Request, job_id: str) -> TransportResponse {
            (user_id, auth_err) = require_user(request);
            if auth_err is not None {
                return auth_err;
            }
            try {
                job = JacScaleScheduler.instance().get_job(job_id);
                access_err = _ensure_authorized(job, str(user_id));
                if access_err is not None {
                    return access_err;
                }
                return TransportResponse.success(
                    data=job, meta=Meta(extra={'http_status': 200})
                );
            } except Exception as e {
                return _err_response(e);
            }
        }

        async def update_job(
            request: Request, job_id: str, body_data: UpdateJobRequest
        ) -> TransportResponse {
            (user_id, auth_err) = require_user(request);
            if auth_err is not None {
                return auth_err;
            }
            (spec, spec_err) = _build_spec(body_data.model_dump(mode='python'));
            if spec is None {
                return spec_err or _fail('INVALID_REQUEST', 'Invalid schedule', 400);
            }
            try {
                acting_as = None if _is_admin(str(user_id)) else str(user_id);
                updated = JacScaleScheduler.instance().update_job(
                    job_id=job_id, spec=spec, acting_as=acting_as
                );
                if updated is None {
                    return _fail('NOT_FOUND', 'Job not found', 404);
                }
                return TransportResponse.success(
                    data=updated, meta=Meta(extra={'http_status': 200})
                );
            } except Exception as e {
                return _err_response(e);
            }
        }

        async def delete_job(request: Request, job_id: str) -> TransportResponse {
            (user_id, auth_err) = require_user(request);
            if auth_err is not None {
                return auth_err;
            }
            try {
                acting_as = None if _is_admin(str(user_id)) else str(user_id);
                if not JacScaleScheduler.instance().delete_job(
                    job_id, acting_as=acting_as
                ) {
                    return _fail('NOT_FOUND', 'Job not found', 404);
                }
                return TransportResponse.success(
                    data={'deleted': True, 'job_id': job_id},
                    meta=Meta(extra={'http_status': 200})
                );
            } except Exception as e {
                return _err_response(e);
            }
        }

        job_id_param = [
            APIParameter(
                name='job_id',
                data_type='str',
                required=True,
                description='Job ID',
                kind=ParameterType.PATH
            )
        ];
        server.add_endpoint(
            JEndPoint(
                method=HTTPMethod.POST,
                path='/jobs',
                callback=create_job,
                parameters=[],
                request_model=CreateJobRequest,
                tags=['Scheduler'],
                summary='Create scheduled job',
                description='Schedule a walker or function decorated with @schedule(trigger=ScheduleTrigger.DYNAMIC).',
                requires_auth=True
            )
        );
        server.add_endpoint(
            JEndPoint(
                method=HTTPMethod.GET,
                path='/jobs',
                callback=list_jobs,
                parameters=[],
                tags=['Scheduler'],
                summary='List scheduled jobs',
                requires_auth=True
            )
        );
        server.add_endpoint(
            JEndPoint(
                method=HTTPMethod.GET,
                path='/jobs/{job_id}',
                callback=get_job,
                parameters=job_id_param,
                tags=['Scheduler'],
                summary='Get scheduled job',
                requires_auth=True
            )
        );
        server.add_endpoint(
            JEndPoint(
                method=HTTPMethod.PUT,
                path='/jobs/{job_id}',
                callback=update_job,
                parameters=job_id_param,
                request_model=UpdateJobRequest,
                tags=['Scheduler'],
                summary='Update scheduled job',
                requires_auth=True
            )
        );
        server.add_endpoint(
            JEndPoint(
                method=HTTPMethod.DELETE,
                path='/jobs/{job_id}',
                callback=delete_job,
                parameters=job_id_param,
                tags=['Scheduler'],
                summary='Delete scheduled job',
                requires_auth=True
            )
        );
    }

    def on_worker_start(server: JacAPIServer) {
        JacScaleScheduler.instance().start();
    }
}
