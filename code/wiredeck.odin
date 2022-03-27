package wiredeck

import "core:fmt"
import "core:strings"
import "core:os"

State :: struct {
	top_bar_open_menu:     TopBarMenu,
	top_bar_pending_close: bool,
	opened_files:          [dynamic]OpenedFile,
	editing:               Maybe(int),
	sidebar_width:         int,
	sidebar_drag_ref:      Maybe(f32),
}

TopBarMenu :: enum {
	None,
	File,
	Edit,
}

OpenedFile :: struct {
	path:                 string,
	content:              string,
	colors:               [][4]f32, // NOTE(sen) Same length as string bytes
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
	open_file(&state, "build.bat", ui.theme.text_colors)
	open_file(&state, "code/tinyfiledialogs/tinyfiledialogs.c", ui.theme.text_colors)
	open_file(&state, "code/input.odin", ui.theme.text_colors)
	state.editing = 0
	state.sidebar_width = 150

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

		ui.total_dim = window.dim
		ui_begin(&ui)

		// NOTE(khvorov) Top bar
		{
			begin_container(&ui, .Top, get_button_dim(&ui).y, {.Bottom})

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
								open_file(&state, filepath, ui.theme.text_colors)
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
		{
			begin_container(&ui, .Bottom, get_button_dim(&ui).y, {.Top})
			ui.current_layout = .Horizontal
			end_container(&ui)
		}

		// NOTE(khvorov) Sidebar
		{
			begin_container(&ui, .Left, ContainerResize{&state.sidebar_width, &state.sidebar_drag_ref})
			ui.current_layout = .Vertical

			for opened_file, index in state.opened_files {
				if button(&ui, opened_file.path, false, .Begin, state.top_bar_open_menu == .None) == .Clicked {
					state.editing = index
				}
			}

			end_container(&ui)
		}

		// NOTE(khvorov) Editors
		if editing, ok := state.editing.(int); ok {
			file := &state.opened_files[editing]
			text_area(&ui, &state.opened_files[editing])
		}

		if ui.should_capture_mouse {
			set_mouse_capture(&window, true)
		} else {
			set_mouse_capture(&window, false)
		}

		set_cursor(&window, ui.req_cursor)

		ui_end(&ui)

		//
		// NOTE(khvorov) Render
		//

		clear_buffers(&renderer, ui.theme.colors[.Background], window.dim)

		for cmd_ui in ui.commands {
			switch cmd in cmd_ui {
			case UICommandRect:
				draw_rect_px(&renderer, cmd.rect, cmd.color)
			case UICommandTextline:
				draw_text_px(&renderer, &font, cmd.str, cmd.text_topleft, cmd.clip_rect, cmd.colors)
			}
		}

		display_pixels(&window, renderer.pixels, renderer.pixels_dim)
	}
}

open_file :: proc(state: ^State, filepath: string, text_cols: [TextColorID][4]f32) {
	if file_contents, ok := os.read_entire_file(filepath); ok {

		// NOTE(khvorov) Count lines and column widths
		str := string(file_contents)
		line_count := 0
		max_col_width_glyphs := 0
		cur_col_width := 0
		for index := 0; index < len(str); index += 1 {
			ch := str[index]
			if ch == '\n' || ch == '\r' {
				line_count += 1
				next_ch: u8 = 0
				if index + 1 < len(str) {
					next_ch = str[index + 1]
				}
				if ch == '\r' && next_ch == '\n' {
					index += 1
				}
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

		colors := highlight(filepath, str, text_cols)

		opened_file := OpenedFile {
			path = strings.clone(filepath),
			content = str,
			colors = colors,
			line_offset_lines = 0,
			line_offset_bytes = 0,
			col_offset = 0,
			cursor_scroll_ref = {nil, nil},
			line_count = line_count,
			max_col_width_glyphs = max_col_width_glyphs,
		}
		append(&state.opened_files, opened_file)
	}
}
