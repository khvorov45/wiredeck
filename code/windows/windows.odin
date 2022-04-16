//+build windows
package windows_bindings

foreign import win { "system:kernel32.lib", "system:user32.lib", "system:Gdi32.lib" }

foreign win {
	SetCapture :: proc(hWnd: HWND) -> HWND ---
	ReleaseCapture :: proc() -> BOOL ---
	GetCursorPos :: proc(lpPoint: LPPOINT) -> BOOL ---
	ScreenToClient :: proc(hWnd: HWND, lpPoint: LPPOINT) -> BOOL ---
	TrackMouseEvent :: proc(lpEventTrack: LPTRACKMOUSEEVENT) -> BOOL ---
	GetLastError :: proc() -> DWORD ---
	GetFullPathNameA :: proc(filename: cstring, buffer_length: DWORD, buffer: cstring, file_part: rawptr) -> u32 ---
	VirtualAlloc :: proc(lpAddress: LPVOID, dwSize: SIZE_T, flAllocationType, flProtect: DWORD) -> LPVOID ---
	GetModuleHandleA :: proc(lpModuleName: LPCSTR) -> HMODULE ---
	LoadCursorA :: proc(hInstance: HINSTANCE, lpCursorName: LPCSTR) -> HCURSOR ---
	RegisterClassExA :: proc(^WNDCLASSEXA) -> ATOM ---
	CreateWindowExA :: proc(
		dwExStyle: DWORD,
		lpClassName: LPCSTR,
		lpWindowName: LPCSTR,
		dwStyle: DWORD,
		X: i32,
		Y: i32,
		nWidth: i32,
		nHeight: i32,
		hWndParent: HWND,
		hMenu: HMENU,
		hInstance: HINSTANCE,
		lpParam: LPVOID,
	) -> HWND ---
	SetWindowLongPtrA :: proc(hWnd: HWND, nIndex: i32, dwNewLong: LONG_PTR) -> LONG_PTR ---
	GetWindowLongPtrA :: proc(hWnd: HWND, nIndex: i32) -> LONG_PTR ---
	GetClientRect :: proc(hWnd: HWND, lpRect: LPRECT) -> BOOL ---
	GetWindowRect :: proc(hWnd: HWND, lpRect: LPRECT) -> BOOL ---
	SetWindowPos :: proc(hWnd, hWndInsertAfter: HWND, X, Y, cx, cy: i32, uFlags: UINT) -> BOOL ---
	ShowWindow :: proc(hWnd: HWND, nCmdSho: i32) -> BOOL ---
	GetDC :: proc(hWnd: HWND) -> HDC ---
	DefWindowProcA :: proc(hWnd: HWND, Msg: UINT, wParam: WPARAM, lParam: LPARAM) -> LRESULT ---
	SetCursor :: proc(hCursor: HCURSOR) -> HCURSOR ---
	TranslateMessage :: proc(lpMsg: ^MSG) -> BOOL ---
	DispatchMessageA :: proc(lpMsg: ^MSG) -> LRESULT ---
	PeekMessageA :: proc(lpMsg: ^MSG, hWnd: HWND, wMsgFilterMin: UINT, wMsgFilterMax: UINT, wRemoveMsg: UINT) -> BOOL ---
	GetMessageA :: proc(lpMsg: ^MSG, hWnd: HWND, wMsgFilterMin: UINT, wMsgFilterMax: UINT) -> BOOL ---
	StretchDIBits :: proc(
		hdc: HDC,
		xDest: i32,
		yDest: i32,
		DestWidth: i32,
		DestHeight: i32,
		xSrc: i32,
		ySrc: i32,
		SrcWidth: i32,
		SrcHeight: i32,
		lpBits: VOID,
		lpbmi: ^BITMAPINFO,
		iUsage: UINT,
		rop: DWORD,
	) -> i32 ---
	SetWindowPlacement :: proc(hWnd: HWND, lpwndpl: ^WINDOWPLACEMENT) -> BOOL ---
	GetWindowPlacement :: proc(hWnd: HWND, lpwndpl: ^WINDOWPLACEMENT) -> BOOL ---
	GetMonitorInfoA :: proc(hMonitor: HMONITOR, lpmi: LPMONITORINFO) -> BOOL ---
	MonitorFromWindow :: proc(hwind: HWND, dwFlags: DWORD) -> HMONITOR ---
}

LOWORD :: #force_inline proc "contextless" (x: DWORD) -> WORD {
	return WORD(x & 0xffff)
}

HIWORD :: #force_inline proc "contextless" (x: DWORD) -> WORD {
	return WORD(x >> 16)
}

VOID :: rawptr
PVOID :: rawptr
LPVOID :: rawptr
HANDLE :: PVOID
HWND :: HANDLE
HINSTANCE :: HANDLE
HMODULE :: HINSTANCE
HCURSOR :: HICON
HICON :: HANDLE
HBRUSH :: HANDLE
HMENU :: HANDLE
HDC :: HANDLE
HMONITOR :: HANDLE

