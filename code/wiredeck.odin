package wiredeck

main :: proc() {

	window: Window
	init_window(&window, "Wiredeck", 1000, 1000)

	renderer: Renderer
	init_renderer(&renderer, window.dim.x, window.dim.y)

	input: Input

	ui: UI
	init_ui(&ui, window.dim.x, window.dim.y, &input)

	for window.is_running {

		clear_half_transitions(&input)
		wait_for_input(&window, &input)

		ui_begin(&ui)

		if begin_container(&ui, .Top, 50, "TopStrip") {
			ui.current_layout = .Horizontal
			dropdown(&ui, "File")

			end_container(&ui)
		}

		ui_end(&ui)

		for cmd_ui in ui.current_commands {
			switch cmd in cmd_ui {
			case UICommandRect:
				draw_rect_px(&renderer, cmd.rect, cmd.color)
			}
		}

		display_pixels(&window, renderer.pixels, renderer.pixels_dim)
	}
}
