// Copyright 2017 Google LLC
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

/// The renderer for text planes.

class Renderer {
    var solidProgram: ShaderProgram
    var vertexArrayIds = [GLuint](repeating: 0, count: 2)
    var bufferIds = [GLuint](repeating: 0, count: 4)
    var solid_u_scale: GLuint = 0
    
    var textProgram: ShaderProgram
    var textVertexArrayId: GLuint = 0
    var text_u_scale: GLuint = 0
    
    var atlas: Atlas
    var instanceBuf: [GLfloat] = []
    
    init() {
        solidProgram = ShaderProgram()
        solidProgram.attachShader(name: "solid.v", type: GL_VERTEX_SHADER)
        solidProgram.attachShader(name: "solid.f", type: GL_FRAGMENT_SHADER)
        solidProgram.link()
        
        solid_u_scale = solidProgram.getUniformLocation(name: "posScale")!
        
        glGenVertexArrays(GLsizei(vertexArrayIds.count), &vertexArrayIds)
        glBindVertexArray(vertexArrayIds[0])
        
        glGenBuffers(GLsizei(bufferIds.count), &bufferIds)
        // vertex position buffer
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), bufferIds[0])
        let vertices: [Float] = [1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0]
        glBufferData(GLenum(GL_ARRAY_BUFFER), MemoryLayout<Float>.size * 8, vertices, GLenum(GL_STATIC_DRAW))
        glVertexAttribPointer(0, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 8, nil)
        glEnableVertexAttribArray(0)
        
        // element buffer
        glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), bufferIds[1])
        let indices: [Int32] = [0, 1, 3, 1, 2, 3]
        glBufferData(GLenum(GL_ELEMENT_ARRAY_BUFFER), MemoryLayout<Int32>.size * 6, indices, GLenum(GL_STATIC_DRAW))
        
        // instance buffer
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), bufferIds[2])
        let instanceSize = GLsizei(MemoryLayout<Float>.size * 8)
        let p: [Float] = [
            200, 200, 600, 600,  255.0, 128.0, 128.0, 255.0,
            500, 100, 100, 400,  128.0, 128.0, 255.0, 127.0,
            ]
        glBufferData(GLenum(GL_ARRAY_BUFFER), GLsizeiptr(instanceSize * 2), p, GLenum(GL_STATIC_DRAW))
        // rectOrigin
        glEnableVertexAttribArray(1)
        glVertexAttribPointer(1, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), instanceSize, nil)
        glVertexAttribDivisor(1, 1)
        // rectSize
        glEnableVertexAttribArray(2)
        glVertexAttribPointer(2, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), instanceSize, UnsafeRawPointer(bitPattern: MemoryLayout<Float>.size * 2))
        glVertexAttribDivisor(2, 1)
        // rgba
        glEnableVertexAttribArray(3)
        glVertexAttribPointer(3, 4, GLenum(GL_FLOAT), GLboolean(GL_FALSE), instanceSize, UnsafeRawPointer(bitPattern: MemoryLayout<Float>.size * 4))
        glVertexAttribDivisor(3, 1)
        
        // text blending
        textProgram = ShaderProgram()
        textProgram.attachShader(name: "text.v", type: GL_VERTEX_SHADER)
        textProgram.attachShader(name: "text.f", type: GL_FRAGMENT_SHADER)
        textProgram.link()
        
        text_u_scale = solidProgram.getUniformLocation(name: "posScale")!
        
        glBindVertexArray(vertexArrayIds[1])
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), bufferIds[0])
        glVertexAttribPointer(0, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 8, nil)
        glEnableVertexAttribArray(0)
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), bufferIds[3])
        let textInstanceSize = GLsizei(MemoryLayout<Float>.size * 12)
        let textP: [Float] = [
            10, 100, 256, 256,  192.0, 192.0, 192.0, 255.0,  0.0, 0.0, 1.0, 1.0
        ]
        glBufferData(GLenum(GL_ARRAY_BUFFER), GLsizeiptr(textInstanceSize * 1), textP, GLenum(GL_STATIC_DRAW))
        // rectOrigin
        glEnableVertexAttribArray(1)
        glVertexAttribPointer(1, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), textInstanceSize, nil)
        glVertexAttribDivisor(1, 1)
        // rectSize
        glEnableVertexAttribArray(2)
        glVertexAttribPointer(2, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), textInstanceSize, UnsafeRawPointer(bitPattern: MemoryLayout<Float>.size * 2))
        glVertexAttribDivisor(2, 1)
        // rgba
        glEnableVertexAttribArray(3)
        glVertexAttribPointer(3, 4, GLenum(GL_FLOAT), GLboolean(GL_FALSE), textInstanceSize, UnsafeRawPointer(bitPattern: MemoryLayout<Float>.size * 4))
        glVertexAttribDivisor(3, 1)
        // uvOrigin
        glEnableVertexAttribArray(4)
        glVertexAttribPointer(4, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), textInstanceSize, UnsafeRawPointer(bitPattern: MemoryLayout<Float>.size * 8))
        glVertexAttribDivisor(4, 1)
        // uvSize
        glEnableVertexAttribArray(5)
        glVertexAttribPointer(5, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), textInstanceSize, UnsafeRawPointer(bitPattern: MemoryLayout<Float>.size * 10))
        glVertexAttribDivisor(5, 1)
        
        atlas = Atlas()
        let font = CTFontCreateWithName("InconsolataGo" as CFString, 28, nil)
        let fr = atlas.getFontRef(font: font)
        for i in 0..<256 {
            let _ = atlas.getGlyph(font: font, fr: fr, glyph: CGGlyph(i))
        }
    }
    
    func render(size: CGSize) {
        // Note: could move this computation so it only happens on size change
        let u_x_scale = 2.0 / GLfloat(size.width)
        let u_y_scale = -2.0 / GLfloat(size.height)
        
        solidProgram.use()
        glBlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA))
        glBindVertexArray(vertexArrayIds[0])
        glUniform2f(GLint(solid_u_scale), u_x_scale, u_y_scale)
        glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), bufferIds[1])
        //glBindBuffer(GLenum(GL_ARRAY_BUFFER), bufferIds[2])
        glDrawElementsInstanced(GLenum(GL_TRIANGLES), 6, GLenum(GL_UNSIGNED_INT), nil, 2)
        
        let text = "Now is the time for all good people to come to the aid of their country. This is a very long string because I really want to fill up the window and see if we can get 60Hz"
        let font = NSFont(name: "InconsolataGo", size: 28)!
        let attributes: [NSAttributedStringKey: AnyObject] = [
            NSAttributedStringKey.font: font,
            ]
        let attrString = NSMutableAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attrString)
        
        instanceBuf.removeAll()
        instanceBuf.append(contentsOf: [10, 100, 256, 256,  192.0, 192.0, 192.0, 255.0,  0.0, 0.0, 1.0, 1.0])
        for j in 0..<60 {
            drawLine(line: line, x: 10, y: GLfloat(30 + j * 30), argb: 0xffffffff)
        }
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), bufferIds[3])
        // todo: use subdata
        glBufferData(GLenum(GL_ARRAY_BUFFER), GLsizeiptr(instanceBuf.count * 4), instanceBuf, GLenum(GL_STATIC_DRAW))
        
        //print(instanceBuf)
        
        textProgram.use()
        glBlendFunc(GLenum(GL_SRC1_COLOR), GLenum(GL_ONE_MINUS_SRC1_COLOR))
        glBindVertexArray(vertexArrayIds[1])
        glUniform2f(GLint(text_u_scale), u_x_scale, u_y_scale)
        glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), bufferIds[1])
        //glBindBuffer(GLenum(GL_ARRAY_BUFFER), bufferIds[3])
        glDrawElementsInstanced(GLenum(GL_TRIANGLES), 6, GLenum(GL_UNSIGNED_INT), nil, GLsizei(instanceBuf.count / 12))
        glUseProgram(0)
    }
    
    func drawLine(line: CTLine, x: GLfloat, y: GLfloat, argb: UInt32) {
        let fg = [GLfloat((argb >> 16) & 0xff),
                  GLfloat((argb >> 8) & 0xff),
                  GLfloat(argb & 0xff),
                  GLfloat(argb >> 24)]
        let runs = CTLineGetGlyphRuns(line) as [AnyObject] as! [CTRun]
        for run in runs {
            let count = CTRunGetGlyphCount(run)
            let attributes: NSDictionary = CTRunGetAttributes(run)
            let font = attributes[kCTFontAttributeName] as! CTFont
            let fr = atlas.getFontRef(font: font)
            for i in 0..<count {
                var glyph = CGGlyph()
                var pos = CGPoint()
                let range = CFRange(location: i, length: 1)
                CTRunGetGlyphs(run, range, &glyph)
                CTRunGetPositions(run, range, &pos)
                let cachedGlyph = atlas.getGlyph(font: font, fr: fr, glyph: glyph)
                let dpiScale: GLfloat = 0.5 // TODO: be systematic
                instanceBuf.append((x + GLfloat(pos.x) + cachedGlyph!.xoff) * dpiScale)
                instanceBuf.append((y + GLfloat(pos.y) + cachedGlyph!.yoff) * dpiScale)
                instanceBuf.append(cachedGlyph!.width * dpiScale)
                instanceBuf.append(cachedGlyph!.height * dpiScale)
                instanceBuf.append(contentsOf: fg)
                instanceBuf.append(contentsOf: cachedGlyph!.uvCoords)
            }
        }
    }
}

