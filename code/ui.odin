package wiredeck

import "core:mem"

UI :: struct {
	input: ^Input,
	font: ^Font,
	theme: Theme,
	total_dim: [2]int,
	current_layout: Layout,
	container_stack: [dynamic]Rect2i,
	commands: [dynamic]UICommand,
}

Theme :: struct {
	colors: [ColorID][4]f32,
	sizes: [SizeID]int,
}

ColorID :: enum {
	Background,
	Hovered,
	Text,
}

SizeID :: enum {
	ButtonPadding,
}

Rect2i :: struct {
	topleft: [2]int,
	dim: [2]int,
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
	rect: Rect2i,
	color: [4]f32,
}

UICommandText :: struct {
	str: string,
	rect: Rect2i,
	color: [4]f32,
}

init_ui :: proc(ui: ^UI, width: int, height: int, input: ^Input, font: ^Font) {

	theme: Theme

	theme.colors[.Background] = [4]f32{0.1, 0.1, 0.1, 1}
	theme.colors[.Hovered] = [4]f32{0.2, 0.2, 0.2, 1}
	theme.colors[.Text] = [4]f32{0.9, 0.9, 0.9, 1}

	theme.sizes[.ButtonPadding] = 5

	ui^ = UI{
		input = input,
		font = font,
		theme = theme,
		total_dim = [2]int{width, height},
		current_layout = .Horizontal,
		container_stack = make([dynamic]Rect2i, 0, 10),
		commands = make([dynamic]UICommand, 0, 50),
	}
}

ui_begin :: proc(ui: ^UI) {
	clear(&ui.commands)
	clear(&ui.container_stack)
	root_rect := Rect2i{{0, 0}, ui.total_dim}
	append(&ui.container_stack, root_rect)
}

ui_end :: proc(ui: ^UI) {}

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

button :: proc(ui: ^UI, label_str: string) -> MouseState {
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
		state = get_rect_mouse_state(ui.input, rect)

		element_slack := rect.dim - element_dim
		element_topleft := rect.topleft + element_slack / 2

		text_rect: Rect2i
		text_rect.dim = [2]int{text_width, text_height}
		text_rect.topleft = element_topleft
		text_rect.topleft.x += padding_x[0]
		text_rect.topleft.y += padding_y[0]

		if state >= .Hovered {
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

get_rect_mouse_state :: proc(input: ^Input, rect: Rect2i) -> MouseState {
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
