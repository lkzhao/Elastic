/*
 
 The MIT License (MIT)
 
 Copyright (c) 2015 Luke Zhao <me@lkzhao.com>
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 
 */

import UIKit
import MetalKit
import Metal


struct Vertex {
  var position: vector_float2
}

struct VertexUniform {
  var position: vector_float2 = [1.0,0]
  var shift: vector_float2 = [0,0]
  var transpose: Float = 0
  var flip: Float = 0
  var foldAlpha: Float = 0.2
  var padding: Float = 0
}


public class ElasticShapeView: MTKView {
  public var edge:Edge = .right{
    didSet{
      viewState.transpose = edge == .bottom || edge == .top ? 1 : 0
      viewState.flip = edge == .bottom || edge == .left ? 1 : 0
      setNeedsDisplay()
    }
  }
  
  public var foldAlpha:Float = 0.2 {
    didSet{
      viewState.foldAlpha = foldAlpha
      setNeedsDisplay()
    }
  }
  
  public var overlayColor:UIColor = .clear {
    didSet{
      var r:CGFloat = 0
      var g:CGFloat = 0
      var b:CGFloat = 0
      var a:CGFloat = 0
      
      overlayColor.getRed(&r, green: &g, blue: &b, alpha: &a)
      clearColor = MTLClearColor(red: Double(r), green: Double(g), blue: Double(b), alpha: Double(a))
      setNeedsDisplay()
    }
  }
  
  public var shift = CGPoint.zero{
    didSet{
      viewState.shift = [Float(shift.x/frame.width), Float(-shift.y/frame.height)]
      setNeedsDisplay()
    }
  }
  
  public var touchPosition = CGPoint.zero{
    didSet{
      setNeedsDisplay()
    }
  }
  
  
  
  
  
  var viewState = VertexUniform()
  
  var commandQueue: MTLCommandQueue?
  var rps: MTLRenderPipelineState?
  var vertexBuffer: MTLBuffer!
  var vertexes: UnsafeMutableBufferPointer<Vertex>? = nil
  var vertexUniformBuffer: MTLBuffer!
  var indexBuffer: MTLBuffer!
  var frontTex: MTLTexture?
  var onNextDraw: (()->Void)?
  
  override public var frame:CGRect{
    didSet{
      vertexBufferSize = (Int(self.frame.width) / 10, Int(self.frame.height) / 10)
      createBuffers()
    }
  }
  
  var vertexBufferSize:(width:Int, height:Int) = (1, 1)

  public init(frame: CGRect = CGRect.zero){
    super.init(frame: frame, device: MTLCreateSystemDefaultDevice())
    commandQueue = device!.makeCommandQueue()
    colorPixelFormat = .bgra8Unorm
    enableSetNeedsDisplay = true
    layer.isOpaque = false
    clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
    registerShaders()
    createBuffers()
  }
  
  required public init(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public func setUpTexture(view:UIView) {
//    let width = Int(view.bounds.width)
//    let height = Int(view.bounds.height)
//    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: colorPixelFormat, width: width, height: height, mipmapped: false)
//    let texture = device!.makeTexture(descriptor: descriptor)
//    let colorSpace = CGColorSpaceCreateDeviceRGB()
//    let context = CGContext(data: texture.buffer!.contents(), width: width, height: height, bitsPerComponent: 8, bytesPerRow: width*4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
//    view.layer.draw(in: context)
//    frontTex = texture
//    setNeedsDisplay()
    
    let textureLoader = MTKTextureLoader(device: device!)
    frontTex = try? textureLoader.newTexture(with: view.takeSnapshot().cgImage!, options: nil)
    setNeedsDisplay()
  }

  func createBuffers() {
    guard let device = device else { return }
    let yRes = UInt16(vertexBufferSize.height)
    let xRes = UInt16(vertexBufferSize.width)
    var vertex_data = Array<Vertex>()
    for y in 0..<yRes+1 {
      let tv = Float(y)/Float(yRes)
      for x in 0..<xRes+1 {
        let tu = Float(x)/Float(xRes)
        vertex_data.append(Vertex(position: [tu, tv]))
      }
    }
    var indices = Array<UInt16>(repeating:0, count:Int(xRes * yRes) * 6)
    for y in 0..<yRes {
      for x in 0..<xRes {
        let i = y*(xRes+1) + x
        let idx = Int(y*xRes + x)
        indices[idx*6+0] = i;
        indices[idx*6+1] = i + 1;
        indices[idx*6+2] = i + xRes + 1;
        indices[idx*6+3] = i + 1;
        indices[idx*6+4] = i + xRes + 2;
        indices[idx*6+5] = i + xRes + 1;
      }
    }
    
    vertexBuffer = device.makeBuffer(bytes: &vertex_data, length: MemoryLayout<Vertex>.size * vertex_data.count, options: [])
    indexBuffer = device.makeBuffer(bytes: &indices, length: MemoryLayout<UInt16>.size * indices.count, options: [])
    vertexUniformBuffer = device.makeBuffer(length: MemoryLayout<VertexUniform>.size, options: [])
  }
  
  func registerShaders() {
    let library = try! device!.makeLibrary(filepath: Bundle(for: ElasticShapeView.self).path(forResource: "default", ofType: "metallib")!)
    let rpld = MTLRenderPipelineDescriptor()
    rpld.vertexFunction = library.makeFunction(name: "elastic_vertex")
    rpld.fragmentFunction = library.makeFunction(name: "elastic_fragment")
    rpld.colorAttachments[0].pixelFormat = colorPixelFormat
    
    do {
      try rps = device!.makeRenderPipelineState(descriptor: rpld)
    } catch let error {
      print("\(error)")
    }
  }
  
  public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    return super.hitTest(point - shift, with: event)
  }
  
  override public func draw(_ rect: CGRect) {
    guard rect.size.width >= 1 && rect.size.height >= 1 else {return}
    if let rpd = currentRenderPassDescriptor, let drawable = currentDrawable, let frontTex = frontTex {
      viewState.position = [Float(touchPosition.x/frame.maxX), 1.0 - Float(touchPosition.y/frame.maxY)]
      
      memcpy(vertexUniformBuffer.contents(), &viewState, MemoryLayout<VertexUniform>.size)
      let commandBuffer = commandQueue!.makeCommandBuffer()
      let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: rpd)
      commandEncoder.setRenderPipelineState(rps!)
      commandEncoder.setVertexBuffer(vertexBuffer, offset: 0, at: 0)
      commandEncoder.setVertexBuffer(vertexUniformBuffer, offset: 0, at: 1)
      commandEncoder.setFragmentTexture(frontTex, at: 0)
      commandEncoder.drawIndexedPrimitives(type: .triangle, indexCount: vertexBufferSize.height * vertexBufferSize.width * 6, indexType: MTLIndexType.uint16, indexBuffer: indexBuffer, indexBufferOffset: 0)
      commandEncoder.endEncoding()
      
      commandBuffer.present(drawable)
      if let nextDraw = onNextDraw{
        onNextDraw = nil
        commandBuffer.addCompletedHandler({ [nextDraw] buffer in
          DispatchQueue.main.async(execute:nextDraw)
        })
      }
      commandBuffer.commit()
    }
  }
}
