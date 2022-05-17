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
	init_font(&monospace_font, get_font_ttf_path(.Monospace), global_arena_allocator, global_pool_allocator)
	varwidth_font: Font
	init_font(&varwidth_font, get_font_ttf_path(.Varwidth), global_arena_allocator, global_pool_allocator)

	ui_: UI
	ui := &ui_
	init_ui(ui, window.dim.x, window.dim.y, input, &monospace_font, &varwidth_font, global_arena_allocator)

	fs_: Filesystem
	fs := &fs_
	init_filesystem(fs, global_arena_allocator, global_pool_allocator)

	open_file(fs, "build.bat", ui.theme.text_colors)

	layout_: Layout
	layout := &layout_
	init_layout(layout, window, ui, fs, global_arena_allocator)

	attach_panel(layout, &layout.root, FileManager{});

	for window.is_running {

		//
		// SECTION Input
		//

		wait_for_input(window, input)

		if was_pressed(input, .F1) {
			layout.edit_mode = !layout.edit_mode
		}

		//
		// SECTION UI
		//

		clear_buffers(renderer, ui.theme.colors[.Background], window.dim)
		ui.total_dim = renderer.pixels_dim
		ui_begin(ui)

		begin_container(ui, .Top, ui.total_dim.y / 2)
		build_layout(layout)
		end_container(ui)

		pool_vis(ui, &global_pool)

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
