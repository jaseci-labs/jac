"""Bundled native `colorsys` cross-backend equivalence fixture (#6978).

The same `import colorsys` binds CPython's pure-Python `colorsys` on the sv
backend and `na_stdlib/colorsys.jac` on the na (native LLVM) backend. Every
conversion is a pure float transform, so the two lanes are pinned on exact
(1e-9 tolerance) values across the RGB/YIQ/HLS/HSV round trips, including the
achromatic (`minc == maxc`) and clamping branches. ES/JS opts out.
"""

import colorsys;


def colorsys_py -> dict[any, any] {
    hls = colorsys.rgb_to_hls(0.2, 0.4, 0.6);
    back_hls = colorsys.hls_to_rgb(hls[0], hls[1], hls[2]);
    hsv = colorsys.rgb_to_hsv(0.2, 0.4, 0.6);
    back_hsv = colorsys.hsv_to_rgb(hsv[0], hsv[1], hsv[2]);
    yiq = colorsys.rgb_to_yiq(0.2, 0.4, 0.6);
    back_yiq = colorsys.yiq_to_rgb(yiq[0], yiq[1], yiq[2]);
    grey = colorsys.rgb_to_hls(0.5, 0.5, 0.5);
    grey_hsv = colorsys.rgb_to_hsv(0.5, 0.5, 0.5);
    light = colorsys.rgb_to_hls(0.9, 0.8, 0.7);
    clamp = colorsys.yiq_to_rgb(2.0, 2.0, 2.0);
    sat0 = colorsys.hls_to_rgb(0.25, 0.4, 0.0);
    hue_red = colorsys.rgb_to_hsv(1.0, 0.0, 0.0);
    hue_green = colorsys.rgb_to_hsv(0.0, 1.0, 0.0);
    wheel = colorsys.hsv_to_rgb(0.75, 1.0, 1.0);
    return {
        "hls_h": hls[0],
        "hls_l": hls[1],
        "hls_s": hls[2],
        "hls_rt_r": back_hls[0],
        "hls_rt_g": back_hls[1],
        "hls_rt_b": back_hls[2],
        "hsv_h": hsv[0],
        "hsv_s": hsv[1],
        "hsv_v": hsv[2],
        "hsv_rt_r": back_hsv[0],
        "hsv_rt_g": back_hsv[1],
        "hsv_rt_b": back_hsv[2],
        "yiq_y": yiq[0],
        "yiq_i": yiq[1],
        "yiq_q": yiq[2],
        "yiq_rt_r": back_yiq[0],
        "yiq_rt_g": back_yiq[1],
        "yiq_rt_b": back_yiq[2],
        "grey_h": grey[0],
        "grey_l": grey[1],
        "grey_s": grey[2],
        "grey_hsv_h": grey_hsv[0],
        "grey_hsv_s": grey_hsv[1],
        "grey_hsv_v": grey_hsv[2],
        "light_h": light[0],
        "light_l": light[1],
        "light_s": light[2],
        "clamp_r": clamp[0],
        "clamp_g": clamp[1],
        "clamp_b": clamp[2],
        "sat0_r": sat0[0],
        "sat0_g": sat0[1],
        "sat0_b": sat0[2],
        "red_h": hue_red[0],
        "green_h": hue_green[0],
        "wheel_r": wheel[0],
        "wheel_g": wheel[1],
        "wheel_b": wheel[2],

    };
}


def colorsys_cl -> dict[any, any] {
    return {};
}


def colorsys_na -> dict[str, any] {
    hls = colorsys.rgb_to_hls(0.2, 0.4, 0.6);
    back_hls = colorsys.hls_to_rgb(hls[0], hls[1], hls[2]);
    hsv = colorsys.rgb_to_hsv(0.2, 0.4, 0.6);
    back_hsv = colorsys.hsv_to_rgb(hsv[0], hsv[1], hsv[2]);
    yiq = colorsys.rgb_to_yiq(0.2, 0.4, 0.6);
    back_yiq = colorsys.yiq_to_rgb(yiq[0], yiq[1], yiq[2]);
    grey = colorsys.rgb_to_hls(0.5, 0.5, 0.5);
    grey_hsv = colorsys.rgb_to_hsv(0.5, 0.5, 0.5);
    light = colorsys.rgb_to_hls(0.9, 0.8, 0.7);
    clamp = colorsys.yiq_to_rgb(2.0, 2.0, 2.0);
    sat0 = colorsys.hls_to_rgb(0.25, 0.4, 0.0);
    hue_red = colorsys.rgb_to_hsv(1.0, 0.0, 0.0);
    hue_green = colorsys.rgb_to_hsv(0.0, 1.0, 0.0);
    wheel = colorsys.hsv_to_rgb(0.75, 1.0, 1.0);
    return {
        "hls_h": hls[0],
        "hls_l": hls[1],
        "hls_s": hls[2],
        "hls_rt_r": back_hls[0],
        "hls_rt_g": back_hls[1],
        "hls_rt_b": back_hls[2],
        "hsv_h": hsv[0],
        "hsv_s": hsv[1],
        "hsv_v": hsv[2],
        "hsv_rt_r": back_hsv[0],
        "hsv_rt_g": back_hsv[1],
        "hsv_rt_b": back_hsv[2],
        "yiq_y": yiq[0],
        "yiq_i": yiq[1],
        "yiq_q": yiq[2],
        "yiq_rt_r": back_yiq[0],
        "yiq_rt_g": back_yiq[1],
        "yiq_rt_b": back_yiq[2],
        "grey_h": grey[0],
        "grey_l": grey[1],
        "grey_s": grey[2],
        "grey_hsv_h": grey_hsv[0],
        "grey_hsv_s": grey_hsv[1],
        "grey_hsv_v": grey_hsv[2],
        "light_h": light[0],
        "light_l": light[1],
        "light_s": light[2],
        "clamp_r": clamp[0],
        "clamp_g": clamp[1],
        "clamp_b": clamp[2],
        "sat0_r": sat0[0],
        "sat0_g": sat0[1],
        "sat0_b": sat0[2],
        "red_h": hue_red[0],
        "green_h": hue_green[0],
        "wheel_r": wheel[0],
        "wheel_g": wheel[1],
        "wheel_b": wheel[2],

    };
}
