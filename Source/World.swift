import AppKit
import SceneKit

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
    var surfaces: [WalkSurface] = []
    var solids: [SolidVolume] = []
    let eaves: [Float] = [10,6.8,13,7,10,7,12.5,8,12,8,10]
    let peaks: [Float] = [14,9,18,9,14,9,17,10,16,10,14]
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
    let stone = GothicMaterials.shared.stone.copy() as! SCNMaterial
    let floorStone = GothicMaterials.shared.floor.copy() as! SCNMaterial
    let trim = GothicMaterials.shared.trim.copy() as! SCNMaterial
    let dark = GothicMaterials.shared.iron.copy() as! SCNMaterial
    let gold = SCNMaterial()
    let copper = SCNMaterial()
    let cyan = SCNMaterial()
    let amber = SCNMaterial()
    let red = SCNMaterial()
    let ceiling = GothicMaterials.shared.ceiling.copy() as! SCNMaterial
    var lightCount = 0

    init() {
        gold.diffuse.contents = NSColor(calibratedRed: 0.31, green: 0.21, blue: 0.077, alpha: 1)
        copper.diffuse.contents = NSColor(calibratedRed: 0.18, green: 0.12, blue: 0.08, alpha: 1)
        cyan.diffuse.contents = NSColor(calibratedRed: 0.17, green: 0.095, blue: 0.038, alpha: 1)
        cyan.emission.contents = NSColor(calibratedRed: 0.11, green: 0.055, blue: 0.019, alpha: 1)
        amber.diffuse.contents = NSColor(calibratedRed: 1, green: 0.48, blue: 0.08, alpha: 1)
        amber.emission.contents = NSColor(calibratedRed: 1, green: 0.30, blue: 0.015, alpha: 1)
        red.diffuse.contents = worldBannerTexture()
        red.emission.contents = NSColor.black
        for m in [gold, copper] { m.lightingModel = .blinn; m.shininess = 0.025 }
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
        let transform = SCNMatrix4MakeScale(CGFloat(x), CGFloat(y), 1)
        for property in [m.diffuse,m.normal,m.roughness] {property.contentsTransform=transform;property.wrapS = .repeat;property.wrapT = .repeat}
        return m
    }
    func point(_ x: Float, _ y: Float, _ z: Float, color: NSColor, intensity: CGFloat, reach: CGFloat) {
        guard lightCount < 14 else { return }; lightCount += 1
        let l = SCNLight(); l.type = .omni; l.color = color; l.intensity = intensity
        l.attenuationStartDistance = 2; l.attenuationEndDistance = reach; l.attenuationFalloffExponent = 1.3
        let n = SCNNode(); n.light = l; n.position = v3(x,y,z); root.addChildNode(n)
    }
    func solid(_ rect: WalkRect, bottom: Float, top: Float) {
        solids.append(SolidVolume(rect:rect,bottom:bottom,top:top))
    }
    func elevated(_ amount: Float, _ operation: () -> Void) {
        let architectureStart=architecture.childNodes.count, rootStart=root.childNodes.count, solidStart=solids.count
        operation()
        for n in architecture.childNodes.dropFirst(architectureStart) {n.position.y += CGFloat(amount)}
        for n in root.childNodes.dropFirst(rootStart) {n.position.y += CGFloat(amount)}
        for i in solidStart..<solids.count {solids[i].bottom += amount;solids[i].top += amount}
    }
    func surface(_ id: String,_ r: WalkRect,y: Float=0,slopeX: Float=0,slopeZ: Float=0,ceiling: Float=30,stairs: Bool=false) {
        let s=WalkSurface(id:id,rect:r,y:y,slopeX:slopeX,slopeZ:slopeZ,thickness:0.35,ceiling:ceiling)
        surfaces.append(s)
        if stairs {
            let alongX=abs(slopeX)>0.001, length=alongX ? r.width:r.depth
            let rise=abs((alongX ? slopeX:slopeZ)*length), count=max(1,Int(ceil(rise/0.20)))
            let step=length/Float(count), stairMaterial=tiled(floorStone,x:(alongX ? step:r.width)/3,y:(alongX ? r.depth:step)/3)
            for i in 0..<count {
                let offset = -length/2+(Float(i)+0.5)*step
                let xx=r.x+(alongX ? offset:0), zz=r.z+(alongX ? 0:offset)
                let top=y+offset*(alongX ? slopeX:slopeZ)+0.04
                box(alongX ? step:r.width,0.27,alongX ? r.depth:step,xx,top-0.135,zz,stairMaterial)
            }
            // A UV-mapped stone soffit and closed sides make the stair a real slab.
            let x0=r.x-r.width/2,x1=r.x+r.width/2,z0=r.z-r.depth/2,z1=r.z+r.depth/2
            func h(_ x:Float,_ z:Float)->Float {y+(x-r.x)*slopeX+(z-r.z)*slopeZ}
            let top=[v3(x0,h(x0,z0)-0.10,z0),v3(x0,h(x0,z1)-0.10,z1),v3(x1,h(x1,z1)-0.10,z1),v3(x1,h(x1,z0)-0.10,z0)]
            let bottom=top.map{v3(Float($0.x),Float($0.y)-0.25,Float($0.z))}
            quad(bottom.reversed().map{$0},material:tiled(ceilingMaterial(),x:r.width/3,y:r.depth/3))
            for i in 0..<4 {let j=(i+1)%4;quad([top[i],bottom[i],bottom[j],top[j]],material:tiled(stone,x:length/3,y:0.3))}
        } else {
            box(r.width,0.35,r.depth,r.x,y-0.175,r.z,tiled(floorStone,x:r.width/3,y:r.depth/3))
            if abs(r.x)<1 && y==0 {
                for xx:Float in [-1.65,1.65] {box(0.035,0.012,r.depth-0.3,xx,0.014,r.z,gold)}
            }
        }
    }
    func ceilingMaterial() -> SCNMaterial {ceiling}
    func quad(_ vertices:[SCNVector3],material:SCNMaterial,firstEdgeIsU:Bool=false) {
        let av=SIMD3<Float>(Float(vertices[0].x),Float(vertices[0].y),Float(vertices[0].z))
        let bv=SIMD3<Float>(Float(vertices[1].x),Float(vertices[1].y),Float(vertices[1].z))
        let cv=SIMD3<Float>(Float(vertices[2].x),Float(vertices[2].y),Float(vertices[2].z))
        let cross=simd_cross(bv-av,cv-av), normal=simd_length(cross)>0.0001 ? simd_normalize(cross):SIMD3<Float>(0,0,1)
        let normals=Array(repeating:v3(normal.x,normal.y,normal.z),count:4)
        let g=SCNGeometry(sources:[SCNGeometrySource(vertices:vertices),SCNGeometrySource(normals:normals),SCNGeometrySource(textureCoordinates:firstEdgeIsU ? [CGPoint(x:0,y:0),CGPoint(x:1,y:0),CGPoint(x:1,y:1),CGPoint(x:0,y:1)]:[CGPoint(x:0,y:0),CGPoint(x:0,y:1),CGPoint(x:1,y:1),CGPoint(x:1,y:0)])],elements:[SCNGeometryElement(indices:[Int32(0),1,2,0,2,3],primitiveType:.triangles)])
        material.isDoubleSided=true;g.materials=[material];architecture.addChildNode(SCNNode(geometry:g))
    }
    func railing(_ a: SCNVector3,_ b: SCNVector3) {
        let dx=Float(b.x-a.x),dz=Float(b.z-a.z),length=hypot(dx,dz),count=max(1,Int(ceil(length/0.65)))
        rod(v3(Float(a.x),Float(a.y)+1.22,Float(a.z)),v3(Float(b.x),Float(b.y)+1.22,Float(b.z)),radius:0.055,material:dark)
        rod(v3(Float(a.x),Float(a.y)+0.52,Float(a.z)),v3(Float(b.x),Float(b.y)+0.52,Float(b.z)),radius:0.033,material:dark)
        for i in 0...count {
            let t=Float(i)/Float(count),x=Float(a.x)+dx*t,z=Float(a.z)+dz*t,y=Float(a.y)+Float(b.y-a.y)*t
            cylinder(0.035,1.25,x,y+0.61,z,dark)
            if i<count {
                let u=Float(i+1)/Float(count),endY=Float(a.y)+Float(b.y-a.y)*u
                solid(WalkRect(x:x+dx/Float(count)/2,z:z+dz/Float(count)/2,width:max(0.12,abs(dx)/Float(count)),depth:max(0.12,abs(dz)/Float(count))),bottom:min(y,endY)-0.035,top:max(y,endY)+1.25)
            }
        }
    }
    func isWalkable(_ x: Float, _ z: Float) -> Bool { walkable.contains { $0.contains(x,z) } }
    func wall(_ x: Float,_ z: Float,_ span: Float,_ alongX: Bool,bottom:Float=0,top:Float=10) {
        let h=top-bottom,w:Float=alongX ? span:0.45,d:Float=alongX ? 0.45:span
        box(w,h,d,x,bottom+h/2,z,tiled(stone,x:max(w,d)/3,y:h/3))
        box(w+0.04,0.35,d+0.04,x,bottom+0.18,z,dark)
        box(w+0.09,0.15,d+0.09,x,bottom+1.03,z,trim)
        box(w+0.12,0.27,d+0.12,x,top-0.20,z,trim)
        solid(WalkRect(x:x,z:z,width:w,depth:d),bottom:bottom-0.35,top:top)
    }
    func boundaryWalls() {
        // Merge exposed intervals. Connected room edges never receive wall geometry.
        for (roomIndex,r) in walkable.enumerated() {
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
                        wall(alongX ? center : edge,alongX ? edge : center,pos-a,alongX,bottom:roomIndex==4 ? -6:0,top:eaves[roomIndex])
                        start = nil
                    }
                    pos += 0.5
                }
            }
        }
    }
    func roof(_ r:WalkRect,low:Float,peak:Float) {
        // Sixteen curved panels have explicit normals/UVs and finite ceiling volumes.
        let count=16,x0=r.x-r.width/2,z0=r.z-r.depth/2,z1=r.z+r.depth/2,step=r.width/Float(count)
        func height(_ x:Float)->Float {low+(peak-low)*(1-pow(abs((x-r.x)/(r.width/2)),0.72))}
        for i in 0..<count {
            let a=x0+Float(i)*step,b=a+step,ya=height(a),yb=height(b)
            quad([v3(a,ya,z0),v3(b,yb,z0),v3(b,yb,z1),v3(a,ya,z1)],material:tiled(ceiling,x:hypot(step,yb-ya)/2.6,y:r.depth/2.6),firstEdgeIsU:true)
            solid(WalkRect(x:(a+b)/2,z:r.z,width:step+0.015,depth:r.depth),bottom:min(ya,yb),top:max(ya,yb)+0.4)
            if i%4==0 || i==count-1 {rod(v3(a,ya-0.045,z0),v3(a,ya-0.045,z1),radius:0.075,material:trim)}
            for zz in [z0,z1] {
                quad([v3(a,low,zz),v3(a,ya,zz),v3(b,yb,zz),v3(b,low,zz)],material:tiled(stone,x:step/3,y:max(0.1,max(ya,yb)-low)/3))
                if max(ya,yb)>low+0.02 {solid(WalkRect(x:(a+b)/2,z:zz,width:step,depth:0.22),bottom:low,top:max(ya,yb))}
            }
        }
        for zz in stride(from:z0+2.5,to:z1,by:5.0) {
            for i in 0..<count {
                let a=x0+Float(i)*step,b=a+step
                rod(v3(a,height(a)-0.08,zz),v3(b,height(b)-0.08,zz),radius:0.105,material:trim)
            }
            box(0.28,0.28,0.38,r.x,peak-0.12,zz,gold,chamfer:0.03)
        }
    }
    func pillar(_ x: Float,_ z: Float,height: Float = 4.9,radius: Float = 0.48) {
        cylinder(radius,height,x,height/2,z,tiled(trim,x:radius*2 * .pi/2.6,y:height/2.6))
        for xx: Float in [-0.3,0.3] { cylinder(radius*0.28,height,x+xx,height/2,z+0.28,stone) }
        box(radius*2.5,0.25,radius*2.5,x,0.125,z,dark,chamfer:0.06)
        box(radius*2.35,0.2,radius*2.35,x,0.36,z,trim,chamfer:0.04)
        box(radius*2.7,0.28,radius*2.7,x,height-0.13,z,trim,chamfer:0.045)
        let footprint=WalkRect(x:x,z:z,width:radius*2.5,depth:radius*2.5)
        obstacles.append(footprint);solid(footprint,bottom:0,top:height)
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
        for side:Float in [-1,1] {
            solid(WalkRect(x:x+(alongZ ? 0:side*3.1),z:z+(alongZ ? side*3.1:0),width:alongZ ? 0.42:0.3,depth:alongZ ? 0.3:0.42),bottom:0,top:3.15)
        }
        let top=walkable.enumerated().filter{$0.element.contains(x,z)}.map{eaves[$0.offset]}.max() ?? 7
        if top>6.3 {
            box(alongZ ? 0.40:6.0,top-6.3,alongZ ? 6.0:0.40,x,(top+6.3)/2,z,tiled(stone,x:2,y:(top-6.3)/3))
            solid(WalkRect(x:x,z:z,width:alongZ ? 0.40:6.0,depth:alongZ ? 6.0:0.40),bottom:6.3,top:top)
        }
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
        let g = SCNShape(path:silhouette(CGFloat(width),CGFloat(height)),extrusionDepth:0.025); g.materials = [cyan]
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
        // Intrinsic tapered geometry survives uniform flicker scaling; no glowing spheres.
        let flameMaterial=simpleMaterial(color(0.82,0.23,0.025,0.72),emission:color(0.80,0.20,0.025))
        flameMaterial.lightingModel = .constant;flameMaterial.blendMode = .add;flameMaterial.writesToDepthBuffer=false
        let flame=SCNCone(topRadius:0.008,bottomRadius:0.21,height:0.68)
        flame.radialSegmentCount=7;flame.materials=[flameMaterial]
        let f=SCNNode(geometry:flame);f.position=v3(x,2.05,z);f.eulerAngles.z=0.10;root.addChildNode(f)
        let core=SCNCone(topRadius:0,bottomRadius:0.105,height:0.40);core.radialSegmentCount=6
        core.materials=[simpleMaterial(color(0.96,0.49,0.075),emission:color(0.86,0.40,0.06))]
        let heart=SCNNode(geometry:core);heart.position=v3(0,-0.10,0);f.addChildNode(heart)
        f.runAction(.repeatForever(.sequence([.scale(to:1.12,duration:0.19),.scale(to:0.87,duration:0.16),.scale(to:1,duration:0.26)])))
        if light { point(x,2.5,z,color:NSColor(calibratedRed:1,green:0.53,blue:0.22,alpha:1),intensity:520,reach:15) }
    }
    func tomb(_ x: Float,_ z: Float,rotation: Float = 0) {
        let node = SCNNode(); node.position = v3(x,0,z); node.eulerAngles.y = CGFloat(rotation); architecture.addChildNode(node)
        box(1.9,0.2,3.4,0,0.1,0,dark,chamfer:0.08,parent:node)
        box(1.6,0.9,3.0,0,0.65,0,stone,chamfer:0.09,parent:node)
        box(1.85,0.22,3.25,0,1.21,0,trim,chamfer:0.08,parent:node)
        box(0.10,0.035,1.8,0,1.34,0,gold,parent:node)
        box(0.77,0.035,0.10,0,1.34,-0.35,gold,parent:node)
        let footprint=WalkRect(x:x,z:z,width:rotation == 0 ? 1.9:3.4,depth:rotation == 0 ? 3.4:1.9)
        obstacles.append(footprint);solid(footprint,bottom:0,top:1.34)
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
        let floorIDs=["nave","whisper-gallery","crossing","west-cloister","ossuary-lower","east-cloister","furnace-ground","penitent-walk","high-crypt","last-procession","sanctum"]
        for (i,r) in walkable.enumerated() {
            surface(floorIDs[i],r,y:i==4 ? -6:0,ceiling:peaks[i]+0.4)
            roof(r,low:eaves[i],peak:peaks[i])
        }
        boundaryWalls()
        // The west entrance rests over the lower crypt: the corridor has no false floor below it.
        box(0.45,5.65,6,-30,-3.175,-44,tiled(stone,x:2,y:2))
        solid(WalkRect(x:-30,z:-44,width:0.45,depth:6),bottom:-6.35,top:-0.35)
        // Broad winding stairs use smooth collision planes beneath individual stone treads.
        surface("west-entry",WalkRect(x:-31.7,z:-44,width:3.4,depth:4),y:0,ceiling:14)
        surface("west-flight-1",WalkRect(x:-31.7,z:-39,width:3.4,depth:6),y:-1,slopeZ:-1/3,ceiling:14,stairs:true)
        surface("west-landing-1",WalkRect(x:-31.7,z:-34.5,width:3.4,depth:3),y:-2,ceiling:14)
        surface("west-flight-2",WalkRect(x:-38,z:-34.5,width:9.2,depth:3),y:-3,slopeX:2/9.2,ceiling:14,stairs:true)
        surface("west-landing-2",WalkRect(x:-44.3,z:-34.5,width:3.4,depth:3),y:-4,ceiling:14)
        surface("west-flight-3",WalkRect(x:-44.3,z:-41,width:3.4,depth:10),y:-5,slopeZ:0.2,ceiling:14,stairs:true)
        railing(v3(-33.4,0,-46),v3(-30,0,-46))
        railing(v3(-33.4,0,-46),v3(-33.4,0,-42))
        railing(v3(-33.4,0,-42),v3(-33.4,-2,-36))
        railing(v3(-33.4,-2,-36),v3(-42.6,-4,-36))
        railing(v3(-42.6,-4,-36),v3(-42.6,-6,-46))
        // The east staircase mirrors the descent, ending on an open elevated choir gallery.
        surface("east-flight-1",WalkRect(x:31.7,z:-39,width:3.4,depth:6),y:1,slopeZ:1/3,ceiling:17,stairs:true)
        surface("east-landing-1",WalkRect(x:31.7,z:-34.5,width:3.4,depth:3),y:2,ceiling:17)
        surface("east-flight-2",WalkRect(x:38,z:-34.5,width:9.2,depth:3),y:3,slopeX:2/9.2,ceiling:17,stairs:true)
        surface("east-landing-2",WalkRect(x:44.3,z:-34.5,width:3.4,depth:3),y:4,ceiling:17)
        surface("east-flight-3",WalkRect(x:44.3,z:-41,width:3.4,depth:10),y:5,slopeZ:-0.2,ceiling:17,stairs:true)
        surface("furnace-upper-gallery",WalkRect(x:38,z:-50.5,width:16,depth:9),y:6,ceiling:17)
        railing(v3(33.4,0,-42),v3(33.4,2,-36))
        railing(v3(33.4,2,-36),v3(42.6,4,-36))
        railing(v3(42.6,4,-36),v3(42.6,6,-46))
        railing(v3(30.3,6,-46),v3(42.5,6,-46))
        // Cathedral nave: tall clustered piers frame textured vaults above the clear early route.
        for zz:Float in [2,-6,-14] {
            for xx:Float in [-6.8,6.8] {pillar(xx,zz,height:9.8);brazier(xx*0.9,zz-1.4)}
            arch(0,zz,width:13.6,base:9.8,rise:4.0)
            for xx:Float in [-8.7,8.7] {stainedWindow(xx,3.0,zz-3.2,width:2.5,height:5.5,rotation:xx<0 ? .pi/2:-.pi/2)}
        }
        for xx:Float in [-6.8,6.8] {
            for zz:Float in [-2,-10] {arch(xx,zz,width:8,base:9.8,rise:1.15,alongZ:true,radius:0.12)}
        }
        elevated(3.6){chandelier(0,-5)};rod(v3(0,12.45,-5),v3(0,13.9,-5),radius:0.025,material:dark)
        for zz:Float in [-5,-13] {funeraryRelief(-8.73,zz,rotation:.pi/2);funeraryRelief(8.73,zz,rotation:-.pi/2)}
        stainedWindow(0,3.2,7.73,width:3.3,height:5.8,rotation:.pi)
        for xx:Float in [-4.5,4.5] {banner(xx,-17.72)}
        for zz:Float in [-18,-30,-56,-72,-96,-106] {portal(0,zz)}
        for xx:Float in [-12,-30,12,30] {portal(xx,-44,alongZ:true)}
        for zz:Float in [-22,-27,-61,-67,-100] {arch(0,zz,width:5.65,base:4.0,rise:3.5,radius:0.13)}
        for xx:Float in [-25,-18,18,25] {arch(xx,-44,width:5.65,base:4.0,rise:3.5,alongZ:true,radius:0.13)}
        for zz:Float in [-24,-63,-100] {hangingIron(zz)}
        for zz:Float in [-34,-52] {
            for xx:Float in [-8.1,8.1] {pillar(xx,zz,height:12.8,radius:0.56)}
            arch(0,zz,width:16.2,base:12.8,rise:4.7)
        }
        for xx:Float in [-11.72,11.72] {
            for zz:Float in [-35,-52] {stainedWindow(xx,4.0,zz,width:2.7,height:7,rotation:xx<0 ? .pi/2:-.pi/2)}
        }
        elevated(6.6){chandelier(0,-43)};rod(v3(0,15.45,-43),v3(0,17.9,-43),radius:0.025,material:dark)
        for xx:Float in [-5.1,5.1] {banner(xx,-55.72);brazier(xx,-53.9)}
        wayfindingPlaque("WEST · DESCEND", "OSSUARY", x:-10.35,z:-40.45,side:-1)
        wayfindingPlaque("EAST · ASCEND", "FURNACE", x:10.35,z:-40.45,side:1)
        wayfindingPlaque("NORTH", "CRYPT", x:0,z:-55.60,side:0)
        // The sunken ossuary has actual room below the entry and no floor at the former level.
        elevated(-6) {
            tomb(-41,-50);tomb(-34.5,-50)
            for xx:Float in [-41.7,-34] {brazier(xx,-52.4);banner(xx,-54.72)}
            sigilDais(-38,-51);funeraryRelief(-38,-54.73)
            stainedWindow(-45.72,2.0,-50,width:2.8,height:4.6,rotation:.pi/2)
        }
        for zz:Float in [-39,-51] {arch(-38,zz,width:13,base:7.5,rise:5.5)}
        stainedWindow(-45.72,2.8,-42,width:3.2,height:5.3,rotation:.pi/2)
        // Pillars support the gallery slab from below and terminate below its walking surface.
        for xx:Float in [33,43] {pillar(xx,-51,height:5.6,radius:0.48)}
        for xx:Float in [34.5,41.5] {brazier(xx,-42);elevated(6){brazier(xx,-53.5)}}
        elevated(6){sigilDais(38,-51);funeraryRelief(38,-54.73);banner(33,-54.72);banner(43,-54.72)}
        for zz:Float in [-39,-51] {arch(38,zz,width:13,base:10.6,rise:5.5)}
        stainedWindow(45.72,7.0,-50,width:3.2,height:4.8,rotation:-.pi/2,hot:true)
        for zz:Float in [-36,-52] {box(7,0.055,0.8,38,0.025,zz,dark);box(6.5,0.02,0.12,38,0.06,zz,amber)}
        // The central crypt preserves ground-level combat beneath a sixteen-metre vault.
        for zz:Float in [-77,-90] {
            for xx:Float in [-9.5,9.5] {pillar(xx,zz,height:11.8,radius:0.62);tomb(xx*0.64,zz)}
            arch(0,zz,width:19,base:11.8,rise:4.0)
        }
        for xx:Float in [-13.72,13.72] {
            for zz:Float in [-78,-87] {stainedWindow(xx,3.5,zz,width:3.2,height:6.5,rotation:xx<0 ? .pi/2:-.pi/2)}
        }
        for xx:Float in [-7,7] {banner(xx,-95.72);brazier(xx,-93.7)}
        sigilDais(0,-92)
        for xx:Float in [-10.6,10.6] {funeraryRelief(xx,-95.73)}
        stainedWindow(0,3.0,-121.72,width:4.8,height:5.6)
        for xx:Float in [-5.3,5.3] {pillar(xx,-117,height:9.5,radius:0.48);brazier(xx,-111)}
        arch(0,-117,width:10.6,base:9.5,rise:4.0);sigilDais(0,-116)
        // Warm dusty light keeps the relief readable without luminous white glass.
        point(0,6,-4,color:color(0.64,0.45,0.28),intensity:680,reach:25)
        point(0,3,-15,color:color(1,0.47,0.19),intensity:500,reach:15)
        point(0,4,-25,color:color(0.47,0.35,0.25),intensity:390,reach:12)
        point(0,8,-43,color:color(0.63,0.44,0.28),intensity:950,reach:29)
        point(-38,-2.7,-47,color:color(0.80,0.39,0.17),intensity:760,reach:19)
        point(-35,2.8,-37,color:color(0.55,0.39,0.25),intensity:580,reach:17)
        point(38,3.0,-40,color:color(0.86,0.37,0.14),intensity:700,reach:17)
        point(38,9.0,-50,color:color(0.85,0.44,0.20),intensity:730,reach:17)
        point(0,4,-64,color:color(0.78,0.43,0.22),intensity:450,reach:14)
        point(-8,5.5,-84,color:color(0.50,0.39,0.28),intensity:790,reach:21)
        point(8,5,-84,color:color(0.60,0.36,0.20),intensity:760,reach:21)
        point(0,3,-94,color:color(1,0.50,0.24),intensity:550,reach:14)
        point(0,5,-116,color:color(0.63,0.43,0.25),intensity:850,reach:20)
        root.name="Black Reliquary — the vaulted cathedral"
        let enemies:[EnemySpawn]=[
            .init(x:-3,z:-10,kind:0),.init(x:4,z:-15,kind:0),.init(x:0,z:-27,kind:0),
            .init(x:-4,z:-36,kind:0),.init(x:4,z:-39,kind:1),.init(x:1,z:-51,kind:0),
            .init(x:-20,z:-44,kind:0),.init(x:-37,z:-39,kind:0,y:-6),.init(x:-40,z:-47,kind:1,y:-6),.init(x:-35,z:-47,kind:0,y:-6),
            .init(x:22,z:-44,kind:0),.init(x:38,z:-40,kind:0),.init(x:40,z:-50,kind:1,y:6),.init(x:36,z:-50,kind:0,y:6),
            .init(x:0,z:-68,kind:0),.init(x:-3,z:-76,kind:0),.init(x:4,z:-78,kind:1),
            .init(x:-10,z:-85,kind:0),.init(x:10,z:-85,kind:0),.init(x:-3,z:-91,kind:1),.init(x:4,z:-93,kind:0),.init(x:0,z:-112,kind:1),
            .init(x:-4,z:-46,kind:2),.init(x:-38,z:-46,kind:2,y:-6),.init(x:38,z:-48,kind:2,y:6),.init(x:0,z:-83,kind:2)
        ]
        let pickups:[PickupSpawn]=[
            .init(x:2,z:3,kind:1),.init(x:-2,z:3,kind:2),.init(x:-7.7,z:-10,kind:0),.init(x:7.7,z:-10,kind:1),
            .init(x:-5,z:-33,kind:1),.init(x:5,z:-33,kind:2),.init(x:0,z:-54,kind:0),
            .init(x:-38,z:-39,kind:1,y:-6),.init(x:-40,z:-43,kind:0,y:-6),.init(x:-35,z:-48,kind:2,y:-6),
            .init(x:38,z:-52,kind:1,y:6),.init(x:44,z:-50,kind:0,y:6),.init(x:35,z:-48,kind:2,y:6),
            .init(x:-1.5,z:-70,kind:1),.init(x:1.5,z:-70,kind:2),.init(x:0,z:-73,kind:0),
            .init(x:-12,z:-90,kind:0),.init(x:12,z:-90,kind:1),.init(x:0,z:-87,kind:2),.init(x:0,z:-104,kind:0),
            .init(x:0,z:-6,kind:3),.init(x:-31.5,z:-44,kind:3),.init(x:31.5,z:-44,kind:3)
        ]
        let names=["THE ASHEN NAVE","GALLERY OF WHISPERS","THE SUNDERED CROSSING","WESTERN CLOISTER","THE LOWER OSSUARY","EASTERN CLOISTER","FURNACE CHAPEL","THE PENITENT'S WALK","CRYPT OF THE FORSAKEN","THE LAST PROCESSION","THE BLACK RELIQUARY"]
        var zones=zip(names,walkable).enumerated().map{Zone(name:$0.element.0,rect:$0.element.1,y:$0.offset==4 ? -6:0)}
        zones += [Zone(name:"OSSUARY · UPPER DESCENT",rect:WalkRect(x:-31.7,z:-40,width:3.4,depth:12),y:-1),Zone(name:"OSSUARY · WINDING STAIR",rect:WalkRect(x:-38,z:-34.5,width:16,depth:3),y:-3),Zone(name:"OSSUARY · LOWER DESCENT",rect:WalkRect(x:-44.3,z:-41,width:3.4,depth:10),y:-5),Zone(name:"FURNACE · ASCENDING STAIR",rect:WalkRect(x:31.7,z:-39,width:3.4,depth:6),y:1),Zone(name:"FURNACE · UPPER STAIR",rect:WalkRect(x:38,z:-34.5,width:16,depth:3),y:3),Zone(name:"FURNACE · GALLERY STAIR",rect:WalkRect(x:44.3,z:-41,width:3.4,depth:10),y:5),Zone(name:"FURNACE · CHOIR GALLERY",rect:WalkRect(x:38,z:-50.5,width:16,depth:9),y:6)]
        return WorldData(root:root,walkable:walkable,obstacles:obstacles,spawn:v3(0,1.65,4),enemies:enemies,pickups:pickups,sigils:[v3(-38,-4.8,-51),v3(38,7.2,-51),v3(0,1.2,-92)],exit:v3(0,0,-116),zones:zones,surfaces:surfaces,solids:solids)
    }
}

func buildWorld() -> WorldData {WorldBuilder().build()}
