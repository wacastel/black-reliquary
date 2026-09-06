import AppKit
import SceneKit
import simd

final class Foe {
    let node:SCNNode; let kind:Int; let home:SIMD3<Float>
    var position:SIMD3<Float>; var health:Float; var cooldown:Float=1
    var active=false; var route=[SIMD2<Float>](); var repath:Float=0; var flash:Float=0
    var leapCooldown:Float=2; var leapRemaining:Float=0
    var leapDirection=SIMD3<Float>.zero; var leapHeight:Float=0
    var attackAnimation:Float=0
    let body:SCNNode; let left:SCNNode; let right:SCNNode
    let auraLight=SCNLight()
    private let head=SCNNode(), jaw=SCNNode(), soul=SCNMaterial()
    private var legs=[SCNNode](), shins=[SCNNode](), forearms=[SCNNode](), tatters=[SCNNode]()
    private var gait:Float=0, movement:Float=0
    private let phase:Float

    init(spawn:EnemySpawn) {
        kind=spawn.kind; position=SIMD3(spawn.x,0,spawn.z); home=position
        health=kind==0 ? 105:(kind==1 ? 85:125); phase=spawn.x*1.7+spawn.z*0.43
        node=SCNNode(); body=SCNNode(); left=SCNNode(); right=SCNNode()
        let iron=simpleMaterial(color(0.075,0.072,0.067)), edge=simpleMaterial(color(0.21,0.19,0.15))
        let bone=simpleMaterial(color(0.36,0.33,0.245)), oldBone=simpleMaterial(color(0.22,0.20,0.145))
        let flesh=simpleMaterial(color(0.16,0.095,0.075)), black=simpleMaterial(color(0.008,0.006,0.007))
        let cloth=simpleMaterial(kind==0 ? color(0.105,0.018,0.014):color(0.022,0.055,0.054))
        let clothLight=simpleMaterial(kind==0 ? color(0.20,0.036,0.020):color(0.037,0.10,0.097))
        for mat in [iron,edge,bone,oldBone,flesh,black,cloth,clothLight] {mat.lightingModel = .blinn; mat.shininess=0.05}
        let glow=kind==0 ? color(1,0.105,0.018):(kind==1 ? color(0.06,0.76,0.79):color(0.46,0.95,0.095))
        soul.diffuse.contents=black.diffuse.contents; soul.emission.contents=glow
        soul.lightingModel = .constant; soul.emission.intensity=1.35
        auraLight.type = .omni; auraLight.color=glow; auraLight.intensity=110
        auraLight.attenuationStartDistance=0.2; auraLight.attenuationEndDistance=3.1; auraLight.castsShadow=false
        let glowNode=SCNNode(); glowNode.name="foeAura"; glowNode.light=auraLight; glowNode.position=v3(0,1.35,-0.18)
        body.addChildNode(glowNode)
        func part(_ g:SCNGeometry,_ p:SIMD3<Float>,_ mat:SCNMaterial,_ parent:SCNNode)->SCNNode {
            g.materials=[mat]; let n=SCNNode(geometry:g); n.position=SCNVector3(p)
            n.categoryBitMask=2; parent.addChildNode(n); return n
        }
        func box(_ x:CGFloat,_ y:CGFloat,_ z:CGFloat,_ bevel:CGFloat=0)->SCNBox {
            let g=SCNBox(width:x,height:y,length:z,chamferRadius:bevel); g.chamferSegmentCount=1; return g
        }
        func cone(_ top:CGFloat,_ bottom:CGFloat,_ height:CGFloat,_ sides:Int=5)->SCNCone {
            let g=SCNCone(topRadius:top,bottomRadius:bottom,height:height); g.radialSegmentCount=sides; g.heightSegmentCount=1; return g
        }
        func shard(_ vertices:[SIMD3<Float>],_ mat:SCNMaterial,_ parent:SCNNode) {
            let normal=simd_normalize(simd_cross(vertices[1]-vertices[0],vertices[2]-vertices[0]))
            let g=SCNGeometry(sources:[SCNGeometrySource(vertices:vertices.map{SCNVector3($0)}),SCNGeometrySource(normals:Array(repeating:SCNVector3(normal),count:3))],elements:[SCNGeometryElement(indices:[Int32(0),1,2],primitiveType:.triangles)])
            mat.isDoubleSided=true; _=part(g,.zero,mat,parent)
        }
        node.addChildNode(body)
        // Hinged legs and an open, torn skirt reveal a readable running gait.
        for side:Float in [-1,1] {
            let hip=SCNNode(); hip.position=v3(side*(kind==2 ? 0.23:0.17),0.99,kind==2 ? 0.18:0.035)
            body.addChildNode(hip); legs.append(hip)
            _=part(cone(0.105,0.075,0.43),SIMD3(0,-0.205,0),kind==2 ? flesh:oldBone,hip)
            let knee=SCNNode(); knee.position=v3(0,-0.43,0); hip.addChildNode(knee); shins.append(knee)
            _=part(box(0.15,0.12,0.13,0.025),.zero,kind==2 ? bone:iron,knee)
            _=part(cone(0.07,0.052,0.43),SIMD3(0,-0.20,0),oldBone,knee)
            _=part(box(0.14,0.095,0.29,0.02),SIMD3(0,-0.42,-0.07),kind==2 ? bone:iron,knee)
            if kind==2 {
                for toe in -1...1 {
                    let claw=part(cone(0,0.022,0.17,3),SIMD3(Float(toe)*0.048,-0.43,-0.25),bone,knee); claw.eulerAngles.x = -.pi/2
                }
            } else {
                let mark=part(box(0.022,0.24,0.012),SIMD3(0,-0.20,-0.067),soul,knee); mark.eulerAngles.z=CGFloat(side*0.14)
            }
        }
        if kind==2 {
            // An exposed ribcage, bent spine and split jaw distinguish the ossuary leaper.
            let torso=part(cone(0.255,0.16,0.66,6),SIMD3(0,1.34,0.03),flesh,body); torso.eulerAngles.x = -0.16
            _=part(box(0.13,0.69,0.12,0.025),SIMD3(0,1.35,0.20),bone,body)
            for rib in 0..<4 {
                let y=1.12+Float(rib)*0.135
                for side:Float in [-1,1] {
                    let ribNode=part(box(CGFloat(0.23+Float(rib)*0.019),0.054,0.12,0.008),SIMD3(side*0.145,y,-0.16),bone,body)
                    ribNode.eulerAngles.z=CGFloat(-side*0.32)
                    let wound=part(box(0.125,0.020,0.022),SIMD3(side*0.10,y-0.051,-0.186),soul,body); wound.eulerAngles.z=CGFloat(-side*0.27)
                }
                let spine=part(cone(0,0.052,0.22,4),SIMD3(0,y+0.15,0.25),oldBone,body); spine.eulerAngles.x=0.95
            }
            head.position=v3(0,1.74,-0.21); body.addChildNode(head)
            _=part(box(0.34,0.36,0.48,0.055),SIMD3(0,0.08,-0.035),bone,head)
            _=part(box(0.29,0.18,0.25,0.028),SIMD3(0,-0.07,-0.25),oldBone,head)
            _=part(box(0.26,0.15,0.018),SIMD3(0,-0.17,-0.373),black,head)
            jaw.position=v3(0,-0.09,-0.09); head.addChildNode(jaw)
            _=part(box(0.29,0.085,0.36,0.018),SIMD3(0,-0.19,-0.09),flesh,jaw)
            for side:Float in [-1,1] {
                let socket=part(box(0.14,0.075,0.05),SIMD3(side*0.09,0.07,-0.287),black,head); socket.eulerAngles.z=CGFloat(-side*0.24)
                let eye=part(box(0.075,0.037,0.023),SIMD3(side*0.09,0.064,-0.317),soul,head); eye.eulerAngles.z=CGFloat(-side*0.24)
                let horn=part(cone(0,0.087,0.45,4),SIMD3(side*0.19,0.32,0.10),oldBone,head); horn.eulerAngles.z=CGFloat(-side*0.60); horn.eulerAngles.x=0.37
                for tooth in 0..<3 {
                    let x=side*(0.043+Float(tooth)*0.04)
                    let fang=part(cone(0,0.02,tooth==0 ? 0.18:0.11,3),SIMD3(x,-0.15,-0.35),bone,head); fang.eulerAngles.z = .pi
                    _=part(cone(0,0.017,0.075,3),SIMD3(x,-0.12,-0.24),bone,jaw)
                }
            }
            _=part(box(0.027,0.27,0.025),SIMD3(0,0.095,-0.286),soul,head)
        } else {
            _=part(cone(0.22,0.265,0.53,7),SIMD3(0,0.98,0.05),cloth,body)
            for i in 0..<7 {
                let a=Float(i)*2*Float.pi/7, b=a+2*Float.pi/7, mid=(a+b)*0.5
                let tatter=SCNNode(); tatter.position=v3(cos(mid)*0.22,1.08,sin(mid)*0.22+0.04)
                body.addChildNode(tatter); tatters.append(tatter)
                shard([SIMD3(cos(a)*0.11,0,sin(a)*0.11),SIMD3(cos(b)*0.11,0,sin(b)*0.11),SIMD3(cos(mid)*0.13,i%2==0 ? -0.64:-0.43,sin(mid)*0.13)],i%3==0 ? clothLight:cloth,tatter)
            }
            let chest=part(box(0.49,0.52,0.31,0.035),SIMD3(0,1.37,0.015),iron,body); chest.eulerAngles.z=0.035
            for side:Float in [-1,1] {
                for rib in 0..<3 {
                    let plate=part(box(0.235,0.064,0.065,0.008),SIMD3(side*0.12,1.48-Float(rib)*0.13,-0.17),edge,body); plate.eulerAngles.z=CGFloat(-side*0.20)
                }
                let rune=part(box(0.018,0.17,0.016),SIMD3(side*0.089,1.41,-0.211),soul,body); rune.eulerAngles.z=CGFloat(side*0.55)
            }
            _=part(box(0.028,0.42,0.025),SIMD3(0,1.37,-0.19),soul,body)
            _=part(box(0.37,0.065,0.31,0.008),SIMD3(0,1.07,0.018),edge,body)
            let pendant=part(cone(0.060,0,0.19,4),SIMD3(0,1.04,-0.191),soul,body); pendant.eulerAngles.y = .pi/4
            head.position=v3(0,1.88,-0.04); body.addChildNode(head)
            let cowl=part(cone(0.035,0.30,kind==0 ? 0.64:0.80,6),SIMD3(0,0.09,0.13),kind==0 ? iron:cloth,head); cowl.eulerAngles.y = .pi/6
            _=part(box(0.30,0.36,0.25,0.048),SIMD3(0,0.045,-0.033),bone,head)
            jaw.position=v3(0,-0.09,-0.055); head.addChildNode(jaw)
            _=part(box(0.25,0.14,0.22,0.022),SIMD3(0,-0.10,-0.016),oldBone,jaw)
            _=part(box(0.21,0.069,0.018),SIMD3(0,-0.029,-0.142),black,jaw)
            for side:Float in [-1,1] {
                let cheek=part(box(0.09,0.15,0.105,0.019),SIMD3(side*0.125,-0.05,-0.134),bone,head); cheek.eulerAngles.z=CGFloat(-side*0.30)
                let socket=part(box(0.12,0.068,0.039,0.006),SIMD3(side*0.08,0.064,-0.172),black,head); socket.eulerAngles.z=CGFloat(side*0.15)
                let eye=part(box(0.084,0.030,0.016),SIMD3(side*0.08,0.061,-0.202),soul,head); eye.eulerAngles.z=CGFloat(side*0.15)
                let brow=part(box(0.145,0.043,0.078,0.006),SIMD3(side*0.08,0.113,-0.15),oldBone,head); brow.eulerAngles.z=CGFloat(side*0.20)
                if kind==0 {
                    let horn=part(cone(0,0.066,0.32,4),SIMD3(side*0.21,0.205,0.08),iron,head); horn.eulerAngles.z=CGFloat(-side*0.36)
                }
                for tooth in 0..<2 {
                    let fang=part(cone(0,0.018,tooth==0 ? 0.088:0.06,3),SIMD3(side*(0.037+Float(tooth)*0.042),-0.02,-0.149),bone,jaw); fang.eulerAngles.z = .pi
                }
            }
            shard([SIMD3(-0.02,0.22,-0.16),SIMD3(0.025,0.16,-0.165),SIMD3(-0.017,0.075,-0.17)],black,head)
            if kind==1 {
                for side:Float in [-1,1] {shard([SIMD3(side*0.19,1.65,0.13),SIMD3(side*0.42,1.43,0.20),SIMD3(side*0.40,0.66,0.30)],cloth,body)}
            }
        }
        for (side,arm) in [(-1 as Float,left),(1 as Float,right)] {
            arm.position=v3(side*(kind==2 ? 0.35:0.37),1.52,kind==2 ? -0.035:0.025); body.addChildNode(arm)
            if kind != 2 {
                let shoulder=part(box(0.23,0.14,0.30,0.024),SIMD3(side*0.02,0.045,0.015),iron,arm); shoulder.eulerAngles.z=CGFloat(-side*0.32)
                let thorn=part(cone(0,0.067,kind==0 ? 0.25:0.36,4),SIMD3(side*0.045,0.22,0.04),iron,arm); thorn.eulerAngles.z=CGFloat(-side*0.48)
            }
            let length:Float=kind==2 ? 0.50:0.36
            let upper=part(cone(0.079,0.060,CGFloat(length),5),SIMD3(side*0.025,-length*0.5,0),kind==2 ? flesh:iron,arm); upper.eulerAngles.z=CGFloat(side*0.09)
            let elbow=SCNNode(); elbow.position=v3(side*0.048,-length,-0.01); arm.addChildNode(elbow); forearms.append(elbow)
            _=part(box(0.13,0.11,0.13,0.022),.zero,bone,elbow)
            let wrist:Float=kind==2 ? 0.46:0.29
            _=part(cone(0.060,0.042,CGFloat(wrist),5),SIMD3(0,-wrist*0.49,-0.015),oldBone,elbow)
            _=part(box(0.13,0.13,0.10,0.018),SIMD3(0,-wrist,-0.035),bone,elbow)
            _=part(box(0.019,CGFloat(wrist*0.72),0.014),SIMD3(0,-wrist*0.49,-0.077),soul,elbow)
            for finger in 0..<3 {
                let length:CGFloat=kind==2 ? 0.35:0.24
                let claw=part(cone(0,0.022,length+CGFloat(finger%2)*0.07,3),SIMD3(Float(finger-1)*0.048,-wrist-Float(length)*0.49,-0.092),bone,elbow); claw.eulerAngles.x = .pi-0.48
            }
        }
        node.position=SCNVector3(position); animate(time:0,delta:0,moving:false)
    }

