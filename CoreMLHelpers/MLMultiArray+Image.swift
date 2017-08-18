/*
  Copyright (c) 2017 M.I. Hollemans

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to
  deal in the Software without restriction, including without limitation the
  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
  sell copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
  IN THE SOFTWARE.
*/

import Foundation
import CoreML

public protocol MultiArrayArithmetic {
  static func +(lhs: Self, rhs: Self) -> Self
  static func *(lhs: Self, rhs: Self) -> Self
  init(_: Int)
  var toUInt8: UInt8 { get }
}

extension Double: MultiArrayArithmetic {
  public var toUInt8: UInt8 { return UInt8(self) }
}
extension Float: MultiArrayArithmetic {
  public var toUInt8: UInt8 { return UInt8(self) }
}
extension Int32: MultiArrayArithmetic {
  public var toUInt8: UInt8 { return UInt8(self) }
}

private func clamp<T: Comparable>(_ x: T, min: T, max: T) -> T {
  if x < min { return min }
  if x > max { return max }
  return x
}

extension MLMultiArray {
  /**
   Converts the multi-array to a color UIImage.
  */
  public func image<T: MultiArrayArithmetic>(offset: T, scale: T) -> UIImage? where T: Comparable {
    var image: UIImage?
    if let result = toRawBytes(offset: offset, scale: scale) {
      var bytes = result.0
      let width = result.1
      let height = result.2

      // Convert the raw data to a UIImage. Could also convert to CVPixelBuffer
      // or any other format here.
      bytes.withUnsafeMutableBytes { ptr in
        if let context = CGContext(data: ptr.baseAddress!,
                                   width: width,
                                   height: height,
                                   bitsPerComponent: 8,
                                   bytesPerRow: width * 4,
                                   space: CGColorSpaceCreateDeviceRGB(),
                                   bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
           let cgImage = context.makeImage() {
          image = UIImage(cgImage: cgImage, scale: 0, orientation: .up)
        }
      }
    }
    return image
  }

  /**
   Converts the multi-array into an array of RGBA pixels.

   Use the `offset` and `scale` parameters to put the values from the array in
   the range [0, 255]. The offset is added first, then the result is multiplied
   by the scale.

   For example, if the range of the data is [0, 1), use `offset: 0` and
   `scale: 255`. If the range is [-1, 1], use `offset: 1` and `scale: 127.5`.

   - Note: The type of `offset` and `scale` must match the `dataType` of the
     MLMultiArray. (By default it is inferred to be `Double`).

   - Note: The multi-array must have shape (3, height, width). Currently other
     arrangements aren't implemented yet.
  */
  public func toRawBytes<T: MultiArrayArithmetic>(offset: T, scale: T)
                        -> (bytes: [UInt8], width: Int, height: Int)? where T: Comparable {
    guard shape.count == 3 else {
      print("Expected a multi-array with 3 dimensions, got \(shape)")
      return nil
    }
    guard shape[0] == 3 else {
      print("Expected first dimension to have 3 channels, got \(shape[0])")
      return nil
    }

    let height = shape[1].intValue
    let width = shape[2].intValue
    var bytes = [UInt8](repeating: 0, count: height * width * 4)

    let channelStride = strides[0].intValue
    let heightStride = strides[1].intValue
    let widthStride = strides[2].intValue
    let pointer = UnsafeMutablePointer<T>(OpaquePointer(dataPointer))

    for h in 0..<height {
      for w in 0..<width {
        let r = (pointer[0*channelStride + h*heightStride + w*widthStride] + offset) * scale
        let g = (pointer[1*channelStride + h*heightStride + w*widthStride] + offset) * scale
        let b = (pointer[2*channelStride + h*heightStride + w*widthStride] + offset) * scale

        let offset = h*width*4 + w*4
        bytes[offset + 0] = clamp(r, min: T(0), max: T(255)).toUInt8
        bytes[offset + 1] = clamp(g, min: T(0), max: T(255)).toUInt8
        bytes[offset + 2] = clamp(b, min: T(0), max: T(255)).toUInt8
        bytes[offset + 3] = 255
      }
    }
    return (bytes, width, height)
  }
}