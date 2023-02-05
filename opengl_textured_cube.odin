package glfw_window

import "core:fmt"
import "vendor:glfw"
import gl "vendor:OpenGL"
import linalg "core:math/linalg"
import glsl "core:math/linalg/glsl"

WIDTH  	:: 640
HEIGHT 	:: 480
TITLE 	:: "OpenGL with Odin"

// @note You might need to lower this to 3.3 depending on how old your graphics card is.
GL_MAJOR_VERSION :: 3
GL_MINOR_VERSION :: 3

program :u32= 0
time:f64 = 0
draw_elements :i32= 0
texHandle:u32 = 0

main :: proc() {
	if !bool(glfw.Init()) {
		fmt.eprintln("GLFW has failed to load.")
		return
	}
	window_handle := glfw.CreateWindow(width=WIDTH, height=HEIGHT, title=TITLE, monitor=nil, share=nil)

	defer glfw.Terminate()
	defer glfw.DestroyWindow(window_handle)

	if window_handle == nil {
		fmt.eprintln("GLFW has failed to load the window.")
		return
	}

	// Load OpenGL context or the "state" of OpenGL.
	glfw.MakeContextCurrent(window_handle)
	// Load OpenGL function pointers with the specficed OpenGL major and minor version.
	gl.load_up_to(GL_MAJOR_VERSION, GL_MINOR_VERSION, glfw.gl_set_proc_address)

    if !setup_shaders() {
        fmt.eprintln("failed to setup shaders")
        return
    }
    err := gl.GetError()
    if (err != gl.NO_ERROR)
    {
        fmt.eprintln("gl error", err)
        return 
    }
    setup_frame()

    texHandle = setup_texture()

    err = gl.GetError()
    if (err != gl.NO_ERROR)
    {
        fmt.eprintln("After setup gl error", err)
    }    

    oldtime :f64= 0.0
    nframes := 0
    seconds :f64= 0.0
    found_error := false

	for !glfw.WindowShouldClose(window_handle) {
		// Process all incoming events like keyboard press, window resize, and etc.
		glfw.PollEvents()
        time = glfw.GetTime()
        dt := time - oldtime
        seconds += dt
        oldtime = time
        if (seconds >= 5.0)
        {
            seconds = 0
            fmt.println("fps:", nframes / 5.0)
            nframes = 0
        }

        render_frame()
        err := gl.GetError()
        if (err != gl.NO_ERROR && !found_error)
        {
            found_error = true
            fmt.eprintln("GLerror %d", err)
        }
        
		glfw.SwapBuffers(window_handle)
        nframes += 1
	}
}

setup_shaders::proc() -> bool {
vs_source :: `
    #version 330 core
    layout(location = 0) in vec3 vertexPosition;
    layout(location = 1) in vec3 vertexNormal;
    layout(location = 2) in vec3 vertexColor;
    layout(location = 3) in vec2 vertexTexcoord;
    
    // Values that stay constant for the whole mesh.
    uniform mat4 MV;
    uniform mat4 MVP;
    uniform mat3 normalMatrix;
    out vec4 vs_color;
    out vec3 n;
    out vec4 p;
    out vec2 t;
    
    void main(){
    // Output position of the vertex, in clip space : MVP * position
    vs_color = vec4( vertexColor, 1.0 );
    n = normalMatrix * vertexNormal;
    t = vertexTexcoord;
    p = MV * vec4(vertexPosition, 1.0);
    gl_Position =  MVP * vec4(vertexPosition, 1.0);
    }    
    `

fs_source :: `
    #version 330 core
    uniform sampler2D tex0;
    in vec4 vs_color;
    in vec3 n;
    in vec2 t;
    in vec4 p;
    out vec4 FragColor;

    void polycube()
    {
        vec4 base = texture2D(tex0, t.xy+.125);
        vec3 light_pos = vec3(-5.0,0.0,0.0);
        vec3 light_dir = light_pos - p.xyz;
        float dist = dot(light_dir, light_dir);
        light_dir *= inversesqrt(dist);
        vec3 norm = normalize(n);
        float diffuse = 0.2 + max(0.0, dot(norm, light_dir))*(24.0/dist);
        float spec = max(0.0,dot(reflect(light_dir,norm),normalize(p.xyz)));
        spec = pow(spec, 16.0)*.25;
        //vec4 debug = vec4(vec3(0.5)+.5*norm, 1.0);
        FragColor = base/**vs_color*/*diffuse + spec*vec4(1.0); 
    }
    void main()
    {
        polycube();
        //vec4 base = vec4( texture2D(tex0, 1.0 * t.xy + 0.125).rgb, 1.0 );
        //FragColor = .7*base + (.3*vs_color) + .01*t.x + .01*n.x;
    }`    
    // shaders
    prog_handle, ok := gl.load_shaders_source(vs_source, fs_source) 
    program = prog_handle
    if !ok {
        msg, shader_type := gl.get_last_error_message()
        fmt.printf("Shader program creation error! %s %v\n", msg, shader_type )
        return false
    }
    return true
}

