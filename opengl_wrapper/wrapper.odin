package Wrapper

import "core:fmt"
import "core:math"
import gl "vendor:OpenGL"
import glsl "core:math/linalg/glsl"

Mesh_t::struct {
    vbo:VertexBuffer_t,
    triangles:i32,
    worldTransform:glsl.mat4,
}

MeshCreate::proc(vbo:VertexBuffer_t) -> Mesh_t {
    mesh := Mesh_t{}
    mesh.vbo = vbo
    return mesh
}

MeshDelete::proc(m:^Mesh_t) {
    VertexBufferDelete(&m.vbo)
}

MeshDraw::proc(m:^Mesh_t, program:u32) {
    VertexBufferBind( &m.vbo )
    BindAttributes()
    //gl.DrawElements(gl.TRIANGLES, draw_elements, gl.UNSIGNED_SHORT, nil);
    gl.DrawArrays(gl.TRIANGLES, 0, m^.triangles)
}

//ibo:u32
    //gl.GenBuffers(1, &ibo)
    //gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ibo);
    //gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(cube_indices), &cube_indices[0], gl.STATIC_DRAW);

CheckAttributes::proc(program:u32) {
    attributeMap := map[cstring]int{
        "vertexPosition" = 0,
        "vertexNormal" = 0,
        "vertexColor" = 0,
        "vertexTexcoord" = 0,
    }
    for k,v in attributeMap {
        loc := gl.GetAttribLocation(program, k)
        if loc == -1 do fmt.println("Attribute", k, " doesnt exist or has been optimized away, loc:", loc)
    }
}

BindAttributes::proc() {
    gl.VertexAttribPointer(0, 3, gl.FLOAT, false, size_of(vertex_format_t), cast(uintptr)offset_of(vertex_format_t, position)) 
    gl.EnableVertexAttribArray(0)    
    gl.VertexAttribPointer(1, 3, gl.FLOAT, false, size_of(vertex_format_t),  cast(uintptr)offset_of(vertex_format_t, normal)) 
    gl.EnableVertexAttribArray(1)
    gl.VertexAttribPointer(2, 3, gl.FLOAT, false, size_of(vertex_format_t),  cast(uintptr)offset_of(vertex_format_t, color))
    gl.EnableVertexAttribArray(2)
    gl.VertexAttribPointer(3, 2, gl.FLOAT, false, size_of(vertex_format_t),  cast(uintptr)offset_of(vertex_format_t, texcoord) )
    gl.EnableVertexAttribArray(3)    
}
