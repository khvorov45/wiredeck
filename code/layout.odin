package wiredeck

Layout :: struct {
	window: ^Window,
	layout: ^Layout,
	ui: ^UI,
	fs: ^Filesystem,
	root: Panel,
	panels_free: Linkedlist(Panel),
	edit_mode: bool,
	freelist_allocator: Allocator,
}

Panel :: struct {
	children: Linkedlist(Panel),
	child_active: ^LinkedlistEntry(Panel), // NOTE(khvorov) nil means the panel itself is active
	mode: PanelMode,
	split_dir: Direction,
	split_size: int,
	ref_count: int,
	contents: PanelContents,
}

PanelContents :: union {
	FileContentViewer,
}

FileContentViewer :: struct {
	active_entry: ^FilesystemEntry,
	active_file_ref: FileRef,
}

PanelMode :: enum {
	Split,
	Tab,
}

init_layout :: proc(layout: ^Layout, window: ^Window, ui: ^UI, fs: ^Filesystem, freelist_allocator: Allocator) {
	layout^ = {window = window, layout = layout, ui = ui, fs = fs, freelist_allocator = freelist_allocator}
}

attach_panel :: proc(layout: ^Layout, panel: ^Panel, contents: PanelContents) -> ^LinkedlistEntry(Panel) {
	child := linkedlist_remove_last_or_new(&layout.panels_free, Panel{contents = contents}, layout.freelist_allocator)
	linkedlist_append(&panel.children, child)
	panel.child_active = child
	return child
}

detach_panel :: proc(layout: ^Layout, panel: ^Panel, child: ^LinkedlistEntry(Panel)) -> ^LinkedlistEntry(Panel) {

	next_ref := child.next

	if ptr_eq(panel.child_active, child) {
		if child.next == nil && child.prev == nil {
			panel.child_active = nil
		} else if child.next == nil {
			panel.child_active = child.prev
		} else {
			panel.child_active = child.next
		}
	}

	linkedlist_remove_clear_append(&panel.children, child, &layout.panels_free)
	return next_ref
}

build_layout :: proc(layout: ^Layout) {
	if layout.edit_mode {
		build_edit_mode(layout)
	} else {
		build_contents(layout)
	}
}

build_contents :: proc(layout: ^Layout) {
	build_panel(layout, &layout.root)
}

build_edit_mode :: proc(layout: ^Layout) {
	build_panel_edit(layout, &layout.root)
}

build_panel :: proc(layout: ^Layout, panel: ^Panel) {

	ui := layout.ui

	if panel.mode == .Tab && panel.children.count > 0 {
		button_height := get_button_dim(ui, "T").y

		begin_container(ui, .Top, button_height)
		children := &panel.children
			for child_panel_in_list := children.first; child_panel_in_list != nil; {

			child_panel := &child_panel_in_list.entry

			button_state := button(
				ui = ui,
				label_str = "MULTIPANEL",
				dir = .Left,
				active = ptr_eq(panel.child_active, child_panel_in_list),
			)

			next_panel_entry := child_panel_in_list.next
			skip_hang_once := true
			#partial switch button_state {
			case .Clicked:
				panel.child_active = child_panel_in_list
			case .ClickedMiddle:
				next_panel_entry = detach_panel(layout, panel, child_panel_in_list)
			case:
				skip_hang_once = false
			}

			layout.window.skip_hang_once ||= skip_hang_once
			child_panel_in_list = next_panel_entry
		}
		end_container(ui)
	}

	switch panel.mode {

	case .Tab:
		if panel.child_active != nil {
			build_panel(layout, &panel.child_active.entry)
		}

	case .Split:
		for child_in_list := panel.children.first;
			child_in_list != nil;
			child_in_list = child_in_list.next {

			child_panel := &child_in_list.entry

			begin_container(ui, child_panel.split_dir, child_panel.split_size)
			build_panel(layout, child_panel)
			end_container(ui)
		}
	}

	switch panel_val in &panel.contents {

	case FileContentViewer:

		if panel_val.active_file_ref.file_in_list != nil {
			text_area(ui, &panel_val.active_file_ref)

		} else {
			active_modified, active_opened := file_selector(ui, layout.fs, &panel_val.active_entry) 

			if active_modified {
				layout.window.skip_hang_once = true

				if active_opened {
					new_file_ref := open_file(layout.fs, panel_val.active_entry, ui.theme.text_colors)
					if new_file_ref != nil {
						panel_val.active_file_ref.file_in_list = new_file_ref
					}
				}
			}
		}
	}
}

build_panel_edit :: proc(layout: ^Layout, panel: ^Panel) {

	/*
	ui := layout.ui

	for panel_ref := panel.panel_refs.first; panel_ref != nil; panel_ref = panel_ref.next {
		add_multipanel_button_state := button(ui = ui, label_str = "Multipanel", dir = .Top)
		add_file_content_viewer_button_state := button(ui = ui, label_str = "FileContentViewer", dir = .Top)
	}

	add_multipanel_button_state := button(ui = ui, label_str = "Multipanel", dir = .Top)
	add_file_content_viewer_button_state := button(ui = ui, label_str = "FileContentViewer", dir = .Top)

	if add_file_content_viewer_button_state == .Clicked {
		file_content_viewer_panel := add_panel(layout, FileContentViewer{})
		attach_panel(layout, panel, file_content_viewer_panel)
		layout.window.skip_hang_once = true
	}
	*/
}
