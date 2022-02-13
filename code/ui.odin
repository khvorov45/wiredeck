package wiredeck

import "core:mem"

UI :: struct {
	input: ^Input,
	font: ^Font,
	total_dim: [2]int,
	container: [dynamic]Rect2i,
	current_layout: Layout,
	current_commands: [dynamic]UICommand,
	elements: map[string]Rect2i,
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

ButtonMouseState :: enum {
	Normal,
	Hovered,
	Pressed,
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
	ui^ = UI{
		input = input,
		font = font,
		total_dim = [2]int{width, height},
		container = make([dynamic]Rect2i, 0, 10),
		current_commands = make([dynamic]UICommand, 0, 50),
	}
	append(&ui.container, Rect2i{{0, 0}, {width, height}})
}

ui_begin :: proc(ui: ^UI) {
	clear(&ui.current_commands)
	(^mem.Raw_Dynamic_Array)(&ui.container).len = 1
}

ui_end :: proc(ui: ^UI) {}

_take_rect :: proc(from: Rect2i, dir: Direction, size_init: int) -> (rect: Rect2i, success: bool) {

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

		success = true
	}

	return rect, success
}

begin_container :: proc(ui: ^UI, dir: Direction, size_init: int, id: string) -> bool {

	result := false
	if rect, ok := _take_rect(ui.container[len(ui.container) - 1], dir, size_init); ok {

		should_redraw := true
		if el, ok := ui.elements[id]; ok {
			if el == rect {
				should_redraw = false
			}
		}

		if should_redraw {
			cmd := UICommandRect{rect, [4]f32{1, 0, 0, 1}}
			append(&ui.current_commands, cmd)
			ui.elements[id] = rect
		}

		result = true
		append(&ui.container, rect)
	}

	return result
}

end_container :: proc(ui: ^UI) {
	pop(&ui.container)
}

dropdown :: proc(ui: ^UI, label: string) -> ButtonMouseState {

	state: ButtonMouseState = .Normal

	padding_x := [2]int{5, 5}
	padding_y := [2]int{5, 5}

	text_width := get_string_width(ui.font, label)
	text_height := get_string_height(ui.font, label)

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

	if rect, ok := _take_rect(ui.container[len(ui.container) - 1], dir, size); ok {

		text_rect: Rect2i
		text_rect.dim = [2]int{text_width, text_height}
		text_slack := rect.dim - text_rect.dim
		text_rect.topleft = rect.topleft + text_slack / 2

		should_redraw := true
		if el, ok := ui.elements[label]; ok {
			if el == rect {
				should_redraw = false
			}
		}

		if should_redraw {
			append(&ui.current_commands, UICommandRect{rect, [4]f32{0, 1, 0, 1}})
			append(&ui.current_commands, UICommandText{label, text_rect, [4]f32{0, 0, 1, 1}})
			ui.elements[label] = rect
		}
	}

	return state
}
