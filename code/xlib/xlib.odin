//+build linux
package xlib_bindings

import "core:c"

foreign import xlib "system:X11"

foreign xlib {
	XInitThreads :: proc() -> Status --- 

	XOpenDisplay :: proc(display_name: cstring) -> ^Display --- 

	XDefaultVisual :: proc(display: ^Display, screen_number: c.int) -> VisualHandle --- 

	XInternAtom :: proc(display: ^Display, atom_name: cstring, only_if_exists: Bool) -> Atom --- 
	XCreateFontCursor :: proc(display: ^Display, shape: c.uint) -> Cursor --- 

	XSetLocaleModifiers :: proc(modifier_list: cstring) -> cstring --- 

	XOpenIM :: proc(
		display: ^Display,
		rdb: XrmHashBucketRecHandle,
		res_name: cstring,
		res_class: cstring,
	) -> XIM --- 

	XCreateWindow :: proc(
		display: ^Display,
		parent: Window,
		x: c.int,
		y: c.int,
		width: c.uint,
		height: c.uint,
		border_width: c.uint,
		depth: c.int,
		class: c.uint,
		visual: VisualHandle,
		valuemask: c.ulong,
		attributes: ^XSetWindowAttributes,
	) -> Window --- 

	XFlush :: proc(display: ^Display) -> c.int --- 

	XStoreName :: proc(display: ^Display, window: Window, window_name: cstring) -> c.int --- 

	XSelectInput :: proc(display: ^Display, window: Window, event_mask: c.long) -> c.int --- 

	XChangeProperty :: proc(
		diplay: ^Display,
		window: Window,
		property: Atom,
		type: Atom,
		format: c.int,
		mode: c.int,
		data: rawptr,
		nelements: c.int,
	) -> c.int --- 

	XMapRaised :: proc(display: ^Display, window: Window) -> c.int --- 

	XSetWMProtocols :: proc(
		display: ^Display,
		window: Window,
		protocols: ^Atom,
		count: c.int,
	) -> Status --- 

	XTranslateCoordinates :: proc(
		display: ^Display,
		src_w: Window,
		dest_w: Window,
		src_x: c.int,
		src_y: c.int,
		dest_x: ^c.int,
		dest_y: ^c.int,
		child: ^Window,
	) -> Bool --- 

	XMoveResizeWindow :: proc(
		display: ^Display,
		window: Window,
		x: c.int,
		y: c.int,
		width: c.uint,
		height: c.uint,
	) -> c.int --- 

	XCreateImage :: proc(
		display: ^Display,
		visual: VisualHandle,
		depth: c.uint,
		format: c.int,
		offset: c.int,
		data: rawptr,
		width: c.uint,
		height: c.uint,
		bitmap_pad: c.int,
		bytes_per_line: c.int,
	) -> ^XImage --- 

	XCreateIC :: proc(im: XIM, #c_vararg args: ..any) -> XIC --- 

	XPending :: proc(display: ^Display) -> c.int --- 

	XNextEvent :: proc(display: ^Display, event: ^XEvent) -> c.int --- 

	XDestroyWindow :: proc(display: ^Display, window: Window) -> c.int --- 

	XDestroyIC :: proc(ic: XIC) --- 

	XPutImage :: proc(
		display: ^Display,
		drawable: Drawable,
		gc: GC,
		image: ^XImage,
		src_x: c.int,
		src_y: c.int,
		dest_x: c.int,
		dest_y: c.int,
		width: c.uint,
		height: c.uint,
	) -> c.int --- 

	XDefineCursor :: proc(display: ^Display, window: Window, cursor: Cursor) -> c.int --- 

	XLookupKeysym :: proc(key_event: ^XKeyEvent, index: int) -> KeySym --- 

	Xutf8LookupString :: proc(
		ic: XIC,
		event: ^XKeyPressedEvent,
		buffer_return: cstring,
		bytes_buffer: int,
		keysym_return: ^KeySym,
		status_return: ^Status,
	) -> c.int ---
}

DefaultRootWindow :: proc(display: ^Display) -> Window {
	return ScreenOfDisplay(display, DefaultScreen(display)).root
}

ScreenOfDisplay :: proc(display: ^Display, src: c.int) -> Screen {
	return display.screens[src]
}

DefaultScreen :: proc(display: ^Display) -> c.int {
	return display.default_screen
}

XDestroyImage :: proc(image: ^XImage) {
	image.f.destroy_image(image)
}

DefaultGC :: proc(display: ^Display, src: c.int) -> GC {
	return ScreenOfDisplay(display, src).default_gc
}

InputOutput :: 1
CopyFromParent :: 0
CWOverrideRedirect :: 1 << 9
XA_ATOM :: 4
PropModeReplace :: 0
ZPixmap :: 2
XNInputStyle :: "inputStyle"
XIMPreeditNothing :: 0x0008
XIMStatusNothing :: 0x0400
XNClientWindow :: "clientWindow"
XNFocusWindow :: "focusWindow"
GC :: distinct rawptr
VisualHandle :: distinct rawptr
XIM :: distinct rawptr
Atom :: distinct c.ulong
Cursor :: distinct XID
XID :: distinct c.ulong
Bool :: distinct c.int
Status :: distinct c.int
XrmHashBucketRecHandle :: distinct rawptr
Pixmap :: distinct XID
Colormap :: distinct XID
Window :: distinct XID
Drawable :: distinct XID
KeySym :: distinct XID
XIC :: distinct rawptr
Time :: distinct c.ulong
XPointer :: distinct ^u8

XC_num_glyphs :: 154
XC_X_cursor :: 0
XC_arrow :: 2
XC_based_arrow_down :: 4
XC_based_arrow_up :: 6
XC_boat :: 8
XC_bogosity :: 10
XC_bottom_left_corner :: 12
XC_bottom_right_corner :: 14
XC_bottom_side :: 16
XC_bottom_tee :: 18
XC_box_spiral :: 20
XC_center_ptr :: 22
XC_circle :: 24
XC_clock :: 26
XC_coffee_mug :: 28
XC_cross :: 30
XC_cross_reverse :: 32
XC_crosshair :: 34
XC_diamond_cross :: 36
XC_dot :: 38
XC_dotbox :: 40
XC_double_arrow :: 42
XC_draft_large :: 44
XC_draft_small :: 46
XC_draped_box :: 48
XC_exchange :: 50
XC_fleur :: 52
XC_gobbler :: 54
XC_gumby :: 56
XC_hand1 :: 58
XC_hand2 :: 60
XC_heart :: 62
XC_icon :: 64
XC_iron_cross :: 66
XC_left_ptr :: 68
XC_left_side :: 70
XC_left_tee :: 72
XC_leftbutton :: 74
XC_ll_angle :: 76
XC_lr_angle :: 78
XC_man :: 80
XC_middlebutton :: 82
XC_mouse :: 84
XC_pencil :: 86
XC_pirate :: 88
XC_plus :: 90
XC_question_arrow :: 92
XC_right_ptr :: 94
XC_right_side :: 96
XC_right_tee :: 98
XC_rightbutton :: 100
XC_rtl_logo :: 102
XC_sailboat :: 104
XC_sb_down_arrow :: 106
XC_sb_h_double_arrow :: 108
XC_sb_left_arrow :: 110
XC_sb_right_arrow :: 112
XC_sb_up_arrow :: 114
XC_sb_v_double_arrow :: 116
XC_shuttle :: 118
XC_sizing :: 120
XC_spider :: 122
XC_spraycan :: 124
XC_star :: 126
XC_target :: 128
XC_tcross :: 130
XC_top_left_arrow :: 132
XC_top_left_corner :: 134
XC_top_right_corner :: 136
XC_top_side :: 138
XC_top_tee :: 140
XC_trek :: 142
XC_ul_angle :: 144
XC_umbrella :: 146
XC_ur_angle :: 148
XC_watch :: 150
XC_xterm :: 152

XK_space :: 0x0020 /* U+0020 SPACE */
XK_exclam :: 0x0021 /* U+0021 EXCLAMATION MARK */
XK_quotedbl :: 0x0022 /* U+0022 QUOTATION MARK */
XK_numbersign :: 0x0023 /* U+0023 NUMBER SIGN */
XK_dollar :: 0x0024 /* U+0024 DOLLAR SIGN */
XK_percent :: 0x0025 /* U+0025 PERCENT SIGN */
XK_ampersand :: 0x0026 /* U+0026 AMPERSAND */
XK_apostrophe :: 0x0027 /* U+0027 APOSTROPHE */
XK_quoteright :: 0x0027 /* deprecated */
XK_parenleft :: 0x0028 /* U+0028 LEFT PARENTHESIS */
XK_parenright :: 0x0029 /* U+0029 RIGHT PARENTHESIS */
XK_asterisk :: 0x002a /* U+002A ASTERISK */
XK_plus :: 0x002b /* U+002B PLUS SIGN */
XK_comma :: 0x002c /* U+002C COMMA */
XK_minus :: 0x002d /* U+002D HYPHEN-MINUS */
XK_period :: 0x002e /* U+002E FULL STOP */
XK_slash :: 0x002f /* U+002F SOLIDUS */
XK_0 :: 0x0030 /* U+0030 DIGIT ZERO */
XK_1 :: 0x0031 /* U+0031 DIGIT ONE */
XK_2 :: 0x0032 /* U+0032 DIGIT TWO */
XK_3 :: 0x0033 /* U+0033 DIGIT THREE */
XK_4 :: 0x0034 /* U+0034 DIGIT FOUR */
XK_5 :: 0x0035 /* U+0035 DIGIT FIVE */
XK_6 :: 0x0036 /* U+0036 DIGIT SIX */
XK_7 :: 0x0037 /* U+0037 DIGIT SEVEN */
XK_8 :: 0x0038 /* U+0038 DIGIT EIGHT */
XK_9 :: 0x0039 /* U+0039 DIGIT NINE */
XK_colon :: 0x003a /* U+003A COLON */
XK_semicolon :: 0x003b /* U+003B SEMICOLON */
XK_less :: 0x003c /* U+003C LESS-THAN SIGN */
XK_equal :: 0x003d /* U+003D EQUALS SIGN */
XK_greater :: 0x003e /* U+003E GREATER-THAN SIGN */
XK_question :: 0x003f /* U+003F QUESTION MARK */
XK_at :: 0x0040 /* U+0040 COMMERCIAL AT */
XK_A :: 0x0041 /* U+0041 LATIN CAPITAL LETTER A */
XK_B :: 0x0042 /* U+0042 LATIN CAPITAL LETTER B */
XK_C :: 0x0043 /* U+0043 LATIN CAPITAL LETTER C */
XK_D :: 0x0044 /* U+0044 LATIN CAPITAL LETTER D */
XK_E :: 0x0045 /* U+0045 LATIN CAPITAL LETTER E */
XK_F :: 0x0046 /* U+0046 LATIN CAPITAL LETTER F */
XK_G :: 0x0047 /* U+0047 LATIN CAPITAL LETTER G */
XK_H :: 0x0048 /* U+0048 LATIN CAPITAL LETTER H */
XK_I :: 0x0049 /* U+0049 LATIN CAPITAL LETTER I */
XK_J :: 0x004a /* U+004A LATIN CAPITAL LETTER J */
XK_K :: 0x004b /* U+004B LATIN CAPITAL LETTER K */
XK_L :: 0x004c /* U+004C LATIN CAPITAL LETTER L */
XK_M :: 0x004d /* U+004D LATIN CAPITAL LETTER M */
XK_N :: 0x004e /* U+004E LATIN CAPITAL LETTER N */
XK_O :: 0x004f /* U+004F LATIN CAPITAL LETTER O */
XK_P :: 0x0050 /* U+0050 LATIN CAPITAL LETTER P */
XK_Q :: 0x0051 /* U+0051 LATIN CAPITAL LETTER Q */
XK_R :: 0x0052 /* U+0052 LATIN CAPITAL LETTER R */
XK_S :: 0x0053 /* U+0053 LATIN CAPITAL LETTER S */
XK_T :: 0x0054 /* U+0054 LATIN CAPITAL LETTER T */
XK_U :: 0x0055 /* U+0055 LATIN CAPITAL LETTER U */
XK_V :: 0x0056 /* U+0056 LATIN CAPITAL LETTER V */
XK_W :: 0x0057 /* U+0057 LATIN CAPITAL LETTER W */
XK_X :: 0x0058 /* U+0058 LATIN CAPITAL LETTER X */
XK_Y :: 0x0059 /* U+0059 LATIN CAPITAL LETTER Y */
XK_Z :: 0x005a /* U+005A LATIN CAPITAL LETTER Z */
XK_bracketleft :: 0x005b /* U+005B LEFT SQUARE BRACKET */
XK_backslash :: 0x005c /* U+005C REVERSE SOLIDUS */
XK_bracketright :: 0x005d /* U+005D RIGHT SQUARE BRACKET */
XK_asciicircum :: 0x005e /* U+005E CIRCUMFLEX ACCENT */
XK_underscore :: 0x005f /* U+005F LOW LINE */
XK_grave :: 0x0060 /* U+0060 GRAVE ACCENT */
XK_quoteleft :: 0x0060 /* deprecated */
XK_a :: 0x0061 /* U+0061 LATIN SMALL LETTER A */
XK_b :: 0x0062 /* U+0062 LATIN SMALL LETTER B */
XK_c :: 0x0063 /* U+0063 LATIN SMALL LETTER C */
XK_d :: 0x0064 /* U+0064 LATIN SMALL LETTER D */
XK_e :: 0x0065 /* U+0065 LATIN SMALL LETTER E */
XK_f :: 0x0066 /* U+0066 LATIN SMALL LETTER F */
XK_g :: 0x0067 /* U+0067 LATIN SMALL LETTER G */
XK_h :: 0x0068 /* U+0068 LATIN SMALL LETTER H */
XK_i :: 0x0069 /* U+0069 LATIN SMALL LETTER I */
XK_j :: 0x006a /* U+006A LATIN SMALL LETTER J */
XK_k :: 0x006b /* U+006B LATIN SMALL LETTER K */
XK_l :: 0x006c /* U+006C LATIN SMALL LETTER L */
XK_m :: 0x006d /* U+006D LATIN SMALL LETTER M */
XK_n :: 0x006e /* U+006E LATIN SMALL LETTER N */
XK_o :: 0x006f /* U+006F LATIN SMALL LETTER O */
XK_p :: 0x0070 /* U+0070 LATIN SMALL LETTER P */
XK_q :: 0x0071 /* U+0071 LATIN SMALL LETTER Q */
XK_r :: 0x0072 /* U+0072 LATIN SMALL LETTER R */
XK_s :: 0x0073 /* U+0073 LATIN SMALL LETTER S */
XK_t :: 0x0074 /* U+0074 LATIN SMALL LETTER T */
XK_u :: 0x0075 /* U+0075 LATIN SMALL LETTER U */
XK_v :: 0x0076 /* U+0076 LATIN SMALL LETTER V */
XK_w :: 0x0077 /* U+0077 LATIN SMALL LETTER W */
XK_x :: 0x0078 /* U+0078 LATIN SMALL LETTER X */
XK_y :: 0x0079 /* U+0079 LATIN SMALL LETTER Y */
XK_z :: 0x007a /* U+007A LATIN SMALL LETTER Z */
XK_braceleft :: 0x007b /* U+007B LEFT CURLY BRACKET */
XK_bar :: 0x007c /* U+007C VERTICAL LINE */
XK_braceright :: 0x007d /* U+007D RIGHT CURLY BRACKET */
XK_asciitilde :: 0x007e /* U+007E TILDE */
XK_nobreakspace :: 0x00a0 /* U+00A0 NO-BREAK SPACE */
XK_exclamdown :: 0x00a1 /* U+00A1 INVERTED EXCLAMATION MARK */
XK_cent :: 0x00a2 /* U+00A2 CENT SIGN */
XK_sterling :: 0x00a3 /* U+00A3 POUND SIGN */
XK_currency :: 0x00a4 /* U+00A4 CURRENCY SIGN */
XK_yen :: 0x00a5 /* U+00A5 YEN SIGN */
XK_brokenbar :: 0x00a6 /* U+00A6 BROKEN BAR */
XK_section :: 0x00a7 /* U+00A7 SECTION SIGN */
XK_diaeresis :: 0x00a8 /* U+00A8 DIAERESIS */
XK_copyright :: 0x00a9 /* U+00A9 COPYRIGHT SIGN */
XK_ordfeminine :: 0x00aa /* U+00AA FEMININE ORDINAL INDICATOR */
XK_guillemotleft :: 0x00ab /* U+00AB LEFT-POINTING DOUBLE ANGLE QUOTATION MARK */
XK_notsign :: 0x00ac /* U+00AC NOT SIGN */
XK_hyphen :: 0x00ad /* U+00AD SOFT HYPHEN */
XK_registered :: 0x00ae /* U+00AE REGISTERED SIGN */
XK_macron :: 0x00af /* U+00AF MACRON */
XK_degree :: 0x00b0 /* U+00B0 DEGREE SIGN */
XK_plusminus :: 0x00b1 /* U+00B1 PLUS-MINUS SIGN */
XK_twosuperior :: 0x00b2 /* U+00B2 SUPERSCRIPT TWO */
XK_threesuperior :: 0x00b3 /* U+00B3 SUPERSCRIPT THREE */
XK_acute :: 0x00b4 /* U+00B4 ACUTE ACCENT */
XK_mu :: 0x00b5 /* U+00B5 MICRO SIGN */
XK_paragraph :: 0x00b6 /* U+00B6 PILCROW SIGN */
XK_periodcentered :: 0x00b7 /* U+00B7 MIDDLE DOT */
XK_cedilla :: 0x00b8 /* U+00B8 CEDILLA */
XK_onesuperior :: 0x00b9 /* U+00B9 SUPERSCRIPT ONE */
XK_masculine :: 0x00ba /* U+00BA MASCULINE ORDINAL INDICATOR */
XK_guillemotright :: 0x00bb /* U+00BB RIGHT-POINTING DOUBLE ANGLE QUOTATION MARK */
XK_onequarter :: 0x00bc /* U+00BC VULGAR FRACTION ONE QUARTER */
XK_onehalf :: 0x00bd /* U+00BD VULGAR FRACTION ONE HALF */
XK_threequarters :: 0x00be /* U+00BE VULGAR FRACTION THREE QUARTERS */
XK_questiondown :: 0x00bf /* U+00BF INVERTED QUESTION MARK */
XK_Agrave :: 0x00c0 /* U+00C0 LATIN CAPITAL LETTER A WITH GRAVE */
XK_Aacute :: 0x00c1 /* U+00C1 LATIN CAPITAL LETTER A WITH ACUTE */
XK_Acircumflex :: 0x00c2 /* U+00C2 LATIN CAPITAL LETTER A WITH CIRCUMFLEX */
XK_Atilde :: 0x00c3 /* U+00C3 LATIN CAPITAL LETTER A WITH TILDE */
XK_Adiaeresis :: 0x00c4 /* U+00C4 LATIN CAPITAL LETTER A WITH DIAERESIS */
XK_Aring :: 0x00c5 /* U+00C5 LATIN CAPITAL LETTER A WITH RING ABOVE */
XK_AE :: 0x00c6 /* U+00C6 LATIN CAPITAL LETTER AE */
XK_Ccedilla :: 0x00c7 /* U+00C7 LATIN CAPITAL LETTER C WITH CEDILLA */
XK_Egrave :: 0x00c8 /* U+00C8 LATIN CAPITAL LETTER E WITH GRAVE */
XK_Eacute :: 0x00c9 /* U+00C9 LATIN CAPITAL LETTER E WITH ACUTE */
XK_Ecircumflex :: 0x00ca /* U+00CA LATIN CAPITAL LETTER E WITH CIRCUMFLEX */
XK_Ediaeresis :: 0x00cb /* U+00CB LATIN CAPITAL LETTER E WITH DIAERESIS */
XK_Igrave :: 0x00cc /* U+00CC LATIN CAPITAL LETTER I WITH GRAVE */
XK_Iacute :: 0x00cd /* U+00CD LATIN CAPITAL LETTER I WITH ACUTE */
XK_Icircumflex :: 0x00ce /* U+00CE LATIN CAPITAL LETTER I WITH CIRCUMFLEX */
XK_Idiaeresis :: 0x00cf /* U+00CF LATIN CAPITAL LETTER I WITH DIAERESIS */
XK_ETH :: 0x00d0 /* U+00D0 LATIN CAPITAL LETTER ETH */
XK_Eth :: 0x00d0 /* deprecated */
XK_Ntilde :: 0x00d1 /* U+00D1 LATIN CAPITAL LETTER N WITH TILDE */
XK_Ograve :: 0x00d2 /* U+00D2 LATIN CAPITAL LETTER O WITH GRAVE */
XK_Oacute :: 0x00d3 /* U+00D3 LATIN CAPITAL LETTER O WITH ACUTE */
XK_Ocircumflex :: 0x00d4 /* U+00D4 LATIN CAPITAL LETTER O WITH CIRCUMFLEX */
XK_Otilde :: 0x00d5 /* U+00D5 LATIN CAPITAL LETTER O WITH TILDE */
XK_Odiaeresis :: 0x00d6 /* U+00D6 LATIN CAPITAL LETTER O WITH DIAERESIS */
XK_multiply :: 0x00d7 /* U+00D7 MULTIPLICATION SIGN */
XK_Oslash :: 0x00d8 /* U+00D8 LATIN CAPITAL LETTER O WITH STROKE */
XK_Ooblique :: 0x00d8 /* U+00D8 LATIN CAPITAL LETTER O WITH STROKE */
XK_Ugrave :: 0x00d9 /* U+00D9 LATIN CAPITAL LETTER U WITH GRAVE */
XK_Uacute :: 0x00da /* U+00DA LATIN CAPITAL LETTER U WITH ACUTE */
XK_Ucircumflex :: 0x00db /* U+00DB LATIN CAPITAL LETTER U WITH CIRCUMFLEX */
XK_Udiaeresis :: 0x00dc /* U+00DC LATIN CAPITAL LETTER U WITH DIAERESIS */
XK_Yacute :: 0x00dd /* U+00DD LATIN CAPITAL LETTER Y WITH ACUTE */
XK_THORN :: 0x00de /* U+00DE LATIN CAPITAL LETTER THORN */
XK_Thorn :: 0x00de /* deprecated */
XK_ssharp :: 0x00df /* U+00DF LATIN SMALL LETTER SHARP S */
XK_agrave :: 0x00e0 /* U+00E0 LATIN SMALL LETTER A WITH GRAVE */
XK_aacute :: 0x00e1 /* U+00E1 LATIN SMALL LETTER A WITH ACUTE */
XK_acircumflex :: 0x00e2 /* U+00E2 LATIN SMALL LETTER A WITH CIRCUMFLEX */
XK_atilde :: 0x00e3 /* U+00E3 LATIN SMALL LETTER A WITH TILDE */
XK_adiaeresis :: 0x00e4 /* U+00E4 LATIN SMALL LETTER A WITH DIAERESIS */
XK_aring :: 0x00e5 /* U+00E5 LATIN SMALL LETTER A WITH RING ABOVE */
XK_ae :: 0x00e6 /* U+00E6 LATIN SMALL LETTER AE */
XK_ccedilla :: 0x00e7 /* U+00E7 LATIN SMALL LETTER C WITH CEDILLA */
XK_egrave :: 0x00e8 /* U+00E8 LATIN SMALL LETTER E WITH GRAVE */
XK_eacute :: 0x00e9 /* U+00E9 LATIN SMALL LETTER E WITH ACUTE */
XK_ecircumflex :: 0x00ea /* U+00EA LATIN SMALL LETTER E WITH CIRCUMFLEX */
XK_ediaeresis :: 0x00eb /* U+00EB LATIN SMALL LETTER E WITH DIAERESIS */
XK_igrave :: 0x00ec /* U+00EC LATIN SMALL LETTER I WITH GRAVE */
XK_iacute :: 0x00ed /* U+00ED LATIN SMALL LETTER I WITH ACUTE */
XK_icircumflex :: 0x00ee /* U+00EE LATIN SMALL LETTER I WITH CIRCUMFLEX */
XK_idiaeresis :: 0x00ef /* U+00EF LATIN SMALL LETTER I WITH DIAERESIS */
XK_eth :: 0x00f0 /* U+00F0 LATIN SMALL LETTER ETH */
XK_ntilde :: 0x00f1 /* U+00F1 LATIN SMALL LETTER N WITH TILDE */
XK_ograve :: 0x00f2 /* U+00F2 LATIN SMALL LETTER O WITH GRAVE */
XK_oacute :: 0x00f3 /* U+00F3 LATIN SMALL LETTER O WITH ACUTE */
XK_ocircumflex :: 0x00f4 /* U+00F4 LATIN SMALL LETTER O WITH CIRCUMFLEX */
XK_otilde :: 0x00f5 /* U+00F5 LATIN SMALL LETTER O WITH TILDE */
XK_odiaeresis :: 0x00f6 /* U+00F6 LATIN SMALL LETTER O WITH DIAERESIS */
XK_division :: 0x00f7 /* U+00F7 DIVISION SIGN */
XK_oslash :: 0x00f8 /* U+00F8 LATIN SMALL LETTER O WITH STROKE */
XK_ooblique :: 0x00f8 /* U+00F8 LATIN SMALL LETTER O WITH STROKE */
XK_ugrave :: 0x00f9 /* U+00F9 LATIN SMALL LETTER U WITH GRAVE */
XK_uacute :: 0x00fa /* U+00FA LATIN SMALL LETTER U WITH ACUTE */
XK_ucircumflex :: 0x00fb /* U+00FB LATIN SMALL LETTER U WITH CIRCUMFLEX */
XK_udiaeresis :: 0x00fc /* U+00FC LATIN SMALL LETTER U WITH DIAERESIS */
XK_yacute :: 0x00fd /* U+00FD LATIN SMALL LETTER Y WITH ACUTE */
XK_thorn :: 0x00fe /* U+00FE LATIN SMALL LETTER THORN */
XK_ydiaeresis :: 0x00ff /* U+00FF LATIN SMALL LETTER Y WITH DIAERESIS */

XK_BackSpace :: 0xff08 /* Back space, back char */
XK_Tab :: 0xff09
XK_Linefeed :: 0xff0a /* Linefeed, LF */
XK_Clear :: 0xff0b
XK_Return :: 0xff0d /* Return, enter */
XK_Pause :: 0xff13 /* Pause, hold */
XK_Scroll_Lock :: 0xff14
XK_Sys_Req :: 0xff15
XK_Escape :: 0xff1b
XK_Delete :: 0xffff /* Delete, rubout */

XK_F1 :: 0xffbe
XK_F2 :: 0xffbf
XK_F3 :: 0xffc0
XK_F4 :: 0xffc1
XK_F5 :: 0xffc2
XK_F6 :: 0xffc3
XK_F7 :: 0xffc4
XK_F8 :: 0xffc5
XK_F9 :: 0xffc6
XK_F10 :: 0xffc7
XK_F11 :: 0xffc8
XK_L1 :: 0xffc8
XK_F12 :: 0xffc9
XK_L2 :: 0xffc9
XK_F13 :: 0xffca
XK_L3 :: 0xffca
XK_F14 :: 0xffcb
XK_L4 :: 0xffcb
XK_F15 :: 0xffcc
XK_L5 :: 0xffcc
XK_F16 :: 0xffcd
XK_L6 :: 0xffcd
XK_F17 :: 0xffce
XK_L7 :: 0xffce
XK_F18 :: 0xffcf
XK_L8 :: 0xffcf
XK_F19 :: 0xffd0
XK_L9 :: 0xffd0
XK_F20 :: 0xffd1
XK_L10 :: 0xffd1
XK_F21 :: 0xffd2
XK_R1 :: 0xffd2
XK_F22 :: 0xffd3
XK_R2 :: 0xffd3
XK_F23 :: 0xffd4
XK_R3 :: 0xffd4
XK_F24 :: 0xffd5
XK_R4 :: 0xffd5
XK_F25 :: 0xffd6
XK_R5 :: 0xffd6
XK_F26 :: 0xffd7
XK_R6 :: 0xffd7
XK_F27 :: 0xffd8
XK_R7 :: 0xffd8
XK_F28 :: 0xffd9
XK_R8 :: 0xffd9
XK_F29 :: 0xffda
XK_R9 :: 0xffda
XK_F30 :: 0xffdb
XK_R10 :: 0xffdb
XK_F31 :: 0xffdc
XK_R11 :: 0xffdc
XK_F32 :: 0xffdd
XK_R12 :: 0xffdd
XK_F33 :: 0xffde
XK_R13 :: 0xffde
XK_F34 :: 0xffdf
XK_R14 :: 0xffdf
XK_F35 :: 0xffe0
XK_R15 :: 0xffe0

XK_Home :: 0xff50
XK_Left :: 0xff51 /* Move left, left arrow */
XK_Up :: 0xff52 /* Move up, up arrow */
XK_Right :: 0xff53 /* Move right, right arrow */
XK_Down :: 0xff54 /* Move down, down arrow */
XK_Prior :: 0xff55 /* Prior, previous */
XK_Page_Up :: 0xff55
XK_Next :: 0xff56 /* Next */
XK_Page_Down :: 0xff56
XK_End :: 0xff57 /* EOL */
XK_Begin :: 0xff58 /* BOL */

XK_Shift_L :: 0xffe1 /* Left shift */
XK_Shift_R :: 0xffe2 /* Right shift */
XK_Control_L :: 0xffe3 /* Left control */
XK_Control_R :: 0xffe4 /* Right control */
XK_Caps_Lock :: 0xffe5 /* Caps lock */
XK_Shift_Lock :: 0xffe6 /* Shift lock */
XK_Meta_L :: 0xffe7 /* Left meta */
XK_Meta_R :: 0xffe8 /* Right meta */
XK_Alt_L :: 0xffe9 /* Left alt */
XK_Alt_R :: 0xffea /* Right alt */
XK_Super_L :: 0xffeb /* Left super */
XK_Super_R :: 0xffec /* Right super */
XK_Hyper_L :: 0xffed /* Left hyper */
XK_Hyper_R :: 0xffee /* Right hyper */

XK_KP_Space :: 0xff80 /* Space */
XK_KP_Tab :: 0xff89
XK_KP_Enter :: 0xff8d /* Enter */
XK_KP_F1 :: 0xff91 /* PF1, KP_A, ... */
XK_KP_F2 :: 0xff92
XK_KP_F3 :: 0xff93
XK_KP_F4 :: 0xff94
XK_KP_Home :: 0xff95
XK_KP_Left :: 0xff96
XK_KP_Up :: 0xff97
XK_KP_Right :: 0xff98
XK_KP_Down :: 0xff99
XK_KP_Prior :: 0xff9a
XK_KP_Page_Up :: 0xff9a
XK_KP_Next :: 0xff9b
XK_KP_Page_Down :: 0xff9b
XK_KP_End :: 0xff9c
XK_KP_Begin :: 0xff9d
XK_KP_Insert :: 0xff9e
XK_KP_Delete :: 0xff9f
XK_KP_Equal :: 0xffbd /* Equals */
XK_KP_Multiply :: 0xffaa
XK_KP_Add :: 0xffab
XK_KP_Separator :: 0xffac /* Separator, often comma */
XK_KP_Subtract :: 0xffad
XK_KP_Decimal :: 0xffae
XK_KP_Divide :: 0xffaf

NoEventMask :: 0
KeyPressMask :: 1 << 0
KeyReleaseMask :: 1 << 1
ButtonPressMask :: 1 << 2
ButtonReleaseMask :: 1 << 3
EnterWindowMask :: 1 << 4
LeaveWindowMask :: 1 << 5
PointerMotionMask :: 1 << 6
PointerMotionHintMask :: 1 << 7
Button1MotionMask :: 1 << 8
Button2MotionMask :: 1 << 9
Button3MotionMask :: 1 << 10
Button4MotionMask :: 1 << 11
Button5MotionMask :: 1 << 12
ButtonMotionMask :: 1 << 13
KeymapStateMask :: 1 << 14
ExposureMask :: 1 << 15
VisibilityChangeMask :: 1 << 16
StructureNotifyMask :: 1 << 17
ResizeRedirectMask :: 1 << 18
SubstructureNotifyMask :: 1 << 19
SubstructureRedirectMask :: 1 << 20
FocusChangeMask :: 1 << 21
PropertyChangeMask :: 1 << 22
ColormapChangeMask :: 1 << 23
OwnerGrabButtonMask :: 1 << 24

KeyPress :: 2
KeyRelease :: 3
ButtonPress :: 4
ButtonRelease :: 5
MotionNotify :: 6
EnterNotify :: 7
LeaveNotify :: 8
FocusIn :: 9
FocusOut :: 10
KeymapNotify :: 11
Expose :: 12
GraphicsExpose :: 13
NoExpose :: 14
VisibilityNotify :: 15
CreateNotify :: 16
DestroyNotify :: 17
UnmapNotify :: 18
MapNotify :: 19
MapRequest :: 20
ReparentNotify :: 21
ConfigureNotify :: 22
ConfigureRequest :: 23
GravityNotify :: 24
ResizeRequest :: 25
CirculateNotify :: 26
CirculateRequest :: 27
PropertyNotify :: 28
SelectionClear :: 29
SelectionRequest :: 30
SelectionNotify :: 31
ColormapNotify :: 32
ClientMessage :: 33
MappingNotify :: 34
GenericEvent :: 35
LASTEvent :: 36

Display :: struct {
	ext_data:            rawptr, /* hook for extension to hang data */
	private1:            rawptr,
	fd:                  c.int, /* Network socket. */
	private2:            c.int,
	proto_major_version: c.int, /* major version of server's X protocol */
	proto_minor_version: c.int, /* minor version of servers X protocol */
	vendor:              cstring, /* vendor of the server hardware */
	private3:            XID,
	private4:            XID,
	private5:            XID,
	private6:            c.int,
	resource_alloc:      proc(display: ^Display) -> XID, /* allocator function */
	byte_order:          c.int, /* screen byte order, LSBFirst, MSBFirst */
	bitmap_unit:         c.int, /* padding and data requirements */
	bitmap_pad:          c.int, /* padding requirements on bitmaps */
	bitmap_bit_order:    c.int, /* LeastSignificant or MostSignificant */
	nformats:            c.int, /* number of pixmap formats in list */
	pixmap_format:       rawptr, /* pixmap format list */
	private8:            c.int,
	release:             c.int, /* release of the server */
	private9, private10: rawptr,
	qlen:                c.int, /* Length of input event queue */
	last_request_read:   c.ulong, /* seq number of last event read */
	request:             c.ulong, /* sequence number of last request. */
	private11:           rawptr,
	private12:           rawptr,
	private13:           rawptr,
	private14:           rawptr,
	max_request_size:    c.uint, /* maximum number 32 bit words in request*/
	db:                  XrmHashBucketRecHandle,
	private15:           proc(display: ^Display) -> int,
	display_name:        cstring, /* "host:display" string used on this connect*/
	default_screen:      c.int, /* default screen for operations */
	nscreens:            c.int, /* number of screens on this server*/
	screens:             [^]Screen, /* pointer to list of screens */
	motion_buffer:       c.ulong, /* size of motion buffer */
	private16:           c.ulong,
	min_keycode:         c.int, /* minimum defined keycode */
	max_keycode:         c.int, /* maximum defined keycode */
	private17:           rawptr,
	private18:           rawptr,
	private19:           c.int,
	xdefaults:           cstring, /* contents of defaults from server */
	/* there is more to this structure, but it is private to Xlib */
}

Screen :: struct {
	ext_data:           rawptr, /* hook for extension to hang data */
	display:            ^Display, /* back pointer to display structure */
	root:               Window, /* Root window id. */
	width, height:      c.int, /* width and height of screen */
	mwidth, mheight:    c.int, /* width and height of  in millimeters */
	ndepths:            c.int, /* number of depths possible */
	depths:             rawptr, /* list of allowable depths on the screen */
	root_depth:         c.int, /* bits per pixel */
	root_visual:        VisualHandle, /* root visual */
	default_gc:         GC, /* GC for the root root visual */
	cmap:               Colormap, /* default color map */
	white_pixel:        c.ulong,
	black_pixel:        c.ulong, /* White and Black pixel values */
	max_maps, min_maps: c.int, /* max and min color maps */
	backing_store:      c.int, /* Never, WhenMapped, Always */
	save_unders:        Bool,
	root_input_mask:    c.long, /* initial root input mask */
}

XSetWindowAttributes :: struct {
	background_pixmap:     Pixmap, /* background or None or ParentRelative */
	background_pixel:      c.ulong, /* background pixel */
	border_pixmap:         Pixmap, /* border of the window */
	border_pixel:          c.ulong, /* border pixel value */
	bit_gravity:           c.int, /* one of bit gravity values */
	win_gravity:           c.int, /* one of the window gravity values */
	backing_store:         c.int, /* NotUseful, WhenMapped, Always */
	backing_planes:        c.ulong, /* planes to be preserved if possible */
	backing_pixel:         c.ulong, /* value to use in restoring planes */
	save_under:            Bool, /* should bits under be saved? (popups) */
	event_mask:            c.long, /* set of events that should be saved */
	do_not_propagate_mask: c.long, /* set of events that should not propagate */
	override_redirect:     Bool, /* boolean value for override-redirect */
	colormap:              Colormap, /* color map to be associated with window */
	cursor:                Cursor, /* cursor to be displayed (or None) */
}

XImage :: struct {
	width, height:    c.int, /* size of image */
	xoffset:          c.int, /* number of pixels offset in X direction */
	format:           c.int, /* XYBitmap, XYPixmap, ZPixmap */
	data:             rawptr, /* pointer to image data */
	byte_order:       c.int, /* data byte order, LSBFirst, MSBFirst */
	bitmap_unit:      c.int, /* quant. of scanline 8, 16, 32 */
	bitmap_bit_order: c.int, /* LSBFirst, MSBFirst */
	bitmap_pad:       c.int, /* 8, 16, 32 either XY or ZPixmap */
	depth:            c.int, /* depth of image */
	bytes_per_line:   c.int, /* accelarator to next line */
	bits_per_pixel:   c.int, /* bits per pixel (ZPixmap) */
	red_mask:         c.ulong, /* bits in z arrangement */
	green_mask:       c.ulong,
	blue_mask:        c.ulong,
	obdata:           XPointer, /* hook for the object routines to hang on */
	f:                struct {
		/* image manipulation routines */
		create_image:  proc(
			display: ^Display,
			visual: VisualHandle,
			depth: c.uint,
			format: c.int,
			offset: c.int,
			data: ^u8,
			width: c.uint,
			height: c.uint,
			bitmap_pad: c.int,
			bytes_per_line: c.int,
		) -> ^XImage,
		destroy_image: proc(image: ^XImage) -> c.int,
		get_pixel:     proc(image: ^XImage, row: c.int, col: c.int) -> c.ulong,
		put_pixel:     proc(image: ^XImage, row: c.int, col: c.int, val: c.ulong) -> c.ulong,
		sub_image:     proc(
			image: ^XImage,
			row: c.int,
			col: c.int,
			width: c.uint,
			height: c.uint,
		) -> ^XImage,
		add_pixel:     proc(image: ^XImage, _: c.long) -> c.int,
	},
}

XEvent :: struct #raw_union {
	type:              c.int, /* must not be changed; first element */
	xany:              XAnyEvent,
	xkey:              XKeyEvent,
	xbutton:           XButtonEvent,
	xmotion:           XMotionEvent,
	xcrossing:         XCrossingEvent,
	xfocus:            XFocusChangeEvent,
	xexpose:           XExposeEvent,
	xgraphicsexpose:   XGraphicsExposeEvent,
	xnoexpose:         XNoExposeEvent,
	xvisibility:       XVisibilityEvent,
	xcreatewindow:     XCreateWindowEvent,
	xdestroywindow:    XDestroyWindowEvent,
	xunmap:            XUnmapEvent,
	xmap:              XMapEvent,
	xmaprequest:       XMapRequestEvent,
	xreparent:         XReparentEvent,
	xconfigure:        XConfigureEvent,
	xgravity:          XGravityEvent,
	xresizerequest:    XResizeRequestEvent,
	xconfigurerequest: XConfigureRequestEvent,
	xcirculate:        XCirculateEvent,
	xcirculaterequest: XCirculateRequestEvent,
	xproperty:         XPropertyEvent,
	xselectionclear:   XSelectionClearEvent,
	xselectionrequest: XSelectionRequestEvent,
	xselection:        XSelectionEvent,
	xcolormap:         XColormapEvent,
	xclient:           XClientMessageEvent,
	xmapping:          XMappingEvent,
	xerror:            XErrorEvent,
	xkeymap:           XKeymapEvent,
	xgeneric:          XGenericEvent,
	xcookie:           XGenericEventCookie,
	pad:               [24]c.long,
}

