/* Header-free extract from Modules/_stat.c (S_IMODE, S_IFMT). */

typedef unsigned int mode_t;

#ifndef S_IMODE
#  define S_IMODE 07777
#endif

#ifndef S_IFMT
#  define S_IFMT 0170000
#endif

static int
_c_mode_ok(long op)
{
    if (op < 0) {
        return 0;
    }
    return 1;
}

unsigned long
stat_S_IMODE(long omode)
{
    mode_t mode;
    if (!_c_mode_ok(omode)) {
        return (unsigned long)-1;
    }
    mode = (mode_t)omode;
    return (unsigned long)(mode & S_IMODE);
}

unsigned long
stat_S_IFMT(long omode)
{
    mode_t mode;
    if (!_c_mode_ok(omode)) {
        return (unsigned long)-1;
    }
    mode = (mode_t)omode;
    return (unsigned long)(mode & S_IFMT);
}
