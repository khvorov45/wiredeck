package wiredeck

main :: proc() {

	window: Window
	init_window(&window, "Wiredeck", 1000, 1000)

	renderer: Renderer
	init_renderer(&renderer, window.dim.x, window.dim.y)

	input: Input

	for window.is_running {

		clear_half_transitions(&input)
		wait_for_input(&window, &input)

		draw_rect_px(&renderer, Rect2d{{0, 0}, {10, 100}}, [4]f32{1, 0, 0, 1})
		draw_line_px(&renderer, LineSegment2d{{0, 0}, {10, 100}}, [4]f32{0, 1, 0, 1})

		display_pixels(&window, renderer.pixels, renderer.pixels_dim)
	}
}
