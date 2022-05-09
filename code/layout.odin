package wiredeck

Layout :: struct {
	root: Multipanel,
	panels: Freelist(Panel),
	panel_refs_free: Linkedlist(PanelRef),
	freelist_allocator: Allocator,
	pool_allocator: Allocator,
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
	FileContentViewer,
}

FileContentViewer :: struct {
	opened_file: ^OpenedFile,
}

init_layout :: proc(layout: ^Layout, freelist_allocator, pool_allocator: Allocator) {
	layout^ = {}
	layout.freelist_allocator = freelist_allocator
	layout.pool_allocator = pool_allocator
	linkedlist_init(&layout.root.panel_refs, new(LinkedlistEntry(PanelRef), freelist_allocator))
	freelist_init(&layout.panels, freelist_allocator)
	linkedlist_init(&layout.panel_refs_free, new(LinkedlistEntry(PanelRef), freelist_allocator))
}

layout_is_empty :: proc(layout: ^Layout) -> bool {
	result := linkedlist_is_empty(&layout.root.panel_refs)
	return result
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

attach_panel :: proc(layout: ^Layout, multipanel: ^Multipanel, panel: ^LinkedlistEntry(Panel)) -> ^LinkedlistEntry(PanelRef) {

	panel.entry.ref_count += 1

	panel_ref := linkedlist_remove_last_or_new(&layout.panel_refs_free, panel, layout.freelist_allocator)
	linkedlist_append(&multipanel.panel_refs, panel_ref)

	if multipanel.active == nil {
		multipanel.active = &panel.entry
	}

	return panel_ref
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

build_contents :: proc(window: ^Window, layout: ^Layout, ui: ^UI, opened_files: ^Freelist(OpenedFile)) {
	build_multipanel(window, layout, ui, opened_files, &layout.root)
}

build_edit_mode :: proc(window: ^Window, layout: ^Layout, ui: ^UI) {
	build_multipanel_edit(window, layout, ui, &layout.root)
}

build_multipanel :: proc(
	window: ^Window, layout: ^Layout, ui: ^UI, 
	opened_files: ^Freelist(OpenedFile), multipanel: ^Multipanel,
) {
	button_height := get_button_dim(ui, "T").y

	begin_container(ui, .Top, button_height)
	panel_refs := &multipanel.panel_refs
	for panel_entry := panel_refs.sentinel.next;
		!linkedlist_entry_is_sentinel(panel_refs, panel_entry); {

		panel := &panel_entry.entry.entry

		button_state := button(
			ui = ui,
			label_str = panel.name,
			dir = .Left,
			active = ptr_eq(multipanel.active, panel),
		)

		next_panel_entry := panel_entry.next
		skip_hang_once := true
		#partial switch button_state {
		case .Clicked:
			multipanel.active = panel
		case .ClickedMiddle:
			next_panel_entry = detach_panel(layout, multipanel, panel_entry)
		case:
			skip_hang_once = false
		}

		window.skip_hang_once ||= skip_hang_once
		panel_entry = next_panel_entry
	}
	end_container(ui)

	if multipanel.active != nil {
		switch panel_val in &multipanel.active.contents {
		case Multipanel: build_multipanel(window, layout, ui, opened_files, &panel_val)
		case FileContentViewer:
			if panel_val.opened_file != nil {
				text_area(ui, panel_val.opened_file)
			} else {
				if file_selected, some_file := file_selector(ui).(string); some_file {
					// TODO(khvorov) See if the file has already been opened
					contents_result := open_file(file_selected, ui.theme.text_colors, layout.pool_allocator)
					if contents, open_success := contents_result.(OpenedFile); open_success {
						contents_in_list := freelist_append(opened_files, contents)
						panel_val.opened_file = &contents_in_list.entry
						window.skip_hang_once = true
					}
				}
			}
		}
	}
}

build_multipanel_edit :: proc(window: ^Window, layout: ^Layout, ui: ^UI, multipanel: ^Multipanel) {

	for panel_ref := multipanel.panel_refs.sentinel.next;
		!linkedlist_entry_is_sentinel(&multipanel.panel_refs, panel_ref);
		panel_ref = panel_ref.next {

		add_multipanel_button_state := button(ui = ui, label_str = "Multipanel", dir = .Top)
		add_file_content_viewer_button_state := button(ui = ui, label_str = "FileContentViewer", dir = .Top)
	}

	add_multipanel_button_state := button(ui = ui, label_str = "Multipanel", dir = .Top)
	add_file_content_viewer_button_state := button(ui = ui, label_str = "FileContentViewer", dir = .Top)

	if add_file_content_viewer_button_state == .Clicked {
		file_content_viewer_panel := add_panel(layout, "FileContentViewer", FileContentViewer{})
		attach_panel(layout, multipanel, file_content_viewer_panel)
		window.skip_hang_once = true
	}
}
