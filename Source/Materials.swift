import AppKit
import SceneKit
import simd

/// Original, tileable cathedral surfaces, synthesized once and shared across resets.
/// Color and tangent-space normals come from the same worn relief; no external assets.
final class GothicMaterials {
    static let shared = GothicMaterials()
    let stone: SCNMaterial
    let floor: SCNMaterial
    let ceiling: SCNMaterial
    let trim: SCNMaterial
    let iron: SCNMaterial

    private init() {
        stone = CathedralSurface.make(.stone)
        floor = CathedralSurface.make(.floor)
        ceiling = CathedralSurface.make(.ceiling)
        trim = CathedralSurface.make(.trim)
        iron = CathedralSurface.make(.iron)
    }
}

private enum CathedralSurface {
    enum Kind: Int { case stone = 11, floor = 29, ceiling = 47, trim = 71, iron = 97 }
    static let side = 1024

    struct Random {
        var state: UInt32
        mutating func unit() -> Float {
            state = state &* 1664525 &+ 1013904223
            return Float(state & 0x00ffffff) / Float(0x01000000)
        }
    }

    /// Periodic value noise, with smooth lattice interpolation and no texture seam.
    struct Field {
        let count: Int
        let rows: Int
        let values: [Float]
        init(_ count: Int, seed: UInt32, rows: Int? = nil) {
            self.count = count
            self.rows = rows ?? count
            var random = Random(state: seed)
            values = (0..<(count * self.rows)).map { _ in random.unit() }
        }
        @inline(__always) func sample(_ x: Float, _ y: Float) -> Float {
            let u = x * Float(count) / Float(side), v = y * Float(rows) / Float(side)
            let ix = Int(floorf(u)), iy = Int(floorf(v))
            let fx = u - floorf(u), fy = v - floorf(v)
            let sx = fx * fx * (3 - 2 * fx), sy = fy * fy * (3 - 2 * fy)
            let xx = (ix % count + count) % count, yy = (iy % rows + rows) % rows
            let nx = (xx + 1) % count, ny = (yy + 1) % rows
            let a = values[yy * count + xx], b = values[yy * count + nx]
            let c = values[ny * count + xx], d = values[ny * count + nx]
            return (a + (b-a)*sx) * (1-sy) + (c + (d-c)*sx) * sy
        }
    }

    struct Course {
        let bottom: Float
        let top: Float
        let offset: Float
        let bounds: [Float]
        let tones: [Float]
    }

    @inline(__always) static func clamp(_ value: Float, _ lo: Float = 0, _ hi: Float = 1) -> Float {
        min(hi, max(lo, value))
    }
    @inline(__always) static func smooth(_ a: Float, _ b: Float, _ value: Float) -> Float {
        let t = clamp((value - a) / (b - a))
        return t * t * (3 - 2*t)
    }
    @inline(__always) static func ring(_ distance: Float, width: Float) -> Float {
        let t = clamp(1 - abs(distance) / width)
        return t*t*(3 - 2*t)
    }
    @inline(__always) static func wrap(_ value: Float, period: Float = Float(side)) -> Float {
        value - floorf(value / period) * period
    }

    static func courses(_ kind: Kind) -> [Course] {
        var random = Random(state: UInt32(kind.rawValue * 9719))
        let heights: [Float] = kind == .floor ? [318, 367, 339] : [172, 178, 149, 186, 170, 169]
        var bottom: Float = 0
        return heights.enumerated().map { row, height in
            let count = kind == .floor ? 3 : (row % 3 == 0 ? 3 : 4)
            var widths = (0..<count).map { _ in 0.79 + random.unit() * 0.42 }
            let sum = widths.reduce(0,+)
            widths = widths.map { $0 * Float(side) / sum }
            var bounds: [Float] = [0]
            for width in widths { bounds.append(bounds.last! + width) }
            bounds[count] = Float(side)
            let course = Course(bottom: bottom, top: bottom + height,
                                offset: random.unit() * 270,
                                bounds: bounds,
                                tones: (0..<count).map { _ in 0.91 + random.unit()*0.20 })
            bottom += height
            return course
        }
    }

