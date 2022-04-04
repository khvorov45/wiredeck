package wiredeck

import "core:strings"
import fp "core:path/filepath"

highlight :: proc(
	filepath: string,
	file_content: string,
	text_cols: [TextColorID][4]f32,
) -> [][4]f32 {

	colors := make([][4]f32, len(file_content))
	for col in &colors {
		col = text_cols[.Normal]
	}

	file_ext: string
	for index := len(filepath) - 1; index >= 0; index -= 1 {
		ch := filepath[index]
		if ch == '.' {
			file_ext = filepath[index + 1:]
		}
	}

	switch file_ext {
	case "c":
		highlight_c(filepath, file_content, &colors, text_cols)
	case "bat":
		highlight_bat(filepath, file_content, &colors, text_cols)
	}

	return colors
}

highlight_c :: proc(
	filepath: string,
	file_content: string,
	colors: ^[][4]f32,
	text_cols: [TextColorID][4]f32,
) {

	str_left := file_content
	col_left := colors[:]

	for len(str_left) > 0 {

		non_whitespace := index_non_whitespace(str_left)
		str_left = str_left[non_whitespace:]
		col_left = col_left[non_whitespace:]

		section_end: Maybe(int)
		section_col := text_cols[.Normal]
		if starts_with(str_left, "/*") {
			section_end = strings.index(str_left, "*/") + 2
			section_col = text_cols[.Comment]
		} else if starts_with(str_left, "//") {
			section_end = strings.index_any(str_left, "\r\n") + 1
			section_col = text_cols[.Comment]
		}

		if section_end, ok := section_end.(int); ok {
			if section_end == -1 {
				section_end = len(str_left)
			}
			section_cols := col_left[:section_end]
			for col in &section_cols {
				col = section_col
			}
			str_left = str_left[section_end:]
			col_left = col_left[section_end:]

		} else if len(str_left) > 0 {

			str_left = str_left[1:]
			col_left = col_left[1:]
		}
	}
}

highlight_bat :: proc(
	filepath: string,
	file_content: string,
	colors: ^[][4]f32,
	text_cols: [TextColorID][4]f32,
) {

	assert(len(file_content) == len(colors))
	str_left := file_content
	col_left := colors[:]

	for len(str_left) > 0 {
		line_end := strings.index_any(str_left, "\r\n")
		if line_end == -1 {
			line_end = len(str_left)
		}

		line := str_left[:line_end]
		col_line := col_left[:line_end]
		non_whitespace := index_non_whitespace(line)
		line = line[non_whitespace:]
		col_line = col_line[non_whitespace:]

		if starts_with(line, "rem") {
			for col in &col_line {
				col = [4]f32{0.5, 0.5, 0.5, 1}
			}
		}

		str_left = str_left[line_end:]
		col_left = col_left[line_end:]
		for len(str_left) > 0 && (str_left[0] == '\r' || str_left[0] == '\n') {
			str_left = str_left[1:]
			col_left = col_left[1:]
		}
	}
}

highlight_filepath :: proc(filepath: string, text_cols: [TextColorID][4]f32) -> [][4]f32 {
	result := make([][4]f32, len(filepath))

	last_sep_index := 0
	for index in 0..<len(filepath) {
		ch := filepath[index]

		when ODIN_OS == .Windows {
			if ch == ':' {
				result[index] = text_cols[.Punctuation]
			}
		}

		if ch == fp.SEPARATOR {
			last_sep_index = index
			result[index] = text_cols[.Punctuation]
		} else {
			result[index] = text_cols[.Normal]
		}
	}

	if len(filepath) > 0 {
		for index in 0..last_sep_index {
			result[index] *= 0.8
		}
	}

	return result
}

index_non_whitespace :: proc(str: string) -> int {
	result := len(str)
	for index in 0 ..< len(str) {
		ch := str[index]
		if ch != ' ' && ch != '\t' && ch != '\r' && ch != '\n' {
			result = index
			break
		}
	}
	return result
}

starts_with :: proc(str: string, with: string) -> bool {
	result := false
	if len(str) >= len(with) {
		result = true
		for index in 0 ..< len(with) {
			ch1 := str[index]
			ch2 := with[index]
			if ch1 != ch2 {
				result = false
				break
			}
		}
	}
	return result
}
