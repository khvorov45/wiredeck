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
	case: err = .Mode_Not_Implemented
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
