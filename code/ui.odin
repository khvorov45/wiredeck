package wiredeck

import "core:strings"
import "core:fmt"
import "core:mem"

UI :: struct {
	input:                ^Input,
	fonts:                 [FontID]^Font,
	monospace_px_width:   int,
	theme:                Theme,
	total_dim:            [2]int,
	current_layout:       Orientation,
	container_stack:      [dynamic]Container,
	commands:             [dynamic]UICommand,
	last_element_rect:    Rect2i,
	floating:             Maybe(Rect2i),
	floating_cmd:         [dynamic]UICommand,
	current_cmd_buffer:   ^[dynamic]UICommand,
	arena:                mem.Arena,
	arena_allocator:      mem.Allocator,
	should_capture_mouse: bool,
	req_cursor:           CursorKind,
}

Container :: struct {
	rect: Rect2i,
	offset: int,
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
}

SizeID :: enum {
	ButtonPadding,
	Separator,
	TextAreaGutter,
	ScrollbarWidth,
	ScrollbarThumbLengthMin,
	ScrollbarIncPerLine,
	ScrollbarIncPerCol,
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
}

UICommand :: union {
	UICommandRect,
	UICommandTextline,
}

UICommandRect :: struct {
	rect: Rect2i,
	color: [4]f32,
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
	sep_drag_ref: ^Maybe(f32),
}

ContainerScroll :: struct {
	height: int,
	offset: ^int,
	ref: ^Maybe(f32),
}

init_ui :: proc(
	ui: ^UI, width, height: int, input: ^Input,
	monospace_font: ^Font, varwidth_font: ^Font,
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

	theme.sizes[.ButtonPadding] = 5
	theme.sizes[.Separator] = 5
	theme.sizes[.TextAreaGutter] = 5
	theme.sizes[.ScrollbarWidth] = 10
	theme.sizes[.ScrollbarThumbLengthMin] = 40
	theme.sizes[.ScrollbarIncPerLine] = 20
	theme.sizes[.ScrollbarIncPerCol] = 20

	fonts: [FontID]^Font
	fonts[.Monospace] = monospace_font
	fonts[.Varwidth] = varwidth_font

	ui^ = UI {
		input = input,
		fonts = fonts,
		monospace_px_width = get_glyph_info(monospace_font, 'a').advance_x,
		theme = theme,
		total_dim = [2]int{width, height},
		current_layout = .Horizontal,
		container_stack = buffer_from_slice(make([]Container, 100)),
		commands = buffer_from_slice(make([]UICommand, 1000)),
		last_element_rect = Rect2i{},
		floating = nil,
		floating_cmd = buffer_from_slice(make([]UICommand, 100)),
		current_cmd_buffer = nil,
	}

	mem.init_arena(&ui.arena, make([]u8, 4 * MEGABYTE))
	ui.arena_allocator = mem.arena_allocator(&ui.arena)
}

