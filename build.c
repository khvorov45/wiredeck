#if PLATFORM_WINDOWS
#else
	#error build only set up for windows
#endif

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
	#define assert(cond) do {if (!(cond)) {DebugBreak(); ExitProcess(1);}} while(0)
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
	cstring pdbPath;
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
	cstring* extraWatch;
	i32 extraWatchLen;
} Step;

i32
cstringLen(cstring str) {
	i32 result = 0;
	while (str[result] != '\0') result++;
	return result;
}

#if PLATFORM_WINDOWS

void*
allocZero(i32 size) {
	HANDLE heap = GetProcessHeap();
	void* result = HeapAlloc(heap, HEAP_ZERO_MEMORY, size);
	assert(result);
	return result;
}

void*
reallocZeroExtra(void* ptr, i32 newSize) {
	HANDLE heap = GetProcessHeap();

	void* result = 0;
	if (ptr) {
		result = HeapReAlloc(heap, HEAP_ZERO_MEMORY, ptr, newSize);
	} else {
		result = allocZero(newSize);
	}

	assert(result);
	return result;
}

void
freeMemory(void* ptr) {
	HANDLE heap = GetProcessHeap();
	HeapFree(heap, 0, ptr);
}

void
copyMemory(void* dest, void* source, i32 size) {
	CopyMemory(dest, source, size);
}

void
removeFileIfExists(cstring path) {
	if (path) {
		DeleteFileA(path);
	}
}

void
createDirIfNotExists(cstring path) {
	CreateDirectory(path, 0);
}

void
clearDir(cstring path) {
	i32 pathLen = cstringLen(path);
	cstring pathDoubleNull = allocZero(pathLen + 2);
	copyMemory(pathDoubleNull, path, pathLen);

	SHFILEOPSTRUCTA fileop = {0};
	fileop.wFunc = FO_DELETE;
	fileop.pFrom = pathDoubleNull;
	fileop.fFlags = FOF_NO_UI;
	SHFileOperationA(&fileop);

	freeMemory(pathDoubleNull);

	createDirIfNotExists(path);
}

u64
getLastModifiedFromPattern(cstring pattern) {
	u64 result = 0;

	WIN32_FIND_DATAA findData;
	HANDLE firstHandle = FindFirstFileA(pattern, &findData);
	if (firstHandle != INVALID_HANDLE_VALUE) {

		u64 thisLastMod = ((u64)findData.ftLastWriteTime.dwHighDateTime << 32) | findData.ftLastWriteTime.dwLowDateTime;
		result = max(result, thisLastMod);
		while (FindNextFileA(firstHandle, &findData)) {
			thisLastMod = ((u64)findData.ftLastWriteTime.dwHighDateTime << 32) | findData.ftLastWriteTime.dwLowDateTime;
			result = max(result, thisLastMod);
		}
		FindClose(firstHandle);
	}

	return result;
}

void
logMessage(i32 argCount, ...) {
	HANDLE out = GetStdHandle(STD_OUTPUT_HANDLE);

	va_list list;
	va_start(list, argCount);

	for (i32 argIndex = 0; argIndex < argCount; argIndex++) {
		cstring str = va_arg(list, cstring);
		i32 len = cstringLen(str);
		WriteFile(out, str, len, 0, 0);
	}

	va_end(list);
}

void
execShellCmd(cstring cmd) {
	STARTUPINFOA startupInfo = {0};
	startupInfo.cb = sizeof(STARTUPINFOA);

	PROCESS_INFORMATION processInfo;
	if (CreateProcessA(0, cmd, 0, 0, 0, 0, 0, 0, &startupInfo, &processInfo)) {
		WaitForSingleObject(processInfo.hProcess, INFINITE);
	}
}

#endif

cstring
cstringFrom(cstring str, i32 strLen) {
	cstring result = allocZero(strLen + 1);
	copyMemory(result, str, strLen);
	return result;
}

void
dcsGrow(DynCstring* dcs, i32 atLeast) {
	if (dcs->cap == 0) {
		dcs->cap = 10;
	}
	i32 by = dcs->cap;
	if (by < atLeast) {
		by = atLeast;
	}
	dcs->cap += by + 1; // NOTE(khvorov) Null terminator
	dcs->buf = reallocZeroExtra(dcs->buf, dcs->cap);
}