XAnyEvent :: struct {
	type:       c.int,
	serial:     c.ulong, /* # of last request processed by server */
	send_event: Bool, /* true if this came from a SendEvent request */
	display:    Display, /* Display the event was read from */
	window:     Window, /* window on which event was requested in event mask */
}

XKeyEvent :: struct {
	type:           c.int,
	serial:         c.ulong, /* # of last request processed by server */
	send_event:     Bool, /* true if this came from a SendEvent request */
	display:        ^Display, /* Display the event was read from */
	window:         Window, /* "event" window it is reported relative to */
	root:           Window, /* root window that the event occurred on */
	subwindow:      Window, /* child window */
	time:           Time, /* milliseconds */
	x, y:           c.int, /* pointer x, y coordinates in event window */
	x_root, y_root: c.int, /* coordinates relative to root */
	state:          c.uint, /* key or button mask */
	keycode:        c.uint, /* detail */
	same_screen:    Bool, /* same screen flag */
}
XKeyPressedEvent :: XKeyEvent
XKeyReleasedEvent :: XKeyEvent

XButtonEvent :: struct {
	type:           c.int,
	serial:         c.ulong, /* # of last request processed by server */
	send_event:     Bool, /* true if this came from a SendEvent request */
	display:        ^Display, /* Display the event was read from */
	window:         Window, /* "event" window it is reported relative to */
	root:           Window, /* root window that the event occurred on */
	subwindow:      Window, /* child window */
	time:           Time, /* milliseconds */
	x, y:           c.int, /* pointer x, y coordinates in event window */
	x_root, y_root: c.int, /* coordinates relative to root */
	state:          c.uint, /* key or button mask */
	button:         c.uint, /* detail */
	same_screen:    Bool, /* same screen flag */
}

