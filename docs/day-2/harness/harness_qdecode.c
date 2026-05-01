/*
 * AFL++ harness: Sophos mailscanner Qdecode (quoted-printable decoder).
 *
 * Qdecode processes =XX hex escape sequences in MIME quoted-printable text.
 * It malloc's an output buffer of (len+1) bytes and decodes in-place.
 *
 * Known bug: inputs with many consecutive '=' characters cause an integer
 * underflow in the final rep movsb copy length, resulting in a massive
 * heap buffer overflow.
 *
 * Build:  clang -m32 -g -O2 -o harness_qdecode harness_qdecode.c -ldl
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dlfcn.h>
#include <unistd.h>

typedef char *(*qdecode_fn)(const char *, int);

static qdecode_fn decode;

static void load_lib(void) {
    if (!dlopen("./stubs.so", RTLD_LAZY | RTLD_GLOBAL)) {
        fprintf(stderr, "dlopen stubs: %s\n", dlerror()); _exit(1);
    }
    void *h = dlopen("./mailscanner.so", RTLD_LAZY);
    if (!h) { fprintf(stderr, "dlopen: %s\n", dlerror()); _exit(1); }

    decode = (qdecode_fn)dlsym(h, "Qdecode");
    if (!decode) { fprintf(stderr, "dlsym: %s\n", dlerror()); _exit(1); }

    int *log_level = (int *)dlsym(h, "log_level");
    if (log_level) *log_level = 0;
}

int main(int argc, char **argv) {
    if (argc < 2) return 1;
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

    char *decoded = decode(buf, (int)n);
    if (decoded) free(decoded);

    free(buf);
    return 0;
}
