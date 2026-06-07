cl import from "clsx" { clsx }
cl import from "tailwind-merge" { twMerge }

def:pub cn(
    a: any = None,
    b: any = None,
    c: any = None,
    d: any = None,
    e: any = None,
    f: any = None,
    g: any = None,
    h: any = None,
    i: any = None,
    j: any = None,
    k: any = None,
    l: any = None
) -> str {
    return twMerge(clsx([a, b, c, d, e, f, g, h, i, j, k, l]));
}
