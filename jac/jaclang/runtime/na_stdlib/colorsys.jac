glob ONE_THIRD: float = 1.0 / 3.0,
     ONE_SIXTH: float = 1.0 / 6.0,
     TWO_THIRD: float = 2.0 / 3.0;


def:pub rgb_to_yiq(r: float, g: float, b: float) -> tuple[float, float, float];


def:pub yiq_to_rgb(y: float, i: float, q: float) -> tuple[float, float, float];


def:pub rgb_to_hls(r: float, g: float, b: float) -> tuple[float, float, float];


def _v(m1: float, m2: float, hue: float) -> float;


def:pub hls_to_rgb(h: float, l: float, s: float) -> tuple[float, float, float];


def:pub rgb_to_hsv(r: float, g: float, b: float) -> tuple[float, float, float];


def:pub hsv_to_rgb(h: float, s: float, v: float) -> tuple[float, float, float];
