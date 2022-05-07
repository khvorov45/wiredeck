package wiredeck

Freelist :: struct($EntryType: typeid) {
	used: Linkedlist(EntryType),
	free: Linkedlist(EntryType),
	allocator: Allocator,
}

// Doubly-linked circular with ever-present sentinel
Linkedlist :: struct($EntryType: typeid) {
	// NOTE(khvorov) Pointer here so you can move the list around on the stack
	sentinel: ^LinkedlistEntry(EntryType),
}

LinkedlistEntry :: struct($EntryType: typeid) {
	entry: EntryType,
	prev, next: ^LinkedlistEntry(EntryType),
}

linkedlist_init :: proc(list: ^Linkedlist($EntryType), sentinel: ^LinkedlistEntry(EntryType)) {
	list^ = {}
	list.sentinel = sentinel
	list.sentinel^ = {}
	list.sentinel.prev = sentinel
	list.sentinel.next = sentinel
}

linkedlist_entry_is_sentinel :: proc(
	list: ^Linkedlist($EntryType), entry: ^LinkedlistEntry(EntryType),
) -> bool {
	result := ptr_eq(entry, list.sentinel)
	return result
}

linkedlist_is_empty :: proc(list: ^Linkedlist($EntryType)) -> bool {
	result := linkedlist_entry_is_sentinel(list, list.sentinel.next)
	if result {
		assert(linkedlist_entry_is_sentinel(list, list.sentinel.prev))
	}
	return result
}

linkedlist_append :: proc(list: ^Linkedlist($EntryType), entry: ^LinkedlistEntry(EntryType)) {
	entry.prev = list.sentinel.prev
	entry.next = list.sentinel
	entry.prev.next = entry
	entry.next.prev = entry
}

linkedlist_entry_remove :: proc(entry: ^LinkedlistEntry($EntryType)) {
	entry.prev.next = entry.next
	entry.next.prev = entry.prev
	entry.prev = nil
	entry.next = nil
}

linkedlist_first :: proc(list: ^Linkedlist($EntryType)) -> ^LinkedlistEntry(EntryType) {
	result := list.sentinel.next
	return result
}

linkedlist_last :: proc(list: ^Linkedlist($EntryType)) -> ^LinkedlistEntry(EntryType) {
	result := list.sentinel.prev
	return result
}

linkedlist_remove_first :: proc(list: ^Linkedlist($EntryType)) -> ^LinkedlistEntry(EntryType) {
	result := linkedlist_first(list)
	linkedlist_entry_remove(result)
	return result
}

linkedlist_remove_last :: proc(list: ^Linkedlist($EntryType)) -> ^LinkedlistEntry(EntryType) {
	result := linkedlist_last(list)
	linkedlist_entry_remove(result)
	return result
}

linkedlist_remove_last_or_new :: proc(
	list: ^Linkedlist($EntryType), entry: EntryType, allocator: Allocator,
) -> ^LinkedlistEntry(EntryType) {
	new_entry: ^LinkedlistEntry(EntryType)
	if linkedlist_is_empty(list) {
		new_entry = new(LinkedlistEntry(EntryType), allocator)
	} else {
		new_entry = linkedlist_remove_last(list)
	}
	new_entry^ = {}
	new_entry.entry = entry
	return new_entry
}

linkedlist_remove_clear_append :: proc(entry: ^LinkedlistEntry($EntryType), dest: ^Linkedlist(EntryType)) {
	linkedlist_entry_remove(entry)
	entry^ = {}
	linkedlist_append(dest, entry)
}

freelist_init :: proc(list: ^Freelist($EntryType), allocator := context.allocator) {
	list^ = {}
	list.allocator = allocator
	linkedlist_init(&list.used, new(LinkedlistEntry(EntryType), allocator))
	linkedlist_init(&list.free, new(LinkedlistEntry(EntryType), allocator))
}

freelist_append :: proc(list: ^Freelist($EntryType), entry: EntryType) -> ^LinkedlistEntry(EntryType) {
	new_entry := linkedlist_remove_last_or_new(&list.free, entry, list.allocator)
	linkedlist_append(&list.used, new_entry)
	return new_entry
}

freelist_remove :: proc(list: ^Freelist($EntryType), entry: ^LinkedlistEntry(EntryType)) {
	linkedlist_remove_clear_append(entry, &list.free)
}
