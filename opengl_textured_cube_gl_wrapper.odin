package glfw_window

import "core:fmt"
import "vendor:glfw"
import gl "vendor:OpenGL"
import linalg "core:math/linalg"
import glsl "core:math/linalg/glsl"
import Wrapper "opengl_wrapper"

WIDTH  	:: 640
HEIGHT 	:: 480
TITLE 	:: "OpenGL with Odin"

// @note You might need to lower this to 3.3 depending on how old your graphics card is.
GL_MAJOR_VERSION :: 3
GL_MINOR_VERSION :: 3

time:f64 = 0
texHandle:u32 = 0

main :: proc() {
    using glsl

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

    program, ok := setup_shaders()
    if !ok {
        msg, shader_type := gl.get_last_error_message()
        fmt.printf("Shader program creation error! %s %v\n", msg, shader_type )
        return
    }
    Wrapper.CheckAttributes(program)

    if err := gl.GetError(); err != gl.NO_ERROR
    {
        fmt.eprintln("gl error", err)
        return 
    }
    
    cube := Wrapper.createCube()
    sphere := Wrapper.createSphere()

    sphere2 := Wrapper.MeshCreate( sphere.vbo )
    sphere2.triangles = sphere.triangles

    defer Wrapper.MeshDelete(&cube)
    defer Wrapper.MeshDelete(&sphere)
    defer gl.DeleteProgram(program)
    meshList:[dynamic]^Wrapper.Mesh_t
    append(&meshList, &cube)
    append(&meshList, &sphere)
    append(&meshList, &sphere2)

    texHandle = setup_texture()
    defer gl.DeleteTextures(1, &texHandle)

    if err := gl.GetError(); err != gl.NO_ERROR
    {
        fmt.eprintln("After setup gl error", err)
    }    

    oldtime :f64= 0.0
    nframes := 0
    seconds :f64= 0.0
    found_error := false

    sphere2_position:vec3 = vec3{-1.5,1,4}
    sphere2_vel:vec3 = vec3{10,10,10}

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

        cube.worldTransform = 
          mat4Translate(vec3{1.5,0,0}) * 
          mat4Rotate( vec3{0,1,1}, radians_f32( 90.0 * f32(time) ) )
        
        sphere.worldTransform = 
           mat4Translate(vec3{-1.5,0,0}) * 
           mat4Rotate( vec3{1,1,0}, radians_f32( 90.0 * f32(time) ) )

        sphere2_position += f32(dt) * sphere2_vel
        if sphere2_position.x < -5 do sphere2_vel.x *= -1
        if sphere2_position.y < -5 do sphere2_vel.y *= -1
        if sphere2_position.z < -5 do sphere2_vel.z *= -1

        if sphere2_position.x > 5 do sphere2_vel.x *= -1
        if sphere2_position.y > 5 do sphere2_vel.y *= -1
        if sphere2_position.z > 5 do sphere2_vel.z *= -1

        sphere2.worldTransform = 
           mat4Translate( sphere2_position ) * 
           mat4Rotate( vec3{1,1,1}, radians_f32( 180.0 * f32(time) ) )

        render_frame(program, meshList)
        
        if err := gl.GetError(); err != gl.NO_ERROR && !found_error
        {
            found_error = true
            fmt.eprintln("GLerror %d", err)
        }
        
		glfw.SwapBuffers(window_handle)
        nframes += 1
	}
}

setup_shaders::proc() -> (u32, bool) {
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
        FragColor = .1*vs_color + base/**vs_color*/*diffuse + spec*vec4(1.0); 
    }
    void main()
    {
        polycube();
        //vec4 base = vec4( texture2D(tex0, 1.0 * t.xy + 0.125).rgb, 1.0 );
        //FragColor = .7*base + (.3*vs_color) + .01*t.x + .01*n.x;
    }`    
    // shaders
    return gl.load_shaders_source(vs_source, fs_source)
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

render_frame::proc( program:u32, meshPointerList:[dynamic]^Wrapper.Mesh_t ) {
    using glsl
    gl.Viewport(0, 0, WIDTH, HEIGHT);
    //gl.FrontFace(gl.CW) // CCW is default
    gl.Enable(gl.CULL_FACE)
    gl.CullFace(gl.BACK)
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

    // Get a handle for our "MVP" uniform
    // Only needed during the initialisation
    uMV := gl.GetUniformLocation(program, "MV")
    uMVP := gl.GetUniformLocation(program, "MVP")
    uNormalMtx := gl.GetUniformLocation(program, "normalMatrix")
    // Send our transformation to the currently bound shader, in the "MVP" uniform
    // This is done in the main loop since each model will have a different MVP matrix (At least for the M part)
    gl.UseProgram(program)

    gl.ActiveTexture(gl.TEXTURE0);
    gl.BindTexture(gl.TEXTURE_2D, texHandle);
    samplerID := gl.GetUniformLocation(program, "tex0");
    gl.Uniform1i(samplerID, 0);

    count := 0
    for meshptr in meshPointerList {
        mesh := meshptr^

        Model:mat4 = mesh.worldTransform
        mv:mat4 = View * Model
        mvp:mat4 = Projection * View * Model; // Remember, matrix multiplication is the other way around
        normalMtx := transpose( inverse( mat3(Model) ) )

        gl.UniformMatrix4fv(uMV, 1, gl.FALSE, &mv[0][0]);
        gl.UniformMatrix4fv(uMVP, 1, gl.FALSE, &mvp[0][0]);
        gl.UniformMatrix3fv(uNormalMtx, 1, gl.FALSE, &normalMtx[0][0]);
    
        Wrapper.MeshDraw( meshptr, program )
    }
}