package wiredeck

Layout :: struct {
	root: Multipanel,
	panels_free: Linkedlist(Panel),
	panel_ptrs_free: Linkedlist(^Panel),
	allocator: Allocator,
}

Multipanel :: struct {
	panels: Linkedlist(^Panel),
	active: ^Panel,
}

Panel :: struct {
	name_chars: [64]u8,
	name: string,
	contents: PanelContents,
}

PanelContents :: union {
	Multipanel,
	OpenedFileViewer,
	TextEditor,
	ThemeEditor,
}

OpenedFileViewer :: struct {}

TextEditor :: struct {}

ThemeEditor :: struct {}

init_layout :: proc(layout: ^Layout, allocator := context.allocator) {
	layout^ = {}
	layout.allocator = allocator
	linkedlist_init(&layout.root.panels, new(LinkedlistEntry(^Panel), allocator))
	linkedlist_init(&layout.panels_free, new(LinkedlistEntry(Panel), allocator))
	linkedlist_init(&layout.panel_ptrs_free, new(LinkedlistEntry(^Panel), allocator))
}

add_panel :: proc(layout: ^Layout, multipanel: ^Multipanel, name: string) -> ^Panel {
	panel := linkedlist_remove_last_or_new(&layout.panels_free, layout.allocator)

	name_len := min(len(name), len(panel.entry.name_chars))
	for index in 0..<name_len {
		panel.entry.name_chars[index] = name[index]
	}
	panel.entry.name = string(panel.entry.name_chars[:name_len])

	panel_ptr := linkedlist_remove_last_or_new(&layout.panel_ptrs_free, layout.allocator)
	panel_ptr.entry = &panel.entry
	linkedlist_append(&multipanel.panels, panel_ptr)

	if multipanel.active == nil {
		multipanel.active = panel_ptr.entry
	}

	return panel_ptr.entry
}
