package wiredeck

import "core:runtime"
import "core:strings"
import win "windows"

PlatformWindow :: struct {
	hwnd: win.HWND,
	hdc: win.HDC,
	pixel_info: win.BITMAPINFO,
	previous_placement: win.WINDOWPLACEMENT,
	decorations_dim: [2]int,
	cursors: [CursorKind]win.HCURSOR,
	input_modified: bool,
	mouse_inside_window: bool,
	context_creation: runtime.Context,
}

init_window :: proc(window: ^Window, title: string, width: int, height: int) {

	window_class_name := strings.clone_to_cstring(title, context.temp_allocator)
	window_name := window_class_name
	window_dim := [2]int{width, height}

	window_instance := win.GetModuleHandleA(nil)
	assert(window_instance != nil)

	cursors: [CursorKind]win.HCURSOR
	for cursor_kind in CursorKind {
		win_cursor_kind: win.LPCSTR
		switch cursor_kind {
		case .Normal: win_cursor_kind = win.IDC_ARROW
		case .Pointer: win_cursor_kind = win.IDC_HAND
		case .SizeWE: win_cursor_kind = win.IDC_SIZEWE
		case .SizeNS: win_cursor_kind = win.IDC_SIZENS
		}
		cursors[cursor_kind] = win.LoadCursorA(nil, win_cursor_kind)
		assert(cursors[cursor_kind] != nil)
	}

	window_class := win.WNDCLASSEXA{
		cbSize = size_of(win.WNDCLASSEXA),
		style = win.CS_HREDRAW | win.CS_VREDRAW,
		lpfnWndProc = _window_proc,
		hInstance = window_instance,
		lpszClassName = window_class_name,
		hCursor = nil, // NOTE(khvorov) If not null, windows will reset it on mouse move
	}
	assert(win.RegisterClassExA(&window_class) != 0)

	hwnd := win.CreateWindowExA(
		dwExStyle = 0,
		lpClassName = window_class_name,
		lpWindowName = window_name,
		dwStyle = win.WS_OVERLAPPEDWINDOW,
		X = win.CW_USEDEFAULT,
		Y = win.CW_USEDEFAULT,
		nWidth = i32(window_dim.x),
		nHeight = i32(window_dim.y),
		hWndParent = nil,
		hMenu = nil,
		hInstance = window_instance,
		lpParam = nil,
	)
	assert(hwnd != nil)

	// NOTE(khvorov) To be able to access stuff in the callback
	win.SetWindowLongPtrA(hwnd, win.GWLP_USERDATA, win.LONG_PTR(uintptr(window)))

	// NOTE(khvorov) Resize so that dim corresponds to the client area
	decorations_dim: [2]int
	{
		client_rect: win.RECT
		win.GetClientRect(hwnd, &client_rect)
		window_rect: win.RECT
		win.GetWindowRect(hwnd, &window_rect)
		client_rect_dim := [2]int{
			int(client_rect.right - client_rect.left),
			int(client_rect.bottom - client_rect.top),
		}
		window_rect_dim := [2]int{
			int(window_rect.right - window_rect.left),
			int(window_rect.bottom - window_rect.top),
		}
		decorations_dim = window_rect_dim - client_rect_dim

		win.SetWindowPos(
			hWnd = hwnd,
			hWndInsertAfter = nil,
			X = 0,
			Y = 0,
			cx = i32(width + decorations_dim.x),
			cy = i32(height + decorations_dim.y),
			uFlags = win.SWP_NOMOVE,
		)
	}

	// NOTE(khvorov) This is to prevent a white flash on window creation
	win.ShowWindow(hwnd, win.SW_SHOWMINIMIZED)
	win.ShowWindow(hwnd, win.SW_SHOWNORMAL)

	hdc := win.GetDC(hwnd)
	assert(hdc != nil)

	pixel_info := win.BITMAPINFO{
		bmiHeader = win.BITMAPINFOHEADER{
			biSize = size_of(win.BITMAPINFOHEADER),
			biWidth = i32(width),
			biHeight = -i32(height), // NOTE(khvorov) Negative means top-down
			biPlanes = 1,
			biBitCount = 32,
			biCompression = win.BI_RGB,
		},
	}

	previous_placement := win.WINDOWPLACEMENT{length = size_of(win.WINDOWPLACEMENT)}

	_track_mouse_leave(hwnd)

	window^ = Window{
		is_running = true,
		is_fullscreen = false,
		is_focused = true,
		is_mouse_captured = false,
		skip_hang_once = false,
		dim = [2]int{width, height},
		platform = {hwnd, hdc, pixel_info, previous_placement, decorations_dim, cursors, false, true, context},
	}

	set_cursor(window, .Normal)
}