    static func make(_ kind: Kind) -> SCNMaterial {
        let seed = UInt32(kind.rawValue * 913 + 7727)
        let cloud = Field(4, seed: seed)
        let stain = Field(11, seed: seed &+ 179)
        let wear = Field(37, seed: seed &+ 571)
        let grit = Field(113, seed: seed &+ 1511)
        let sand = Field(251, seed: seed &+ 2341)
        let veins = Field(19, seed: seed &+ 3389)
        let streaks = Field(43, seed: seed &+ 4799, rows: 4)
        let rows = courses(kind)
        var heights = [Float](repeating: 0, count: side*side)
        var colors = [SIMD3<Float>](repeating: .zero, count: side*side)
        var roughness = [Float](repeating: 0.9, count: side*side)
        var random = Random(state: seed &+ 8513)

        for y in 0..<side {
            let fy = Float(y)
            for x in 0..<side {
                let fx = Float(x), index = y*side+x
                let large = cloud.sample(fx,fy), medium = stain.sample(fx,fy)
                let worn = wear.sample(fx,fy), granular = grit.sample(fx,fy)
                let grains = sand.sample(fx,fy)
                let grain = random.unit()
                let patches = smooth(0.35,0.83,medium) * (0.55 + large*0.45)
                let pits = powf(clamp((0.37-granular)*3.1),2)
                let mineral = smooth(0.64,0.94,veins.sample(fx,fy))
                var relief: Float = 0.5
                var tone: Float = 0.40
                var tint = SIMD3<Float>(1.09,0.94,0.795)

                switch kind {
                case .stone, .floor:
                    // Warp the courses and each joint gently; chipped edges are
                    // modeled as rounded height transitions rather than dark outlines.
                    let bend = (veins.sample(fx,fy)-0.5) * (kind == .floor ? 15 : 10)
                    let yy = wrap(fy + bend)
                    let row = rows.first { yy >= $0.bottom && yy < $0.top } ?? rows[0]
                    let xx = wrap(fx + row.offset + (worn-0.5)*7)
                    var col = 0
                    while col+1 < row.bounds.count-1 && xx >= row.bounds[col+1] { col += 1 }
                    let edge = min(yy-row.bottom,row.top-yy,xx-row.bounds[col],row.bounds[col+1]-xx)
                    let chips = max(0,(0.47-granular)*11) + max(0,(0.31-worn)*22)
                    let face = smooth(1.6,11.5,edge-chips)
                    let rim = ring(edge-12,width:6) * 0.022
                    relief = 0.19 + face*0.35 + rim + (worn-0.5)*0.045 - pits*0.047
                    tone = (kind == .floor ? 0.405 : 0.435) * row.tones[col]
                    tone *= 0.79 + face*0.21
                    tone += rim*0.38
                    tone -= (1-face)*0.055
                    if kind == .floor {
                        // Broad worn centers and iron-brown dirt in flagstone joints.
                        relief -= smooth(25,145,edge)*0.045
                        tone += smooth(17,115,edge)*0.023
                        tint = SIMD3<Float>(1.04,0.963,0.835)
                    } else {
                        tone -= smooth(0.32,0.8,streaks.sample(fx,fy))*0.055
                    }
                case .ceiling:
                    let px = wrap(fx,period:512)-256, py = wrap(fy,period:512)-256
                    let edge = 256-max(abs(px),abs(py))
                    let radius = hypotf(px,py), angle = atan2f(py,px)
                    // Two carved coffers in each direction, framed by stepped ribs.
                    relief = 0.31 + ring(edge-10,width:9)*0.21
                    relief += ring(edge-33,width:8)*0.14 + ring(edge-56,width:7)*0.12
                    relief -= ring(edge-22,width:3)*0.065 + ring(edge-44,width:3)*0.05
                    let diagonal = abs(abs(px)-abs(py)) * 0.7071
                    relief += ring(diagonal,width:5.5)*0.065*smooth(116,168,radius)
                    let rosette = 73 + 16*cosf(angle*8)
                    relief += ring(radius-rosette,width:5)*0.18
                    relief -= ring(radius-rosette-8,width:2.5)*0.055
                    relief += ring(radius-34,width:4)*0.095
                    relief += ring(radius-10,width:10)*0.15
                    relief += ring(radius-(49+7*cosf(angle*8)),width:2.6)*0.075
                    // Four trefoil carvings sit between the central rose and ribs.
                    for p in [SIMD2<Float>(0,151),SIMD2<Float>(151,0),SIMD2<Float>(0,-151),SIMD2<Float>(-151,0)] {
                        let q = SIMD2<Float>(px,py)-p
                        if abs(q.x)<49 && abs(q.y)<49 {
                            let a = atan2f(q.y,q.x)-atan2f(p.y,p.x)
                            let contour = 27+8*cosf(a*3)
                            let d = simd_length(q)-contour
                            relief += ring(d,width:3.8)*0.12
                            relief -= ring(d-6,width:2.1)*0.05
                            relief += ring(simd_length(q)-10,width:2)*0.047
                        }
                    }
                    let bead = ring(edge-77,width:3.2)
                    let along = abs(px)>abs(py) ? py : px
                    relief += bead*powf(0.5+0.5*cosf(along*Float.pi/11),3)*0.065
                    tone = 0.335 + (relief-0.31)*0.26
                    tone -= ring(edge-22,width:4)*0.035
                    tint = SIMD3<Float>(1.09,0.96,0.775)
                case .trim:
                    let yy = wrap(fy,period:256)
                    relief = 0.36 + ring(yy-18,width:13)*0.16 + ring(yy-237,width:13)*0.16
                    relief += ring(yy-45,width:7)*0.095 + ring(yy-210,width:7)*0.095
                    relief -= ring(yy-31,width:3)*0.06 + ring(yy-223,width:3)*0.06
                    let px = wrap(fx,period:128)-64, py = yy-128
                    let a = atan2f(py,px), r = hypotf(px,py)
                    relief += ring(r-(34+10*cosf(a*3)),width:4.7)*0.11
                    relief -= ring(r-(42+10*cosf(a*3)),width:2.2)*0.05
                    relief += ring(yy-70,width:3.3)*powf(0.5+0.5*cosf(fx*Float.pi/16),2)*0.055
                    relief += ring(yy-184,width:3.3)*powf(0.5+0.5*cosf(fx*Float.pi/16),2)*0.055
                    tone = 0.365 + (relief-0.36)*0.25
                    tint = SIMD3<Float>(1.075,0.96,0.795)
                case .iron:
                    let corrosion = smooth(0.39,0.74,medium)*smooth(0.22,0.77,worn)
                    relief = 0.39 + (worn-0.5)*0.032 - pits*0.075
                    relief += corrosion*0.017
                    tone = 0.155 + large*0.047 + corrosion*0.033
                    tint = SIMD3<Float>(1.04+corrosion*0.29,0.975-corrosion*0.13,0.87-corrosion*0.24)
                    roughness[index] = 0.68 + corrosion*0.23
                }

                // Multi-scale mineral mottling, smoky stains and fine sandstone pores.
                let finish: Float = kind == .iron ? 0.42 : 1
                tone += ((large-0.5)*0.084 + (worn-0.5)*0.074 + (grain-0.5)*0.054)*finish
                tone += ((granular-0.5)*0.043 + (grains-0.5)*0.041)*finish
                tone -= patches*0.068*finish + pits*0.040
                tone += mineral*0.023*finish
                relief += (granular-0.5)*0.020 + (grains-0.5)*0.009 + (grain-0.5)*0.004
                // Tiny fractured mineral faces break up broad cloudy weathering.
                let flake = smooth(0.58,0.88,grains)*smooth(0.32,0.70,granular)
                tone -= flake*0.039*finish
                relief -= flake*0.022
                if grain < 0.027 { relief -= 0.018; tone -= 0.031 }
                heights[index] = relief
                colors[index] = tint * max(0.075,tone)
                if kind != .iron { roughness[index] = clamp(0.84+patches*0.1+pits*0.045) }
            }
        }

        carveCracks(kind,heights:&heights,colors:&colors,seed:seed &+ 9929)
        return material(kind,heights:heights,colors:colors,roughness:roughness)
    }

