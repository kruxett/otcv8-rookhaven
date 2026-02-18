// Corpse Glow Shader - Subtle Glow Effect
// Creates a persistent glow on unlooted corpses
// Animation is handled by Lua pulsing the color overlay

uniform sampler2D u_Tex0;              // Item texture
varying vec2 v_TexCoord;

void main()
{
    vec4 texColor = texture2D(u_Tex0, v_TexCoord);
    
    // Discard fully transparent pixels
    if(texColor.a < 0.05) {
        discard;
    }
    
    // Static glow across entire sprite
    float glowAmount = 0.35;  // 35% brightness increase
    
    // Subtle green-cyan glow color
    vec3 glowColor = vec3(0.2, 0.6, 0.5);  // Teal-green glow
    
    // Additive blend: add glow
    vec3 finalColor = texColor.rgb + (glowColor * glowAmount);
    
    gl_FragColor = vec4(finalColor, texColor.a);
}
