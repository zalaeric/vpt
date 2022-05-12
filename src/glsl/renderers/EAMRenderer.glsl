// #part /glsl/shaders/renderers/EAM/generate/vertex

#version 300 es

uniform mat4 uMvpInverseMatrix;

layout(location = 0) in vec2 aPosition;
out vec3 vRayFrom;
out vec3 vRayTo;

// #link /glsl/mixins/unproject.glsl
@unproject

void main() {
    unproject(aPosition, uMvpInverseMatrix, vRayFrom, vRayTo);
    gl_Position = vec4(aPosition, 0, 1);
}

// #part /glsl/shaders/renderers/EAM/generate/fragment

#version 300 es
precision mediump float;

uniform mediump sampler3D uVolume;
uniform mediump sampler2D uTransferFunction;
uniform float uStepSize;
uniform float uRandom;
uniform float uExtinction;
uniform int uMethod;

in vec3 vRayFrom;
in vec3 vRayTo;
out vec4 oColor;

// #link /glsl/mixins/intersectCube.glsl
@intersectCube
@rand

vec4 sampleVolumeColor(vec3 position) {
    vec2 volumeSample = texture(uVolume, position).rg;
    vec4 transferSample = texture(uTransferFunction, volumeSample);
    return transferSample;
}

void main() {
    vec3 rayDirection = vRayTo - vRayFrom;
    vec2 tbounds = max(intersectCube(vRayFrom, rayDirection), 0.0);
    if (tbounds.x >= tbounds.y) {
        oColor = vec4(0, 0, 0, 1);
    } else {
        vec3 from = mix(vRayFrom, vRayTo, tbounds.x);
        vec3 to = mix(vRayFrom, vRayTo, tbounds.y);
        float rayStepLength = distance(from, to) * uStepSize;

        float t = 0.0;
        float t2 = 0.0;
        vec4 accumulator = vec4(0);

        if (uMethod < 1) { // navadno

            while (t < 1.0 && accumulator.a < 0.99) {
                vec3 position = mix(from, to, t);
                vec4 colorSample = sampleVolumeColor(position);
                colorSample.a *= rayStepLength * uExtinction;
                colorSample.rgb *= colorSample.a;
                accumulator += (1.0 - accumulator.a) * colorSample;
                t += uStepSize;
            }

        } else if (uMethod < 2) { // random offset

            t = uStepSize * uRandom;
            while (t < 1.0 && accumulator.a < 0.99) {
                vec3 position = mix(from, to, t);
                vec4 colorSample = sampleVolumeColor(position);
                colorSample.a *= rayStepLength * uExtinction;
                colorSample.rgb *= colorSample.a;
                accumulator += (1.0 - accumulator.a) * colorSample;
                t += uStepSize;
            }

        } else { // jitter

            vec2 randomPos = vRayFrom.xy * uRandom;

            int i = 0;
            while (t < 1.0 && accumulator.a < 0.99) {
                vec3 position = mix(from, to, t2);
                vec4 colorSample = sampleVolumeColor(position);
                colorSample.a *= rayStepLength * uExtinction;
                colorSample.rgb *= colorSample.a;
                accumulator += (1.0 - accumulator.a) * colorSample;
                
                t2 = uStepSize * (randomPos.x + float(i));
                randomPos = rand(randomPos);
                t += uStepSize;
                i += 1;
            }
        }



        if (accumulator.a > 1.0) {
            accumulator.rgb /= accumulator.a;
        }

        oColor = vec4(accumulator.rgb, 1);
    }
}

// #part /glsl/shaders/renderers/EAM/integrate/vertex

#version 300 es

layout(location = 0) in vec2 aPosition;
out vec2 vPosition;

void main() {
    vPosition = aPosition * 0.5 + 0.5;
    gl_Position = vec4(aPosition, 0, 1);
}

// #part /glsl/shaders/renderers/EAM/integrate/fragment

#version 300 es
precision mediump float;

uniform mediump sampler2D uAccumulator;
uniform mediump sampler2D uFrame;
uniform float uInvFrameNumber;

in vec2 vPosition;
out vec4 oColor;

void main() {
    //iz MCS da ne migeta
    
    vec4 acc = texture(uAccumulator, vPosition);
    vec4 frame = texture(uFrame, vPosition);
    oColor = acc + (frame - acc) * uInvFrameNumber;
    
    //oColor = texture(uFrame, vPosition);
}

// #part /glsl/shaders/renderers/EAM/render/vertex

#version 300 es

layout(location = 0) in vec2 aPosition;
out vec2 vPosition;

void main() {
    vPosition = aPosition * 0.5 + 0.5;
    gl_Position = vec4(aPosition, 0, 1);
}

// #part /glsl/shaders/renderers/EAM/render/fragment

#version 300 es
precision mediump float;

uniform mediump sampler2D uAccumulator;

in vec2 vPosition;
out vec4 oColor;

void main() {
    oColor = texture(uAccumulator, vPosition);
}

// #part /glsl/shaders/renderers/EAM/reset/vertex

#version 300 es

layout(location = 0) in vec2 aPosition;

void main() {
    gl_Position = vec4(aPosition, 0, 1);
}

// #part /glsl/shaders/renderers/EAM/reset/fragment

#version 300 es
precision mediump float;

out vec4 oColor;

void main() {
    oColor = vec4(0, 0, 0, 1);
}
