def:priv bits(value: i64) -> int;

def:pub jacpy_math_gcd(arguments: ptr[PyObject], lcm: i64) -> ptr[PyObject];

def:priv odd_product(start: i64, stop: i64) -> ptr[PyObject];

def:pub jacpy_math_factorial(argument: ptr[PyObject]) -> ptr[PyObject];

def:pub jacpy_math_isqrt(argument: ptr[PyObject]) -> ptr[PyObject];

import from c {
    glob:priv reduced_factorial_odd_part: list[u64] = [
             u64(0x1),
             u64(0x1),
             u64(0x1),
             u64(0x3),
             u64(0x3),
             u64(0xf),
             u64(0x2d),
             u64(0x13b),
             u64(0x13b),
             u64(0xb13),
             u64(0x375f),
             u64(0x26115),
             u64(0x7233f),
             u64(0x5cca33),
             u64(0x2898765),
             u64(0x260eeeeb),
             u64(0x260eeeeb),
             u64(0x286fddd9b),
             u64(0x16beecca73),
             u64(0x1b02b930689),
             u64(0x870d9df20ad),
             u64(0xb141df4dae31),
             u64(0x79dd498567c1b),
             u64(0xaf2e19afc5266d),
             u64(0x20d8a4d0f4f7347),
             u64(0x335281867ec241ef),
             u64(0x9b3093d46fdd5923),
             u64(0x5e1f9767cc5866b1),
             u64(0x92dd23d6966aced7),
             u64(0xa30d0f4f0a196e5b),
             u64(0x8dc3e5a1977d7755),
             u64(0x2ab8ce915831734b),
             u64(0x2ab8ce915831734b),
             u64(0x81d2a0bc5e5fdcab),
             u64(0x9efcac82445da75b),
             u64(0xbc8b95cf58cde171),
             u64(0xa0e8444a1f3cecf9),
             u64(0x4191deb683ce3ffd),
             u64(0xddd3878bc84ebfc7),
             u64(0xcb39a64b83ff3751),
             u64(0xf8203f7993fc1495),
             u64(0xbd2a2a78b35f4bdd),
             u64(0x84757be6b6d13921),
             u64(0x3fbbcfc0b524988b),
             u64(0xbd11ed47c8928df9),
             u64(0x3c26b59e41c2f4c5),
             u64(0x677a5137e883fdb3),
             u64(0xff74e943b03b93dd),
             u64(0xfe5ebbcb10b2bb97),
             u64(0xb021f1de3235e7e7),
             u64(0x33509eb2e743a58f),
             u64(0x390f9da41279fb7d),
             u64(0xe5cb0154f031c559),
             u64(0x93074695ba4ddb6d),
             u64(0x81c471caa636247f),
             u64(0xe1347289b5a1d749),
             u64(0x286f21c3f76ce2ff),
             u64(0xbe84a2173e8ac7),
             u64(0x1595065ca215b88b),
             u64(0xf95877595b018809),
             u64(0x9c2efe3c5516f887),
             u64(0x373294604679382b),
             u64(0xaf1ff7a888adcd35),
             u64(0x18ddf279a2c5800b),
             u64(0x18ddf279a2c5800b),
             u64(0x505a90e2542582cb),
             u64(0x5bacad2cd8d5dc2b),
             u64(0xfe3152bcbff89f41),
             u64(0xe1467e88bf829351),
             u64(0xb8001adb9e31b4d5),
             u64(0x2803ac06a0cbb91f),
             u64(0x1904b5d698805799),
             u64(0xe12a648b5c831461),
             u64(0x3516abbd6160cfa9),
             u64(0xac46d25f12fe036d),
             u64(0x78bfa1da906b00ef),
             u64(0xf6390338b7f111bd),
             u64(0xf25f80f538255d9),
             u64(0x4ec8ca55b8db140f),
             u64(0x4ff670740b9b30a1),
             u64(0x8fd032443a07f325),
             u64(0x80dfe7965c83eeb5),
             u64(0xa3dc1714d1213afd),
             u64(0x205b7bbfcdc62007),
             u64(0xa78126bbe140a093),
             u64(0x9de1dc61ca7550cf),
             u64(0x84f0046d01b492c5),
             u64(0x2d91810b945de0f3),
             u64(0xf5408b7f6008aa71),
             u64(0x43707f4863034149),
             u64(0xdac65fb9679279d5),
             u64(0xc48406e7d1114eb7),
             u64(0xa7dc9ed3c88e1271),
             u64(0xfb25b2efdb9cb30d),
             u64(0x1bebda0951c4df63),
             u64(0x5c85e975580ee5bd),
             u64(0x1591bc60082cb137),
             u64(0x2c38606318ef25d7),
             u64(0x76ca72f7c5c63e27),
             u64(0xf04a75d17baa0915),
             u64(0x77458175139ae30d),
             u64(0xe6c1330bc1b9421),
             u64(0xdf87d2b5797e8293),
             u64(0xefa5c703e1e68925),
             u64(0x2b6b1b3278b4f6e1),
             u64(0xceee27b382394249),
             u64(0xd74e3829f5dab91d),
             u64(0xfdb17989c26b5f1f),
             u64(0xc1b7d18781530845),
             u64(0x7b4436b2105a8561),
             u64(0x7ba7c0418372a7d7),
             u64(0x9dbc5c67feb6c639),
             u64(0x502686d7f6ff6b8f),
             u64(0x6101855406be7a1f),
             u64(0x9956afb5806930e7),
             u64(0xe1f0ee88af40f7c5),
             u64(0x984b057bda5c1151),
             u64(0x9a49819acc13ea05),
             u64(0x8ef0dead0896ef27),
             u64(0x71f7826efe292b21),
             u64(0xad80a480e46986ef),
             u64(0x1cdc0ebf5e0c6f7),
             u64(0x6e06f839968f68db),
             u64(0xdd5943ab56e76139),
             u64(0xcdcf31bf8604c5e7),
             u64(0x7e2b4a847054a1cb),
             u64(0xca75697a4d3d0f5),
             u64(0x4703f53ac514a98b)
         ],
         inverted_factorial_odd_part: list[u64] = [
             u64(0x1),
             u64(0x1),
             u64(0x1),
             u64(0xaaaaaaaaaaaaaaab),
             u64(0xaaaaaaaaaaaaaaab),
             u64(0xeeeeeeeeeeeeeeef),
             u64(0x4fa4fa4fa4fa4fa5),
             u64(0x2ff2ff2ff2ff2ff3),
             u64(0x2ff2ff2ff2ff2ff3),
             u64(0x938cc70553e3771b),
             u64(0xb71c27cddd93e49f),
             u64(0xb38e3229fcdee63d),
             u64(0xe684bb63544a4cbf),
             u64(0xc2f684917ca340fb),
             u64(0xf747c9cba417526d),
             u64(0xbb26eb51d7bd49c3),
             u64(0xbb26eb51d7bd49c3),
             u64(0xb0a7efb985294093),
             u64(0xbe4b8c69f259eabb),
             u64(0x6854d17ed6dc4fb9),
             u64(0xe1aa904c915f4325),
             u64(0x3b8206df131cead1),
             u64(0x79c6009fea76fe13),
             u64(0xd8c5d381633cd365),
             u64(0x4841f12b21144677),
             u64(0x4a91ff68200b0d0f),
             u64(0x8f9513a58c4f9e8b),
             u64(0x2b3e690621a42251),
             u64(0x4f520f00e03c04e7),
             u64(0x2edf84ee600211d3),
             u64(0xadcaa2764aaacdfd),
             u64(0x161f4f9033f4fe63),
             u64(0x161f4f9033f4fe63),
             u64(0xbada2932ea4d3e03),
             u64(0xcec189f3efaa30d3),
             u64(0xf7475bb68330bf91),
             u64(0x37eb7bf7d5b01549),
             u64(0x46b35660a4e91555),
             u64(0xa567c12d81f151f7),
             u64(0x4c724007bb2071b1),
             u64(0xf4a0cce58a016bd),
             u64(0xfa21068e66106475),
             u64(0x244ab72b5a318ae1),
             u64(0x366ce67e080d0f23),
             u64(0xd666fdae5dd2a449),
             u64(0xd740ddd0acc06a0d),
             u64(0xb050bbbb28e6f97b),
             u64(0x70b003fe890a5c75),
             u64(0xd03aabff83037427),
             u64(0x13ec4ca72c783bd7),
             u64(0x90282c06afdbd96f),
             u64(0x4414ddb9db4a95d5),
             u64(0xa2c68735ae6832e9),
             u64(0xbf72d71455676665),
             u64(0xa8469fab6b759b7f),
             u64(0xc1e55b56e606caf9),
             u64(0x40455630fc4a1cff),
             u64(0x120a7b0046d16f7),
             u64(0xa7c3553b08faef23),
             u64(0x9f0bfd1b08d48639),
             u64(0xa433ffce9a304d37),
             u64(0xa22ad1d53915c683),
             u64(0xcb6cbc723ba5dd1d),
             u64(0x547fb1b8ab9d0ba3),
             u64(0x547fb1b8ab9d0ba3),
             u64(0x8f15a826498852e3),
             u64(0x32e1a03f38880283),
             u64(0x3de4cce63283f0c1),
             u64(0x5dfe6667e4da95b1),
             u64(0xfda6eeeef479e47d),
             u64(0xf14de991cc7882df),
             u64(0xe68db79247630ca9),
             u64(0xa7d6db8207ee8fa1),
             u64(0x255e1f0fcf034499),
             u64(0xc9a8990e43dd7e65),
             u64(0x3279b6f289702e0f),
             u64(0xe7b5905d9b71b195),
             u64(0x3025ba41ff0da69),
             u64(0xb7df3d6d3be55aef),
             u64(0xf89b212ebff2b361),
             u64(0xfe856d095996f0ad),
             u64(0xd6e533e9fdf20f9d),
             u64(0xf8c0e84a63da3255),
             u64(0xa677876cd91b4db7),
             u64(0x7ed4f97780d7d9b),
             u64(0x90a8705f258db62f),
             u64(0xa41bbb2be31b1c0d),
             u64(0x6ec28690b038383b),
             u64(0xdb860c3bb2edd691),
             u64(0x838286838a980f9),
             u64(0x558417a74b36f77d),
             u64(0x71779afc3646ef07),
             u64(0x743cda377ccb6e91),
             u64(0x7fdf9f3fe89153c5),
             u64(0xdc97d25df49b9a4b),
             u64(0x76321a778eb37d95),
             u64(0x7cbb5e27da3bd487),
             u64(0x9cff4ade1a009de7),
             u64(0x70eb166d05c15197),
             u64(0xdcf0460b71d5fe3d),
             u64(0x5ac1ee5260b6a3c5),
             u64(0xc922dedfdd78efe1),
             u64(0xe5d381dc3b8eeb9b),
             u64(0xd57e5347bafc6aad),
             u64(0x86939040983acd21),
             u64(0x395b9d69740a4ff9),
             u64(0x1467299c8e43d135),
             u64(0x5fe440fcad975cdf),
             u64(0xcaa9a39794a6ca8d),
             u64(0xf61dbd640868dea1),
             u64(0xac09d98d74843be7),
             u64(0x2b103b9e1a6b4809),
             u64(0x2ab92d16960f536f),
             u64(0x6653323d5e3681df),
             u64(0xefd48c1c0624e2d7),
             u64(0xa496fefe04816f0d),
             u64(0x1754a7b07bbdd7b1),
             u64(0x23353c829a3852cd),
             u64(0xbf831261abd59097),
             u64(0x57a8e656df0618e1),
             u64(0x16e9206c3100680f),
             u64(0xadad4c6ee921dac7),
             u64(0x635f2b3860265353),
             u64(0xdd6d0059f44b3d09),
             u64(0xac4dd6b894447dd7),
             u64(0x42ea183eeaa87be3),
             u64(0x15612d1550ee5b5d),
             u64(0x226fa19d656cb623)
         ],
         factorial_trailing_zeros: list[u8] = [
             u8(0),
             u8(0),
             u8(1),
             u8(1),
             u8(3),
             u8(3),
             u8(4),
             u8(4),
             u8(7),
             u8(7),
             u8(8),
             u8(8),
             u8(10),
             u8(10),
             u8(11),
             u8(11),
             u8(15),
             u8(15),
             u8(16),
             u8(16),
             u8(18),
             u8(18),
             u8(19),
             u8(19),
             u8(22),
             u8(22),
             u8(23),
             u8(23),
             u8(25),
             u8(25),
             u8(26),
             u8(26),
             u8(31),
             u8(31),
             u8(32),
             u8(32),
             u8(34),
             u8(34),
             u8(35),
             u8(35),
             u8(38),
             u8(38),
             u8(39),
             u8(39),
             u8(41),
             u8(41),
             u8(42),
             u8(42),
             u8(46),
             u8(46),
             u8(47),
             u8(47),
             u8(49),
             u8(49),
             u8(50),
             u8(50),
             u8(53),
             u8(53),
             u8(54),
             u8(54),
             u8(56),
             u8(56),
             u8(57),
             u8(57),
             u8(63),
             u8(63),
             u8(64),
             u8(64),
             u8(66),
             u8(66),
             u8(67),
             u8(67),
             u8(70),
             u8(70),
             u8(71),
             u8(71),
             u8(73),
             u8(73),
             u8(74),
             u8(74),
             u8(78),
             u8(78),
             u8(79),
             u8(79),
             u8(81),
             u8(81),
             u8(82),
             u8(82),
             u8(85),
             u8(85),
             u8(86),
             u8(86),
             u8(88),
             u8(88),
             u8(89),
             u8(89),
             u8(94),
             u8(94),
             u8(95),
             u8(95),
             u8(97),
             u8(97),
             u8(98),
             u8(98),
             u8(101),
             u8(101),
             u8(102),
             u8(102),
             u8(104),
             u8(104),
             u8(105),
             u8(105),
             u8(109),
             u8(109),
             u8(110),
             u8(110),
             u8(112),
             u8(112),
             u8(113),
             u8(113),
             u8(116),
             u8(116),
             u8(117),
             u8(117),
             u8(119),
             u8(119),
             u8(120),
             u8(120)
         ],
         fast_comb_limits1: list[u8] = [
             u8(0),
             u8(0),
             u8(127),
             u8(127),
             u8(127),
             u8(127),
             u8(127),
             u8(127),
             u8(127),
             u8(127),
             u8(127),
             u8(127),
             u8(127),
             u8(127),
             u8(127),
             u8(127),
             u8(116),
             u8(105),
             u8(97),
             u8(91),
             u8(86),
             u8(82),
             u8(78),
             u8(76),
             u8(74),
             u8(72),
             u8(71),
             u8(70),
             u8(69),
             u8(68),
             u8(68),
             u8(67),
             u8(67),
             u8(67),
             u8(67)
         ],
         fast_comb_limits2: list[u64] = [
             u64(0x0),
             u64(0xffffffffffffffff),
             u64(0x100000000),
             u64(0x32cbfe),
             u64(0x190aa),
             u64(0x349b),
             u64(0xe1c),
             u64(0x5a9),
             u64(0x2ea),
             u64(0x1c5),
             u64(0x134),
             u64(0xe3),
             u64(0xb2),
             u64(0x93)
         ],
         fast_perm_limits: list[u64] = [
             u64(0x0),
             u64(0xffffffffffffffff),
             u64(0x100000000),
             u64(0x285146),
             u64(0x10001),
             u64(0x1bdd),
             u64(0x65b),
             u64(0x238),
             u64(0x103),
             u64(0x8e),
             u64(0x58),
             u64(0x3d),
             u64(0x2d),
             u64(0x24),
             u64(0x1e),
             u64(0x1a),
             u64(0x18),
             u64(0x16),
             u64(0x15),
             u64(0x14),
             u64(0x14)
         ];
}

