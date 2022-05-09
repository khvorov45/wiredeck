package wiredeck

import "core:strings"
import win "windows"

get_full_filepath :: proc(path: string, allocator: Allocator) -> (result: string) {
	path_cstring := strings.clone_to_cstring(path, context.temp_allocator)
	path_size := win.GetFullPathNameA(path_cstring, 0, nil, nil)
	buffer := make([]u8, path_size, allocator)
	win.GetFullPathNameA(path_cstring, path_size, cstring(raw_data(buffer)), nil)
	result = string(buffer[:len(buffer) - 1]) // NOTE(khvorov) Ingore the null terminator
	return result
}

read_entire_file :: proc(path: string, allocator: Allocator) -> (contents: Maybe([]u8)) {

	path_cstring := strings.clone_to_cstring(path, context.temp_allocator)
	handle := win.CreateFileA(
		path_cstring, win.GENERIC_READ, win.FILE_SHARE_READ, nil, win.OPEN_EXISTING,
		win.FILE_ATTRIBUTE_NORMAL, nil,
	)

	file_size := win.GetFileSize(handle, nil)
	contents = make([]u8, file_size, allocator)

	bytes_read: win.DWORD
	win.ReadFile(handle, raw_data(contents.([]u8)), file_size, &bytes_read, nil)
	
	if int(bytes_read) != len(contents.([]u8)) {
		delete(contents.([]u8))
		contents = nil
	}

	return contents
}
