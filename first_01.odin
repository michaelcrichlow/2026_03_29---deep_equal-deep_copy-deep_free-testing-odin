package test

import "base:intrinsics"
import "core:fmt"
import "core:mem"
import "core:slice"
import "core:strconv"
import "core:strings"
import "core:math"
import "core:sys/windows"
import "core:time"
import "core:unicode"
import "core:reflect"
import "core:os"
import "core:encoding/json"
import p_str "python_string_functions"
import p_list "python_list_functions"
import p_int "python_int_functions"
import p_float "python_float_functions"
import p_heap "python_heap_functions"
import p_rand "python_random_functions"
import re "python_regex_functions"
import p_deque "python_deque_functions"
//print :: fmt.println
//printf :: fmt.printf

// DEBUG_MODE :: true

main :: proc() {

    when DEBUG_MODE {
        // tracking allocator
        track: mem.Tracking_Allocator
        mem.tracking_allocator_init(&track, context.allocator)
        context.allocator = mem.tracking_allocator(&track)

        defer {
            if len(track.allocation_map) > 0 {
                fmt.eprintf(
                    "=== %v allocations not freed: context.allocator ===\n",
                    len(track.allocation_map),
                )
                for _, entry in track.allocation_map {
                    fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
                }
            }
            if len(track.bad_free_array) > 0 {
                fmt.eprintf(
                    "=== %v incorrect frees: context.allocator ===\n",
                    len(track.bad_free_array),
                )
                for entry in track.bad_free_array {
                    fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
                }
            }
            mem.tracking_allocator_destroy(&track)
        }

        // tracking temp_allocator
        track_temp: mem.Tracking_Allocator
        mem.tracking_allocator_init(&track_temp, context.temp_allocator)
        context.temp_allocator = mem.tracking_allocator(&track_temp)

        defer {
            if len(track_temp.allocation_map) > 0 {
                fmt.eprintf(
                    "=== %v allocations not freed: context.temp_allocator ===\n",
                    len(track_temp.allocation_map),
                )
                for _, entry in track_temp.allocation_map {
                    fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
                }
            }
            if len(track_temp.bad_free_array) > 0 {
                fmt.eprintf(
                    "=== %v incorrect frees: context.temp_allocator ===\n",
                    len(track_temp.bad_free_array),
                )
                for entry in track_temp.bad_free_array {
                    fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
                }
            }
            mem.tracking_allocator_destroy(&track_temp)
        }
    }

    // main work
    print("Hello from Odin!")
    windows.SetConsoleOutputCP(windows.CODEPAGE.UTF8)
    start: time.Time = time.now()

    // code goes here
    // ----------------------------------------------------------------------------------------------------------------
    run_thorough_tests()
    // ----------------------------------------------------------------------------------------------------------------

    elapsed: time.Duration = time.since(start)
    print("Odin took:", elapsed)

}
// END MAIN
// ----------------------------------------------------------------------------------


run_thorough_tests :: proc() {
    print("--- STARTING DEEP LIBRARIES TEST SUITE ---")
    
    // 1. Setup complex nested data
    p1 := Person{
        name = "Alice",
        age = 30,
        Friends = []string{"Bob", "Charlie"},
        address = Address{
            street = "123 Main St",
            city   = "Springfield",
            state  = "IL",
            zip    = 62704,
            is_work = false,
        },
    }

    // Creating a deeply nested []any structure
    inner_00 := []any{1, 2, 3} 
    inner_01 := []any{5, inner_00}
    inner_02 := []any{4.5678, inner_01}
    inner_03 := []any{true, inner_02}
    inner_04 := []any{"apple", inner_03}
    source   := []any{p1, inner_04}
    // source is essentially --> [Person, ["apple", [true, [4.5678, [5, [1, 2, 3]]]]]]

    // 2. Perform Deep Copy
    print("Action: Deep Copying source...")
    cloned := deep_copy(source)
    defer deep_free(cloned)

    // 3. Test: Equality
    eq_result := deep_equal(source, cloned)
    print("Test 1 (Equality):", eq_result ? "PASSED" : "FAILED")
    assert(deep_equal(source, cloned))

    // 4a. Test: Independence (Modify clone, source should not change)
    print("Action: Modifying clone...")

    // Reach into the clone and change the name of the Person
    cloned_person := transmute(^Person)cloned[0].data
    update_string(&cloned_person.name, "Malice") // release memory for the current string, allocate memory for the new string
    cloned_person.age = 300

    print("---- The Addresses of both `source` and `cloned` ----") 
    fmt.printf("Source Data Ptr: %p\n", source[0].data)   // <---+-- these values should be different
    fmt.printf("Clone Data Ptr:  %p\n", cloned[0].data)   // <---+

    print("\n source:", source)
    print("\n cloned:", cloned)
    print("\n-------------------------------------------")
    
    // 4b. Test : Reach deep into the nested []any and change a value
    // Path: cloned[1] -> inner_04 -> inner_03 -> inner_02 -> inner_01 -> inner_00
    c_inner_04 := (transmute(^[]any)cloned[1].data)^
    c_inner_03 := (transmute(^[]any)c_inner_04[1].data)^
    c_inner_02 := (transmute(^[]any)c_inner_03[1].data)^
    c_inner_01 := (transmute(^[]any)c_inner_02[1].data)^
    c_inner_00 := (transmute(^[]any)c_inner_01[1].data)^
    print(c_inner_00) // [1, 2, 3]

    // So, how to update a value in c_inner_00? Like change 1 to 100 so it looks like this:
    // [1, 2, 3] --> [100, 2, 3]
    
    // Attempt 01: the direct approach. doesn't work
    // c_inner_00[0] = 100 // <--- causes `bad free` 
    // Bad free of pointer 532187508760 Illegal instruction

    // Attempt 02: this doesn't work either
    // (c_inner_00[0].data)^ = 100 // Cannot dereference '(c_inner_00[0].data)' of type 'rawptr'(checker)
    // The compiler won't let you dereference a `rawptr` (which is what .data is) 
    // since it doesn't know how much space to READ FROM or WRITE TO.

    // Attempt 03: To change the value, you have to get the `rawptr` in `<whatever you want>.data` and then
    // cast() or transmute() it to a pointer of what you want  (e.g.: ^int)
    // 1. Get the pointer to the actual data inside the 'any'
    val_ptr := transmute(^int)c_inner_00[0].data
    // 2. Change the value at that address (No new allocation needed!)
    val_ptr^ = 100

    // Hurray! Now it works. :)

    // Repeat for the others
    // You can cast() it or transmute() it. Both work.
    (cast(^int)c_inner_00[1].data)^ = 200
    (transmute(^int)c_inner_00[2].data)^ = 300

    // now the innermost []any has been updated: [1, 2, 3] --> [100, 200, 300]
    print(c_inner_00) // [100, 200, 300]
    print("-------------------------------------------\n")

    print("---- `source` and `cloned` after updates ----")
    print("\n source:", source)
    print("\n cloned:", cloned)
    print("")

    diff_result := !deep_equal(source, cloned)
    print("Test 2 (Independence):", diff_result ? "PASSED" : "FAILED")
    
    if source[0].(Person).name == "Alice" {
        print("Test 3 (Source Integrity): PASSED - Source name remains 'Alice'")
    } else {
        print("Test 3 (Source Integrity): FAILED - Source name was overwritten!")
    }

    // // 5. Test: Robust Slice Handler ([]int inside 'any')
    // // Let's create two identical 'any' wrappers containing []int
    arr_a := []int{10, 20, 30}
    arr_b := []int{10, 20, 30}
    any_a: any = arr_a
    any_b: any = arr_b
    
    slice_eq := deep_equal(any_a, any_b)
    print("Test 4 (Robust []int Comparison):", slice_eq ? "PASSED" : "FAILED")

    print("--- TEST SUITE COMPLETE ---\n")
}

