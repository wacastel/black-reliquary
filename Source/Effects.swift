import AppKit
import SceneKit
import simd

struct GoreFragment {
    let node: SCNNode
    var position: SIMD3<Float>
    var velocity: SIMD3<Float>
    let spin: SIMD3<Float>
    var life: Float
}

/// One gate owns all its persistent effects; unlocking is a one-time transition.
final class ExitGate {
    let node = SCNNode()
    let ring = SCNNode()
    let innerRing = SCNNode()
    let veil = SCNNode()
    let light = SCNLight()
    let sparks = SCNParticleSystem()
    let ringMaterial = simpleMaterial(color(0.16,0.11,0.075), emission: color(0.055,0.012,0.003))
    var seals = [SCNNode]()
    private(set) var isOpen = false

    init() {
        node.categoryBitMask = 4
        let hoop = SCNTorus(ringRadius:1.5,pipeRadius:0.105)
        hoop.ringSegmentCount=48; hoop.pipeSegmentCount=6; hoop.materials=[ringMaterial]
        ring.geometry=hoop; ring.eulerAngles.x = .pi/2; node.addChildNode(ring)
        let inner = SCNTorus(ringRadius:1.31,pipeRadius:0.026)
        inner.ringSegmentCount=48; inner.pipeSegmentCount=4; inner.materials=[ringMaterial]
        innerRing.geometry=inner; innerRing.eulerAngles.x = .pi/2; node.addChildNode(innerRing)
        for i in 0..<16 {
            let angle=Float(i)*2 * .pi/16
            let rune=SCNBox(width:0.075,height:0.18,length:0.075,chamferRadius:0)
            rune.materials=[ringMaterial]
            let n=SCNNode(geometry:rune); n.position=v3(sin(angle)*1.51,cos(angle)*1.51,-0.025)
            n.eulerAngles.z=CGFloat(-angle + .pi/4); n.categoryBitMask=4; node.addChildNode(n)
        }
        for i in 0..<3 {
            let g=SCNBox(width:0.13,height:0.13,length:0.13,chamferRadius:0.015)
            g.materials=[simpleMaterial(color(0.2,0.04,0.015),emission:color(0.07,0.006,0.002))]
            let n=SCNNode(geometry:g); n.position=v3(Float(i-1)*0.34,1.83,0); n.eulerAngles.z = .pi/4
            n.categoryBitMask=4; node.addChildNode(n); seals.append(n)
        }
        let surface=SCNCylinder(radius:1.35,height:0.012)
        surface.radialSegmentCount=48
        let mist=simpleMaterial(color(0.06,0.38,0.29,0.28),emission:color(0.06,0.5,0.29))
        mist.lightingModel = .constant; mist.blendMode = .add; mist.writesToDepthBuffer=false
        surface.materials=[mist]; veil.geometry=surface; veil.eulerAngles.x = .pi/2
        veil.opacity=0; veil.categoryBitMask=4; node.addChildNode(veil)
        light.type = .omni; light.color=color(0.23,1,0.64); light.intensity=0
        light.attenuationStartDistance=0; light.attenuationEndDistance=10
        let lightNode=SCNNode(); lightNode.light=light; lightNode.position=v3(0,0,1); node.addChildNode(lightNode)

        let emitter=SCNNode(); emitter.eulerAngles.x = .pi/2; node.addChildNode(emitter)
        sparks.emitterShape=SCNTorus(ringRadius:1.47,pipeRadius:0.06)
        sparks.birthRate=0; sparks.particleLifeSpan=1.3; sparks.particleLifeSpanVariation=0.4
        sparks.particleSize=0.035; sparks.particleSizeVariation=0.025
        sparks.particleColor=color(0.45,1,0.68); sparks.particleColorVariation=SCNVector4(0.1,0.15,0.1,0)
        sparks.particleVelocity=0.32; sparks.particleVelocityVariation=0.3; sparks.spreadingAngle=180
        sparks.acceleration=SCNVector3(0,0.25,0); sparks.blendMode = .additive
        sparks.isLightingEnabled=false; emitter.addParticleSystem(sparks)
        node.enumerateChildNodes { n,_ in n.categoryBitMask=4 }
    }

    @discardableResult func unlock() -> Bool {
        guard !isOpen else { return false }
        isOpen=true; sparks.birthRate=145; veil.opacity=0.4
        ringMaterial.diffuse.contents=color(0.3,0.78,0.47)
        ringMaterial.emission.contents=color(0.22,1,0.58)
        return true
    }

