package freetype

import "core:c"

when ODIN_OS == .Windows {
	foreign import freetype "../../build/freetype.lib"
} else {
	foreign import freetype "system:freetype"
}

@(link_prefix = "FT_", default_calling_convention = "c")
foreign freetype {
	Init_FreeType :: proc(library: ^Library) -> Error ---
	Done_FreeType :: proc(library: Library) -> Error ---

	New_Face :: proc(
		library: Library,
		filepathname: cstring,
		face_index: Long,
		aface: ^Face,
	) -> Error ---
	New_Memory_Face :: proc(
		library: Library,
		file_base: ^byte,
		file_size: Long,
		face_index: Long,
		aface: ^Face,
	) -> Error ---
	Done_Face :: proc(face: Face) -> Error ---

	Set_Char_Size :: proc(
		face: Face,
		char_width,
		char_height: F26Dot6,
		horz_resolution,
		vert_resolution: u32,
	) -> Error ---
	Set_Pixel_Sizes :: proc(face: Face, pixel_width, pixel_height: u32) -> Error ---

	Get_First_Char :: proc(face: Face, index: ^u32) -> c.ulong ---
	Get_Next_Char :: proc(face: Face, character: c.ulong, index: ^u32) -> c.ulong ---
	Get_Char_Index :: proc(face: Face, charcode: ULong) -> u32 ---

	Get_Kerning :: proc(
		face: Face,
		left_glyph,
		right_glyph: u32,
		kern_mode: u32,
		akerning: ^Vector,
	) -> Error ---

	Load_Char :: proc(face: Face, char_code: u32, load_flags: i32) -> Error ---
	Load_Glyph :: proc(face: Face, glyph_index: u32, load_flags: i32) -> Error ---
	Render_Glyph :: proc(glyph: GlyphSlot, render_mode: Render_Mode) -> Error ---

	Select_Charmap :: proc(face: Face, encoding: Encoding) -> Error ---

	Set_Transform :: proc(face: Face, mat: ^Matrix, delta: ^Vector) ---

	Load_Sfnt_Table :: proc(
		face: Face,
		tag: ULong,
		offset: Long,
		buffer: ^byte,
		length: ^ULong,
	) -> Error ---

	MulFix :: proc(a, b: Long) -> Long ---
}

HAS_KERNING :: proc(face: Face) -> bool {
	return FaceFlag.KERNING in face.face_flags
}

Long :: c.long
ULong :: c.ulong

LOAD_DEFAULT :: 0
LOAD_NO_SCALE :: 1 << 0
LOAD_NO_HINTING :: 1 << 1
LOAD_RENDER :: 1 << 2
LOAD_NO_BITMAP :: 1 << 3
LOAD_VERTICAL_LAYOUT :: 1 << 4
LOAD_FORCE_AUTOHINT :: 1 << 5
LOAD_CROP_BITMAP :: 1 << 6
LOAD_PEDANTIC :: 1 << 7
LOAD_IGNORE_GLOBAL_ADVANCE_WIDTH :: 1 << 9
LOAD_NO_RECURSE :: 1 << 10
LOAD_IGNORE_TRANSFORM :: 1 << 11
LOAD_MONOCHROME :: 1 << 12
LOAD_LINEAR_DESIGN :: 1 << 13
LOAD_NO_AUTOHINT :: 1 << 15
// Bits 16-19 are used by `FT_LOAD_TARGET_'
LOAD_COLOR :: 1 << 20
LOAD_COMPUTE_METRICS :: 1 << 21
LOAD_BITMAP_METRICS_ONLY :: 1 << 22


// used internally only by certain font drivers
LOAD_ADVANCE_ONLY :: 1 << 8
LOAD_SBITS_ONLY :: 1 << 14


KERNING_DEFAULT :: 0
KERNING_UNFITTED :: 1
KERNING_UNSCALED :: 2

TTAG_GSUB :: 0x47535542

Error :: distinct c.int

Err_Ok :: 0x00