void
dcsPush(DynCstring* dcs, i32 count, ...) {

	va_list list;
	va_start(list, count);

	for (i32 argIndex = 0; argIndex < count; argIndex++) {
		cstring src = va_arg(list, cstring);

		assert(dcs->len <= dcs->cap);
		i32 free = dcs->cap - dcs->len;
		i32 srcLen = cstringLen(src);
		if (free < srcLen) {
			dcsGrow(dcs, srcLen - free);
		}
		assert(dcs->cap - dcs->len >= srcLen);
		copyMemory(dcs->buf + dcs->len, src, srcLen);
		dcs->len += srcLen;
	}

	va_end(list);
}

void
dcsMark(DynCstring* dcs) {
	assert(dcs->markersLen < arrLen(dcs->markers));
	dcs->markers[dcs->markersLen++] = dcs->len;
}

cstring
dcsCloneCstringFromMarker(DynCstring* dcs) {
	assert(dcs->markersLen > 0);
	i32 marker = dcs->markers[--dcs->markersLen];
	cstring result = cstringFrom(dcs->buf + marker, dcs->len - marker);
	return result;
}

#if PLATFORM_WINDOWS

CompileCmd
constructCompileCommand(Builder builder, Step step) {

	DynCstring cmdBuilder = {0};

	dcsPush(&cmdBuilder, 1, "cl /nologo /diagnostics:column ");

	if (step.kind == BuildKind_Lib) {
		dcsPush(&cmdBuilder, 1, "-c ");
	}

	for (i32 flagIndex = 0; flagIndex < step.flagsLen; flagIndex++) {
		dcsPush(&cmdBuilder, 2, step.flags[flagIndex], " ");
	}

	switch (builder.mode) {
	case BuildMode_Debug: dcsPush(&cmdBuilder, 1, "/Zi "); break;
	}

	// NOTE(khvorov) obj output
	dcsPush(&cmdBuilder, 1, "/Fo");
	dcsMark(&cmdBuilder);
	dcsPush(&cmdBuilder, 3, builder.outDir, "/", step.name);
	cstring objDir = dcsCloneCstringFromMarker(&cmdBuilder);
	dcsPush(&cmdBuilder, 1, "/ ");

	// NOTE(khvorov) pdb output
	dcsPush(&cmdBuilder, 1, "/Fd");
	dcsMark(&cmdBuilder);
	dcsPush(&cmdBuilder, 4, builder.outDir, "/", step.name, ".pdb");
	cstring pdbPath = dcsCloneCstringFromMarker(&cmdBuilder);
	dcsPush(&cmdBuilder, 1, " ");

	// NOTE(khvorov) exe output
	dcsPush(&cmdBuilder, 1, "/Fe");
	dcsMark(&cmdBuilder);
	dcsPush(&cmdBuilder, 4, builder.outDir, "/", step.name, ".exe");
	cstring outPath = dcsCloneCstringFromMarker(&cmdBuilder);
	dcsPush(&cmdBuilder, 1, " ");

	for (i32 srcIndex = 0; srcIndex < step.sourcesLen; srcIndex++) {
		dcsPush(&cmdBuilder, 2, step.sources[srcIndex], " ");
	}

	cstring libCmd = 0;

	if (step.kind == BuildKind_Lib) {
		DynCstring libCmdBuilder = {0};

		dcsMark(&libCmdBuilder);

		dcsPush(&libCmdBuilder, 3, "lib /nologo ", objDir, "/*.obj -out:");

		dcsMark(&libCmdBuilder);
		dcsPush(&libCmdBuilder, 4, builder.outDir, "/", step.name, ".lib");
		outPath = dcsCloneCstringFromMarker(&libCmdBuilder);

		libCmd = dcsCloneCstringFromMarker(&libCmdBuilder);
	}

	if (step.kind == BuildKind_Exe) {

		if (step.linkLen > 0) {
			dcsPush(&cmdBuilder, 1, "/link /incremental:no /subsystem:windows ");
		}

		for (i32 linkIndex = 0; linkIndex < step.linkLen; linkIndex++) {
			cstring thisLink = step.link[linkIndex];
			dcsPush(&cmdBuilder, 2, thisLink, " ");
		}
	}

	CompileCmd result = {
		.name = step.name,
		.cmd = cmdBuilder.buf,
		.outPath = outPath,
		.libCmd = libCmd,
		.objDir = objDir,
		.pdbPath = pdbPath,
	};
	return result;
}

