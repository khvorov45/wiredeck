package wiredeck

import "core:strings"
import "core:fmt"

UI :: struct {
	input:                ^Input,
	fonts:                [FontID]^Font,
	monospace_px_width:   int,
	theme:                Theme,
	total_dim:            [2]int,
	container_stack:      [dynamic]Container,
	commands:             [dynamic]UICommand,
	last_element_rect:    Rect2i,
	floating:             Maybe(Rect2i),
	floating_cmd:         [dynamic]UICommand,
	current_cmd_buffer:   ^[dynamic]UICommand,
	arena:                Arena,
	arena_allocator:      Allocator,
	should_capture_mouse: bool,
	req_cursor:           CursorKind,
}

Container :: struct {
	available: Rect2i,
	visible: Rect2i,
}

Theme :: struct {
	colors: [ColorID][4]f32,
	text_colors: [TextColorID][4]f32,
	sizes:  [SizeID]int,
}

FontID :: enum {
	Monospace,
	Varwidth,
}

ColorID :: enum {
	Background,
	BackgroundFloating,
	BackgroundHovered,
	LineNumber,
	Border,
	ScrollbarTrack,
	ScrollbarThumb,
	ScrollbarThumbHovered,
}

TextColorID :: enum {
	Normal,
	Comment,
	Punctuation,
	FilepathSeparator,
}

SizeID :: enum {
	ButtonPadding,
	Separator,
	TextAreaGutter,
	ScrollbarWidth,
	ScrollbarThumbLengthMin,
	ScrollbarIncPerLine,
	ScrollbarIncPerCol,
	ScrollContPxPerWheelInc,
}

Rect2i :: struct {
	topleft: [2]int,
	dim:     [2]int,
}

Direction :: enum {
	Top,
	Right,
	Bottom,
	Left,
}

Directions :: bit_set[Direction]

Orientation :: enum {
	Horizontal,
	Vertical,
}

MouseState :: enum {
	Normal,
	Hovered,
	Pressed,
	Clicked,
	PressedMiddle,
	ClickedMiddle,
}

UICommand :: union {
	UICommandRect,
	UICommandTextline,
	UICommandRectGradient2d,
}

UICommandRect :: struct {
	rect: Rect2i,
	color: [4]f32,
}

UICommandRectGradient2d :: struct {
	grad: Gradient2d,
}

UICommandTextline :: struct {
	str:          string,
	font_id:      FontID,
	text_topleft: [2]int,
	clip_rect:    Rect2i,
	colors:       union{[4]f32, [][4]f32},
}

Align :: enum {
	Center,
	Begin,
	End,
}

ScrollCommon :: struct {
	orientation: Orientation,
	range: int,
	thumb_size: int,
	track: Rect2i,
	bounding_rect: Rect2i,
}

ScrollDiscrete :: struct {
	inc: f32,
	total_step_count: int,
}

ScrollContinuous :: struct {
	offset_delta_per_px_scroll: f32,
	px_scroll_per_wheel_inc: int,
}

ScrollSpec :: struct {
	orientation: Orientation,
	range: int,
	thumb_size: int,
	track: Rect2i,
	bounding_rect: Rect2i,
	specific: union {
		ScrollDiscrete,
		ScrollContinuous,
	},
}

ContainerResize :: struct {
	size: ^int,
	sep_drag: ^Maybe(DragRef),
}

ContainerScroll :: struct {
	height: int,
	offset: ^int,
	ref: ^Maybe(f32),
}

DragRef :: struct {
	ref: [2]f32,
	cursor_delta: [2]f32,
}

init_ui :: proc(
	ui: ^UI, width, height: int, input: ^Input,
	monospace_font: ^Font, varwidth_font: ^Font,
	allocator: Allocator,
) {

	theme: Theme

	theme.colors[.Background] = [4]f32{0.05, 0.05, 0.05, 1}
	theme.colors[.BackgroundFloating] = [4]f32{0.1, 0.1, 0.1, 1}
	theme.colors[.BackgroundHovered] = [4]f32{0.2, 0.2, 0.2, 1}
	theme.colors[.Border] = [4]f32{0.2, 0.2, 0.2, 1}
	theme.colors[.LineNumber] = [4]f32{0.7, 0.7, 0.7, 1}
	theme.colors[.ScrollbarTrack] = [4]f32{0.1, 0.1, 0.1, 1}
	theme.colors[.ScrollbarThumb] = [4]f32{0.3, 0.3, 0.3, 1}
	theme.colors[.ScrollbarThumbHovered] = [4]f32{0.7, 0.7, 0.7, 1}

	theme.text_colors[.Normal] = [4]f32{0.9, 0.9, 0.9, 1}
	theme.text_colors[.Comment] = [4]f32{0.5, 0.5, 0.5, 1}
	theme.text_colors[.Punctuation] = [4]f32{0.8, 0.8, 0, 1}
	theme.text_colors[.FilepathSeparator] = [4]f32{255, 192, 146, 255} / 255

	theme.sizes[.ButtonPadding] = 5
	theme.sizes[.Separator] = 5
	theme.sizes[.TextAreaGutter] = 5
	theme.sizes[.ScrollbarWidth] = 10
	theme.sizes[.ScrollbarThumbLengthMin] = 40
	theme.sizes[.ScrollbarIncPerLine] = 20
	theme.sizes[.ScrollbarIncPerCol] = 20
	theme.sizes[.ScrollContPxPerWheelInc] = 10

	fonts: [FontID]^Font
	fonts[.Monospace] = monospace_font
	fonts[.Varwidth] = varwidth_font

	ui^ = UI {
		input = input,
		fonts = fonts,
		monospace_px_width = get_glyph_info(monospace_font, 'a').advance_x,
		theme = theme,
		total_dim = [2]int{width, height},
		container_stack = buffer_from_slice(make([]Container, 100, allocator)),
		commands = buffer_from_slice(make([]UICommand, 1000, allocator)),
		last_element_rect = Rect2i{},
		floating = nil,
		floating_cmd = buffer_from_slice(make([]UICommand, 100, allocator)),
		current_cmd_buffer = nil,
	}

	arena_init(&ui.arena, make([]u8, 4 * MEGABYTE, allocator))
	ui.arena_allocator = arena_allocator(&ui.arena)
}

ui_begin :: proc(ui: ^UI) {
	clear(&ui.commands)
	clear(&ui.container_stack)
	root_rect := Rect2i{{0, 0}, ui.total_dim}
	append(&ui.container_stack, Container{root_rect, root_rect})
	ui.last_element_rect = Rect2i{}
	ui.floating = nil
	clear(&ui.floating_cmd)
	ui.current_cmd_buffer = &ui.commands
	ui.should_capture_mouse = false
	ui.req_cursor = .Normal
	free_all(ui.arena_allocator)
}

ui_end :: proc(ui: ^UI) {
	for cmd in ui.floating_cmd {
		append(&ui.commands, cmd)
	}
}