def:priv table_u64(table: ptr[u64], index: u64) -> u64;

def:priv table_u8(table: ptr[u8], index: u64) -> u64;

def:priv perm_comb_small(n: u64, k: u64, combination: bool) -> ptr[PyObject];

def:priv perm_comb(n: ptr[PyObject], k: i64, combination: bool) -> ptr[PyObject];

def:pub jacpy_math_comb(
    n_arg: ptr[PyObject], k_arg: ptr[PyObject], combination: i64
) -> ptr[PyObject];

def:priv input_float(value: ptr[PyObject]) -> float;

def:priv float_repr(value: float) -> str;

def:priv domain(operation: i64, value: float);

def:priv logarithm(value: ptr[PyObject], base: int) -> float;

glob:priv pi: float = 3.141592653589793238462643383279502884197,
     logpi: float = 1.144729885849400174143427351353058711647,
     lanczos_g: float = 6.024680040776729583740234375,
     lanczos_g_minus_half: float = 5.524680040776729583740234375,
     lanczos_num_coeffs: list[float] = [
         23531376880.410759688572007674451636754734846804940,
         42919803642.649098768957899047001988850926355848959,
         35711959237.355668049440185451547166705960488635843,
         17921034426.037209699919755754458931112671403265390,
         6039542586.3520280050642916443072979210699388420708,
         1439720407.3117216736632230727949123939715485786772,
         248874557.86205415651146038641322942321632125127801,
         31426415.585400194380614231628318205362874684987640,
         2876370.6289353724412254090516208496135991145378768,
         186056.26539522349504029498971604569928220784236328,
         8071.6720023658162106380029022722506138218516325024,
         210.82427775157934587250973392071336271166969580291,
         2.5066282746310002701649081771338373386264310793408
     ],
     lanczos_den_coeffs: list[float] = [
         0.0,
         39916800.0,
         120543840.0,
         150917976.0,
         105258076.0,
         45995730.0,
         13339535.0,
         2637558.0,
         357423.0,
         32670.0,
         1925.0,
         66.0,
         1.0
     ],
     gamma_integral: list[float] = [
         1.0,
         1.0,
         2.0,
         6.0,
         24.0,
         120.0,
         720.0,
         5040.0,
         40320.0,
         362880.0,
         3628800.0,
         39916800.0,
         479001600.0,
         6227020800.0,
         87178291200.0,
         1307674368000.0,
         20922789888000.0,
         355687428096000.0,
         6402373705728000.0,
         121645100408832000.0,
         2432902008176640000.0,
         51090942171709440000.0,
         1124000727777607680000.0
     ];

