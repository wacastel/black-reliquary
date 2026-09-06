import AppKit
import SceneKit
import simd

final class Foe {
    let node: SCNNode; let kind: Int; let home: SIMD3<Float>
    var position: SIMD3<Float>; var health: Float; var cooldown: Float = 1
    var active=false; var route=[SIMD2<Float>](); var repath: Float=0; var flash:Float=0
    let body: SCNNode; let left:SCNNode; let right:SCNNode
    init(spawn:EnemySpawn) {
        kind=spawn.kind; position=SIMD3(spawn.x,0,spawn.z); home=position; health=kind==0 ? 105:85
        node=SCNNode(); body=SCNNode(); left=SCNNode(); right=SCNNode()
        let iron=simpleMaterial(color(0.12,0.135,0.14))
        let edge=simpleMaterial(color(0.24,0.235,0.20))
        let bone=simpleMaterial(color(0.34,0.325,0.26))
        let oldBone=simpleMaterial(color(0.235,0.225,0.18))
        let black=simpleMaterial(color(0.009,0.011,0.013))
        let cloth=simpleMaterial(kind==0 ? color(0.13,0.025,0.018):color(0.035,0.075,0.085))
        let clothLight=simpleMaterial(kind==0 ? color(0.19,0.044,0.025):color(0.06,0.12,0.13))
        for mat in [iron,edge,bone,oldBone,black,cloth,clothLight] {
            mat.lightingModel = .blinn; mat.shininess = 0.05
        }
        func part(_ g:SCNGeometry,_ p:SIMD3<Float>,_ mat:SCNMaterial,_ parent:SCNNode) -> SCNNode {
            g.materials=[mat]; let n=SCNNode(geometry:g); n.position=SCNVector3(p); n.categoryBitMask=2; parent.addChildNode(n); return n
        }
        func box(_ x:CGFloat,_ y:CGFloat,_ z:CGFloat,_ bevel:CGFloat=0)->SCNBox {
            let g=SCNBox(width:x,height:y,length:z,chamferRadius:bevel)
            g.chamferSegmentCount=1;return g
        }
        func cone(_ top:CGFloat,_ bottom:CGFloat,_ height:CGFloat,_ sides:Int=5)->SCNCone {
            let g=SCNCone(topRadius:top,bottomRadius:bottom,height:height)
            g.radialSegmentCount=sides;g.heightSegmentCount=1;return g
        }
        // Flat triangular faces keep the robe silhouette torn instead of bell-shaped.
        func shard(_ vertices:[SIMD3<Float>],_ mat:SCNMaterial,_ parent:SCNNode) {
            let normal=simd_normalize(simd_cross(vertices[1]-vertices[0],vertices[2]-vertices[0]))
            let g=SCNGeometry(sources:[SCNGeometrySource(vertices:vertices.map{SCNVector3($0)}),SCNGeometrySource(normals:Array(repeating:SCNVector3(normal),count:3))],elements:[SCNGeometryElement(indices:[Int32(0),1,2],primitiveType:.triangles)])
            mat.isDoubleSided=true
            _=part(g,.zero,mat,parent)
        }
        node.addChildNode(body)
        _=part(cone(0.285,kind==0 ? 0.39:0.47,0.82,8),SIMD3(0,0.88,0.035),cloth,body)
        for i in 0..<8 {
            let a=Float(i)*Float.pi/4, b=a+Float.pi/4
            let radius:Float=kind==0 ? 0.39:0.47
            let bottom:Float = kind==0 ? (i%2==0 ? 0.17:0.28):(i%2==0 ? 0.04:0.22)
            let mid=(a+b)/2
            shard([SIMD3(cos(a)*radius,0.55,sin(a)*radius+0.035),SIMD3(cos(b)*radius,0.55,sin(b)*radius+0.035),SIMD3(cos(mid)*(radius+0.055),bottom,sin(mid)*(radius+0.055)+0.035)],i%3==0 ? clothLight:cloth,body)
        }
        // A narrow hanging stole divides the armor and ends in a ragged point.
        shard([SIMD3(-0.13,1.18,-0.30),SIMD3(0.13,1.18,-0.30),SIMD3(0.055,0.35,-0.43)],clothLight,body)
        let chest=part(box(0.66,0.48,0.40,0.045),SIMD3(0,1.35,-0.005),iron,body)
        chest.eulerAngles.z=0.04
        for side:Float in [-1,1] {
            let plate=part(box(0.27,0.28,0.065,0.015),SIMD3(side*0.17,1.40,-0.232),edge,body)
            plate.eulerAngles.z=CGFloat(side*0.17)
            let rib=part(box(0.245,0.055,0.05),SIMD3(side*0.16,1.24,-0.235),oldBone,body)
            rib.eulerAngles.z=CGFloat(-side*0.19)
        }
        _=part(box(0.075,0.39,0.09,0.01),SIMD3(0,1.35,-0.255),iron,body)
        _=part(box(0.47,0.07,0.37,0.008),SIMD3(0,1.06,0),edge,body)
        _=part(box(0.105,0.14,0.04),SIMD3(0,1.05,-0.21),oldBone,body)
        // Faceted cowl and an elongated death mask. No spherical skull or eyes.
        let cowl=part(cone(0.035,0.37,kind==0 ? 0.74:0.88,6),SIMD3(0,1.94,0.115),kind==0 ? iron:cloth,body)
        cowl.eulerAngles.y = .pi/6
        _=part(box(0.37,0.43,0.31,0.065),SIMD3(0,1.93,-0.035),bone,body)
        _=part(box(0.31,0.17,0.25,0.025),SIMD3(0,1.672,-0.058),oldBone,body)
        _=part(box(0.25,0.079,0.023),SIMD3(0,1.748,-0.233),black,body)
        for side:Float in [-1,1] {
            let cheek=part(box(0.108,0.19,0.12,0.023),SIMD3(side*0.153,1.805,-0.159),bone,body)
            cheek.eulerAngles.z=CGFloat(-side*0.34)
            let socket=part(box(0.145,0.072,0.041,0.008),SIMD3(side*0.092,1.963,-0.218),black,body)
            socket.eulerAngles.z=CGFloat(side*0.16)
            let glow=kind==0 ? color(0.9,0.14,0.016):color(0.04,0.64,0.81)
            let slit=part(box(0.09,0.019,0.007),SIMD3(side*0.092,1.96,-0.244),simpleMaterial(glow,emission:glow),body)
            slit.eulerAngles.z=CGFloat(side*0.16)
            let brow=part(box(0.18,0.055,0.10,0.008),SIMD3(side*0.096,2.015,-0.184),oldBone,body)
            brow.eulerAngles.z=CGFloat(side*0.19)
            if kind==0 {
                let horn=part(cone(0,0.072,0.32,4),SIMD3(side*0.255,2.105,0.07),iron,body)
                horn.eulerAngles.z=CGFloat(-side*0.31)
            }
            for tooth in 0..<2 {
                let fang=part(cone(0,0.020,tooth==0 ? 0.092:0.068,3),SIMD3(side*(0.043+Float(tooth)*0.047),1.727,-0.238),bone,body)
                fang.eulerAngles.z = .pi
            }
        }
        let nose=part(cone(0.025,0.061,0.15,3),SIMD3(0,1.849,-0.215),oldBone,body)
        nose.eulerAngles.z = .pi
        shard([SIMD3(-0.055,2.125,-0.198),SIMD3(-0.016,2.068,-0.198),SIMD3(-0.027,2.069,-0.198)],black,body)
        shard([SIMD3(-0.02,2.071,-0.199),SIMD3(0.010,2.049,-0.199),SIMD3(-0.001,2.085,-0.199)],black,body)
        // Heavy angular pauldrons, exposed wrist bones, and forward-curving talons.
        for (side,arm) in [(-1 as Float,left),(1 as Float,right)] {
            arm.position=SCNVector3(SIMD3(side*0.48,1.42,0)); body.addChildNode(arm)
            let shoulder=part(box(0.32,0.19,0.40,0.03),SIMD3(side*0.015,0.09,0.015),iron,arm)
            shoulder.eulerAngles.z=CGFloat(-side*0.23)
            let edgePlate=part(box(0.27,0.045,0.43,0.008),SIMD3(side*0.02,0.025,0.008),edge,arm)
            edgePlate.eulerAngles.z=CGFloat(-side*0.23)
            let upper=part(box(0.175,0.33,0.22,0.026),SIMD3(side*0.035,-0.19,0.015),iron,arm)
            upper.eulerAngles.z=CGFloat(side*0.1)
            _=part(box(0.155,0.10,0.22,0.017),SIMD3(side*0.05,-0.385,-0.025),edge,arm)
            let forearm=part(cone(0.09,0.065,0.30,5),SIMD3(side*0.035,-0.49,-0.025),oldBone,arm)
            forearm.eulerAngles.x = -0.14
            _=part(box(0.16,0.145,0.12,0.023),SIMD3(side*0.026,-0.66,-0.06),bone,arm)
            for j in 0..<3 {
                let x=Float(j-1)*0.056+side*0.026
                let claw=part(cone(0,0.025,0.25+CGFloat(j%2)*0.06,3),SIMD3(x,-0.825,-0.118),oldBone,arm)
                claw.eulerAngles.x = .pi-0.38
            }
            let thorn=part(cone(0,0.085,kind==0 ? 0.29:0.42,4),SIMD3(side*0.10,0.29,0.035),iron,arm)
            thorn.eulerAngles.z=CGFloat(-side*0.44)
            if kind==0 {
                _=part(box(0.20,0.34,0.24,0.022),SIMD3(side*0.205,0.23,0.015),iron,body)
                _=part(box(0.225,0.15,0.37,0.018),SIMD3(side*0.21,0.10,-0.07),iron,body)
            } else {
                shard([SIMD3(side*0.23,1.54,0.14),SIMD3(side*0.58,1.35,0.20),SIMD3(side*0.72,0.83,0.29)],cloth,body)
            }
        }
        node.position=SCNVector3(position)
    }
}
