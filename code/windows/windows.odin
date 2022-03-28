//+build windows
package windows_bindings

import "core:c"

foreign import win { "system:kernel32.lib", "system:user32.lib" }

foreign win {
	SetCapture :: proc(hWnd: HWND) -> HWND ---
	ReleaseCapture :: proc() -> BOOL ---
	GetCursorPos :: proc(lpPoint: LPPOINT) -> BOOL ---
	ScreenToClient :: proc(hWnd: HWND, lpPoint: LPPOINT) -> BOOL ---
}

HWND :: distinct rawptr
BOOL :: distinct c.int
LPPOINT :: ^POINT
POINT :: struct { x, y: LONG }
LONG :: c.long