XMotionEvent :: struct {
	type:           c.int,
	serial:         c.ulong, /* # of last request processed by server */
	send_event:     Bool, /* true if this came from a SendEvent request */
	display:        ^Display, /* Display the event was read from */
	window:         Window, /* "event" window reported relative to */
	root:           Window, /* root window that the event occurred on */
	subwindow:      Window, /* child window */
	time:           Time, /* milliseconds */
	x, y:           c.int, /* pointer x, y coordinates in event window */
	x_root, y_root: c.int, /* coordinates relative to root */
	state:          c.uint, /* key or button mask */
	is_hint:        i8, /* detail */
	same_screen:    Bool, /* same screen flag */
}

XCrossingEvent :: struct {
	type:           c.int,
	serial:         c.ulong, /* # of last request processed by server */
	send_event:     Bool, /* true if this came from a SendEvent request */
	display:        ^Display, /* Display the event was read from */
	window:         Window, /* "event" window reported relative to */
	root:           Window, /* root window that the event occurred on */
	subwindow:      Window, /* child window */
	time:           Time, /* milliseconds */
	x, y:           c.int, /* pointer x, y coordinates in event window */
	x_root, y_root: c.int, /* coordinates relative to root */
	mode:           c.int, /* NotifyNormal, NotifyGrab, NotifyUngrab */
	detail:         c.int,
	/*
	 * NotifyAncestor, NotifyVirtual, NotifyInferior,
	 * NotifyNonlinear,NotifyNonlinearVirtual
	 */
	same_screen:    Bool, /* same screen flag */
	focus:          Bool, /* boolean focus */
	state:          c.uint, /* key or button mask */
}

