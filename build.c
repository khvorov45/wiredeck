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

typedef struct Builder {
	BuildMode mode;
	cstring outDir;
} Builder;

typedef struct Step {
	cstring name;
	BuildKind kind;
	cstring* sources;
	i32 sourcesLen;
	cstring* flags;
	i32 flagsLen;
	cstring* link;
	i32 linkLen;
} Step;

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

CompileCmd
constructCompileCommand(Builder builder, Step step) {

	DynCstring cmdBuilder = {0};

	#if PLATFORM_WINDOWS
		dynCStringPush(&cmdBuilder, "cl /nologo /diagnostics:column ");
	#endif

	if (step.kind == BuildKind_Lib) {
		dynCStringPush(&cmdBuilder, "-c ");
	}

	for (i32 flagIndex = 0; flagIndex < step.flagsLen; flagIndex++) {
		dynCStringPush(&cmdBuilder, step.flags[flagIndex]);
		dynCStringPush(&cmdBuilder, " ");
	}

	#if PLATFORM_WINDOWS
		cstring debugFlags = "/Zi ";
	#endif

	switch (builder.mode) {
	case BuildMode_Debug: dynCStringPush(&cmdBuilder, debugFlags); break;
	}

	#if PLATFORM_WINDOWS
		dynCStringPush(&cmdBuilder, "/Fo");
		dynCStringPush(&cmdBuilder, builder.outDir);
		dynCStringPush(&cmdBuilder, "/");
		dynCStringPush(&cmdBuilder, step.name);
		dynCStringPush(&cmdBuilder, "/ ");

		dynCStringPush(&cmdBuilder, "/Fd");

		dynCStringMark(&cmdBuilder);
		dynCStringPush(&cmdBuilder, builder.outDir);
		dynCStringPush(&cmdBuilder, "/");
		dynCStringPush(&cmdBuilder, step.name);
		cstring objDir = dynCStringCloneCstringFromMarker(&cmdBuilder);

		dynCStringPush(&cmdBuilder, ".pdb ");

		dynCStringPush(&cmdBuilder, "/Fe");

		dynCStringMark(&cmdBuilder);
		dynCStringPush(&cmdBuilder, builder.outDir);
		dynCStringPush(&cmdBuilder, "/");
		dynCStringPush(&cmdBuilder, step.name);
		dynCStringPush(&cmdBuilder, ".exe");
		cstring outPath = dynCStringCloneCstringFromMarker(&cmdBuilder);

		dynCStringPush(&cmdBuilder, " ");
	#endif

	for (i32 srcIndex = 0; srcIndex < step.sourcesLen; srcIndex++) {
		dynCStringPush(&cmdBuilder, step.sources[srcIndex]);
		dynCStringPush(&cmdBuilder, " ");
	}

	cstring libCmd = 0;

	if (step.kind == BuildKind_Lib) {
		DynCstring libCmdBuilder = {0};

		dynCStringMark(&libCmdBuilder);

		#if PLATFORM_WINDOWS
			dynCStringPush(&libCmdBuilder, "lib /nologo ");
			dynCStringPush(&libCmdBuilder, objDir);
			dynCStringPush(&libCmdBuilder, "/*.obj -out:");

			dynCStringMark(&libCmdBuilder);
			dynCStringPush(&libCmdBuilder, builder.outDir);
			dynCStringPush(&libCmdBuilder, "/");
			dynCStringPush(&libCmdBuilder, step.name);
			dynCStringPush(&libCmdBuilder, ".lib");
			outPath = dynCStringCloneCstringFromMarker(&libCmdBuilder);
		#endif

		libCmd = dynCStringCloneCstringFromMarker(&libCmdBuilder);
	}

	if (step.kind == BuildKind_Exe) {

		if (step.linkLen > 0) {
			#if PLATFORM_WINDOWS
				dynCStringPush(&cmdBuilder, "/link /incremental:no /subsystem:windows ");
			#endif
		}

		for (i32 linkIndex = 0; linkIndex < step.linkLen; linkIndex++) {
			cstring thisLink = step.link[linkIndex];
			#if PLATFORM_WINDOWS
				dynCStringPush(&cmdBuilder, thisLink);
				dynCStringPush(&cmdBuilder, " ");
			#endif
		}
	}

	CompileCmd result = {
		.name = step.name,
		.cmd = cmdBuilder.buf,
		.outPath = outPath,
		.libCmd = libCmd,
		.objDir = objDir,
	};
	return result;
}

void
createDirIfNotExists(cstring path) {
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

	createDirIfNotExists(path);
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

Builder
newBuilder(BuildMode mode) {
	char* outDirs[BuildMode_Len] = {0};
	outDirs[BuildMode_Debug] = "build-debug";
	char* outDir = outDirs[mode];

	u64 buildFileTime = getLastModified(__FILE__);
	u64 outDirCreateTime = getLastModified(outDir);

	if (buildFileTime > outDirCreateTime) {
		clearDir(outDir);
	}

	Builder result = {.mode = mode, .outDir = outDir};
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

CompileCmd
execStep(Builder builder, Step step) {
	CompileCmd cmd = constructCompileCommand(builder, step);

	u64 outTime = getLastModified(cmd.outPath);
	u64 inTime = getLastModifiedSource(step.sources, step.sourcesLen);
	u64 depTime = getLastModifiedSource(step.link, step.linkLen);

	if (inTime > outTime || depTime > outTime) {
		createDirIfNotExists(builder.outDir);
		clearDir(cmd.objDir);
		cmdRunLog(&cmd);
		cmdRun(&cmd);
	} else {
		cmdNoRunLog(&cmd);
	}

	return cmd;
}

int
main() {
	Builder builder = newBuilder(BuildMode_Debug);

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
			"code/SDL/src/main/windows/*.c",
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

	Step sdlStep = {
		.name = "SDL",
		.kind = BuildKind_Lib,
		.sources = sdlSources,
		.sourcesLen = arrLen(sdlSources),
		.flags = sdlFlags,
		.flagsLen = arrLen(sdlFlags),
		.link = 0,
		.linkLen = 0,
	};

	CompileCmd sdlCmd = execStep(builder, sdlStep);

	// TODO(khvorov) Check if #inlcude files changed in any of the sources
	cstring wiredeckSources[] = {"code/wiredeck.c"};

	#if PLATFORM_WINDOWS
		cstring wiredeckFlags[] = {"/W2"};
	#endif

	cstring wiredeckLink[] = {
		sdlCmd.outPath,
		#if PLATFORM_WINDOWS
		"Ole32.lib", "Advapi32.lib", "Winmm.lib", "User32.lib", "Gdi32.lib",
		"OleAut32.lib", "Imm32.lib", "Shell32.lib", "Version.lib",
		#endif
	};

	Step wiredeckStep = {
		.name = "wiredeck",
		.kind = BuildKind_Exe,
		.sources = wiredeckSources,
		.sourcesLen = arrLen(wiredeckSources),
		.flags = wiredeckFlags,
		.flagsLen = arrLen(wiredeckFlags),
		.link = wiredeckLink,
		.linkLen = arrLen(wiredeckLink),
	};

	execStep(builder, wiredeckStep);

	return 0;
}