    static func carveCracks(_ kind: Kind, heights: inout [Float], colors: inout [SIMD3<Float>], seed: UInt32) {
        var random = Random(state: seed)
        let count = kind == .stone ? 39 : kind == .floor ? 31 : kind == .iron ? 29 : 23
        for _ in 0..<count {
            var point = SIMD2<Float>(random.unit()*Float(side),random.unit()*Float(side))
            let direction = random.unit()*Float.pi*2
            let width: Float = kind == .iron ? 0.55 : 0.4+random.unit()*0.75
            let depth: Float = kind == .iron ? 0.018 : 0.024+random.unit()*0.019
            let segments = 3+Int(random.unit()*6)
            for segment in 0..<segments {
                let angle = direction+(random.unit()-0.5)*1.8
                let length = 6+random.unit()*20
                let next = point+SIMD2<Float>(cosf(angle),sinf(angle))*length
                groove(point,next,width:width,depth:depth,heights:&heights,colors:&colors)
                if segment == 2 && random.unit()<0.65 {
                    let branchAngle = angle+0.8
                    let end = point+SIMD2<Float>(cosf(branchAngle),sinf(branchAngle))*(8+random.unit()*15)
                    groove(point,end,width:width*0.6,depth:depth*0.7,heights:&heights,colors:&colors)
                }
                point = next
            }
        }
    }

