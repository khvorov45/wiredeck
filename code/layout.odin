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
	children_mode: PanelMode,
	split: Maybe(PanelSplitSpec),
	contents: PanelContents,
}

PanelSplitSpec :: struct {
	dir: Direction,
	size: int,
}

PanelContents :: union {
	FileManager,
	FileContentView,
}

FileContentView :: struct {
	file: ^File,
	line_offset_lines: int,
	line_offset_bytes: int,
	col_offset: int,
	cursor_scroll_ref: [2]Maybe(f32),
}

FileManager :: struct {
	selector_active: bool,
}

PanelMode :: enum {
	Split,
	Tab,
}

init_layout :: proc(layout: ^Layout, window: ^Window, ui: ^UI, fs: ^Filesystem, freelist_allocator: Allocator) {
	layout^ = {window = window, layout = layout, ui = ui, fs = fs, freelist_allocator = freelist_allocator}
}

attach_panel :: proc(
	layout: ^Layout, panel: ^Panel, contents: PanelContents, 
	split_spec: Maybe(PanelSplitSpec) = nil,
) -> ^LinkedlistEntry(Panel) {
	new_panel := Panel{contents = contents, split = split_spec}
	child := linkedlist_remove_last_or_new(&layout.panels_free, new_panel, layout.freelist_allocator)
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
	assert(layout.root.contents == nil, "layout root panel should be empty")
	if layout.edit_mode {
		build_panel_edit(layout, &layout.root)
	} else {
		build_panel(layout, &layout.root)
	}
}

build_panel :: proc(layout: ^Layout, panel: ^Panel) {

	ui := layout.ui

	if panel.children_mode == .Tab && panel.children.count > 0 {
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

	switch panel.children_mode {

	case .Tab:
		if panel.child_active != nil {
			build_panel(layout, &panel.child_active.entry)
		}

	case .Split:
		for child_in_list := panel.children.first;
			child_in_list != nil;
			child_in_list = child_in_list.next {

			child_panel := &child_in_list.entry

			split_dir := Direction.Top
			split_size := last_container(ui).available.dim.y
			if child_split, some := child_panel.split.(PanelSplitSpec); some {
				split_dir = child_split.dir
				split_size = child_split.size 
			}

			begin_container(ui, split_dir, split_size)
			build_panel(layout, child_panel)
			end_container(ui)
		}
	}

	switch panel_val in &panel.contents {
	case FileContentView: text_area(ui, &panel_val)
	
	case FileManager:

		if button(ui = ui, dir = .Top, label_str = "Add...", text_align = .Begin) == .Clicked {
			panel_val.selector_active = !panel_val.selector_active
		}

		for file_in_list := layout.fs.files.used.first; file_in_list != nil; file_in_list = file_in_list.next {
			file := &file_in_list.entry
			button(ui = ui, dir = .Top, label_str = file.fullpath, label_col = file.fullpath_col, text_align = .Begin)
		}

		if panel_val.selector_active {
			unimplemented("file selector")
		}

		/*
		cur_rect := full_rect
		default_col_width := 100

		cur_root: Maybe(string)
		for {

			cur_rect.dim.x = 0
			filesystem_entries_iter := filesystem_entries_begin(cur_root)
			for filesystem_entry_str in filesystem_entry_next(&filesystem_entries_iter, context.temp_allocator) {
				cur_rect.dim.x = max(cur_rect.dim.x, get_button_dim(ui, filesystem_entry_str).x)
			}
			if cur_rect.dim.x == 0 {
				cur_rect.dim.x = default_col_width
			}

			cur_text_rect := cur_rect
			cur_text_rect.dim.y = get_button_dim(ui, "T").y

			filesystem_entries_iter = filesystem_entries_begin(cur_root)
			next_root: Maybe(string)
			for filesystem_entry_str in filesystem_entry_next(&filesystem_entries_iter, context.temp_allocator) {

				visible := clip_rect_to_rect(cur_text_rect, visible_rect)

				state := _get_rect_mouse_state(ui.input, visible)

				if state >= .Hovered {
					_cmd_rect(ui, visible, ui.theme.colors[.BackgroundHovered])
				}

				if state == .Clicked {
					next_root = strings.clone(filesystem_entry_str, ui.arena_allocator)
				}

				_cmd_textline(
					ui = ui,
					full = cur_text_rect,
					visible = visible,
					label_str = filesystem_entry_str,
					text_align = .Begin,
				)

				cur_text_rect.topleft.y += cur_text_rect.dim.y
			}

			if next_root == nil {
				break
			} else {
				cur_root = next_root
				cur_rect.topleft.x += cur_rect.dim.x
			}
		}
		*/


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
