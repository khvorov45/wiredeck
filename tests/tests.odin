package tests

import "core:runtime"
import "core:fmt"
import "core:mem"
import "core:math/rand"
import "../code"

println :: fmt.println
printf :: fmt.printf

get_aligned_byte_slice :: proc() {

	for _ in 0..100 {
		start := rawptr(uintptr(rand.uint32()))
		size := int(rand.uint32())
		align := 1 << (uint(rand.uint32() % 21))

		data, size_aligned := code.get_aligned_byte_slice(start, size, align)

		assert((uintptr(raw_data(data)) % uintptr(align)) == 0)
		assert(len(data) == size)

		assert(uintptr(raw_data(data)) - uintptr(start) < uintptr(align))
	}

	success()
}

static_arena :: proc() {
	data: code.StaticArena
	code.static_arena_init(&data, 1 * code.GIGABYTE)
	allocator := code.static_arena_allocator(&data)

	for _ in 0..100 {
		size := int(rand.uint32() & 0xff)
		align := 1 << (uint(rand.uint32() % 21))

		data, err := mem.make_aligned([]u8, size, align, allocator)
		assert(err == .None)

		assert(uintptr(raw_data(data)) % uintptr(align) == 0)
		assert(len(data) == size)
	}

	success()
}

scratch :: proc() {
	data: code.ScratchBuffer
	code.scratch_buffer_init(&data, 1 * code.MEGABYTE)
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
		size := int(rand.uint32() & 0xff)
		align := 1 << (uint(rand.uint32() % 21))

		data, err := mem.make_aligned([]u8, size, align, allocator)
		assert(err == .None)

		assert(uintptr(raw_data(data)) % uintptr(align) == 0)
		assert(len(data) == size)
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
}

assertion_failure_proc :: proc(prefix, message: string, loc: runtime.Source_Code_Location) -> ! {
	runtime.print_caller_location(loc)
	runtime.print_string(" ")
	printf("test failed in %s: ", loc.procedure)
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
	println(loc.procedure, "ok")
}
