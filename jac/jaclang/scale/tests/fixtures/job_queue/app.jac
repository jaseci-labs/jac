import from reviews { Review }
import from jaclang.scale.jobs { enqueue, job_info }

walker:pub QueueReview {
    has run_id: str,
        hang: bool = False;

    can go with Root entry {
        job_id = enqueue(
            Review,
            {"run_id": self.run_id, "hang": self.hang},
            queue="agents",
            max_attempts=1,
            timeout_s=0.5 if self.hang else 0.0
        );
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
        report {"status": info.status, "last_error": info.last_error};
    }
}