setup_texture::proc(/*const char *filename*/) -> u32 {
    width :: 4
    height :: width
    components :: 3
    
    rgb::struct {r:u8,g:u8,b:u8,}
    pixels : [width*height]rgb
    //int width, height;
    //void *pixels = read_tga(filename, &width, &height);
    // write checker pattern

    for y in 0 ..< height {
        for x in 0 ..<width {
            // white
            color := rgb{255,255,255}
            if ( (x+y)%2==0 ) do color = rgb{127,127,127}

            if ( x==1 && y==1 ) do color = rgb{255,127,127}
            if ( x==3 && y==1 ) do color = rgb{127,255,127}
            if ( x==1 && y==3 ) do color = rgb{127,255,127}
            if ( x==2 && y==2 ) do color = rgb{127,127,255}
            if ( x==3 && y==3 ) do color = rgb{255,127,127}
            pixels[y*width+x] = color
        }
    }

    texture:u32

    //if (!pixels)
        //return 0;

    gl.GenTextures(1, &texture)
    gl.BindTexture(gl.TEXTURE_2D, texture)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S,     gl.REPEAT/*gl.CLAMP_TO_EDGE*/)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T,     gl.REPEAT/*gl.CLAMP_TO_EDGE*/)
    gl.TexImage2D(
        gl.TEXTURE_2D, 0,           /* target, level */
        gl.RGB8,                    /* internal format */
        width, height, 0,           /* width, height, border */
        gl.RGB/*gl.BGR*/, gl.UNSIGNED_BYTE,   /* external format, type */
        &pixels)
    //free(pixels);
    return texture
}

setup_frame::proc() {
    // Setup A struct so its more convenient to type the array literals
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
    assert( size_of(vec2) == 2*4 )
    assert( size_of(vec3) == 3*4 )
    assert( size_of(vertex_format_t) == 44 )
    assert( offset_of(vertex_format_t, position) == 0 )
    assert( offset_of(vertex_format_t, normal) == 3*size_of(f32) )
    assert( offset_of(vertex_format_t, color) == (2*3*size_of(f32)) )
    assert( offset_of(vertex_format_t, texcoord) == (3*3*size_of(f32)) )

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
    draw_elements = 36

    for i:=0; i<36; i+=1 
    {
        vertexBuffer[i].position = cube_vertices[ cube_indices[i] ]
        face := i/6
        vertexBuffer[i].normal = cube_normals[face]
        vertexBuffer[i].color = cube_colors[face]
        vertexBuffer[i].texcoord = cube_texcoords[ texInds[i%6] ]
    }

    vbo :u32
    gl.GenBuffers(1, &vbo)
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(vertexBuffer), &vertexBuffer, gl.STATIC_DRAW)

    attributeMap := map[cstring]int{
        "vertexPosition" = 0,
        "vertexNormal" = 0,
        "vertexColor" = 0,
        "vertexTexcoord" = 0}
    for k,v in attributeMap {
        loc := gl.GetAttribLocation(program, k)
        if loc == -1 do fmt.println("Attribute", k, " doesnt exist or has been optimized away, loc:", loc)
    }
    
    gl.EnableVertexAttribArray(0)
    gl.VertexAttribPointer(0, 3, gl.FLOAT, false, size_of(vertex_format_t), cast(uintptr)0 )//offset_of(vertex_format_t, position) ) 

    gl.EnableVertexAttribArray(1)
    gl.VertexAttribPointer(1, 3, gl.FLOAT, false, size_of(vertex_format_t),  cast(uintptr)offset_of(vertex_format_t, normal)) 

    gl.EnableVertexAttribArray(2)
    gl.VertexAttribPointer(2, 3, gl.FLOAT, false, size_of(vertex_format_t),  cast(uintptr)offset_of(vertex_format_t, color))

    gl.EnableVertexAttribArray(3)
    gl.VertexAttribPointer(3, 2, gl.FLOAT, false, size_of(vertex_format_t),  cast(uintptr)offset_of(vertex_format_t, texcoord) )

    //ibo:u32
    //gl.GenBuffers(1, &ibo)
    //gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ibo);
    //gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(cube_indices), &cube_indices[0], gl.STATIC_DRAW);
}

