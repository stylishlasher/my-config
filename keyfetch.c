/*
 * keyfetch - a tiny fetch with a spinning 3D key.
 * Single file, no dependencies except libm.
 *
 *   cc -O2 -o keyfetch keyfetch.c -lm
 *   ./keyfetch -c "#ff8800"
 *
 * Press any key to stop (Ctrl-C works too). The last frame stays on screen.
 */
#define _GNU_SOURCE
#include <ctype.h>
#include <fcntl.h>
#include <getopt.h>
#include <math.h>
#include <pwd.h>
#include <signal.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/statvfs.h>
#include <sys/utsname.h>
#include <termios.h>
#include <time.h>
#include <unistd.h>

/* ------------------------------------------------------------------ */
/* colors                                                              */
/* ------------------------------------------------------------------ */

typedef struct { int r, g, b; } RGB;

static const struct { const char *name; RGB c; } NAMES[] = {
    {"red",     {255,  60,  60}}, {"green",  { 70, 220,  90}},
    {"yellow",  {255, 220,  60}}, {"blue",   { 70, 120, 255}},
    {"magenta", {230,  70, 220}}, {"cyan",   { 60, 220, 230}},
    {"white",   {235, 235, 235}}, {"orange", {255, 140,  30}},
    {"pink",    {255, 130, 190}}, {"purple", {160,  90, 255}},
    {"gold",    {255, 200,  40}}, {"silver", {190, 195, 205}},
    {"teal",    { 30, 190, 170}}, {"lime",   {160, 255,  60}},
};

static int parse_color(const char *s, RGB *out) {
    for (size_t i = 0; i < sizeof NAMES / sizeof *NAMES; i++)
        if (!strcasecmp(s, NAMES[i].name)) { *out = NAMES[i].c; return 1; }
    if (*s == '#') s++;
    if (strlen(s) == 6 && strspn(s, "0123456789abcdefABCDEF") == 6) {
        unsigned v = (unsigned)strtoul(s, NULL, 16);
        *out = (RGB){(int)(v >> 16) & 255, (int)(v >> 8) & 255, (int)v & 255};
        return 1;
    }
    return 0;
}

static RGB hsv(float h, float s, float v) {
    float c = v * s, hh = fmodf(h, 360.f) / 60.f;
    float x = c * (1 - fabsf(fmodf(hh, 2.f) - 1)), m = v - c, r = 0, g = 0, b = 0;
    if      (hh < 1) { r = c; g = x; }
    else if (hh < 2) { r = x; g = c; }
    else if (hh < 3) { g = c; b = x; }
    else if (hh < 4) { g = x; b = c; }
    else if (hh < 5) { r = x; b = c; }
    else             { r = c; b = x; }
    return (RGB){(int)((r + m) * 255), (int)((g + m) * 255), (int)((b + m) * 255)};
}

static int truecolor = 1;

static int to256(RGB c) {
    return 16 + 36 * ((c.r * 5 + 127) / 255) + 6 * ((c.g * 5 + 127) / 255) +
           ((c.b * 5 + 127) / 255);
}

static char *put_color(char *p, RGB c) {
    if (truecolor) return p + sprintf(p, "\033[38;2;%d;%d;%dm", c.r, c.g, c.b);
    return p + sprintf(p, "\033[38;5;%dm", to256(c));
}

static int clampi(int v, int lo, int hi) { return v < lo ? lo : v > hi ? hi : v; }

/* ------------------------------------------------------------------ */
/* the key: a point cloud with normals                                 */
/* ------------------------------------------------------------------ */

typedef struct { float x, y, z, nx, ny, nz; } Pt;
static Pt *pts;
static int npts, cap;
#define STEP 0.03f

static void add(float x, float y, float z, float nx, float ny, float nz) {
    if (npts == cap) {
        cap = cap ? cap * 2 : 8192;
        pts = realloc(pts, (size_t)cap * sizeof(Pt));
        if (!pts) { perror("realloc"); exit(1); }
    }
    pts[npts++] = (Pt){x, y, z, nx, ny, nz};
}

