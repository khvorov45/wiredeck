package wiredeck

Freelist :: struct($EntryType: typeid) {
	used: Linkedlist(EntryType),
	free: Linkedlist(EntryType),
	allocator: Allocator,
}

Linkedlist :: struct($EntryType: typeid) {
	first: ^LinkedlistEntry(EntryType),
	last: ^LinkedlistEntry(EntryType),
}

LinkedlistEntry :: struct($EntryType: typeid) {
	entry: EntryType,
	prev, next: ^LinkedlistEntry(EntryType),
}

linkedlist_append :: proc(list: ^Linkedlist($EntryType), entry: ^LinkedlistEntry(EntryType)) {
	if list.first == nil {
		list.first = entry
		list.last = entry
		entry.next = nil
		entry.prev = nil
	} else {
		entry.next = nil
		entry.prev = list.last
		list.last = entry
		entry.prev.next = entry
	}
}

linkedlist_entry_remove :: proc(list: ^Linkedlist($EntryType), entry: ^LinkedlistEntry(EntryType)) -> ^LinkedlistEntry(EntryType) {
	if entry.prev != nil {
		entry.prev.next = entry.next
	} else {
		list.first = entry.next
	}
	if entry.next != nil {
		entry.next.prev = entry.prev
	} else {
		list.last = entry.prev
	}
	entry.prev = nil
	entry.next = nil
	return entry
}

linkedlist_remove_last_or_new :: proc(
	list: ^Linkedlist($EntryType), entry: EntryType, allocator: Allocator,
) -> ^LinkedlistEntry(EntryType) {
	new_entry: ^LinkedlistEntry(EntryType)
	if list.last == nil {
		new_entry = new(LinkedlistEntry(EntryType), allocator)
	} else {
		new_entry = linkedlist_entry_remove(list, list.last)
	}
	new_entry^ = {}
	new_entry.entry = entry
	return new_entry
}

linkedlist_remove_clear_append :: proc(source: ^Linkedlist($EntryType), entry: ^LinkedlistEntry(EntryType), dest: ^Linkedlist(EntryType)) {
	linkedlist_entry_remove(source, entry)
	entry^ = {}
	linkedlist_append(dest, entry)
}

freelist_init :: proc(list: ^Freelist($EntryType), allocator: Allocator) {
	list^ = {}
	list.allocator = allocator
}

freelist_append :: proc(list: ^Freelist($EntryType), entry: EntryType) -> ^LinkedlistEntry(EntryType) {
	new_entry := linkedlist_remove_last_or_new(&list.free, entry, list.allocator)
	linkedlist_append(&list.used, new_entry)
	return new_entry
}

freelist_remove :: proc(list: ^Freelist($EntryType), entry: ^LinkedlistEntry(EntryType)) {
	linkedlist_remove_clear_append(&list.used, entry, &list.free)
}