XFocusChangeEvent :: struct {
	type:       c.int,
	serial:     c.ulong, /* # of last request processed by server */
	send_event: Bool, /* true if this came from a SendEvent request */
	display:    ^Display, /* Display the event was read from */
	window:     Window, /* window of event */
	mode:       c.int, /* NotifyNormal, NotifyWhileGrabbed, NotifyGrab, NotifyUngrab */
	detail:     c.int,
	/*
	 * NotifyAncestor, NotifyVirtual, NotifyInferior,
	 * NotifyNonlinear,NotifyNonlinearVirtual, NotifyPointer,
	 * NotifyPointerRoot, NotifyDetailNone
	 */
}

XExposeEvent :: struct {
	type:          c.int,
	serial:        c.ulong, /* # of last request processed by server */
	send_event:    Bool, /* true if this came from a SendEvent request */
	display:       ^Display, /* Display the event was read from */
	window:        Window,
	x, y:          c.int,
	width, height: c.int,
	count:         c.int, /* if non-zero, at least this many more */
}

XGraphicsExposeEvent :: struct {
	type:          c.int,
	serial:        c.ulong, /* # of last request processed by server */
	send_event:    Bool, /* true if this came from a SendEvent request */
	display:       ^Display, /* Display the event was read from */
	drawable:      Drawable,
	x, y:          c.int,
	width, height: c.int,
	count:         c.int, /* if non-zero, at least this many more */
	major_code:    c.int, /* core is CopyArea or CopyPlane */
	minor_code:    c.int, /* not defined in the core */
}