def:priv m_sinpi(x: float) -> float;

def:priv lanczos_sum(x: float) -> float;

def:priv m_tgamma(x: float) -> tuple[float, int];

def:priv m_lgamma(x: float) -> tuple[float, int];

def:pub jacpy_math_log(value: ptr[PyObject], base: ptr[PyObject]) -> ptr[PyObject];

def:pub jacpy_math_unary(operation: i64, value: ptr[PyObject]) -> ptr[PyObject];

def:pub jacpy_math_binary(
    operation: i64, a: ptr[PyObject], b: ptr[PyObject]
) -> ptr[PyObject];

def:pub jacpy_math_parts(operation: i64, value: ptr[PyObject]) -> ptr[PyObject];

def:pub jacpy_math_ldexp(
    value: ptr[PyObject], exponent: ptr[PyObject]
) -> ptr[PyObject];

def:pub jacpy_math_fma(
    a: ptr[PyObject], b: ptr[PyObject], c: ptr[PyObject]
) -> ptr[PyObject];

def:pub jacpy_math_isclose(
    a: ptr[PyObject], b: ptr[PyObject], rel: ptr[PyObject], abs_tol: ptr[PyObject]
) -> ptr[PyObject];

def:pub jacpy_math_nextafter(
    a: ptr[PyObject], b: ptr[PyObject], steps: ptr[PyObject]
) -> ptr[PyObject];

def:pub jacpy_math_fsum(iterable: ptr[PyObject]) -> ptr[PyObject];

def:priv double_sum(a: float, b: float) -> tuple[float, float];

def:priv fast_sum(a: float, b: float) -> tuple[float, float];

def:priv double_product(a: float, b: float) -> tuple[float, float];

def:priv triple_product(
    a: float, b: float, total: tuple[float, float, float]
) -> tuple[float, float, float];

def:priv triple_value(total: tuple[float, float, float]) -> float;

def:priv norm(values: list[float], largest: float, found_nan: bool) -> float;

def:pub jacpy_math_hypot(arguments: ptr[PyObject]) -> ptr[PyObject];

def:pub jacpy_math_dist(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject];

def:pub jacpy_math_prod(
    iterable: ptr[PyObject], start: ptr[PyObject]
) -> ptr[PyObject];

def:pub jacpy_math_sumprod(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject];

def:priv float_object(value: f64) -> ptr[PyObject];

def:priv unary_float(operation: int, x: f64) -> ptr[PyObject];

def:priv binary_float(operation: int, x: f64, y: f64) -> ptr[PyObject];

