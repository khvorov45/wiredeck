package wiredeck

import "core:math"
import "core:math/linalg"

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

	total_length := linalg.length(delta)
	inc_length := linalg.length(inc)
	one_over_w_start: f32 = 0
	one_over_w_end: f32 = 0

	cur := line.start
	for step in 0 ..< int(run_length) {

		cur_rounded_x := int(math.round(cur.x))
		cur_rounded_y := int(math.round(cur.y))

		px_index := cur_rounded_y * renderer.pixels_dim.x + cur_rounded_x
		old_col := renderer.pixels[px_index]
		new_col32 := color_blend(old_col, color)
		renderer.pixels[px_index] = new_col32
		
		cur += inc
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
	new := (1 - new.a) * old4 + new.a * new
	new32 := color_to_u32argb(new)
	return new32
}