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
typedef uint64_t u64;

typedef enum BuildMode {
	BuildMode_Debug,
	BuildMode_Len,
} BuildMode;

typedef enum BuildKind {
	BuildKind_Lib,
	BuildKind_Exe,
} BuildKind;

typedef struct DynCstring {
	cstring buf;
	i32 len;
	i32 cap;
	i32 markers[4];
	i32 markersLen;
} DynCstring;

typedef struct CompileCmd {
	cstring name;
	cstring cmd;
	cstring outPath;
	cstring libCmd;
	cstring objDir;
} CompileCmd;

i32
cstringLen(cstring str) {
	i32 result = 0;
	while (str[result] != '\0') result++;
	return result;
}

cstring
cstringFrom(cstring str, i32 strLen) {
	cstring result = calloc(strLen + 1, 1);
	memcpy(result, str, strLen);
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

void
dynCStringMark(DynCstring* dynCString) {
	assert(dynCString->markersLen < arrLen(dynCString->markers));
	dynCString->markers[dynCString->markersLen++] = dynCString->len;
}

cstring
dynCStringCloneCstringFromMarker(DynCstring* dynCString) {
	assert(dynCString->markersLen > 0);
	i32 marker = dynCString->markers[--dynCString->markersLen];
	cstring result = cstringFrom(dynCString->buf + marker, dynCString->len - marker);
	return result;
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

CompileCmd
constructCompileCommand(
	cstring outDir, cstring outName, BuildMode buildMode, BuildKind buildKind,
	cstring* flags, i32 flagsLen,
	cstring* sources, i32 sourcesLen
) {
	DynCstring cmdBuilder = {0};

	#if PLATFORM_WINDOWS
		dynCStringPush(&cmdBuilder, "cl /nologo ");
	#endif

	if (buildKind == BuildKind_Lib) {
		dynCStringPush(&cmdBuilder, "-c ");
	}

	for (i32 flagIndex = 0; flagIndex < flagsLen; flagIndex++) {
		dynCStringPush(&cmdBuilder, flags[flagIndex]);
		dynCStringPush(&cmdBuilder, " ");
	}

	#if PLATFORM_WINDOWS
		cstring debugFlags = "/Zi ";
	#endif

	switch (buildMode) {
	case BuildMode_Debug: dynCStringPush(&cmdBuilder, debugFlags); break;
	}

	#if PLATFORM_WINDOWS
		dynCStringPush(&cmdBuilder, "/Fo");
		dynCStringPush(&cmdBuilder, outDir);
		dynCStringPush(&cmdBuilder, "/");
		dynCStringPush(&cmdBuilder, outName);
		dynCStringPush(&cmdBuilder, "/ ");

		dynCStringPush(&cmdBuilder, "/Fd");

		dynCStringMark(&cmdBuilder);
		dynCStringPush(&cmdBuilder, outDir);
		dynCStringPush(&cmdBuilder, "/");
		dynCStringPush(&cmdBuilder, outName);
		cstring objDir = dynCStringCloneCstringFromMarker(&cmdBuilder);

		dynCStringPush(&cmdBuilder, ".pdb ");

		dynCStringPush(&cmdBuilder, "/Fe");

		dynCStringMark(&cmdBuilder);
		dynCStringPush(&cmdBuilder, outDir);
		dynCStringPush(&cmdBuilder, "/");
		dynCStringPush(&cmdBuilder, outName);
		dynCStringPush(&cmdBuilder, ".exe");
		cstring outPath = dynCStringCloneCstringFromMarker(&cmdBuilder);

		dynCStringPush(&cmdBuilder, " ");
	#endif

	for (i32 srcIndex = 0; srcIndex < sourcesLen; srcIndex++) {
		dynCStringPush(&cmdBuilder, sources[srcIndex]);
		dynCStringPush(&cmdBuilder, " ");
	}

	cstring libCmd = 0;

	if (buildKind == BuildKind_Lib) {
		DynCstring libCmdBuilder = {0};

		dynCStringMark(&libCmdBuilder);

		#if PLATFORM_WINDOWS
			dynCStringPush(&libCmdBuilder, "lib /nologo ");
			dynCStringPush(&libCmdBuilder, objDir);
			dynCStringPush(&libCmdBuilder, "/*.obj -out:");

			dynCStringMark(&libCmdBuilder);
			dynCStringPush(&libCmdBuilder, outDir);
			dynCStringPush(&libCmdBuilder, "/");
			dynCStringPush(&libCmdBuilder, outName);
			dynCStringPush(&libCmdBuilder, ".lib");
			outPath = dynCStringCloneCstringFromMarker(&libCmdBuilder);
		#endif

		libCmd = dynCStringCloneCstringFromMarker(&libCmdBuilder);
	}

	CompileCmd result = {
		.name = outName,
		.cmd = cmdBuilder.buf,
		.outPath = outPath,
		.libCmd = libCmd,
		.objDir = objDir,
	};
	return result;
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

void
cmdRunLog(CompileCmd* cmd) {
	printf("RUN %s; objDir: '%s'; out: '%s'\n", cmd->name, cmd->objDir, cmd->outPath);
}

void
cmdNoRunLog(CompileCmd* cmd) {
	printf("SKIP %s\n", cmd->name);
}

u64
getLastModified(cstring path) {
	u64 result = 0;

	#if PLATFORM_WINDOWS
		WIN32_FIND_DATAA findData;
		HANDLE firstHandle = FindFirstFileA(path, &findData);
		if (firstHandle != INVALID_HANDLE_VALUE) {

			u64 thisLastMod = ((u64)findData.ftLastWriteTime.dwHighDateTime << 32) | findData.ftLastWriteTime.dwLowDateTime;
			result = max(result, thisLastMod);
			while (FindNextFileA(firstHandle, &findData)) {
				thisLastMod = ((u64)findData.ftLastWriteTime.dwHighDateTime << 32) | findData.ftLastWriteTime.dwLowDateTime;
				result = max(result, thisLastMod);
			}
			FindClose(firstHandle);
		}
	#endif

	return result;
}

u64
getLastModifiedSource(cstring* sources, i32 sourcesLen) {
	u64 result = 0;
	for (i32 srcIndex = 0; srcIndex < sourcesLen; srcIndex++) {
		cstring src = sources[srcIndex];
		u64 thisLastMod = getLastModified(src);
		result = max(result, thisLastMod);
	}
	return result;
}

void
execShellCmd(cstring cmd) {
	#if PLATFORM_WINDOWS
		STARTUPINFOA startupInfo = {0};
		startupInfo.cb = sizeof(STARTUPINFOA);

		PROCESS_INFORMATION processInfo;
		if (CreateProcessA(0, cmd, 0, 0, 0, 0, 0, 0, &startupInfo, &processInfo) == 0) {
			printf("ERR: failed to run\n%s\n", cmd);
		} else {
			printf("OK: run\n%s\n", cmd);
			WaitForSingleObject(processInfo.hProcess, INFINITE);
		}
	#endif
}

void
cmdRun(CompileCmd* cmd) {
	execShellCmd(cmd->cmd);
	if (cmd->libCmd) {
		execShellCmd(cmd->libCmd);
	}
}

int
main() {
	BuildMode buildMode = BuildMode_Debug;

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
		"-Icode/SDL/include",
		"-DSDL_AUDIO_DISABLED",
	 	"-DSDL_HAPTIC_DISABLED",
	 	"-DSDL_HIDAPI_DISABLED",
	 	"-DSDL_SENSOR_DISABLED",
	 	"-DSDL_THREADS_DISABLED",
	 	"-DSDL_TIMERS_DISABLED",
	 	"-DSDL_JOYSTICK_DISABLED",
	};

	char* outDirs[BuildMode_Len] = {0};
	outDirs[BuildMode_Debug] = "build-debug";

	char* outDir = outDirs[buildMode];

	CompileCmd sdlCompileCmd = constructCompileCommand(
		outDir, "SDL", buildMode, BuildKind_Lib, sdlFlags, arrLen(sdlFlags), sdlSources, arrLen(sdlSources)
	);

	u64 sdlOutTime = getLastModified(sdlCompileCmd.outPath);
	u64 sdlInTime = getLastModifiedSource(sdlSources, arrLen(sdlSources));

	if (sdlInTime > sdlOutTime) {
		clearDir(sdlCompileCmd.objDir);
		cmdRunLog(&sdlCompileCmd);
		cmdRun(&sdlCompileCmd);
	} else {
		cmdNoRunLog(&sdlCompileCmd);
	}

	return 0;
}
