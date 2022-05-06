package wiredeck

FreeList :: struct($EntryType: typeid) {
	sentinel: FreeListEntry(EntryType),
	free: ^FreeListEntry(EntryType),
	allocator: Allocator,
}

FreeListEntry :: struct($EntryType: typeid) {
	entry: EntryType,
	prev, next: ^FreeListEntry(EntryType),
}

freelist_init :: proc(list: ^FreeList($EntryType), allocator := context.allocator) {
	list^ = {}
	list.allocator = allocator
	list.sentinel.prev = &list.sentinel
	list.sentinel.next = &list.sentinel
}

freelist_append :: proc(list: ^FreeList($EntryType), entry: EntryType) {

	if list.free == nil {
		list.free = new(FreeListEntry(EntryType), list.allocator)
		list.free^ = {}
	}

	new_entry := list.free
	list.free = list.free.next

	new_entry.entry = entry
	new_entry.prev = list.sentinel.prev
	new_entry.next = &list.sentinel

	new_entry.prev.next = new_entry
	new_entry.next.prev = new_entry
}
