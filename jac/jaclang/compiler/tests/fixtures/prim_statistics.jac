"""Bundled native ``statistics`` cross-backend equivalence fixture.

The sv entry uses CPython's statistics module; the na entry the bundled
`statistics.na.jac`. Results are pinned as scaled ints so the exact-Fraction
CPython pipeline and the double-precision native pipeline agree. The bundled
median always computes in float (CPython preserves the element for odd
counts); consumers pin through int(). Errors are pinned via ValueError
(StatisticsError subclasses it). ES/JS opts out.
"""

import statistics;
import from statistics { fmean, mean, median, pstdev, pvariance, stdev, variance }


def statistics_py -> dict {
    times = [900, 100, 500];
    med_bare = int(statistics.median(times));
    med_odd = int(median([5, 1, 9]));
    med_even_x10 = int(median([1, 2, 3, 4]) * 10);
    mean_x10 = int(mean([1, 2, 3, 4]) * 10);
    fmean_x10 = int(fmean([1.5, 2.5]) * 10);
    pstdev_x1000 = int(pstdev([2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0]) * 1000);
    stdev_x1000 = int(stdev([2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0]) * 1000);
    var_x1000 = int(variance([1.0, 2.0, 3.0]) * 1000);
    pvar_x1000 = int(pvariance([1.0, 2.0, 3.0]) * 1000);
    empty_ints: list[int] = [];
    empty_raises = 0;
    try {
        tmp = median(empty_ints);
    } except ValueError {
        empty_raises = 1;
    }
    one_stdev_raises = 0;
    try {
        tmp2 = stdev([3.0]);
    } except ValueError {
        one_stdev_raises = 1;
    }
    return {
        "med_bare": med_bare,
        "med_odd": med_odd,
        "med_even_x10": med_even_x10,
        "mean_x10": mean_x10,
        "fmean_x10": fmean_x10,
        "pstdev_x1000": pstdev_x1000,
        "stdev_x1000": stdev_x1000,
        "var_x1000": var_x1000,
        "pvar_x1000": pvar_x1000,
        "empty_raises": empty_raises,
        "one_stdev_raises": one_stdev_raises,

    };
}

cl def statistics_cl -> dict {
    return {};
}

na {
    def statistics_na -> dict[str, any] {
        times = [900, 100, 500];
        med_bare = int(statistics.median(times));
        med_odd = int(median([5, 1, 9]));
        med_even_x10 = int(median([1, 2, 3, 4]) * 10);
        mean_x10 = int(mean([1, 2, 3, 4]) * 10);
        fmean_x10 = int(fmean([1.5, 2.5]) * 10);
        pstdev_x1000 = int(pstdev([2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0]) * 1000);
        stdev_x1000 = int(stdev([2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0]) * 1000);
        var_x1000 = int(variance([1.0, 2.0, 3.0]) * 1000);
        pvar_x1000 = int(pvariance([1.0, 2.0, 3.0]) * 1000);
        empty_ints: list[int] = [];
        empty_raises = 0;
        try {
            tmp = median(empty_ints);
        } except ValueError {
            empty_raises = 1;
        }
        one_stdev_raises = 0;
        try {
            tmp2 = stdev([3.0]);
        } except ValueError {
            one_stdev_raises = 1;
        }
        return {
            "med_bare": med_bare,
            "med_odd": med_odd,
            "med_even_x10": med_even_x10,
            "mean_x10": mean_x10,
            "fmean_x10": fmean_x10,
            "pstdev_x1000": pstdev_x1000,
            "stdev_x1000": stdev_x1000,
            "var_x1000": var_x1000,
            "pvar_x1000": pvar_x1000,
            "empty_raises": empty_raises,
            "one_stdev_raises": one_stdev_raises,

        };
    }
}