_window_proc :: proc "c" (hwnd: win.HWND, msg: win.UINT, wparam: win.WPARAM, lparam: win.LPARAM) -> win.LRESULT {
	result: win.LRESULT
	window := cast(^Window)uintptr(win.GetWindowLongPtrA(hwnd, win.GWLP_USERDATA))

	if (window != nil) {
		context = window.platform.context_creation
		input_modified := true
		switch msg {
		case win.WM_DESTROY: window.is_running = false
		case win.WM_KILLFOCUS: window.is_focused = false
		case win.WM_SETFOCUS: window.is_focused = true
		case win.WM_SIZE:
			window.platform.input_modified = true
			window.dim = [2]int{int(win.LOWORD(win.DWORD(lparam))), int(win.HIWORD(win.DWORD(lparam)))}
		case: input_modified = false
		}
		window.platform.input_modified ||= input_modified
	}

	result = win.DefWindowProcA(hwnd, msg, wparam, lparam)
	return result
}

_track_mouse_leave :: proc(hwnd: win.HWND) {
	track_mouse := win.TRACKMOUSEEVENT{
		cbSize = size_of(win.TRACKMOUSEEVENT),
		dwFlags = win.TME_LEAVE,
		hwndTrack = hwnd,
	}
	win.TrackMouseEvent(&track_mouse)
}

set_mouse_capture :: proc(window: ^Window, state: bool) {
	if state {
		win.SetCapture(window.platform.hwnd)
	} else {
		win.ReleaseCapture()
	}
	window.is_mouse_captured = state
}

set_cursor :: proc(window: ^Window, cursor: CursorKind) {
	win.SetCursor(window.platform.cursors[cursor])
}

_record_event :: proc(window: ^Window, input: ^Input, event: ^win.MSG) {
	switch event.message {

	case win.WM_KEYDOWN, win.WM_SYSKEYDOWN, win.WM_KEYUP, win.WM_SYSKEYUP:
		if window.is_focused {
			window.platform.input_modified = true
			ended_down := (event.lParam & (1 << 31)) == 0

			switch event.wParam {
			case win.VK_RETURN: record_key(input, .Enter, ended_down)
			case win.VK_MENU:
				if event.lParam & (1 << 24) != 0 {
					record_key(input, .AltR, ended_down)
				} else {
					record_key(input, .AltL, ended_down)
				}
			case 'W': record_key(input, .W, ended_down)
			case 'A': record_key(input, .A, ended_down)
			case 'S': record_key(input, .S, ended_down)
			case 'D': record_key(input, .D, ended_down)
			case 'Q': record_key(input, .Q, ended_down)
			case 'E': record_key(input, .E, ended_down)
			case '1': record_key(input, .Digit1, ended_down)
			case '2': record_key(input, .Digit2, ended_down)
			case '3': record_key(input, .Digit3, ended_down)
			case '4': record_key(input, .Digit4, ended_down)
			case '5': record_key(input, .Digit5, ended_down)
			case '6': record_key(input, .Digit6, ended_down)
			case '7': record_key(input, .Digit7, ended_down)
			case '8': record_key(input, .Digit8, ended_down)
			case '9': record_key(input, .Digit9, ended_down)
			case '0': record_key(input, .Digit0, ended_down)
			case win.VK_SHIFT: record_key(input, .Shift, ended_down)
			case win.VK_SPACE: record_key(input, .Space, ended_down)
			case win.VK_CONTROL: record_key(input, .Ctrl, ended_down)
			case win.VK_F1: record_key(input, .F1, ended_down)
			case win.VK_F4: record_key(input, .F4, ended_down)
			case win.VK_F11: record_key(input, .F11, ended_down)
			case: window.platform.input_modified = false
			}
		}

	case win.WM_LBUTTONDOWN, win.WM_MBUTTONDOWN, win.WM_RBUTTONDOWN, win.WM_LBUTTONUP, win.WM_MBUTTONUP, win.WM_RBUTTONUP:
		window.platform.input_modified = true
		switch event.message {
			case win.WM_LBUTTONDOWN: record_mouse_button(input, .MouseLeft, true)
			case win.WM_MBUTTONDOWN: record_mouse_button(input, .MouseMiddle, true)
			case win.WM_RBUTTONDOWN: record_mouse_button(input, .MouseRight, true)
			case win.WM_LBUTTONUP: record_mouse_button(input, .MouseLeft, false)
			case win.WM_MBUTTONUP: record_mouse_button(input, .MouseMiddle, false)
			case win.WM_RBUTTONUP: record_mouse_button(input, .MouseRight, false)
		}

	case win.WM_MOUSELEAVE:
		window.platform.mouse_inside_window = false
		if window.is_focused || window.is_mouse_captured {
			window.platform.input_modified = true
			if !window.is_mouse_captured {
				input.cursor_pos = -1
			}
		}

	case win.WM_MOUSEWHEEL:
		if window.is_focused || window.is_mouse_captured {
			window.platform.input_modified = true
			delta := -int(transmute(i16)(win.HIWORD(win.DWORD(event.wParam)))) / 120
			if input.keys[.Shift].ended_down {
				input.scroll.x = delta
			} else {
				input.scroll.y = delta
			}
		}

	case win.WM_MOUSEMOVE:
		if !window.platform.mouse_inside_window {
			window.platform.mouse_inside_window = true
			_track_mouse_leave(window.platform.hwnd)
		}
		window.platform.input_modified = true
		input.cursor_pos = [2]int{
			int(transmute(i16)win.LOWORD(win.DWORD(event.lParam))),
			int(transmute(i16)win.HIWORD(win.DWORD(event.lParam))),
		}

	case win.WM_PAINT:
		window.platform.input_modified = true
		win.TranslateMessage(event)
		win.DispatchMessageA(event)

	case:
		win.TranslateMessage(event)
		win.DispatchMessageA(event)
	}
}

