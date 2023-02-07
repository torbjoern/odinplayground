package Wrapper

import "core:fmt"
import "core:math"
import gl "vendor:OpenGL"
import glsl "core:math/linalg/glsl"

createCube::proc() -> Mesh_t {
    cube_vertices := [8]vec3 {
        vec3{-1, -1, -1},
        vec3{1, -1, -1},
        vec3{1, 1, -1},
        vec3{-1, 1, -1},
        vec3{-1, -1, 1},
        vec3{1, -1, 1},
        vec3{1, 1, 1},
        vec3{-1, 1, 1},
    }
    cube_texcoords := [4]vec2 {
        vec2{0,0},
        vec2{1,0},
        vec2{1,1},
        vec2{0,1},
    }
    cube_normals := [6]vec3 {
        vec3{0,0,1},
        vec3{1,0,0},
        vec3{0,0,-1},
        vec3{-1,0,0},
        vec3{0,1,0},
        vec3{0,-1,0},
    }
    cube_colors := [6]vec3 {
        vec3{1,0,0},
        vec3{0,1,0},
        vec3{0,0,1},
        vec3{1,1,0},
        vec3{1,0,1},
        vec3{0,1,1},
    }
        
    texInds := [6]u16 { 0, 1, 3, 3, 1, 2 }

    cube_indices := [6 * 6] u16  {
        0, 1, 3, 3, 1, 2,
        1, 5, 2, 2, 5, 6,
        5, 4, 6, 6, 4, 7,
        4, 0, 7, 7, 0, 3,
        3, 2, 7, 7, 2, 6,
        4, 5, 0, 0, 5, 1,
    }

    vertexBuffer : [36]vertex_format_t = {}
    assert( 36*size_of(vertex_format_t) == size_of(vertexBuffer) )

    for i:=0; i<36; i+=1 
    {
        vertexBuffer[i].position = cube_vertices[ cube_indices[i] ]
        face := i/6
        vertexBuffer[i].normal = cube_normals[face]
        vertexBuffer[i].color = cube_colors[face]
        vertexBuffer[i].texcoord = cube_texcoords[ texInds[i%6] ]
    }
    // Swap winding, 0,1,2 -> 0,2,1
    for i:=0; i<36; i+=3 
    {
        vertexBuffer[i+0], vertexBuffer[i+2] = vertexBuffer[i+2], vertexBuffer[i+0] 
    }

    vbo := VertexBufferCreate( &vertexBuffer, size_of(vertexBuffer) )
    mesh := MeshCreate( vbo )
    mesh.triangles = 36 
    return mesh
}    