begin_container :: proc(
	ui: ^UI,
	dir: Direction,
	size_init: union{int, ContainerResize},
	border: Directions = nil,
	scroll_spec: Maybe(ContainerScroll) = nil,
) {
	size_after_resize: int
	sep_drag: Maybe(DragRef)
	resisable := false
	switch val in size_init {
	case int:
		size_after_resize = val
	case ContainerResize:
		size_after_resize = val.size^
		sep_drag = val.sep_drag^
		resisable = true
	}

	if resisable {
		sep_is_vertical := true
		if dir == .Top || dir == .Bottom {
			sep_is_vertical = false
		}

		size_after_resize = max(size_after_resize, 0)
		last_container_rect := last_container(ui)^
		container_rect_init := _take_rect_from_container(&last_container_rect, dir, size_after_resize)
		size_after_resize = container_rect_init.dim.y
		if sep_is_vertical {
			size_after_resize = container_rect_init.dim.x
		}
		separator_rect_init := _take_rect_from_rect(&container_rect_init, dir_opposite(dir), ui.theme.sizes[.Separator])

		drag_delta := _update_drag_ref(ui, &sep_drag, separator_rect_init, last_container(ui).available)

		if dir == .Right || dir == .Bottom {
			drag_delta = -drag_delta
		}

		if sep_is_vertical {
			size_after_resize += int(drag_delta.x)
		} else {
			size_after_resize += int(drag_delta.y)
		}


		if sep_drag != nil || _get_rect_mouse_state(ui.input, separator_rect_init) > .Normal {
			ui.req_cursor = .SizeNS
			if sep_is_vertical {
				ui.req_cursor = .SizeWE
			}
		}
	}

	full_rect := _take_rect_from_container(last_container(ui), dir, size_after_resize)
	visible_rect := clip_rect_to_rect(full_rect, last_container(ui).visible)
	if scroll_spec != nil {
		full_rect.dim.y = max(full_rect.dim.y, scroll_spec.(ContainerScroll).height)
	}
	content_rect := full_rect

	if .Left in border {
		content_rect.topleft.x += 1
		content_rect.dim.x -= 1
	}
	if .Right in border {
		content_rect.dim.x -= 1
	}
	if .Top in border {
		content_rect.topleft.y += 1
		content_rect.dim.y -= 1
	}
	if .Bottom in border {
		content_rect.dim.y -= 1
	}

	if resisable {
		sep_rect := content_rect

		#partial switch dir {
		case .Left: sep_rect.topleft.x += content_rect.dim.x - ui.theme.sizes[.Separator]
		case .Top: sep_rect.topleft.y += content_rect.dim.y - ui.theme.sizes[.Separator]
		}

		switch dir {
		case .Left, .Right:
			sep_rect.dim.x = ui.theme.sizes[.Separator]
			content_rect.dim.x -= ui.theme.sizes[.Separator]
		case .Top, .Bottom:
			sep_rect.dim.y = ui.theme.sizes[.Separator]
			content_rect.dim.y -= ui.theme.sizes[.Separator]
		}

		#partial switch dir {
		case .Right: content_rect.topleft.x += sep_rect.dim.x
		case .Bottom: content_rect.topleft.y += sep_rect.dim.y
		}

		_cmd_rect(ui, sep_rect, ui.theme.colors[.Border])
	}

	scroll_offset := 0
	if scroll_spec != nil {
		scroll := scroll_spec.(ContainerScroll)

		bounding_rect := clip_rect_to_rect(content_rect, visible_rect)
		content_rect.dim.x -= ui.theme.sizes[.ScrollbarWidth]
		track := _position_scrollbar_track(
			clip_rect_to_rect(content_rect, visible_rect),
			ui.theme.sizes[.ScrollbarWidth],
			.Vertical,
		)
		_cmd_rect(ui, track, ui.theme.colors[.ScrollbarTrack])

		scroll_ref := _clamp_scroll_ref(track, scroll.ref^, .Vertical)

		scroll_continuous := _get_scroll_continuous(
			track,
			scroll.height,
			ui.theme.sizes[.ScrollbarThumbLengthMin],
			ui.theme.sizes[.ScrollContPxPerWheelInc],
			bounding_rect,
		)

		line_offset, line_offset_delta :=
			_get_scroll_offset_and_delta(ui.input, scroll_ref, scroll.offset^, scroll_continuous)

		thumb_rect := _get_scroll_thumb_rect(line_offset, scroll_continuous)
		thumb_state := _get_rect_mouse_state(ui.input, thumb_rect)
		thumb_color := _get_scroll_thumb_col(ui, thumb_state, scroll_ref, scroll_continuous.range)
		_cmd_rect(ui, thumb_rect, thumb_color)

		scroll.ref^ = _update_scroll_ref(
			ui.input, thumb_state, scroll.ref^, line_offset_delta, scroll_continuous,
		)
		scroll.offset^ = line_offset

		if scroll.ref^ != nil {
			ui.should_capture_mouse = true
		}

		scroll_rate := scroll_continuous.specific.(ScrollContinuous).offset_delta_per_px_scroll
		scroll_offset = int(f32(scroll.offset^) * scroll_rate)
	}

	available_rect := content_rect
	available_rect.topleft.y -= scroll_offset
	append(
		&ui.container_stack,
		Container{available_rect, clip_rect_to_rect(content_rect, visible_rect)},
	)
	_cmd_outline(ui, full_rect, ui.theme.colors[.Border], border)

	if resisable {
		size_init.(ContainerResize).size^ = size_after_resize
		size_init.(ContainerResize).sep_drag^ = sep_drag

		if sep_drag != nil {
			ui.should_capture_mouse = true
		}
	}
}

end_container :: proc(ui: ^UI) {
	pop(&ui.container_stack)
}

begin_floating :: proc(ui: ^UI, dir: Direction, dim: [2]int, ref: ^Rect2i = nil) -> bool {
	result := false
	if ui.floating == nil {
		ui.current_cmd_buffer = &ui.floating_cmd

		rect: Rect2i

		if ref == nil {
			ref^ = ui.last_element_rect
		}
		ref_bottomright := ref.topleft + ref.dim

		rect.dim = dim

		switch dir {
		case .Bottom:
			rect.topleft.x = ref.topleft.x
			rect.topleft.y = ref_bottomright.y
		case .Top:
			rect.topleft.x = ref.topleft.x
			rect.topleft.y = ref.topleft.y - dim.y
		case .Left:
			rect.topleft.x = ref.topleft.x - dim.x
			rect.topleft.y = ref.topleft.y
		case .Right:
			rect.topleft.x = ref_bottomright.x + dim.x
			rect.topleft.y = ref.topleft.y
		}

		append(&ui.container_stack, Container{rect, rect})

		_cmd_rect(ui, rect, ui.theme.colors[.BackgroundFloating])
		_cmd_outline(ui, rect, ui.theme.colors[.Border])

		ui.floating = rect
		result = true
	}
	return result
}

