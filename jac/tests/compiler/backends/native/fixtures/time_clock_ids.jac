import time;

with entry {
    print(
        time.CLOCK_REALTIME,
        time.CLOCK_MONOTONIC,
        time.CLOCK_MONOTONIC_RAW,
        time.CLOCK_PROCESS_CPUTIME_ID,
        time.CLOCK_THREAD_CPUTIME_ID
    );
    first = time.monotonic();
    time.sleep(0.01);
    print(time.monotonic() > first);
}