#endif

u64
getLastModifiedFromPatterns(cstring* patterns, i32 patternsLen) {
	u64 result = 0;
	for (i32 patIndex = 0; patIndex < patternsLen; patIndex++) {
		cstring pattern = patterns[patIndex];
		u64 thisLastMod = getLastModifiedFromPattern(pattern);
		result = max(result, thisLastMod);
	}
	return result;
}

Builder
newBuilder(BuildMode mode) {
	char* outDirs[BuildMode_Len] = {0};
	outDirs[BuildMode_Debug] = "build-debug";
	char* outDir = outDirs[mode];

	u64 buildFileTime = getLastModifiedFromPattern(__FILE__);
	u64 outDirCreateTime = getLastModifiedFromPattern(outDir);

	if (buildFileTime > outDirCreateTime) {
		clearDir(outDir);
	}

	Builder result = {.mode = mode, .outDir = outDir};
	return result;
}

void
cmdRun(CompileCmd* cmd) {
	logMessage(5, "RUN: ", cmd->name, "\n", cmd->cmd, "\n\n");
	execShellCmd(cmd->cmd);
	if (cmd->libCmd) {
		logMessage(5, "\nRUN: ", cmd->name, " LIB\n", cmd->libCmd, "\n\n");
		execShellCmd(cmd->libCmd);
	}
}

