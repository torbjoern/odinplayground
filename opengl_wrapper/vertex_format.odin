package Wrapper

import "core:fmt"

// Setup a struct so its more convenient to type the array literals
vec2::struct {
    x:f32, y:f32,
}
vec3::struct {
    x:f32, y:f32, z:f32,
}
vertex_format_t::struct {
    position:vec3,
    normal:vec3,
    color:vec3,
    texcoord:vec2,
}
#assert( size_of(vec2) == 2*4 )
#assert( size_of(vec3) == 3*4 )
#assert( size_of(vertex_format_t) == 44 )
#assert( offset_of(vertex_format_t, position) == 0 )
#assert( offset_of(vertex_format_t, normal) == 3*size_of(f32) )
#assert( offset_of(vertex_format_t, color) == (2*3*size_of(f32)) )
#assert( offset_of(vertex_format_t, texcoord) == (3*3*size_of(f32)) )
