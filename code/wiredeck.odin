package wiredeck

import "core:fmt"
import "core:strings"
import "core:os"

State :: struct {
	top_bar_open_menu:     TopBarMenu,
	top_bar_pending_close: bool,
	opened_files:          [dynamic]OpenedFile,
	editing:               Maybe(int),
}

TopBarMenu :: enum {
	None,
	File,
	Edit,
}

OpenedFile :: struct {
	path:                 string,
	content:              string,

	ch_per_newline:       int,
	line_count:           int,
	max_col_width_glyphs: int,

	line_offset_lines:    int,
	line_offset_bytes:    int,
	col_offset:           int,
	cursor_scroll_ref:    [2]Maybe(f32),
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
	open_file(&state, "build.bat")
	open_file(&state, "code/tinyfiledialogs/tinyfiledialogs.c")
	state.editing = 0

	for window.is_running {

		//
		// NOTE(khvorov) Input
		//

		clear_half_transitions(&input)
		input.scroll = 0
		if !window.is_focused {
			state.top_bar_open_menu = .None
			input = Input{}
		}

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
		if begin_container(&ui, .Top, get_button_dim(&ui).y) {

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
				item_count: int
				#partial switch state.top_bar_open_menu {
				case .File:
					ref = file_button_rect
					item_count = 2
				case .Edit:
					ref = edit_button_rect
					item_count = 3
				}

				float_height := get_button_dim(&ui).y * item_count
				if begin_floating(&ui, .Bottom, [2]int{100, float_height}, &ref) {
					float_rect = last_container(&ui)^

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
		if begin_container(&ui, .Bottom, get_button_dim(&ui).y) {
			ui.current_layout = .Horizontal
			end_container(&ui)
		}

		// NOTE(khvorov) Sidebar
		if begin_container(&ui, .Left, 153) {
			ui.current_layout = .Vertical

			for opened_file, index in state.opened_files {
				if button(&ui, opened_file.path, false, .Begin, state.top_bar_open_menu == .None) == .Clicked {
					state.editing = index
				}
			}

			end_container(&ui)
		}

		separator(&ui, .Vertical)

		// NOTE(khvorov) Editors
		if editing, ok := state.editing.(int); ok {
			file := &state.opened_files[editing]
			text_area(&ui, &state.opened_files[editing])
			if file.cursor_scroll_ref.y != nil || file.cursor_scroll_ref.x != nil {
				set_mouse_capture(&window, true)
			} else {
				set_mouse_capture(&window, false)
			}
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
			case UICommandTextline:
				draw_text_px(&renderer, &font, cmd.str, cmd.text_topleft, cmd.clip_rect, cmd.color)
			}
		}

		display_pixels(&window, renderer.pixels, renderer.pixels_dim)
	}
}

open_file :: proc(state: ^State, filepath: string) {
	if file_contents, ok := os.read_entire_file(filepath); ok {

		// NOTE(khvorov) Count lines and column widths
		file_contents_string := string(file_contents)
		ch_per_newline := 1
		if strings.index(file_contents_string, "\r\n") != -1 {
			ch_per_newline = 2
		}
		line_count := 0
		max_col_width_glyphs := 0
		cur_col_width := 0
		for index := 0; index < len(file_contents_string); index += 1 {
			ch := file_contents_string[index]
			if ch == '\n' || ch == '\r' {
				line_count += 1
				index += ch_per_newline - 1
				max_col_width_glyphs = max(max_col_width_glyphs, cur_col_width)
				cur_col_width = 0
			} else if ch == '\t' {
				cur_col_width += 4
			} else {
				cur_col_width += 1
			}
		}
		// NOTE(khvorov) Account for last line
		max_col_width_glyphs = max(max_col_width_glyphs, cur_col_width)
		line_count += 1 // NOTE(khvorov) Start counting from 1

		opened_file := OpenedFile {
			path = strings.clone(filepath),
			content = file_contents_string,
			line_offset_lines = 0,
			line_offset_bytes = 0,
			col_offset = 0,
			cursor_scroll_ref = {nil, nil},
			line_count = line_count,
			max_col_width_glyphs = max_col_width_glyphs,
			ch_per_newline = ch_per_newline,
		}
		append(&state.opened_files, opened_file)
	}
}
