package wiredeck

import "core:fmt"
import "core:strings"

println :: fmt.println
printf :: fmt.printf
tprintf :: fmt.tprintf

ColorPickerState :: struct {
	open: bool,
	hue, sat: f32,
	hue_drag, grad2d_drag: Maybe(DragRef),
}

OpenedFile :: struct {
	path: string,
	fullpath: string,
	fullpath_col: [][4]f32, // NOTE(khvorov) Same length as fullpath bytes
	content: string,
	colors: [][4]f32, // NOTE(khvorov) Same length as content bytes
	line_count: int,
	max_col_width_glyphs: int,
	line_offset_lines: int,
	line_offset_bytes: int,
	col_offset: int,
	cursor_scroll_ref: [2]Maybe(f32),
}

main :: proc() {

	context.allocator = panic_allocator()

	global_arena: StaticArena
	assert(static_arena_init(&global_arena, 1 * GIGABYTE) == .None)
	global_arena_allocator := static_arena_allocator(&global_arena)

	global_scratch: ScratchBuffer
	assert(scratch_buffer_init(&global_scratch, 10 * MEGABYTE, global_arena_allocator) == .None)
	context.temp_allocator = scratch_allocator(&global_scratch)

	global_pool: MemoryPool
	assert(memory_pool_init(&global_pool, 50 * MEGABYTE, global_arena_allocator) == .None)
	global_pool_allocator := pool_allocator(&global_pool)

	window_: Window
	window := &window_
	init_window(window, "Wiredeck", 1000, 1000)

	renderer_: Renderer
	renderer := &renderer_
	init_renderer(renderer, 7680, 4320, global_arena_allocator)

	input_: Input
	input := &input_
	input.cursor_pos = -1

	monospace_font: Font
	init_font(&monospace_font, "fonts/LiberationMono-Regular.ttf", global_arena_allocator, global_pool_allocator)
	varwidth_font: Font
	init_font(&varwidth_font, "fonts/LiberationSans-Regular.ttf", global_arena_allocator, global_pool_allocator)

	ui_: UI
	ui := &ui_
	init_ui(ui, window.dim.x, window.dim.y, input, &monospace_font, &varwidth_font, global_arena_allocator)

	layout_: Layout
	layout := &layout_
	init_layout(layout, global_arena_allocator, global_pool_allocator)

	opened_files_: Freelist(OpenedFile)
	opened_files := &opened_files_
	freelist_init(opened_files, global_pool_allocator)

	attach_panel(layout, &layout.root, add_panel(layout, "FileContentViewer", FileContentViewer{}))
	layout_edit_mode_active := false

	for window.is_running {

		//
		// SECTION Input
		//

		wait_for_input(window, input)

		if was_pressed(input, .F1) {
			layout_edit_mode_active = !layout_edit_mode_active
		}

		//
		// SECTION UI
		//

		clear_buffers(renderer, ui.theme.colors[.Background], window.dim)
		ui.total_dim = renderer.pixels_dim
		ui_begin(ui)

		if layout_edit_mode_active {
			build_edit_mode(window, layout, ui)
		} else {
			build_contents(window, layout, ui, opened_files)
		}

		if ui.should_capture_mouse {
			set_mouse_capture(window, true)
		} else {
			set_mouse_capture(window, false)
		}
		set_cursor(window, ui.req_cursor)
		ui_end(ui)

		//
		// SECTION Render
		//

		for cmd_ui in ui.commands {
			switch cmd in cmd_ui {
			case UICommandRect:
				draw_rect_px(renderer, cmd.rect, cmd.color)
			case UICommandTextline:
				draw_text_px(renderer, ui.fonts[cmd.font_id], cmd.str, cmd.text_topleft, cmd.clip_rect, cmd.colors)
			case UICommandRectGradient2d:
				draw_rect_gradient2d(renderer, cmd.grad)
			}
		}

		display_pixels(window, renderer.pixels, renderer.pixels_dim)
	}
}

open_file :: proc(
	filepath: string, text_cols: [TextColorID][4]f32, allocator: Allocator,
) -> (opened_file: Maybe(OpenedFile)) {

	if file_contents, success := read_entire_file(filepath, allocator).([]u8); success {

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

		colors := make([][4]f32, len(str))
		highlight(filepath, str, &colors, text_cols)

		fullpath := get_full_filepath(filepath, allocator)
		fullpath_col := make([][4]f32, len(fullpath))
		highlight_filepath(fullpath, &fullpath_col, text_cols)

		opened_file = OpenedFile {
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
	}

	return opened_file
}

/*
collapsible_color_picker :: proc(
	ui: ^UI, window: ^Window,
	color_id_string: string, state: ^ColorPickerState, cur_color: ^[4]f32, height: int,
) {
	button_dim := get_button_dim(ui, color_id_string)
	begin_container(ui, UIDataContainerBegin{.Top, button_dim.y, {}, nil})
	ui.current_layout = .Horizontal

	button_state := button(ui = ui, label_str = color_id_string, text_align = .Begin)

	begin_container(ui, UIDataContainerBegin{.Left, button_dim.y, {}, nil})
	fill_container(ui, cur_color^)
	end_container(ui)

	ui.current_layout = .Horizontal
	text(ui = ui, label_str = color4f32_to_string(cur_color^, state.hue, state.sat), text_align = .Begin)

	end_container(ui)

	if state.open {
		begin_container(ui, UIDataContainerBegin{.Top, height, {}, nil})

		old_col := cur_color^
		color_picker(
			ui, cur_color, &state.hue, &state.sat,
			&state.hue_drag, &state.grad2d_drag,
		)
		if cur_color^ != old_col {
			window.skip_hang_once = true
		}

		end_container(ui)
	}

	if button_state == .Clicked {
		state.open = !state.open
		window.skip_hang_once = true
	}
}
*/

color4f32_to_string :: proc(col: [4]f32, hue_init, sat_init: f32, allocator := context.temp_allocator) -> string {
	context.allocator = allocator
	col255 := col * 255
	hue, sat, brt := rgb_to_hsv(col.rgb, hue_init, sat_init)
	result := fmt.aprintf(
		"#{0:02x}{1:02x}{2:02x} rgb({0:d}, {1:d}, {2:d}) hsv({3:d}, {4:d}, {5:d})",
		int(col255.r), int(col255.g), int(col255.b), int(hue), int(sat), int(brt),
	)
	return result
}
