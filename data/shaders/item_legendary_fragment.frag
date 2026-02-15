varying vec2 v_TexCoord;
uniform sampler2D u_Tex0;

void main()
{
    vec4 texColor = texture2D(u_Tex0, v_TexCoord);
    
    // If this pixel is transparent, check if any neighbor is opaque (edge detection)
    if(texColor.a < 0.1) {
        float pixelSize = 1.0 / 32.0;
        
        float edge = 0.0;
        edge += texture2D(u_Tex0, v_TexCoord + vec2(-pixelSize, 0.0)).a;
        edge += texture2D(u_Tex0, v_TexCoord + vec2(pixelSize, 0.0)).a;
        edge += texture2D(u_Tex0, v_TexCoord + vec2(0.0, -pixelSize)).a;
        edge += texture2D(u_Tex0, v_TexCoord + vec2(0.0, pixelSize)).a;
        edge += texture2D(u_Tex0, v_TexCoord + vec2(-pixelSize, -pixelSize)).a;
        edge += texture2D(u_Tex0, v_TexCoord + vec2(pixelSize, -pixelSize)).a;
        edge += texture2D(u_Tex0, v_TexCoord + vec2(-pixelSize, pixelSize)).a;
        edge += texture2D(u_Tex0, v_TexCoord + vec2(pixelSize, pixelSize)).a;
        
        if(edge > 0.1) {
            // Gold outline for legendary items (RGB: 255, 200, 0)
            gl_FragColor = vec4(1.0, 0.784, 0.0, 1.0);
        } else {
            discard;
        }
    } else {
        gl_FragColor = texColor;
    }
}
