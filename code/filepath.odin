package wiredeck

import "core:strings"
when ODIN_OS == .Windows {
	import win "windows"
} else {
	import "core:os"
}

get_full_filepath :: proc(path: string) -> (result: string) {
	when ODIN_OS == .Windows {
		path_cstring := strings.clone_to_cstring(path, context.temp_allocator)
		path_size := win.GetFullPathNameA(path_cstring, 0, nil, nil)
		buffer := make([]u8, path_size)
		win.GetFullPathNameA(path_cstring, path_size, cstring(raw_data(buffer)), nil)
		result = string(buffer[:len(buffer) - 1]) // NOTE(khvorov) Ingore the null terminator
	} else {
		result, err = os.absolute_path_from_relative(path)
		assert(err == ERROR_NONE)
	}
	return result
}
