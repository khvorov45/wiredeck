package wiredeck

import mu "vendor:microui"

main :: proc() {

	window: Window
	init_window(&window, "Wiredeck", 1000, 1000)

	renderer: Renderer
	init_renderer(&renderer, window.dim.x, window.dim.y)

	ui: mu.Context
	mu.init(&ui)
	ui.text_width = mu.default_atlas_text_width
	ui.text_height = mu.default_atlas_text_height

	input: Input

	for window.is_running {

		clear_half_transitions(&input)
		wait_for_input(&window, &input)

		mu.begin(&ui)

		if mu.begin_window(&ui, "window", mu.Rect{0, 0, 300, 300}) {

			mu.end_window(&ui)			
		}

		mu.end(&ui)

		ui_cmd: ^mu.Command
		for mu.next_command(&ui, &ui_cmd) {

			switch cmd in ui_cmd.variant {
			case ^mu.Command_Rect:
				mu_col := cmd.color
				mu_col4 := mu_color_to_4f32(cmd.color)

				mu_rect := cmd.rect
				rect := Rect2d{
					[2]f32{f32(mu_rect.x), f32(mu_rect.y)},
					[2]f32{f32(mu_rect.w), f32(mu_rect.h)},
				}
				rect_clipped := clip_to_px_buffer_rect(rect, renderer.pixels_dim)

				draw_rect_px(&renderer, rect_clipped, mu_col4, ) 

			case ^mu.Command_Text:
			case ^mu.Command_Jump:
			case ^mu.Command_Icon:
			case ^mu.Command_Clip:
			}

		}

		display_pixels(&window, renderer.pixels, renderer.pixels_dim)
	}
}

mu_color_to_4f32 :: proc(col: mu.Color) -> [4]f32 {
	col := col
	result := [4]f32{f32(col.r), f32(col.g), f32(col.b), f32(col.a)} / 255
	return result
}
