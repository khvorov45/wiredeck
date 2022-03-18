package wiredeck

import "core:os"
import "core:fmt"
import "core:c"

import ft "freetype"

Font :: struct {
	ft_lib: ft.Library,
	ft_face: ft.Face,
	px_height_font: int,
	px_height_line: int,
	px_width: int, // NOTE(khvorov) Assume monospace for now
	alphamap: []u8,
	alphamap_dim: [2]int,
	alphamap_glyphs: []GlyphInfo,
	firstchar: rune,
}

GlyphInfo :: struct {
	tex_rect: Rect2i,
	offset: [2]int,
}

init_font :: proc(font: ^Font, filepath: string) {

	alphamap_dim := [2]int{1000, 1000} // TODO(khvorov) Better size here
	firstchar: rune = '!'
	char_count := int('~') - int(firstchar) + 1

	font^ = Font{
		px_height_font = 14,
		alphamap = make([]u8, alphamap_dim.y * alphamap_dim.y),
		alphamap_dim = alphamap_dim,
		alphamap_glyphs = make([]GlyphInfo, char_count),
		firstchar = firstchar,
	}

	assert(ft.Init_FreeType(&font.ft_lib) == ft.Err_Ok)

	file_data, read_ok := os.read_entire_file_from_filename(filepath)
	assert(read_ok, fmt.tprintf("failed to read font at %s", filepath))

	assert(ft.New_Memory_Face(font.ft_lib, raw_data(file_data), ft.Long(len(file_data)), 0, &font.ft_face) == ft.Err_Ok)
	assert(ft.Set_Pixel_Sizes(font.ft_face, 0, u32(font.px_height_font)) == ft.Err_Ok)

	alphamap_offset := [2]int{0, 0}
	cur_row_max_y := 0
	for ch_index in 0..<char_count {
		ch := rune(int(firstchar) + ch_index)
		ft_glyph_index := ft.Get_Char_Index(font.ft_face, ft.ULong(ch))
		ft.Load_Glyph(font.ft_face, ft_glyph_index, ft.LOAD_DEFAULT)
		if font.ft_face.glyph.format != ft.Glyph_Format.BITMAP {
			assert(ft.Render_Glyph(font.ft_face.glyph, ft.Render_Mode.NORMAL) == ft.Err_Ok)
		}

		bm := font.ft_face.glyph.bitmap
		if alphamap_offset.x + int(bm.width) >= alphamap_dim.x {
			alphamap_offset.x = 0
			alphamap_offset.y += cur_row_max_y
			assert(alphamap_offset.y + int(bm.rows) < alphamap_dim.y)
			cur_row_max_y = int(bm.rows)
		}

		for row in 0..<int(bm.rows) {
			for col in 0..<int(bm.width) {
				bm_px_index := row * int(bm.pitch) + col
				bm_px := (cast([^]u8)bm.buffer)[bm_px_index]

				alphamap_coords := alphamap_offset + [2]int{col, row}
				alphamap_px_index := alphamap_coords.y * alphamap_dim.x + alphamap_coords.x
				font.alphamap[alphamap_px_index] = bm_px
			}
		}

		font.alphamap_glyphs[ch_index] = GlyphInfo{
			Rect2i{alphamap_offset, [2]int{int(bm.width), int(bm.rows)}},
			[2]int{int(font.ft_face.glyph.bitmap_left), font.px_height_font - int(font.ft_face.glyph.bitmap_top)},
		}

		alphamap_offset.x += int(bm.width)
		cur_row_max_y = max(cur_row_max_y, int(bm.rows))
	}

	font.px_width = int(font.ft_face.glyph.advance.x) >> 6
	font.px_height_line = int(ft.MulFix(ft.Long(font.ft_face.height), ft.Long(font.ft_face.size.metrics.y_scale))) / 64
}

get_glyph_info :: proc(font: ^Font, glyph: u8) -> GlyphInfo {
	ch_index := int(glyph) - int(font.firstchar)
	ch_data := font.alphamap_glyphs[ch_index]
	return ch_data
}
