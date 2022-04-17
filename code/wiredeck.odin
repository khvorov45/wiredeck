package wiredeck

import "core:fmt"
import "core:strings"
import "core:os"

println :: fmt.println
printf :: fmt.printf
tprintf :: fmt.tprintf

State :: struct {
	opened_files:      [dynamic]OpenedFile,
	editing:           Maybe(int),
	sidebar_width:     int,
	sidebar_drag_ref:  Maybe(f32),
	theme_editor_open: bool,
	color_picker_open: [ColorID]bool,
}

OpenedFile :: struct {
	path:                 string,
	fullpath:             string,
	fullpath_col:         [][4]f32, // NOTE(khvorov) Same length as fullpath bytes
	content:              string,
	colors:               [][4]f32, // NOTE(khvorov) Same length as content bytes
	line_count:           int,
	max_col_width_glyphs: int,
	line_offset_lines:    int,
	line_offset_bytes:    int,
	col_offset:           int,
	cursor_scroll_ref:    [2]Maybe(f32),
}

main :: proc() {

	global_arena: StaticArena
	assert(static_arena_init(&global_arena, 1 * GIGABYTE) == .None)
	context.allocator = static_arena_allocator(&global_arena)

	global_scratch: ScratchBuffer
	assert(scratch_buffer_init(&global_scratch, 10 * MEGABYTE) == .None)
	context.temp_allocator = scratch_allocator(&global_scratch)

	window: Window
	init_window(&window, "Wiredeck", 1000, 1000)

	renderer: Renderer
	init_renderer(&renderer, 7680, 4320)

	input: Input
	input.cursor_pos = -1

	monospace_font: Font
	init_font(&monospace_font, "fonts/LiberationMono-Regular.ttf")
	varwidth_font: Font
	init_font(&varwidth_font, "fonts/LiberationSans-Regular.ttf")

	ui: UI
	init_ui(&ui, window.dim.x, window.dim.y, &input, &monospace_font, &varwidth_font)

	state: State
	state.opened_files = buffer_from_slice(make([]OpenedFile, 2048))
	open_file(&state, "build.bat", ui.theme.text_colors)
	open_file(&state, "code/input.odin", ui.theme.text_colors)
	open_file(&state, "tests/highlight-c/highlight-c.c", ui.theme.text_colors)
	state.editing = 2
	state.sidebar_width = 150

	state.theme_editor_open = true

	for window.is_running {

		//
		// SECTION Input
		//

		wait_for_input(&window, &input)

		//
		// SECTION UI
		//

		clear_buffers(&renderer, ui.theme.colors[.Background], window.dim)
		ui.total_dim = renderer.pixels_dim
		ui_begin(&ui)

		// NOTE(khvorov) Theme editor
		if was_pressed(&input, .F11) {
			state.theme_editor_open = !state.theme_editor_open
		}
		if state.theme_editor_open {
			begin_container(&ui, .Right, ui.total_dim.x / 2, {.Left})

			for color_id in ColorID {
				color_id_string := tprintf("%v", color_id)
				button_dim := get_button_dim(&ui, color_id_string)
				begin_container(&ui, .Top, button_dim.y)
				ui.current_layout = .Horizontal

				button_state := button(ui = &ui, label_str = color_id_string, text_align = .Begin)

				begin_container(&ui, .Left, button_dim.y)
				fill_container(&ui, ui.theme.colors[color_id])
				end_container(&ui)

				if button_state == .Clicked {
					state.color_picker_open[color_id] = !state.color_picker_open[color_id]
				}

				if state.color_picker_open[color_id] {
					println("draw color picker for", color_id)
				}

				end_container(&ui)
			}

			end_container(&ui)
		}

		// NOTE(khvorov) Sidebar
		{
			begin_container(&ui, .Left, ContainerResize{&state.sidebar_width, &state.sidebar_drag_ref})
			ui.current_layout = .Vertical

			for opened_file, index in state.opened_files {
				button_state := button(
					ui = &ui,
					label_str = opened_file.fullpath,
					label_col = opened_file.fullpath_col,
					text_align = .End,
				)
				if button_state == .Clicked {
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
		// SECTION Render
		//

		for cmd_ui in ui.commands {
			switch cmd in cmd_ui {
			case UICommandRect:
				draw_rect_px(&renderer, cmd.rect, cmd.color)
			case UICommandTextline:
				draw_text_px(&renderer, ui.fonts[cmd.font_id], cmd.str, cmd.text_topleft, cmd.clip_rect, cmd.colors)
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

		fullpath := get_full_filepath(filepath)
		fullpath_col := highlight_filepath(fullpath, text_cols)

		opened_file := OpenedFile {
			path = strings.clone(filepath),
			fullpath = fullpath,
			fullpath_col = fullpath_col,
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