def math_gcd_impl(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def math_lcm_impl(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def math_hypot_impl(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def math_ceil_impl(module: ptr[PyObject], x: ptr[PyObject]) -> ptr[PyObject];

def math_floor_impl(module: ptr[PyObject], x: ptr[PyObject]) -> ptr[PyObject];

def math_trunc_impl(module: ptr[PyObject], x: ptr[PyObject]) -> ptr[PyObject];

def math_log10_impl(module: ptr[PyObject], x: ptr[PyObject]) -> ptr[PyObject];

def math_log2_impl(module: ptr[PyObject], x: ptr[PyObject]) -> ptr[PyObject];

def math_fsum_impl(module: ptr[PyObject], seq: ptr[PyObject]) -> ptr[PyObject];

def math_isqrt_impl(module: ptr[PyObject], n: ptr[PyObject]) -> ptr[PyObject];

def math_factorial_impl(module: ptr[PyObject], n: ptr[PyObject]) -> ptr[PyObject];

def math_frexp_impl(module: ptr[PyObject], x: f64) -> ptr[PyObject];

def math_modf_impl(module: ptr[PyObject], x: f64) -> ptr[PyObject];

def math_ldexp_impl(module: ptr[PyObject], x: f64, i: ptr[PyObject]) -> ptr[PyObject];

def math_fma_impl(module: ptr[PyObject], x: f64, y: f64, z: f64) -> ptr[PyObject];

def math_fmod_impl(module: ptr[PyObject], x: f64, y: f64) -> ptr[PyObject];

def math_pow_impl(module: ptr[PyObject], x: f64, y: f64) -> ptr[PyObject];

def math_dist_impl(
    module: ptr[PyObject], p: ptr[PyObject], q: ptr[PyObject]
) -> ptr[PyObject];

def math_sumprod_impl(
    module: ptr[PyObject], p: ptr[PyObject], q: ptr[PyObject]
) -> ptr[PyObject];

def math_degrees_impl(module: ptr[PyObject], x: f64) -> ptr[PyObject];

def math_radians_impl(module: ptr[PyObject], x: f64) -> ptr[PyObject];

def math_isfinite_impl(module: ptr[PyObject], x: f64) -> ptr[PyObject];

def math_isinf_impl(module: ptr[PyObject], x: f64) -> ptr[PyObject];

def math_isnan_impl(module: ptr[PyObject], x: f64) -> ptr[PyObject];

def math_isclose_impl(
    module: ptr[PyObject], a: f64, b: f64, rel_tol: f64, abs_tol: f64
) -> i32;

def math_prod_impl(
    module: ptr[PyObject], iterable: ptr[PyObject], start: ptr[PyObject]
) -> ptr[PyObject];

def math_perm_impl(
    module: ptr[PyObject], n: ptr[PyObject], k: ptr[PyObject]
) -> ptr[PyObject];

def math_comb_impl(
    module: ptr[PyObject], n: ptr[PyObject], k: ptr[PyObject]
) -> ptr[PyObject];

def math_nextafter_impl(
    module: ptr[PyObject], x: f64, y: f64, steps: ptr[PyObject]
) -> ptr[PyObject];

def math_ulp_impl(module: ptr[PyObject], x: f64) -> f64;

impl bits(value: i64) -> int {
    n = value;
    result = 0;
    while n > 0 {
        result += 1;
        n >>= 1;
    }
    return result;
}

impl jacpy_math_gcd(arguments: ptr[PyObject], lcm: i64) -> ptr[PyObject] {
    result: ptr[PyObject] = NULL;
    try {
        result = required(PyLong_FromLongLong(1 if lcm != 0 else 0));
        for i in range(int(PyTuple_Size(arguments))) {
            argument: ptr[PyObject] = NULL;
            indexed: ptr[PyObject] = NULL;
            absolute: ptr[PyObject] = NULL;
            divisor: ptr[PyObject] = NULL;
            quotient: ptr[PyObject] = NULL;
            try {
                argument = required(jacpy_tuple_item(arguments, i64(i)));
                indexed = required(PyNumber_Index(argument));
                absolute = required(PyNumber_Absolute(indexed));
                divisor = required(_PyLong_GCD(result, absolute));
                replacement: ptr[PyObject] = NULL;
                if lcm == 0 {
                    replacement = Py_NewRef(divisor);
                } elif jacpy_long_sign(result) == 0 or jacpy_long_sign(absolute) == 0 {
                    replacement = required(PyLong_FromLongLong(0));
                } else {
                    quotient = required(PyNumber_FloorDivide(result, divisor));
                    replacement = required(PyNumber_Multiply(quotient, absolute));
                }
                jacpy_release(result);
                result = replacement;
            } finally {
                jacpy_release(argument);
                jacpy_release(indexed);
                jacpy_release(absolute);
                jacpy_release(divisor);
                jacpy_release(quotient);
            }
        }
        return Py_NewRef(result);
    } except boundary_failure {
        return NULL;
    } finally {
        jacpy_release(result);
    }
}

impl odd_product(start: i64, stop: i64) -> ptr[PyObject] {
    count = (stop - start) // 2;
    if count <= 64 and count * i64(bits(stop - 2)) <= 64 {
        product: u64 = 1;
        for i in range(int(start), int(stop), 2) {
            product *= u64(i);
        }
        return required(PyLong_FromUnsignedLongLong(product));
    }
    middle = (start + count) | i64(1);
    left: ptr[PyObject] = NULL;
    right: ptr[PyObject] = NULL;
    try {
        left = odd_product(start, middle);
        right = odd_product(middle, stop);
        return required(PyNumber_Multiply(left, right));
    } finally {
        jacpy_release(left);
        jacpy_release(right);
    }
}

impl jacpy_math_factorial(argument: ptr[PyObject]) -> ptr[PyObject] {
    value: ptr[PyObject] = NULL;
    inner: ptr[PyObject] = NULL;
    outer: ptr[PyObject] = NULL;
    try {
        value = required(PyNumber_Index(argument));
        if jacpy_long_sign(value) < 0 {
            object_error(
                PyExc_ValueError, "factorial() not defined for negative values"
            );
            return NULL;
        }
        if _PyLong_NumBits(value) > 63 {
            object_error(
                PyExc_OverflowError,
                "factorial() argument should not exceed 9223372036854775807"
            );
            return NULL;
        }
        n = PyLong_AsLongLong(value);
        inner = required(PyLong_FromLongLong(1));
        outer = Py_NewRef(inner);
        upper: i64 = 3;
        for i in range(bits(n) - 2, -1, -1) {
            v = n >> i64(i);
            if v <= 2 {
                continue;
            }
            lower = upper;
            upper = (v + 1) | i64(1);
            partial = odd_product(lower, upper);
            try {
                replacement = required(PyNumber_Multiply(inner, partial));
                jacpy_release(inner);
                inner = replacement;
                replacement = required(PyNumber_Multiply(outer, inner));
                jacpy_release(outer);
                outer = replacement;
            } finally {
                jacpy_release(partial);
            }
        }
        remaining = n;
        ones: i64 = 0;
        while remaining != 0 {
            ones += remaining & i64(1);
            remaining >>= i64(1);
        }
        return required(jacpy_long_shift(outer, n - ones, 1));
    } except boundary_failure {
        return NULL;
    } finally {
        jacpy_release(value);
        jacpy_release(inner);
        jacpy_release(outer);
    }
}

impl jacpy_math_isqrt(argument: ptr[PyObject]) -> ptr[PyObject] {
    n: ptr[PyObject] = NULL;
    approximation: ptr[PyObject] = NULL;
    square: ptr[PyObject] = NULL;
    try {
        n = required(PyNumber_Index(argument));
        sign = jacpy_long_sign(n);
        if sign < 0 {
            object_error(PyExc_ValueError, "isqrt() argument must be nonnegative");
            return NULL;
        }
        if sign == 0 {
            return required(PyLong_FromLongLong(0));
        }
        c = (_PyLong_NumBits(n) - 1) // 2;
        approximation = required(PyLong_FromLongLong(1));
        d: i64 = 0;
        for s in range(bits(c) - 1, -1, -1) {
            e = d;
            d = c >> i64(s);
            shifted: ptr[PyObject] = NULL;
            quotient: ptr[PyObject] = NULL;
            prefix: ptr[PyObject] = NULL;
            try {
                shifted = required(jacpy_long_shift(n, 2 * c - e - d + 1, 0));
                quotient = required(PyNumber_FloorDivide(shifted, approximation));
                prefix = required(jacpy_long_shift(approximation, d - e - 1, 1));
                replacement = required(PyNumber_Add(prefix, quotient));
                jacpy_release(approximation);
                approximation = replacement;
            } finally {
                jacpy_release(shifted);
                jacpy_release(quotient);
                jacpy_release(prefix);
            }
        }
        square = required(PyNumber_Multiply(approximation, approximation));
        too_large = PyObject_RichCompareBool(square, n, 4);
        if too_large < 0 {
            return NULL;
        }
        if too_large != 0 {
            one = required(PyLong_FromLongLong(1));
            try {
                return required(PyNumber_Subtract(approximation, one));
            } finally {
                jacpy_release(one);
            }
        }
        return Py_NewRef(approximation);
    } except boundary_failure {
        return NULL;
    } finally {
        jacpy_release(n);
        jacpy_release(approximation);
        jacpy_release(square);
    }
}

impl table_u64(table: ptr[u64], index: u64) -> u64 {
    return (table + i64(index)).view(1)[0];
}

impl table_u8(table: ptr[u8], index: u64) -> u64 {
    return u64((table + i64(index)).view(1)[0]);
}

impl perm_comb_small(n: u64, k: u64, combination: bool) -> ptr[PyObject] {
    odd = addressof(reduced_factorial_odd_part);
    inverted = addressof(inverted_factorial_odd_part);
    zeros = addressof(factorial_trailing_zeros);
    if combination {
        if k < u64(35) and n <= table_u8(addressof(fast_comb_limits1), k) {
            part = wrapping_mul(
                wrapping_mul(table_u64(odd, n), table_u64(inverted, k)),
                table_u64(inverted, n - k)
            );
            shift = table_u8(zeros, n) - table_u8(zeros, k) - table_u8(zeros, n - k);
            return PyLong_FromUnsignedLongLong(wrapping_shl(part, shift));
        }
        if k < u64(14) and n <= table_u64(addressof(fast_comb_limits2), k) {
            result = n;
            top = n;
            i = u64(1);
            while i < k {
                top -= u64(1);
                result *= top;
                i += u64(1);
                result //= i;
            }
            return PyLong_FromUnsignedLongLong(result);
        }
    } elif k < u64(21) and n <= table_u64(addressof(fast_perm_limits), k) {
        if n <= u64(127) {
            part = wrapping_mul(table_u64(odd, n), table_u64(inverted, n - k));
            shift = table_u8(zeros, n) - table_u8(zeros, n - k);
            return PyLong_FromUnsignedLongLong(wrapping_shl(part, shift));
        }
        result = n;
        top = n;
        i = u64(1);
        while i < k {
            top -= u64(1);
            result *= top;
            i += u64(1);
        }
        return PyLong_FromUnsignedLongLong(result);
    }
    j = k // u64(2);
    left = perm_comb_small(n, j, combination);
    if not left {
        return NULL;
    }
    right = perm_comb_small(n - j, k - j, combination);
    if not right {
        jacpy_release(left);
        return NULL;
    }
    product = PyNumber_Multiply(left, right);
    jacpy_release(left);
    jacpy_release(right);
    if not product or not combination {
        return product;
    }
    divisor = perm_comb_small(k, j, True);
    if not divisor {
        jacpy_release(product);
        return NULL;
    }
    quotient = PyNumber_FloorDivide(product, divisor);
    jacpy_release(product);
    jacpy_release(divisor);
    return quotient;
}

impl perm_comb(n: ptr[PyObject], k: i64, combination: bool) -> ptr[PyObject] {
    if k == 0 {
        return required(PyLong_FromLongLong(1));
    }
    if k == 1 {
        return Py_NewRef(n);
    }
    middle = k // 2;
    left: ptr[PyObject] = NULL;
    right: ptr[PyObject] = NULL;
    offset: ptr[PyObject] = NULL;
    remaining: ptr[PyObject] = NULL;
    product: ptr[PyObject] = NULL;
    denominator: ptr[PyObject] = NULL;
    try {
        left = perm_comb(n, middle, combination);
        offset = required(PyLong_FromLongLong(middle));
        remaining = required(PyNumber_Subtract(n, offset));
        right = perm_comb(remaining, k - middle, combination);
        product = required(PyNumber_Multiply(left, right));
        if not combination {
            return Py_NewRef(product);
        }
        denominator = required(perm_comb_small(u64(k), u64(middle), True));
        return required(PyNumber_FloorDivide(product, denominator));
    } finally {
        jacpy_release(left);
        jacpy_release(right);
        jacpy_release(offset);
        jacpy_release(remaining);
        jacpy_release(product);
        jacpy_release(denominator);
    }
}

impl jacpy_math_comb(
    n_arg: ptr[PyObject], k_arg: ptr[PyObject], combination: i64
) -> ptr[PyObject] {
    if combination == 0 and (k_arg == 0 or k_arg == Py_None) {
        return jacpy_math_factorial(n_arg);
    }
    n: ptr[PyObject] = NULL;
    k: ptr[PyObject] = NULL;
    difference: ptr[PyObject] = NULL;
    try {
        n = required(PyNumber_Index(n_arg));
        k = required(PyNumber_Index(k_arg));
        if jacpy_long_sign(n) < 0 {
            object_error(PyExc_ValueError, "n must be a non-negative integer");
            return NULL;
        }
        if jacpy_long_sign(k) < 0 {
            object_error(PyExc_ValueError, "k must be a non-negative integer");
            return NULL;
        }
        comparison = PyObject_RichCompareBool(k, n, 4);
        if comparison < 0 {
            return NULL;
        }
        if comparison != 0 {
            return required(PyLong_FromLongLong(0));
        }
        if combination != 0 {
            difference = required(PyNumber_Subtract(n, k));
            comparison = PyObject_RichCompareBool(difference, k, 0);
            if comparison < 0 {
                return NULL;
            }
            if comparison != 0 {
                jacpy_release(k);
                k = Py_NewRef(difference);
            }
        }
        overflow = i32(0);
        small_n = PyLong_AsLongLongAndOverflow(n, &mut overflow);
        if overflow == 0 {
            small_k = PyLong_AsLongLong(k);
            if small_k > 1 {
                return perm_comb_small(u64(small_n), u64(small_k), combination != 0);
            }
        }
        if _PyLong_NumBits(k) > 63 {
            object_error(
                PyExc_OverflowError,
                ("min(n - k, k)" if combination != 0 else "k")
                    + " must not exceed 9223372036854775807"
            );
            return NULL;
        }
        count = PyLong_AsLongLong(k);
        if jacpy_error_pending() != 0 {
            return NULL;
        }
        return perm_comb(n, count, combination != 0);
    } except boundary_failure {
        return NULL;
    } finally {
        jacpy_release(n);
        jacpy_release(k);
        jacpy_release(difference);
    }
}

impl input_float(value: ptr[PyObject]) -> float {
    result = PyFloat_AsDouble(value);
    if jacpy_error_pending() != 0 {
        raise boundary_failure();
    }
    return result;
}

impl float_repr(value: float) -> str {
    object = required(PyFloat_FromDouble(value));
    try {
        return repr_value(object);
    } finally {
        jacpy_release(object);
    }
}

impl domain(operation: i64, value: float) {
    message = "math domain error";
    if operation == 0 or operation == 2 {
        message = "expected a number in range from -1 up to 1, got "
            + float_repr(value);
    } elif operation == 1 {
        message = "expected argument value not less than 1, got " + float_repr(value);
    } elif operation == 5 {
        message = "expected a number between -1 and 1, got " + float_repr(value);
    } elif operation == 7 or operation == 18 or operation == 21 {
        message = "expected a finite input, got " + float_repr(value);
    } elif operation == 15 or operation == 16 {
        message = "expected a noninteger or positive integer, got " + float_repr(value);
    } elif operation == 17 {
        message = "expected argument value > -1, got " + float_repr(value);
    } elif operation == 20 {
        message = "expected a nonnegative input, got " + float_repr(value);
    }
    object_error(PyExc_ValueError, message);
}

impl logarithm(value: ptr[PyObject], base: int) -> float {
    if jacpy_is_long(value) != 0 {
        if jacpy_long_sign(value) <= 0 {
            object_error(PyExc_ValueError, "expected a positive input");
            raise boundary_failure();
        }
        x = PyLong_AsDouble(value);
        if jacpy_error_pending() != 0 {
            PyErr_Clear();
            exponent: i64 = 0;
            x = _PyLong_Frexp(value, &mut exponent);
            power = float(exponent);
            if base == 2 {
                return log2(x) + power;
            }
            if base == 10 {
                return log10(x) + power * log10(2.0);
            }
            return log(x) + power * log(2.0);
        }
        if base == 2 {
            return log2(x);
        }
        if base == 10 {
            return log10(x);
        }
        return log(x);
    }
    x = input_float(value);
    if x <= 0.0 {
        object_error(
            PyExc_ValueError, "expected a positive input, got " + float_repr(x)
        );
        raise boundary_failure();
    }
    if base == 2 {
        return log2(x);
    }
    if base == 10 {
        return log10(x);
    }
    return log(x);
}

impl m_sinpi(x: float) -> float {
    y = fmod(fabs(x), 2.0);
    n = int(round(2.0 * y));
    r: float = 0.0;
    if n == 0 {
        r = sin(pi * y);
    } elif n == 1 {
        r = cos(pi * (y - 0.5));
    } elif n == 2 {
        r = sin(pi * (1.0 - y));
    } elif n == 3 {
        r = -cos(pi * (y - 1.5));
    } else {
        r = sin(pi * (y - 2.0));
    }
    return copysign(1.0, x) * r;
}

impl lanczos_sum(x: float) -> float {
    num = 0.0;
    den = 0.0;
    if x < 5.0 {
        for i in range(12, -1, -1) {
            num = num * x + lanczos_num_coeffs[i];
            den = den * x + lanczos_den_coeffs[i];
        }
    } else {
        for i in range(13) {
            num = num / x + lanczos_num_coeffs[i];
            den = den / x + lanczos_den_coeffs[i];
        }
    }
    return num / den;
}

impl m_tgamma(x: float) -> tuple[float, int] {
    if not isfinite(x) {
        if isnan(x) or x > 0.0 {
            return (x, 0);
        }
        return (nan, 1);
    }
    if x == 0.0 {
        return (copysign(infinity, x), 1);
    }
    if x == floor(x) {
        if x < 0.0 {
            return (nan, 1);
        }
        if x <= 23.0 {
            return (gamma_integral[int(x) - 1], 0);
        }
    }
    absx = fabs(x);
    if absx < 1e-20 {
        r = 1.0 / x;
        return (r, 2 if isinf(r) else 0);
    }
    if absx > 200.0 {
        if x < 0.0 {
            return (0.0 / m_sinpi(x), 0);
        }
        return (infinity, 2);
    }
    y = absx + lanczos_g_minus_half;
    z: float = 0.0;
    if absx > lanczos_g_minus_half {
        q = y - absx;
        z = q - lanczos_g_minus_half;
    } else {
        q = y - lanczos_g_minus_half;
        z = q - absx;
    }
    z = z * lanczos_g / y;
    r: float = 0.0;
    if x < 0.0 {
        r = -pi / m_sinpi(absx) / absx * exp(y) / lanczos_sum(absx);
        r -= z * r;
        if absx < 140.0 {
            r /= pow(y, absx - 0.5);
        } else {
            sqrtpow = pow(y, absx / 2.0 - 0.25);
            r /= sqrtpow;
            r /= sqrtpow;
        }
    } else {
        r = lanczos_sum(absx) / exp(y);
        r += z * r;
        if absx < 140.0 {
            r *= pow(y, absx - 0.5);
        } else {
            sqrtpow = pow(y, absx / 2.0 - 0.25);
            r *= sqrtpow;
            r *= sqrtpow;
        }
    }
    return (r, 2 if isinf(r) else 0);
}

impl m_lgamma(x: float) -> tuple[float, int] {
    if not isfinite(x) {
        if isnan(x) {
            return (x, 0);
        }
        return (infinity, 0);
    }
    if x == floor(x) and x <= 2.0 {
        if x <= 0.0 {
            return (infinity, 1);
        }
        return (0.0, 0);
    }
    absx = fabs(x);
    if absx < 1e-20 {
        return (-log(absx), 0);
    }
    r = log(lanczos_sum(absx)) - lanczos_g;
    r += (absx - 0.5) * (log(absx + lanczos_g - 0.5) - 1.0);
    if x < 0.0 {
        r = logpi - log(fabs(m_sinpi(absx))) - log(absx) - r;
    }
    return (r, 2 if isinf(r) else 0);
}

impl jacpy_math_log(value: ptr[PyObject], base: ptr[PyObject]) -> ptr[PyObject] {
    try {
        numerator = logarithm(value, 0);
        if base == 0 {
            return required(PyFloat_FromDouble(numerator));
        }
        denominator = logarithm(base, 0);
        if denominator == 0.0 {
            object_error(PyExc_ZeroDivisionError, "division by zero");
            return NULL;
        }
        return required(PyFloat_FromDouble(numerator / denominator));
    } except boundary_failure {
        return NULL;
    }
}

impl jacpy_math_unary(operation: i64, value: ptr[PyObject]) -> ptr[PyObject] {
    try {
        if operation >= 28 and operation <= 30 {
            name = "__ceil__"
                if operation == 28
                else "__floor__" if operation == 29 else "__trunc__";
            result_object = jacpy_special_noargs(value, name);
            if result_object != 0 or jacpy_error_pending() != 0 {
                return result_object;
            }
            if operation == 30 {
                object_error(
                    PyExc_TypeError,
                    "type " + type_name(value) + " doesn't define __trunc__ method"
                );
                return NULL;
            }
        }
        if operation == 31 {
            return required(PyFloat_FromDouble(logarithm(value, 10)));
        }
        if operation == 32 {
            return required(PyFloat_FromDouble(logarithm(value, 2)));
        }
        x = input_float(value);
        if operation == 25 {
            return required(PyBool_FromLong(1 if isfinite(x) else 0));
        }
        if operation == 26 {
            return required(PyBool_FromLong(1 if isinf(x) else 0));
        }
        if operation == 27 {
            return required(PyBool_FromLong(1 if isnan(x) else 0));
        }
        if operation == 28 {
            return required(PyLong_FromDouble(ceil(x)));
        }
        if operation == 29 {
            return required(PyLong_FromDouble(floor(x)));
        }
        if operation == 33 {
            if isnan(x) {
                return required(PyFloat_FromDouble(x));
            }
            x = fabs(x);
            if isinf(x) {
                return required(PyFloat_FromDouble(x));
            }
            following = nextafter(x, infinity);
            if isinf(following) {
                return required(PyFloat_FromDouble(x - nextafter(x, -infinity)));
            }
            return required(PyFloat_FromDouble(following - x));
        }
        jacpy_clear_errno();
        if operation == 15 or operation == 16 {
            (gamma, gamma_error) = m_tgamma(x) if operation == 15 else m_lgamma(x);
            if gamma_error == 0 {
                gamma_error = int(jacpy_math_errno());
            }
            if gamma_error == 1 {
                domain(operation, x);
                return NULL;
            }
            if gamma_error == 2 and fabs(gamma) >= 1.5 {
                object_error(PyExc_OverflowError, "math range error");
                return NULL;
            }
            return required(PyFloat_FromDouble(gamma));
        }
        result: float = 0.0;
        if operation == 0 {
            result = acos(x);
        } elif operation == 1 {
            result = acosh(x);
        } elif operation == 2 {
            result = asin(x);
        } elif operation == 3 {
            result = asinh(x);
        } elif operation == 4 {
            result = atan(x);
        } elif operation == 5 {
            result = atanh(x);
        } elif operation == 6 {
            result = cbrt(x);
        } elif operation == 7 {
            result = cos(x);
        } elif operation == 8 {
            result = cosh(x);
        } elif operation == 9 {
            result = erf(x);
        } elif operation == 10 {
            result = erfc(x);
        } elif operation == 11 {
            result = exp(x);
        } elif operation == 12 {
            result = exp2(x);
        } elif operation == 13 {
            result = expm1(x);
        } elif operation == 14 {
            result = fabs(x);
        } elif operation == 17 {
            result = _Py_log1p(x);
        } elif operation == 18 {
            result = sin(x);
        } elif operation == 19 {
            result = sinh(x);
        } elif operation == 20 {
            result = sqrt(x);
        } elif operation == 21 {
            result = tan(x);
        } elif operation == 22 {
            result = tanh(x);
        } elif operation == 23 {
            return required(PyFloat_FromDouble(x * 57.2957795130823208768));
        } elif operation == 24 {
            return required(PyFloat_FromDouble(x * 0.0174532925199432957692));
        }
        error = jacpy_math_errno();
        overflow = operation == 8
            or operation == 11
            or operation == 12
            or operation == 13
            or operation == 19;
        if (isnan(result) and not isnan(x))
            or error == 1
            or (isinf(result) and isfinite(x) and not overflow) {
            domain(operation, x);
            return NULL;
        }
        if (isinf(result) and isfinite(x)) or (error == 2 and fabs(result) >= 1.0) {
            object_error(PyExc_OverflowError, "math range error");
            return NULL;
        }
        return required(PyFloat_FromDouble(result));
    } except boundary_failure {
        return NULL;
    }
}

impl jacpy_math_binary(
    operation: i64, a: ptr[PyObject], b: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        x = input_float(a);
        y = input_float(b);
        jacpy_clear_errno();
        result: float = 0.0;
        if operation == 0 {
            result = atan2(x, y);
        } elif operation == 1 {
            result = copysign(x, y);
        } elif operation == 2 {
            result = fmod(x, y);
        } elif operation == 3 {
            result = remainder(x, y);
        } else {
            result = pow(x, y);
        }
        error = jacpy_math_errno();
        if isnan(result) {
            if not isnan(x) and not isnan(y) {
                object_error(PyExc_ValueError, "math domain error");
                return NULL;
            }
            error = 0;
        } elif isinf(result) {
            if isfinite(x) and isfinite(y) {
                object_error(
                    PyExc_ValueError
                        if operation == 4 and x == 0.0
                        else PyExc_OverflowError,
                    "math domain error"
                        if operation == 4 and x == 0.0
                        else "math range error"
                );
                return NULL;
            }
            error = 0;
        }
        if error == 1 {
            object_error(PyExc_ValueError, "math domain error");
            return NULL;
        }
        if error == 2 and fabs(result) >= 1.0 {
            object_error(PyExc_OverflowError, "math range error");
            return NULL;
        }
        return required(PyFloat_FromDouble(result));
    } except boundary_failure {
        return NULL;
    }
}

impl jacpy_math_parts(operation: i64, value: ptr[PyObject]) -> ptr[PyObject] {
    x: float = 0.0;
    try {
        x = input_float(value);
    } except boundary_failure {
        return NULL;
    }
    if operation == 0 {
        exponent: i32 = 0;
        if not (isnan(x) or isinf(x) or x == 0.0) {
            x = frexp(x, &mut exponent);
        }
        return Py_BuildValue(ptr[u8]("(di)"), x, exponent);
    }
    if isinf(x) {
        return Py_BuildValue(ptr[u8]("(dd)"), copysign(0.0, x), x);
    }
    if isnan(x) {
        return Py_BuildValue(ptr[u8]("(dd)"), x, x);
    }
    whole: float = 0.0;
    fraction = modf(x, &mut whole);
    return Py_BuildValue(ptr[u8]("(dd)"), fraction, whole);
}

impl jacpy_math_ldexp(value: ptr[PyObject], exponent: ptr[PyObject]) -> ptr[PyObject] {
    try {
        x = input_float(value);
        if jacpy_is_long(exponent) == 0 {
            object_error(
                PyExc_TypeError, "Expected an int as second argument to ldexp."
            );
            return NULL;
        }
        if x == 0.0 or not isfinite(x) {
            return required(PyFloat_FromDouble(x));
        }
        sign = jacpy_long_sign(exponent);
        if _PyLong_NumBits(exponent) > 31 {
            if sign > 0 {
                object_error(PyExc_OverflowError, "math range error");
                return NULL;
            }
            return required(PyFloat_FromDouble(copysign(0.0, x)));
        }
        result = scaled(x, int(PyLong_AsLongLong(exponent)));
        if isinf(result) {
            object_error(PyExc_OverflowError, "math range error");
            return NULL;
        }
        return required(PyFloat_FromDouble(result));
    } except boundary_failure {
        return NULL;
    }
}

impl jacpy_math_fma(
    a: ptr[PyObject], b: ptr[PyObject], c: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        x = input_float(a);
        y = input_float(b);
        z = input_float(c);
        result = fma(x, y, z);
        if isnan(result) and not isnan(x) and not isnan(y) and not isnan(z) {
            object_error(PyExc_ValueError, "invalid operation in fma");
            return NULL;
        }
        if isinf(result) and isfinite(x) and isfinite(y) and isfinite(z) {
            object_error(PyExc_OverflowError, "overflow in fma");
            return NULL;
        }
        return required(PyFloat_FromDouble(result));
    } except boundary_failure {
        return NULL;
    }
}

impl jacpy_math_isclose(
    a: ptr[PyObject], b: ptr[PyObject], rel: ptr[PyObject], abs_tol: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        x = input_float(a);
        y = input_float(b);
        relative = input_float(rel) if rel != 0 else 1e-9;
        absolute = input_float(abs_tol) if abs_tol != 0 else 0.0;
        if relative < 0.0 or absolute < 0.0 {
            object_error(PyExc_ValueError, "tolerances must be non-negative");
            return NULL;
        }
        if x == y {
            return required(PyBool_FromLong(1));
        }
        if isinf(x) or isinf(y) {
            return required(PyBool_FromLong(0));
        }
        difference = fabs(y - x);
        return required(
            PyBool_FromLong(
                1
                    if difference <= fabs(relative * x)
                        or difference <= fabs(relative * y)
                        or difference <= absolute
                    else 0
            )
        );
    } except boundary_failure {
        return NULL;
    }
}