end_floating :: proc(ui: ^UI) {
	pop(&ui.container_stack)
	ui.current_cmd_buffer = &ui.commands
}

button :: proc(
	ui: ^UI,
	label_str: string,
	dir: Direction,
	label_col: Maybe([][4]f32) = nil,
	active: bool = false,
	text_align: Align = .Center,
	process_input: bool = true,
) -> MouseState {

	state := MouseState.Normal
	full, visible := _take_element_from_last_container(ui, get_button_dim(ui, label_str), dir)

	if process_input {
		state = _get_rect_mouse_state(ui.input, visible)
	}

	if state >= .Hovered || active {
		_cmd_rect(ui, visible, ui.theme.colors[.BackgroundHovered])
	}

	if state >= .Hovered {
		ui.req_cursor = .Pointer
	}

	_cmd_textline(ui, full, visible, label_str, label_col, text_align)
	return state
}

text :: proc(
	ui: ^UI,
	label_str: string,
	dir: Direction,
	label_col: Maybe([][4]f32) = nil,
	text_align: Align = .Center,
) {
	full, visible := _take_element_from_last_container(ui, get_button_dim(ui, label_str), dir)
	_cmd_textline(ui, full, visible, label_str, label_col, text_align)
}

text_area :: proc(ui: ^UI, ref: ^FileContentView) {
	assert(ref != nil)
	assert(ref.file != nil)

	file := ref.file

	line_count := file.line_count

	line_count_str := fmt.tprintf("%d", line_count)
	num_rect_dim := [2]int{get_string_width(ui.fonts[.Monospace], line_count_str), ui.fonts[.Monospace].px_height_line}

	text_area_rect := _take_entire_rect(last_container(ui))
	text_rect := text_area_rect
	text_rect.dim -= ui.theme.sizes[.ScrollbarWidth]
	text_rect.dim.x = max(text_rect.dim.x, 0)
	text_rect.dim.y = max(text_rect.dim.y, 0)
	text_rect_max_y := text_rect.topleft.y + text_rect.dim.y

	line_numbers_rect := text_rect
	line_numbers_rect.dim.x = min(num_rect_dim.x + 2 * ui.theme.sizes[.TextAreaGutter], text_rect.dim.x)
	text_rect.dim.x -= line_numbers_rect.dim.x
	text_rect.topleft.x += line_numbers_rect.dim.x
	_cmd_outline(ui, line_numbers_rect, ui.theme.colors[.Border], {.Right})

	// NOTE(khvorov) Scrollbars
	scrollbar_tracks := _position_scrollbar_tracks(text_rect, ui.theme.sizes[.ScrollbarWidth])
	for track in &scrollbar_tracks {
		track = clip_rect_to_rect(track, text_area_rect)
		_cmd_rect(ui, track, ui.theme.colors[.ScrollbarTrack])
	}
	cursor_scroll_ref := _clamp_scroll_refs(scrollbar_tracks, ref.cursor_scroll_ref)

	scroll_discrete := _get_scroll_discrete2(
		scrollbar_tracks,
		[2]f32{f32(ui.theme.sizes[.ScrollbarIncPerCol]), f32(ui.theme.sizes[.ScrollbarIncPerLine])},
		[2]int{file.max_col_width_glyphs - text_rect.dim.x / ui.monospace_px_width, line_count - 1},
		ui.theme.sizes[.ScrollbarThumbLengthMin],
		text_area_rect,
	)

	line_offset, line_offset_delta :=
		_get_scroll_offset_and_delta(ui.input, cursor_scroll_ref.y, ref.line_offset_lines, scroll_discrete.y)

	col_offset, col_offset_delta :=
		_get_scroll_offset_and_delta(ui.input, cursor_scroll_ref.x, ref.col_offset, scroll_discrete.x)

	scrollbar_v_thumb_rect := _get_scroll_thumb_rect(line_offset, scroll_discrete.y)
	scrollbar_v_thumb_state := _get_rect_mouse_state(ui.input, scrollbar_v_thumb_rect)
	scrollbar_v_thumb_color := _get_scroll_thumb_col(ui, scrollbar_v_thumb_state, cursor_scroll_ref.y, scroll_discrete.y.range)
	_cmd_rect(ui, scrollbar_v_thumb_rect, scrollbar_v_thumb_color)

	scrollbar_h_thumb_rect := _get_scroll_thumb_rect(col_offset, scroll_discrete.x)
	scrollbar_h_thumb_state := _get_rect_mouse_state(ui.input, scrollbar_h_thumb_rect)
	scrollbar_h_thumb_color := _get_scroll_thumb_col(ui, scrollbar_h_thumb_state, cursor_scroll_ref.x, scroll_discrete.x.range)
	_cmd_rect(ui, scrollbar_h_thumb_rect, scrollbar_h_thumb_color)

	cursor_scroll_ref.y = _update_scroll_ref(
		ui.input, scrollbar_v_thumb_state, cursor_scroll_ref.y, line_offset_delta, scroll_discrete.y,
	)

	cursor_scroll_ref.x = _update_scroll_ref(
		ui.input, scrollbar_h_thumb_state, cursor_scroll_ref.x, col_offset_delta, scroll_discrete.x,
	)

	// NOTE(sen) Figure out byte offset
	byte_offset := ref.line_offset_bytes
	if line_offset_delta != 0 {
		lines_skipped := 0

		if line_offset_delta > 0 {

			for index := byte_offset; index < len(file.content.str); index += 1 {
				ch := file.content.str[index]
				if ch == '\n' || ch == '\r' {
					lines_skipped += 1
					next_ch: u8 = 0
					if index + 1 < len(file.content.str) {
						next_ch = file.content.str[index + 1]
					}
					if ch == '\r' && next_ch == '\n' {
						index += 1
					}
					if lines_skipped == line_offset_delta {
						byte_offset = index + 1
						break
					}
				}
			}
		} else if line_offset == 0 {
			byte_offset = 0
		} else {

			for index := byte_offset - 1; index >= 0; index -= 1 {
				ch := file.content.str[index]
				if ch == '\n' || ch == '\r' {
					lines_skipped += 1
					if lines_skipped == -(line_offset_delta) + 1 {
						byte_offset = index + 1
						break
					}
					prev_ch: u8 = 0
					if index - 1 >= 0 {
						prev_ch = file.content.str[index - 1]
					}
					if ch == '\n' && prev_ch == '\r' {
						index -= 1
					}
				}
			}
		}
	}
	byte_offset = clamp(byte_offset, 0, len(file.content.str))

	// NOTE(khvorov) Text content
	assert(len(file.content.str) == len(file.content.cols))
	str_left := file.content.str[byte_offset:]
	colors_left := file.content.cols[byte_offset:]
	current_topleft_y := text_area_rect.topleft.y
	current_topleft_x_num := line_numbers_rect.topleft.x + ui.theme.sizes[.TextAreaGutter]
	current_topleft_x_line := text_rect.topleft.x
	current_line_number := 1 + line_offset
	for {

		// NOTE(khvorov) Line content
		line_end_index := strings.index_any(str_left, "\r\n")
		if line_end_index == -1 {
			line_end_index = len(str_left)
		}

		line := str_left[:line_end_index]
		line_col := colors_left[:line_end_index]

		current_line_topleft := [2]int{current_topleft_x_line - col_offset * ui.monospace_px_width, current_topleft_y}
		append(
			ui.current_cmd_buffer,
			UICommandTextline{line, .Monospace, current_line_topleft, text_rect, line_col},
		)

		str_left = str_left[line_end_index:]
		colors_left = colors_left[line_end_index:]
		skip_count := 0
		for len(str_left) > 0 {
			ch := str_left[0]
			if ch == '\n' || ch == '\r' {
				skip_count += 1
				next_ch: u8 = 0
				if len(str_left) > 1 {
					next_ch = str_left[1]
				}
				if ch == '\r' && next_ch == '\n' {
					str_left = str_left[2:]
					colors_left = colors_left[2:]
				} else {
					str_left = str_left[1:]
					colors_left = colors_left[1:]
				}
			} else {
				break
			}
		}

		// NOTE(khvorov) Line number
		line_number_count := max(skip_count, 1)
		for line_index in 0 ..< line_number_count {
			num_string: string
			{
				context.allocator = ui.arena_allocator
				num_string = fmt.aprintf("%d", current_line_number)
			}
			current_num_topleft := [2]int{current_topleft_x_num, current_topleft_y}
			append(
				ui.current_cmd_buffer,
				UICommandTextline{num_string, .Monospace, current_num_topleft, line_numbers_rect, ui.theme.colors[.LineNumber]},
			)
			current_line_number += 1
			current_topleft_y += ui.fonts[.Monospace].px_height_line
		}

		if skip_count == 0 || current_topleft_y > text_rect_max_y {
			break
		}
	}

	ref.line_offset_lines = line_offset
	ref.line_offset_bytes = byte_offset
	ref.cursor_scroll_ref = cursor_scroll_ref
	ref.col_offset = col_offset

	if cursor_scroll_ref.y != nil || cursor_scroll_ref.x != nil {
		ui.should_capture_mouse = true
	}
}

