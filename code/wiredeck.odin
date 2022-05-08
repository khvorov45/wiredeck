package wiredeck

import "core:fmt"
import "core:strings"

println :: fmt.println
printf :: fmt.printf
tprintf :: fmt.tprintf

State :: struct {
	opened_files: [dynamic]OpenedFile,
	editing: Maybe(int),
	sidebar_width: int,
	sidebar_drag: Maybe(DragRef),
	theme_editor_open: bool,
	color_pickers: [ColorID]ColorPickerState,
	text_color_pickers: [TextColorID]ColorPickerState,
	theme_editor_scroll_ref: Maybe(f32),
	theme_editor_offset: int,
	theme_editor_width: int,
	theme_editor_drag: Maybe(DragRef),
}

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

	global_arena: StaticArena
	assert(static_arena_init(&global_arena, 1 * GIGABYTE) == .None)
	context.allocator = static_arena_allocator(&global_arena)

	global_scratch: ScratchBuffer
	assert(scratch_buffer_init(&global_scratch, 10 * MEGABYTE) == .None)
	context.temp_allocator = scratch_allocator(&global_scratch)

	window_: Window
	window := &window_
	init_window(window, "Wiredeck", 1000, 1000)

	renderer_: Renderer
	renderer := &renderer_
	init_renderer(renderer, 7680, 4320)

	input_: Input
	input := &input_
	input.cursor_pos = -1

	monospace_font: Font
	init_font(&monospace_font, "fonts/LiberationMono-Regular.ttf")
	varwidth_font: Font
	init_font(&varwidth_font, "fonts/LiberationSans-Regular.ttf")

	ui_: UI
	ui := &ui_
	init_ui(ui, window.dim.x, window.dim.y, input, &monospace_font, &varwidth_font)

	layout_: Layout
	layout := &layout_
	init_layout(layout)

	opened_files_: Freelist(OpenedFile)
	opened_files := &opened_files_
	freelist_init(opened_files)

	open_and_create_panel :: proc(layout: ^Layout, ui: ^UI, opened_files: ^Freelist(OpenedFile), name: string) {
		if file, success := open_file(name, ui.theme.text_colors); success {
			file_in_list := freelist_append(opened_files, file)
			attach_panel(layout, &layout.root, add_panel(layout, name, TextEditor{&file_in_list.entry}))
		}
	}

	open_and_create_panel(layout, ui, opened_files, "build.bat")
	open_and_create_panel(layout, ui, opened_files, "shell.bat")
	open_and_create_panel(layout, ui, opened_files, "sdlbug.c")

	/*ui_data_storage_ := freelist_create(UIData)
	ui_data_storage := &ui_data_storage_

	ui_data_add_container :: proc(storage: ^Freelist(UIData), data: UIDataContainerBegin) -> ^UIDataContainerBegin {
		entry := freelist_append(storage, data)
		entry_data := &entry.entry.(UIDataContainerBegin)
		return entry_data
	}

	ui_root := ui_data_add_container(
		ui_data_storage,
		UIDataContainerBegin{.Left, ContainerResize{100, nil}, {}, nil, freelist_create(^UIData)},
	)*/

	/*
	layout_: Freelist(UIData)
	layout := &layout_
	freelist_init(layout)
	first_container := freelist_append(layout, UIDataContainerBegin{.Left, ContainerResize{100, nil}, {}, nil, freelist_create(^UIData)})
	file_viewer := freelist_append(layout, UIDataOpenedFileViewer{opened_files})

	first_container_data := &first_container.entry.(UIDataContainerBegin)
	freelist_append(first_container_data.contents)

	first_container_contents := freelist_create(^UIData)

	data_opened_file_viewer: UIData = UIDataOpenedFileViewer{opened_files}
	freelist_append(&first_container_contents, &data_opened_file_viewer)

	freelist_append(layout, UIDataOpenedFileViewer{opened_files})
	freelist_append(layout, UIDataContainerEnd{})
	freelist_append(layout, UIDataTextArea{&opened_files.sentinel.next.entry})
	*/

	/*
	state_: State
	state := &state_
	state.opened_files = buffer_from_slice(make([]OpenedFile, 2048))
	open_file(state, "code/input.odin", ui.theme.text_colors)
	open_file(state, "tests/highlight-c.c", ui.theme.text_colors)
	state.editing = 1
	state.sidebar_width = window.dim.x / 3

	for color_id in ColorID {
		state.color_pickers[color_id].hue, _, _ =
			rgb_to_hsv(ui.theme.colors[color_id].rgb, state.color_pickers[color_id].hue, state.color_pickers[color_id].sat)
	}

	state.theme_editor_width = window.dim.x / 2
	state.theme_editor_open = true
	state.text_color_pickers[.FilepathSeparator].open = true
	*/

	for window.is_running {

		//
		// SECTION Input
		//

		wait_for_input(window, input)

		if was_pressed(input, .F1) {
			open_and_create_panel(layout, ui, opened_files, "build.bat")
		}

		//
		// SECTION UI
		//

		clear_buffers(renderer, ui.theme.colors[.Background], window.dim)
		ui.total_dim = renderer.pixels_dim
		ui_begin(ui)

		build_multipanel :: proc(
			window: ^Window, layout: ^Layout, ui: ^UI,
			multipanel: ^Multipanel, opened_files: ^Linkedlist(OpenedFile),
		) {
			button_height := get_button_dim(ui, "T").y

			begin_container(ui, .Top, button_height)
			panel_refs := &multipanel.panel_refs
			for panel_entry := panel_refs.sentinel.next;
				!linkedlist_entry_is_sentinel(panel_refs, panel_entry); {

				panel := &panel_entry.entry.entry

				button_state := button(
					ui = ui,
					label_str = panel.name,
					active = ptr_eq(multipanel.active, panel),
				)
				if button_state == .Clicked {
					multipanel.active = panel
					window.skip_hang_once = true
				}

				if button(ui = ui, label_str = "x") == .Clicked {
					panel_entry = detach_panel(layout, multipanel, panel_entry)
					window.skip_hang_once = true
				} else {
					panel_entry = panel_entry.next
				}
			}
			end_container(ui)

			if multipanel.active != nil {
				switch panel_val in &multipanel.active.contents {
				case Multipanel: build_multipanel(window, layout, ui, &panel_val, opened_files)
				case OpenedFileViewer:
				case TextEditor: text_area(ui, panel_val.opened_file)
				case ThemeEditor:
				}
			}
		}

		begin_container(ui, .Top, ui.total_dim.y / 2)
		build_multipanel(window, layout, ui, &layout.root, &opened_files.used)
		end_container(ui)

		linked_list_vis(ui, "panels_used", &layout.panels.used)
		linked_list_vis(ui, "panels_free", &layout.panels.free)
		linked_list_vis(ui, "root.panel_refs", &layout.root.panel_refs)
		linked_list_vis(ui, "panel_refs_free", &layout.panel_refs_free)

		/*
		for layout_entry := layout.sentinel.next; layout_entry != &layout.sentinel; layout_entry = layout_entry.next {
			switch args_val in &layout_entry.entry {
			case UIDataContainerBegin:
				container_begin(ui, &args_val)
			case UIDataContainerEnd:
				container_end(ui)
			case UIDataTextArea:
				text_area(ui, &args_val)
			case UIDataOpenedFileViewer:
				//clicked := opened_file_viewer(ui, &args_val)
				//add_clicked_to_last_active_container(clicked)
			}
		}
		*/

		/*

		// NOTE(khvorov) Theme editor
		if was_pressed(input, .F11) {
			state.theme_editor_open = !state.theme_editor_open
		}
		if state.theme_editor_open {
			one_color_height := get_button_dim(ui, "").y

			color_picker_height := 200
			open_color_piker_count := 0
			for color in ColorID {
				if state.color_pickers[color].open {
					open_color_piker_count += 1
				}
			}
			for color in TextColorID {
				if state.text_color_pickers[color].open {
					open_color_piker_count += 1
				}
			}

			/*begin_container(ui, .Top, 100)
			end_container(ui)
			begin_container(ui, .Bottom, 100)
			end_container(ui)*/

			theme_editor_height := one_color_height * len(ColorID) + open_color_piker_count * color_picker_height

			begin_container(
				ui, .Right, ContainerResize{&state.theme_editor_width, &state.theme_editor_drag}, {.Left},
				ContainerScroll{
					theme_editor_height,
					&state.theme_editor_offset,
					&state.theme_editor_scroll_ref,
				},
			)

			for color_id in ColorID {
				collapsible_color_picker(
					ui, window,
					tprintf("%v", color_id), &state.color_pickers[color_id],
					&ui.theme.colors[color_id], color_picker_height,
				)
			}

			for color_id in TextColorID {
				old_col := ui.theme.text_colors[color_id]
				collapsible_color_picker(
					ui, window,
					tprintf("Text%v", color_id), &state.text_color_pickers[color_id],
					&ui.theme.text_colors[color_id], color_picker_height,
				)

				if ui.theme.text_colors[color_id] != old_col {
					for opened_file in &state.opened_files {
						using opened_file
						highlight(fullpath, content, &colors, ui.theme.text_colors)
						highlight_filepath(fullpath, &fullpath_col, ui.theme.text_colors)
					}
				}
			}

			end_container(ui)
		}

		// NOTE(khvorov) Sidebar
		{
			begin_container(ui, .Left, ContainerResize{&state.sidebar_width, &state.sidebar_drag})
			ui.current_layout = .Vertical

			for opened_file, index in state.opened_files {
				button_state := button(
					ui = ui,
					label_str = opened_file.fullpath,
					label_col = opened_file.fullpath_col,
					text_align = .End,
				)
				if button_state == .Clicked {
					state.editing = index
				}
			}

			end_container(ui)
		}

		// NOTE(khvorov) Editors
		if editing, ok := state.editing.(int); ok {
			file := state.opened_files[editing]
			text_area(ui, &state.opened_files[editing])
		}
		*/

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

open_file :: proc(filepath: string, text_cols: [TextColorID][4]f32) -> (opened_file: OpenedFile, success: bool) {

	file_contents: []u8
	if file_contents, success = read_entire_file(filepath); success {

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

		fullpath := get_full_filepath(filepath)
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

	return opened_file, success
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
