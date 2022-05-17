package wiredeck

import "core:strings"

Filesystem :: struct {
	open: Linkedlist(FilesystemEntry),
	entries_free: Linkedlist(FilesystemEntry),
	freelist_allocator: Allocator,
	file_content_allocator: Allocator,
}

FilesystemEntry :: struct {
	fullpath: ColoredString,
	parent: Maybe(^FilesystemEntry), // NOTE(khvorov) nill on maybe - didn't look; nill on ptr - no parent
	content: union {Dir, File},
}

Dir :: struct {
	entries: Linkedlist(FilesystemEntry),
}

File :: struct {
	content: ColoredString,
	line_count: int,
	max_col_width_glyphs: int,
}

ColoredString :: struct {
	str: string,
	cols: [][4]f32, // NOTE(khvorov) Same length as str bytes
}

init_filesystem :: proc(fs: ^Filesystem, freelist_allocator, file_content_allocator: Allocator) {
	fs^ = {}
	fs.file_content_allocator = file_content_allocator
	fs.freelist_allocator = freelist_allocator
}

open_file :: proc(
	fs: ^Filesystem, filepath: string, text_cols: [TextColorID][4]f32,
) -> (entry_in_list: ^LinkedlistEntry(FilesystemEntry)) {

	// TODO(khvorov) See if the file has already been opened

	if file_contents, success := read_entire_file(filepath, fs.file_content_allocator).([]u8); success {

		// NOTE(khvorov) Count lines and column widths
		str := string(file_contents)
		line_count := 0
		max_col_width_glyphs := 0
		cur_col_width := 0
		for index := 0; index < len(str); index += 1 {
			ch := str[index]
			if ch == '\n' || ch == '\r' {
				line_count += 1
				next_ch: u8 = 0
				if index + 1 < len(str) {
					next_ch = str[index + 1]
				}
				if ch == '\r' && next_ch == '\n' {
					index += 1
				}
				max_col_width_glyphs = max(max_col_width_glyphs, cur_col_width)
				cur_col_width = 0
			} else if ch == '\t' {
				cur_col_width += 4
			} else {
				cur_col_width += 1
			}
		}

		// NOTE(khvorov) Account for last line
		max_col_width_glyphs = max(max_col_width_glyphs, cur_col_width)
		line_count += 1 // NOTE(khvorov) Start counting from 1

		colors := make([][4]f32, len(str), fs.file_content_allocator)
		highlight(filepath, str, &colors, text_cols)

		fullpath := get_full_filepath(filepath, fs.file_content_allocator)
		fullpath_col := make([][4]f32, len(fullpath), fs.file_content_allocator)
		highlight_filepath(fullpath, &fullpath_col, text_cols)

		opened_file := File {
			content = ColoredString{str, colors},
			line_count = line_count,
			max_col_width_glyphs = max_col_width_glyphs,
		}

		entry_in_list = linkedlist_remove_last_or_new(
			&fs.entries_free,
			FilesystemEntry{ColoredString{fullpath, fullpath_col}, nil, opened_file},
			fs.freelist_allocator,
		)
		linkedlist_append(&fs.open, entry_in_list)
	}

	return entry_in_list
}

open_dir :: proc(fs: ^Filesystem, dirpath: string, text_cols: [TextColorID][4]f32) {

}