impl jacpy_math_nextafter(
    a: ptr[PyObject], b: ptr[PyObject], steps: ptr[PyObject]
) -> ptr[PyObject] {
    count_object: ptr[PyObject] = NULL;
    try {
        x = input_float(a);
        y = input_float(b);
        count: u64 = 1;
        if steps == 0 or steps == Py_None {
            return required(PyFloat_FromDouble(nextafter(x, y)));
        }
        if steps != 0 {
            count_object = required(PyNumber_Index(steps));
            if jacpy_long_sign(count_object) < 0 {
                object_error(PyExc_ValueError, "steps must be a non-negative integer");
                return NULL;
            }
            count = u64(18446744073709551615)
                if _PyLong_NumBits(count_object) > 64
                else PyLong_AsUnsignedLongLong(count_object);
        }
        if count == 0 {
            return required(PyFloat_FromDouble(x));
        }
        if x == y {
            return required(PyFloat_FromDouble(y));
        }
        if isnan(x) {
            return required(PyFloat_FromDouble(x));
        }
        if isnan(y) {
            return required(PyFloat_FromDouble(y));
        }
        sign: u64 = 9223372036854775808;
        first = jacpy_float_bits(x);
        last = jacpy_float_bits(y);
        first_magnitude = first & (sign - u64(1));
        last_magnitude = last & (sign - u64(1));
        if (first & sign) != (last & sign) {
            distance = first_magnitude + last_magnitude;
            if count >= distance {
                return required(PyFloat_FromDouble(y));
            }
            if count <= first_magnitude {
                return required(
                    PyFloat_FromDouble(
                        jacpy_float_from_bits(
                            (first & sign) | (first_magnitude - count)
                        )
                    )
                );
            }
            return required(
                PyFloat_FromDouble(
                    jacpy_float_from_bits((last & sign) | (count - first_magnitude))
                )
            );
        }
        distance = first_magnitude - last_magnitude
            if first_magnitude > last_magnitude
            else last_magnitude - first_magnitude;
        if count >= distance {
            return required(PyFloat_FromDouble(y));
        }
        result_bits = first - count
            if first_magnitude > last_magnitude
            else first + count;
        return required(PyFloat_FromDouble(jacpy_float_from_bits(result_bits)));
    } except boundary_failure {
        return NULL;
    } finally {
        jacpy_release(count_object);
    }
}

