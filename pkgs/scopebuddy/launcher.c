/*
 * Statically linked entry point for ScopeBuddy.
 *
 * Steam injects gameoverlayrenderer.so (steamrt64/steamrt32) through
 * LD_PRELOAD. That library needs libGL.so.1, which is not on the default
 * loader path on NixOS. With the preload present, the dynamic loader aborts
 * every dynamically linked program started from that environment, including
 * the bash interpreter named in a script's shebang. A script cannot repair
 * this because the failure happens before its first line runs, so this
 * launcher is a static ELF (the loader never processes LD_PRELOAD for it),
 * and it runs before any dynamic program.
 *
 * Only when LD_PRELOAD names gameoverlayrenderer.so does it prepend the
 * libGL.so.1 paths (64-bit and 32-bit, supplied at build time) that are not
 * already present. The 64-bit libGL is loaded by 64-bit processes and the
 * 32-bit one by 32-bit processes; the loader skips the wrong class with an
 * ignored-preload message. Other environments are passed through unchanged.
 *
 * Compile-time definitions (see default.nix):
 *   SCB_BASH        absolute path of bash
 *   SCB_LIBGL64     absolute path of the 64-bit libGL.so.1
 *   SCB_LIBGL32     absolute path of the 32-bit libGL.so.1
 *   SCB_SCRIPT_REL  script path relative to this executable's directory
 */

#define _GNU_SOURCE
#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define OVERLAY_MARKER "gameoverlayrenderer.so"

static const char *const libgl_paths[] = {SCB_LIBGL64, SCB_LIBGL32};
#define LIBGL_COUNT (sizeof(libgl_paths) / sizeof(libgl_paths[0]))

/* Build the new LD_PRELOAD into a freshly allocated string; NULL on failure. */
static char *build_preload(const char *current) {
	size_t len = strlen(current) + 1;
	for (size_t i = 0; i < LIBGL_COUNT; i++) {
		if (!strstr(current, libgl_paths[i]))
			len += strlen(libgl_paths[i]) + 1;
	}
	char *out = malloc(len);
	if (!out)
		return NULL;
	out[0] = '\0';
	for (size_t i = 0; i < LIBGL_COUNT; i++) {
		if (!strstr(current, libgl_paths[i])) {
			strcat(out, libgl_paths[i]);
			strcat(out, ":");
		}
	}
	strcat(out, current);
	return out;
}

/* Resolve <dir of this executable>/<SCB_SCRIPT_REL> without embedding the
 * output path in the binary (that would make the package self-referential). */
static int script_path(char *buf, size_t size) {
	char self[PATH_MAX];
	ssize_t n = readlink("/proc/self/exe", self, sizeof(self) - 1);
	if (n < 0)
		return -1;
	self[n] = '\0';
	char *slash = strrchr(self, '/');
	if (!slash)
		return -1;
	*slash = '\0';
	int written = snprintf(buf, size, "%s/%s", self, SCB_SCRIPT_REL);
	return (written < 0 || (size_t)written >= size) ? -1 : 0;
}

int main(int argc, char **argv) {
	const char *preload = getenv("LD_PRELOAD");
	if (preload && strstr(preload, OVERLAY_MARKER)) {
		char *updated = build_preload(preload);
		if (!updated) {
			fprintf(stderr, "scopebuddy: out of memory\n");
			return 127;
		}
		if (setenv("LD_PRELOAD", updated, 1) != 0) {
			fprintf(stderr, "scopebuddy: setenv: %s\n", strerror(errno));
			return 127;
		}
		free(updated);
	}

	char script[PATH_MAX];
	if (script_path(script, sizeof(script)) != 0) {
		fprintf(stderr, "scopebuddy: cannot locate script\n");
		return 127;
	}

	char **nargv = calloc((size_t)argc + 2, sizeof(char *));
	if (!nargv) {
		fprintf(stderr, "scopebuddy: out of memory\n");
		return 127;
	}
	nargv[0] = (char *)SCB_BASH;
	nargv[1] = script;
	for (int i = 1; i < argc; i++)
		nargv[i + 1] = argv[i];
	nargv[argc + 1] = NULL;

	execv(SCB_BASH, nargv);
	fprintf(stderr, "scopebuddy: exec %s: %s\n", SCB_BASH, strerror(errno));
	return 127;
}
