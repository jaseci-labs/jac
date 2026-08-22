/* Header-free extract of CPython Modules/getbuildinfo.c (Py_GetBuildInfo). */

static int c_strcmp(const char *a, const char *b) {
    while (*a && *a == *b) {
        a++;
        b++;
    }
    return (unsigned char)*a - (unsigned char)*b;
}

static void c_strcpy(char *dst, const char *src) {
    int i = 0;
    while (src[i] != '\0') {
        dst[i] = src[i];
        i++;
    }
    dst[i] = '\0';
}

static void c_strcat(char *dst, const char *src) {
    int i = 0;
    while (dst[i] != '\0') {
        i++;
    }
    int j = 0;
    while (src[j] != '\0') {
        dst[i + j] = src[j];
        j++;
    }
    dst[i + j] = '\0';
}

#ifndef DATE
#define DATE "Jan 01 1970"
#endif

#ifndef TIME
#define TIME "00:00:00"
#endif

#ifndef GITVERSION
#define GITVERSION ""
#endif

#ifndef GITTAG
#define GITTAG ""
#endif

#ifndef GITBRANCH
#define GITBRANCH ""
#endif

static int initialized = 0;
static char buildinfo[128];

const char *_Py_gitversion(void);
const char *_Py_gitidentifier(void);

const char *
Py_GetBuildInfo(void)
{
    if (initialized) {
        return buildinfo;
    }
    initialized = 1;
    const char *revision = _Py_gitversion();
    const char *gitid = _Py_gitidentifier();
    if (gitid[0] == '\0') {
        gitid = "main";
    }
    buildinfo[0] = '\0';
    c_strcpy(buildinfo, gitid);
    if (revision[0] != '\0') {
        c_strcat(buildinfo, ":");
        c_strcat(buildinfo, revision);
    }
    c_strcat(buildinfo, ", ");
    c_strcat(buildinfo, DATE);
    c_strcat(buildinfo, ", ");
    c_strcat(buildinfo, TIME);
    return buildinfo;
}

const char *
_Py_gitversion(void)
{
    return GITVERSION;
}

const char *
_Py_gitidentifier(void)
{
    const char *gittag, *gitid;
    gittag = GITTAG;
    if (gittag[0] != '\0' && c_strcmp(gittag, "undefined") != 0)
        gitid = gittag;
    else
        gitid = GITBRANCH;
    return gitid;
}
