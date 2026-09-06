import AppKit
import SceneKit

private func worldStoneTexture(floor: Bool = false) -> NSImage {
    let side = 512
    let image = NSImage(size: NSSize(width: side, height: side))
    image.lockFocus()
    // Baked chips, mineral veins and soot add wear without more geometry or shaders.
    var randomState: UInt32 = floor ? 7919 : 15427
    func random() -> CGFloat {
        randomState = randomState &* 1664525 &+ 1013904223
        return CGFloat(randomState & 0x00ffffff) / CGFloat(0x00ffffff)
    }
    NSColor(calibratedRed: 0.07, green: 0.062, blue: 0.046, alpha: 1).setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: side, height: side)).fill()
    let rows = floor ? 4 : 8
    let cellW = 128, cellH = side / rows
    for row in 0..<rows {
        let offset = row % 2 == 0 ? 0 : -cellW/2
        for col in 0..<6 {
            let base = (floor ? 0.26 : 0.29) + random() * 0.15
            NSColor(calibratedRed: base * 1.04, green: base * 0.94, blue: base * 0.77, alpha: 1).setFill()
            let rect = NSRect(x: offset + col * cellW + 2, y: row * cellH + 2, width: cellW-4, height: cellH-4)
            let stone = NSBezierPath()
            stone.move(to:NSPoint(x:rect.minX+2+random()*4,y:rect.minY+random()*3))
            stone.line(to:NSPoint(x:rect.maxX-3-random()*5,y:rect.minY+random()*3))
            stone.line(to:NSPoint(x:rect.maxX-random()*3,y:rect.minY+5+random()*5))
            stone.line(to:NSPoint(x:rect.maxX-random()*2,y:rect.maxY-5-random()*3))
            stone.line(to:NSPoint(x:rect.maxX-5-random()*5,y:rect.maxY-random()*2))
            stone.line(to:NSPoint(x:rect.minX+5+random()*4,y:rect.maxY-random()*2))
            stone.line(to:NSPoint(x:rect.minX+random()*3,y:rect.maxY-4-random()*5))
            stone.line(to:NSPoint(x:rect.minX+random()*2,y:rect.minY+7))
            stone.close(); stone.fill()
            NSColor(calibratedRed:base+0.13,green:base+0.09,blue:base+0.025,alpha:0.29).setStroke()
            let edge = NSBezierPath()
            edge.move(to:NSPoint(x:rect.minX+8,y:rect.maxY-3)); edge.line(to:NSPoint(x:rect.maxX-10,y:rect.maxY-4))
            edge.lineWidth = 1.2; edge.stroke()
            for _ in 0..<22 {
                let xx = rect.minX+3+random()*CGFloat(cellW-12), yy = rect.minY+3+random()*CGFloat(cellH-12)
                NSColor(calibratedWhite:random() < 0.35 ? 0.63 : 0.04,alpha:0.08+random()*0.09).setFill()
                NSBezierPath(rect:NSRect(x:xx,y:yy,width:2+random()*8,height:1+random()*2)).fill()
            }
            if random() < 0.7 {
                let x = rect.minX+20+random()*70, y = rect.maxY-2
                let crack = NSBezierPath()
                crack.move(to:NSPoint(x:x,y:y))
                crack.line(to:NSPoint(x:x-7,y:y-CGFloat(cellH)*0.24))
                crack.line(to:NSPoint(x:x+4,y:y-CGFloat(cellH)*0.39))
                crack.line(to:NSPoint(x:x-10,y:y-CGFloat(cellH)*0.74))
                crack.move(to:NSPoint(x:x+4,y:y-CGFloat(cellH)*0.39))
                crack.line(to:NSPoint(x:x+20,y:y-CGFloat(cellH)*0.46))
                NSColor(calibratedRed:0.04,green:0.036,blue:0.027,alpha:0.52).setStroke()
                crack.lineWidth = 1.0+random()*1.1; crack.stroke()
            }
        }
    }
    for i in 0..<14000 {
        let xx = random()*512, yy = random()*512
        NSColor(calibratedWhite:i % 3 == 0 ? 0.78 : 0.02,alpha:0.035+random()*0.085).setFill()
        NSBezierPath(rect:NSRect(x:xx,y:yy,width:1+random()*3,height:1+random()*2)).fill()
    }
    for _ in 0..<480 {
        let xx = random()*512, yy = random()*512
        NSColor(calibratedRed:0.028,green:0.036,blue:0.012,alpha:0.035).setFill()
        NSBezierPath(ovalIn:NSRect(x:xx,y:yy,width:15+random()*82,height:8+random()*36)).fill()
    }
    if !floor {
        for _ in 0..<70 {
            let xx = random()*512, yy = random()*512
            NSColor(calibratedRed:0.021,green:0.016,blue:0.008,alpha:0.06).setFill()
            NSBezierPath(ovalIn:NSRect(x:xx,y:yy-100,width:3+random()*14,height:50+random()*180)).fill()
        }
    }
    image.unlockFocus()
    return image
}