XNoExposeEvent :: struct {
	type:       c.int,
	serial:     c.ulong, /* # of last request processed by server */
	send_event: Bool, /* true if this came from a SendEvent request */
	display:    ^Display, /* Display the event was read from */
	drawable:   Drawable,
	major_code: c.int, /* core is CopyArea or CopyPlane */
	minor_code: c.int, /* not defined in the core */
}

XVisibilityEvent :: struct {
	type:       c.int,
	serial:     c.ulong, /* # of last request processed by server */
	send_event: Bool, /* true if this came from a SendEvent request */
	display:    ^Display, /* Display the event was read from */
	window:     Window,
	state:      c.int, /* Visibility state */
}

XCreateWindowEvent :: struct {
	type:              c.int,
	serial:            c.ulong, /* # of last request processed by server */
	send_event:        Bool, /* true if this came from a SendEvent request */
	display:           ^Display, /* Display the event was read from */
	parent:            Window, /* parent of the window */
	window:            Window, /* window id of window created */
	x, y:              c.int, /* window location */
	width, height:     c.int, /* size of window */
	border_width:      c.int, /* border width */
	override_redirect: Bool, /* creation should be overridden */
}

XDestroyWindowEvent :: struct {
	type:       c.int,
	serial:     c.ulong, /* # of last request processed by server */
	send_event: Bool, /* true if this came from a SendEvent request */
	display:    ^Display, /* Display the event was read from */
	event:      Window,
	window:     Window,
}

