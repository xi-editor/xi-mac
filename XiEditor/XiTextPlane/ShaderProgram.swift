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

import Foundation
import OpenGL

/// A convenience for loading GLSL shaders.

class ShaderProgram {
    var program: GLuint

    init() {
        program = glCreateProgram()
        if program == 0 {
            NSLog("glCreateProgram failed")
        }
    }

    deinit {
        glDeleteProgram(program)
    }

    func attachShader(name: String, type: GLint) {
        let path = Bundle.main.path(forResource: name, ofType: "glsl")!
        guard let data = NSData(contentsOfFile: path) else {
            NSLog("loading shader \(name) failed")
            return
        }
        let shader = glCreateShader(GLenum(type))
        var bytes = data.bytes.assumingMemoryBound(to: GLchar.self) as UnsafePointer<GLchar>?
        var length = GLint(data.length)
        glShaderSource(shader, 1, &bytes, &length)
        glCompileShader(shader)
        var result: GLint = 0
        glGetShaderiv(shader, GLenum(GL_COMPILE_STATUS), &result)
        if result == GL_TRUE {
            glAttachShader(program, shader)
        } else {
            var length: GLint = 0
            glGetShaderiv(shader, GLenum(GL_INFO_LOG_LENGTH), &length)
            var str = [GLchar](repeating: GLchar(0), count: Int(length) + 1)
            var size: GLsizei = 0
            glGetShaderInfoLog(shader, GLsizei(length), &size, &str)
            let msg = String(cString: str)
            NSLog("compilation of \(name) failed: \(msg)")
        }
        glDeleteShader(shader)
    }

    func link() {
        glLinkProgram(program)
        var result: GLint = 0
        glGetProgramiv(program, GLenum(GL_LINK_STATUS), &result)
        if result == GL_FALSE {
            NSLog("shader linking failed")
            // TODO: print log
        }
    }

    func use() {
        glUseProgram(program)
    }

    func getUniformLocation(name: String) -> GLuint? {
        let loc = glGetUniformLocation(program, name.cString(using: String.Encoding.utf8))
        return loc < 0 ? nil : GLuint(loc)
    }
}