private func worldBannerTexture() -> NSImage {
    let image = NSImage(size:NSSize(width:128,height:256))
    image.lockFocus()
    NSColor(calibratedRed:0.20,green:0.023,blue:0.014,alpha:1).setFill()
    NSBezierPath(rect:NSRect(x:0,y:0,width:128,height:256)).fill()
    for i in 0..<64 {
        NSColor(calibratedRed:0.032,green:0.012,blue:0.008,alpha:i % 3 == 0 ? 0.45 : 0.16).setFill()
        NSBezierPath(rect:NSRect(x:i*2,y:0,width:1,height:256)).fill()
    }
    for i in 0..<110 {
        NSColor(calibratedRed:0.045,green:0.025,blue:0.011,alpha:0.12).setFill()
        NSBezierPath(ovalIn:NSRect(x:(i*47)%128,y:(i*71)%256,width:3+i%16,height:8+i%27)).fill()
    }
    image.unlockFocus()
    return image
}

private final class WorldBuilder {
    let root = SCNNode()
    let architecture = SCNNode()
    var obstacles: [WalkRect] = []
    let walkable: [WalkRect] = [
        WalkRect(x: 0, z: -5, width: 18, depth: 26),
        WalkRect(x: 0, z: -24, width: 6, depth: 12),
        WalkRect(x: 0, z: -43, width: 24, depth: 26),
        WalkRect(x: -21, z: -44, width: 18, depth: 6),
        WalkRect(x: -38, z: -44, width: 16, depth: 22),
        WalkRect(x: 21, z: -44, width: 18, depth: 6),
        WalkRect(x: 38, z: -44, width: 16, depth: 22),
        WalkRect(x: 0, z: -64, width: 6, depth: 16),
        WalkRect(x: 0, z: -84, width: 28, depth: 24),
        WalkRect(x: 0, z: -101, width: 6, depth: 10),
        WalkRect(x: 0, z: -114, width: 14, depth: 16)
    ]
    let stone = SCNMaterial()
    let floorStone = SCNMaterial()
    let trim = SCNMaterial()
    let dark = SCNMaterial()
    let gold = SCNMaterial()
    let copper = SCNMaterial()
    let cyan = SCNMaterial()
    let amber = SCNMaterial()
    let red = SCNMaterial()
    let ceiling = SCNMaterial()
    var lightCount = 0

    init() {
        stone.diffuse.contents = worldStoneTexture()
        floorStone.diffuse.contents = worldStoneTexture(floor: true)
        for m in [stone, floorStone] {
            m.diffuse.wrapS = .repeat; m.diffuse.wrapT = .repeat
            m.diffuse.mipFilter = .linear; m.lightingModel = .blinn; m.shininess = 0.04
        }
        trim.diffuse.contents = stone.diffuse.contents
        trim.diffuse.wrapS = .repeat; trim.diffuse.wrapT = .repeat
        trim.diffuse.mipFilter = .linear
        trim.diffuse.contentsTransform = SCNMatrix4MakeScale(0.7, 1.5, 1)
        dark.diffuse.contents = NSColor(calibratedRed: 0.063, green: 0.058, blue: 0.050, alpha: 1)
        gold.diffuse.contents = NSColor(calibratedRed: 0.31, green: 0.21, blue: 0.077, alpha: 1)
        copper.diffuse.contents = NSColor(calibratedRed: 0.18, green: 0.12, blue: 0.08, alpha: 1)
        ceiling.diffuse.contents = NSColor(calibratedRed: 0.037, green: 0.043, blue: 0.039, alpha: 1)
        cyan.diffuse.contents = NSColor(calibratedRed: 0.10, green: 0.29, blue: 0.24, alpha: 1)
        cyan.emission.contents = NSColor(calibratedRed: 0.045, green: 0.20, blue: 0.16, alpha: 1)
        amber.diffuse.contents = NSColor(calibratedRed: 1, green: 0.48, blue: 0.08, alpha: 1)
        amber.emission.contents = NSColor(calibratedRed: 1, green: 0.30, blue: 0.015, alpha: 1)
        red.diffuse.contents = worldBannerTexture()
        red.emission.contents = NSColor.black
        for m in [trim, dark, gold, copper, ceiling] { m.lightingModel = .blinn; m.shininess = 0.025 }
        root.addChildNode(architecture)
    }

