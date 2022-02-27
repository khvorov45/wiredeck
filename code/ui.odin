package wiredeck

import "core:strings"
import "core:fmt"
import "core:mem"

UI :: struct {
	input:              ^Input,
	font:               ^Font,
	theme:              Theme,
	total_dim:          [2]int,
	current_layout:     Orientation,
	container_stack:    [dynamic]Rect2i,
	commands:           [dynamic]UICommand,
	last_element_rect:  Rect2i,
	floating:           Maybe(Rect2i),
	floating_cmd:       [dynamic]UICommand,
	current_cmd_buffer: ^[dynamic]UICommand,
	arena:              mem.Arena,
	arena_allocator:    mem.Allocator,
}

Theme :: struct {
	colors: [ColorID][4]f32,
	sizes:  [SizeID]int,
}

ColorID :: enum {
	Background,
	BackgroundHovered,
	Text,
	LineNumber,
	Border,
	ScrollbarTrack,
	ScrollbarThumb,
	ScrollbarThumbHovered,
}

SizeID :: enum {
	ButtonPadding,
	Separator,
	TextAreaGutter,
	ScrollbarWidth,
	ScrollbarThumbLengthMin,
	ScrollbarIncPerLine,
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
	rect:  Rect2i,
	color: [4]f32,
}

UICommandTextline :: struct {
	str:          string,
	text_topleft: [2]int,
	clip_rect:    Rect2i,
	color:        [4]f32,
}

Align :: enum {
	Center,
	Begin,
	End,
}

init_ui :: proc(ui: ^UI, width: int, height: int, input: ^Input, font: ^Font) {

	theme: Theme

	theme.colors[.Background] = [4]f32{0.1, 0.1, 0.1, 1}
	theme.colors[.BackgroundHovered] = [4]f32{0.2, 0.2, 0.2, 1}
	theme.colors[.Text] = [4]f32{0.9, 0.9, 0.9, 1}
	theme.colors[.Border] = [4]f32{0.3, 0.3, 0.3, 1}
	theme.colors[.LineNumber] = [4]f32{0.7, 0.7, 0.7, 1}
	theme.colors[.ScrollbarTrack] = [4]f32{0.2, 0.2, 0.2, 1}
	theme.colors[.ScrollbarThumb] = [4]f32{0.5, 0.5, 0.5, 1}
	theme.colors[.ScrollbarThumbHovered] = [4]f32{0.7, 0.7, 0.7, 1}

	theme.sizes[.ButtonPadding] = 5
	theme.sizes[.Separator] = 5
	theme.sizes[.TextAreaGutter] = 5
	theme.sizes[.ScrollbarWidth] = 10
	theme.sizes[.ScrollbarThumbLengthMin] = 40
	theme.sizes[.ScrollbarIncPerLine] = 20

	ui^ = UI {
		input = input,
		font = font,
		theme = theme,
		total_dim = [2]int{width, height},
		current_layout = .Horizontal,
		container_stack = make([dynamic]Rect2i, 0, 10),
		commands = make([dynamic]UICommand, 0, 50),
		last_element_rect = Rect2i{},
		floating = nil,
		floating_cmd = make([dynamic]UICommand, 0, 50),
		current_cmd_buffer = nil,
	}

	mem.init_arena(&ui.arena, make([]u8, mem.megabytes(4)))
	ui.arena_allocator = mem.arena_allocator(&ui.arena)
}

ui_begin :: proc(ui: ^UI) {
	clear(&ui.commands)
	clear(&ui.container_stack)
	root_rect := Rect2i{{0, 0}, ui.total_dim}
	append(&ui.container_stack, root_rect)
	ui.last_element_rect = Rect2i{}
	ui.floating = nil
	clear(&ui.floating_cmd)
	ui.current_cmd_buffer = &ui.commands
}

ui_end :: proc(ui: ^UI) {
	for cmd in ui.floating_cmd {
		append(&ui.commands, cmd)
	}
	free_all(ui.arena_allocator)
}

begin_container :: proc(ui: ^UI, dir: Direction, size_init: int) -> bool {
	result := false
	if rect, ok := _take_rect(last_container(ui), dir, size_init); ok {
		append(&ui.container_stack, rect)
		result = true
	}
	return result
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

		append(&ui.container_stack, rect)

		append(ui.current_cmd_buffer, UICommandRect{rect, ui.theme.colors[.Background]})
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

	if rect, ok := _take_rect(last_container(ui), dir, size); ok {
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

		append(
			ui.current_cmd_buffer,
			UICommandTextline{label_str, text_topleft, rect, ui.theme.colors[.Text]},
		)
	}

	return state
}

