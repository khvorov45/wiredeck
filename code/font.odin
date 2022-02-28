package wiredeck

import "core:os"
import "core:fmt"
import "core:c"

import tt "vendor:stb/truetype"

Font :: struct {
	px_height: int,
	px_width: int, // NOTE(khvorov) Assume monospace for now
	alphamap: []u8,
	alphamap_dim: [2]int, 
	chardata: []tt.bakedchar,
	firstchar: rune,
}

init_font :: proc(font: ^Font, filepath: string) {
	
	file_data, read_ok := os.read_entire_file_from_filename(filepath)
	assert(read_ok, fmt.tprintf("failed to read font at %s", filepath))
	
	alphamap_dim := [2]int{1000, 1000} // TODO(khvorov) Better size here
	firstchar: rune = '!'
	char_count := int('~') - int(firstchar) + 1

	font^ = Font{
		px_height = 16,
		alphamap = make([]u8, alphamap_dim.y * alphamap_dim.y),
		alphamap_dim = alphamap_dim,
		chardata = make([]tt.bakedchar, char_count),
		firstchar = firstchar,
	}


	bake_result := tt.BakeFontBitmap(
		raw_data(file_data),
		0,
		f32(font.px_height),
		raw_data(font.alphamap),
		c.int(font.alphamap_dim.x),
		c.int(font.alphamap_dim.y),
		'!', 
		c.int(char_count),
		raw_data(font.chardata),
	)

	assert(
		bake_result > 0, 
		fmt.tprintf(
			"failed to pack %d chars of font %s to bitmap size (%d, %d)", 
			-bake_result, filepath, alphamap_dim.x, alphamap_dim.y,
		),
	)

	font.px_width = int(font.chardata[0].xadvance)
}

get_glyph_tex_coords_and_offset :: proc(font: ^Font, glyph: rune) -> (Rect2i, [2]int) {

	ch_index := int(glyph) - int(font.firstchar)
	ch_data := font.chardata[ch_index]

	rect: Rect2i
	rect.topleft = [2]int{int(ch_data.x0), int(ch_data.y0)}
	rect.dim = [2]int{int(ch_data.x1 - ch_data.x0), int(ch_data.y1 - ch_data.y0)}

	offset := [2]int{int(ch_data.xoff), font.px_height + int(ch_data.yoff)}
	return rect, offset
}