    @discardableResult func box(_ w: Float, _ h: Float, _ d: Float, _ x: Float, _ y: Float, _ z: Float, _ mat: SCNMaterial, chamfer: Float = 0, parent: SCNNode? = nil) -> SCNNode {
        let g = SCNBox(width: CGFloat(w), height: CGFloat(h), length: CGFloat(d), chamferRadius: CGFloat(chamfer))
        g.chamferSegmentCount = chamfer > 0 ? 1 : 0; g.materials = [mat]
        let n = SCNNode(geometry: g); n.position = v3(x,y,z); (parent ?? architecture).addChildNode(n); return n
    }
    @discardableResult func cylinder(_ radius: Float, _ height: Float, _ x: Float, _ y: Float, _ z: Float, _ mat: SCNMaterial, parent: SCNNode? = nil) -> SCNNode {
        let g = SCNCylinder(radius: CGFloat(radius), height: CGFloat(height)); g.radialSegmentCount = 10; g.materials = [mat]
        let n = SCNNode(geometry: g); n.position = v3(x,y,z); (parent ?? architecture).addChildNode(n); return n
    }
    func rod(_ a: SCNVector3, _ b: SCNVector3, radius: Float, material: SCNMaterial, parent: SCNNode? = nil) {
        let dx = Float(b.x-a.x), dy = Float(b.y-a.y), dz = Float(b.z-a.z)
        let len = sqrt(dx*dx+dy*dy+dz*dz)
        let n = cylinder(radius,len,Float((a.x+b.x)/2),Float((a.y+b.y)/2),Float((a.z+b.z)/2),material,parent: parent)
        n.simdOrientation = simd_quatf(from: SIMD3<Float>(0,1,0), to: SIMD3<Float>(dx,dy,dz)/len)
    }
    func tiled(_ base: SCNMaterial, x: Float, y: Float) -> SCNMaterial {
        let m = base.copy() as! SCNMaterial
        m.diffuse.contentsTransform = SCNMatrix4MakeScale(CGFloat(x), CGFloat(y), 1)
        return m
    }
    func point(_ x: Float, _ y: Float, _ z: Float, color: NSColor, intensity: CGFloat, reach: CGFloat) {
        guard lightCount < 11 else { return }; lightCount += 1
        let l = SCNLight(); l.type = .omni; l.color = color; l.intensity = intensity
        l.attenuationStartDistance = 2; l.attenuationEndDistance = reach; l.attenuationFalloffExponent = 1.3
        let n = SCNNode(); n.light = l; n.position = v3(x,y,z); root.addChildNode(n)
    }
    func floor(_ r: WalkRect) {
        let p = SCNPlane(width: CGFloat(r.width), height: CGFloat(r.depth))
        p.materials = [tiled(floorStone,x:r.width/4,y:r.depth/4)]
        let n = SCNNode(geometry:p); n.eulerAngles.x = -.pi/2; n.position = v3(r.x,0,r.z); architecture.addChildNode(n)
        // A narrow procession path ties the rooms together without covering the stonework.
        if abs(r.x) < 1 {
            for xx: Float in [-1.65, 1.65] { box(0.055,0.013,r.depth-0.3,xx,0.014,r.z,gold) }
            for zz in stride(from:r.z-r.depth/2+1,to:r.z+r.depth/2,by:3) { box(3.3,0.01,0.035,r.x,0.017,zz,gold) }
        }
    }
    func isWalkable(_ x: Float, _ z: Float) -> Bool { walkable.contains { $0.contains(x,z) } }
    func wall(_ x: Float,_ z: Float, _ span: Float,_ alongX: Bool) {
        let h: Float = 7.25
        let w: Float = alongX ? span : 0.45
        let d: Float = alongX ? 0.45 : span
        box(w,h,d,x,h/2,z,tiled(stone,x:max(w,d)/4,y:h/4))
        box(w+0.04,0.35,d+0.04,x,0.18,z,dark)
        box(w+0.09,0.15,d+0.09,x,1.03,z,trim)
        box(w+0.12,0.27,d+0.12,x,6.95,z,trim)
    }
    func boundaryWalls() {
        // Merge exposed intervals. Connected room edges never receive wall geometry.
        for r in walkable {
            for side in 0..<4 {
                let alongX = side < 2
                let lo = alongX ? r.x-r.width/2 : r.z-r.depth/2
                let hi = alongX ? r.x+r.width/2 : r.z+r.depth/2
                let edge = side == 0 ? r.z-r.depth/2 : side == 1 ? r.z+r.depth/2 : side == 2 ? r.x-r.width/2 : r.x+r.width/2
                let sign: Float = side == 0 || side == 2 ? -1 : 1
                var start: Float? = nil
                var pos = lo
                while pos < hi + 0.01 {
                    let finish = pos >= hi
                    let midpoint = min(pos+0.25,hi)
                    let exposed = !finish && !isWalkable(alongX ? midpoint : edge+sign*0.08, alongX ? edge+sign*0.08 : midpoint)
                    if exposed && start == nil { start = pos }
                    if !exposed, let a = start {
                        let center = (a+pos)/2
                        wall(alongX ? center : edge,alongX ? edge : center,pos-a,alongX)
                        start = nil
                    }
                    pos += 0.5
                }
            }
        }
    }
    func roof(_ r: WalkRect, low: Float = 7.23, peak: Float = 10.4) {
        let x0 = r.x-r.width/2, x1 = r.x+r.width/2, z0 = r.z-r.depth/2, z1 = r.z+r.depth/2
        let vs = [v3(x0,low,z0),v3(r.x,peak,z0),v3(x0,low,z1),v3(r.x,peak,z1),v3(x1,low,z0),v3(x1,low,z1)]
        let indices: [Int32] = [0,1,2,1,3,2,1,4,3,4,5,3]
        let g = SCNGeometry(sources:[SCNGeometrySource(vertices:vs)],elements:[SCNGeometryElement(indices:indices,primitiveType:.triangles)])
        let m = ceiling.copy() as! SCNMaterial; m.isDoubleSided = true; m.lightingModel = .constant; g.materials = [m]
        architecture.addChildNode(SCNNode(geometry:g))
        // Close both gable ends above the open portals.
        let cap = NSBezierPath()
        cap.move(to:NSPoint(x:-CGFloat(r.width/2),y:0))
        cap.line(to:NSPoint(x:CGFloat(r.width/2),y:0))
        cap.line(to:NSPoint(x:0,y:CGFloat(peak-low)))
        cap.close()
        for zz in [z0,z1] {
            let shape = SCNShape(path:cap,extrusionDepth:0.22)
            shape.materials = [tiled(stone,x:r.width/4,y:(peak-low)/4)]
            let node = SCNNode(geometry:shape); node.position = v3(r.x,low,zz); architecture.addChildNode(node)
        }
    }
    func pillar(_ x: Float,_ z: Float,height: Float = 4.9,radius: Float = 0.48) {
        cylinder(radius,height,x,height/2,z,trim)
        for xx: Float in [-0.3,0.3] { cylinder(radius*0.28,height,x+xx,height/2,z+0.28,stone) }
        box(radius*2.5,0.25,radius*2.5,x,0.125,z,dark,chamfer:0.06)
        box(radius*2.35,0.2,radius*2.35,x,0.36,z,trim,chamfer:0.04)
        box(radius*2.7,0.28,radius*2.7,x,height-0.13,z,trim,chamfer:0.045)
        obstacles.append(WalkRect(x:x,z:z,width:radius*2.5,depth:radius*2.5))
    }
    func arch(_ x: Float,_ z: Float,width: Float,base: Float,rise: Float,alongZ: Bool = false,radius: Float = 0.17) {
        for side: Float in [-1,1] {
            var previous = v3(x+side*width/2,base,z)
            if alongZ { previous = v3(x,base,z+side*width/2) }
            for k in 1...12 {
                let t = Float(k)/12, u = 1-t
                let horizontal = side*width/2*(u*u+2*u*t*0.74)
                let yy = base + rise*(2*u*t*0.66+t*t)
                let next = alongZ ? v3(x,yy,z+horizontal) : v3(x+horizontal,yy,z)
                rod(previous,next,radius:radius,material:trim); previous = next
            }
        }
        box(0.34,0.42,0.36,x,base+rise,z,gold,chamfer:0.05)
    }
    func portal(_ x: Float,_ z: Float,alongZ: Bool = false) {
        let node = SCNNode(); node.position = v3(x,0,z); if alongZ { node.eulerAngles.y = .pi/2 }; architecture.addChildNode(node)
        for s: Float in [-1,1] {
            box(0.3,3.0,0.42,s*3.1,1.5,0,trim,parent:node)
            box(0.42,0.24,0.55,s*3.1,2.9,0,gold,parent:node)
        }
        arch(x,z,width:6.2,base:3,rise:3.15,alongZ:alongZ,radius:0.23)
    }
    func stainedWindow(_ x: Float,_ y: Float,_ z: Float,width: Float,height: Float,rotation: Float = 0,hot: Bool = false) {
        let node = SCNNode(); node.position = v3(x,y,z); node.eulerAngles.y = CGFloat(rotation); architecture.addChildNode(node)
        func silhouette(_ w: CGFloat,_ h: CGFloat) -> NSBezierPath {
            let p = NSBezierPath(); p.move(to:NSPoint(x:-w/2,y:0)); p.line(to:NSPoint(x:w/2,y:0)); p.line(to:NSPoint(x:w/2,y:h*0.61))
            p.curve(to:NSPoint(x:0,y:h),controlPoint1:NSPoint(x:w*0.46,y:h*0.79),controlPoint2:NSPoint(x:w*0.14,y:h*0.98))
            p.curve(to:NSPoint(x:-w/2,y:h*0.61),controlPoint1:NSPoint(x:-w*0.14,y:h*0.98),controlPoint2:NSPoint(x:-w*0.46,y:h*0.79))
            p.close(); return p
        }
        let outer = SCNShape(path:silhouette(CGFloat(width+0.38),CGFloat(height+0.22)),extrusionDepth:0.17); outer.materials = [dark]
        node.addChildNode(SCNNode(geometry:outer))
        let g = SCNShape(path:silhouette(CGFloat(width),CGFloat(height)),extrusionDepth:0.025); g.materials = [hot ? amber : cyan]
        let glass = SCNNode(geometry:g); glass.position.z = 0.12; glass.position.y = 0.08; node.addChildNode(glass)
        for s: Float in [-1,0,1] {
            rod(v3(s*width*0.26,0.1,0.17),v3(s*width*0.26,height*(s == 0 ? 0.98 : 0.75),0.17),radius:0.038,material:dark,parent:node)
        }
        for level: Float in [0.23,0.46,0.65] {
            rod(v3(-width*0.48,height*level,0.17),v3(width*0.48,height*level,0.17),radius:0.045,material:dark,parent:node)
        }
        for yy: Float in [0.1,0.33,0.56] {
            for s: Float in [-1,1] {
                let cx = s*width*0.26, cy = height*(yy+0.11)
                rod(v3(cx-width*0.21,cy,0.18),v3(cx,cy+height*0.11,0.18),radius:0.025,material:gold,parent:node)
                rod(v3(cx,cy+height*0.11,0.18),v3(cx+width*0.21,cy,0.18),radius:0.025,material:gold,parent:node)
                rod(v3(cx+width*0.21,cy,0.18),v3(cx,cy-height*0.11,0.18),radius:0.025,material:gold,parent:node)
                rod(v3(cx,cy-height*0.11,0.18),v3(cx-width*0.21,cy,0.18),radius:0.025,material:gold,parent:node)
            }
        }
        box(width+0.62,0.19,0.47,0,-0.06,0.06,trim,parent:node)
    }
    func brazier(_ x: Float,_ z: Float,light: Bool = false) {
        cylinder(0.28,0.15,x,0.075,z,dark)
        cylinder(0.11,1.7,x,0.9,z,copper)
        let bowl = SCNCone(topRadius:0.45,bottomRadius:0.12,height:0.32); bowl.radialSegmentCount = 10; bowl.materials = [copper]
        let n = SCNNode(geometry:bowl); n.position = v3(x,1.73,z); architecture.addChildNode(n)
        for i in 0..<4 {
            let a = Float(i) * Float.pi / 2
            rod(v3(x+cos(a)*0.34,1.62,z+sin(a)*0.34),v3(x+cos(a)*0.48,2.1,z+sin(a)*0.48),radius:0.037,material:dark)
        }
        let flame = SCNSphere(radius:0.24); flame.segmentCount = 8; flame.materials = [amber]
        let f = SCNNode(geometry:flame); f.position = v3(x,2.03,z); f.scale = v3(0.85,1.8,0.85); root.addChildNode(f)
        f.runAction(.repeatForever(.sequence([.scale(to:1.13,duration:0.19),.scale(to:0.91,duration:0.16),.scale(to:1,duration:0.26)])))
        if light { point(x,2.5,z,color:NSColor(calibratedRed:1,green:0.53,blue:0.22,alpha:1),intensity:520,reach:15) }
    }
    func tomb(_ x: Float,_ z: Float,rotation: Float = 0) {
        let node = SCNNode(); node.position = v3(x,0,z); node.eulerAngles.y = CGFloat(rotation); architecture.addChildNode(node)
        box(1.9,0.2,3.4,0,0.1,0,dark,chamfer:0.08,parent:node)
        box(1.6,0.9,3.0,0,0.65,0,stone,chamfer:0.09,parent:node)
        box(1.85,0.22,3.25,0,1.21,0,trim,chamfer:0.08,parent:node)
        box(0.10,0.035,1.8,0,1.34,0,gold,parent:node)
        box(0.77,0.035,0.10,0,1.34,-0.35,gold,parent:node)
        obstacles.append(WalkRect(x:x,z:z,width:rotation == 0 ? 1.9 : 3.4,depth:rotation == 0 ? 3.4 : 1.9))
    }
    func chandelier(_ x: Float,_ z: Float) {
        let ring = SCNTorus(ringRadius:1.6,pipeRadius:0.07); ring.ringSegmentCount = 24; ring.pipeSegmentCount = 5; ring.materials = [copper]
        let n = SCNNode(geometry:ring); n.position = v3(x,5.75,z); architecture.addChildNode(n)
        for i in 0..<8 {
            let a = Float(i)*Float.pi/4, xx = x+cos(a)*1.6, zz = z+sin(a)*1.6
            cylinder(0.045,0.34,xx,5.94,zz,gold)
            let g = SCNSphere(radius:0.09); g.segmentCount = 6; g.materials = [amber]
            let f = SCNNode(geometry:g); f.position = v3(xx,6.18,zz); f.scale.y = 1.8; architecture.addChildNode(f)
            if i % 2 == 0 { rod(v3(xx,5.77,zz),v3(x,8.85,z),radius:0.024,material:dark) }
        }
    }
    func sigilDais(_ x: Float,_ z: Float) {
        cylinder(1.35,0.075,x,0.036,z,dark)
        let ring = SCNTorus(ringRadius:1.14,pipeRadius:0.03); ring.materials = [gold]
        let n = SCNNode(geometry:ring); n.position = v3(x,0.087,z); architecture.addChildNode(n)
        for i in 0..<8 { let a = Float(i)*Float.pi/4; box(0.1,0.025,0.3,x+cos(a)*0.9,0.089,z+sin(a)*0.9,cyan) }
    }
    func banner(_ x: Float,_ z: Float,rotation: Float = 0) {
        let n = SCNNode(); n.position = v3(x,3.1,z); n.eulerAngles.y = CGFloat(rotation); architecture.addChildNode(n)
        let cloth = NSBezierPath()
        cloth.move(to:NSPoint(x:-0.675,y:1.425)); cloth.line(to:NSPoint(x:0.675,y:1.425))
        for (x,y): (CGFloat,CGFloat) in [(0.675,-1.16),(0.48,-1.05),(0.38,-1.51),(0.17,-1.26),(0.09,-1.62),(-0.12,-1.19),(-0.30,-1.49),(-0.45,-1.15),(-0.675,-1.34)] {
            cloth.line(to:NSPoint(x:x,y:y))
        }
        cloth.close()
        let fabric = SCNShape(path:cloth,extrusionDepth:0.025); fabric.materials = [red]
        n.addChildNode(SCNNode(geometry:fabric))
        rod(v3(-0.82,1.46,0),v3(0.82,1.46,0),radius:0.055,material:gold,parent:n)
        box(0.065,1.45,0.015,0,0.12,0.037,gold,parent:n)
        rod(v3(-0.36,0.45,0.04),v3(0,-0.35,0.04),radius:0.043,material:gold,parent:n)
        rod(v3(0,-0.35,0.04),v3(0.36,0.45,0.04),radius:0.043,material:gold,parent:n)
    }

