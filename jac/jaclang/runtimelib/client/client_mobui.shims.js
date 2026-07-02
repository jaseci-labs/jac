// ── Factory registry: constructor-type API → factory ─────────────────────────
export const createAnimatedValue   = (initial = 0)              => new Animated.Value(initial);
export const createAnimatedValueXY = (initial = { x: 0, y: 0 }) => new Animated.ValueXY(initial);