impl jacpy_math_fsum(iterable: ptr[PyObject]) -> ptr[PyObject] {
    iterator: ptr[PyObject] = NULL;
    try {
        iterator = required(PyObject_GetIter(iterable));
        partials: list[float] = [];
        special: float = 0.0;
        infinities: float = 0.0;
        low: float = 0.0;
        while True {
            item = PyIter_Next(iterator);
            if item == 0 {
                break;
            }
            x: float = 0.0;
            try {
                x = input_float(item);
            } finally {
                jacpy_release(item);
            }
            original = x;
            count = 0;
            for j in range(len(partials)) {
                y = partials[j];
                if fabs(x) < fabs(y) {
                    temporary = x;
                    x = y;
                    y = temporary;
                }
                high = x + y;
                rounded = high - x;
                low = y - rounded;
                if low != 0.0 {
                    partials[count] = low;
                    count += 1;
                }
                x = high;
            }
            while len(partials) > count {
                partials.pop();
            }
            if x != 0.0 {
                if not isfinite(x) {
                    if isfinite(original) {
                        object_error(
                            PyExc_OverflowError, "intermediate overflow in fsum"
                        );
                        return NULL;
                    }
                    if isinf(original) {
                        infinities += original;
                    }
                    special += original;
                    partials.clear();
                } else {
                    partials.append(x);
                }
            }
        }
        if jacpy_error_pending() != 0 {
            return NULL;
        }
        if special != 0.0 {
            if isnan(infinities) {
                object_error(PyExc_ValueError, "-inf + inf in fsum");
                return NULL;
            }
            return required(PyFloat_FromDouble(special));
        }
        high: float = 0.0;
        if partials {
            high = partials.pop();
            while partials {
                x = high;
                y = partials.pop();
                high = x + y;
                rounded = high - x;
                low = y - rounded;
                if low != 0.0 {
                    break;
                }
            }
            if partials
                and (
                    (low < 0.0 and partials[-1] < 0.0)
                    or (low > 0.0 and partials[-1] > 0.0)
                ) {
                y = low * 2.0;
                x = high + y;
                rounded = x - high;
                if y == rounded {
                    high = x;
                }
            }
        }
        return required(PyFloat_FromDouble(high));
    } except boundary_failure {
        return NULL;
    } finally {
        jacpy_release(iterator);
    }
}