    func funeraryRelief(_ x: Float,_ z: Float,rotation: Float = 0) {
        // Shallow death masks stay above head height and inside existing wall skins.
        let n = SCNNode(); n.position = v3(x,3.6,z); n.eulerAngles.y = CGFloat(rotation); architecture.addChildNode(n)
        box(1.22,1.72,0.07,0,0,0,dark,chamfer:0.06,parent:n)
        box(1.07,1.57,0.075,0,0,0.045,stone,chamfer:0.045,parent:n)
        let skull = SCNSphere(radius:0.39); skull.segmentCount = 10; skull.materials = [trim]
        let head = SCNNode(geometry:skull); head.position = v3(0,0.14,0.15); head.scale = v3(0.87,1.04,0.48); n.addChildNode(head)
        box(0.40,0.22,0.17,0,-0.23,0.19,trim,chamfer:0.025,parent:n)
        for sx: Float in [-0.14,0.14] {
            let socket = SCNSphere(radius:0.105); socket.segmentCount = 8; socket.materials = [dark]
            let eye = SCNNode(geometry:socket); eye.position = v3(sx,0.16,0.325); eye.scale = v3(1,0.82,0.19); n.addChildNode(eye)
        }
        box(0.065,0.105,0.025,0,-0.02,0.335,dark,chamfer:0.009,parent:n)
        for sx: Float in [-0.12,0,0.12] { box(0.034,0.11,0.03,sx,-0.25,0.284,dark,parent:n) }
        rod(v3(-0.32,-0.66,0.1),v3(0.32,-0.43,0.1),radius:0.052,material:trim,parent:n)
        rod(v3(0.32,-0.66,0.1),v3(-0.32,-0.43,0.1),radius:0.052,material:trim,parent:n)
        for sx: Float in [-0.40,0.40] { box(0.07,0.07,0.025,sx,0.61,0.095,copper,parent:n) }
    }

