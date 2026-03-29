package test

// import "core:slice"
import "base:intrinsics"
import "core:encoding/json"
import "base:runtime"
// import "core:fmt"


// Convenience function that lists all functions defined in `useful_deep_equal_functions.odin`
show_deep_equal_functions :: proc() {
    print("============================================================================================================")
    print("██████╗ ███████╗███████╗██████╗     ███████╗ ██████╗ ██╗   ██╗ █████╗ ██╗     ")
    print("██╔══██╗██╔════╝██╔════╝██╔══██╗    ██╔════╝██╔═══██╗██║   ██║██╔══██╗██║     ")
    print("██║  ██║█████╗  █████╗  ██████╔╝    █████╗  ██║   ██║██║   ██║███████║██║     ")
    print("██║  ██║██╔══╝  ██╔══╝  ██╔═══╝     ██╔══╝  ██║▄▄ ██║██║   ██║██╔══██║██║     ")
    print("██████╔╝███████╗███████╗██║         ███████╗╚██████╔╝╚██████╔╝██║  ██║███████╗")
    print("╚═════╝ ╚══════╝╚══════╝╚═╝         ╚══════╝ ╚══▀▀═╝  ╚═════╝ ╚═╝  ╚═╝╚══════╝")
    print("============================================================================================================")
    print("---- deep_equal functions ----")
    print("============================================================================================================")
    print("Note: Prefer using the procedure group `deep_equal()`.")
    print("")
    print("deep_equal_basic(a, b)          -> compares base types using == (comparable types only)")
    print("deep_equal_slice(a, b)          -> compares slices element-by-element recursively")
    print("deep_equal_array(a, b)          -> compares arrays element-by-element recursively")
    print("deep_equal_map(a, b)            -> compares maps by keys and values recursively")
    print("deep_equal_Group(a, b)          -> compares Group struct members recursively")
    print("deep_equal_Value(a, b)          -> compares json.Value (Null, Integer, Float, Boolean, String, Array, Object)")
    print("deep_equal_Address(a, b)        -> compares Address struct fields directly")
    print("deep_equal_Person(a, b)         -> compares Person struct fields (name, age, Friends slice, nested Address)")
    // add more as needed to make deep_equal() as helpful as possible
    print("============================================================================================================")
}


from_string :: proc(s: string) -> map[string]int {
    local_map := make(map[string]int, context.temp_allocator)
    local_map["foo"] = 1

    return local_map
}

map_equal :: proc(a, b: map[$K]$V) -> bool {
    if len(a) != len(b) {
        return false
    }
    if len(a) == 0 {
        return true
    }

    when intrinsics.type_is_simple_compare(V) {
        // Fast path: just compare values directly
        for key, val_a in a {
            val_b, exists := b[key]
            if !exists || val_a != val_b {
                return false
            }
        }
    } else {
        // Fallback: use deep comparison
        for key, val_a in a {
            val_b, exists := b[key]
            if !exists || !deep_equal(val_a, val_b) {
                return false
            }
        }
    }

    return true
}


// has to be updated for structs as you make them
deep_equal :: proc {
    deep_equal_any,
    deep_equal_basic,
    deep_equal_slice,
    deep_equal_array,
    deep_equal_map,
    deep_equal_Group,
    deep_equal_Value,
    deep_equal_Address,
    deep_equal_Person,
}

// Base comparable types
deep_equal_basic :: proc(a, b: $T) -> bool where intrinsics.type_is_comparable(T) {
    // print("a, ", a, "b:", b)
    return a == b
}

// Slices
deep_equal_slice :: proc(a, b: []$T) -> bool {
    if len(a) != len(b) { return false }
    for i in 0 ..< len(a) {
        if !deep_equal(a[i], b[i]) { return false } // this line is the problem with the current approach. maybe it's an ambiguous call
    }
    return true
}

// Arrays
deep_equal_array :: proc(a, b: [$N]$T) -> bool {
    for i in 0..<N {
        if !deep_equal(a[i], b[i]) { return false }
    }
    return true
}

// Maps
deep_equal_map :: proc(a, b: map[$K]$V) -> bool {
    if len(a) != len(b) { return false }
    for k, va in a {
        vb, ok := b[k]
        if !ok { return false }
        if !deep_equal(va, vb) { return false }
    }
    return true
}

// ----------------------------------------------------------------------------------
// example struct to test equality
Group :: struct {
    members: []string,
}

// struct example
deep_equal_Group :: proc(a, b: Group) -> bool {
    for i in 0 ..< len(a.members) {
        if !deep_equal(a.members[i], b.members[i]) { return false }
    }
    return true
}
// ----------------------------------------------------------------------------------


