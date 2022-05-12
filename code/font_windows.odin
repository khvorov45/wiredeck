package wiredeck

import "core:runtime"
import win "windows"

get_font_ttf_path :: proc(font_id: FontID) -> string {

	font_path: string
	switch font_id {
	case .Monospace: font_path = "C:\\Windows\\Fonts\\consola.ttf"
	case .Varwidth: font_path = "C:\\Windows\\Fonts\\arial.ttf"
	}

	return font_path
}