    func update(sealCount:Int,time:Double) {
        for (i,seal) in seals.enumerated() {
            seal.geometry?.firstMaterial?.emission.contents=i<sealCount ? color(0.75,0.6,0.15):color(0.07,0.006,0.002)
        }
        guard isOpen else { return }
        light.intensity=480+CGFloat(sin(time*3))*80
        veil.opacity=0.28+CGFloat(sin(time*2.7))*0.1
        innerRing.eulerAngles.z=CGFloat(time*0.4)
        let scale=1+CGFloat(sin(time*2.2))*0.025
        veil.scale=SCNVector3(scale,1,scale)
        sparks.particleSize=0.035+CGFloat(sin(time*4))*0.008
    }
}

extension Game {
    var empowered: Bool { powerupRemaining > 0 }
    var weaponDamageMultiplier: Float { empowered ? 5 : 1 }

    func activatePowerup() {
        powerupRemaining=25; shells+=8; rockets+=2
        makeWeapon(); audio.play("powerup"); trauma=max(trauma,0.18)
        announce("BLOODFIRE · 5× DAMAGE FOR 25 SECONDS",for:4)
    }

    func updatePowerup(_ dt:Float) {
        guard powerupRemaining>0 else { return }
        powerupRemaining=max(0,powerupRemaining-dt)
        if powerupRemaining==0 { makeWeapon(); announce("THE BLOODFIRE FADES",for:2.5) }
    }

    func makeBloodfireRelic() -> SCNNode {
        let n=SCNNode(); n.name="bloodfire-relic"; n.categoryBitMask=4
        let metal=simpleMaterial(color(0.16,0.075,0.05))
        let fire=simpleMaterial(color(0.95,0.2,0.035),emission:color(1,0.14,0.015))
        for i in 0..<2 {
            let g=SCNTorus(ringRadius:0.4,pipeRadius:0.035); g.ringSegmentCount=24; g.pipeSegmentCount=4; g.materials=[metal]
            let ring=SCNNode(geometry:g); ring.eulerAngles.x=CGFloat(i) * .pi/2; n.addChildNode(ring)
        }
        let crystal=SCNPyramid(width:0.32,height:0.52,length:0.32); crystal.materials=[fire]
        let upper=SCNNode(geometry:crystal); n.addChildNode(upper)
        let lower=SCNNode(geometry:crystal); lower.eulerAngles.x = .pi; lower.position.y = -0.01; n.addChildNode(lower)
        for side:Float in [-1,1] {
            let blade=SCNBox(width:0.075,height:0.58,length:0.07,chamferRadius:0); blade.materials=[fire]
            let rune=SCNNode(geometry:blade); rune.eulerAngles.z=CGFloat(side)*0.65; n.addChildNode(rune)
        }
        let embers=SCNParticleSystem(); embers.birthRate=12; embers.particleLifeSpan=0.8; embers.particleSize=0.025
        embers.emitterShape=SCNSphere(radius:0.28); embers.particleColor=color(1,0.27,0.04)
        embers.particleVelocity=0.15; embers.acceleration=SCNVector3(0,0.6,0)
        embers.blendMode = .additive; embers.isLightingEnabled=false; n.addParticleSystem(embers)
        n.enumerateChildNodes { child,_ in child.categoryBitMask=4 }; return n
    }

    func addWeaponRunes() {
        guard empowered else { return }
        let fire=simpleMaterial(color(1,0.2,0.035),emission:color(1,0.16,0.015))
        for i in 0..<5 {
            let g=SCNBox(width:0.06,height:0.012,length:0.04,chamferRadius:0)
            g.materials=[fire]; let n=SCNNode(geometry:g)
            n.position=SCNVector3(0,0.107,-0.12-CGFloat(i)*0.09); n.eulerAngles.y = .pi/4
            n.categoryBitMask=8; weaponRoot.addChildNode(n)
        }
    }

    func enemyCenter(_ e:Foe) -> SIMD3<Float> {
        e.position+SIMD3(0,(e.kind==0 ? 1.3:(e.kind==1 ? 1.7:0.9))+e.leapHeight,0)
    }