color_picker :: proc(
	ui: ^UI, sel_rgba: ^[4]f32, sel_hue_init: ^f32, sel_sat_init: ^f32,
	hue_drag, grad2d_drag: ^Maybe(DragRef),
) {

	full_rect := _take_entire_rect(last_container(ui))
	visible_rect := clip_rect_to_rect(full_rect, last_container(ui).visible)

	full_rect_copy := full_rect
	gap_size := 10
	hue_size := 30
	picker2d_rect := _take_rect_from_rect(&full_rect_copy, .Left, full_rect.dim.x - hue_size - gap_size * 2)
	_take_rect_from_rect(&full_rect_copy, .Left, gap_size)
	hue_rect := _take_rect_from_rect(&full_rect_copy, .Left, hue_size)

	subhue_rect_height := hue_rect.dim.y / 6
	picker2d_rect.dim.y = subhue_rect_height * 6
	hue_rect.dim.y = picker2d_rect.dim.y

	color4point_hue_all: [6]Color4point
	subhue_rect_all: [6]Rect2i
	hue_top: f32 = 0
	hue_bottom: f32 = 59
	hue_rect_copy := hue_rect
	for color4point_hue, index in &color4point_hue_all {
		color4point_hue = Color4point{
			topleft = hsv_to_rgb(hue_top, 100, 100),
			topright = hsv_to_rgb(hue_top, 100, 100),
			bottomleft = hsv_to_rgb(hue_bottom, 100, 100),
			bottomright = hsv_to_rgb(hue_bottom, 100, 100),
		}
		subhue_rect_all[index] = _take_rect_from_rect(&hue_rect_copy, .Top, subhue_rect_height)
		hue_top += 60
		hue_bottom += 60
	}

	cmd_grad2d :: proc(ui: ^UI, grad: Color4point, og: Rect2i) {
		clipped_rect := clip_rect_to_rect(og, last_container(ui).visible)
		clipped_grad := clip_color4point(grad, og, clipped_rect)
		append(ui.current_cmd_buffer, UICommandRectGradient2d{{clipped_rect, clipped_grad}})
	}

	for color4point_hue, index in color4point_hue_all {
		cmd_grad2d(ui, color4point_hue, subhue_rect_all[index])
	}

	sel_hue, sel_sat, sel_brt := rgb_to_hsv(sel_rgba.rgb, sel_hue_init^, sel_sat_init^)

	get_sel_hue_outline :: proc(sel_hue: f32, hue_rect: Rect2i) -> Rect2i {
		sel_hue_outline_height := 5
		sel_hue_outline_start_y :=
			int(f32(sel_hue) / 359 * f32(hue_rect.dim.y - 1)) + hue_rect.topleft.y - sel_hue_outline_height / 2
		sel_hue_outline := Rect2i{
			[2]int{hue_rect.topleft.x, sel_hue_outline_start_y},
			[2]int{hue_rect.dim.x, sel_hue_outline_height},
		}
		return sel_hue_outline
	}

	sel_hue_outline := get_sel_hue_outline(sel_hue, hue_rect)
	if _get_rect_mouse_state(ui.input, clip_rect_to_rect(hue_rect, visible_rect)) == .Pressed &&
		_get_rect_mouse_state(ui.input, clip_rect_to_rect(sel_hue_outline, visible_rect)) == .Normal {
		sel_hue = f32(ui.input.cursor_pos.y - hue_rect.topleft.y) / f32(hue_rect.dim.y - 1) * 359
		sel_hue_outline = get_sel_hue_outline(sel_hue, hue_rect)
	}

	hue_drag_delta := _update_drag_ref(
		ui, hue_drag,
		clip_rect_to_rect(sel_hue_outline, visible_rect),
		clip_rect_to_rect(hue_rect, visible_rect),
	)
	sel_hue_outline.topleft.y += int(hue_drag_delta.y)
	sel_hue = clamp(sel_hue + hue_drag_delta.y / f32(hue_rect.dim.y - 1) * 359, 0, 359)

	cmd_double_outline :: proc(ui: ^UI, outline, clip: Rect2i) {
		outline := outline
		_cmd_outline(ui = ui, rect = outline, color = [4]f32{0.25, 0.25, 0.25, 1}, clip_rect = clip)
		outline.topleft -= 1
		outline.dim += 2
		_cmd_outline(ui = ui, rect = outline, color = [4]f32{0.75, 0.75, 0.75, 1}, clip_rect = clip)
	}

	cmd_double_outline(ui, sel_hue_outline, visible_rect)

	color4point_picker2d := Color4point{
		topleft = hsv_to_rgb(sel_hue, 0, 100),
		topright = hsv_to_rgb(sel_hue, 100, 100),
		bottomleft = hsv_to_rgb(sel_hue, 0, 0),
		bottomright = hsv_to_rgb(sel_hue, 100, 0),
	}

	cmd_grad2d(ui, color4point_picker2d, picker2d_rect)

	get_sel_2d_outline :: proc(sel_sat, sel_brt: f32, picker2d_rect: Rect2i) -> Rect2i {
		outline_dim := [2]int{5, 5}
		outline_center := [2]f32{sel_sat, 100 - sel_brt} / 100 * to_2f32(picker2d_rect.dim - 1) + to_2f32(picker2d_rect.topleft)
		outline_topleft := outline_center - to_2f32(outline_dim) / 2
		outline := Rect2i{to_2int(outline_topleft + 0.5), outline_dim}
		return outline
	}

	sel_2d_outline := get_sel_2d_outline(sel_sat, sel_brt, picker2d_rect)
	if _get_rect_mouse_state(ui.input, clip_rect_to_rect(picker2d_rect, visible_rect)) == .Pressed &&
		_get_rect_mouse_state(ui.input, clip_rect_to_rect(sel_2d_outline, visible_rect)) == .Normal {
		sel_sat = f32(ui.input.cursor_pos.x - picker2d_rect.topleft.x) / f32(picker2d_rect.dim.x - 1) * 100
		sel_brt = 100 - f32(ui.input.cursor_pos.y - picker2d_rect.topleft.y) / f32(picker2d_rect.dim.y - 1) * 100
		sel_2d_outline = get_sel_2d_outline(sel_sat, sel_brt, picker2d_rect)
	}

	sel_2d_drag_delta := _update_drag_ref(
		ui, grad2d_drag,
		clip_rect_to_rect(sel_2d_outline, visible_rect),
		clip_rect_to_rect(picker2d_rect, visible_rect),
		true,
	)
	sel_sat = clamp(sel_sat + sel_2d_drag_delta.x / f32(picker2d_rect.dim.x - 1) * 100, 0, 100)
	sel_brt = clamp(sel_brt - sel_2d_drag_delta.y / f32(picker2d_rect.dim.y - 1) * 100, 0, 100)
	sel_2d_outline = get_sel_2d_outline(sel_sat, sel_brt, picker2d_rect)

	cmd_double_outline(ui, sel_2d_outline, clip_rect_to_rect(picker2d_rect, visible_rect))

	sel_rgba^ = hsv_to_rgb(sel_hue, sel_sat, sel_brt)
	sel_hue_init^ = sel_hue
	sel_sat_init^ = sel_sat

	if hue_drag^ != nil || grad2d_drag^ != nil {
		ui.should_capture_mouse = true
	}
}

