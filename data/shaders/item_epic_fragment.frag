varying vec2 v_TexCoord;
uniform sampler2D u_Tex0;

void main()
{
    vec4 texColor = texture2D(u_Tex0, v_TexCoord);
    
    // If this pixel is opaque, check if it's near a transparent pixel (inside edge)
    if(texColor.a > 0.1) {
        float pixelSize = 1.0 / 32.0;
        
        // Check 4 cardinal directions for transparency
        float edge = 0.0;
        if(texture2D(u_Tex0, v_TexCoord + vec2(-pixelSize, 0.0)).a < 0.1) edge = 1.0;
        if(texture2D(u_Tex0, v_TexCoord + vec2(pixelSize, 0.0)).a < 0.1) edge = 1.0;
        if(texture2D(u_Tex0, v_TexCoord + vec2(0.0, -pixelSize)).a < 0.1) edge = 1.0;
        if(texture2D(u_Tex0, v_TexCoord + vec2(0.0, pixelSize)).a < 0.1) edge = 1.0;
        
        if(edge > 0.5) {
            // Purple outline for epic items (RGB: 200, 0, 255)
            // Mix outline color with original for smoother effect
            vec3 outlineColor = vec3(0.784, 0.0, 1.0);
            gl_FragColor = vec4(mix(texColor.rgb, outlineColor, 0.7), texColor.a);
        } else {
            gl_FragColor = texColor;
        }
    } else {
        discard;
    }
}