/* ring (bow of the key), lies in the XY plane */
static void add_torus(float cx, float R, float r) {
    int nu = (int)ceilf(2 * M_PI * (R + r) / STEP);
    int nv = (int)ceilf(2 * M_PI * r / STEP);
    for (int i = 0; i < nu; i++)
        for (int j = 0; j < nv; j++) {
            float u = 2 * M_PI * i / nu, v = 2 * M_PI * j / nv;
            float cu = cosf(u), su = sinf(u), cv = cosf(v), sv = sinf(v);
            add(cx + (R + r * cv) * cu, (R + r * cv) * su, r * sv, cv * cu, cv * su, sv);
        }
}

/* cylinder along X */
static void add_cyl(float x0, float x1, float rho) {
    int nt = (int)ceilf(2 * M_PI * rho / STEP);
    int nx = (int)ceilf((x1 - x0) / STEP) + 1;
    for (int i = 0; i < nx; i++) {
        float x = x0 + (x1 - x0) * i / (nx - 1);
        for (int j = 0; j < nt; j++) {
            float t = 2 * M_PI * j / nt;
            add(x, rho * cosf(t), rho * sinf(t), 0, cosf(t), sinf(t));
        }
    }
}

/* flat disc closing a cylinder, normal = (dir,0,0) */
static void add_disc(float x, float rho, float dir) {
    for (float rad = 0; rad <= rho; rad += STEP) {
        int n = rad < 1e-4f ? 1 : (int)ceilf(2 * M_PI * rad / STEP);
        for (int j = 0; j < n; j++) {
            float t = 2 * M_PI * j / n;
            add(x, rad * cosf(t), rad * sinf(t), dir, 0, 0);
        }
    }
}

/* axis-aligned box (teeth of the key) */
static void add_box(float x0, float x1, float y0, float y1, float z0, float z1) {
    int nx = (int)ceilf((x1 - x0) / STEP) + 1;
    int ny = (int)ceilf((y1 - y0) / STEP) + 1;
    int nz = (int)ceilf((z1 - z0) / STEP) + 1;
#define LX (x0 + (x1 - x0) * i / (nx - 1))
#define LY (y0 + (y1 - y0) * j / (ny - 1))
#define LZ (z0 + (z1 - z0) * k / (nz - 1))
    for (int i = 0; i < nx; i++)
        for (int j = 0; j < ny; j++) {
            add(LX, LY, z0, 0, 0, -1);
            add(LX, LY, z1, 0, 0, 1);
        }
    for (int i = 0; i < nx; i++)
        for (int k = 0; k < nz; k++) {
            add(LX, y0, LZ, 0, -1, 0);
            add(LX, y1, LZ, 0, 1, 0);
        }
    for (int j = 0; j < ny; j++)
        for (int k = 0; k < nz; k++) {
            add(x0, LY, LZ, -1, 0, 0);
            add(x1, LY, LZ, 1, 0, 0);
        }
#undef LX
#undef LY
#undef LZ
}

static void build_key(void) {
    add_torus(-1.55f, 0.62f, 0.17f);               /* bow           */
    add_cyl(-0.80f, 1.95f, 0.12f);                 /* shaft         */
    add_disc(1.95f, 0.12f, 1);                     /* shaft tip     */
    add_cyl(-0.55f, -0.38f, 0.20f);                /* collar        */
    add_disc(-0.55f, 0.20f, -1);
    add_disc(-0.38f, 0.20f, 1);
    add_box(1.28f, 1.44f, -0.55f, -0.08f, -0.08f, 0.08f); /* teeth */
    add_box(1.54f, 1.70f, -0.38f, -0.08f, -0.08f, 0.08f);
    add_box(1.80f, 1.95f, -0.62f, -0.08f, -0.08f, 0.08f);

    /* center the model and fit it into a unit sphere */
    float mn[3] = {1e9f, 1e9f, 1e9f}, mx[3] = {-1e9f, -1e9f, -1e9f};
    for (int i = 0; i < npts; i++) {
        float v[3] = {pts[i].x, pts[i].y, pts[i].z};
        for (int k = 0; k < 3; k++) {
            if (v[k] < mn[k]) mn[k] = v[k];
            if (v[k] > mx[k]) mx[k] = v[k];
        }
    }
    float c[3] = {(mn[0] + mx[0]) / 2, (mn[1] + mx[1]) / 2, (mn[2] + mx[2]) / 2};
    float rmax = 0;
    for (int i = 0; i < npts; i++) {
        pts[i].x -= c[0]; pts[i].y -= c[1]; pts[i].z -= c[2];
        float d = sqrtf(pts[i].x * pts[i].x + pts[i].y * pts[i].y + pts[i].z * pts[i].z);
        if (d > rmax) rmax = d;
    }
    for (int i = 0; i < npts; i++) { pts[i].x /= rmax; pts[i].y /= rmax; pts[i].z /= rmax; }
}