ui_begin :: proc(ui: ^UI) {
	clear(&ui.commands)
	clear(&ui.container_stack)
	root_rect := Rect2i{{0, 0}, ui.total_dim}
	append(&ui.container_stack, Container{root_rect, 0})
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
	size: int
	sep_drag_ref: Maybe(f32)
	resisable := false
	switch val in size_init {
	case int:
		size = val
	case ContainerResize:
		size = val.size^
		sep_drag_ref = val.sep_drag_ref^
		resisable = true
	}

	if resisable {
		sep_is_vertical := true
		if dir == .Top || dir == .Bottom {
			sep_is_vertical = false
		}

		size = max(size, 0)
		last_container_rect := last_container(ui)^
		container_rect_init := Container{_take_rect(&last_container_rect, dir, size + ui.theme.sizes[.Separator]), 0}
		separator_rect_init := _take_rect(&container_rect_init, dir_opposite(dir), ui.theme.sizes[.Separator])

		size = container_rect_init.rect.dim.y
		if sep_is_vertical {
			size = container_rect_init.rect.dim.x
		}

		separator_state := _get_rect_mouse_state(ui.input, separator_rect_init)
		cur_cursor: f32
		if sep_is_vertical {
			cur_cursor = f32(ui.input.cursor_pos.x)
		} else {
			cur_cursor = f32(ui.input.cursor_pos.y)
		}

		if sep_drag_ref == nil {
			if separator_state == .Pressed {
				sep_drag_ref = cur_cursor
			}
		} else {
			if ui.input.keys[.MouseLeft].ended_down {
				delta := cur_cursor - sep_drag_ref.(f32)
				max_size := last_container(ui).rect.dim.y
				if sep_is_vertical {
					max_size = last_container(ui).rect.dim.x
				}
				new_size := clamp(size + int(delta), 0, max_size - ui.theme.sizes[.Separator])
				delta = f32(new_size - size)
				sep_drag_ref = sep_drag_ref.(f32) + delta
				size = new_size
			} else {
				sep_drag_ref = nil
			}
		}

		if sep_drag_ref != nil || separator_state > .Normal {
			ui.req_cursor = .SizeNS
			if sep_is_vertical {
				ui.req_cursor = .SizeWE
			}
		}
	}

	rect: Rect2i
	if resisable {
		container := Container{_take_rect(last_container(ui), dir, size + ui.theme.sizes[.Separator]), 0}
		sep_rect := _take_rect(&container, dir_opposite(dir), ui.theme.sizes[.Separator])
		rect = container.rect
		append(ui.current_cmd_buffer, UICommandRect{sep_rect, ui.theme.colors[.Border]})
	} else {
		rect = _take_rect(last_container(ui), dir, size)
	}

	scroll_offset := 0
	if scroll_spec != nil {
		bounding_rect := rect
		scroll := scroll_spec.(ContainerScroll)

		rect.dim.x -= ui.theme.sizes[.ScrollbarWidth]
		track := _position_scrollbar_track(rect, ui.theme.sizes[.ScrollbarWidth], .Vertical)
		append(ui.current_cmd_buffer, UICommandRect{track, ui.theme.colors[.ScrollbarTrack]})

		scroll_ref := _clamp_scroll_ref(track, scroll.ref^, .Vertical)

		scroll_continuous := _get_scroll_continuous(
			track, scroll.height,
			ui.theme.sizes[.ScrollbarThumbLengthMin], bounding_rect,
		)

		line_offset, line_offset_delta :=
			_get_scroll_offset_and_delta(ui.input, scroll_ref, scroll.offset^, scroll_continuous)

		thumb_rect := _get_scroll_thumb_rect(line_offset, scroll_continuous)
		thumb_state := _get_rect_mouse_state(ui.input, thumb_rect)
		thumb_color := _get_scroll_thumb_col(ui, thumb_state)
		append(ui.current_cmd_buffer, UICommandRect{thumb_rect, thumb_color})

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

	append(&ui.container_stack, Container{rect, scroll_offset})
	_cmd_outline(ui, rect, ui.theme.colors[.Border], border)

	if resisable {
		size_init.(ContainerResize).size^ = size
		size_init.(ContainerResize).sep_drag_ref^ = sep_drag_ref

		if sep_drag_ref != nil {
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

		append(&ui.container_stack, Container{rect, 0})

		append(ui.current_cmd_buffer, UICommandRect{rect, ui.theme.colors[.BackgroundFloating]})
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
	label_col: Maybe([][4]f32) = nil,
	active: bool = false,
	text_align: Align = .Center,
	process_input: bool = true,
) -> MouseState {

	state := MouseState.Normal

	padding := get_button_pad(ui)
	element_dim := get_button_dim(ui, label_str)

	dir: Direction
	size: int
	switch ui.current_layout {
	case .Horizontal:
		size = element_dim.x
		dir = .Left
	case .Vertical:
		size = element_dim.y
		dir = .Top
	}

	bounding_rect := last_container(ui).rect
	rect := _take_rect(last_container(ui), dir, size)
	ui.last_element_rect = rect
	if process_input {
		state = _get_rect_mouse_state(ui.input, rect)
	}

	element_slack := rect.dim - element_dim
	element_topleft := rect.topleft
	if text_align == .Center {
		element_topleft += element_slack / 2
	} else if text_align == .End {
		element_topleft += element_slack
	}

	text_topleft := element_topleft
	text_topleft.x += padding.x[0]
	text_topleft.y += padding.y[0]

	if state >= .Hovered || active {
		append(ui.current_cmd_buffer, UICommandRect{rect, ui.theme.colors[.BackgroundHovered]})
	}

	if state >= .Hovered {
		ui.req_cursor = .Pointer
	}

	col: union{[4]f32, [][4]f32}
	if label_col != nil {
		col = label_col.([][4]f32)
	} else {
		col = ui.theme.text_colors[.Normal]
	}
	append(
		ui.current_cmd_buffer,
		UICommandTextline{strings.clone(label_str, ui.arena_allocator), .Varwidth, text_topleft, rect, col},
	)

	return state
}

text_area :: proc(ui: ^UI, file: ^OpenedFile) {

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
	line_numbers_rect.dim.x = num_rect_dim.x + 2 * ui.theme.sizes[.TextAreaGutter]
	text_rect.dim.x -= line_numbers_rect.dim.x
	text_rect.topleft.x += line_numbers_rect.dim.x
	_cmd_outline(ui, line_numbers_rect, ui.theme.colors[.Border], {.Right})

	// NOTE(khvorov) Scrollbars
	scrollbar_tracks := _position_scrollbar_tracks(text_rect, ui.theme.sizes[.ScrollbarWidth])
	for track in scrollbar_tracks {
		append(ui.current_cmd_buffer, UICommandRect{track, ui.theme.colors[.ScrollbarTrack]})
	}
	cursor_scroll_ref := _clamp_scroll_refs(scrollbar_tracks, file.cursor_scroll_ref)

	scroll_discrete := _get_scroll_discrete2(
		scrollbar_tracks,
		[2]f32{f32(ui.theme.sizes[.ScrollbarIncPerCol]), f32(ui.theme.sizes[.ScrollbarIncPerLine])},
		[2]int{file.max_col_width_glyphs - text_rect.dim.x / ui.monospace_px_width, line_count - 1},
		ui.theme.sizes[.ScrollbarThumbLengthMin],
		text_area_rect,
	)

	line_offset, line_offset_delta :=
		_get_scroll_offset_and_delta(ui.input, cursor_scroll_ref.y, file.line_offset_lines, scroll_discrete.y)

	col_offset, col_offset_delta :=
		_get_scroll_offset_and_delta(ui.input, cursor_scroll_ref.x, file.col_offset, scroll_discrete.x)

	scrollbar_v_thumb_rect := _get_scroll_thumb_rect(line_offset, scroll_discrete.y)
	scrollbar_v_thumb_state := _get_rect_mouse_state(ui.input, scrollbar_v_thumb_rect)
	scrollbar_v_thumb_color := _get_scroll_thumb_col(ui, scrollbar_v_thumb_state)
	append(ui.current_cmd_buffer, UICommandRect{scrollbar_v_thumb_rect, scrollbar_v_thumb_color})

	scrollbar_h_thumb_rect := _get_scroll_thumb_rect(col_offset, scroll_discrete.x)
	scrollbar_h_thumb_state := _get_rect_mouse_state(ui.input, scrollbar_h_thumb_rect)
	scrollbar_h_thumb_color := _get_scroll_thumb_col(ui, scrollbar_h_thumb_state)
	append(ui.current_cmd_buffer, UICommandRect{scrollbar_h_thumb_rect, scrollbar_h_thumb_color})

	cursor_scroll_ref.y = _update_scroll_ref(
		ui.input, scrollbar_v_thumb_state, cursor_scroll_ref.y, line_offset_delta, scroll_discrete.y,
	)

	cursor_scroll_ref.x = _update_scroll_ref(
		ui.input, scrollbar_h_thumb_state, cursor_scroll_ref.x, col_offset_delta, scroll_discrete.x,
	)

	// NOTE(sen) Figure out byte offset
	byte_offset := file.line_offset_bytes
	if line_offset_delta != 0 {
		lines_skipped := 0

		if line_offset_delta > 0 {

			for index := byte_offset; index < len(file.content); index += 1 {
				ch := file.content[index]
				if ch == '\n' || ch == '\r' {
					lines_skipped += 1
					next_ch: u8 = 0
					if index + 1 < len(file.content) {
						next_ch = file.content[index + 1]
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
				ch := file.content[index]
				if ch == '\n' || ch == '\r' {
					lines_skipped += 1
					if lines_skipped == -(line_offset_delta) + 1 {
						byte_offset = index + 1
						break
					}
					prev_ch: u8 = 0
					if index - 1 >= 0 {
						prev_ch = file.content[index - 1]
					}
					if ch == '\n' && prev_ch == '\r' {
						index -= 1
					}
				}
			}
		}
	}
	byte_offset = clamp(byte_offset, 0, len(file.content))

	// NOTE(khvorov) Text content
	assert(len(file.content) == len(file.colors))
	str_left := file.content[byte_offset:]
	colors_left := file.colors[byte_offset:]
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

	file.line_offset_lines = line_offset
	file.line_offset_bytes = byte_offset
	file.cursor_scroll_ref = cursor_scroll_ref
	file.col_offset = col_offset

	if cursor_scroll_ref.y != nil || cursor_scroll_ref.x != nil {
		ui.should_capture_mouse = true
	}
}

fill_container :: proc(ui: ^UI, color: [4]f32) {
	rect := last_container(ui).rect
	append(ui.current_cmd_buffer, UICommandRect{rect, color})
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
	result := [2]f32{f32(rect.topleft.x), f32(rect.topleft.y)} + 0.5 * [2]f32{f32(rect.dim.x), f32(rect.dim.y)}
	return result
}

_take_rect :: proc(from_container: ^Container, dir: Direction, size_init: int) -> Rect2i {
	rect := _peek_rect(from_container, dir, size_init)

	from := &from_container.rect

	size: int
	switch dir {
	case .Top, .Bottom:
		size = rect.dim.y
	case .Left, .Right:
		size = rect.dim.x
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

_peek_rect :: proc(from_container: ^Container, dir: Direction, size_init: int) -> (rect: Rect2i) {

	from := from_container.rect
	from.topleft.y -= from_container.offset
	from.dim.y += from_container.offset

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

	return rect
}

_take_entire_rect :: proc(from: ^Container) -> Rect2i {
	result := from.rect
	from.rect.topleft += from.rect.dim
	from.rect.dim = 0
	return result
}

_get_rect_mouse_state :: proc(input: ^Input, rect: Rect2i) -> MouseState {
	state := MouseState.Normal
	if point_inside_rect(input.cursor_pos, rect) {
		state = .Hovered
		mouse_left_down := input.keys[.MouseLeft].ended_down
		if was_pressed(input, .MouseLeft) && mouse_left_down {
			state = .Pressed
		} else if was_unpressed(input, .MouseLeft) && !mouse_left_down {
			state = .Clicked
		}
	}
	return state
}

_get_inner_outline :: proc(rect: Rect2i) -> (result: [Direction]Rect2i) {
	top := rect
	top.dim.y = 1

	bottom := top
	bottom.topleft.y += rect.dim.y - 1

	left := rect
	left.dim.x = 1

	right := left
	right.topleft.x += rect.dim.x - 1

	result[.Top] = top
	result[.Bottom] = bottom
	result[.Left] = left
	result[.Right] = right

	return result
}

_cmd_outline :: proc(ui: ^UI, rect: Rect2i, color: [4]f32, dirs: Directions = {.Top, .Bottom, .Left, .Right}) {
	rects := _get_inner_outline(rect)
	for dir in Direction {
		if dir in dirs {
			append(ui.current_cmd_buffer, UICommandRect{rects[dir], color})
		}
	}
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
	track: Rect2i, height, thumb_size_min: int,
	bounding_rect: Rect2i,
) -> (result: ScrollSpec) {
	track_len := _get_scroll_track_len(track, .Vertical)
	if height <= track_len {
		result = ScrollSpec{.Vertical, 0, track_len, track, bounding_rect, ScrollContinuous{0}}
	} else {
		range := height - track_len
		thumb_size := track_len - range
		if thumb_size < thumb_size_min {
			thumb_size = thumb_size_min
			range = track_len - thumb_size
		}
		result = ScrollSpec{
			.Vertical, range, thumb_size, track, bounding_rect,
			ScrollContinuous{f32(height - track_len) / f32(range)},
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
		thumb_size = thumb_size_min
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
	case ScrollContinuous: result = offset
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
	}

	offset = _clamp_scroll_offset(old_offset + offset_delta, settings)
	delta = offset - old_offset
	return offset, delta
}

_get_scroll_thumb_col :: proc(ui: ^UI, state: MouseState) -> [4]f32 {
	color := ui.theme.colors[.ScrollbarThumb]
	if state > .Normal {
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
		if !input.keys[.MouseLeft].ended_down {
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
