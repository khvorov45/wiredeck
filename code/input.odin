package wiredeck

Input :: struct {
	keys: [KeyID]Key,
	cursor_pos: [2]int,
	scroll: [2]int,
	mouse_buttons: [MouseButtonID]MouseButton,
}

KeyID :: enum {
	AltR, AltL, Enter, Shift, Space, Ctrl,
	W, A, S, D, Q, E,
	Digit1, Digit2, Digit3, Digit4, Digit5, Digit6, Digit7, Digit8, Digit9, Digit0,
	F1, F4, F11,
}

MouseButtonID :: enum { MouseLeft, MouseMiddle, MouseRight }

Key :: struct {
	ended_down: bool,
	half_transition_count: int,
}

MouseButton :: struct {
	key: Key,
	last_down_cursor_pos: [2]int,
}

clear_ended_down :: proc(input: ^Input) {
	for key in &input.keys {
		key.ended_down = false
	}
	for button in &input.mouse_buttons {
		button.key.ended_down = false
	}
}

clear_half_transitions :: proc(input: ^Input) {
	for key in &input.keys {
		key.half_transition_count = 0
	}
	for button in &input.mouse_buttons {
		button.key.half_transition_count = 0
	}
}

get_key :: proc(input: ^Input, key_id: union{KeyID, MouseButtonID}) -> (result: Key) {
	switch val in key_id {
	case KeyID: result = input.keys[val]
	case MouseButtonID: result = input.mouse_buttons[val].key
	}
	return result
}

was_pressed :: proc(input: ^Input, key_id: union{KeyID, MouseButtonID}) -> bool {
	result := was_key_pressed(get_key(input, key_id))
	return result
}

was_key_pressed :: proc(key: Key) -> bool {
	result := false
	if key.half_transition_count >= 2 {
		result = true
	} else if key.half_transition_count == 1 {
		result = key.ended_down
	}
	return result
}

was_unpressed :: proc(input: ^Input, key_id: union{KeyID, MouseButtonID}) -> bool {
	result := was_key_unpressed(get_key(input, key_id))
	return result
}

was_key_unpressed :: proc(key: Key) -> bool {
	result := false
	if key.half_transition_count >= 2 {
		result = true
	} else if key.half_transition_count == 1 {
		result = !key.ended_down
	}
	return result
}

record_key :: proc(input: ^Input, key_id: KeyID, ended_down: bool) {
	input.keys[key_id].ended_down = ended_down
	input.keys[key_id].half_transition_count += 1
}

record_mouse_button :: proc(input: ^Input, button_id: MouseButtonID, ended_down: bool) {
	button := &input.mouse_buttons[button_id]
	if ended_down {
		button.last_down_cursor_pos = input.cursor_pos
	}
	button.key.ended_down = ended_down
	button.key.half_transition_count += 1
}