impl double_sum(a: float, b: float) -> tuple[float, float] {
    high = a + b;
    rounded = high - a;
    return (high, (a - (high - rounded)) + (b - rounded));
}

impl fast_sum(a: float, b: float) -> tuple[float, float] {
    high = a + b;
    return (high, (a - high) + b);
}

impl double_product(a: float, b: float) -> tuple[float, float] {
    high = a * b;
    return (high, fma(a, b, -high));
}

impl triple_product(
    a: float, b: float, total: tuple[float, float, float]
) -> tuple[float, float, float] {
    product = double_product(a, b);
    high = double_sum(total[0], product[0]);
    first = double_sum(total[1], product[1]);
    second = double_sum(first[0], high[1]);
    return (high[0], second[0], total[2] + first[1] + second[1]);
}

impl triple_value(total: tuple[float, float, float]) -> float {
    last = double_sum(total[1], total[0]);
    return total[2] + last[1] + last[0];
}

impl norm(values: list[float], largest: float, found_nan: bool) -> float {
    if isinf(largest) {
        return largest;
    }
    if found_nan {
        return nan;
    }
    if largest == 0.0 or len(values) <= 1 {
        return largest;
    }
    exponent: i32 = 0;
    frexp(largest, &mut exponent);
    power = int(exponent);
    if power < -1023 {
        for i in range(len(values)) {
            values[i] /= 2.2250738585072014e-308;
        }
        return 2.2250738585072014e-308
            * norm(values, largest / 2.2250738585072014e-308, found_nan);
    }
    scale = scaled(1.0, -power);
    total: float = 1.0;
    fraction1: float = 0.0;
    fraction2: float = 0.0;
    for value in values {
        x = value * scale;
        product = double_product(x, x);
        addition = fast_sum(total, product[0]);
        total = addition[0];
        fraction1 += product[1];
        fraction2 += addition[1];
    }
    result = sqrt(total - 1.0 + (fraction1 + fraction2));
    correction = double_product(-result, result);
    addition = fast_sum(total, correction[0]);
    total = addition[0];
    fraction1 += correction[1];
    fraction2 += addition[1];
    residual = total - 1.0 + (fraction1 + fraction2);
    result += residual / (2.0 * result);
    return result / scale;
}

impl jacpy_math_hypot(arguments: ptr[PyObject]) -> ptr[PyObject] {
    try {
        values: list[float] = [];
        largest: float = 0.0;
        found_nan = False;
        for i in range(int(PyTuple_Size(arguments))) {
            item = required(jacpy_tuple_item(arguments, i64(i)));
            x: float = 0.0;
            try {
                x = fabs(input_float(item));
            } finally {
                jacpy_release(item);
            }
            values.append(x);
            found_nan = found_nan or isnan(x);
            if x > largest {
                largest = x;
            }
        }
        return required(PyFloat_FromDouble(norm(values, largest, found_nan)));
    } except boundary_failure {
        return NULL;
    }
}

impl jacpy_math_dist(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    left: ptr[PyObject] = NULL;
    right: ptr[PyObject] = NULL;
    try {
        left = required(
            Py_NewRef(a) if jacpy_is_tuple(a) != 0 else PySequence_Tuple(a)
        );
        right = required(
            Py_NewRef(b) if jacpy_is_tuple(b) != 0 else PySequence_Tuple(b)
        );
        count = PyTuple_Size(left);
        if count != PyTuple_Size(right) {
            object_error(
                PyExc_ValueError, "both points must have the same number of dimensions"
            );
            return NULL;
        }
        values: list[float] = [];
        largest: float = 0.0;
        found_nan = False;
        for i in range(int(count)) {
            first = required(jacpy_tuple_item(left, i64(i)));
            second: ptr[PyObject] = NULL;
            distance: float = 0.0;
            try {
                x = input_float(first);
                second = required(jacpy_tuple_item(right, i64(i)));
                distance = fabs(x - input_float(second));
            } finally {
                jacpy_release(first);
                jacpy_release(second);
            }
            values.append(distance);
            found_nan = found_nan or isnan(distance);
            if distance > largest {
                largest = distance;
            }
        }
        return required(PyFloat_FromDouble(norm(values, largest, found_nan)));
    } except boundary_failure {
        return NULL;
    } finally {
        jacpy_release(left);
        jacpy_release(right);
    }
}

impl jacpy_math_prod(iterable: ptr[PyObject], start: ptr[PyObject]) -> ptr[PyObject] {
    iterator: ptr[PyObject] = NULL;
    result: ptr[PyObject] = NULL;
    try {
        result = required(PyLong_FromLongLong(1) if start == 0 else Py_NewRef(start));
        iterator = required(PyObject_GetIter(iterable));
        while True {
            value = PyIter_Next(iterator);
            if value == 0 {
                break;
            }
            try {
                replacement = required(PyNumber_Multiply(result, value));
                jacpy_release(result);
                result = replacement;
            } finally {
                jacpy_release(value);
            }
        }
        if jacpy_error_pending() != 0 {
            return NULL;
        }
        return Py_NewRef(result);
    } except boundary_failure {
        return NULL;
    } finally {
        jacpy_release(iterator);
        jacpy_release(result);
    }
}

