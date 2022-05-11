package wiredeck

import "core:runtime"
import win "windows"

get_monospace_font :: proc(window: ^Window) {

	font_proc: win.FONTENUMPROCA : proc "c" (
		lpelfe: ^win.LOGFONTA, lpntme: ^win.TEXTMETRICA, FontType: win.DWORD, lParam: win.LPARAM,
	) -> i32 {
		context = (transmute(^runtime.Context)lParam)^

		if FontType == win.TRUETYPE_FONTTYPE && 
			lpelfe.lfWeight == 400 && 
			!bool(lpelfe.lfItalic) && 
			!bool(lpelfe.lfUnderline) && 
			!bool(lpelfe.lfStrikeOut) &&
			(lpelfe.lfPitchAndFamily & 3) == win.FIXED_PITCH {

			printf("%#v\n", lpntme)
			printf("%s\n", cstring(&lpelfe.lfFaceName[0]))
		}

		return 1
	}

	font_info := win.LOGFONTA{lfCharSet = win.ANSI_CHARSET}
	ctx := context
	win.EnumFontFamiliesExA(window.platform.hdc, &font_info, font_proc, transmute(win.LPARAM)&ctx, 0)
}