linked_list_vis :: proc(ui: ^UI, name: string, list: ^Linkedlist($EntryType)) {
	full_rect, visible_rect := _take_element_from_last_container(ui, [2]int{100, 50}, .Top)

	entry_dim := [2]int{20, 20}
	cur_entry_rect := Rect2i{full_rect.topleft, entry_dim}
	cur_entry_rect.topleft.y += full_rect.dim.y / 2 - cur_entry_rect.dim.y / 2

	label_rect := cur_entry_rect
	label_rect.dim = [2]int{full_rect.dim.x, 20}
	label_rect.topleft.y -= label_rect.dim.y
	_cmd_textline(ui = ui, full = label_rect, visible = visible_rect, label_str = name, text_align = .Begin)

	_cmd_rect(ui, clip_rect_to_rect(cur_entry_rect, visible_rect), [4]f32{1, 0, 0, 1})

	for entry := list.sentinel.next; !linkedlist_entry_is_sentinel(list, entry); entry = entry.next {
		cur_entry_rect.topleft.x += entry_dim.x + 10
		_cmd_rect(ui, clip_rect_to_rect(cur_entry_rect, visible_rect), [4]f32{1, 1, 0, 1})
	}
}

pool_vis :: proc(ui: ^UI, pool: ^MemoryPool) {
	full_rect, visible_rect := _take_element_from_last_container(ui, [2]int{100, 50}, .Top)

	bytes_over_pixels := 1024 * 100
	cur_chunk_rect := Rect2i{full_rect.topleft, [2]int{0, 10}}

	for chunk := pool.first_chunk; chunk != nil; chunk = chunk.next {

		cur_chunk_rect.dim.x = chunk.size / bytes_over_pixels
		_cmd_rect(ui, clip_rect_to_rect(cur_chunk_rect, visible_rect), [4]f32{0, 1, 0, 1})

		if chunk.first_marker.free_till_next {
			assert(uintptr(chunk.first_marker) == uintptr(chunk) + size_of(chunk))
		}

		for marker := chunk.first_marker; marker != nil; marker = marker.next {

			assert(marker.next == nil || marker.next.prev == marker)
			assert(marker.prev == nil || marker.prev.next == marker)

			marker_rect := cur_chunk_rect
			marker_rect.dim.x = 2

			bytes_to_marker := int(uintptr(rawptr(marker)) - uintptr(rawptr(chunk)))
			px_to_marker := bytes_to_marker / bytes_over_pixels
			marker_rect.topleft.x += px_to_marker
			_cmd_rect(ui, clip_rect_to_rect(marker_rect, visible_rect), [4]f32{1, 1, 1, 1})

			if !marker.free_till_next {
				next_pos := uintptr(marker.next)
				if next_pos == 0 {
					next_pos = uintptr(rawptr(chunk)) + uintptr(chunk.size)
				}

				bytes_to_next := int(next_pos - uintptr(rawptr(chunk)))
				px_to_next := bytes_to_next / bytes_over_pixels

				marker_next_rect := marker_rect
				marker_next_rect.topleft.x += marker_rect.dim.x
				marker_next_rect.dim.x = px_to_next - px_to_marker - marker_rect.dim.x
				_cmd_rect(ui, clip_rect_to_rect(marker_next_rect, visible_rect), [4]f32{1, 0, 0, 1})
			}
		}

		cur_chunk_rect.topleft.x += cur_chunk_rect.dim.x + 10
	}

}

fill_container :: proc(ui: ^UI, color: [4]f32) {
	rect := last_container(ui).visible
	_cmd_rect(ui, rect, color)
}

get_button_pad :: proc(ui: ^UI) -> [2][2]int {
	pad := ui.theme.sizes[.ButtonPadding]
	padding: [2][2]int
	padding.x = [2]int{pad, pad}
	padding.y = [2]int{0, pad}
	return padding
}

