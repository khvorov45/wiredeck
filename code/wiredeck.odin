package wiredeck

main :: proc() {
	window: Window
	init_window(&window, "Wiredeck", 1000, 1000)

	input: Input

	for window.is_running {

		clear_half_transitions(&input)

		wait_for_input(&window, &input)
	}
}
