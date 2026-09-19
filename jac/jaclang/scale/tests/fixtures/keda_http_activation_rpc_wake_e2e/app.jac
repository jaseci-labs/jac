import from worker { ping }

walker:pub trigger_ping {
    async can run with Root entry {
        rp = await ping();
        report rp.reports[0];
    }
}
