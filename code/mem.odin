package wiredeck

import "core:mem"

MemoryBlock :: struct {
	base: [^]byte,
	used: int,
	committed: int,
	reserved: int,
}

StaticArena :: struct {
	block: MemoryBlock,
	temp_count: int,
}

StaticArenaTemp :: struct {
	arena: ^StaticArena,
	used: int,
}

ScratchBuffer :: struct {
	data: []byte,
	curr_offset: int,
	prev_allocation: rawptr,
}

BYTE :: 1
KILOBYTE :: 1024 * BYTE
MEGABYTE :: 1024 * KILOBYTE
GIGABYTE :: 1024 * MEGABYTE

align_formula :: proc(size, align: int) -> int {
	max_size := size + align - 1
	result := max_size - max_size % align
	return result
}

buffer_from_slice :: proc "contextless" (backing: $T/[]$E) -> [dynamic]E {
	return transmute([dynamic]E)mem.Raw_Dynamic_Array{
		data      = raw_data(backing),
		len       = 0,
		cap       = len(backing),
		allocator =  mem.Allocator{
			procedure = mem.panic_allocator_proc,
			data = nil,
		},
	}
}

//
// SECTION Memory block
//

memory_block_init :: proc(block: ^MemoryBlock, reserve, commit: int) -> (err: mem.Allocator_Error) {
	block^ = {}
	block.base, block.reserved, err = platform_memory_reserve(reserve)
	if err == .None {
		err = memory_block_commit(block, commit)
	}
	return err
}

memory_block_commit :: proc(block: ^MemoryBlock, size: int) -> (err: mem.Allocator_Error) {
	assert(block.used <= block.committed)
	assert(block.committed <= block.reserved)
	if block.committed - block.used < size {
		block.committed, err = platform_memory_commit(block.base, block.used + size)
	}
	return err
}

memory_block_alloc :: proc(
	block: ^MemoryBlock,
	size, align: int,
) -> (data: []byte, err: mem.Allocator_Error) {
	size_aligned := align_formula(size, align)
	err = memory_block_commit(block, size_aligned)
	if err == .None {
		data = block.base[block.used + (size_aligned - size):][:size]
		block.used += size_aligned
	}
	return data, err
}

//
// SECTION Static arena
//

static_arena_init :: proc(
	arena: ^StaticArena,
	reserve: int,
	commit: int = 1<<20, // NOTE(khvorov) 1 MiB
) -> (err: mem.Allocator_Error) {
	arena^ = {}
	err = memory_block_init(&arena.block, reserve, commit)
	return err
}

static_arena_allocator :: proc(arena: ^StaticArena) -> mem.Allocator {
	result := mem.Allocator{static_arena_allocator_proc, arena}
	return result
}

static_arena_allocator_proc :: proc(
	allocator_data: rawptr, mode: mem.Allocator_Mode,
    size, align: int,
    old_memory: rawptr, old_size: int,
    location := #caller_location,
) -> (data: []byte, err: mem.Allocator_Error) {
	arena := (^StaticArena)(allocator_data)
	#partial switch mode {
	case .Alloc: data, err = memory_block_alloc(&arena.block, size, align)
	case .Free_All: arena.block.used = 0
	case: panic(tprintf("static arena called with mode %s", mode), location)
	}
	return data, err
}

static_arena_temp_begin :: proc(arena: ^StaticArena) -> (temp: StaticArenaTemp) {
	temp.arena = arena
	temp.used = arena.block.used
	arena.temp_count += 1
	return
}

static_arena_temp_end :: proc(temp: StaticArenaTemp, loc := #caller_location) {
	assert(temp.arena != nil, "nil arena", loc)
	assert(temp.used >= temp.arena.block.used, "invalid Static_Arena_Temp", loc)
	assert(temp.arena.temp_count > 0, "double-use of static_arena_temp_end", loc)
	temp.arena.block.used = temp.used
	temp.arena.temp_count -= 1
}

static_arena_assert_no_temp :: proc(arena: ^StaticArena, loc := #caller_location) {
	assert(arena.temp_count == 0, "Static_Arena_Temp not been ended", loc)
}

//
// SECTION Scratch
//

scratch_buffer_init :: proc(
	buf: ^ScratchBuffer, size: int, allocator := context.allocator,
) -> (err: mem.Allocator_Error) {
	buf^ = {}
	buf.data, err = mem.make_aligned([]byte, size, 2 * align_of(rawptr), allocator)
	return err
}

scratch_allocator :: proc(buffer: ^ScratchBuffer) -> mem.Allocator {
	result := mem.Allocator{scratch_allocator_proc, buffer,}
	return result
}

scratch_allocator_proc :: proc(
	allocator_data: rawptr, mode: mem.Allocator_Mode,
	size_init, align: int,
    old_memory: rawptr, old_size: int, loc := #caller_location,
) -> (data: []byte, err: mem.Allocator_Error) {

	scratch := (^ScratchBuffer)(allocator_data)
	assert(scratch.data != nil)

	switch mode {
	case .Alloc:
		size := align_formula(size_init, align)

		switch {
		case scratch.curr_offset + size <= len(scratch.data):
			data = scratch.data[scratch.curr_offset + (size - size_init):][:size_init]
			scratch.curr_offset += size
			scratch.prev_allocation = raw_data(data)

		case size <= len(scratch.data):
			data = scratch.data[size - size_init:][:size_init]
			scratch.curr_offset = size
			scratch.prev_allocation = raw_data(data)

		case: panic(tprintf(
			"scratch size is %d bytes but asked to allocate %d bytes", len(scratch.data), size,
			), loc)
		}

	case .Free:
		if scratch.prev_allocation == old_memory {
			scratch.curr_offset = int(uintptr(scratch.prev_allocation) - uintptr(raw_data(scratch.data)))
			scratch.prev_allocation = nil
		}

	case .Free_All:
		scratch.curr_offset = 0
		scratch.prev_allocation = nil

	case .Resize:
		begin := uintptr(raw_data(scratch.data))
		end := begin + uintptr(len(scratch.data))
		old_ptr := uintptr(old_memory)
		if begin <= old_ptr && old_ptr < end {
			if old_ptr + uintptr(size_init) < end {
				data = mem.byte_slice(old_memory, size_init)
				scratch.curr_offset = int(old_ptr - begin) + size_init
			} else {
				data, err := scratch_allocator_proc(allocator_data, .Alloc, size_init, align, old_memory, old_size, loc)
				if err == nil {
					copy(data, mem.byte_slice(old_memory, old_size))
				}
			}
		} else {
			err = .Invalid_Pointer
		}

	case .Query_Features:
		set := (^mem.Allocator_Mode_Set)(old_memory)
		if set != nil {
			set^ = {.Alloc, .Free, .Free_All, .Resize, .Query_Features}
		}

	case .Query_Info: err = .Mode_Not_Implemented
	}

	return data, err
}