Err_Cannot_Open_Resource :: 0x01
Err_Unknown_File_Format :: 0x02
Err_Invalid_File_Format :: 0x03
Err_Invalid_Version :: 0x04
Err_Lower_Module_Version :: 0x05
Err_Invalid_Argument :: 0x06
Err_Unimplemented_Feature :: 0x07
Err_Invalid_Table :: 0x08
Err_Invalid_Offset :: 0x09
Err_Array_Too_Large :: 0x0A
Err_Missing_Module :: 0x0B
Err_Missing_Property :: 0x0C

/* glyph/character errors */

Err_Invalid_Glyph_Index :: 0x10
Err_Invalid_Character_Code :: 0x11
Err_Invalid_Glyph_Format :: 0x12
Err_Cannot_Render_Glyph :: 0x13
Err_Invalid_Outline :: 0x14
Err_Invalid_Composite :: 0x15
Err_Too_Many_Hints :: 0x16
Err_Invalid_Pixel_Size :: 0x17

/* handle errors */

Err_Invalid_Handle :: 0x20
Err_Invalid_Library_Handle :: 0x21
Err_Invalid_Driver_Handle :: 0x22
Err_Invalid_Face_Handle :: 0x23
Err_Invalid_Size_Handle :: 0x24
Err_Invalid_Slot_Handle :: 0x25
Err_Invalid_CharMap_Handle :: 0x26
Err_Invalid_Cache_Handle :: 0x27
Err_Invalid_Stream_Handle :: 0x28

/* driver errors */

Err_Too_Many_Drivers :: 0x30
Err_Too_Many_Extensions :: 0x31

/* memory errors */

Err_Out_Of_Memory :: 0x40
Err_Unlisted_Object :: 0x41

/* stream errors */

Err_Cannot_Open_Stream :: 0x51
Err_Invalid_Stream_Seek :: 0x52
Err_Invalid_Stream_Skip :: 0x53
Err_Invalid_Stream_Read :: 0x54
Err_Invalid_Stream_Operation :: 0x55
Err_Invalid_Frame_Operation :: 0x56
Err_Nested_Frame_Access :: 0x57
Err_Invalid_Frame_Read :: 0x58

/* raster errors */

Err_Raster_Uninitialized :: 0x60
Err_Raster_Corrupted :: 0x61
Err_Raster_Overflow :: 0x62
Err_Raster_Negative_Height :: 0x63

/* cache errors */

Err_Too_Many_Caches :: 0x70

/* TrueType and SFNT errors */

Err_Invalid_Opcode :: 0x80
Err_Too_Few_Arguments :: 0x81
Err_Stack_Overflow :: 0x82
Err_Code_Overflow :: 0x83
Err_Bad_Argument :: 0x84
Err_Divide_By_Zero :: 0x85
Err_Invalid_Reference :: 0x86
Err_Debug_OpCode :: 0x87
Err_ENDF_In_Exec_Stream :: 0x88
Err_Nested_DEFS :: 0x89
Err_Invalid_CodeRange :: 0x8A
Err_Execution_Too_Long :: 0x8B
Err_Too_Many_Function_Defs :: 0x8C
Err_Too_Many_Instruction_Defs :: 0x8D
Err_Table_Missing :: 0x8E
Err_Horiz_Header_Missing :: 0x8F
Err_Locations_Missing :: 0x90
Err_Name_Table_Missing :: 0x91
Err_CMap_Table_Missing :: 0x92
Err_Hmtx_Table_Missing :: 0x93
Err_Post_Table_Missing :: 0x94
Err_Invalid_Horiz_Metrics :: 0x95
Err_Invalid_CharMap_Format :: 0x96
Err_Invalid_PPem :: 0x97
Err_Invalid_Vert_Metrics :: 0x98
Err_Could_Not_Find_Context :: 0x99
Err_Invalid_Post_Table_Format :: 0x9A
Err_Invalid_Post_Table :: 0x9B
Err_DEF_In_Glyf_Bytecode :: 0x9C
Err_Missing_Bitmap :: 0x9D

/* CFF, CID, and Type 1 errors */

Err_Syntax_Error :: 0xA0
Err_Stack_Underflow :: 0xA1
Err_Ignore :: 0xA2
Err_No_Unicode_Glyph_Name :: 0xA3
Err_Glyph_Too_Big :: 0xA4

/* BDF errors */

