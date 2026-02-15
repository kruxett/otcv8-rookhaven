varying vec2 v_TexCoord;
uniform sampler2D u_Tex0;

void main()
{
    vec4 texColor = texture2D(u_Tex0, v_TexCoord);

    // Solid-color mask for outline pass (draw only where the sprite is opaque)
    if (texColor.a > 0.1) {
        // Blue outline for rare items (RGB: 0, 150, 255)
        gl_FragColor = vec4(0.0, 0.588, 1.0, texColor.a);
    } else {
        discard;
    }
}