get_button_dim :: proc(ui: ^UI, label: string = "") -> [2]int {
	text_width := get_string_width(ui.fonts[.Varwidth], label)
	text_height := ui.fonts[.Varwidth].px_height_line
	padding := get_button_pad(ui)
	result := [2]int{
		text_width + padding.x[0] + padding.x[1],
		text_height + padding.y[0] + padding.y[1],
	}
	return result
}

point_inside_rect :: proc(point: [2]int, rect: Rect2i) -> bool {
	rect_bottomright := rect.topleft + rect.dim
	x_overlaps := point.x >= rect.topleft.x && point.x < rect_bottomright.x
	y_overlaps := point.y >= rect.topleft.y && point.y < rect_bottomright.y
	result := x_overlaps && y_overlaps
	return result
}

last_container :: proc(ui: ^UI) -> ^Container {
	result := &ui.container_stack[len(ui.container_stack) - 1]
	return result
}

dir_opposite :: proc(dir: Direction) -> Direction {
	result: Direction
	switch dir {
	case .Top:
		result = .Bottom
	case .Bottom:
		result = .Top
	case .Left:
		result = .Right
	case .Right:
		result = .Left
	}
	return result
}

get_rect_center_f32 :: proc(rect: Rect2i) -> [2]f32 {
	result := to_2f32(rect.topleft) + 0.5 * to_2f32(rect.dim - 1)
	return result
}

rgb_to_hsv :: proc(rgb: [3]f32, hue_default, sat_default: f32) -> (hue: f32, sat: f32, brt: f32) {
	range: f32
	rgb_max: f32
	hue_loc: f32

	switch {
	case rgb.r == rgb.b && rgb.b == rgb.g:
		rgb_max = rgb.r
		range = 0
		hue_loc = f32(hue_default) / 60
	case rgb.r >= rgb.g && rgb.g >= rgb.b:
		rgb_max = rgb.r
		rgb_min := rgb.b
		range = rgb_max - rgb_min
		grad := (rgb.g - rgb_min) / range
		hue_loc = grad + 0
	case rgb.g >= rgb.r && rgb.r >= rgb.b:
		rgb_max = rgb.g
		rgb_min := rgb.b
		range = rgb_max - rgb_min
		grad := (rgb.r - rgb.b) / range
		hue_loc = (1 - grad) + 1
	case rgb.g >= rgb.b && rgb.b >= rgb.r:
		rgb_max = rgb.g
		rgb_min := rgb.r
		range = rgb_max - rgb_min
		grad := (rgb.b - rgb_min) / range
		hue_loc = grad + 2
	case rgb.b >= rgb.g && rgb.g >= rgb.r:
		rgb_max = rgb.b
		rgb_min := rgb.r
		range = rgb_max - rgb_min
		grad := (rgb.g - rgb_min) / range
		hue_loc = (1 - grad) + 3
	case rgb.b >= rgb.r && rgb.r >= rgb.g:
		rgb_max = rgb.b
		rgb_min := rgb.g
		range = rgb_max - rgb_min
		grad := (rgb.r - rgb_min) / range
		hue_loc = grad + 4
	case rgb.r >= rgb.b && rgb.b >= rgb.g:
		rgb_max = rgb.r
		rgb_min := rgb.g
		range = rgb_max - rgb_min
		grad := (rgb.b - rgb_min) / range
		hue_loc = (1 - grad) + 5
	case: panic("undexpected color")
	}

	brt = rgb_max * 100
	sat = sat_default
	if rgb_max != 0 {
		sat = range / rgb_max * 100
	}
	hue = hue_loc * 60

	return hue, sat, brt
}

hsv_to_rgb :: proc(hue, sat, brt: f32) -> [4]f32 {
	assert(hue >= 0 && hue < 360 && sat >= 0 && sat <= 100 && brt >= 0 && brt <= 100)

	rgb_max := f32(brt) / 100
	range := rgb_max * f32(sat) / 100
	hue_loc := f32(hue) / 60

	result: [4]f32
	switch {
	case hue_loc < 1:
		grad := hue_loc - 0
		other := grad * range
		result = [4]f32{range, other, 0, 1}
	case hue_loc < 2:
		grad := 1 - (hue_loc - 1)
		other := grad * range
		result = [4]f32{other, range, 0, 1}
	case hue_loc < 3:
		grad := hue_loc - 2
		other := grad * range
		result = [4]f32{0, range, other, 1}
	case hue_loc < 4:
		grad := 1 - (hue_loc - 3)
		other := grad * range
		result = [4]f32{0, other, range, 1}
	case hue_loc < 5:
		grad := hue_loc - 4
		other := grad * range
		result = [4]f32{other, 0, range, 1}
	case hue_loc < 6:
		grad := 1 - (hue_loc - 5)
		other := grad * range
		result = [4]f32{range, 0, other, 1}
	}

	rgb_min := rgb_max - range
	result.rgb += rgb_min

	return result
}

_take_element_from_last_container :: proc(ui: ^UI, dim: [2]int, dir: Direction) -> (full: Rect2i, visible: Rect2i) {

	size: int
	switch dir {
	case .Top, .Bottom:
		size = dim.y
	case .Left, .Right:
		size = dim.x
	}

	full = _take_rect_from_container(last_container(ui), dir, size)
	ui.last_element_rect = full

	visible = clip_rect_to_rect(full, last_container(ui).visible)

	return full, visible
}

_take_rect_from_container :: proc(from_container: ^Container, dir: Direction, size_init: int) -> Rect2i {
	rect := _take_rect_from_rect(&from_container.available, dir, size_init)
	return rect
}

_take_rect_from_rect :: proc(from: ^Rect2i, dir: Direction, size_init: int) -> (rect: Rect2i) {

	size: int
	switch dir {
	case .Top, .Bottom:
		size = clamp(size_init, 0, from.dim.y)
	case .Left, .Right:
		size = clamp(size_init, 0, from.dim.x)
	}

	switch dir {
	case .Top, .Left:
		rect.topleft = from.topleft
	case .Bottom:
		rect.topleft.x = from.topleft.x
		rect.topleft.y = from.topleft.y + (from.dim.y - size)
	case .Right:
		rect.topleft.x = from.topleft.x + (from.dim.x - size)
		rect.topleft.y = from.topleft.y
	}

	switch dir {
	case .Top, .Bottom:
		rect.dim = [2]int{from.dim.x, size}
	case .Left, .Right:
		rect.dim = [2]int{size, from.dim.y}
	}

	#partial switch dir {
	case .Top:
		from.topleft.y += size
	case .Left:
		from.topleft.x += size
	}

	switch dir {
	case .Top, .Bottom:
		from.dim.y -= size
	case .Left, .Right:
		from.dim.x -= size
	}

	return rect
}

_take_entire_rect :: proc(from: ^Container) -> Rect2i {
	result := from.available
	from.available.topleft += from.available.dim
	from.available.dim = 0
	return result
}

