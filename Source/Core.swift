import AppKit
import SceneKit
import simd

struct WalkRect {
    var x: Float; var z: Float; var width: Float; var depth: Float
    func contains(_ x: Float, _ z: Float, margin: Float = 0) -> Bool {
        abs(x-self.x) <= width/2-margin && abs(z-self.z) <= depth/2-margin
    }
}
struct EnemySpawn { var x: Float; var z: Float; var kind: Int }
struct PickupSpawn { var x: Float; var z: Float; var kind: Int } // 0 health, 1 shells, 2 rockets
struct Zone { var name: String; var rect: WalkRect }
struct WorldData {
    let root: SCNNode
    let walkable: [WalkRect]
    let obstacles: [WalkRect]
    let spawn: SCNVector3
    let enemies: [EnemySpawn]
    let pickups: [PickupSpawn]
    let sigils: [SCNVector3]
    let exit: SCNVector3
    let zones: [Zone]
}
func v3(_ x: Float, _ y: Float, _ z: Float) -> SCNVector3 { SCNVector3(x,y,z) }
func distanceXZ(_ a: SCNVector3, _ b: SCNVector3) -> Float { hypot(Float(a.x-b.x), Float(a.z-b.z)) }
func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor { NSColor(calibratedRed:r,green:g,blue:b,alpha:a) }
func simpleMaterial(_ c: NSColor, emission: NSColor? = nil) -> SCNMaterial {
    let m = SCNMaterial(); m.diffuse.contents = c; m.roughness.contents = 0.85
    if let e = emission { m.emission.contents = e }; return m
}