Err_Missing_Startfont_Field :: 0xB0
Err_Missing_Font_Field :: 0xB1
Err_Missing_Size_Field :: 0xB2
Err_Missing_Fontboundingbox_Field :: 0xB3
Err_Missing_Chars_Field :: 0xB4
Err_Missing_Startchar_Field :: 0xB5
Err_Missing_Encoding_Field :: 0xB6
Err_Missing_Bbx_Field :: 0xB7
Err_Bbx_Too_Big :: 0xB8
Err_Corrupted_Font_Header :: 0xB9
Err_Corrupted_Font_Glyphs :: 0xBA

Glyph_Format :: enum c.ulong {
	NONE      = 0,
	COMPOSITE = ('c' << 24) | ('o' << 16) | ('m' << 8) | ('p' << 0),
	BITMAP    = ('b' << 24) | ('i' << 16) | ('t' << 8) | ('s' << 0),
	OUTLINE   = ('o' << 24) | ('u' << 16) | ('t' << 8) | ('l' << 0),
	PLOTTER   = ('p' << 24) | ('l' << 16) | ('o' << 8) | ('t' << 0),
}

F26Dot6 :: Long

Handle :: distinct rawptr

Library :: distinct Handle
CharMap :: ^CharMapRec
Face :: ^FaceRec
GlyphSlot :: ^GlyphSlotRec
Face_Internal :: distinct Handle
Driver :: distinct Handle
Memory :: distinct Handle
Stream :: distinct Handle
SubGlyph :: distinct Handle
Slot_Internal :: distinct Handle

Generic_Finalizer :: proc "c" (object: rawptr)
Generic :: struct {
	data:      rawptr,
	finalizer: Generic_Finalizer,
}

Pos :: distinct Long
Fixed :: distinct Long
UShort :: distinct c.ushort

pos6_to_f32 :: proc(p: Pos) -> f32 {
	return f32(p >> 6) + f32(p & 0b111111) / 64
}
pos6_to_i16 :: proc(p: Pos) -> i16 {
	return i16(p >> 6)
}


Vector :: struct {
	x, y: Pos,
}
Matrix :: struct {
	xx, xy: Fixed,
	yx, yy: Fixed,
}

Encoding :: enum u32 {
	NONE           = 0,
	MS_SYMBOL      = 's' << 24 | 'y' << 16 | 'm' << 8 | 'b',
	UNICODE        = 'u' << 24 | 'n' << 16 | 'i' << 8 | 'c',
	SJIS           = 's' << 24 | 'j' << 16 | 'i' << 8 | 's',
	PRC            = 'g' << 24 | 'b' << 16 | ' ' << 8 | ' ',
	BIG5           = 'b' << 24 | 'i' << 16 | 'g' << 8 | '5',
	WANSUNG        = 'w' << 24 | 'a' << 16 | 'n' << 8 | 's',
	JOHAB          = 'j' << 24 | 'o' << 16 | 'h' << 8 | 'a',

	// for backward compatibility
	GB2312         = PRC,
	MS_SJIS        = SJIS,
	MS_GB2312      = PRC,
	MS_BIG5        = BIG5,
	MS_WANSUNG     = WANSUNG,
	MS_JOHAB       = JOHAB,
	ADOBE_STANDARD = 'A' << 24 | 'D' << 16 | 'O' << 8 | 'B',
	ADOBE_EXPERT   = 'A' << 24 | 'D' << 16 | 'B' << 8 | 'E',
	ADOBE_CUSTOM   = 'A' << 24 | 'D' << 16 | 'B' << 8 | 'C',
	ADOBE_LATIN_1  = 'l' << 24 | 'a' << 16 | 't' << 8 | '1',
	OLD_LATIN_2    = 'l' << 24 | 'a' << 16 | 't' << 8 | '2',
	APPLE_ROMAN    = 'a' << 24 | 'r' << 16 | 'm' << 8 | 'n',
}

CharMapRec :: struct {
	face:        Face,
	encoding:    Encoding,
	platform_id: u16,
	encoding_id: u16,
}

Glyph_Metrics :: struct {
	width:        Pos,
	height:       Pos,
	horiBearingX: Pos,
	horiBearingY: Pos,
	horiAdvance:  Pos,
	vertBearingX: Pos,
	vertBearingY: Pos,
	vertAdvance:  Pos,
}

