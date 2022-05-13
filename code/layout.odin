package wiredeck

Layout :: struct {
	window: ^Window,
	layout: ^Layout,
	ui: ^UI,
	fs: ^Filesystem,
	root: Multipanel,
	panels: Freelist(Panel),
	panel_refs_free: Linkedlist(PanelRef),
	freelist_allocator: Allocator,
}

Multipanel :: struct {
	panel_refs: Linkedlist(PanelRef),
	panel_count: int,
	active: ^LinkedlistEntry(PanelRef),
	mode: MultipanelMode,
}

Panel :: struct {
	name_chars: [64]u8,
	name: string,
	contents: PanelContents,
	ref_count: int,
}

PanelRef :: struct {
	panel_in_list: ^LinkedlistEntry(Panel),
	split_dir: Direction,
	split_size: int,
}

PanelContents :: union {
	Multipanel,
	FileContentViewer,
}

FileContentViewer :: struct {
	//selected: ???,
	file_ref: FileRef,
}

MultipanelMode :: enum {
	Split,
	Tab,
}

init_layout :: proc(layout: ^Layout, window: ^Window, ui: ^UI, fs: ^Filesystem, freelist_allocator: Allocator) {
	layout^ = {window = window, layout = layout, ui = ui, fs = fs, freelist_allocator = freelist_allocator}
	freelist_init(&layout.panels, freelist_allocator)
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

	switch contents in panel_in_list.entry.contents {
	case Multipanel:
		unimplemented("detach all the children")
	case FileContentViewer:
		unimplemented("remove file ref and free file if nobody is referring to it")
	}

	freelist_remove(&layout.panels, panel_in_list)
}

attach_panel :: proc(layout: ^Layout, multipanel: ^Multipanel, panel: ^LinkedlistEntry(Panel)) -> ^LinkedlistEntry(PanelRef) {

	multipanel.panel_count += 1
	panel.entry.ref_count += 1

	panel_ref := linkedlist_remove_last_or_new(
		&layout.panel_refs_free,
		PanelRef{panel, .Left, 500},
		layout.freelist_allocator,
	)
	linkedlist_append(&multipanel.panel_refs, panel_ref)

	if multipanel.active == nil {
		multipanel.active = panel_ref
	}

	return panel_ref
}

detach_panel :: proc(layout: ^Layout, multipanel: ^Multipanel, panel: ^LinkedlistEntry(PanelRef)) -> ^LinkedlistEntry(PanelRef) {

	assert(multipanel.panel_count > 0)
	multipanel.panel_count -= 1
	next_ref := panel.next
	assert(panel.entry.panel_in_list.entry.ref_count > 0)
	panel.entry.panel_in_list.entry.ref_count -= 1

	if ptr_eq(multipanel.active, panel) {
		if ptr_eq(panel.next, panel) {
			multipanel.active = nil
		} else if ptr_eq(panel.next, multipanel.panel_refs.first) {
			multipanel.active = panel.prev
		} else {
			multipanel.active = panel.next
		}
	}

	if panel.entry.panel_in_list.entry.ref_count == 0 {
		remove_panel(layout, panel.entry.panel_in_list)
	}
	linkedlist_remove_clear_append(&multipanel.panel_refs, panel, &layout.panel_refs_free)

	return next_ref
}

build_contents :: proc(layout: ^Layout) {
	build_multipanel(layout, &layout.root)
}

build_edit_mode :: proc(layout: ^Layout) {
	build_multipanel_edit(layout, &layout.root)
}

build_multipanel :: proc(layout: ^Layout, multipanel: ^Multipanel) {

	ui := layout.ui

	if multipanel.mode == .Tab {
		button_height := get_button_dim(ui, "T").y

		begin_container(ui, .Top, button_height)
		panel_refs := &multipanel.panel_refs
			for panel_entry := panel_refs.first; panel_entry != nil; {

			panel := &panel_entry.entry.panel_in_list.entry

			button_state := button(
				ui = ui,
				label_str = panel.name,
				dir = .Left,
				active = ptr_eq(multipanel.active, panel_entry),
			)

			next_panel_entry := panel_entry.next
			skip_hang_once := true
			#partial switch button_state {
			case .Clicked:
				multipanel.active = panel_entry
			case .ClickedMiddle:
				next_panel_entry = detach_panel(layout, multipanel, panel_entry)
			case:
				skip_hang_once = false
			}

			layout.window.skip_hang_once ||= skip_hang_once
			panel_entry = next_panel_entry
		}
		end_container(ui)
	}

	switch multipanel.mode {

	case .Tab:
		if multipanel.active != nil {
			build_panel(layout, &multipanel.active.entry.panel_in_list.entry)
		}

	case .Split:
		for panel_ref_in_list := multipanel.panel_refs.first;
			panel_ref_in_list != nil;
			panel_ref_in_list = panel_ref_in_list.next {

			panel_ref := &panel_ref_in_list.entry
			panel := &panel_ref.panel_in_list.entry

			begin_container(ui, panel_ref.split_dir, panel_ref.split_size)
			build_panel(layout, panel)
			end_container(ui)
		}
	}
}

build_panel :: proc(layout: ^Layout, panel: ^Panel) {

	ui := layout.ui

	switch panel_val in &panel.contents {
	case Multipanel: build_multipanel(layout, &panel_val)

	case FileContentViewer:
		if panel_val.file_ref.file_in_list != nil {
			text_area(ui, &panel_val.file_ref.file_in_list.entry, &panel_val.file_ref)
		} else {
			if file_selected, some_file := file_selector(ui).(string); some_file {
				panel_val.file_ref.file_in_list = open_file(layout.fs, file_selected, ui.theme.text_colors)
				if panel_val.file_ref.file_in_list != nil {
					layout.window.skip_hang_once = true
				}
			}
		}
	}
}

build_multipanel_edit :: proc(layout: ^Layout, multipanel: ^Multipanel) {

	ui := layout.ui

	for panel_ref := multipanel.panel_refs.first; panel_ref != nil; panel_ref = panel_ref.next {
		add_multipanel_button_state := button(ui = ui, label_str = "Multipanel", dir = .Top)
		add_file_content_viewer_button_state := button(ui = ui, label_str = "FileContentViewer", dir = .Top)
	}

	add_multipanel_button_state := button(ui = ui, label_str = "Multipanel", dir = .Top)
	add_file_content_viewer_button_state := button(ui = ui, label_str = "FileContentViewer", dir = .Top)

	if add_file_content_viewer_button_state == .Clicked {
		file_content_viewer_panel := add_panel(layout, "FileContentViewer", FileContentViewer{})
		attach_panel(layout, multipanel, file_content_viewer_panel)
		layout.window.skip_hang_once = true
	}
}