_get_rect_mouse_state :: proc(input: ^Input, rect: Rect2i) -> MouseState {
	state := MouseState.Normal
	if point_inside_rect(input.cursor_pos, rect) {
		state = .Hovered
		mouse_left_down := input.mouse_buttons[.MouseLeft].key.ended_down
		mouse_middle_down := input.mouse_buttons[.MouseMiddle].key.ended_down

		switch {
		case was_pressed(input, .MouseLeft) && mouse_left_down:
			state = .Pressed

		case was_unpressed(input, .MouseLeft) && !mouse_left_down:
			last_pressed_inside := point_inside_rect(input.mouse_buttons[.MouseLeft].last_down_cursor_pos, rect)
			if last_pressed_inside {
				state = .Clicked
			}

		case was_pressed(input, .MouseMiddle) && mouse_middle_down:
			state = .PressedMiddle

		case was_unpressed(input, .MouseMiddle) && !mouse_middle_down:
			last_pressed_inside := point_inside_rect(input.mouse_buttons[.MouseMiddle].last_down_cursor_pos, rect)
			if last_pressed_inside {
				state = .ClickedMiddle
			}
		}
	}
	return state
}

_get_inner_outline :: proc(rect: Rect2i) -> (result: [Direction]Rect2i) {
	top := rect
	top.dim.y = min(1, rect.dim.y)

	bottom := top
	bottom.topleft.y += rect.dim.y - 1

	left := rect
	left.dim.x = min(1, rect.dim.x)

	right := left
	right.topleft.x += rect.dim.x - 1

	result[.Top] = top
	result[.Bottom] = bottom
	result[.Left] = left
	result[.Right] = right

	return result
}

_cmd_rect :: proc(ui: ^UI, rect: Rect2i, color: [4]f32) {
	append(ui.current_cmd_buffer, UICommandRect{rect, color})
}

_cmd_outline :: proc(
	ui: ^UI, rect: Rect2i, color: [4]f32,
	dirs: Directions = {.Top, .Bottom, .Left, .Right},
	clip_rect: Maybe(Rect2i) = nil,
) {
	rects := _get_inner_outline(rect)
	for dir in Direction {
		if dir in dirs {
			outline_rect := rects[dir]
			if clip_rect != nil {
				outline_rect = clip_rect_to_rect(outline_rect, clip_rect.(Rect2i))
			}
			_cmd_rect(ui, outline_rect, color)
		}
	}
}

_cmd_textline :: proc(
	ui: ^UI, full, visible: Rect2i, label_str: string,
	label_col: Maybe([][4]f32) = nil,
	text_align: Align = .Center,
) {
	element_dim := get_button_dim(ui, label_str)

	element_slack := full.dim - element_dim
	element_topleft := full.topleft
	if text_align == .Center {
		element_topleft += element_slack / 2
	} else if text_align == .End {
		element_topleft += element_slack
	}

	padding := get_button_pad(ui)
	text_topleft := element_topleft
	text_topleft.x += padding.x[0]
	text_topleft.y += padding.y[0]
	col: union{[4]f32, [][4]f32}

	if label_col != nil {
		col = label_col.([][4]f32)
	} else {
		col = ui.theme.text_colors[.Normal]
	}

	append(
		ui.current_cmd_buffer,
		UICommandTextline{
			strings.clone(label_str, ui.arena_allocator), .Varwidth,
			text_topleft, visible, col,
		},
	)
}

_position_scrollbar_track :: proc(rect: Rect2i, size: int, orientation: Orientation) -> Rect2i {
	track := rect
	switch orientation {
	case .Horizontal:
		track.topleft.y += rect.dim.y
		track.dim.y = size
	case .Vertical:
		track.topleft.x += rect.dim.x
		track.dim.x = size
	}
	return track
}

_position_scrollbar_tracks :: proc(rect: Rect2i, size: int) -> (tracks: [2]Rect2i) {
	tracks.x = _position_scrollbar_track(rect, size, .Horizontal)
	tracks.y = _position_scrollbar_track(rect, size, .Vertical)
	return tracks
}

_clamp_scroll_ref :: proc(track: Rect2i, ref_init: Maybe(f32), orientation: Orientation) -> Maybe(f32) {
	ref := ref_init
	switch orientation {
	case .Horizontal:
	if ref_init != nil {
		ref = clamp(
			ref_init.(f32),
			f32(track.topleft.x),
			f32(track.topleft.x + track.dim.x),
		)
	}
	case .Vertical:
	if ref_init != nil {
		ref = clamp(
			ref_init.(f32),
			f32(track.topleft.y),
			f32(track.topleft.y + track.dim.y),
		)
	}
	}
	return ref
}

_clamp_scroll_refs :: proc(scroll_tracks: [2]Rect2i, refs_init: [2]Maybe(f32)) -> (refs: [2]Maybe(f32)) {
	refs.x = _clamp_scroll_ref(scroll_tracks.x, refs_init.x, .Horizontal)
	refs.y = _clamp_scroll_ref(scroll_tracks.y, refs_init.y, .Vertical)
	return refs
}

_get_scroll_continuous :: proc(
	track: Rect2i, height, thumb_size_min, px_scroll_per_wheel_inc: int,
	bounding_rect: Rect2i,
) -> (result: ScrollSpec) {
	track_len := _get_scroll_track_len(track, .Vertical)
	if height <= track_len {
		result = ScrollSpec{.Vertical, 0, track_len, track, bounding_rect, ScrollContinuous{}}
	} else {
		range := height - track_len
		thumb_size := track_len - range
		if thumb_size < thumb_size_min {
			thumb_size = min(thumb_size_min, track_len / 2)
			range = track_len - thumb_size
		}
		result = ScrollSpec{
			.Vertical, range, thumb_size, track, bounding_rect,
			ScrollContinuous{f32(height - track_len) / f32(range), px_scroll_per_wheel_inc},
		}
	}
	return result
}

_get_scroll_discrete :: proc(
	track: Rect2i, orientation: Orientation, inc_init: f32, total_step_count_init, thumb_size_min: int,
	bounding_rect: Rect2i,
) -> ScrollSpec {
	total_step_count := max(total_step_count_init, 0)
	inc := inc_init
	range := total_step_count * int(inc)
	track_len := _get_scroll_track_len(track, orientation)
	thumb_size := track_len - range
	if thumb_size < thumb_size_min {
		thumb_size = min(thumb_size_min, track_len / 2)
		range = track_len - thumb_size
		if total_step_count > 0 {
			inc = f32(range) / f32(total_step_count)
		}
	}
	result := ScrollSpec{
		orientation, range, thumb_size, track, bounding_rect,
		ScrollDiscrete{inc, total_step_count},
	}
	return result
}

