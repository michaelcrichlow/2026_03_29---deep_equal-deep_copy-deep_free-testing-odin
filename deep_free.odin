package test

import "core:mem"
import "core:strings"
import "core:encoding/json"
import "base:intrinsics"
import "base:runtime"

// deep_free :: proc {
//     deep_free_any,
//     deep_free_string,
//     deep_free_basic,
//     deep_free_slice,
//     deep_free_array,
//     deep_free_map,
//     deep_free_Group,
//     // deep_free_Value,
//     deep_free_Address,
//     deep_free_Person,
// }

deep_free :: proc {
    deep_free_any,     // Must be first
    deep_free_Person,  // Move these up
    deep_free_Address,
    deep_free_Group,
    deep_free_slice,
    deep_free_string,
    deep_free_array,
    deep_free_map,
    deep_free_basic,   // Must be last
}

// 0. Strings
deep_free_string :: proc(val: string, allocator := context.allocator) {
    print("---- ENTERING deep_free_string() -----")
    if len(val) > 0 {
        delete(val, allocator)
    }
}

// 1. Basic Types - Only for things that DON'T need freeing
// deep_free_basic :: proc(val: $T, allocator := context.allocator) 
//     where !intrinsics.type_is_slice(T) && 
//           !intrinsics.type_is_map(T)   && 
//           !intrinsics.type_is_array(T) && 
//           T != string && 
//           T != any && 
//           T != Address && 
//           T != Person {
//     // Do nothing. Ints, bools, and runes don't have heap memory.
//     print("---- ENTERING deep_free_basic() -----")
// }

// 1. Basic Types - The "Whitelist" approach
deep_free_basic :: proc(val: $T, allocator := context.allocator) 
    where intrinsics.type_is_numeric(T) || 
          intrinsics.type_is_boolean(T) || 
          intrinsics.type_is_enum(T)    ||
          T == rune { 
    // fmt.println("---- ENTERING deep_free_basic() -----")
    // Do nothing. These never have heap memory.
}

// 2. Slices
deep_free_slice :: proc(val: []$T, allocator := context.allocator) {
    print("---- ENTERING deep_free_slice() -----")
    for elem in val {
        deep_free(elem, allocator)
    }
    delete(val, allocator)
}

// 3. Arrays
deep_free_array :: proc(val: [$N]$T, allocator := context.allocator) {
    print("---- ENTERING deep_free_array() -----")
    for i in 0 ..< N {
        deep_free(val[i], allocator)
    }
}

// 4. Maps
deep_free_map :: proc(val: map[$K]$V, allocator := context.allocator) {
    print("---- ENTERING deep_free_map() -----")
    for k, v in val {
        deep_free(k, allocator)
        deep_free(v, allocator)
    }
    delete(val) // Maps in Odin track their own allocator
}

// 5. Group
deep_free_Group :: proc(val: Group, allocator := context.allocator) {
    print("---- ENTERING deep_free_Group() -----")
    deep_free(val.members, allocator)
}

// 6. Address
deep_free_Address :: proc(val: Address, allocator := context.allocator) {
    print("---- ENTERING deep_free_Address() -----")
    delete(val.street, allocator)
    delete(val.city, allocator)
    delete(val.state, allocator)
}

// 7. Person
deep_free_Person :: proc(val: Person, allocator := context.allocator) {
    print("---- ENTERING deep_free_Person() -----")
    delete(val.name, allocator) // this line threw an error. this is line 77
    deep_free(val.Friends, allocator)
    deep_free(val.address, allocator)
}

// this one is not working yet...
// 8. JSON Value
// deep_free_Value :: proc(val: json.Value, allocator := context.allocator) {
//     #partial switch v in val {
//     case json.String:
//         delete(v, allocator)
//     case json.Array:
//         for elem in v {
//             deep_free_Value(elem, allocator)
//         }
//         // Cast to base slice type so 'delete' works
//         delete([]json.Value(v), allocator)
//     case json.Object:
//         for key, value in v {
//             delete(key, allocator)
//             deep_free_Value(value, allocator)
//         }
//         // Cast to base map type so 'delete' works
//         delete(map[string]json.Value(v))
//     case: 
//         return
//     }
// }

deep_free_any :: proc(val: any, allocator := context.allocator) {
    print("---- ENTERING deep_free_any() -----")
    if val.data == nil || val.id == nil do return

    ti := type_info_of(val.id)
    // rest of code...

    switch val.id {
    case string:
        ptr := transmute(^string)val.data
        delete(ptr^, allocator)
        
    case []any:
        ptr := transmute(^[]any)val.data
        deep_free_slice(ptr^, allocator)

    case Person:
        ptr := transmute(^Person)val.data
        deep_free_Person(ptr^, allocator)

    case Address:
        ptr := transmute(^Address)val.data
        deep_free_Address(ptr^, allocator)

    case:
        // Robust Catch-all for other slice types
        #partial switch variant in ti.variant {
        case runtime.Type_Info_Slice:
            raw_val := (transmute(^runtime.Raw_Slice)val.data)^
            if raw_val.data == nil do break
            
            elem_ti := variant.elem
            // Free individual elements if they have heap data
            for i in 0..<raw_val.len {
                elem_ptr := rawptr(uintptr(raw_val.data) + uintptr(i * elem_ti.size))
                deep_free(any{elem_ptr, elem_ti.id}, allocator)
            }
            // Free the slice buffer itself
            mem.free(raw_val.data, allocator)
        }
    }

    // Finally, free the memory block that was allocated for the value itself
    mem.free(val.data, allocator)
}