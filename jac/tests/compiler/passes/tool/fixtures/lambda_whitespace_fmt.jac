def main -> None {
    useEffect(
        lambda -> any {
            if not autoRefresh {
                return undefined;
            }
            interval = setInterval(lambda { loadMetrics(); }, 3000);
            return lambda { clearInterval(interval); };
        },
        [autoRefresh]
    );
}
