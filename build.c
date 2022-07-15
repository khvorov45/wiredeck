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

	cstring pdbPath = 0;

	#if PLATFORM_WINDOWS

		// NOTE(khvorov) obj output
		dynCStringPush(&cmdBuilder, "/Fo");
		dynCStringMark(&cmdBuilder);
		dynCStringPush(&cmdBuilder, builder.outDir);
		dynCStringPush(&cmdBuilder, "/");
		dynCStringPush(&cmdBuilder, step.name);
		cstring objDir = dynCStringCloneCstringFromMarker(&cmdBuilder);
		dynCStringPush(&cmdBuilder, "/ ");

		// NOTE(khvorov) pdb output
		dynCStringPush(&cmdBuilder, "/Fd");
		dynCStringMark(&cmdBuilder);
		dynCStringPush(&cmdBuilder, builder.outDir);
		dynCStringPush(&cmdBuilder, "/");
		dynCStringPush(&cmdBuilder, step.name);
		dynCStringPush(&cmdBuilder, ".pdb ");
		pdbPath = dynCStringCloneCstringFromMarker(&cmdBuilder);

		// NOTE(khvorov) exe output
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
		.pdbPath = pdbPath,
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
getLastModifiedFromPattern(cstring pattern) {
	u64 result = 0;

	#if PLATFORM_WINDOWS
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
	#endif

	return result;
}

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

void
removeFileIfExists(cstring path) {
	if (path) {
		#if PLATFORM_WINDOWS
			DeleteFileA(path);
		#endif
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
			"-Icode/imgui",
			"-Icode/imgui/backends",
			"-Icode/imgui/misc/freetype",
			freetypeIncludeFlag,
			"-Icode/SDL/include",
			#if PLATFORM_WINDOWS
				"/W2",
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