/* ------------------------------------------------------------------ */
/* system info (Linux; fields that can't be read are just skipped)     */
/* ------------------------------------------------------------------ */

enum { L_TITLE, L_SEP, L_FIELD };
typedef struct { int kind; char label[16]; char val[200]; } Line;
static Line info[24];
static int ninfo, idx_up = -1, idx_mem = -1, title_len;

static int add_line(int kind, const char *label, const char *fmt, ...) {
    if (ninfo >= 24) return -1;
    Line *l = &info[ninfo];
    l->kind = kind;
    snprintf(l->label, sizeof l->label, "%s", label);
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(l->val, sizeof l->val, fmt, ap);
    va_end(ap);
    return ninfo++;
}

static int first_line(const char *path, char *buf, size_t n) {
    FILE *f = fopen(path, "r");
    if (!f) return 0;
    if (!fgets(buf, (int)n, f)) { fclose(f); return 0; }
    fclose(f);
    buf[strcspn(buf, "\r\n")] = 0;
    return buf[0] != 0;
}

static void strip_sub(char *s, const char *sub) {
    size_t n = strlen(sub);
    for (char *p; (p = strstr(s, sub));) memmove(p, p + n, strlen(p + n) + 1);
}

static void squeeze(char *s) {
    char *w = s;
    for (char *r = s; *r; r++)
        if (!(*r == ' ' && (w == s || w[-1] == ' '))) *w++ = *r;
    if (w > s && w[-1] == ' ') w--;
    *w = 0;
}

static int os_name(char *b, size_t n) {
    FILE *f = fopen("/etc/os-release", "r");
    if (!f) return 0;
    char line[256];
    int ok = 0;
    while (fgets(line, sizeof line, f))
        if (!strncmp(line, "PRETTY_NAME=", 12)) {
            char *v = line + 12;
            v[strcspn(v, "\r\n")] = 0;
            if (*v == '"' || *v == '\'') { v++; v[strcspn(v, "\"'")] = 0; }
            snprintf(b, n, "%s", v);
            ok = 1;
            break;
        }
    fclose(f);
    return ok;
}

static int cpu_name(char *b, size_t n) {
    FILE *f = fopen("/proc/cpuinfo", "r");
    if (!f) return 0;
    char line[256];
    int ok = 0, cores = 0;
    while (fgets(line, sizeof line, f)) {
        if (!ok && (!strncmp(line, "model name", 10) || !strncmp(line, "Model name", 10))) {
            char *v = strchr(line, ':');
            if (v) { snprintf(b, n, "%s", v + 2); b[strcspn(b, "\r\n")] = 0; ok = 1; }
        }
        if (!strncmp(line, "processor", 9)) cores++;
    }
    fclose(f);
    if (!ok) return 0;
    strip_sub(b, "(R)"); strip_sub(b, "(TM)"); strip_sub(b, "(tm)");
    squeeze(b);
    size_t l = strlen(b);
    if (cores > 0 && l + 8 < n) snprintf(b + l, n - l, " (%d)", cores);
    return 1;
}

