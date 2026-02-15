varying vec2 v_TexCoord;
uniform sampler2D u_Tex0;

void main()
{
    vec4 texColor = texture2D(u_Tex0, v_TexCoord);

    // Solid-color mask for outline pass (draw only where the sprite is opaque)
    if (texColor.a > 0.1) {
        // Gold outline for legendary items (RGB: 255, 200, 0)
        gl_FragColor = vec4(1.0, 0.784, 0.0, texColor.a);
    } else {
        discard;
    }
}