XUnmapEvent :: struct {
	type:           c.int,
	serial:         c.ulong, /* # of last request processed by server */
	send_event:     Bool, /* true if this came from a SendEvent request */
	display:        ^Display, /* Display the event was read from */
	event:          Window,
	window:         Window,
	from_configure: Bool,
}

XMapEvent :: struct {
	type:              c.int,
	serial:            c.ulong, /* # of last request processed by server */
	send_event:        Bool, /* true if this came from a SendEvent request */
	display:           ^Display, /* Display the event was read from */
	event:             Window,
	window:            Window,
	override_redirect: Bool, /* boolean, is override set... */
}

XMapRequestEvent :: struct {
	type:       c.int,
	serial:     c.ulong, /* # of last request processed by server */
	send_event: Bool, /* true if this came from a SendEvent request */
	display:    ^Display, /* Display the event was read from */
	parent:     Window,
	window:     Window,
}

XReparentEvent :: struct {
	type:              c.int,
	serial:            c.ulong, /* # of last request processed by server */
	send_event:        Bool, /* true if this came from a SendEvent request */
	display:           ^Display, /* Display the event was read from */
	event:             Window,
	window:            Window,
	parent:            Window,
	x, y:              c.int,
	override_redirect: Bool,
}

XConfigureEvent :: struct {
	type:              c.int,
	serial:            c.ulong, /* # of last request processed by server */
	send_event:        Bool, /* true if this came from a SendEvent request */
	display:           ^Display, /* Display the event was read from */
	event:             Window,
	window:            Window,
	x, y:              c.int,
	width, height:     c.int,
	border_width:      c.int,
	above:             Window,
	override_redirect: Bool,
}