static void fmt_uptime(char *b, size_t n) {
    double up = 0;
    FILE *f = fopen("/proc/uptime", "r");
    if (!f) { b[0] = 0; return; }
    if (fscanf(f, "%lf", &up) != 1) up = 0;
    fclose(f);
    long s = (long)up, d = s / 86400, h = s % 86400 / 3600, m = s % 3600 / 60;
    if (d) snprintf(b, n, "%ld day%s, %ld hour%s, %ld min%s", d, d == 1 ? "" : "s", h,
                    h == 1 ? "" : "s", m, m == 1 ? "" : "s");
    else if (h) snprintf(b, n, "%ld hour%s, %ld min%s", h, h == 1 ? "" : "s", m, m == 1 ? "" : "s");
    else snprintf(b, n, "%ld min%s, %ld sec", m, m == 1 ? "" : "s", s % 60);
}

static int fmt_mem(char *b, size_t n) {
    FILE *f = fopen("/proc/meminfo", "r");
    if (!f) return 0;
    char line[128];
    long total = 0, avail = 0;
    while (fgets(line, sizeof line, f)) {
        sscanf(line, "MemTotal: %ld kB", &total);
        sscanf(line, "MemAvailable: %ld kB", &avail);
    }
    fclose(f);
    if (!total) return 0;
    double u = (total - avail) / 1048576.0, t = total / 1048576.0;
    snprintf(b, n, "%.2f / %.2f GiB (%d%%)", u, t, (int)(100.0 * (total - avail) / total));
    return 1;
}

static void build_info(void) {
    char buf[200], host[64] = "localhost";
    struct passwd *pw = getpwuid(getuid());
    gethostname(host, sizeof host);
    title_len = (int)(strlen(pw ? pw->pw_name : "user") + 1 + strlen(host));
    add_line(L_TITLE, "", "%s@%s", pw ? pw->pw_name : "user", host);
    add_line(L_SEP, "", "");
    if (os_name(buf, sizeof buf)) add_line(L_FIELD, "OS", "%s", buf);
    if (first_line("/sys/class/dmi/id/product_name", buf, sizeof buf)) add_line(L_FIELD, "Host", "%s", buf);
    struct utsname u;
    if (!uname(&u)) add_line(L_FIELD, "Kernel", "%s", u.release);
    idx_up = add_line(L_FIELD, "Uptime", "");
    const char *sh = getenv("SHELL");
    if (sh) add_line(L_FIELD, "Shell", "%s", strrchr(sh, '/') ? strrchr(sh, '/') + 1 : sh);
    const char *term = getenv("TERM_PROGRAM");
    if (!term) term = getenv("TERM");
    if (term) add_line(L_FIELD, "Terminal", "%s", term);
    if (cpu_name(buf, sizeof buf)) add_line(L_FIELD, "CPU", "%s", buf);
    if (fmt_mem(buf, sizeof buf)) idx_mem = add_line(L_FIELD, "Memory", "%s", buf);
    struct statvfs sv;
    if (!statvfs("/", &sv)) {
        double t = (double)sv.f_blocks * sv.f_frsize / 1073741824.0;
        double used = ((double)sv.f_blocks - sv.f_bfree) * sv.f_frsize / 1073741824.0;
        add_line(L_FIELD, "Disk", "%.1f / %.1f GiB (%d%%)", used, t, t > 0 ? (int)(100 * used / t) : 0);
    }
}

static void update_live(void) {
    char buf[200];
    if (idx_up >= 0) { fmt_uptime(buf, sizeof buf); snprintf(info[idx_up].val, sizeof info[0].val, "%s", buf); }
    if (idx_mem >= 0 && fmt_mem(buf, sizeof buf)) snprintf(info[idx_mem].val, sizeof info[0].val, "%s", buf);
}

static void trunc_cp(char *s, int maxcp) {
    int cp = 0;
    for (char *q = s; *q; q++)
        if (((unsigned char)*q & 0xC0) != 0x80) {
            if (cp == maxcp) { *q = 0; break; }
            cp++;
        }
}