    func burstEnemy(_ e:Foe, direction:SIMD3<Float>) {
        let origin=enemyCenter(e)
        e.node.removeAllActions(); e.node.removeFromParentNode(); e.leapHeight=0; e.leapRemaining=0
        audio.play("gore_burst"); trauma=max(trauma,0.3*(1-min(1,simd_distance(position,origin)/22)))
        // Bound debris even when a powered rocket tears through a crowded room.
        while fragments.count>160-22 { fragments.removeFirst().node.removeFromParentNode() }
        let flesh=simpleMaterial(color(0.34,0.017,0.012)); flesh.lightingModel = .blinn; flesh.shininess=0.4
        let bone=simpleMaterial(color(0.57,0.48,0.29)); let iron=simpleMaterial(color(0.12,0.13,0.12))
        let push=simd_length(direction)>0.01 ? simd_normalize(direction):SIMD3<Float>(0,0,-1)
        for i in 0..<22 {
            let size=CGFloat.random(in:0.055...0.16)
            let geo:SCNGeometry
            if i%4==0 { let g=SCNCylinder(radius:size*0.45,height:size*3.2); g.radialSegmentCount=5; geo=g }
            else { geo=SCNBox(width:size*1.6,height:size,length:size*1.3,chamferRadius:0) }
            geo.materials=[i%4==0 ? bone:(i%5==0 ? iron:flesh)]
            let n=SCNNode(geometry:geo); n.categoryBitMask=4
            let p=origin+SIMD3(Float.random(in:-0.28...0.28),Float.random(in:-0.45...0.4),Float.random(in:-0.28...0.28))
            n.position=SCNVector3(p); effectsRoot.addChildNode(n)
            let velocity=SIMD3<Float>(Float.random(in:-3.8...3.8),Float.random(in:2.0...6.2),Float.random(in:-3.8...3.8))+push*2.4
            fragments.append(GoreFragment(node:n,position:p,velocity:velocity,spin:SIMD3(Float.random(in:-8...8),Float.random(in:-8...8),Float.random(in:-8...8)),life:Float.random(in:2.8...4.5)))
        }
        let blood=SCNParticleSystem(); blood.birthRate=2200; blood.emissionDuration=0.04; blood.loops=false
        blood.particleLifeSpan=0.48; blood.particleLifeSpanVariation=0.2; blood.particleSize=0.085
        blood.particleSizeVariation=0.05; blood.particleColor=color(0.48,0.025,0.009,0.9)
        blood.spreadingAngle=180; blood.particleVelocity=4; blood.particleVelocityVariation=2
        blood.acceleration=SCNVector3(0,-8,0); blood.blendMode = .alpha; blood.isLightingEnabled=false
        let spray=SCNNode(); spray.position=SCNVector3(origin); spray.categoryBitMask=4; spray.addParticleSystem(blood)
        effectsRoot.addChildNode(spray); spray.runAction(.sequence([.wait(duration:1),.removeFromParentNode()]))
        spark(at:origin,c:color(1,0.24,0.035),count:18)
        // A short-lived stain gives the impact weight without accumulating geometry.
        let stain=SCNCylinder(radius:0.62,height:0.009); stain.radialSegmentCount=12; stain.materials=[flesh]
        let pool=SCNNode(geometry:stain); pool.position=v3(origin.x,0.018,origin.z); pool.scale=SCNVector3(1,1,0.64)
        pool.categoryBitMask=4; effectsRoot.addChildNode(pool)
        pool.runAction(.sequence([.wait(duration:7),.fadeOut(duration:2),.removeFromParentNode()]))
    }

    func updateFragments(_ dt:Float) {
        for i in fragments.indices.reversed() {
            var f=fragments[i]; f.life-=dt
            if f.life<=0 { f.node.removeFromParentNode(); fragments.remove(at:i); continue }
            f.velocity.y-=dt*12
            var next=move(f.position,by:f.velocity*dt,radius:0.04)
            if abs(next.x-f.position.x)<0.001 { f.velocity.x *= -0.32 }
            if abs(next.z-f.position.z)<0.001 { f.velocity.z *= -0.32 }
            next.y=max(0.06,f.position.y+f.velocity.y*dt)
            if next.y<=0.06 { f.velocity.y=abs(f.velocity.y)*0.26; f.velocity.x *= 0.85; f.velocity.z *= 0.85 }
            f.position=next; f.node.position=SCNVector3(next)
            f.node.eulerAngles=SCNVector3(f.node.eulerAngles.f+f.spin*dt)
            f.node.opacity=CGFloat(min(1,f.life)); fragments[i]=f
        }
    }
}
