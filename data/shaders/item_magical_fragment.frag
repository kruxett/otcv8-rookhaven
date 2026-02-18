// Magical Item Fragment Shader
// Creates a bright cyan magical aura around items

uniform sampler2D u_Tex0;
varying vec2 v_TexCoord;

void main()
{
    vec4 texColor = texture2D(u_Tex0, v_TexCoord);
    
    // Discard fully transparent pixels
    if(texColor.a < 0.05) {
        discard;
    }
    
    // Bright cyan magical glow color
    // Cyan (RGB: 0, 255, 255) = (0.0, 1.0, 1.0)
    vec3 magicalColor = vec3(0.0, 1.0, 1.0);
    
    // Add bright magical glow (60% brightness boost)
    // This creates a vibrant magical aura effect
    vec3 finalColor = texColor.rgb + (magicalColor * 0.60);
    
    gl_FragColor = vec4(finalColor, texColor.a);
}