/*
$ cd 'C:\Users\mikec\Visual Studio Code' && odin run .
Hello from Odin!
--- STARTING DEEP LIBRARIES TEST SUITE ---
Action: Deep Copying source...
Test 1 (Equality): PASSED
Action: Modifying clone...
---- The Addresses of both `source` and `cloned` ----
Source Data Ptr: 0x858A9CEFE0
Clone Data Ptr:  0x1B37389AF08

 source: [Person{name = "Alice", age = 30, Friends = ["Bob", "Charlie"], address = Address{street = "123 Main St", city = "Springfield", state = "IL", zip = 62704, is_work = false}}, ["apple", [true, [4.5678, [5, [1, 2, 3]]]]]]

 cloned: [Person{name = "Malice", age = 300, Friends = ["Bob", "Charlie"], address = Address{street = "123 Main St", city = "Springfield", state = "IL", zip = 62704, is_work = false}}, ["apple", [true, [4.5678, [5, [1, 2, 3]]]]]]

-------------------------------------------
[1, 2, 3]
[100, 200, 300]
-------------------------------------------

---- `source` and `cloned` after updates ----

 source: [Person{name = "Alice", age = 30, Friends = ["Bob", "Charlie"], address = Address{street = "123 Main St", city = "Springfield", state = "IL", zip = 62704, is_work = false}}, ["apple", [true, [4.5678, [5, [1, 2, 3]]]]]]

 cloned: [Person{name = "Malice", age = 300, Friends = ["Bob", "Charlie"], address = Address{street = "123 Main St", city = "Springfield", state = "IL", zip = 62704, is_work = false}}, ["apple", [true, [4.5678, [5, [100, 200, 300]]]]]]

Test 2 (Independence): PASSED
Test 3 (Source Integrity): PASSED - Source name remains 'Alice'
Test 4 (Robust []int Comparison): PASSED
--- TEST SUITE COMPLETE ---

---- ENTERING deep_free_slice() -----
---- ENTERING deep_free_any() -----
---- ENTERING deep_free_Person() -----
---- ENTERING deep_free_slice() -----
---- ENTERING deep_free_string() -----
---- ENTERING deep_free_string() -----
---- ENTERING deep_free_Address() -----
---- ENTERING deep_free_any() -----
---- ENTERING deep_free_slice() -----
---- ENTERING deep_free_any() -----
---- ENTERING deep_free_any() -----
---- ENTERING deep_free_slice() -----
---- ENTERING deep_free_any() -----
---- ENTERING deep_free_any() -----
---- ENTERING deep_free_slice() -----
---- ENTERING deep_free_any() -----
---- ENTERING deep_free_any() -----
---- ENTERING deep_free_slice() -----
---- ENTERING deep_free_any() -----
---- ENTERING deep_free_any() -----
---- ENTERING deep_free_slice() -----
---- ENTERING deep_free_any() -----
---- ENTERING deep_free_any() -----
---- ENTERING deep_free_any() -----
Odin took: 1.7192ms
*/
