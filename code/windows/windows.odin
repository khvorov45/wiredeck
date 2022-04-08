//+build windows
package windows_bindings

foreign import win { "system:kernel32.lib", "system:user32.lib" }

foreign win {
	SetCapture :: proc(hWnd: HWND) -> HWND ---
	ReleaseCapture :: proc() -> BOOL ---
	GetCursorPos :: proc(lpPoint: LPPOINT) -> BOOL ---
	ScreenToClient :: proc(hWnd: HWND, lpPoint: LPPOINT) -> BOOL ---
	TrackMouseEvent :: proc(lpEventTrack: LPTRACKMOUSEEVENT) -> BOOL ---
	GetLastError :: proc() -> DWORD ---
	GetFullPathNameA :: proc(filename: cstring, buffer_length: DWORD, buffer: cstring, file_part: rawptr) -> u32 ---
	VirtualAlloc :: proc(lpAddress: LPVOID, dwSize: SIZE_T, flAllocationType, flProtect: DWORD) -> LPVOID ---
}

HWND :: distinct rawptr
BOOL :: distinct i32
LPPOINT :: ^POINT
POINT :: struct { x, y: LONG }
LONG :: i32
LPTRACKMOUSEEVENT :: ^TRACKMOUSEEVENT
TRACKMOUSEEVENT :: struct { cbSize, dwFlags: DWORD, hwndTrack: HWND, dwHoverTime: DWORD }
DWORD :: u32
LPVOID :: rawptr
SIZE_T :: uint

TME_LEAVE :: 0x00000002
MEM_COMMIT :: 0x00001000
MEM_RESERVE :: 0x00002000
PAGE_READWRITE :: 0x04