XGravityEvent :: struct {
	type:       c.int,
	serial:     c.ulong, /* # of last request processed by server */
	send_event: Bool, /* true if this came from a SendEvent request */
	display:    ^Display, /* Display the event was read from */
	event:      Window,
	window:     Window,
	x, y:       c.int,
}

XResizeRequestEvent :: struct {
	type:          c.int,
	serial:        c.ulong, /* # of last request processed by server */
	send_event:    Bool, /* true if this came from a SendEvent request */
	display:       ^Display, /* Display the event was read from */
	window:        Window,
	width, height: c.int,
}

XConfigureRequestEvent :: struct {
	type:          c.int,
	serial:        c.ulong, /* # of last request processed by server */
	send_event:    Bool, /* true if this came from a SendEvent request */
	display:       ^Display, /* Display the event was read from */
	parent:        Window,
	window:        Window,
	x, y:          c.int,
	width, height: c.int,
	border_width:  c.int,
	above:         Window,
	detail:        c.int, /* Above, Below, TopIf, BottomIf, Opposite */
	value_mask:    c.ulong,
}

XCirculateEvent :: struct {
	type:       c.int,
	serial:     c.ulong, /* # of last request processed by server */
	send_event: Bool, /* true if this came from a SendEvent request */
	display:    ^Display, /* Display the event was read from */
	event:      Window,
	window:     Window,
	place:      c.int, /* PlaceOnTop, PlaceOnBottom */
}