    func hangingIron(_ z: Float) {
        // Broken portcullis teeth only occupy the overhead space, leaving the gallery clear.
        box(5.7,0.12,0.15,0,5.65,z,dark)
        for i in -3...3 {
            let xx = Float(i)*0.77, drop: Float = i % 2 == 0 ? 1.28 : 0.79
            rod(v3(xx,5.65,z),v3(xx,5.65-drop,z),radius:0.048,material:copper)
            let tip = SCNCone(topRadius:0,bottomRadius:0.11,height:0.27)
            tip.radialSegmentCount = 5; tip.materials = [dark]
            let tooth = SCNNode(geometry:tip); tooth.position = v3(xx,5.53-drop,z); tooth.eulerAngles.z = .pi; architecture.addChildNode(tooth)
        }
    }

    func wayfindingPlaque(_ direction: String, _ destination: String, x: Float, z: Float, side: Float) {
        // Iron brackets and short chains make these physical wall signs above head height.
        let centerY: Float = 2.85
        let plate = SCNNode(); plate.position = v3(x,centerY,z); architecture.addChildNode(plate)
        box(2.38,0.82,0.10,0,0,0,gold,chamfer:0.045,parent:plate)
        box(2.28,0.72,0.12,0,0,0.024,dark,chamfer:0.035,parent:plate)
        let lettering = SCNMaterial()
        lettering.diffuse.contents = NSColor(calibratedRed:0.68,green:0.55,blue:0.32,alpha:1)
        lettering.emission.contents = NSColor(calibratedRed:0.22,green:0.15,blue:0.065,alpha:1)
        lettering.lightingModel = .blinn
        for (line, yy, height) in [(direction,Float(0.18),Float(0.16)),(destination,Float(-0.17),Float(0.24))] {
            let text = SCNText(string:line,extrusionDepth:0.015)
            text.font = NSFont.systemFont(ofSize:1,weight:.semibold)
            text.flatness = 0.15; text.materials = [lettering]
            let label = SCNNode(geometry:text)
            let bounds = label.boundingBox
            let scale = min(height / Float(bounds.max.y-bounds.min.y), 1.97 / Float(bounds.max.x-bounds.min.x))
            label.scale = v3(scale,scale,scale)
            label.position = v3(-Float(bounds.min.x+bounds.max.x)*scale/2,yy-Float(bounds.min.y+bounds.max.y)*scale/2,0.095)
            plate.addChildNode(label)
        }
        for sx: Float in [-1.06,1.06] {
            for sy: Float in [-0.28,0.28] { box(0.045,0.045,0.025,sx,sy,0.10,gold,chamfer:0.009,parent:plate) }
        }
        if side == 0 {
            // The north sign hangs from the doorway's pointed stone arch.
            for sx: Float in [-0.82,0.82] { rod(v3(x+sx,3.26,z),v3(x+sx,5.64,z),radius:0.021,material:copper) }
        } else {
            let wallX: Float = side * 11.77
            box(0.10,0.48,0.26,wallX,3.37,z,dark)
            rod(v3(wallX,3.50,z),v3(x-side*1.07,3.50,z),radius:0.046,material:copper)
            rod(v3(wallX,3.17,z),v3(x,3.50,z),radius:0.033,material:copper)
            for sx: Float in [-0.82,0.82] { rod(v3(x+sx,3.26,z),v3(x+sx,3.50,z),radius:0.021,material:copper) }
        }
    }

