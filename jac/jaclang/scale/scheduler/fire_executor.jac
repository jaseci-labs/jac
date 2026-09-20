import from apscheduler.executors.base { run_job }
import from apscheduler.executors.pool { ThreadPoolExecutor }

class ScheduledRun {
    def init(self: any, job: any, run_time: any) {
        self._job = job;
        self.kwargs = {** job.kwargs, 'scheduled_at': run_time};
    }

    def __getattr__(self: any, name: str) -> any {
        return getattr(self._job, name);
    }

    def __str__(self: any) -> str {
        return str(self._job);
    }
}

class FireTimeExecutor(ThreadPoolExecutor) {
    def _do_submit_job(self: any, job: any, run_times: list[any]) {
        pool_executor: any = self;
        alias = job._jobstore_alias;
        logger_name = pool_executor._logger.name;

        def run_each -> list[any] {
            events: list[any] = [];
            for run_time in run_times {
                events.extend(
                    run_job(ScheduledRun(job, run_time), alias, [run_time], logger_name)
                );
            }
            return events;
        }

        def finished(future: any) {
            error = future.exception();
            if error is not None {
                pool_executor._run_job_error(job.id, error, error.__traceback__);
            } else {
                pool_executor._run_job_success(job.id, future.result());
            }
        }
        future: any = pool_executor._pool.submit(run_each);
        future.add_done_callback(finished);
    }
}
