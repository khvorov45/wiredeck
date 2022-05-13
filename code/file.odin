package wiredeck

import "core:strings"

Filesystem :: struct {
	tree: Linkedlist(FilesystemEntry),
	files: Freelist(File),
	entries_free: Linkedlist(FilesystemEntry),
	freelist_allocator: Allocator,
	file_content_allocator: Allocator,
}

File :: struct {
	path: string,
	fullpath: string,
	fullpath_col: [][4]f32, // NOTE(khvorov) Same length as fullpath bytes
	content: string,
	colors: [][4]f32, // NOTE(khvorov) Same length as content bytes
	line_count: int,
	max_col_width_glyphs: int,
}

FileRef :: struct {
	file_in_list: ^LinkedlistEntry(File),
	line_offset_lines: int,
	line_offset_bytes: int,
	col_offset: int,
	cursor_scroll_ref: [2]Maybe(f32),
}

FilesystemEntry :: struct {
	name: string,
	entries: Linkedlist(FilesystemEntry),
}

init_filesystem :: proc(fs: ^Filesystem, freelist_allocator, file_content_allocator: Allocator) {
	fs^ = {}
	fs.file_content_allocator = file_content_allocator
	fs.freelist_allocator = freelist_allocator
	freelist_init(&fs.files, freelist_allocator)
}


open_file :: proc(
	fs: ^Filesystem, filepath: string, text_cols: [TextColorID][4]f32,
) -> (file_in_list: ^LinkedlistEntry(File)) {

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

		colors := make([][4]f32, len(str))
		highlight(filepath, str, &colors, text_cols)

		fullpath := get_full_filepath(filepath, fs.file_content_allocator)
		fullpath_col := make([][4]f32, len(fullpath))
		highlight_filepath(fullpath, &fullpath_col, text_cols)

		opened_file := File {
			path = strings.clone(filepath),
			fullpath = fullpath,
			fullpath_col = fullpath_col,
			content = str,
			colors = colors,
			line_count = line_count,
			max_col_width_glyphs = max_col_width_glyphs,
		}

		file_in_list = freelist_append(&fs.files, opened_file)
	}

	return file_in_list
}