    func build() -> WorldData {
        for (i,r) in walkable.enumerated() { floor(r); roof(r,peak: [1,3,5,7,9].contains(i) ? 7.6 : 10.5) }
        boundaryWalls()
        // Cathedral nave: clustered piers, pointed transverse arches, clerestory glass.
        for zz: Float in [2,-6,-14] {
            for xx: Float in [-6.8,6.8] { pillar(xx,zz); brazier(xx*0.9,zz-1.4) }
            arch(0,zz,width:13.6,base:4.9,rise:4.95)
            for xx: Float in [-8.7,8.7] { stainedWindow(xx,2.25,zz-3.2,width:2.5,height:4.25,rotation:xx < 0 ? .pi/2 : -.pi/2) }
        }
        for xx: Float in [-6.8,6.8] {
            for zz: Float in [-2,-10] { arch(xx,zz,width:8,base:4.9,rise:2.9,alongZ:true,radius:0.12) }
        }
        chandelier(0,-5)
        for zz: Float in [-5,-13] {
            funeraryRelief(-8.73,zz,rotation:.pi/2)
            funeraryRelief(8.73,zz,rotation:-.pi/2)
        }
        stainedWindow(0,2.4,7.73,width:3.3,height:4.2,rotation:.pi)
        for xx: Float in [-4.5,4.5] { banner(xx,-17.72) }
        for zz: Float in [-18,-30,-56,-72,-96,-106] { portal(0,zz) }
        for xx: Float in [-12,-30,12,30] { portal(xx,-44,alongZ:true) }
        // Rib rhythm in connecting galleries.
        for zz: Float in [-22,-27,-61,-67,-100] { arch(0,zz,width:5.65,base:3.2,rise:3.55,radius:0.13) }
        for xx: Float in [-25,-18,18,25] { arch(xx,-44,width:5.65,base:3.2,rise:3.55,alongZ:true,radius:0.13) }
        for zz: Float in [-24,-63,-100] { hangingIron(zz) }
        // Cruciform crossing: long sightlines make branch navigation legible.
        for zz: Float in [-34,-52] {
            for xx: Float in [-8.1,8.1] { pillar(xx,zz,height:5.1,radius:0.56) }
            arch(0,zz,width:16.2,base:5.1,rise:4.65)
        }
        for xx: Float in [-11.72,11.72] {
            for zz: Float in [-35,-52] { stainedWindow(xx,2.3,zz,width:2.4,height:4.2,rotation:xx < 0 ? .pi/2 : -.pi/2) }
        }
        chandelier(0,-43)
        for xx: Float in [-5.1,5.1] { banner(xx,-55.72); brazier(xx,-53.9) }
        wayfindingPlaque("WEST", "OSSUARY", x:-10.35, z:-40.45, side:-1)
        wayfindingPlaque("EAST", "FURNACE", x:10.35, z:-40.45, side:1)
        wayfindingPlaque("NORTH", "CRYPT", x:0, z:-55.60, side:0)
        // Ossuary: tombs flank a clear central circuit.
        for xx: Float in [-43.4,-32.6] { for zz: Float in [-37,-50] { tomb(xx,zz) } }
        for zz: Float in [-37,-51] { arch(-38,zz,width:13,base:4.5,rise:4.6) }
        stainedWindow(-45.72,2.1,-44,width:4.3,height:4.7,rotation:.pi/2)
        for xx: Float in [-42,-34] { banner(xx,-54.72); brazier(xx,-52.5) }
        sigilDais(-38,-51)
        funeraryRelief(-38,-54.73)
        // Furnace chapel uses glowing inset wall plates, a warm counterpart to the ossuary.
        for zz: Float in [-37,-51] { arch(38,zz,width:13,base:4.5,rise:4.6) }
        stainedWindow(45.72,2.1,-44,width:4.3,height:4.7,rotation:-.pi/2,hot:true)
        for xx: Float in [33,43] {
            pillar(xx,-36,height:4.6,radius:0.48); pillar(xx,-51,height:4.6,radius:0.48)
            brazier(xx,-40); brazier(xx,-48)
        }
        for zz: Float in [-36,-52] { box(8,0.055,0.8,38,0.025,zz,dark); box(7.5,0.02,0.18,38,0.06,zz,amber) }
        sigilDais(38,-51)
        funeraryRelief(38,-54.73)
        // High crypt: layered monuments keep the final fight mobile.
        for zz: Float in [-77,-90] {
            for xx: Float in [-9.5,9.5] { pillar(xx,zz,height:5.3,radius:0.62); tomb(xx*0.64,zz) }
            arch(0,zz,width:19,base:5.3,rise:4.7)
        }
        for xx: Float in [-13.72,13.72] {
            for zz: Float in [-78,-87] { stainedWindow(xx,2.2,zz,width:3.1,height:4.7,rotation:xx < 0 ? .pi/2 : -.pi/2) }
        }
        for xx: Float in [-7,7] { banner(xx,-95.72); brazier(xx,-93.7) }
        sigilDais(0,-92)
        for xx: Float in [-10.6,10.6] { funeraryRelief(xx,-95.73) }
        // Sanctum: an illuminated rose-like pointed window frames the extraction seal.
        stainedWindow(0,2.15,-121.72,width:4.8,height:4.9)
        for xx: Float in [-5.3,5.3] { pillar(xx,-117,height:4.7,radius:0.48); brazier(xx,-111) }
        arch(0,-117,width:10.6,base:4.7,rise:4.7)
        sigilDais(0,-116)
        // Eleven local lights plus the caller's ambient/directional illumination.
        point(0,5,-4,color:NSColor(calibratedRed:0.44,green:0.50,blue:0.43,alpha:1),intensity:620,reach:23)
        point(0,3,-15,color:NSColor(calibratedRed:1,green:0.47,blue:0.19,alpha:1),intensity:500,reach:15)
        point(0,3.5,-25,color:NSColor(calibratedRed:0.33,green:0.45,blue:0.39,alpha:1),intensity:320,reach:11)
        point(0,6,-43,color:NSColor(calibratedRed:0.42,green:0.52,blue:0.42,alpha:1),intensity:790,reach:24)
        point(-38,4,-44,color:NSColor(calibratedRed:0.22,green:0.48,blue:0.38,alpha:1),intensity:730,reach:18)
        point(38,3.5,-44,color:NSColor(calibratedRed:1,green:0.29,blue:0.08,alpha:1),intensity:780,reach:18)
        point(0,3,-64,color:NSColor(calibratedRed:1,green:0.57,blue:0.29,alpha:1),intensity:400,reach:13)
        point(-8,4.5,-84,color:NSColor(calibratedRed:0.31,green:0.42,blue:0.46,alpha:1),intensity:730,reach:19)
        point(8,4,-84,color:NSColor(calibratedRed:0.43,green:0.34,blue:0.25,alpha:1),intensity:740,reach:19)
        point(0,3,-94,color:NSColor(calibratedRed:1,green:0.50,blue:0.24,alpha:1),intensity:550,reach:14)
        point(0,4,-116,color:NSColor(calibratedRed:0.26,green:0.50,blue:0.42,alpha:1),intensity:780,reach:18)
        // Static details share the existing small material palette; only brazier flames animate.
        root.name = "Black Reliquary — soot-blackened gothic ruins"
        let enemies: [EnemySpawn] = [
            .init(x:-3,z:-10,kind:0),.init(x:4,z:-15,kind:0),.init(x:0,z:-27,kind:0),
            .init(x:-4,z:-36,kind:0),.init(x:4,z:-39,kind:1),.init(x:1,z:-51,kind:0),
            .init(x:-20,z:-44,kind:0),.init(x:-37,z:-39,kind:0),.init(x:-40,z:-47,kind:1),.init(x:-35,z:-51,kind:0),
            .init(x:22,z:-44,kind:0),.init(x:38,z:-37,kind:0),.init(x:40,z:-45,kind:1),.init(x:36,z:-50,kind:0),
            .init(x:0,z:-68,kind:0),.init(x:-3,z:-76,kind:0),.init(x:4,z:-78,kind:1),
            .init(x:-10,z:-85,kind:0),.init(x:10,z:-85,kind:0),.init(x:-3,z:-91,kind:1),.init(x:4,z:-93,kind:0),.init(x:0,z:-112,kind:1),
            .init(x:-4,z:-46,kind:2),.init(x:-38,z:-46,kind:2),.init(x:38,z:-48,kind:2),.init(x:0,z:-83,kind:2)
        ]
        let pickups: [PickupSpawn] = [
            .init(x:2,z:3,kind:1),.init(x:-2,z:3,kind:2),.init(x:-7.7,z:-10,kind:0),.init(x:7.7,z:-10,kind:1),
            .init(x:-5,z:-33,kind:1),.init(x:5,z:-33,kind:2),.init(x:0,z:-54,kind:0),
            .init(x:-38,z:-35,kind:1),.init(x:-44,z:-44,kind:0),.init(x:-35,z:-48,kind:2),
            .init(x:38,z:-35,kind:1),.init(x:44,z:-44,kind:0),.init(x:35,z:-48,kind:2),
            .init(x:-1.5,z:-70,kind:1),.init(x:1.5,z:-70,kind:2),.init(x:0,z:-73,kind:0),
            .init(x:-12,z:-90,kind:0),.init(x:12,z:-90,kind:1),.init(x:0,z:-87,kind:2),.init(x:0,z:-104,kind:0),
            .init(x:0,z:-6,kind:3),.init(x:-31.5,z:-44,kind:3),.init(x:31.5,z:-44,kind:3)
        ]
        let names = ["THE ASHEN NAVE","GALLERY OF WHISPERS","THE SUNDERED CROSSING","WESTERN CLOISTER","THE OSSUARY","EASTERN CLOISTER","FURNACE CHAPEL","THE PENITENT'S WALK","CRYPT OF THE FORSAKEN","THE LAST PROCESSION","THE BLACK RELIQUARY"]
        return WorldData(root:root,walkable:walkable,obstacles:obstacles,spawn:v3(0,1.65,4),enemies:enemies,pickups:pickups,sigils:[v3(-38,1.2,-51),v3(38,1.2,-51),v3(0,1.2,-92)],exit:v3(0,0,-116),zones:zip(names,walkable).map { Zone(name:$0.0,rect:$0.1) })
    }
}

func buildWorld() -> WorldData { WorldBuilder().build() }
