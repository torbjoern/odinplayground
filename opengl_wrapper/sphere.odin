package Wrapper

import "core:fmt"
import "core:math"
import gl "vendor:OpenGL"
import glsl "core:math/linalg/glsl"

createSphere::proc() -> Mesh_t {
    sectorCount := 18
    stackCount := 36

    radius:f32 = 1.0
    x, y, z, xy : f32                              // vertex position
    nx, ny, nz : f32
    lengthInv := 1.0 / radius    // vertex normal

    using math
    sectorStep:f32 = 2.0 * f32(PI) / f32(sectorCount)
    stackStep:f32 = PI / f32(stackCount)
    sectorAngle, stackAngle : f32

    vertices:[dynamic]vec3
    normals:[dynamic]vec3
    texCoords:[dynamic]vec2

    for i:=0; i <= stackCount; i+=1 {
        stackAngle = PI / 2 - f32(i) * stackStep        // starting from pi/2 to -pi/2
        xy = radius * cos_f32(stackAngle)             // r * cos(u)
        z = radius * sin_f32(stackAngle)              // r * sin(u)

        // add (sectorCount+1) vertices per stack
        // the first and last vertices have same position and normal, but different tex coords
        for j := 0; j <= sectorCount; j+=1 {
            sectorAngle = f32(j) * sectorStep           // starting from 0 to 2pi

            // vertex position (x, y, z)
            x = xy * cos_f32(sectorAngle)             // r * cos(u) * cos(v)
            y = xy * sin_f32(sectorAngle)             // r * cos(u) * sin(v)
            append(&vertices, vec3{x,y,z})

            // normalized vertex normal (nx, ny, nz)
            nx = x * lengthInv
            ny = y * lengthInv
            nz = z * lengthInv
            append(&normals, vec3{nx,ny,nz})

            // vertex tex coord (s, t) range between [0, 1]
            s := f32(j) / f32(sectorCount)
            t := f32(i) / f32(stackCount)
            append(&texCoords, vec2{s, t})
        }
    }
        
    indices:[dynamic]int
    lineIndices:[dynamic]int

    for i:= 0; i < stackCount; i+=1 {
        k1 :int= i * (sectorCount + 1)
        k2 :int= k1 + sectorCount + 1

        for j:=0; j < sectorCount; j+=1 {
            // 2 triangles per sector excluding first and last stacks
            // k1 => k2 => k1+1
            if i != 0 {
                append(&indices, k1)
                append(&indices, k2)
                append(&indices, k1+1)
            }

            // k1+1 => k2 => k2+1
            if i != (stackCount-1) {
                append(&indices, k1+1)
                append(&indices, k2)
                append(&indices, k2+1)
            }

            // store indices for lines
            // vertical lines for all stacks, k1 => k2
            append(&lineIndices, k1)
            append(&lineIndices, k2)
            if i != 0  // horizontal lines except 1st stack, k1 => k+1
            {
                append(&lineIndices, k1)
                append(&lineIndices, k1 + 1)
            }

            k1 += 1
            k2 += 1
        }
    }

    vertexBuffer:[dynamic]vertex_format_t

    for i:=0; i<len(indices); i+=1 
    {
        vertex:vertex_format_t
        vertex.position = vertices[ indices[i] ]
        vertex.normal = normals[ indices[i] ]
        vertex.texcoord = texCoords[ indices[i] ]
        vertex.color = vec3{.8, .8, .8}
        append(&vertexBuffer, vertex)
    }

    vbo := VertexBufferCreate( &vertexBuffer[0], size_of(vertex_format_t) * len(vertexBuffer) )
    mesh := MeshCreate( vbo )
    mesh.triangles = i32( len(indices) )
    return mesh
}    