impl jacpy_math_sumprod(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    left: ptr[PyObject] = NULL;
    right: ptr[PyObject] = NULL;
    result: ptr[PyObject] = NULL;
    try {
        left = required(PyObject_GetIter(a));
        right = required(PyObject_GetIter(b));
        result = required(PyLong_FromLongLong(0));
        float_enabled = True;
        float_used = False;
        integer_prefix = True;
        total: tuple[float, float, float] = (0.0, 0.0, 0.0);
        while True {
            first = PyIter_Next(left);
            second: ptr[PyObject] = NULL;
            term: ptr[PyObject] = NULL;
            try {
                if first == 0 and jacpy_error_pending() != 0 {
                    return NULL;
                }
                second = PyIter_Next(right);
                if second == 0 and jacpy_error_pending() != 0 {
                    return NULL;
                }
                if (first == 0) != (second == 0) {
                    object_error(PyExc_ValueError, "Inputs are not the same length");
                    return NULL;
                }
                finished = first == 0;
                if not finished
                    and integer_prefix
                    and jacpy_is_exact_long(first) != 0
                    and jacpy_is_exact_long(second) != 0 {
                    term = required(PyNumber_Multiply(first, second));
                    replacement = required(PyNumber_Add(result, term));
                    if jacpy_long_fits_i64(first) != 0
                        and jacpy_long_fits_i64(second) != 0
                        and jacpy_long_fits_i64(term) != 0
                        and jacpy_long_fits_i64(replacement) != 0 {
                        jacpy_release(result);
                        result = replacement;
                        continue;
                    }
                    jacpy_release(replacement);
                    jacpy_release(term);
                    term = NULL;
                }
                integer_prefix = False;
                if float_enabled {
                    eligible = False;
                    if not finished {
                        first_float = jacpy_is_exact_float(first) != 0;
                        second_float = jacpy_is_exact_float(second) != 0;
                        eligible = (first_float and second_float)
                            or (
                                first_float
                                and (
                                    jacpy_is_exact_long(second) != 0
                                    or jacpy_is_bool(second) != 0
                                )
                            )
                            or (
                                second_float
                                and (
                                    jacpy_is_exact_long(first) != 0
                                    or jacpy_is_bool(first) != 0
                                )
                            );
                    }
                    if eligible {
                        x = PyFloat_AsDouble(first);
                        conversion_failed = jacpy_error_pending() != 0;
                        y: float = 0.0;
                        if not conversion_failed {
                            y = PyFloat_AsDouble(second);
                            conversion_failed = jacpy_error_pending() != 0;
                        }
                        if conversion_failed {
                            PyErr_Clear();
                        } else {
                            updated = triple_product(x, y, total);
                            if isfinite(updated[0]) {
                                total = updated;
                                float_used = True;
                                continue;
                            }
                        }
                    }
                    float_enabled = False;
                    if float_used {
                        term = required(PyFloat_FromDouble(triple_value(total)));
                        replacement = required(PyNumber_Add(result, term));
                        jacpy_release(result);
                        result = replacement;
                        jacpy_release(term);
                        term = NULL;
                    }
                }
                if finished {
                    return Py_NewRef(result);
                }
                term = required(PyNumber_Multiply(first, second));
                replacement = required(PyNumber_Add(result, term));
                jacpy_release(result);
                result = replacement;
            } finally {
                jacpy_release(first);
                jacpy_release(second);
                jacpy_release(term);
            }
        }
    } except boundary_failure {
        return NULL;
    } finally {
        jacpy_release(left);
        jacpy_release(right);
        jacpy_release(result);
    }
    return NULL;
}

impl float_object(value: f64) -> ptr[PyObject] {
    return PyFloat_FromDouble(value);
}

impl unary_float(operation: int, x: f64) -> ptr[PyObject] {
    value = float_object(x);
    if value == 0 {
        return NULL;
    }
    result = jacpy_math_unary(i64(operation), value);
    jacpy_release(value);
    return result;
}

impl binary_float(operation: int, x: f64, y: f64) -> ptr[PyObject] {
    left = float_object(x);
    right = float_object(y);
    result: ptr[PyObject] = NULL;
    if left != 0 and right != 0 {
        result = jacpy_math_binary(i64(operation), left, right);
    }
    jacpy_release(left);
    jacpy_release(right);
    return result;
}

impl math_gcd_impl(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    arguments = vector_tuple(args, nargs);
    if arguments == 0 {
        return NULL;
    }
    result = jacpy_math_gcd(arguments, 0);
    jacpy_release(arguments);
    return result;
}

impl math_lcm_impl(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    arguments = vector_tuple(args, nargs);
    if arguments == 0 {
        return NULL;
    }
    result = jacpy_math_gcd(arguments, 1);
    jacpy_release(arguments);
    return result;
}

impl math_hypot_impl(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    arguments = vector_tuple(args, nargs);
    if arguments == 0 {
        return NULL;
    }
    result = jacpy_math_hypot(arguments);
    jacpy_release(arguments);
    return result;
}

impl math_ceil_impl(module: ptr[PyObject], x: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_math_unary(28, x);
}

impl math_floor_impl(module: ptr[PyObject], x: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_math_unary(29, x);
}

impl math_trunc_impl(module: ptr[PyObject], x: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_math_unary(30, x);
}

impl math_log10_impl(module: ptr[PyObject], x: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_math_unary(31, x);
}

impl math_log2_impl(module: ptr[PyObject], x: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_math_unary(32, x);
}

impl math_fsum_impl(module: ptr[PyObject], seq: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_math_fsum(seq);
}

impl math_isqrt_impl(module: ptr[PyObject], n: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_math_isqrt(n);
}

impl math_factorial_impl(module: ptr[PyObject], n: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_math_factorial(n);
}

impl math_frexp_impl(module: ptr[PyObject], x: f64) -> ptr[PyObject] {
    value = float_object(x);
    if value == 0 {
        return NULL;
    }
    result = jacpy_math_parts(0, value);
    jacpy_release(value);
    return result;
}

impl math_modf_impl(module: ptr[PyObject], x: f64) -> ptr[PyObject] {
    value = float_object(x);
    if value == 0 {
        return NULL;
    }
    result = jacpy_math_parts(1, value);
    jacpy_release(value);
    return result;
}

impl math_ldexp_impl(module: ptr[PyObject], x: f64, i: ptr[PyObject]) -> ptr[PyObject] {
    value = float_object(x);
    if value == 0 {
        return NULL;
    }
    result = jacpy_math_ldexp(value, i);
    jacpy_release(value);
    return result;
}

impl math_fma_impl(module: ptr[PyObject], x: f64, y: f64, z: f64) -> ptr[PyObject] {
    values = [float_object(x), float_object(y), float_object(z)];
    result: ptr[PyObject] = NULL;
    if 0 not in values {
        result = jacpy_math_fma(values[0], values[1], values[2]);
    }
    for value in values {
        jacpy_release(value);
    }
    return result;
}

impl math_fmod_impl(module: ptr[PyObject], x: f64, y: f64) -> ptr[PyObject] {
    return binary_float(2, x, y);
}

impl math_pow_impl(module: ptr[PyObject], x: f64, y: f64) -> ptr[PyObject] {
    return binary_float(4, x, y);
}

impl math_dist_impl(
    module: ptr[PyObject], p: ptr[PyObject], q: ptr[PyObject]
) -> ptr[PyObject] {
    return jacpy_math_dist(p, q);
}

impl math_sumprod_impl(
    module: ptr[PyObject], p: ptr[PyObject], q: ptr[PyObject]
) -> ptr[PyObject] {
    return jacpy_math_sumprod(p, q);
}

impl math_degrees_impl(module: ptr[PyObject], x: f64) -> ptr[PyObject] {
    return unary_float(23, x);
}

impl math_radians_impl(module: ptr[PyObject], x: f64) -> ptr[PyObject] {
    return unary_float(24, x);
}

impl math_isfinite_impl(module: ptr[PyObject], x: f64) -> ptr[PyObject] {
    return unary_float(25, x);
}

impl math_isinf_impl(module: ptr[PyObject], x: f64) -> ptr[PyObject] {
    return unary_float(26, x);
}

impl math_isnan_impl(module: ptr[PyObject], x: f64) -> ptr[PyObject] {
    return unary_float(27, x);
}

impl math_isclose_impl(
    module: ptr[PyObject], a: f64, b: f64, rel_tol: f64, abs_tol: f64
) -> i32 {
    values = [
        float_object(a),
        float_object(b),
        float_object(rel_tol),
        float_object(abs_tol)
    ];
    result: ptr[PyObject] = NULL;
    if 0 not in values {
        result = jacpy_math_isclose(values[0], values[1], values[2], values[3]);
    }
    for value in values {
        jacpy_release(value);
    }
    if result == 0 {
        return i32(-1);
    }
    truth = PyObject_IsTrue(result);
    jacpy_release(result);
    return i32(truth);
}

impl math_prod_impl(
    module: ptr[PyObject], iterable: ptr[PyObject], start: ptr[PyObject]
) -> ptr[PyObject] {
    return jacpy_math_prod(iterable, start);
}

impl math_perm_impl(
    module: ptr[PyObject], n: ptr[PyObject], k: ptr[PyObject]
) -> ptr[PyObject] {
    return jacpy_math_comb(n, k, 0);
}

impl math_comb_impl(
    module: ptr[PyObject], n: ptr[PyObject], k: ptr[PyObject]
) -> ptr[PyObject] {
    return jacpy_math_comb(n, k, 1);
}

impl math_nextafter_impl(
    module: ptr[PyObject], x: f64, y: f64, steps: ptr[PyObject]
) -> ptr[PyObject] {
    left = float_object(x);
    right = float_object(y);
    result: ptr[PyObject] = NULL;
    if left != 0 and right != 0 {
        result = jacpy_math_nextafter(left, right, steps);
    }
    jacpy_release(left);
    jacpy_release(right);
    return result;
}

impl math_ulp_impl(module: ptr[PyObject], x: f64) -> f64 {
    result = unary_float(33, x);
    if result == 0 {
        return -1.0;
    }
    value = PyFloat_AsDouble(result);
    jacpy_release(result);
    return value;
}
