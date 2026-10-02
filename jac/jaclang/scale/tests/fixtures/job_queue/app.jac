import from reviews { Housekeeping, Review, Task }
import from jaclang.scale.jobs { enqueue, job_info }

walker:pub QueueReview {
    has run_id: str,
        hang: bool = False,
        as_root: str = "",
        key: str = "",
        fail_after: bool = False,
        housekeeping: bool = False;

    can go with Root entry {
        if self.housekeeping {
            report {"job_id": enqueue(Housekeeping, {"tenant_root": jid(root)})};
            return;
        }
        task = Task(title=self.run_id);
        here ++> task;
        job_id = enqueue(
            Review,
            {
                "run_id": self.run_id,
                "hang": self.hang,
                "node_id": jid(task),
                "expect_root": self.as_root or jid(root)
            },
            key=self.key,
            queue="agents",
            max_attempts=1,
            timeout_s=0.5 if self.hang else 0.0,
            as_root=self.as_root or None
        );
        if self.fail_after {
            raise RuntimeError("failed after enqueue");
        }
        report {"job_id": job_id};
    }
}

walker:pub ReviewStatus {
    has job_id: str;

    can go with Root entry {
        info = job_info(self.job_id);
        if info is None {
            report {"status": "missing", "last_error": ""};
            return;
        }
        report {
            "status": info.status,
            "last_error": info.last_error,
            "attempts": info.attempts,
            "as_root": info.as_root,
            "enqueued_by": info.enqueued_by,
            "target": info.target
        };
    }
}
