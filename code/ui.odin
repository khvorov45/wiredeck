package wiredeck

import "core:mem"

UI :: struct {
	input:             ^Input,
	font:              ^Font,
	theme:             Theme,
	total_dim:         [2]int,
	current_layout:    Layout,
	container_stack:   [dynamic]Rect2i,
	commands:          [dynamic]UICommand,
	last_element_rect: Rect2i,
}

Theme :: struct {
	colors: [ColorID][4]f32,
	sizes:  [SizeID]int,
}

ColorID :: enum {
	Background,
	Hovered,
	Text,
	Border,
}

SizeID :: enum {
	ButtonPadding,
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

Layout :: enum {
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
	UICommandText,
}

UICommandRect :: struct {
	rect:  Rect2i,
	color: [4]f32,
}

UICommandText :: struct {
	str:   string,
	rect:  Rect2i,
	color: [4]f32,
}

init_ui :: proc(ui: ^UI, width: int, height: int, input: ^Input, font: ^Font) {

	theme: Theme

	theme.colors[.Background] = [4]f32{0.1, 0.1, 0.1, 1}
	theme.colors[.Hovered] = [4]f32{0.2, 0.2, 0.2, 1}
	theme.colors[.Text] = [4]f32{0.9, 0.9, 0.9, 1}
	theme.colors[.Border] = [4]f32{0.3, 0.3, 0.3, 1}

	theme.sizes[.ButtonPadding] = 5

	ui^ = UI {
		input = input,
		font = font,
		theme = theme,
		total_dim = [2]int{width, height},
		current_layout = .Horizontal,
		container_stack = make([dynamic]Rect2i, 0, 10),
		commands = make([dynamic]UICommand, 0, 50),
		last_element_rect = Rect2i{},
	}
}

ui_begin :: proc(ui: ^UI) {
	clear(&ui.commands)
	clear(&ui.container_stack)
	root_rect := Rect2i{{0, 0}, ui.total_dim}
	append(&ui.container_stack, root_rect)
	ui.last_element_rect = Rect2i{}
}

ui_end :: proc(ui: ^UI) {}

begin_container :: proc(ui: ^UI, dir: Direction, size_init: int) -> bool {
	result := false
	if rect, ok := _take_rect(&ui.container_stack[len(ui.container_stack) - 1], dir, size_init); ok {
		append(&ui.container_stack, rect)
		result = true
	}
	return result
}

end_container :: proc(ui: ^UI) {
	pop(&ui.container_stack)
}

begin_floating :: proc(ui: ^UI, dir: Direction, dim: [2]int, ref: ^Rect2i = nil) {
	result := false
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
	_cmd_outline(ui, rect, ui.theme.colors[.Border])
}

end_floating :: proc(ui: ^UI) {
	pop(&ui.container_stack)
}

button :: proc(ui: ^UI, label_str: string, active: bool = false) -> MouseState {
	state := MouseState.Normal

	pad := ui.theme.sizes[.ButtonPadding]

	padding_x := [2]int{pad, pad}
	padding_y := [2]int{0, pad}

	text_width := get_string_width(ui.font, label_str)
	text_height := get_string_height(ui.font, label_str)

	element_dim := [2]int{
		text_width + padding_x[0] + padding_x[1],
		text_height + padding_y[0] + padding_y[1],
	}

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

	if rect, ok := _take_rect(&ui.container_stack[len(ui.container_stack) - 1], dir, size); ok {
		ui.last_element_rect = rect
		state = _get_rect_mouse_state(ui.input, rect)

		element_slack := rect.dim - element_dim
		element_topleft := rect.topleft + element_slack / 2

		text_rect: Rect2i
		text_rect.dim = [2]int{text_width, text_height}
		text_rect.topleft = element_topleft
		text_rect.topleft.x += padding_x[0]
		text_rect.topleft.y += padding_y[0]

		if state >= .Hovered || active {
			append(&ui.commands, UICommandRect{rect, ui.theme.colors[.Hovered]})
		}

		append(&ui.commands, UICommandText{label_str, text_rect, ui.theme.colors[.Text]})
	}

	return state
}

point_inside_rect :: proc(point: [2]int, rect: Rect2i) -> bool {
	rect_bottomright := rect.topleft + rect.dim
	x_overlaps := point.x >= rect.topleft.x && point.x < rect_bottomright.x
	y_overlaps := point.y >= rect.topleft.y && point.y < rect_bottomright.y
	result := x_overlaps && y_overlaps
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

	append(&ui.commands, UICommandRect{top, color})
	append(&ui.commands, UICommandRect{bottom, color})
	append(&ui.commands, UICommandRect{left, color})
	append(&ui.commands, UICommandRect{right, color})
}
