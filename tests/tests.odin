package tests

import "core:runtime"
import "core:fmt"
import "core:mem"
import "core:math/rand"
import "../code"

println :: fmt.println
printf :: fmt.printf
tprintf :: fmt.tprintf

_get_random_size_align :: proc() -> (size: int, align: int) {
	size = max(int(rand.uint32() & 0xff), 1)
	align = 1 << (uint(rand.uint32() % 21)) 
	return size, align
}

_check_allocation_result :: proc(data: []u8, err: code.AllocatorError, size, align: int) {
	assert(err == .None)
	assert(uintptr(raw_data(data)) % uintptr(align) == 0)
	assert(len(data) == size)
}

get_aligned_byte_slice :: proc() {

	for _ in 0..100 {
		start := rawptr(uintptr(rand.uint32()))
		size, align := _get_random_size_align()

		data, size_aligned := code.get_aligned_byte_slice(start, size, align)
		_check_allocation_result(data, .None, size, align)
	}

	success()
}

static_arena :: proc() {
	data: code.StaticArena
	code.static_arena_init(&data, 1 * code.GIGABYTE)
	allocator := code.static_arena_allocator(&data)

	for _ in 0..100 {
		size, align := _get_random_size_align()

		data, err := mem.make_aligned([]u8, size, align, allocator)
		_check_allocation_result(data, err, size, align)
	}

	success()
}

scratch :: proc() {
	data: code.ScratchBuffer
	code.scratch_buffer_init(&data, 1 * code.MEGABYTE, context.allocator)
	allocator := code.scratch_allocator(&data)

	buf1, err1 := mem.make_aligned([]u8, 300, 1, allocator)
	assert(err1 == .None)
	assert(uintptr(raw_data(buf1)) == uintptr(raw_data(data.data)))

	buf2, err2 := mem.make_aligned([]u8, 300, 1, allocator)
	assert(err2 == .None)
	assert(uintptr(raw_data(buf2)) == uintptr(raw_data(data.data)) + uintptr(len(buf1)))

	buf3, err3 := mem.make_aligned([]u8, 1 * code.MEGABYTE, 1, allocator)
	assert(err3 == .None)
	assert(uintptr(raw_data(buf3)) == uintptr(raw_data(data.data)))

	success()
}

arena :: proc() {

	data: code.Arena
	code.arena_init(&data, make([]u8, 1 * code.GIGABYTE))
	allocator := code.arena_allocator(&data)

	for _ in 0..100 {
		size, align := _get_random_size_align()

		data, err := mem.make_aligned([]u8, size, align, allocator)
		_check_allocation_result(data, err, size, align)
	}

	success()
}

pool :: proc() {
	pool_data: code.MemoryPool
	code.memory_pool_init(&pool_data, 100 * code.MEGABYTE, context.allocator)
	allocator := code.pool_allocator(&pool_data)

	Request :: struct {
		size: int,
		align: int,
		data: []u8,
	}

	req_count := 100
	requests := make([]Request, req_count)

	check_entire_pool :: proc(pool: ^code.MemoryPool) {
		for chunk := pool.first_chunk; chunk != nil; chunk = chunk.next {
			for marker := chunk.first_marker; marker != nil; marker = marker.next {
				assert(marker.chunk == chunk)

				if marker.free_till_next {
					if marker.next != nil {
						assert(!marker.next.free_till_next)
					}
					if marker.prev != nil {
						assert(!marker.prev.free_till_next)
					}
				}

				if marker.prev == nil {
					assert(code.ptr_eq(chunk.first_marker, marker))
					if marker.free_till_next {
						assert(uintptr(chunk.first_marker) == uintptr(chunk) + size_of(code.PoolMarker))
					}
				} else {
					assert(code.ptr_eq(marker.prev.next, marker))
				}

				if marker.next != nil {
					assert(
						code.ptr_eq(marker.next.prev, marker),
						tprintf("marker.next.prev != marker:\n{0:p} {0:v}\n{1:p} {1:v}\n", marker.next.prev, marker),
					)
				}


			}
		}
	}

	for req_index in 0..<req_count {
		size, align := _get_random_size_align()
		data, err := mem.make_aligned([]u8, size, align, allocator)
		_check_allocation_result(data, err, size, align)
		check_entire_pool(&pool_data)
		requests[req_index] = Request{size, align, data}
	}

	for _ in 0..10000 {
		req_index := int(rand.uint32() % u32(req_count))
		request := &requests[req_index]

		if request.data == nil {
			data, err := mem.make_aligned([]u8, request.size, request.align, allocator)
			_check_allocation_result(data, err, request.size, request.align)
			check_entire_pool(&pool_data)
			request.data = data
		} else {
			delete(request.data, allocator)
			check_entire_pool(&pool_data)
			request.data = nil
		}
	}

	success()
}

main :: proc() {
	context.assertion_failure_proc = assertion_failure_proc
	println("running tests")

	get_aligned_byte_slice()
	static_arena()
	scratch()
	arena()
	pool()

	println("tests passed")
}

assertion_failure_proc :: proc(prefix, message: string, loc: runtime.Source_Code_Location) -> ! {
	runtime.print_caller_location(loc)
	runtime.print_string(" ")
	printf("ERR: test failed in %s: ", loc.procedure)
	//runtime.print_string(prefix)
	if len(message) > 0 {
		runtime.print_string(message)
	} else {
		runtime.print_string("no message provided")
	}
	runtime.print_byte('\n')
	runtime.trap()
}

success :: proc(loc := #caller_location) {
	println("OK:", loc.procedure)
}
