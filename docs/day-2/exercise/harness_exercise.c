/*
 * Exercise: Fuzz the Sophos mailscanner Content-Disposition parser.
 *
 * mime_disposition_new() parses headers like:
 *   attachment; filename="document.pdf"
 *   inline; filename="image.png"
 *
 * TODO: Fill in the marked sections below, then compile and fuzz.
 *
 * Compile: clang -m32 -g -O2 -o harness_exercise harness_exercise.c -ldl
 * Fuzz:    ./run_fuzz_exercise.sh
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dlfcn.h>
#include <unistd.h>

/*
 * TODO 1: Define the function pointer types.
 * mime_disposition_new takes (const char*, int, int) and returns void*.
 * mime_disposition_destroy takes (void*) and returns void.
 */
typedef void *(*disp_parse_fn)(/* TODO */);
typedef void  (*disp_destroy_fn)(/* TODO */);

static disp_parse_fn   parse;
static disp_destroy_fn destroy;

static void load_lib(void) {
    if (!dlopen("./stubs.so", RTLD_LAZY | RTLD_GLOBAL)) {
        fprintf(stderr, "dlopen stubs: %s\n", dlerror()); _exit(1);
    }
    void *h = dlopen("./mailscanner.so", RTLD_LAZY);
    if (!h) { fprintf(stderr, "dlopen: %s\n", dlerror()); _exit(1); }

    /*
     * TODO 2: Look up the parse and destroy functions with dlsym.
     * Find the symbol names with: nm -D mailscanner.so | grep mime_disposition
     */
    parse   = (disp_parse_fn)  dlsym(h, "TODO_PARSE_SYMBOL");
    destroy = (disp_destroy_fn) dlsym(h, "TODO_DESTROY_SYMBOL");
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

    /*
     * TODO 3: Call the parse function.
     * Same argument pattern as mime_content_type_new_from_string:
     *   (string, flags, length)
     */
    void *disp = /* TODO: call parse() here */;

    /*
     * TODO 4: Destroy the result if non-NULL.
     */
    /* TODO 5: if disp is non-NULL, call destroy() on it */

    free(buf);
    return 0;
}
