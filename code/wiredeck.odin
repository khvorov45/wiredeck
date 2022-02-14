package wiredeck

main :: proc() {

	window: Window
	init_window(&window, "Wiredeck", 1000, 1000)

	renderer: Renderer
	init_renderer(&renderer, window.dim.x, window.dim.y)

	input: Input

	font: Font
	init_font(&font, "fonts/LiberationMono-Regular.ttf")

	ui: UI
	init_ui(&ui, window.dim.x, window.dim.y, &input, &font)

	for window.is_running {

		clear_half_transitions(&input)
		wait_for_input(&window, &input)

		ui_begin(&ui)

		if begin_container(&ui, .Top, font.px_height + ui.theme.sizes[.ButtonPadding]) {
			ui.current_layout = .Horizontal
			dropdown(&ui, "File")
			dropdown(&ui, "Edit")

			end_container(&ui)
		}

		if begin_container(&ui, .Bottom, font.px_height + ui.theme.sizes[.ButtonPadding]) {

			end_container(&ui)
		}

		ui_end(&ui)

		for cmd_ui in ui.commands {
			switch cmd in cmd_ui {
			case UICommandRect:
				draw_rect_px(&renderer, cmd.rect, cmd.color)
			case UICommandText:
				draw_text_px(&renderer, &font, cmd.str, cmd.rect.topleft, cmd.color)
			}
		}

		display_pixels(&window, renderer.pixels, renderer.pixels_dim)
	}
}
