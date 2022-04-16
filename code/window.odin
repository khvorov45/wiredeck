package wiredeck

Window :: struct {
	is_running:        bool,
	is_fullscreen:     bool,
	is_focused:        bool,
	is_mouse_captured: bool,
	dim:               [2]int,
	platform:          PlatformWindow,
}

CursorKind :: enum {
	Normal,
	Pointer,
	SizeWE,
	SizeNS,
}