static char *put_info(char *p, const Line *l, int avail, RGB lab, int maxlab, int use_color) {
    char tmp[256];
    if (l->kind == L_TITLE) {
        snprintf(tmp, sizeof tmp, "%s", l->val);
        trunc_cp(tmp, avail);
        if (use_color) { p += sprintf(p, "\033[1m"); p = put_color(p, lab); }
        p += sprintf(p, "%s", tmp);
    } else if (l->kind == L_SEP) {
        int n = title_len < avail ? title_len : avail;
        if (use_color) p += sprintf(p, "\033[2m");
        for (int i = 0; i < n; i++) p += sprintf(p, "\xe2\x94\x80");
    } else {
        if (use_color) { p += sprintf(p, "\033[1m"); p = put_color(p, lab); }
        p += sprintf(p, "%-*s", maxlab, l->label);
        if (use_color) p += sprintf(p, "\033[0m");
        snprintf(tmp, sizeof tmp, "%s", l->val);
        trunc_cp(tmp, avail - maxlab - 1 > 0 ? avail - maxlab - 1 : 0);
        p += sprintf(p, " %s", tmp);
    }
    if (use_color) p += sprintf(p, "\033[0m");
    return p;
}

/* ------------------------------------------------------------------ */
/* terminal plumbing                                                   */
/* ------------------------------------------------------------------ */

static struct termios orig_tio;
static int have_tio;
static volatile sig_atomic_t stop_flag;

static int pinned;

static void restore_term(void) {
    ssize_t r;
    if (pinned) { /* give the scroll region back, keep the shell's cursor */
        static const char s[] = "\0337\033[r\0338";
        r = write(1, s, sizeof s - 1);
        (void)r;
        return;
    }
    if (have_tio) tcsetattr(0, TCSANOW, &orig_tio);
    r = write(1, "\033[0m\033[?25h", 10);
    (void)r;
}

/* --pin bookkeeping: one background key per terminal (pidfile keyed by tty) */
static void pidfile_path(char *b, size_t n) {
    const char *tn = ttyname(1);
    char s[96] = "notty";
    if (tn) {
        size_t j = 0;
        for (const char *q = tn; *q && j < sizeof s - 1; q++) s[j++] = isalnum((unsigned char)*q) ? *q : '_';
        s[j] = 0;
    }
    snprintf(b, n, "/tmp/keyfetch-%d-%s.pid", (int)getuid(), s);
}

static int same_comm(int pid) { /* don't kill a recycled pid that isn't us */
    char a[64] = "", b[64] = "", p[64];
    snprintf(p, sizeof p, "/proc/%d/comm", pid);
    first_line(p, a, sizeof a);
    first_line("/proc/self/comm", b, sizeof b);
    return a[0] && !strcmp(a, b);
}

static int alive(int pid) { /* a zombie counts as gone */
    char p[64], l[256];
    snprintf(p, sizeof p, "/proc/%d/stat", pid);
    if (kill(pid, 0) != 0) return 0;
    if (!first_line(p, l, sizeof l)) return 0;
    char *q = strrchr(l, ')');
    return !(q && q[1] == ' ' && q[2] == 'Z');
}

static void pin_kill_old(const char *pf) {
    FILE *f = fopen(pf, "r");
    if (!f) return;
    int pid = 0;
    if (fscanf(f, "%d", &pid) == 1 && pid > 1 && same_comm(pid)) {
        kill(pid, SIGTERM);
        for (int i = 0; i < 50 && alive(pid); i++) usleep(10000); /* let it reset the region */
    }
    fclose(f);
    unlink(pf);
}
static void on_sig(int s) { (void)s; stop_flag = 1; }

static double now_s(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec * 1e-9;
}

static void usage(const char *a0) {
    printf("usage: %s [options]\n\n"
           "  -c, --color <c>        key color: name (red, orange, gold, cyan, pink, ...)\n"
           "                         or hex like \"#ff8800\"   (default: gold)\n"
           "  -t, --label-color <c>  color of the info labels (default: same as key)\n"
           "  -r, --rainbow          cycle the hue over time\n"
           "  -s, --speed <f>        rotation speed multiplier (default 1.0)\n"
           "      --size <f>         key scale (default 1.0)\n"
           "      --height <n>       render height in rows (default 16)\n"
           "      --spin <x|y|xy>    rotation axes (default y)\n"
           "      --frames <n>       stop after n frames\n"
           "      --pin              run in the background, pinned to the top of the\n"
           "                         screen; the shell stays usable below (clears screen)\n"
           "      --stop             stop the pinned key of this terminal\n"
           "  -n, --no-info          only the key\n"
           "      --no-color         disable colors\n"
           "  -h, --help             this help\n", a0);
}

