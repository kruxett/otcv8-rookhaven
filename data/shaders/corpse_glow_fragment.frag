// Corpse Glow Shader - Pulsing Glow Effect
// Creates a bottom-to-top wave pulse on unlooted corpses
// TEST VERSION: Added bright edge glow to verify shader is actually running

uniform sampler2D u_Tex0;              // Item texture
varying vec2 v_TexCoord;

void main()
{
    vec4 texColor = texture2D(u_Tex0, v_TexCoord);
    
    // Discard fully transparent pixels
    if(texColor.a < 0.05) {
        discard;
    }
    
    // TEST: Create a bright green edge glow to verify shader is running
    // This creates a visible edge effect that ONLY a shader can produce
    
    // Distance from edges (0 at edge, 1 in center)
    float edgeDistX = min(v_TexCoord.x, 1.0 - v_TexCoord.x);
    float edgeDistY = min(v_TexCoord.y, 1.0 - v_TexCoord.y);
    float edgeDist = min(edgeDistX, edgeDistY);
    
    // Create edge glow: bright at edges (low edgeDist), dark in center
    float edgeGlow = smoothstep(0.0, 0.3, edgeDist);
    
    // Inverse to make edges bright
    edgeGlow = 1.0 - (edgeGlow * 0.7);  // 1.0 at edge, 0.3 in center
    
    // Add green glow at edges
    vec3 glowColor = vec3(0.0, 0.8, 0.5);  // Bright cyan-green
    
    // Composite: original texture with shader glow at edges
    vec3 finalColor = mix(texColor.rgb, glowColor, (1.0 - edgeGlow) * 0.8);
    
    gl_FragColor = vec4(finalColor, texColor.a);
}