text_area_string :: proc(
	ui: ^UI,
	str: string,
	col_offset_bytes_init: ^int,
	line_offset_init: ^int,
	cursor_scroll_ref_init: ^[2]Maybe(f32),
) {

	assert(col_offset_bytes_init != nil)
	assert(line_offset_init != nil)
	assert(cursor_scroll_ref_init != nil)

	// NOTE(khvorov) Count lines and column widths
	ch_per_newline := 1
	if strings.index(str, "\r\n") != -1 {
		ch_per_newline = 2
	}
	line_count := 0
	max_col_bytes := 0
	cur_col_width := 0
	for index := 0; index < len(str); index += 1 {
		ch := str[index]
		if ch == '\n' || ch == '\r' {
			line_count += 1
			index += ch_per_newline - 1
			max_col_bytes = max(max_col_bytes, cur_col_width)
			cur_col_width = 0
		} else {
			cur_col_width += 1
		}
	}
	line_count += 1 // NOTE(khvorov) Start counting from 1

	line_count_str := fmt.tprintf("%d", line_count)
	num_rect_dim := [2]int{get_string_width(ui.font, line_count_str), get_string_height(ui.font, "")}

	text_area_rect := _take_entire_rect(last_container(ui))
	text_rect := text_area_rect
	text_rect.dim -= ui.theme.sizes[.ScrollbarWidth]
	text_rect_max_y := text_rect.topleft.y + text_rect.dim.y

	line_numbers_rect := text_rect
	line_numbers_rect.dim.x = num_rect_dim.x + 2 * ui.theme.sizes[.TextAreaGutter]
	text_rect.dim.x -= line_numbers_rect.dim.x
	text_rect.topleft.x += line_numbers_rect.dim.x

	cursor_scroll_ref := cursor_scroll_ref_init^

	scrollbar_v_rect := text_rect
	scrollbar_v_rect.topleft.x += text_rect.dim.x
	scrollbar_v_rect.dim.x = ui.theme.sizes[.ScrollbarWidth]
	if cursor_scroll_ref_init.y != nil {
		cursor_scroll_ref.y = clamp(
			cursor_scroll_ref_init.y.(f32),
			f32(scrollbar_v_rect.topleft.y),
			f32(scrollbar_v_rect.topleft.y + scrollbar_v_rect.dim.y),
		)
	}

	scrollbar_h_rect := text_rect
	scrollbar_h_rect.topleft.y += text_rect.dim.y
	scrollbar_h_rect.dim.y = ui.theme.sizes[.ScrollbarWidth]

	// NOTE(khvorov) Vertical Scrollbar
	scrollbar_v_inc_per_line := f32(ui.theme.sizes[.ScrollbarIncPerLine])
	scrollbar_v_range := (line_count - 1) * int(scrollbar_v_inc_per_line)
	scrollbar_v_length := text_area_rect.dim.y - scrollbar_v_range
	if scrollbar_v_length < ui.theme.sizes[.ScrollbarThumbLengthMin] {
		scrollbar_v_length = ui.theme.sizes[.ScrollbarThumbLengthMin]
		scrollbar_v_range = scrollbar_v_rect.dim.y - scrollbar_v_length
		if line_count > 1 {
			scrollbar_v_inc_per_line = f32(scrollbar_v_range) / f32(line_count - 1)
		}
	}
	scrollbar_v_top_start := scrollbar_v_rect.topleft.y
	scrollbar_v_top_pos := scrollbar_v_top_start

	// NOTE(sen) Process line offset inputs
	line_offset_delta := 0
	if cursor_scroll_ref.y == nil {
		line_offset_delta = ui.input.scroll.y
	} else {
		scroll_delta_px := f32(ui.input.cursor_pos.y) - cursor_scroll_ref.y.(f32)
		line_offset_delta = int(scroll_delta_px / scrollbar_v_inc_per_line)
	}
	old_line_offset := clamp(line_offset_init^, 0, line_count - 1)
	line_offset := clamp(old_line_offset + line_offset_delta, 0, line_count - 1)
	line_offset_delta = line_offset - old_line_offset

	// NOTE(sen) Figure out byte offset
	byte_offset := 0
	cur_line := 0
	for index := 0; index < len(str); index += 1 {
		ch := str[index]
		if ch == '\n' || ch == '\r' {
			cur_line += 1
			if cur_line == line_offset {
				byte_offset = index + ch_per_newline
				break
			}
			index += ch_per_newline - 1
		}
	}

	if line_count > 1 {
		scrollbar_v_top_pos = int(
			f32(line_offset) / f32(line_count - 1) * f32(scrollbar_v_range) + f32(scrollbar_v_top_start),
		)
	}

	// NOTE(sen) Position vertical scrollbar thumb
	scrollbar_v_thumb_rect := scrollbar_v_rect
	scrollbar_v_thumb_rect.topleft.y = scrollbar_v_top_pos
	scrollbar_v_thumb_rect.dim.y = scrollbar_v_length
	scrollbar_v_thumb_color := ui.theme.colors[.ScrollbarThumb]
	scrollbar_v_thumb_state := _get_rect_mouse_state(ui.input, scrollbar_v_thumb_rect)
	if scrollbar_v_thumb_state > .Normal {
		scrollbar_v_thumb_color = ui.theme.colors[.ScrollbarThumbHovered]
	}
	append(ui.current_cmd_buffer, UICommandRect{scrollbar_v_thumb_rect, scrollbar_v_thumb_color})

	// NOTE(sen) Vertical scroll state input check
	if scrollbar_v_thumb_state == .Pressed && cursor_scroll_ref.y == nil {
		cursor_scroll_ref.y = f32(ui.input.cursor_pos.y)
	} else if cursor_scroll_ref.y != nil {
		if !ui.input.keys[.MouseLeft].ended_down {
			cursor_scroll_ref.y = nil
		} else {
			cursor_scroll_ref.y = cursor_scroll_ref.y.(f32) + f32(line_offset_delta) * scrollbar_v_inc_per_line
		}
	}

	// NOTE(khvorov) Figure out column offset
	max_col_width_px := max_col_bytes * ui.font.px_width
	max_col_slack_px := max(max_col_width_px - text_rect.dim.x, 0)
	max_col_slack_bytes := max_col_slack_px / ui.font.px_width
	if max_col_slack_px > 0 {
		max_col_slack_bytes += 1
	}
	old_col_offset_bytes := clamp(col_offset_bytes_init^, 0, max_col_slack_bytes)

	col_offset_delta := 0
	if cursor_scroll_ref.x == nil {
		col_offset_delta = ui.input.scroll.x
	}
	col_offset_bytes := clamp(old_col_offset_bytes + col_offset_delta, 0, max_col_slack_bytes)
	col_offset_delta = col_offset_bytes - old_col_offset_bytes

	// NOTE(khvorov) Text content
	str_left := str[clamp(byte_offset, 0, len(str)):]
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

		line_init := str_left[:line_end_index]
		str_left = str_left[line_end_index:]

		if len(line_init) > col_offset_bytes {
			line := line_init[col_offset_bytes:]
			current_line_topleft := [2]int{current_topleft_x_line, current_topleft_y}
			append(
				ui.current_cmd_buffer,
				UICommandTextline{line, current_line_topleft, text_rect, ui.theme.colors[.Text]},
			)
		}

		skip_count := 0
		for len(str_left) > 0 && (str_left[0] == '\n' || str_left[0] == '\r') {
			skip_count += 1
			str_left = str_left[1:]
		}

		// NOTE(khvorov) Line number
		line_number_count := max(skip_count, ch_per_newline) / ch_per_newline
		for line_index in 0 ..< line_number_count {
			num_string: string
			{
				context.allocator = ui.arena_allocator
				num_string = fmt.aprintf("%d", current_line_number)
			}
			current_num_topleft := [2]int{current_topleft_x_num, current_topleft_y}
			append(
				ui.current_cmd_buffer,
				UICommandTextline{num_string, current_num_topleft, line_numbers_rect, ui.theme.colors[.LineNumber]},
			)
			current_line_number += 1
			current_topleft_y += get_string_height(ui.font, line_init)
		}

		if skip_count == 0 || current_topleft_y > text_rect_max_y {
			break
		}
	}

	line_offset_init^ = line_offset
	cursor_scroll_ref_init^ = cursor_scroll_ref
	col_offset_bytes_init^ = col_offset_bytes
}

