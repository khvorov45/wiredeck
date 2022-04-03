package wiredeck

Renderer :: struct {
	pixels:     []u32,
	pixels_dim: [2]int,
}

LineSegment2i :: struct {
	start: [2]int,
	end:   [2]int,
}

init_renderer :: proc(renderer: ^Renderer, width, height: int) {
	renderer^ = Renderer {
		pixels = make([]u32, width * height),
		pixels_dim = [2]int{width, height},
	}
}

clear_buffers :: proc(renderer: ^Renderer, color: [4]f32, dim: [2]int) {
	if renderer.pixels_dim != dim {
		new_pixels := make([]u32, dim.x * dim.y)
		delete(renderer.pixels)
		renderer.pixels = new_pixels
		renderer.pixels_dim = dim
	}

	color32 := color_to_u32argb(color)
	for pixel in &renderer.pixels {
		pixel = color32
	}
}

draw_rect_px :: proc(renderer: ^Renderer, rect_init: Rect2i, color: [4]f32) {
	rect := clip_rect_to_rect(rect_init, Rect2i{{0, 0}, renderer.pixels_dim})
	if is_valid_draw_rect(rect, renderer.pixels_dim) {
		bottomright := rect.topleft + rect.dim
		for row in rect.topleft.y ..< bottomright.y {
			for col in rect.topleft.x ..< bottomright.x {
				px_index := row * renderer.pixels_dim.x + col
				old_col := renderer.pixels[px_index]
				new_col32 := color_blend(old_col, color)
				renderer.pixels[px_index] = new_col32
			}
		}
	}
}

draw_line_px :: proc(renderer: ^Renderer, line_init: LineSegment2i, color: [4]f32) {
	line := clip_line_to_rect(line_init, Rect2i{{0, 0}, renderer.pixels_dim})

	delta := line.end - line.start
	run_length := max(abs(delta.x), abs(delta.y))
	inc := delta / run_length

	cur := line.start
	for _ in 0 ..< int(run_length) {

		cur_rounded_x := cur.x
		cur_rounded_y := cur.y

		px_index := cur_rounded_y * renderer.pixels_dim.x + cur_rounded_x
		old_col := renderer.pixels[px_index]
		new_col32 := color_blend(old_col, color)
		renderer.pixels[px_index] = new_col32

		cur += inc
	}
}

draw_alpha_tex_rect_px :: proc(
	renderer: ^Renderer,
	tex_rect: Rect2i,
	tex_alpha: []u8,
	tex_pitch: int,
	topleft: [2]int,
	color: [4]f32,
	clip_rect: Rect2i,
) {
	px_rect: Rect2i
	px_rect.topleft = topleft
	px_rect.dim = tex_rect.dim

	px_rect_clipped := clip_rect_to_rect(px_rect, Rect2i{{0, 0}, renderer.pixels_dim})
	px_rect_clipped = clip_rect_to_rect(px_rect_clipped, clip_rect)

	if is_valid_draw_rect(px_rect_clipped, renderer.pixels_dim) {

		cur_px_coord := px_rect_clipped.topleft
		tex_topleft := tex_rect.topleft + (px_rect_clipped.topleft - px_rect.topleft)
		tex_bottomright := tex_topleft + px_rect_clipped.dim

		for y_coord in tex_topleft.y ..< tex_bottomright.y {
			for x_coord in tex_topleft.x ..< tex_bottomright.x {

				tex_index := y_coord * tex_pitch + x_coord
				tex_alpha := tex_alpha[tex_index]
				tex_alpha01 := f32(tex_alpha) / 255
				tex_col := color
				tex_col.a *= tex_alpha01

				px_index := cur_px_coord.y * renderer.pixels_dim.x + cur_px_coord.x
				old_px_col := renderer.pixels[px_index]
				new_px_col := color_blend(old_px_col, tex_col)
				renderer.pixels[px_index] = new_px_col

				cur_px_coord.x += 1
			}

			cur_px_coord.y += 1
			cur_px_coord.x = px_rect_clipped.topleft.x
		}
	}
}

draw_glyph_px :: proc(
	renderer: ^Renderer,
	font: ^Font,
	glyph: u8,
	topleft: [2]int,
	color: [4]f32,
	clip_rect: Rect2i,
) {
	glyph_info := get_glyph_info(font, glyph)
	topleft_offset := topleft + glyph_info.offset
	draw_alpha_tex_rect_px(
		renderer,
		glyph_info.tex_rect,
		font.alphamap,
		font.alphamap_dim.x,
		topleft_offset,
		color,
		clip_rect,
	)
}

draw_text_px :: proc(
	renderer: ^Renderer,
	font: ^Font,
	str: string,
	text_topleft: [2]int,
	clip_rect: Rect2i,
	colors: union{[4]f32, [][4]f32},
) {
	cur_topleft := text_topleft
	rect_bottomright := clip_rect.topleft + clip_rect.dim
	for index in 0..<len(str) {
		ch := str[index]
		if ch != ' ' && ch != '\t' {
			color: [4]f32
			switch col in colors {
			case [4]f32:
				color = col
			case [][4]f32:
				color = col[index]
			}
			draw_glyph_px(renderer, font, ch, cur_topleft, color, clip_rect)
		}
		if ch == '\t' {
			cur_topleft.x += 4 * get_glyph_info(font, ' ').advance_x
		} else {
			cur_topleft.x += get_glyph_info(font, ch).advance_x
		}
		if cur_topleft.x > rect_bottomright.x {
			break
		}
	}
}

