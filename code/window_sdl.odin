package wiredeck

import sdl "vendor:sdl2"

PlatformWindow :: struct {
	window:      ^sdl.Window,
	renderer:    ^sdl.Renderer,
	texture:     ^sdl.Texture,
	texture_dim: [2]int,
}

init_window :: proc(window: ^Window, title: string, width: int, height: int) {

	assert(sdl.Init(sdl.INIT_EVERYTHING) == 0)

	sdl_window := sdl.CreateWindow(
		cstring(raw_data(title)),
		sdl.WINDOWPOS_CENTERED,
		sdl.WINDOWPOS_CENTERED,
		i32(width),
		i32(height),
		sdl.WINDOW_HIDDEN,
	)
	assert(sdl_window != nil)

	renderer := sdl.CreateRenderer(sdl_window, -1, nil)
	assert(renderer != nil)

	assert(sdl.SetRenderDrawColor(renderer, 0, 0, 0, 255) == 0)
	assert(sdl.RenderClear(renderer) == 0)

	sdl.ShowWindow(sdl_window)
	sdl.RenderPresent(renderer)

	texture := sdl.CreateTexture(
		renderer,
		u32(sdl.PixelFormatEnum.ARGB8888),
		sdl.TextureAccess.STREAMING,
		i32(width),
		i32(height),
	)
	texture_dim := [2]int{width, height}
	assert(texture != nil)

	window^ = Window{
		true,
		false,
		true,
		[2]int{width, height},
		{sdl_window, renderer, texture, texture_dim},
	}
}

_record_event :: proc(window: ^Window, input: ^Input, event: sdl.Event) {
	#partial switch event.type {

	case .QUIT:
		window.is_running = false

	case .KEYDOWN, .KEYUP:
		ended_down := event.type == .KEYDOWN

		#partial switch event.key.keysym.sym {

		case .RETURN:
			record_key(input, .Enter, ended_down)

		case .RALT:
			record_key(input, .AltR, ended_down)

		case .LALT:
			record_key(input, .AltL, ended_down)

		case .W:
			record_key(input, .W, ended_down)

		case .A:
			record_key(input, .A, ended_down)

		case .S:
			record_key(input, .S, ended_down)

		case .D:
			record_key(input, .D, ended_down)

		case .Q:
			record_key(input, .Q, ended_down)

		case .E:
			record_key(input, .E, ended_down)

		case .NUM1:
			record_key(input, .Digit1, ended_down)

		case .NUM2:
			record_key(input, .Digit2, ended_down)

		case .NUM3:
			record_key(input, .Digit3, ended_down)

		case .NUM4:
			record_key(input, .Digit4, ended_down)

		case .NUM5:
			record_key(input, .Digit5, ended_down)

		case .NUM6:
			record_key(input, .Digit6, ended_down)

		case .NUM7:
			record_key(input, .Digit7, ended_down)

		case .NUM8:
			record_key(input, .Digit8, ended_down)

		case .NUM9:
			record_key(input, .Digit9, ended_down)

		case .NUM0:
			record_key(input, .Digit0, ended_down)

		case .LSHIFT, .RSHIFT:
			record_key(input, .Shift, ended_down)

		case .SPACE:
			record_key(input, .Space, ended_down)

		case .LCTRL, .RCTRL:
			record_key(input, .Ctrl, ended_down)

		case .F1:
			record_key(input, .F1, ended_down)

		case .F4:
			record_key(input, .F4, ended_down)

		}

	case .WINDOWEVENT:
		#partial switch event.window.event {

		case .FOCUS_LOST:
			window.is_focused = false

		case .FOCUS_GAINED:
			window.is_focused = true

		case .LEAVE:
			input.cursor_pos = -1

		}

	case .MOUSEBUTTONDOWN, .MOUSEBUTTONUP:
		ended_down := event.type == .MOUSEBUTTONDOWN
		switch event.button.button {
		case sdl.BUTTON_LEFT:
			record_key(input, .MouseLeft, ended_down)
		case sdl.BUTTON_MIDDLE:
			record_key(input, .MouseMiddle, ended_down)
		case sdl.BUTTON_RIGHT:
			record_key(input, .MouseRight, ended_down)
		}

	case .MOUSEWHEEL:
		input.scroll.x = int(event.wheel.x)
		input.scroll.y = int(-event.wheel.y)

	case .MOUSEMOTION:
		input.cursor_pos = [2]int{int(event.motion.x), int(event.motion.y)}
	}
}

wait_for_input :: proc(window: ^Window, input: ^Input) {

	event_count := sdl.PeepEvents(nil, 0, sdl.eventaction.PEEKEVENT, sdl.EventType.FIRSTEVENT, sdl.EventType.LASTEVENT)

	event: sdl.Event
	if event_count == 0 {
		sdl.WaitEvent(&event)
		_record_event(window, input, event)
	}

	for sdl.PollEvent(&event) != 0 {
		_record_event(window, input, event)
	}
}

display_pixels :: proc(window: ^Window, pixels: []u32, pixels_dim: [2]int) {

	assert(sdl.RenderClear(window.platform.renderer) == 0)

	update_texture_result := sdl.UpdateTexture(
		window.platform.texture,
		nil,
		raw_data(pixels),
		i32(pixels_dim.x) * size_of(pixels[0]),
	)
	assert(update_texture_result == 0)

	render_copy_result := sdl.RenderCopy(
		window.platform.renderer,
		window.platform.texture,
		nil,
		nil,
	)
	assert(render_copy_result == 0)

	sdl.RenderPresent(window.platform.renderer)
}

toggle_fullscreen :: proc(window: ^Window) {
	if window.is_fullscreen {
		sdl.SetWindowFullscreen(window.platform.window, nil)
	} else {
		sdl.SetWindowFullscreen(window.platform.window, sdl.WINDOW_FULLSCREEN_DESKTOP)
	}
	window.is_fullscreen = !window.is_fullscreen
}
