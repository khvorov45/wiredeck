package wiredeck

import "core:strings"
import "core:c"

foreign import tinyfd {"../build/tinyfiledialog.lib", "system:User32.lib", "system:Comdlg32.lib", "system:Ole32.lib", "system:Shell32.lib"}

foreign tinyfd {
	tinyfd_openFileDialog :: proc(
		aTitle,
		aDefaultPathAndFile: rawptr,
		aNumOfFilterPatterns: c.int,
		aFilterPatterns,
		aSingleFilterDescription: rawptr,
		aAllowMultipleSelects: c.int,
	) -> cstring ---

	tinyfd_selectFolderDialog :: proc(aTitle, aDefaultPath: rawptr) -> cstring ---

	tinyfd_free :: proc(ptr: cstring) ---
}

PathKind :: enum {
	File,
	Folder,
}

get_path_from_platform_file_dialog :: proc(path_kind: PathKind) -> string {
	outpath: cstring
	result: string = ""

	switch path_kind {
	case .File:
		outpath = tinyfd_openFileDialog(nil, nil, 0, nil, nil, 0)
	case .Folder:
		outpath = tinyfd_selectFolderDialog(nil, nil)
	}

	if outpath != nil {
		result = strings.clone_from_cstring(outpath, context.temp_allocator)
		tinyfd_free(outpath)
	}

	return result
}
