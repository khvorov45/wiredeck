package wiredeck

import "core:math"

import mu "vendor:microui"

Renderer :: struct {
	pixels:	    []u32,
	pixels_dim:	[2]int,
}

Rect2d :: struct {
	topleft: [2]f32,
	dim:     [2]f32,
}

LineSegment2d :: struct {
	start: [2]f32,
	end:   [2]f32,
}

init_renderer :: proc(renderer: ^Renderer, width, height: int) {

	renderer^ = Renderer {
		pixels = make([]u32, width * height),
		pixels_dim = [2]int{width, height},
	}

	clear_buffers(renderer)
}

clear_buffers :: proc(renderer: ^Renderer) {
	for pixel in &renderer.pixels {
		pixel = 0
	}
}

draw_rect_px :: proc(renderer: ^Renderer, rect: Rect2d, color: [4]f32) {
	bottomright := rect.topleft + rect.dim
	for row in int(math.ceil(rect.topleft.y)) ..< int(math.ceil(bottomright.y)) {
		for col in int(math.ceil(rect.topleft.x)) ..< int(math.ceil(bottomright.x)) {
			px_index := row * renderer.pixels_dim.x + col
			old_col := renderer.pixels[px_index]
			new_col32 := color_blend(old_col, color)
			renderer.pixels[px_index] = new_col32
		}
	}
}

draw_line_px :: proc(
	renderer: ^Renderer,
	line: LineSegment2d,
	color: [4]f32,
) {
	delta := line.end - line.start
	run_length := max(abs(delta.x), abs(delta.y))
	inc := delta / run_length

	cur := line.start
	for _ in 0 ..< int(run_length) {

		cur_rounded_x := int(math.round(cur.x))
		cur_rounded_y := int(math.round(cur.y))

		px_index := cur_rounded_y * renderer.pixels_dim.x + cur_rounded_x
		old_col := renderer.pixels[px_index]
		new_col32 := color_blend(old_col, color)
		renderer.pixels[px_index] = new_col32
		
		cur += inc
	}
}

draw_alpha_tex_rect_px :: proc(
	renderer: ^Renderer,
	tex_coords: [2]int,
	tex_dim: [2]int,
	tex_alpha: []u8,
	tex_pitch: int,
	topleft: [2]f32,
	color: [4]f32,
) {
	px_coords := [2]int{int(math.ceil(topleft.x)), int(math.ceil(topleft.y))}

	cur_px_coord := px_coords
	for y_coord in tex_coords.y ..< tex_coords.y + tex_dim.y {
		for x_coord in tex_coords.x ..< tex_coords.x + tex_dim.x {

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
		cur_px_coord.x = px_coords.x
	}
}

draw_glyph_px :: proc(
	renderer: ^Renderer,
	glyph: u8,
	topleft: [2]f32,
	color: [4]f32,
) -> f32 {
	tex_coords := mu.default_atlas[mu.DEFAULT_ATLAS_FONT + int(glyph)]
	draw_alpha_tex_rect_px(
		renderer, 
		[2]int{int(tex_coords.x), int(tex_coords.y)},
		[2]int{int(tex_coords.w), int(tex_coords.h)},
		mu.default_atlas_alpha[:], 
		mu.DEFAULT_ATLAS_WIDTH, 
		topleft, 
		color,
	)
	return f32(tex_coords.w)
}

draw_icon_px :: proc(
	renderer: ^Renderer,
	icon: mu.Icon,
	rect: Rect2d,
	color: [4]f32,
) -> f32 {
	tex_coords := mu.default_atlas[icon]
	icon_dim := [2]f32{f32(tex_coords.w), f32(tex_coords.h)}
	slack := rect.dim - icon_dim
	topleft := rect.topleft + slack * 0.5
	draw_alpha_tex_rect_px(
		renderer, 
		[2]int{int(tex_coords.x), int(tex_coords.y)},
		[2]int{int(tex_coords.w), int(tex_coords.h)},
		mu.default_atlas_alpha[:], 
		mu.DEFAULT_ATLAS_WIDTH, 
		topleft, 
		color,
	)
	return f32(tex_coords.w)
}

draw_string_px :: proc(
	renderer: ^Renderer,
	str: string,
	topleft: [2]f32,
	color: [4]f32,
) {

	topleft := topleft
	for i in 0 ..< len(str) {
		glyph := str[i]
		glyph_width := draw_glyph_px(renderer, glyph, topleft, color)
		topleft.x += glyph_width
	}

}

clip_to_px_buffer_rect :: proc(rect: Rect2d, px_dim: [2]int) -> Rect2d {

	dim_f32 := [2]f32{f32(px_dim.x), f32(px_dim.y)}
	result: Rect2d

	topleft := rect.topleft
	bottomright := topleft + rect.dim

	x_overlaps := topleft.x < dim_f32.x && bottomright.x > 0
	y_overlaps := topleft.y < dim_f32.y && bottomright.y > 0

	if x_overlaps && y_overlaps {

		topleft.x = max(topleft.x, 0)
		topleft.y = max(topleft.y, 0)

		bottomright.x = min(bottomright.x, dim_f32.x)
		bottomright.y = min(bottomright.y, dim_f32.y)

		result.topleft = topleft
		result.dim = bottomright - topleft

	}

	return result
}

// Liang–Barsky algorithm
// https://en.wikipedia.org/wiki/Liang%E2%80%93Barsky_algorithm
clip_to_px_buffer_line :: proc(line: LineSegment2d, px_dim: [2]int) -> LineSegment2d {

	dim_f32 := [2]f32{f32(px_dim.x - 1), f32(px_dim.y - 1)}

	p1 := -(line.end.x - line.start.x)
	p2 := -p1
	p3 := -(line.end.y - line.start.y)
	p4 := -p3

	q1 := line.start.x
	q2 := dim_f32.x - line.start.x
	q3 := line.start.y
	q4 := dim_f32.y - line.start.y

	posarr, negarr: [5]f32
	posarr[0] = 1
	negarr[0] = 0
	posind := 1
	negind := 1

	result: LineSegment2d

	// NOTE(khvorov) Line parallel to clipping window
	if (p1 == 0 && q1 < 0) || (p2 == 0 && q2 < 0) || (p3 == 0 && q3 < 0) || (p4 == 0 && q4 <
	   0) {
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

	// NOTE(khvorov) To avoid getting ambushed by floating point error
	result.start.x = clamp(result.start.x, 0, f32(px_dim.x - 1))
	result.start.y = clamp(result.start.y, 0, f32(px_dim.y - 1))
	result.end.x = clamp(result.end.x, 0, f32(px_dim.x - 1))
	result.end.y = clamp(result.end.y, 0, f32(px_dim.y - 1))

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