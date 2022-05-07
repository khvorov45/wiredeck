package wiredeck

Freelist :: struct($EntryType: typeid) {
	sentinel: FreelistEntry(EntryType),
	free: ^FreelistEntry(EntryType),
	allocator: Allocator,
}

FreelistEntry :: struct($EntryType: typeid) {
	entry: EntryType,
	prev, next: ^FreelistEntry(EntryType),
}

freelist_init :: proc(list: ^Freelist($EntryType), allocator := context.allocator) {
	list^ = {}
	list.allocator = allocator
	list.sentinel.prev = &list.sentinel
	list.sentinel.next = &list.sentinel
}

freelist_create :: proc($Type: typeid) -> Freelist(Type) {
	list: Freelist(Type)
	freelist_init(&list)
	return list
}

freelist_append :: proc(list: ^Freelist($EntryType), entry: EntryType) -> ^FreelistEntry(EntryType) {

	if list.free == nil {
		list.free = new(FreelistEntry(EntryType), list.allocator)
		list.free^ = {}
	}

	new_entry := list.free
	list.free = list.free.next

	new_entry.entry = entry
	new_entry.prev = list.sentinel.prev
	new_entry.next = &list.sentinel

	new_entry.prev.next = new_entry
	new_entry.next.prev = new_entry

	return new_entry
}

freelist_first :: proc(list: ^Freelist($EntryType)) -> ^FreelistEntry(EntryType) {
	result := &list.sentinel.next
	return result
}

freelist_last :: proc(list: ^Freelist($EntryType)) -> ^FreelistEntry(EntryType) {
	result := &list.sentinel.prev
	return result
}
