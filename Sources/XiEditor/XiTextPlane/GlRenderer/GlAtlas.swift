// Copyright 2019 The xi-editor Authors.
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

import Cocoa
import OpenGL

class GlAtlas: Atlas {
    var textureId: GLuint = 0

    override init() {
        super.init()
        glGenTextures(1, &textureId)
        glBindTexture(GLenum(GL_TEXTURE_2D), textureId)
        glPixelStorei(GLenum(GL_UNPACK_ALIGNMENT), 1)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GL_CLAMP_TO_EDGE)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GL_CLAMP_TO_EDGE)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_NEAREST)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_NEAREST)
        var data = [UInt8](repeating: 255, count: width * height * 4)

        glTexImage2D(GLenum(GL_TEXTURE_2D), 0, GL_RGBA, GLsizei(width), GLsizei(height), 0, GLenum(GL_BGRA), GLenum(GL_UNSIGNED_BYTE), &data)
    }

    override func writeGlyphToTexture(origin: AtlasPoint, size: AtlasSize, data: [uint8]) {
        var pixels = data
        glTexSubImage2D(GLenum(GL_TEXTURE_2D), 0,
                        GLint(origin.x), GLint(origin.y),
                        GLsizei(size.width), GLsizei(size.height),
                        GLenum(GL_BGRA),
                        GLenum(GL_UNSIGNED_BYTE),
                        &pixels)
    }
}