_get_scroll_discrete2 :: proc(
	tracks: [2]Rect2i, inc_init: [2]f32, total_step_count: [2]int, thumb_size_min: int,
	bounding_rect: Rect2i,
) -> (result: [2]ScrollSpec) {
	result.x = _get_scroll_discrete(tracks.x, .Horizontal, inc_init.x, total_step_count.x, thumb_size_min, bounding_rect)
	result.y = _get_scroll_discrete(tracks.y, .Vertical, inc_init.y, total_step_count.y, thumb_size_min, bounding_rect)
	return result
}

_get_scroll_track_len :: proc(track: Rect2i, orientation: Orientation) -> int {
	result: int
	switch orientation {
	case .Horizontal: result = track.dim.x
	case .Vertical: result = track.dim.y
	}
	return result
}

_get_scroll_track_start :: proc(track: Rect2i, orientation: Orientation) -> int {
	result: int
	switch orientation {
	case .Horizontal: result = track.topleft.x
	case .Vertical: result = track.topleft.y
	}
	return result
}

_clamp_scroll_offset :: proc(offset_init: int, settings: ScrollSpec) -> (offset: int) {
	switch val in settings.specific {
	case ScrollDiscrete: offset = clamp(offset_init, 0, val.total_step_count)
	case ScrollContinuous: offset = clamp(offset_init, 0, settings.range)
	}
	return offset
}

_get_scroll_start :: proc(offset_init: int, settings: ScrollSpec) -> int {
	offset := _clamp_scroll_offset(offset_init, settings)
	track_start := _get_scroll_track_start(settings.track, settings.orientation)
	result := track_start
	switch val in settings.specific {
	case ScrollDiscrete:
		if val.total_step_count > 0 {
			result = int(
				f32(offset) / f32(val.total_step_count) * f32(settings.range) + f32(track_start),
			)
		}
	case ScrollContinuous: result = offset + track_start
	}
	return result
}

_get_scroll_thumb_rect :: proc(offset: int, settings: ScrollSpec) -> Rect2i {
	rect := settings.track
	start := _get_scroll_start(offset, settings)
	switch settings.orientation {
	case .Horizontal:
		rect.topleft.x = start
		rect.dim.x = settings.thumb_size
	case .Vertical:
		rect.topleft.y = start
		rect.dim.y = settings.thumb_size
	}
	return rect
}

_get_scroll_cursor_pos :: proc(input: ^Input, settings: ScrollSpec) -> int {
	cursor_pos: int
	switch settings.orientation {
	case .Horizontal: cursor_pos = input.cursor_pos.x
	case .Vertical: cursor_pos = input.cursor_pos.y
	}
	return cursor_pos
}

_get_scroll_offset_and_delta :: proc(
	input: ^Input, scroll_ref: Maybe(f32), old_offset_init: int, settings: ScrollSpec,
) -> (offset: int, delta: int) {

	old_offset := _clamp_scroll_offset(old_offset_init, settings)
	old_thumb_rect := _get_scroll_thumb_rect(old_offset, settings)
	old_thumb_state := _get_rect_mouse_state(input, old_thumb_rect)

	offset_delta := 0
	rect_state := _get_rect_mouse_state(input, settings.track)

	cursor_pos := _get_scroll_cursor_pos(input, settings)

	// NOTE(sen) Drag the scroll thumb
	if scroll_ref != nil {
		scroll_delta_px := f32(cursor_pos) - scroll_ref.(f32)
		switch val in settings.specific {
		case ScrollDiscrete: offset_delta = int(scroll_delta_px / val.inc)
		case ScrollContinuous: offset_delta = int(scroll_delta_px)
		}

	// NOTE(sen) Click on track
	} else if old_thumb_state == .Normal && rect_state == .Pressed {
		center2 := get_rect_center_f32(old_thumb_rect)
		center: f32
		switch settings.orientation {
		case .Horizontal: center = center2.x
		case .Vertical: center = center2.y
		}
		scroll_delta_px := f32(cursor_pos) - center
		switch val in settings.specific {
		case ScrollDiscrete: offset_delta = int(scroll_delta_px / val.inc)
		case ScrollContinuous: offset_delta = int(scroll_delta_px)
		}

	// NOTE(sen) Scroll wheel
	} else if point_inside_rect(input.cursor_pos, settings.bounding_rect) {
		switch settings.orientation {
		case .Horizontal: offset_delta = input.scroll.x
		case .Vertical: offset_delta = input.scroll.y
		}
		if val, ok := settings.specific.(ScrollContinuous); ok {
			offset_delta *= val.px_scroll_per_wheel_inc
		}
	}

	offset = _clamp_scroll_offset(old_offset + offset_delta, settings)
	delta = offset - old_offset
	return offset, delta
}

_get_scroll_thumb_col :: proc(ui: ^UI, state: MouseState, ref: Maybe(f32), range: int) -> [4]f32 {
	color := ui.theme.colors[.ScrollbarThumb]
	if range > 0 && (state > .Normal || ref != nil) {
		color = ui.theme.colors[.ScrollbarThumbHovered]
	}
	return color
}

_update_scroll_ref :: proc(
	input: ^Input, thumb_state: MouseState, ref_init: Maybe(f32),
	offset_delta: int, settings: ScrollSpec,
) -> Maybe(f32) {

	cursor_pos := _get_scroll_cursor_pos(input, settings)
	ref := ref_init
	if thumb_state == .Pressed && ref == nil {
		ref = f32(cursor_pos)
	} else if ref != nil {
		if !input.mouse_buttons[.MouseLeft].key.ended_down {
			ref = nil
		} else {
			switch val in settings.specific {
			case ScrollDiscrete: ref = ref.(f32) + f32(offset_delta) * val.inc
			case ScrollContinuous: ref = ref.(f32) + f32(offset_delta)
			}
		}
	}

	return ref
}

_update_drag_ref :: proc(
	ui: ^UI, drag: ^Maybe(DragRef), drag_rect: Rect2i, bounding_rect: Rect2i,
	clip_to_bounding: bool = false,
) -> (delta: [2]f32) {

	drag_rect_clipped := drag_rect
	if clip_to_bounding {
		drag_rect_clipped = clip_rect_to_rect(drag_rect, bounding_rect)
	}

	if drag^ == nil {
		if _get_rect_mouse_state(ui.input, drag_rect_clipped) == .Pressed {
			ref := get_rect_center_f32(drag_rect)
			delta := to_2f32(ui.input.cursor_pos) - ref
			drag^ = DragRef{ref, delta}
		}
	} else {
		if ui.input.mouse_buttons[.MouseLeft].key.ended_down {
			old_ref_pos := drag.(DragRef).ref
			test_new_ref_pos := to_2f32(ui.input.cursor_pos) - drag.(DragRef).cursor_delta
			actual_new_ref_pos := clip_point_to_rect(test_new_ref_pos, bounding_rect)
			delta = actual_new_ref_pos - old_ref_pos
			drag^ = DragRef{actual_new_ref_pos, drag.(DragRef).cursor_delta}
		} else {
			drag^ = nil
		}
	}

	return delta
}
