import AppKit
let svgURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outDir = URL(fileURLWithPath: CommandLine.arguments[2])
let glyphSource = NSImage(contentsOf: svgURL)!
let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
func c(_ h: Int, _ a: CGFloat = 1) -> CGColor { CGColor(srgbRed: CGFloat((h>>16)&255)/255, green: CGFloat((h>>8)&255)/255, blue: CGFloat(h&255)/255, alpha: a) }
func ctx(_ s: Int) -> CGContext { CGContext(data: nil, width: s, height: s, bitsPerComponent: 8, bytesPerRow: 0, space: srgb, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)! }
func glyph(_ side: Int) -> CGImage {
  var r = NSRect(x: 0, y: 0, width: side, height: side)
  let g = glyphSource.cgImage(forProposedRect: &r, context: nil, hints: nil)!
  let k = ctx(side); let b = CGRect(x: 0, y: 0, width: side, height: side)
  k.interpolationQuality = .high; k.draw(g, in: b); k.setBlendMode(.sourceIn); k.setFillColor(c(0xF2F2F2)); k.fill(b)
  return k.makeImage()!
}
// Apple macOS Icon-Raster: 1024er Fläche, Kachel 824 (Rand 100), Radius ~185, Schatten nach unten.
func render(_ px: Int) -> CGImage {
  let k = ctx(px); let S = CGFloat(px); let u = S / 1024
  let tile = CGRect(x: 100*u, y: 100*u, width: 824*u, height: 824*u)
  let radius = 185.4*u
  let path = CGPath(roundedRect: tile, cornerWidth: radius, cornerHeight: radius, transform: nil)
  if px >= 64 {
    k.saveGState()
    k.setShadow(offset: CGSize(width: 0, height: -10*u), blur: 20*u, color: c(0x000000, 0.30))
    k.addPath(path); k.setFillColor(c(0x1F1F1F)); k.fillPath()
    k.restoreGState()
  }
  k.saveGState(); k.addPath(path); k.clip()
  // CSS linear-gradient(160deg, #2b2b2d, #1f1f1f) — y in Quartz gespiegelt
  let rad = 160 * CGFloat.pi / 180, dx = sin(rad), dy = cos(rad)
  let half = (abs(sin(rad)) + abs(cos(rad))) * tile.width / 2
  let m = CGPoint(x: tile.midX, y: tile.midY)
  let grad = CGGradient(colorsSpace: srgb, colors: [c(0x2B2B2D), c(0x1F1F1F)] as CFArray, locations: [0,1])!
  k.drawLinearGradient(grad, start: CGPoint(x: m.x - dx*half, y: m.y - dy*half), end: CGPoint(x: m.x + dx*half, y: m.y + dy*half), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
  k.restoreGState()
  let gs = Int((tile.width * 54 / 72).rounded())
  let o = (S - CGFloat(gs)) / 2
  k.draw(glyph(gs), in: CGRect(x: o, y: o, width: CGFloat(gs), height: CGFloat(gs)))
  return k.makeImage()!
}
for (name, px) in [("icon_16x16.png",16),("icon_16x16@2x.png",32),("icon_32x32.png",32),("icon_32x32@2x.png",64),("icon_128x128.png",128),("icon_128x128@2x.png",256),("icon_256x256.png",256),("icon_256x256@2x.png",512),("icon_512x512.png",512),("icon_512x512@2x.png",1024)] {
  let png = NSBitmapImageRep(cgImage: render(px)).representation(using: .png, properties: [:])!
  try! png.write(to: outDir.appendingPathComponent(name)); print("wrote", name)
}
