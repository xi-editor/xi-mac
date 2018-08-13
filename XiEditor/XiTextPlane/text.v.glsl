// Copyright 2017 The xi-editor Authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#version 330 core
// corners of the quad, ranges from (0, 0) to (1, 1)
layout (location = 0) in vec2 position;

// rect coords are in pixels (to be scaled by posScale)
layout (location = 1) in vec2 rectOrigin;

layout (location = 2) in vec2 rectSize;

// in 0..255 units
layout (location = 3) in vec4 rgba;

layout (location = 4) in vec2 uvOrigin;

layout (location = 5) in vec2 uvSize;

uniform vec2 posScale;

flat out vec4 passColor;
out vec2 uv;

void main() {
    vec2 pixelPos = rectOrigin + position * rectSize;
    vec2 pos = pixelPos * posScale + vec2(-1.0, 1.0);
    gl_Position = vec4(pos, 0.0, 1.0);
    passColor = rgba * vec4(1.0 / 255.0);
    // TODO: more precise sRGB formula
    passColor = passColor * passColor; // do conversion to sRGB
    uv = uvOrigin + position * uvSize;
}