    /// Pose only: the game owns navigation, jump timing and root world position.
    func animate(time:Double,delta:Float,moving:Bool) {
        let t=Float(time), dt=max(0,delta)
        movement += ((moving ? 1:0)-movement)*min(1,dt*9)
        gait += dt*(kind==2 ? 12.5:(kind==0 ? 9.3:7.8))*(0.20+movement*0.80)
        let stride=sin(gait+phase), breathing=sin(t*2.5+phase)
        let airborne=leapRemaining>0 || leapHeight>0.04
        let attack=sin(min(1,max(0,attackAnimation/0.55))*Float.pi), hurt=min(1,max(0,flash)*5)
        if kind==2 {
            body.position=v3(0,-0.16+abs(stride)*0.067*movement+breathing*0.014,0)
            body.eulerAngles=SCNVector3(CGFloat(airborne ? -0.35:-0.21-attack*0.23),CGFloat(stride*0.05*movement),CGFloat(stride*0.047*movement))
            head.eulerAngles=SCNVector3(CGFloat(0.15+breathing*0.045-attack*0.18),CGFloat(sin(t*3.4+phase)*0.045),CGFloat(sin(t*5+phase)*0.04))
            jaw.eulerAngles.x=CGFloat(0.14+max(0,breathing)*0.09+attack*0.36+(airborne ? 0.26:0))
        } else {
            body.position=v3(0,abs(stride)*0.052*movement+(kind==1 ? sin(t*3.1+phase)*0.045:breathing*0.012),0)
            body.eulerAngles=SCNVector3(CGFloat(-0.035-movement*0.075-attack*0.16+hurt*0.14),CGFloat(stride*movement*0.045),CGFloat(stride*movement*0.043))
            head.eulerAngles=SCNVector3(CGFloat(breathing*0.026),CGFloat(-stride*movement*0.032),CGFloat(sin(t*2.1+phase)*0.035))
            jaw.eulerAngles.x=CGFloat(0.025+attack*0.18+(kind==1 ? max(0,breathing)*0.08:0))
        }
        for i in 0..<2 {
            let side:Float=i==0 ? -1:1, step=stride*side
            if kind==2 {
                legs[i].eulerAngles.x=CGFloat(airborne ? 0.72:0.39+step*0.62*movement)
                shins[i].eulerAngles.x=CGFloat(airborne ? -1.02:-0.53-max(0,-step)*0.49*movement)
            } else {
                legs[i].eulerAngles.x=CGFloat(step*0.59*movement); shins[i].eulerAngles.x=CGFloat(-max(0,-step)*0.72*movement)
            }
            let arm=i==0 ? left:right, swipe=attack*(i==0 ? 1.0:0.73)
            arm.eulerAngles.x=CGFloat(airborne ? -1.22:(kind==2 ? -0.30:-0.10)-step*0.57*movement-swipe*1.20)
            arm.eulerAngles.z=CGFloat(side*((kind==2 ? 0.20:0.12)+swipe*0.19+(airborne ? 0.26:0)))
            forearms[i].eulerAngles.x=CGFloat((kind==2 ? -0.32:-0.16)-max(0,step)*0.30*movement-swipe*0.43)
            forearms[i].eulerAngles.z=CGFloat(side*0.04+sin(t*3+Float(i)+phase)*0.025)
        }
        for (i,tatter) in tatters.enumerated() {
            tatter.eulerAngles.x=CGFloat(sin(gait+Float(i)*0.9+phase)*movement*0.13+sin(t*2.5+Float(i))*0.025)
            tatter.eulerAngles.z=CGFloat(sin(gait+Float(i)*1.3)*movement*0.065)
        }
        let pulse=0.5+0.5*sin(t*(kind==2 ? 6:3.8)+phase)
        soul.emission.intensity=CGFloat(1.10+pulse*0.65+hurt*0.90+attack*0.50)
        auraLight.intensity=CGFloat(85+pulse*55+hurt*100+(airborne ? 85:0))
        attackAnimation=max(0,attackAnimation-dt)
    }
}
