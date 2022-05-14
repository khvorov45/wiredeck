package wiredeck

import "core:strings"
import "core:fmt"
import win "windows"

PATH_SEP :: '\\'

FilesystemIter :: struct {
	mask: win.DWORD,
	next_index: int,
	next_bit_index: int,
}

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

	if handle != win.INVALID_HANDLE_VALUE {

		file_size := win.GetFileSize(handle, nil)
		contents = make([]u8, file_size, allocator)

		bytes_read: win.DWORD
		win.ReadFile(handle, raw_data(contents.([]u8)), file_size, &bytes_read, nil)

		if int(bytes_read) != len(contents.([]u8)) {
			delete(contents.([]u8))
			contents = nil
		}

	} else {

		err_code := win.GetLastError()
		err_msg: win.LPWSTR
		msg_len := win.FormatMessageW(
			dwFlags = win.FORMAT_MESSAGE_ALLOCATE_BUFFER | win.FORMAT_MESSAGE_FROM_SYSTEM | win.FORMAT_MESSAGE_IGNORE_INSERTS,
			lpSource = nil,
			dwMessageId = err_code,
			dwLanguageId = 0,
			lpBuffer = &err_msg,
			nSize = 1024,
			Argument = nil,
		)
		printf("file read %s failed, code %d, message: ", path, err_code)

		for index in 0..<msg_len {
			char := rune(err_msg[index])
			printf("%c", char)
		}
		printf("\n")
	}

	return contents
}

filesystem_entries_begin :: proc(dir: Maybe(string)) -> (iter: FilesystemIter) {
	if dir == nil {
		iter = FilesystemIter{win.GetLogicalDrives(), 0, 0}
	} else {
		unimplemented("list folder entries")
	}
	return iter
}

filesystem_entry_next :: proc(
	iter: ^FilesystemIter, allocator: Allocator,
) -> (entry: string, index: int, present: bool) {

	for bit_index in iter.next_bit_index ..< 32 {
		logical_drive_available := (iter.mask & (1 << uint(bit_index))) != 0
		if logical_drive_available {
			ascii_code := int('A') + bit_index
			{
				context.allocator = allocator
				entry = fmt.aprintf("%c:", rune(ascii_code))
			}
			index = iter.next_index
			present = true

			iter.next_index += 1
			iter.next_bit_index = bit_index + 1
			break
		}
	}
	
	return entry, index, present
}
