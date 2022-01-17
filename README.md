# Custom Render Pipeline for Unity

## TODO

#### [Shadows](https://catlikecoding.com/unity/tutorials/custom-srp/directional-shadows)
- Cascade Blend Modes
    - Hard, Soft, Dithered
- Material Transparency Shadow Modes
    - On, Clip, Dither, Off
- Receive Shadows Toggle
- Debug Visualize Cascades
- Spot Light Shadows
    - Clamped Sampling: Is it even necessary with attenuation?
- Point Light Shadows

### Deferred
- Emission
- Lights
    - Point light instancing
    - Spot lights
    - All other light shapes

### Other
- Material Fresnel Scale Slider
- [Premultiplied Alpha](https://catlikecoding.com/unity/tutorials/custom-srp/directional-lights/#4) 
- GBuffers should be size of target backbuffer, not size of monitor
- Indirect reflections are too prominent in the dark
- Spotlight inner angle inspector GUI
