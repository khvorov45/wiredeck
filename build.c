#if PLATFORM_WINDOWS
#else
	#error build only set up for windows
#endif

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

#if PLATFORM_WINDOWS
	#define WIN32_LEAN_AND_MEAN
	#include <windows.h>
	#include <shellapi.h>
#endif

#define false 0
#define true 1

#define arrLen(x) (sizeof(x) / sizeof((x)[0]))

#if PLATFORM_WINDOWS
	#define assert(cond) if (!(cond)) DebugBreak()
#endif

typedef char* cstring;

typedef int32_t b32;
typedef int32_t i32;

typedef enum BuildMode {
	BuildMode_Debug,
} BuildMode;

typedef struct DynCstring {
	cstring buf;
	i32 len;
	i32 cap;
} DynCstring;

i32
cstringLen(cstring str) {
	i32 result = 0;
	while (str[result] != '\0') result++;
	return result;
}

void
dynCStringGrow(DynCstring* dynCString, i32 atLeast) {
	if (dynCString->cap == 0) {
		dynCString->cap = 10;
	}
	i32 by = dynCString->cap;
	if (by < atLeast) {
		by = atLeast;
	}
	dynCString->cap += by + 1; // NOTE(khvorov) Null terminator
	dynCString->buf = realloc(dynCString->buf, dynCString->cap);
	memset(dynCString->buf + dynCString->len, 0, dynCString->cap - dynCString->len);
}

void
dynCStringPush(DynCstring* dynCString, cstring src) {
	assert(dynCString->len <= dynCString->cap);
	i32 free = dynCString->cap - dynCString->len;
	i32 srcLen = cstringLen(src);
	if (free < srcLen) {
		dynCStringGrow(dynCString, srcLen - free);
	}
	assert(dynCString->cap - dynCString->len >= srcLen);
	memcpy(dynCString->buf + dynCString->len, src, srcLen);
	dynCString->len += srcLen;
}

b32
isFile(cstring path) {
	b32 result = false;

	#if PLATFORM_WINDOWS
		DWORD attr = GetFileAttributesA(path);
		if (attr != INVALID_FILE_ATTRIBUTES) {
			result = (attr & FILE_ATTRIBUTE_NORMAL) != 0;
		}
	#endif

	return result;
}

b32
isDir(cstring path) {
	b32 result = false;

	#if PLATFORM_WINDOWS
		DWORD attr = GetFileAttributesA(path);
		if (attr != INVALID_FILE_ATTRIBUTES) {
			result = (attr & FILE_ATTRIBUTE_DIRECTORY) != 0;
		}
	#endif

	return result;
}

cstring
constructCompileCommand(
	cstring outDir, cstring outName, BuildMode buildMode,
	cstring* flags, i32 flagsLen,
	cstring* sources, i32 sourcesLen
) {
	DynCstring result = {0};

	#if PLATFORM_WINDOWS
		dynCStringPush(&result, "cl /nologo ");
	#endif

	for (i32 flagIndex = 0; flagIndex < flagsLen; flagIndex++) {
		dynCStringPush(&result, flags[flagIndex]);
		dynCStringPush(&result, " ");
	}

	#if PLATFORM_WINDOWS
		cstring debugFlags = "/Zi ";
	#endif

	switch (buildMode) {
	case BuildMode_Debug: dynCStringPush(&result, debugFlags); break;
	}

	#if PLATFORM_WINDOWS
		dynCStringPush(&result, "/Fo");
		dynCStringPush(&result, outDir);
		dynCStringPush(&result, "/");
		dynCStringPush(&result, outName);
		dynCStringPush(&result, "/ ");

		dynCStringPush(&result, "/Fd");
		dynCStringPush(&result, outDir);
		dynCStringPush(&result, "/");
		dynCStringPush(&result, outName);
		dynCStringPush(&result, ".pdb ");

		dynCStringPush(&result, "/Fe");
		dynCStringPush(&result, outDir);
		dynCStringPush(&result, "/");
		dynCStringPush(&result, outName);
		dynCStringPush(&result, ".exe ");
	#endif

	for (i32 srcIndex = 0; srcIndex < sourcesLen; srcIndex++) {
		dynCStringPush(&result, sources[srcIndex]);
		dynCStringPush(&result, " ");
	}

	return result.buf;
}

void
createDir(cstring path) {
	#if PLATFORM_WINDOWS
		CreateDirectory(path, 0);
	#endif
}

void
clearDir(cstring path) {
	#if PLATFORM_WINDOWS
		i32 pathLen = cstringLen(path);
		cstring pathDoubleNull = calloc(pathLen + 2, 1);
		memcpy(pathDoubleNull, path, pathLen);

		SHFILEOPSTRUCTA fileop = {0};
		fileop.wFunc = FO_DELETE;
		fileop.pFrom = pathDoubleNull;
		fileop.fFlags = FOF_NO_UI;
		SHFileOperationA(&fileop);

		free(pathDoubleNull);
	#endif

	createDir(path);
}

int
main() {
	BuildMode buildMode = BuildMode_Debug;

	cstring outDir = "build";
	switch (buildMode) {
	case BuildMode_Debug: outDir = "build-debug"; break;
	}
	clearDir(outDir);

	char strBuf[64] = {0};

	cstring sdlOutName = "SDL";
	sprintf(strBuf, "%s/%s", outDir, sdlOutName);
	createDir(strBuf);

	cstring sdlSources[] = {
		"code/SDL/src/atomic/*.c",
		"code/SDL/src/thread/*.c",
		"code/SDL/src/thread/generic/*.c",
		"code/SDL/src/events/*.c",
		"code/SDL/src/file/*.c",
		"code/SDL/src/stdlib/*.c",
		"code/SDL/src/libm/*.c",
		"code/SDL/src/timer/*.c",
		"code/SDL/src/video/*.c",
		"code/SDL/src/video/yuv2rgb/*.c",
		"code/SDL/src/render/*.c",
		"code/SDL/src/render/software/*.c",
		"code/SDL/src/cpuinfo/*.c",
		"code/SDL/src/*.c",
		#if PLATFORM_WINDOWS
			"code/SDL/src/core/windows/*.c",
			"code/SDL/src/timer/windows/*.c",
			"code/SDL/src/video/windows/*.c",
			"code/SDL/src/loadso/windows/*.c",
		#endif
	};

	cstring sdlFlags[] = {
		"-c",
		"-Icode/SDL/include"
		"-DSDL_AUDIO_DISABLED",
	 	"-DSDL_HAPTIC_DISABLED",
	 	"-DSDL_HIDAPI_DISABLED",
	 	"-DSDL_SENSOR_DISABLED",
	 	"-DSDL_THREADS_DISABLED",
	 	"-DSDL_TIMERS_DISABLED",
	 	"-DSDL_JOYSTICK_DISABLED",
	};

	cstring sdlCompileCmd = constructCompileCommand(
		outDir, sdlOutName, buildMode, sdlFlags, arrLen(sdlFlags), sdlSources, arrLen(sdlSources)
	);

	printf("SDL compile command:\n%s\n", sdlCompileCmd);

	return 0;
}