render_frame::proc() {
    using glsl
    gl.Disable(gl.CULL_FACE)
    gl.ClearColor(0.5, 0.0, 1.0, 1.0)
    gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT | gl.STENCIL_BUFFER_BIT )

    // Enable depth test
    gl.Enable(gl.DEPTH_TEST);
    // Accept fragment if it closer to the camera than the former one
    gl.DepthFunc(gl.LESS);

    // mat4Perspective :: proc "c" (fovy, aspect, near, far: f32)
    Projection := mat4Perspective( radians_f32(60.0), WIDTH / f32(HEIGHT), 0.1, 1000.0 )
    //mat4LookAt :: proc "c" (eye, centre, up: vec3) -> (m: mat4) {
    View := mat4LookAt(
        vec3{0,0,-4}, // Camera is at (4,3,3), in World Space
        vec3{0,0,0}, // and looks at the origin
        vec3{0,1,0},  // Head is up (set to 0,-1,0 to look upside-down)
    )

    // Model matrix : an identity matrix (model will be at the origin)
    Model:mat4 = mat4(1.0)
    Model = mat4Rotate( vec3{1,1,0}, radians_f32( 90.0 * f32(time) ) )
    mv:mat4 = View * Model
    mvp:mat4 = Projection * View * Model; // Remember, matrix multiplication is the other way around
    normalMtx := transpose( inverse( mat3(Model) ) )
    // Get a handle for our "MVP" uniform
    // Only during the initialisation
    uMV := gl.GetUniformLocation(program, "MV");
    uMVP := gl.GetUniformLocation(program, "MVP");
    uNormalMtx := gl.GetUniformLocation(program, "normalMatrix");
    // Send our transformation to the currently bound shader, in the "MVP" uniform
    // This is done in the main loop since each model will have a different MVP matrix (At least for the M part)
    gl.EnableVertexAttribArray(0)    
    gl.EnableVertexAttribArray(1)
    gl.EnableVertexAttribArray(2)
    gl.EnableVertexAttribArray(3)
    gl.UseProgram(program)

    gl.ActiveTexture(gl.TEXTURE0);
    gl.BindTexture(gl.TEXTURE_2D, texHandle);
    samplerID := gl.GetUniformLocation(program, "tex0");
    gl.Uniform1i(samplerID, 0);

    gl.UniformMatrix4fv(uMV, 1, gl.FALSE, &mv[0][0]);
    gl.UniformMatrix4fv(uMVP, 1, gl.FALSE, &mvp[0][0]);
    gl.UniformMatrix3fv(uNormalMtx, 1, gl.FALSE, &normalMtx[0][0]);
    //gl.DrawElements(gl.TRIANGLES, draw_elements, gl.UNSIGNED_SHORT, nil);
    gl.DrawArrays(gl.TRIANGLES, 0, 36)
}