package wiredeck

import "core:mem"
import win "windows"

platform_memory_reserve :: proc(reserve: int) -> (base: [^]byte, reserved: int, err: mem.Allocator_Error) {
	assert(reserve >= 0)
	base = cast([^]byte)win.VirtualAlloc(nil, uint(reserve), win.MEM_RESERVE, win.PAGE_READWRITE)
	if base != nil {
		reserved = reserve
	} else {
		err = .Out_Of_Memory
	}
	return base, reserved, err
}

platform_memory_commit :: proc(base: [^]byte, commit: int) -> (committed: int, err: mem.Allocator_Error) {
	assert(commit >= 0)
	result := win.VirtualAlloc(base, uint(commit), win.MEM_COMMIT, win.PAGE_READWRITE)
	if result != nil {
		committed = commit
	} else {
		err = .Out_Of_Memory
	}
	return committed, err
}