// equality with union json.Value
deep_equal_Value :: proc(a, b: json.Value) -> bool {
    switch v1 in a {

    case json.Null:
        _, ok := b.(json.Null)
        return ok

    case json.Integer:
        v2, ok := b.(json.Integer)
        return ok && v1 == v2

    case json.Float:
        v2, ok := b.(json.Float)
        return ok && v1 == v2

    case json.Boolean:
        v2, ok := b.(json.Boolean)
        return ok && v1 == v2

    case json.String:
        v2, ok := b.(json.String)
        return ok && v1 == v2

    case json.Array:
        v2, ok := b.(json.Array)
        if !ok || len(v1) != len(v2) { return false }
        
        for i in 0 ..< len(v1) {
            if !deep_equal_Value(v1[i], v2[i]) { return false }
        }
        return true

    case json.Object:
        v2, ok := b.(json.Object)
        if !ok || len(v1) != len(v2) { return false } 
        
        for key, val1 in v1 {
            val2, exists := v2[key]
            if !exists || !deep_equal_Value(val1, val2) { return false } 
        }
        return true
    }

    return false
}

// ----------------------------------------------------------------------------------

// Example struct to show use case for testing equality
/*
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

    p2 := Person{
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

    print(deep_equal(p1, p2)) // true
*/

Person :: struct {
    name: string,
    age: int,
    Friends : []string,
    address: Address,
}

Address :: struct {
	street:  string,
	city:    string,
	state:   string,
	zip:     int,
	is_work: bool,
}


// Compare Address structs
deep_equal_Address :: proc(a, b: Address) -> bool {
    // all simple fields so can compare directly
    return a.street  == b.street &&
           a.city    == b.city   &&
           a.state   == b.state  &&
           a.zip     == b.zip    &&
           a.is_work == b.is_work
}

// Compare Person structs
deep_equal_Person :: proc(a, b: Person) -> bool {
    // Compare simple fields
    if a.name != b.name { return false }
    if a.age  != b.age  { return false }

    // Compare Friends slice
    if !deep_equal(a.Friends, b.Friends) {
        return false
    }

    // Compare nested Address
    if !deep_equal(a.address, b.address) {
        return false
    }

    return true
}

// ----------------------------------------------------------------------------------

// 2. Implementation of the any dispatcher
// deep_equal_any :: proc(a, b: any) -> bool {
//     // 1. Basic pointer and type checks
//     if a.id != b.id { return false }
//     if a.data == b.data { return true }
//     if a.data == nil || b.data == nil { return false }


//     // 2. Dispatch based on the Type ID
//     // We handle your specific Persona types and common primitives
//     // switch a.id {
//     // case int:    return a.data.(^int)^    == b.data.(^int)^
//     // case f64:    return a.data.(^f64)^    == b.data.(^f64)^
//     // case bool:   return a.data.(^bool)^   == b.data.(^bool)^
//     // case string: return a.data.(^string)^ == b.data.(^string)^

//     // case []any:
//     //     return deep_equal_slice(a.data.(^[]any)^, b.data.(^[]any)^)
        

//     // case Person:
//     //     return deep_equal_Person(a.data.(^Person)^, b.data.(^Person)^)

//     // case Address:
//     //     return deep_equal_Address(a.data.(^Address)^, b.data.(^Address)^)

//     // case Group:
//     //     return deep_equal_Group(a.data.(^Group)^, b.data.(^Group)^)

//     // // Add other slice types if you use them inside any, e.g.:
//     // // case []int: return deep_equal_slice(a.data.(^[]int)^, b.data.(^[]int)^)
//     // }

//     return false
// }

deep_equal_any :: proc(a, b: any) -> bool {
    // 1. Basic pointer and type checks
    if a.id == b.id && a.data == b.data { return true }
    if a.id != b.id { return false }
    if a.data == nil || b.data == nil { return false }

    // 2. Dispatch based on the Type ID using transmute
    switch a.id {
    case int:    return (transmute(^int)a.data)^    == (transmute(^int)b.data)^
    case f64:    return (transmute(^f64)a.data)^    == (transmute(^f64)b.data)^
    case bool:   return (transmute(^bool)a.data)^   == (transmute(^bool)b.data)^
    case string: return (transmute(^string)a.data)^ == (transmute(^string)b.data)^

    case []any:
        return deep_equal_slice((transmute(^[]any)a.data)^, (transmute(^[]any)b.data)^)

    case Person:
        return deep_equal_Person((transmute(^Person)a.data)^, (transmute(^Person)b.data)^)

    case Address:
        return deep_equal_Address((transmute(^Address)a.data)^, (transmute(^Address)b.data)^)

    case Group:
        return deep_equal_Group((transmute(^Group)a.data)^, (transmute(^Group)b.data)^)

    // 3. Robust Catch-all for other slice types (e.g., []int, []f32, etc.)
    case:
        ti := type_info_of(a.id)
        #partial switch variant in ti.variant {
        case runtime.Type_Info_Slice:
            raw_a := (transmute(^runtime.Raw_Slice)a.data)^
            raw_b := (transmute(^runtime.Raw_Slice)b.data)^

            if raw_a.len != raw_b.len { return false }
            
            elem_ti := variant.elem
            for i in 0..<raw_a.len {
                // Calculate memory offset for each element
                ptr_a := rawptr(uintptr(raw_a.data) + uintptr(i * elem_ti.size))
                ptr_b := rawptr(uintptr(raw_b.data) + uintptr(i * elem_ti.size))
                
                // Wrap elements back into 'any' to recurse back into deep_equal
                if !deep_equal(any{ptr_a, elem_ti.id}, any{ptr_b, elem_ti.id}) {
                    return false
                }
            }
            return true
        }
    }

    return false
}


