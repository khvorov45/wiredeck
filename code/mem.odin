package wiredeck

import "core:mem"

AllocatorError :: mem.Allocator_Error
AllocatorMode :: mem.Allocator_Mode
Allocator :: mem.Allocator

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

Arena :: struct {
	data: []byte,
	used: int,
	temp_count: int,
}

ArenaTemp :: struct {
	arena: ^Arena,
	used: int,
}

BYTE :: 1
KILOBYTE :: 1024 * BYTE
MEGABYTE :: 1024 * KILOBYTE
GIGABYTE :: 1024 * MEGABYTE

get_aligned_byte_slice :: proc(ptr: rawptr, size, align: int) -> (data: []u8, size_aligned: int) {
	assert(align > 0)
	assert((align & (align - 1)) == 0)
	assert(size >= 0)
	ptr_aligned := ptr
	modulo := uintptr(ptr_aligned) & uintptr((align - 1))
	if modulo != 0 {
		ptr_aligned = rawptr(uintptr(ptr_aligned) + (uintptr(align) - modulo))
	}
	data = mem.byte_slice(ptr_aligned, size)
	size_aligned = size + int(uintptr(ptr_aligned) - uintptr(ptr))
	assert(size_aligned >= size)
	return data, size_aligned
}

buffer_from_slice :: proc "contextless" (backing: $T/[]$E) -> [dynamic]E {
	return transmute([dynamic]E)mem.Raw_Dynamic_Array{
		data      = raw_data(backing),
		len       = 0,
		cap       = len(backing),
		allocator =  Allocator{
			procedure = mem.panic_allocator_proc,
			data = nil,
		},
	}
}

//
// SECTION Memory block
//

memory_block_init :: proc(block: ^MemoryBlock, reserve, commit: int) -> (err: AllocatorError) {
	block^ = {}
	block.base, block.reserved, err = platform_memory_reserve(reserve)
	if err == .None {
		err = memory_block_commit(block, commit)
	}
	return err
}

memory_block_commit :: proc(block: ^MemoryBlock, size: int) -> (err: AllocatorError) {
	assert(block.used <= block.committed)
	assert(block.committed <= block.reserved)
	if block.committed - block.used < size {
		if block.reserved - block.used >= size {
			block.committed, err = platform_memory_commit(block.base, block.used + size)
		} else {
			err = .Out_Of_Memory
		}
	}
	return err
}

memory_block_alloc :: proc(
	block: ^MemoryBlock, size, align: int,
) -> (data: []byte, err: AllocatorError) {
	size_aligned: int
	data, size_aligned = get_aligned_byte_slice(block.base[block.used:], size, align)
	err = memory_block_commit(block, size_aligned)
	if err == .None {
		block.used += size_aligned
	} else {
		data = nil
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
) -> (err: AllocatorError) {
	arena^ = {}
	err = memory_block_init(&arena.block, reserve, commit)
	return err
}

static_arena_allocator :: proc(arena: ^StaticArena) -> Allocator {
	result := Allocator{static_arena_allocator_proc, arena}
	return result
}

static_arena_allocator_proc :: proc(
	allocator_data: rawptr, mode: AllocatorMode,
    size, align: int,
    old_memory: rawptr, old_size: int,
    location := #caller_location,
) -> (data: []byte, err: AllocatorError) {
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
) -> (err: AllocatorError) {
	buf^ = {}
	buf.data, err = mem.make_aligned([]byte, size, 2 * align_of(rawptr), allocator)
	return err
}

scratch_allocator :: proc(buffer: ^ScratchBuffer) -> Allocator {
	result := Allocator{scratch_allocator_proc, buffer,}
	return result
}

scratch_allocator_proc :: proc(
	allocator_data: rawptr, mode: AllocatorMode,
	size, align: int,
    old_memory: rawptr, old_size: int, loc := #caller_location,
) -> (data: []byte, err: AllocatorError) {

	scratch := (^ScratchBuffer)(allocator_data)
	assert(scratch.data != nil)

	switch mode {
	case .Alloc:
		data_from_cur, size_aligned_from_cur :=
			get_aligned_byte_slice(raw_data(scratch.data[scratch.curr_offset:]), size, align)
		data_from_base, size_aligned_from_base :=
			get_aligned_byte_slice(raw_data(scratch.data), size, align)

		switch {
		case scratch.curr_offset + size_aligned_from_cur <= len(scratch.data):
			data = data_from_cur
			scratch.curr_offset += size_aligned_from_cur
			scratch.prev_allocation = raw_data(data)

		case size_aligned_from_base <= len(scratch.data):
			data = data_from_base
			scratch.curr_offset = size_aligned_from_base
			scratch.prev_allocation = raw_data(data)

		case: panic(tprintf(
				"scratch size is %d bytes but asked to allocate %d bytes with %d alignment",
				len(scratch.data), size, align,
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
			if old_ptr + uintptr(size) < end {
				data = mem.byte_slice(old_memory, size)
				scratch.curr_offset = int(old_ptr - begin) + size
			} else {
				data, err := 
					scratch_allocator_proc(allocator_data, .Alloc, size, align, old_memory, old_size, loc)
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

//
// SECTION Arena
//

init_arena :: proc(arena: ^Arena, data: []byte) {
	arena^ = {}
	arena.data = data
}

arena_allocator :: proc(arena: ^Arena) -> Allocator {
	result := Allocator{arena_allocator_proc, arena}
	return result
}

arena_allocator_proc :: proc(
	allocator_data: rawptr, mode: AllocatorMode,
    size, align: int,
    old_memory: rawptr, old_size: int, location := #caller_location,
) -> (data: []byte, err: AllocatorError)  {

	arena := cast(^Arena)allocator_data
	assert(arena != nil)

	#partial switch mode {
	case .Alloc:
		size_aligned: int
		data, size_aligned = get_aligned_byte_slice(raw_data(arena.data[arena.used:]), size, align)
		if arena.used + size_aligned > len(arena.data) {
			data = nil
			err = .Out_Of_Memory
		} else {
			arena.used += size_aligned
		}
	case .Free_All: arena.used = 0
	case: panic(tprintf("arena called with mode %s", mode), location)
	}

	return data, err
}

begin_arena_temp_memory :: proc(arena: ^Arena) -> ArenaTemp {
	temp := ArenaTemp{arena, arena.used}
	arena.temp_count += 1
	return temp
}

end_arena_temp_memory :: proc(temp: ArenaTemp, loc := #caller_location) {
	assert(temp.arena != nil, "nil arena", loc)
	assert(temp.used >= temp.arena.used, "invalid Static_Arena_Temp", loc)
	assert(temp.arena.temp_count > 0, "double-use of static_arena_temp_end", loc)
	temp.arena.used = temp.used
	temp.arena.temp_count -= 1
}
