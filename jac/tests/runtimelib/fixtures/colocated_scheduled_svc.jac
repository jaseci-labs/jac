glob TICKS: list[int] = [];

@schedule(trigger=ScheduleTrigger.STATIC, interval=3600)
def:priv svc_tick {
    TICKS.append(1);
}