GlyphSlotRec :: struct {
	library:           Library,
	face:              Face,
	next:              GlyphSlot,
	reserved:          u32, // retained for binary compatibility
	generic:           Generic,
	metrics:           Glyph_Metrics,
	linearHoriAdvance: Fixed,
	linearVertAdvance: Fixed,
	advance:           Vector,
	format:            Glyph_Format,
	bitmap:            Bitmap,
	bitmap_left:       c.int,
	bitmap_top:        c.int,
	outline:           Outline,
	num_subglyphs:     u32,
	subglyphs:         SubGlyph,
	control_data:      rawptr,
	control_len:       Long,
	lsb_delta:         Pos,
	rsb_delta:         Pos,
	other:             rawptr,
	internal:          Slot_Internal,
}

Outline :: struct {
	n_contours: i16, // number of contours in glyph
	n_points:   i16, // number of points in the glyph
	points:     ^Vector, // the outline's points
	tags:       cstring, // the points flags
	contours:   ^i16, // the contour end points
	flags:      i32, // outline masks
}

Bitmap :: struct {
	rows:         u32,
	width:        u32,
	pitch:        i32,
	buffer:       ^byte,
	num_grays:    u16,
	pixel_mode:   u8,
	palette_mode: u8,
	palette:      rawptr,
}

Bitmap_Size :: struct {
	height: i16,
	width:  i16,
	size:   Pos,
	x_ppem: Pos,
	y_ppem: Pos,
}

BBox :: struct {
	xMin, yMin: Pos,
	xMax, yMax: Pos,
}

ListNode :: distinct rawptr

ListRec :: struct {
	head: ListNode,
	tail: ListNode,
}


FaceFlag :: enum Long {
	SCALABLE         = 0,
	FIXED_SIZES      = 1,
	FIXED_WIDTH      = 2,
	SFNT             = 3,
	HORIZONTAL       = 4,
	VERTICAL         = 5,
	KERNING          = 6,
	FAST_GLYPHS      = 7,
	MULTIPLE_MASTERS = 8,
	GLYPH_NAMES      = 9,
	EXTERNAL_STREAM  = 10,
	HINTER           = 11,
	CID_KEYED        = 12,
	TRICKY           = 13,
	COLOR            = 14,
	VARIATION        = 15,
}

FaceRec :: struct {
	num_faces:           Long,
	face_index:          Long,
	face_flags:          bit_set[FaceFlag;Long],
	style_flags:         Long,
	num_glyphs:          Long,
	family_name:         cstring,
	style_name:          cstring,
	num_fixed_sizes:     c.int,
	available_sizes:     ^Bitmap_Size,
	num_charmaps:        c.int,
	charmaps:            ^CharMap,
	generic:             Generic,

	// The following member variables (down to `underline_thickness')
	// are only relevant to scalable outlines; cf. @FT_Bitmap_Size
	// for bitmap fonts.
	bbox:                BBox,
	units_per_EM:        u16,
	ascender:            i16,
	descender:           i16,
	height:              i16,
	max_advance_width:   i16,
	max_advance_height:  i16,
	underline_position:  i16,
	underline_thickness: i16,
	glyph:               GlyphSlot,
	size:                Size,
	charmap:             CharMap,
	driver:              Driver,
	memory:              Memory,
	stream:              Stream,
	sizes_list:          ListRec,
	autohint:            Generic, // face-specific auto-hinter data
	extensions:          rawptr, // unused
	internal:            Face_Internal,
}

Render_Mode :: enum c.int {
	NORMAL = 0,
	LIGHT,
	MONO,
	LCD,
	LCD_V,
	SDF,
	MAX,
}

SizeRec :: struct {
	face: Face,
	generic: Generic,
	metrics: Size_Metrics,
	internal: Size_Internal,
}

Size :: distinct ^SizeRec

Size_Metrics :: struct {
	x_ppem:      UShort,
	y_ppem:      UShort,
	x_scale:     Fixed,
	y_scale:     Fixed,
	ascender:    Pos,
	descender:   Pos,
	height:      Pos,
	max_advance: Pos,
}

Size_Internal :: distinct ^Size_InternalRec_

Size_InternalRec_ :: struct {}
