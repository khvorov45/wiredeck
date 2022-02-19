package wiredeck

import "core:fmt"
import "core:strings"
import "core:os"

TopBarMenu :: enum {
	None,
	File,
	Edit,
}

State :: struct {
	top_bar_open_menu:     TopBarMenu,
	top_bar_pending_close: bool,
	opened_files:          [dynamic]OpenedFile,
}

OpenedFile :: struct {
	path:    string,
	content: string,
}

main :: proc() {

	window: Window
	init_window(&window, "Wiredeck", 1000, 1000)

	renderer: Renderer
	init_renderer(&renderer, window.dim.x, window.dim.y)

	input: Input
	input.cursor_pos = -1

	font: Font
	init_font(&font, "fonts/LiberationMono-Regular.ttf")

	ui: UI
	init_ui(&ui, window.dim.x, window.dim.y, &input, &font)

	state: State

	for window.is_running {

		//
		// NOTE(khvorov) Input
		//

		clear_half_transitions(&input)

		if state.top_bar_pending_close {
			state.top_bar_pending_close = false
			state.top_bar_open_menu = .None
		} else {
			wait_for_input(&window, &input)
		}

		//
		// NOTE(khvorov) UI
		//

		ui_begin(&ui)

		// NOTE(khvorov) Top bar
		if begin_container(&ui, .Top, font.px_height + ui.theme.sizes[.ButtonPadding]) {
			if !window.is_focused {
				state.top_bar_open_menu = .None
			}

			ui.current_layout = .Horizontal

			file_button_state := button(&ui, "File", state.top_bar_open_menu == .File)
			file_button_rect := ui.last_element_rect

			edit_button_state := button(&ui, "Edit", state.top_bar_open_menu == .Edit)
			edit_button_rect := ui.last_element_rect

			if state.top_bar_open_menu != .None {
				if file_button_state == .Hovered {
					state.top_bar_open_menu = .File
				}
				if edit_button_state == .Hovered {
					state.top_bar_open_menu = .Edit
				}
			}

			if file_button_state == .Clicked {
				state.top_bar_open_menu = .None if state.top_bar_open_menu == .File else .File
			}

			if edit_button_state == .Clicked {
				state.top_bar_open_menu = .None if state.top_bar_open_menu == .Edit else .Edit
			}

			float_rect: Rect2i
			if state.top_bar_open_menu != .None {
				ref: Rect2i
				#partial switch state.top_bar_open_menu {
				case .File:
					ref = file_button_rect
				case .Edit:
					ref = edit_button_rect
				}

				if begin_floating(&ui, .Bottom, 100, &ref) {
					float_rect = ui.container_stack[len(ui.container_stack) - 1]

					ui.current_layout = .Vertical

					#partial switch state.top_bar_open_menu {
					case .File:
						if button(&ui, "Open file", false, .Begin) == .Clicked {
							filepath := get_path_from_platform_file_dialog(.File)
							if filepath != "" {
								open_file(&state, filepath)
							}
						}

						if button(&ui, "Open folder", false, .Begin) == .Clicked {
							dirpath := get_path_from_platform_file_dialog(.Folder)
							if dirpath == "" {
								fmt.println("open folder: dialog closed")
							} else {
								fmt.println("open folder: ", dirpath)
							}
						}

					case .Edit:
					}

					end_floating(&ui)
				}
			}

			if state.top_bar_open_menu != .None {
				if was_unpressed(&input, .MouseLeft) || was_unpressed(&input, .MouseRight) {
					file_pressed := point_inside_rect(input.cursor_pos, file_button_rect)
					edit_pressed := point_inside_rect(input.cursor_pos, edit_button_rect)
					float_pressed := point_inside_rect(input.cursor_pos, float_rect)
					if !file_pressed && !edit_pressed && !float_pressed {
						state.top_bar_pending_close = true
					}
				}
			}

			end_container(&ui)
		}

		// NOTE(khvorov) Bottom bar
		if begin_container(&ui, .Bottom, font.px_height + ui.theme.sizes[.ButtonPadding]) {
			ui.current_layout = .Horizontal
			end_container(&ui)
		}

		// NOTE(khvorov) Sidebar
		if begin_container(&ui, .Left, 153) {
			ui.current_layout = .Vertical

			for opened_file in state.opened_files {
				button(&ui, opened_file.path, false, .Begin, state.top_bar_open_menu == .None)
			}

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
				draw_text_px(&renderer, &font, cmd.str, cmd.text_topleft, cmd.clip_rect, cmd.color)
			}
		}

		display_pixels(&window, renderer.pixels, renderer.pixels_dim)
	}
}

open_file :: proc(state: ^State, filepath: string) {
	if file_contents, ok := os.read_entire_file(filepath); ok {
		opened_file := OpenedFile {
			path    = strings.clone(filepath),
			content = string(file_contents),
		}
		append(&state.opened_files, opened_file)
	}
}