separator :: proc(ui: ^UI, orientation: Orientation) {
	size := ui.theme.sizes[.Separator]

	dir: Direction
	switch orientation {
	case .Horizontal:
		dir = .Top
	case .Vertical:
		dir = .Left
	}

	if rect, ok := _take_rect(last_container(ui), dir, size); ok {
		append(ui.current_cmd_buffer, UICommandRect{rect, ui.theme.colors[.Border]})
	}
}

get_button_pad :: proc(ui: ^UI) -> [2][2]int {
	pad := ui.theme.sizes[.ButtonPadding]
	padding: [2][2]int
	padding.x = [2]int{pad, pad}
	padding.y = [2]int{0, pad}
	return padding
}

get_button_dim :: proc(ui: ^UI, label: string = "") -> [2]int {
	text_width := get_string_width(ui.font, label)
	text_height := get_string_height(ui.font, label)
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

last_container :: proc(ui: ^UI) -> ^Rect2i {
	result := &ui.container_stack[len(ui.container_stack) - 1]
	return result
}

_take_rect :: proc(from: ^Rect2i, dir: Direction, size_init: int) -> (rect: Rect2i, success: bool) {

	size: int
	switch dir {
	case .Top, .Bottom:
		size = clamp(size_init, 0, from.dim.y)
	case .Left, .Right:
		size = clamp(size_init, 0, from.dim.x)
	}

	if size > 0 {
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

		success = true
	}

	return rect, success
}

_take_entire_rect :: proc(from: ^Rect2i) -> Rect2i {
	result := from^
	from.topleft += from.dim
	from.dim = 0
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

_cmd_outline :: proc(ui: ^UI, rect: Rect2i, color: [4]f32) {
	top := rect
	top.dim.y = 1

	bottom := top
	bottom.topleft.y += rect.dim.y - 1

	left := rect
	left.dim.x = 1

	right := left
	right.topleft.x += rect.dim.x - 1

	append(ui.current_cmd_buffer, UICommandRect{top, color})
	append(ui.current_cmd_buffer, UICommandRect{bottom, color})
	append(ui.current_cmd_buffer, UICommandRect{left, color})
	append(ui.current_cmd_buffer, UICommandRect{right, color})
}