    static func groove(_ a: SIMD2<Float>, _ b: SIMD2<Float>, width: Float, depth: Float,
                       heights: inout [Float], colors: inout [SIMD3<Float>]) {
        let direction = b-a, denominator = max(0.001,simd_length_squared(direction))
        let loX = Int(floorf(min(a.x,b.x)-width-1)), hiX = Int(ceilf(max(a.x,b.x)+width+1))
        let loY = Int(floorf(min(a.y,b.y)-width-1)), hiY = Int(ceilf(max(a.y,b.y)+width+1))
        for y in loY...hiY {
            for x in loX...hiX {
                let point = SIMD2<Float>(Float(x)+0.5,Float(y)+0.5)
                let t = clamp(simd_dot(point-a,direction)/denominator)
                let distance = simd_length(point-(a+direction*t))
                let amount = 1-smooth(width*0.35,width+0.8,distance)
                if amount > 0 {
                    let xx = (x%side+side)%side, yy = (y%side+side)%side, index = yy*side+xx
                    heights[index] -= depth*amount
                    colors[index] *= 1-amount*0.14
                }
            }
        }
    }

    static func image(_ bytes: [UInt8]) -> NSImage {
        let data = Data(bytes) as CFData
        let provider = CGDataProvider(data:data)!
        let bitmap = CGImage(width:side,height:side,bitsPerComponent:8,bitsPerPixel:32,
                             bytesPerRow:side*4,space:CGColorSpaceCreateDeviceRGB(),
                             bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.premultipliedLast.rawValue),
                             provider:provider,decode:nil,shouldInterpolate:true,intent:.defaultIntent)!
        return NSImage(cgImage:bitmap,size:NSSize(width:side,height:side))
    }

    static func material(_ kind: Kind, heights: [Float], colors: [SIMD3<Float>], roughness: [Float]) -> SCNMaterial {
        var diffuse = [UInt8](repeating:255,count:side*side*4)
        var normals = diffuse
        var rough = diffuse
        let strength: Float = kind == .iron ? 7 : kind == .ceiling || kind == .trim ? 13 : 10
        for y in 0..<side {
            let above = ((y+side-1)%side)*side, below = ((y+1)%side)*side
            for x in 0..<side {
                let index = y*side+x, offset = index*4
                let dx = heights[y*side+(x+1)%side]-heights[y*side+(x+side-1)%side]
                let dy = heights[below+x]-heights[above+x]
                let normal = simd_normalize(SIMD3<Float>(-dx*strength,dy*strength,1))
                for channel in 0..<3 {
                    diffuse[offset+channel] = UInt8(clamp(colors[index][channel])*255)
                    normals[offset+channel] = UInt8(clamp(normal[channel]*0.5+0.5)*255)
                    rough[offset+channel] = UInt8(clamp(roughness[index])*255)
                }
            }
        }
        let result = SCNMaterial()
        result.name = "gothic-\(kind)-1024"
        result.diffuse.contents = image(diffuse)
        result.normal.contents = image(normals)
        result.roughness.contents = image(rough)
        // Match the game's direct-light shading while retaining roughness maps
        // for material copies that choose physically based lighting later.
        result.lightingModel = .blinn
        result.shininess = kind == .iron ? 0.13 : 0.035
        result.specular.contents = NSColor(calibratedWhite:kind == .iron ? 0.20 : 0.085,alpha:1)
        result.normal.intensity = 0.9
        for property in [result.diffuse,result.normal,result.roughness] {
            property.wrapS = .repeat; property.wrapT = .repeat
            property.minificationFilter = .linear; property.magnificationFilter = .linear
            property.mipFilter = .linear; property.maxAnisotropy = 8
        }
        return result
    }
}
