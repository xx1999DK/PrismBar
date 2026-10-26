import AppKit
let destination = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
func color(_ value: UInt32) -> NSColor { NSColor(srgbRed: CGFloat(value >> 16 & 255)/255, green: CGFloat(value >> 8 & 255)/255, blue: CGFloat(value & 255)/255, alpha: 1) }
func draw(size: Int, name: String) throws {
  let image = NSImage(size: NSSize(width: size, height: size))
  image.lockFocus()
  let transform = NSAffineTransform(); transform.scale(by: CGFloat(size)/512); transform.concat()
  let background = NSBezierPath(roundedRect: NSRect(x: 20, y: 20, width: 472, height: 472), xRadius: 108, yRadius: 108)
  NSGradient(starting: color(0xEAF3FF), ending: color(0xDAD8F6))!.draw(in: background, angle: -50)
  let colors: [(UInt32, UInt32)] = [(0x3076CF,0x5A9BE7),(0x4F70C7,0x8A76D9),(0x7271D2,0xAA8CD9)]
  for row in 0..<3 {
    let y = CGFloat(285-row*70)
    let path = NSBezierPath()
    path.move(to: NSPoint(x: 115,y: y+30)); path.line(to: NSPoint(x: 275,y: y+81))
    path.line(to: NSPoint(x: 401,y: y+30)); path.line(to: NSPoint(x: 239,y:y-23)); path.close()
    NSGradient(starting: color(colors[row].0), ending: color(colors[row].1))!.draw(in:path, angle:0)
  }
  image.unlockFocus()
  let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
  try bitmap.representation(using:.png,properties:[:])!.write(to:destination.appendingPathComponent(name))
}
for size in [16,32,128,256,512] {
  try draw(size:size,name:"icon_\(size)x\(size).png")
  try draw(size:size*2,name:"icon_\(size)x\(size)@2x.png")
}
