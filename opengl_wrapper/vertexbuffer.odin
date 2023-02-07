package Wrapper

import "core:fmt"
import "core:math"
import gl "vendor:OpenGL"

VertexBuffer_t::struct {
    vbo:u32,
}
VertexBufferBind::proc(vbo:^VertexBuffer_t) {
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo^.vbo)
}
VertexBufferUnbind::proc(mesh:^VertexBuffer_t) {
    gl.BindBuffer(gl.ARRAY_BUFFER, 0)
}
VertexBufferDelete::proc(vbo:^VertexBuffer_t) {
    gl.DeleteBuffers(1, &vbo^.vbo)
}
VertexBufferCreate::proc(vertexBufferData:rawptr, size:int) -> VertexBuffer_t {
    vbo := VertexBuffer_t{}
    gl.GenBuffers(1, &vbo.vbo)
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo.vbo)
    //(target: u32, size: int, data: rawptr, usage: u32)
    gl.BufferData(gl.ARRAY_BUFFER, size, vertexBufferData, gl.STATIC_DRAW)
    return vbo
}