/*
draw_icon_px :: proc(
	renderer: ^Renderer,
	icon: mu.Icon,
	rect: Rect2i,
	color: [4]f32,
) -> int {
	tex_coords := mu.default_atlas[icon]
	icon_dim := [2]int{int(tex_coords.w), int(tex_coords.h)}
	slack := rect.dim - icon_dim
	topleft := rect.topleft + slack / 2
	draw_alpha_tex_rect_px(
		renderer, 
		[2]int{int(tex_coords.x), int(tex_coords.y)},
		[2]int{int(tex_coords.w), int(tex_coords.h)},
		mu.default_atlas_alpha[:], 
		mu.DEFAULT_ATLAS_WIDTH, 
		topleft,
		color,
	)
	return int(tex_coords.w)
}
*/

clip_rect_to_rect :: proc(rect: Rect2i, bounds: Rect2i) -> Rect2i {

	result: Rect2i

	topleft := rect.topleft
	bottomright := topleft + rect.dim

	bound_topleft := bounds.topleft
	bound_bottomright := bound_topleft + bounds.dim

	x_overlaps := topleft.x < bound_bottomright.x && bottomright.x >= bound_topleft.x
	y_overlaps := topleft.y < bound_bottomright.y && bottomright.y >= bound_topleft.y

	if x_overlaps && y_overlaps {

		topleft.x = max(topleft.x, bound_topleft.x)
		topleft.y = max(topleft.y, bound_topleft.y)

		bottomright.x = min(bottomright.x, bound_bottomright.x)
		bottomright.y = min(bottomright.y, bound_bottomright.y)

		result.topleft = topleft
		result.dim = bottomright - topleft
	}

	return result
}

// Liang–Barsky algorithm
// https://en.wikipedia.org/wiki/Liang%E2%80%93Barsky_algorithm
clip_line_to_rect :: proc(line: LineSegment2i, bounds: Rect2i) -> LineSegment2i {

	bound_topleft := bounds.topleft
	bound_bottomright := bounds.topleft + bounds.dim

	p1 := -(line.end.x - line.start.x)
	p2 := -p1
	p3 := -(line.end.y - line.start.y)
	p4 := -p3

	q1 := line.start.x - bound_topleft.x
	q2 := bound_bottomright.x - line.start.x
	q3 := line.start.y - bound_topleft.y
	q4 := bound_bottomright.y - line.start.y

	posarr, negarr: [5]int
	posarr[0] = 1
	negarr[0] = 0
	posind := 1
	negind := 1

	result: LineSegment2i

	// NOTE(khvorov) Line parallel to clipping window
	if (p1 == 0 && q1 < 0) || (p2 == 0 && q2 < 0) || (p3 == 0 && q3 < 0) || (p4 == 0 && q4 < 0) {
		return result
	}

	if p1 != 0 {
		r1 := q1 / p1
		r2 := q2 / p2
		if p1 < 0 {
			negarr[negind] = r1
			posarr[posind] = r2
		} else {
			negarr[negind] = r2
			posarr[posind] = r1
		}
		negind += 1
		posind += 1
	}

	if p3 != 0 {
		r3 := q3 / p3
		r4 := q4 / p4
		if (p3 < 0) {
			negarr[negind] = r3
			posarr[posind] = r4
		} else {
			negarr[negind] = r4
			posarr[posind] = r3
		}
		negind += 1
		posind += 1
	}

	rn1 := negarr[0]
	for neg in negarr[1:negind] {
		rn1 = max(rn1, neg)
	}
	rn2 := posarr[0]
	for pos in posarr[1:posind] {
		rn2 = min(rn2, pos)
	}

	// NOTE(khvorov) Line outside clipping window
	if rn1 > rn2 {
		return result
	}

	result.start.x = line.start.x + p2 * rn1
	result.start.y = line.start.y + p4 * rn1

	result.end.x = line.start.x + p2 * rn2
	result.end.y = line.start.y + p4 * rn2

	return result
}

is_valid_draw_rect :: proc(rect: Rect2i, px_dim: [2]int) -> bool {
	rect_bottomright := rect.topleft + rect.dim
	nonzero := rect.dim.x > 0 && rect.dim.y > 0
	topleft_in := rect.topleft.x >= 0 && rect.topleft.y >= 0
	bottomright_in := rect_bottomright.x <= px_dim.x && rect_bottomright.y <= px_dim.y
	result := nonzero && topleft_in && bottomright_in
	return result
}

color_to_u32argb :: proc(color01: [4]f32) -> u32 {
	color := color01 * 255
	result := u32(color.a) << 24 | u32(color.r) << 16 | u32(color.g) << 8 | u32(color.b)
	return result
}

color_to_4f32 :: proc(argb: u32) -> [4]f32 {
	a := (argb & 0xFF000000) >> 24
	r := (argb & 0x00FF0000) >> 16
	g := (argb & 0x0000FF00) >> 8
	b := (argb & 0x000000FF) >> 0
	color := [4]f32{f32(r), f32(g), f32(b), f32(a)}
	color /= 255
	return color
}

color_blend :: proc(old: u32, new: [4]f32) -> u32 {
	old4 := color_to_4f32(old)
	new4 := (1 - new.a) * old4 + new.a * new
	new32 := color_to_u32argb(new4)
	return new32
}