BOOL :: i32
LONG :: i32
UINT :: u32
WORD :: u16
DWORD :: u32
SIZE_T :: uint
LPCSTR :: cstring
LONG_PTR :: int
UINT_PTR :: uint
LRESULT :: LONG_PTR
LPARAM :: LONG_PTR
WPARAM :: UINT_PTR
ATOM :: WORD
BYTE :: u8

POINT :: struct { x, y: LONG }
LPPOINT :: ^POINT
LPTRACKMOUSEEVENT :: ^TRACKMOUSEEVENT
TRACKMOUSEEVENT :: struct { cbSize, dwFlags: DWORD, hwndTrack: HWND, dwHoverTime: DWORD }
WNDCLASSEXA :: struct {
	cbSize: UINT,
	style: UINT,
	lpfnWndProc: WNDPROC,
	cbClsExtra: i32,
	cbWndExtra: i32,
	hInstance: HINSTANCE,
	hIcon: HICON,
	hCursor: HCURSOR,
	hbrBackground: HBRUSH,
	lpszMenuName: LPCSTR,
	lpszClassName: LPCSTR,
	hIconSm: HICON,
}
WNDPROC :: #type proc "c" (HWND, UINT, WPARAM, LPARAM) -> LRESULT
RECT :: struct {left, top, right, bottom: LONG}
LPRECT :: ^RECT
BITMAPINFO :: struct {bmiHeader: BITMAPINFOHEADER, bmiColors: [1]RGBQUAD}
BITMAPINFOHEADER :: struct {
	biSize: DWORD,
	biWidth: LONG,
	biHeight: LONG,
	biPlanes: WORD,
	biBitCount: WORD,
	biCompression: DWORD,
	biSizeImage: DWORD,
	biXPelsPerMeter: LONG,
	biYPelsPerMeter: LONG,
	biClrUsed: DWORD,
	biClrImportant: DWORD,
}
RGBQUAD :: struct {rgbBlue, rgbGreen, rgbRed, rgbReserved: BYTE}
WINDOWPLACEMENT :: struct {
	length: UINT,
	flags: UINT,
	showCmd: UINT,
	ptMinPosition: POINT,
	ptMaxPosition: POINT,
	rcNormalPosition: RECT,
	rcDevice: RECT,
}
MSG :: struct {
	hwnd: HWND,
	message: UINT,
	wParam: WPARAM,
	lParam: LPARAM,
	time: DWORD,
	pt: POINT,
}
MONITORINFO :: struct {cbSize: DWORD, rcMonitor, rcWork: RECT, dwFlags: DWORD}
LPMONITORINFO :: ^MONITORINFO

TME_LEAVE :: 0x00000002
MEM_COMMIT :: 0x00001000
MEM_RESERVE :: 0x00002000
PAGE_READWRITE :: 0x04
CS_VREDRAW :: 0x0001
CS_HREDRAW :: 0x0002
WS_OVERLAPPED :: 0x00000000
WS_CAPTION :: 0x00C00000
WS_SYSMENU :: 0x00080000
WS_THICKFRAME :: 0x00040000
WS_MINIMIZEBOX :: 0x00020000
WS_MAXIMIZEBOX :: 0x00010000
WS_OVERLAPPEDWINDOW :: WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX
GWLP_USERDATA :: -21
GWL_STYLE   :: -16
SW_SHOWNORMAL :: 1
SW_SHOWMINIMIZED :: 2
BI_RGB :: 0x0000
PM_NOREMOVE :: 0x0000
PM_REMOVE :: 0x0001
PM_NOYIELD :: 0x0002
DIB_RGB_COLORS :: 0
SRCCOPY :: 0x00CC0020
SWP_NOSIZE :: 0x0001
SWP_NOMOVE :: 0x0002
SWP_NOZORDER :: 0x0004
SWP_NOREDRAW :: 0x0008
SWP_NOACTIVATE :: 0x0010
SWP_FRAMECHANGED :: 0x0020
SWP_SHOWWINDOW :: 0x0040
SWP_HIDEWINDOW :: 0x0080
SWP_NOCOPYBITS :: 0x0100
SWP_NOOWNERZORDER :: 0x0200
SWP_NOSENDCHANGING :: 0x0400
MONITOR_DEFAULTTONULL :: 0x00000000
MONITOR_DEFAULTTOPRIMARY :: 0x00000001
MONITOR_DEFAULTTONEAREST :: 0x00000002

_CW_USEDEFAULT := 0x80000000
CW_USEDEFAULT := i32(_CW_USEDEFAULT)

_IDC_ARROW := rawptr(uintptr(32512))
_IDC_SIZENS := rawptr(uintptr(32645))
_IDC_SIZEWE := rawptr(uintptr(32644))
_IDC_HAND := rawptr(uintptr(32649))

IDC_ARROW := cstring(_IDC_ARROW)
IDC_SIZENS := cstring(_IDC_SIZENS)
IDC_SIZEWE := cstring(_IDC_SIZEWE)
IDC_HAND := cstring(_IDC_HAND)
