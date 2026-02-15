uniform vec4 u_OutlineColor;
varying vec2 v_TexCoord;
uniform sampler2D u_Tex0;
uniform vec2 u_TextureSize;

void main()
{
    vec4 texColor = texture2D(u_Tex0, v_TexCoord);
    
    // If this pixel is transparent, check if any neighbor is opaque (edge detection)
    if(texColor.a < 0.1) {
        float pixelSize = 1.0 / 32.0; // Item sprites are typically 32x32
        
        // Sample neighboring pixels in 8 directions
        float edge = 0.0;
        edge += texture2D(u_Tex0, v_TexCoord + vec2(-pixelSize, 0.0)).a;
        edge += texture2D(u_Tex0, v_TexCoord + vec2(pixelSize, 0.0)).a;
        edge += texture2D(u_Tex0, v_TexCoord + vec2(0.0, -pixelSize)).a;
        edge += texture2D(u_Tex0, v_TexCoord + vec2(0.0, pixelSize)).a;
        edge += texture2D(u_Tex0, v_TexCoord + vec2(-pixelSize, -pixelSize)).a;
        edge += texture2D(u_Tex0, v_TexCoord + vec2(pixelSize, -pixelSize)).a;
        edge += texture2D(u_Tex0, v_TexCoord + vec2(-pixelSize, pixelSize)).a;
        edge += texture2D(u_Tex0, v_TexCoord + vec2(pixelSize, pixelSize)).a;
        
        // If any neighbor is opaque, this is an outline pixel
        if(edge > 0.1) {
            gl_FragColor = u_OutlineColor;
        } else {
            discard;
        }
    } else {
        // Draw the item normally
        gl_FragColor = texColor;
    }
}
