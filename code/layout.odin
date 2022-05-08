package wiredeck

Layout :: struct {
	root: Multipanel,
	panels: Freelist(Panel),
	panel_refs_free: Linkedlist(PanelRef),
	allocator: Allocator,
}

Multipanel :: struct {
	panel_refs: Linkedlist(PanelRef),
	active: ^Panel,
}

Panel :: struct {
	name_chars: [64]u8,
	name: string,
	contents: PanelContents,
	ref_count: int,
}

PanelRef :: ^LinkedlistEntry(Panel)

PanelContents :: union {
	Multipanel,
	OpenedFileViewer,
	TextEditor,
	ThemeEditor,
}

OpenedFileViewer :: struct {}

TextEditor :: struct {
	opened_file: ^OpenedFile,
}

ThemeEditor :: struct {}

init_layout :: proc(layout: ^Layout, allocator := context.allocator) {
	layout^ = {}
	layout.allocator = allocator
	linkedlist_init(&layout.root.panel_refs, new(LinkedlistEntry(PanelRef), allocator))
	freelist_init(&layout.panels, allocator)
	linkedlist_init(&layout.panel_refs_free, new(LinkedlistEntry(PanelRef), allocator))
}

add_panel :: proc(layout: ^Layout, name: string, contents: PanelContents) -> ^LinkedlistEntry(Panel) {
	panel := freelist_append(&layout.panels, Panel{})

	name_len := min(len(name), len(panel.entry.name_chars))
	for index in 0..<name_len {
		panel.entry.name_chars[index] = name[index]
	}
	panel.entry.name = string(panel.entry.name_chars[:name_len])

	panel.entry.contents = contents
	panel.entry.ref_count = 0

	return panel
}

remove_panel :: proc(layout: ^Layout, panel_in_list: ^LinkedlistEntry(Panel)) {
	assert(panel_in_list.entry.ref_count == 0)
	freelist_remove(&layout.panels, panel_in_list)
}

attach_panel :: proc(layout: ^Layout, multipanel: ^Multipanel, panel: ^LinkedlistEntry(Panel)) -> ^Panel {

	panel.entry.ref_count += 1

	panel_ref := linkedlist_remove_last_or_new(&layout.panel_refs_free, panel, layout.allocator)
	linkedlist_append(&multipanel.panel_refs, panel_ref)

	if multipanel.active == nil {
		multipanel.active = &panel.entry
	}

	return &panel.entry
}

detach_panel :: proc(layout: ^Layout, multipanel: ^Multipanel, panel: ^LinkedlistEntry(PanelRef)) -> ^LinkedlistEntry(PanelRef) {
	next_ref := panel.next
	panel.entry.entry.ref_count -= 1

	if ptr_eq(multipanel.active, &panel.entry.entry) {
		multipanel.active = &next_ref.entry.entry
	}

	if panel.entry.entry.ref_count == 0 {
		remove_panel(layout, panel.entry)
	}
	linkedlist_remove_clear_append(panel, &layout.panel_refs_free)

	if linkedlist_is_empty(&multipanel.panel_refs) {
		multipanel.active = nil
	} else if ptr_eq(&multipanel.panel_refs.sentinel.entry.entry, multipanel.active) {
		multipanel.active = &multipanel.panel_refs.sentinel.prev.entry.entry
	}

	return next_ref
}
