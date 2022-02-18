package wiredeck

TopBarMenu :: enum {
	None,
	File,
	Edit,
}

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

	top_bar_open_menu := TopBarMenu.None

	for window.is_running {

		//
		// NOTE(khvorov) Input
		//

		clear_half_transitions(&input)
		wait_for_input(&window, &input)

		//
		// NOTE(khvorov) UI
		//

		ui_begin(&ui)

		// NOTE(khvorov) Top bar
		if begin_container(&ui, .Top, font.px_height + ui.theme.sizes[.ButtonPadding]) {
			if !window.is_focused {
				top_bar_open_menu = .None
			}

			ui.current_layout = .Horizontal

			file_button_state := button(&ui, "File", top_bar_open_menu == .File)
			file_button_rect := ui.last_element_rect

			edit_button_state := button(&ui, "Edit", top_bar_open_menu == .Edit)
			edit_button_rect := ui.last_element_rect

			if top_bar_open_menu != .None {
				if file_button_state == .Hovered {
					top_bar_open_menu = .File
				}
				if edit_button_state == .Hovered {
					top_bar_open_menu = .Edit
				}
			}

			if file_button_state == .Clicked {
				top_bar_open_menu = .None if top_bar_open_menu == .File else .File
			}

			if edit_button_state == .Clicked {
				top_bar_open_menu = .None if top_bar_open_menu == .Edit else .Edit
			}

			float_rect: Rect2i
			if top_bar_open_menu != .None {
				ref: Rect2i
				#partial switch top_bar_open_menu {
				case .File:
					ref = file_button_rect
				case .Edit:
					ref = edit_button_rect
				}

				begin_floating(&ui, .Bottom, 100, &ref)
				float_rect = ui.container_stack[len(ui.container_stack) - 1]
				end_floating(&ui)
			}

			if top_bar_open_menu != .None {
				if was_pressed(&input, .MouseLeft) || was_pressed(&input, .MouseRight) {
					file_pressed := _point_inside_rect(input.cursor_pos, file_button_rect)
					edit_pressed := _point_inside_rect(input.cursor_pos, edit_button_rect)
					float_pressed := _point_inside_rect(input.cursor_pos, float_rect)
					if !file_pressed && !edit_pressed && !float_pressed {
						top_bar_open_menu = .None
					}
				}
			}

			end_container(&ui)
		}

		if begin_container(&ui, .Bottom, font.px_height + ui.theme.sizes[.ButtonPadding]) {

			end_container(&ui)
		}

		if begin_container(&ui, .Left, 150) {
			ui.current_layout = .Vertical

			end_container(&ui)
		}

		ui_end(&ui)

		//
		// NOTE(khvorov) Render
		//

		clear_buffers(&renderer, ui.theme.colors[.Background])

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