XCirculateRequestEvent :: struct {
	type:       c.int,
	serial:     c.ulong, /* # of last request processed by server */
	send_event: Bool, /* true if this came from a SendEvent request */
	display:    ^Display, /* Display the event was read from */
	parent:     Window,
	window:     Window,
	place:      c.int, /* PlaceOnTop, PlaceOnBottom */
}

XPropertyEvent :: struct {
	type:       c.int,
	serial:     c.ulong, /* # of last request processed by server */
	send_event: Bool, /* true if this came from a SendEvent request */
	display:    ^Display, /* Display the event was read from */
	window:     Window,
	atom:       Atom,
	time:       Time,
	state:      c.int, /* NewValue, Deleted */
}

XSelectionClearEvent :: struct {
	type:       c.int,
	serial:     c.ulong, /* # of last request processed by server */
	send_event: Bool, /* true if this came from a SendEvent request */
	display:    ^Display, /* Display the event was read from */
	window:     Window,
	selection:  Atom,
	time:       Time,
}

XSelectionRequestEvent :: struct {
	type:       c.int,
	serial:     c.ulong, /* # of last request processed by server */
	send_event: Bool, /* true if this came from a SendEvent request */
	display:    ^Display, /* Display the event was read from */
	owner:      Window,
	requestor:  Window,
	selection:  Atom,
	target:     Atom,
	property:   Atom,
	time:       Time,
}

XSelectionEvent :: struct {
	type:       c.int,
	serial:     c.ulong, /* # of last request processed by server */
	send_event: Bool, /* true if this came from a SendEvent request */
	display:    ^Display, /* Display the event was read from */
	requestor:  Window,
	selection:  Atom,
	target:     Atom,
	property:   Atom, /* ATOM or None */
	time:       Time,
}

XColormapEvent :: struct {
	type:       c.int,
	serial:     c.ulong, /* # of last request processed by server */
	send_event: Bool, /* true if this came from a SendEvent request */
	display:    ^Display, /* Display the event was read from */
	window:     Window,
	colormap:   Colormap, /* COLORMAP or None */
	new:        Bool,
	state:      c.int, /* ColormapInstalled, ColormapUninstalled */
}

XClientMessageEvent :: struct {
	type:         c.int,
	serial:       c.ulong, /* # of last request processed by server */
	send_event:   Bool, /* true if this came from a SendEvent request */
	display:      ^Display, /* Display the event was read from */
	window:       Window,
	message_type: Atom,
	format:       c.int,
	data:         struct #raw_union {
		b: [20]i8,
		s: [10]c.short,
		l: [5]c.long,
	},
}

XMappingEvent :: struct {
	type:          c.int,
	serial:        c.ulong, /* # of last request processed by server */
	send_event:    Bool, /* true if this came from a SendEvent request */
	display:       ^Display, /* Display the event was read from */
	window:        Window, /* unused */
	request:       c.int, /* one of MappingModifier, MappingKeyboard, MappingPointer */
	first_keycode: c.int, /* first keycode */
	count:         c.int, /* defines range of change w. first_keycode*/
}

XErrorEvent :: struct {
	type:         c.int,
	display:      ^Display, /* Display the event was read from */
	resourceid:   XID, /* resource id */
	serial:       c.ulong, /* serial number of failed request */
	error_code:   u8, /* error code of failed request */
	request_code: u8, /* Major op-code of failed request */
	minor_code:   u8, /* Minor op-code of failed request */
}

XKeymapEvent :: struct {
	type:       c.int,
	serial:     c.ulong, /* # of last request processed by server */
	send_event: Bool, /* true if this came from a SendEvent request */
	display:    ^Display, /* Display the event was read from */
	window:     Window,
	key_vector: [32]i8,
}

XGenericEvent :: struct {
	type:       c.int,
	serial:     c.ulong, /* # of last request processed */
	send_event: Bool, /* true if from SendEvent request */
	display:    ^Display, /* Display the event was read from */
	extension:  c.int, /* major opcode of extension that caused the event */
	evtype:     c.int, /* actual event type. */
}

XGenericEventCookie :: struct {
	type:       c.int,
	serial:     c.ulong, /* # of last request processed */
	send_event: Bool, /* true if from SendEvent request */
	display:    ^Display, /* Display the event was read from */
	extension:  c.int, /* major opcode of extension that caused the event */
	evtype:     c.int, /* actual event type. */
	cookie:     c.uint,
	data:       rawptr,
}