/* ------------------------------------------------------------------ */

int main(int argc, char **argv) {
    RGB key_col = {255, 200, 40}, lab_col = key_col;
    int lab_set = 0, rainbow = 0, use_color = !getenv("NO_COLOR"), show_info = 1;
    int H = 16, max_frames = 0, spin_x = 0, spin_y = 1, pin = 0, stop_cmd = 0;
    float speed = 1.f, size = 1.f;

    static const struct option lo[] = {
        {"color", 1, 0, 'c'}, {"label-color", 1, 0, 't'}, {"rainbow", 0, 0, 'r'},
        {"speed", 1, 0, 's'}, {"size", 1, 0, 'z'},        {"height", 1, 0, 'H'},
        {"spin", 1, 0, 'S'},  {"frames", 1, 0, 'f'},      {"no-info", 0, 0, 'n'},
        {"no-color", 0, 0, 'N'}, {"pin", 0, 0, 'P'},      {"stop", 0, 0, 'Q'},
        {"help", 0, 0, 'h'},     {0, 0, 0, 0}};
    int o;
    while ((o = getopt_long(argc, argv, "c:t:rs:nh", lo, NULL)) != -1) {
        switch (o) {
        case 'c':
            if (!parse_color(optarg, &key_col)) { fprintf(stderr, "bad color: %s\n", optarg); return 1; }
            if (!lab_set) lab_col = key_col;
            break;
        case 't':
            if (!parse_color(optarg, &lab_col)) { fprintf(stderr, "bad color: %s\n", optarg); return 1; }
            lab_set = 1;
            break;
        case 'r': rainbow = 1; break;
        case 's': speed = (float)atof(optarg); break;
        case 'z': size = (float)atof(optarg); break;
        case 'H': H = atoi(optarg); break;
        case 'S':
            spin_x = strchr(optarg, 'x') != NULL;
            spin_y = strchr(optarg, 'y') != NULL;
            if (!spin_x && !spin_y) { fprintf(stderr, "--spin expects x, y or xy\n"); return 1; }
            break;
        case 'f': max_frames = atoi(optarg); break;
        case 'n': show_info = 0; break;
        case 'N': use_color = 0; break;
        case 'P': pin = 1; break;
        case 'Q': stop_cmd = 1; break;
        default: usage(argv[0]); return o == 'h' ? 0 : 1;
        }
    }

    if (stop_cmd) {
        char pf[128];
        pidfile_path(pf, sizeof pf);
        pin_kill_old(pf);
        static const char s[] = "\0337\033[r\0338";
        if (write(1, s, sizeof s - 1) < 0) {}
        return 0;
    }
    if (pin && !isatty(1)) { fprintf(stderr, "--pin needs a terminal\n"); return 1; }

    struct winsize ws = {0};
    ioctl(1, TIOCGWINSZ, &ws);
    int cols = ws.ws_col ? ws.ws_col : 80, rows = ws.ws_row ? ws.ws_row : 24;
    if (H > rows - 2) H = rows - 2;
    if (pin && H > rows / 2) H = rows / 2;
    if (H < 6) H = 6;
    int W = 2 * H;
    if (W > cols) { W = cols; }
    int avail = cols - W - 3;
    if (avail > 200) avail = 200;
    int want_info = show_info;

    const char *ct = getenv("COLORTERM");
    truecolor = ct && (strstr(ct, "truecolor") || strstr(ct, "24bit"));
    if (!ct) truecolor = 1; /* most modern terminals; set COLORTERM= to force 256 */
    if (ct && !*ct) truecolor = 0;

    build_key();
    if (want_info) { build_info(); update_live(); }
    int maxlab = 0;
    for (int i = 0; i < ninfo; i++)
        if (info[i].kind == L_FIELD && (int)strlen(info[i].label) > maxlab) maxlab = (int)strlen(info[i].label);
    int off = ninfo < H ? (H - ninfo) / 2 : 0;

    /* lighting: top-left, in camera space (camera looks along +z) */
    float L[3] = {-0.45f, 0.65f, -0.75f};
    float ln = sqrtf(L[0] * L[0] + L[1] * L[1] + L[2] * L[2]);
    for (int i = 0; i < 3; i++) L[i] /= ln;
    float Hv[3] = {L[0], L[1], L[2] - 1.f};
    float hn = sqrtf(Hv[0] * Hv[0] + Hv[1] * Hv[1] + Hv[2] * Hv[2]);
    for (int i = 0; i < 3; i++) Hv[i] /= hn;

    const char *ramp = " .,-~:;=!*#$@";
    int nramp = (int)strlen(ramp);

    float *zb = malloc(sizeof(float) * H * W);
    float *dif = malloc(sizeof(float) * H * W);
    float *spc = malloc(sizeof(float) * H * W);
    size_t outcap = (size_t)H * ((size_t)W * 24 + 2048) + 64;
    char *out = malloc(outcap);
    if (!zb || !dif || !spc || !out) { perror("malloc"); return 1; }

    if (pin) {
        char pf[128];
        pidfile_path(pf, sizeof pf);
        pin_kill_old(pf);
        /* clear, reserve H rows at the top (scroll region = the rest), cursor below */
        char seq[64];
        int sn = snprintf(seq, sizeof seq, "\033[2J\033[%d;%dr\033[%d;1H", H + 1, rows, H + 1);
        if (write(1, seq, (size_t)sn) < 0) {}
        pid_t pid = fork();
        if (pid < 0) { perror("fork"); return 1; }
        if (pid > 0) {
            FILE *f = fopen(pf, "w");
            if (f) { fprintf(f, "%d\n", (int)pid); fclose(f); }
            _exit(0); /* shell gets its prompt back right away */
        }
        setsid();
        int dn = open("/dev/null", O_RDWR);
        if (dn >= 0) { dup2(dn, 0); dup2(dn, 2); if (dn > 2) close(dn); }
        pinned = 1;
    }

    struct sigaction sa = {0};
    sa.sa_handler = on_sig;
    sigaction(SIGINT, &sa, NULL);
    sigaction(SIGTERM, &sa, NULL);
    if (isatty(0) && tcgetattr(0, &orig_tio) == 0) {
        have_tio = 1;
        struct termios t = orig_tio;
        t.c_lflag &= ~(ICANON | ECHO);
        t.c_cc[VMIN] = 0;
        t.c_cc[VTIME] = 0;
        tcsetattr(0, TCSANOW, &t);
    }
    atexit(restore_term);
    if (!pin && write(1, "\033[?25l", 6) < 0) {}

    const float D = 4.f;
    const float K = 0.48f * H * (D - 1.f) * size * 1.3f; /* 1.3: key is long & thin, fill the box */
    const float tilt = 0.35f;
    double t0 = now_s(), last_info = t0, last_chk = t0;

    for (int frame = 0; !stop_flag; frame++) {
        double now = now_s(), t = (now - t0) * speed;
        if (now - last_info >= 1.0 && want_info) { update_live(); last_info = now; }
        if (pin && now - last_chk >= 1.0) { /* follow terminal resizes */
            last_chk = now;
            struct winsize w2 = {0};
            if (ioctl(1, TIOCGWINSZ, &w2) == 0 && w2.ws_col &&
                (w2.ws_col != cols || w2.ws_row != rows)) {
                cols = w2.ws_col; rows = w2.ws_row;
                avail = cols - W - 3;
                if (avail > 200) avail = 200;
                char seq[64];
                int sn = snprintf(seq, sizeof seq, "\0337\033[%d;%dr\0338", H + 1, rows);
                if (write(1, seq, (size_t)sn) < 0) break;
            }
        }
        int Wd = W < cols ? W : cols;
        if (rainbow) {
            key_col = hsv((float)(t * 50.0), 0.75f, 1.f);
            if (!lab_set) lab_col = key_col;
        }

        float ay = spin_y ? (float)t * 0.9f : 0.5f;
        float ax = tilt + (spin_x ? (float)t * 0.9f : 0.f);
        float cy_ = cosf(ay), sy_ = sinf(ay), cx_ = cosf(ax), sx_ = sinf(ax);

        for (int i = 0; i < H * W; i++) zb[i] = 1e9f;

        for (int i = 0; i < npts; i++) {
            const Pt *q = &pts[i];
            /* normal first (cheap early-out for back faces) */
            float nx1 = q->nx * cy_ + q->nz * sy_, nz1 = -q->nx * sy_ + q->nz * cy_;
            float ny2 = q->ny * cx_ - nz1 * sx_, nz2 = q->ny * sx_ + nz1 * cx_;
            if (nz2 > 0.05f) continue;
            float x1 = q->x * cy_ + q->z * sy_, z1 = -q->x * sy_ + q->z * cy_;
            float y2 = q->y * cx_ - z1 * sx_, z2 = q->y * sx_ + z1 * cx_;
            float depth = D + z2;
            int ix = (int)floorf(W / 2.f + 2.f * K * x1 / depth);
            int iy = (int)floorf(H / 2.f - K * y2 / depth);
            if (ix < 0 || ix >= W || iy < 0 || iy >= H) continue;
            int c = iy * W + ix;
            if (depth >= zb[c]) continue;
            zb[c] = depth;
            float d = nx1 * L[0] + ny2 * L[1] + nz2 * L[2];
            float s = nx1 * Hv[0] + ny2 * Hv[1] + nz2 * Hv[2];
            dif[c] = d > 0 ? d : 0;
            spc[c] = (d > 0 && s > 0) ? powf(s, 28.f) : 0;
        }

        char *p = out;
        if (pin) p += sprintf(p, "\0337");                      /* save cursor */
        else if (frame > 0) p += sprintf(p, "\033[%dA\r", H);
        for (int r = 0; r < H; r++) {
            RGB last = {-1, -1, -1};
            if (pin) p += sprintf(p, "\033[%d;1H", r + 1);      /* absolute row */
            for (int c = 0; c < Wd; c++) {
                int i = r * W + c;
                if (zb[i] >= 1e8f) { *p++ = ' '; continue; }
                float sh = 0.16f + 0.84f * dif[i], sp = spc[i];
                float lum = sh * 0.85f + sp * 0.45f;
                int idx = clampi(1 + (int)(lum * (nramp - 2)), 1, nramp - 1);
                if (use_color) {
                    RGB col = {clampi((int)(key_col.r * sh + 255 * sp * 0.7f), 0, 255),
                               clampi((int)(key_col.g * sh + 255 * sp * 0.7f), 0, 255),
                               clampi((int)(key_col.b * sh + 255 * sp * 0.7f), 0, 255)};
                    if (col.r != last.r || col.g != last.g || col.b != last.b) {
                        p = put_color(p, col);
                        last = col;
                    }
                }
                *p++ = ramp[idx];
            }
            if (use_color) p += sprintf(p, "\033[0m");
            if (want_info && avail >= 12) {
                int li = r - off;
                if (li >= 0 && li < ninfo) {
                    p += sprintf(p, "   ");
                    p = put_info(p, &info[li], avail, lab_col, maxlab, use_color);
                }
            }
            p += sprintf(p, pin ? "\033[K" : "\033[K\n");
        }
        if (pin) p += sprintf(p, "\0338");                      /* restore cursor */
        if (write(1, out, (size_t)(p - out)) < 0) break;

        if (max_frames && frame + 1 >= max_frames) break;
        if (have_tio && !pin) {
            char ch;
            if (read(0, &ch, 1) > 0) break;
        }
        usleep(33000);
    }
    return 0;
}