CompileCmd
execStep(Builder builder, Step step) {
	CompileCmd cmd = constructCompileCommand(builder, step);

	u64 outTime = getLastModifiedFromPattern(cmd.outPath);
	u64 inTime = getLastModifiedFromPatterns(step.sources, step.sourcesLen);
	u64 depTime = getLastModifiedFromPatterns(step.link, step.linkLen);
	u64 extraTime = getLastModifiedFromPatterns(step.extraWatch, step.extraWatchLen);

	if (inTime > outTime || depTime > outTime || extraTime > outTime) {
		createDirIfNotExists(builder.outDir);
		clearDir(cmd.objDir);
		removeFileIfExists(cmd.outPath);
		removeFileIfExists(cmd.pdbPath);
		cmdRun(&cmd);
	} else {
		logMessage(3, "SKIP: ", cmd.name, "\n");
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
		"code/SDL/src/timer/*.c",
		"code/SDL/src/thread/*.c",
		"code/SDL/src/*.c",
		#if PLATFORM_WINDOWS
			"code/SDL/src/core/windows/*.c",
			"code/SDL/src/timer/windows/*.c",
			"code/SDL/src/video/windows/*.c",
			"code/SDL/src/loadso/windows/*.c",
			"code/SDL/src/main/windows/*.c",
			"code/SDL/src/timer/windows/*.c",
			"code/SDL/src/thread/windows/*.c",
		#endif
	};

	cstring sdlFlags[] = {
		"-Icode/SDL/include",
		"-DSDL_AUDIO_DISABLED",
		"-DSDL_HAPTIC_DISABLED",
		"-DSDL_HIDAPI_DISABLED",
		"-DSDL_SENSOR_DISABLED",
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
		.extraWatch = 0,
		.extraWatchLen = 0,
	};

	CompileCmd sdlCmd = execStep(builder, sdlStep);

	cstring freetypeSources[] = {
		// Required
		"code/freetype/src/base/ftsystem.c",
		"code/freetype/src/base/ftinit.c",
		"code/freetype/src/base/ftdebug.c",
		"code/freetype/src/base/ftbase.c",

		// Recommended
		"code/freetype/src/base/ftbbox.c",
		"code/freetype/src/base/ftglyph.c",

		// Optional
		"code/freetype/src/base/ftbdf.c",
		"code/freetype/src/base/ftbitmap.c",
		"code/freetype/src/base/ftcid.c",
		"code/freetype/src/base/ftfstype.c",
		"code/freetype/src/base/ftgasp.c",
		"code/freetype/src/base/ftgxval.c",
		"code/freetype/src/base/ftmm.c",
		"code/freetype/src/base/ftotval.c",
		"code/freetype/src/base/ftpatent.c",
		"code/freetype/src/base/ftpfr.c",
		"code/freetype/src/base/ftstroke.c",
		"code/freetype/src/base/ftsynth.c",
		"code/freetype/src/base/fttype1.c",
		"code/freetype/src/base/ftwinfnt.c",

		// Font drivers
		"code/freetype/src/bdf/bdf.c",
		"code/freetype/src/cff/cff.c",
		"code/freetype/src/cid/type1cid.c",
		"code/freetype/src/pcf/pcf.c",
		"code/freetype/src/pfr/pfr.c",
		"code/freetype/src/sfnt/sfnt.c",
		"code/freetype/src/truetype/truetype.c",
		"code/freetype/src/type1/type1.c",
		"code/freetype/src/type42/type42.c",
		"code/freetype/src/winfonts/winfnt.c",

		// Rasterisers
		"code/freetype/src/raster/raster.c",
		"code/freetype/src/sdf/sdf.c",
		"code/freetype/src/smooth/smooth.c",
		"code/freetype/src/svg/svg.c",

		// Auxillary
		"code/freetype/src/autofit/autofit.c",
		"code/freetype/src/cache/ftcache.c",
		"code/freetype/src/gzip/ftgzip.c",
		"code/freetype/src/lzw/ftlzw.c",
		"code/freetype/src/bzip2/ftbzip2.c",
		"code/freetype/src/gxvalid/gxvalid.c",
		"code/freetype/src/otvalid/otvalid.c",
		"code/freetype/src/psaux/psaux.c",
		"code/freetype/src/pshinter/pshinter.c",
		"code/freetype/src/psnames/psnames.c",
	};

	cstring freetypeIncludeFlag = "-Icode/freetype/include";
	cstring freetypeFlags[] = {freetypeIncludeFlag, "-DFT2_BUILD_LIBRARY"};

	Step freetypeStep = {
		.name = "freetype",
		.kind = BuildKind_Lib,
		.sources = freetypeSources,
		.sourcesLen = arrLen(freetypeSources),
		.flags = freetypeFlags,
		.flagsLen = arrLen(freetypeFlags),
		.link = 0,
		.linkLen = 0,
		.extraWatch = 0,
		.extraWatchLen = 0,
	};

	CompileCmd freetypeCmd = execStep(builder, freetypeStep);

	cstring wiredeckSources[] = {"code/wiredeck.c"};

	cstring wiredeckFlags[] = {
		freetypeIncludeFlag,
		"-Icode/SDL/include",
		#if PLATFORM_WINDOWS
			"/Wall",
			"/wd4204", // NOTE(khvorov) non-constant aggregate initializer
			"/wd4100", // NOTE(khvorov) unreferenced formal parameter
			"/wd4820", // NOTE(khvorov) padding
			"/wd4255", // NOTE(khvorov) converting () to (void)
			"/wd5045", // NOTE(khvorov) spectre mitigation
			"/wd4668" // NOTE(khvorov) not defined as a preprocessor macro
		#endif
	};

	cstring wiredeckLink[] = {
		sdlCmd.outPath,
		freetypeCmd.outPath,
		#if PLATFORM_WINDOWS
			"Ole32.lib", "Advapi32.lib", "Winmm.lib", "User32.lib", "Gdi32.lib",
			"OleAut32.lib", "Imm32.lib", "Shell32.lib", "Version.lib",
		#endif
	};

	cstring wiredeckExtraWatch[] = {"code/*.c", "code/*.h"};

	Step wiredeckStep = {
		.name = "wiredeck",
		.kind = BuildKind_Exe,
		.sources = wiredeckSources,
		.sourcesLen = arrLen(wiredeckSources),
		.flags = wiredeckFlags,
		.flagsLen = arrLen(wiredeckFlags),
		.link = wiredeckLink,
		.linkLen = arrLen(wiredeckLink),
		.extraWatch = wiredeckExtraWatch,
		.extraWatchLen = arrLen(wiredeckExtraWatch),
	};

	execStep(builder, wiredeckStep);

	return 0;
}
