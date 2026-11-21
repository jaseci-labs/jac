glob PI: float = 3.141592653589793,
     TWO_PI: float = 6.283185307179586,
     HALF_PI: float = 1.5707963267948796,
     DEG2RAD: float = 0.017453292519943295;

def jcos(a: float) -> float;

def jsin(a: float) -> float;

def jsqrt(v: float) -> float;

def lerp(a: float, b: float, t: float) -> float;

def clampf(v: float, lo: float, hi: float) -> float;

obj Rng {
    has state: int = 987654321;
}

def rand01(r: &mut Rng) -> float;

def rand_range(r: &mut Rng, lo: float, hi: float) -> float;

def rand_sign(r: &mut Rng) -> float;
