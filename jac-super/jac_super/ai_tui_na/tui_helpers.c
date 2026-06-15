/*
 * tui_helpers.c — low-level terminal helpers for the NA TUI binary.
 *
 * Provides scalar-only entry points so the NA side never needs to touch
 * C structs (termios, winsize, pollfd) — all struct manipulation stays here.
 *
 * Build: gcc -O2 -shared -fPIC -o libtui_helpers.so tui_helpers.c
 */
#include <termios.h>
#include <unistd.h>
#include <fcntl.h>
#include <poll.h>
#include <sys/ioctl.h>
#include <string.h>
#include <errno.h>

/* ── globals ─────────────────────────────────────────────────────────────── */

static struct termios g_saved;
static int g_rows = 24, g_cols = 80;
static int g_stdin_ready = 0, g_key_ready = 0;

/* Static read buffers returned by the string-returning helpers. */
static char g_key_buf[16];
static char g_line_buf[8192];

/* ── terminal lifecycle ───────────────────────────────────────────────────── */

/* Open /dev/tty, enter raw mode (non-blocking), return fd; -1 on error. */
int tui_open(void) {
    int fd = open("/dev/tty", O_RDWR);
    if (fd < 0) return -1;

    /* Push the tty fd above 9 so otui_init's dup2(1,3) can't clobber it. */
    if (fd < 10) {
        int safe = fcntl(fd, F_DUPFD, 10);
        close(fd);
        if (safe < 0) return -1;
        fd = safe;
    }

    tcgetattr(fd, &g_saved);

    struct termios raw;
    memcpy(&raw, &g_saved, sizeof(raw));
    cfmakeraw(&raw);
    tcsetattr(fd, TCSANOW, &raw);

    int fl = fcntl(fd, F_GETFL, 0);
    fcntl(fd, F_SETFL, fl | O_NONBLOCK);

    return fd;
}

/* Restore terminal and close fd. */
void tui_close(int fd) {
    if (fd >= 0) {
        tcsetattr(fd, TCSANOW, &g_saved);
        close(fd);
    }
}

/* ── size ────────────────────────────────────────────────────────────────── */

void tui_update_size(int fd) {
    struct winsize ws;
    if (ioctl(fd, TIOCGWINSZ, &ws) == 0 && ws.ws_row > 0 && ws.ws_col > 0) {
        g_rows = (int)ws.ws_row;
        g_cols = (int)ws.ws_col;
    }
}

int tui_rows(void) { return g_rows; }
int tui_cols(void) { return g_cols; }

/* ── multiplexed poll ────────────────────────────────────────────────────── */

/*
 * Poll stdin (fd 0) and the tty fd simultaneously.
 * Sets g_stdin_ready / g_key_ready, clears them first each call.
 * timeout_ms == 0: non-blocking; > 0: wait up to that many ms.
 */
void tui_poll(int tty_fd, int timeout_ms) {
    g_stdin_ready = 0;
    g_key_ready   = 0;

    struct pollfd fds[2];
    fds[0].fd      = 0;      /* stdin — IPC pipe from Python */
    fds[0].events  = POLLIN;
    fds[0].revents = 0;
    fds[1].fd      = tty_fd; /* keyboard */
    fds[1].events  = POLLIN;
    fds[1].revents = 0;

    int r = poll(fds, 2, timeout_ms);
    if (r <= 0) return;

    if (fds[0].revents & POLLIN) g_stdin_ready = 1;
    if (fds[1].revents & POLLIN) g_key_ready   = 1;
}

int tui_stdin_ready(void) { return g_stdin_ready; }
int tui_key_ready(void)   { return g_key_ready;   }

/* ── IPC line reader (blocking, called only when stdin is readable) ───────── */

/*
 * Read one newline-terminated line from stdin into g_line_buf.
 * Strips the trailing '\n'.  Returns "" on EOF/error.
 * The NA side receives a copy of this buffer as a Jac str.
 */
const char *tui_read_line(void) {
    int n = 0;
    char c;
    while (n < (int)(sizeof(g_line_buf) - 1)) {
        ssize_t r = read(0, &c, 1);
        if (r <= 0) break;        /* EOF or error */
        if (c == '\n') break;
        if (c != '\r') g_line_buf[n++] = c;
    }
    g_line_buf[n] = '\0';
    return g_line_buf;
}

/* ── keyboard reader ─────────────────────────────────────────────────────── */

/*
 * Read one keypress from tty_fd into g_key_buf and return it as a string.
 * Regular printable chars are returned as a 1-char string.
 * ESC sequences are assembled and returned whole (\033[A, \033[5~, etc.).
 * Returns "" if nothing is ready (O_NONBLOCK).
 */
const char *tui_read_key(int fd) {
    unsigned char c;
    ssize_t n = read(fd, &c, 1);
    if (n <= 0) return "";

    if (c != 27) {
        /* Normal character */
        g_key_buf[0] = (char)c;
        g_key_buf[1] = '\0';
        return g_key_buf;
    }

    /* ESC — try to read the rest of the sequence without blocking long */
    g_key_buf[0] = 27;
    int pos = 1;

    unsigned char c2;
    n = read(fd, &c2, 1);
    if (n <= 0) {
        /* Lone ESC */
        g_key_buf[1] = '\0';
        return g_key_buf;
    }
    g_key_buf[pos++] = (char)c2;

    if (c2 == '[') {
        unsigned char c3;
        n = read(fd, &c3, 1);
        if (n > 0) {
            g_key_buf[pos++] = (char)c3;
            /* Extended: [5~ [6~ [1;5C etc. */
            if ((c3 >= '0' && c3 <= '9') || c3 == '1') {
                unsigned char c4;
                n = read(fd, &c4, 1);
                if (n > 0) {
                    g_key_buf[pos++] = (char)c4;
                    /* Could have one more byte for \033[1;5A etc. */
                    if (c4 == ';') {
                        unsigned char c5, c6;
                        n = read(fd, &c5, 1);
                        if (n > 0) {
                            g_key_buf[pos++] = (char)c5;
                            n = read(fd, &c6, 1);
                            if (n > 0) g_key_buf[pos++] = (char)c6;
                        }
                    }
                }
            }
        }
    } else if (c2 == 'O') {
        /* SS3 sequences: \033OA = up, etc. */
        unsigned char c3;
        n = read(fd, &c3, 1);
        if (n > 0) g_key_buf[pos++] = (char)c3;
    }

    g_key_buf[pos] = '\0';
    return g_key_buf;
}

/* ── output ──────────────────────────────────────────────────────────────── */

/* Write a NUL-terminated string to fd (no newline added). */
void tui_write(int fd, const char *s) {
    size_t len = strlen(s);
    if (len == 0) return;
    /* Retry on EINTR */
    size_t written = 0;
    while (written < len) {
        ssize_t r = write(fd, s + written, len - written);
        if (r <= 0) break;
        written += (size_t)r;
    }
}
