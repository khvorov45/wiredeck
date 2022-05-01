package wiredeck

import "core:fmt"

import ft "freetype"

Font :: struct {
	px_height_font: int,
	px_height_line: int,
	alphamap: []u8,
	alphamap_glyphs: []GlyphInfo,
	firstchar: rune,
}

GlyphInfo :: struct {
	offset: [2]int,
	alphamap_offset: int,
	width: int,
	rows: int,
	advance_x: int,
}

init_font :: proc(font: ^Font, filepath: string) {

	firstchar: rune = ' '
	char_count := int('~') - int(firstchar) + 1

	font^ = Font{
		px_height_font = 14,
		alphamap_glyphs = make([]GlyphInfo, char_count),
		firstchar = firstchar,
	}

	ft_lib: ft.Library
	assert(ft.Init_FreeType(&ft_lib) == ft.Err_Ok)

	file_data, read_ok := read_entire_file(filepath)
	assert(read_ok, fmt.tprintf("failed to read font at %s", filepath))

	ft_face: ft.Face
	assert(ft.New_Memory_Face(ft_lib, raw_data(file_data), ft.Long(len(file_data)), 0, &ft_face) == ft.Err_Ok)
	assert(ft.Set_Pixel_Sizes(ft_face, 0, u32(font.px_height_font)) == ft.Err_Ok)
	font.px_height_line = int(ft.MulFix(ft.Long(ft_face.height), ft.Long(ft_face.size.metrics.y_scale))) / 64

	load_and_render_ft_bitmap :: proc(firstchar: rune, ch_index: int, ft_face: ft.Face) {
		ch := rune(int(firstchar) + ch_index)
		ft_glyph_index := ft.Get_Char_Index(ft_face, ft.ULong(ch))
		ft.Load_Glyph(ft_face, ft_glyph_index, ft.LOAD_DEFAULT)
		if ft_face.glyph.format != ft.Glyph_Format.BITMAP {
			assert(ft.Render_Glyph(ft_face.glyph, ft.Render_Mode.NORMAL) == ft.Err_Ok)
		}
	}

	req_alphamap_size := 0
	for ch_index in 0..<char_count {
		load_and_render_ft_bitmap(firstchar, ch_index, ft_face)
		bm := ft_face.glyph.bitmap
		req_alphamap_size += int(bm.width * bm.rows)
	}

	font.alphamap = make([]u8, req_alphamap_size)

	alphamap_offset := 0
	for ch_index in 0..<char_count {
		load_and_render_ft_bitmap(firstchar, ch_index, ft_face)
		bm := ft_face.glyph.bitmap

		font.alphamap_glyphs[ch_index] = GlyphInfo{
			[2]int{int(ft_face.glyph.bitmap_left), font.px_height_font - int(ft_face.glyph.bitmap_top)},
			alphamap_offset,
			int(bm.width),
			int(bm.rows),
			int(ft_face.glyph.advance.x) >> 6,
		}

		for row in 0..<int(bm.rows) {
			for col in 0..<int(bm.width) {
				bm_px_index := row * int(bm.pitch) + col
				bm_px := (cast([^]u8)bm.buffer)[bm_px_index]
				font.alphamap[alphamap_offset] = bm_px
				alphamap_offset += 1
			}
		}
	}

	ft.Done_FreeType(ft_lib)
}

get_glyph_index :: proc(font: ^Font, glyph: u8) -> int {
	result := int(glyph) - int(font.firstchar)
	return result
}

get_glyph_info :: proc(font: ^Font, glyph: u8) -> GlyphInfo {
	ch_index := get_glyph_index(font, glyph)
	ch_data := font.alphamap_glyphs[ch_index]
	return ch_data
}

get_string_width :: proc(font: ^Font, str: string) -> int {
	result := 0
	for byte_index in 0..<len(str) {
		ch := str[byte_index]
		ch_info := get_glyph_info(font, ch)
		result += ch_info.advance_x
	}
	return result
}
