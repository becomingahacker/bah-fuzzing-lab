/*
 * AFL++ harness: Sophos mailscanner MIME Content-Type parser.
 *
 * Loads mailscanner.so (converted from the mailscanner executable via LIEF)
 * and calls mime_content_type_new_from_string with fuzz input.
 *
 * The parser handles Content-Type header values like:
 *   text/html; charset=utf-8; boundary="----=_Part_123"; name="file.txt"
 *
 * Build:  clang -m32 -g -O2 -o harness_ct harness_ct.c -ldl
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dlfcn.h>
#include <unistd.h>

typedef void *(*ct_parse_fn)(const char *, int, int);
typedef void  (*ct_destroy_fn)(void *);

static ct_parse_fn   parse;
static ct_destroy_fn destroy;

static void load_lib(void) {
    if (!dlopen("./stubs.so", RTLD_LAZY | RTLD_GLOBAL)) {
        fprintf(stderr, "dlopen stubs: %s\n", dlerror()); _exit(1);
    }
    void *h = dlopen("./mailscanner.so", RTLD_LAZY);
    if (!h) { fprintf(stderr, "dlopen: %s\n", dlerror()); _exit(1); }

    parse   = (ct_parse_fn)  dlsym(h, "mime_content_type_new_from_string");
    destroy = (ct_destroy_fn)dlsym(h, "mime_content_type_destroy");
    if (!parse || !destroy) {
        fprintf(stderr, "dlsym: %s\n", dlerror()); _exit(1);
    }

    int *log_level = (int *)dlsym(h, "log_level");
    if (log_level) *log_level = 0;
}

int main(int argc, char **argv) {
    if (argc < 2) { fprintf(stderr, "Usage: %s <input>\n", argv[0]); return 1; }

    static int init;
    if (!init) { load_lib(); init = 1; }

    FILE *f = fopen(argv[1], "rb");
    if (!f) return 1;
    fseek(f, 0, SEEK_END);
    long len = ftell(f);
    if (len < 0 || len > 64 * 1024) { fclose(f); return 1; }
    fseek(f, 0, SEEK_SET);
    char *buf = malloc(len + 1);
    if (!buf) { fclose(f); return 1; }
    size_t n = fread(buf, 1, len, f);
    buf[n] = '\0';
    fclose(f);

    void *ct = parse(buf, 0, (int)n);
    if (ct) destroy(ct);

    free(buf);
    return 0;
}
