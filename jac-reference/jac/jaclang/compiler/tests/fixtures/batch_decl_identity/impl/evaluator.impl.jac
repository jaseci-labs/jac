impl Evaluator.produce(flag: bool) -> Box | None {
    if flag {
        return Box(value=1);
    }
    return None;
}