wait_for_input :: proc(window: ^Window, input: ^Input) {

	clear_half_transitions(input)
	input.scroll = 0
	window.platform.input_modified = false

	for {
		event: win.MSG
		if win.PeekMessageA(&event, window.platform.hwnd, 0, 0, win.PM_REMOVE) == 0 {
			if window.platform.input_modified || window.skip_hang_once {
				window.skip_hang_once = false
				break
			} else {
				win.GetMessageA(&event, window.platform.hwnd, 0, 0)
			}
		}

		_record_event(window, input, &event)
	}
}

display_pixels :: proc(window: ^Window, pixels: []u32, pixels_dim: [2]int) {
	if window.is_running {
		window.platform.pixel_info.bmiHeader.biWidth = i32(pixels_dim.x)
		window.platform.pixel_info.bmiHeader.biHeight = -i32(pixels_dim.y)
		result := win.StretchDIBits(
			hdc = window.platform.hdc,
			xDest = 0,
			yDest = 0,
			DestWidth = i32(window.dim.x),
			DestHeight = i32(window.dim.y),
			xSrc = 0,
			ySrc = 0,
			SrcWidth = i32(pixels_dim.x),
			SrcHeight = i32(pixels_dim.y),
			lpBits = raw_data(pixels),
			lpbmi = &window.platform.pixel_info,
			iUsage = win.DIB_RGB_COLORS,
			rop = win.SRCCOPY,
		)
		assert(
			result == i32(pixels_dim.y),
			tprintf("expected {}, got {}\n", pixels_dim.y, result),
		)
	}
}

// Taken from https://devblogs.microsoft.com/oldnewthing/20100412-00/?p=14353
toggle_fullscreen :: proc(window: ^Window) {

	style := win.GetWindowLongPtrA(window.platform.hwnd, win.GWL_STYLE)

	if window.is_fullscreen {

		win.SetWindowLongPtrA(
			window.platform.hwnd,
			win.GWL_STYLE,
			win.LONG_PTR(uint(style) | uint(win.WS_OVERLAPPEDWINDOW)),
		)

		win.SetWindowPlacement(window.platform.hwnd, &window.platform.previous_placement)

		win.SetWindowPos(
			hWnd = window.platform.hwnd,
			hWndInsertAfter = nil,
			X = 0,
			Y = 0,
			cx = 0,
			cy = 0,
			uFlags = win.SWP_NOMOVE | win.SWP_NOSIZE | win.SWP_NOZORDER | win.SWP_NOOWNERZORDER | win.SWP_FRAMECHANGED,
		)

	} else {

		mi := win.MONITORINFO{cbSize = size_of(win.MONITORINFO)}
		get_monitor_result := win.GetMonitorInfoA(
			win.MonitorFromWindow(window.platform.hwnd, win.MONITOR_DEFAULTTOPRIMARY),
			&mi,
		)
		assert(bool(get_monitor_result))

		get_window_placement_result := win.GetWindowPlacement(
			window.platform.hwnd,
			&window.platform.previous_placement,
		)
		assert(bool(get_window_placement_result))

		win.SetWindowLongPtrA(
			window.platform.hwnd,
			win.GWL_STYLE,
			win.LONG_PTR(uint(style) & ~uint(win.WS_OVERLAPPEDWINDOW)),
		)

		win.SetWindowPos(
			hWnd = window.platform.hwnd,
			hWndInsertAfter = nil,
			X = mi.rcMonitor.left,
			Y = mi.rcMonitor.top,
			cx = mi.rcMonitor.right - mi.rcMonitor.left,
			cy = mi.rcMonitor.bottom - mi.rcMonitor.top,
			uFlags = win.SWP_NOOWNERZORDER | win.SWP_FRAMECHANGED,
		)

	}

	window.is_fullscreen = !window.is_fullscreen
}
