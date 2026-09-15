import from worker { ping }

walker:pub trigger_ping {
    can run with Root entry {
        rp = ping();
        report rp.reports[0];
    }
}
