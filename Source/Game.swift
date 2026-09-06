import AppKit
import SceneKit
import simd
import QuartzCore

extension SCNVector3 {
    var f: SIMD3<Float> { SIMD3(Float(x), Float(y), Float(z)) }
    init(_ f: SIMD3<Float>) { self.init(CGFloat(f.x),CGFloat(f.y),CGFloat(f.z)) }
}
struct Missile { var node:SCNNode; var pos:SIMD3<Float>; var velocity:SIMD3<Float>; var life:Float; var hostile:Bool; var empowered:Bool }
struct Loot { var node:SCNNode; var pos:SIMD3<Float>; var kind:Int; var collected:Bool=false }
struct Seal { var node:SCNNode; var pos:SIMD3<Float>; var collected:Bool=false }
final class RenderProbe: NSObject, SCNSceneRendererDelegate {
    private let lock=NSLock(); private var stamps=[TimeInterval]()
    func renderer(_ renderer:SCNSceneRenderer,didRenderScene scene:SCNScene,atTime time:TimeInterval) {
        lock.lock(); stamps.append(CACurrentMediaTime()); if stamps.count>240 {stamps.removeFirst()}; lock.unlock()
    }
    var framesPerSecond:Double {lock.lock();defer{lock.unlock()};guard stamps.count>10,let a=stamps.first,let b=stamps.last,b>a else{return 0};return Double(stamps.count-1)/(b-a)}
    func reset() {lock.lock();stamps.removeAll();lock.unlock()}
}

final class Game {
    let view:GameView; let hud:HUDView; let scene=SCNScene(); let cameraRig=SCNNode(); let camera=SCNNode()
    let renderProbe=RenderProbe(); let weaponRoot=SCNNode(); let muzzle=SCNNode(); let muzzleLight=SCNLight(); let audio=GameAudio()
    var navigation:WorldNavigation!; var world:WorldData!; var timer:Timer?; var last:TimeInterval=0; var mode="menu"
    var keys=Set<UInt16>(); var mouseHeld=false; var position=SIMD3<Float>(0,1.65,4); var yaw:Float=0; var pitch:Float=0
    var sensitivity:Float=1; var health:Float=100; var shells=42; var rockets=10; var weapon=0; var kills=0
    var elapsed:Double=0; var cooldown:Float=0; var recoil:Float=0; var jumpVelocity:Float=0; var height:Float=0
    var damageFlash:Float=0; var hitFlash:Float=0; var message=""; var messageTime:Float=0; var bob:Float=0
    var enemies=[Foe](); var missiles=[Missile](); var loot=[Loot](); var seals=[Seal](); var exitNode=SCNNode()
    let effectsRoot=SCNNode(); var fragments=[GoreFragment](); var gate:ExitGate!
    var powerupRemaining:Float=0; var trauma:Float=0; var enhancementTest=false
    var jumpRequested=false
    var muted=false; var ticks=0; var fps=60; var fpsClock:Double=0; var screenshotTaken=false
    var testMode=false; var autoPlay=false; var testResults=[String:Any](); var lastZone=""; var metricsWritten=false
    var musicStarted=false
    init(view:GameView,hud:HUDView) {
        self.view=view; self.hud=hud
        enhancementTest=CommandLine.arguments.contains("--enhancement-test")
        testMode=CommandLine.arguments.contains("--smoke-test") || enhancementTest; autoPlay=CommandLine.arguments.contains("--autoplay-test")
        view.game=self; view.scene=scene; view.pointOfView=camera; view.preferredFramesPerSecond=60
        view.delegate=renderProbe;view.antialiasingMode = .multisampling2X; view.isPlaying=true; view.rendersContinuously=true
        scene.background.contents=color(0.012,0.009,0.007)
        scene.fogColor=color(0.027,0.021,0.015); scene.fogStartDistance=20; scene.fogEndDistance=62
        scene.lightingEnvironment.intensity=0.4
        let ambient=SCNNode(); ambient.light=SCNLight(); ambient.light!.type = .ambient; ambient.light!.color=color(0.39,0.36,0.30); ambient.light!.intensity=260; scene.rootNode.addChildNode(ambient)
        let moon=SCNNode(); moon.light=SCNLight(); moon.light!.type = .directional; moon.light!.color=color(0.44,0.39,0.32); moon.light!.intensity=290; moon.eulerAngles=SCNVector3(-0.8,-0.6,0); scene.rootNode.addChildNode(moon)
        camera.camera=SCNCamera(); camera.camera!.fieldOfView=80; camera.camera!.zNear=0.045; camera.camera!.zFar=120
        camera.camera!.wantsHDR=true; camera.camera!.exposureOffset=0.12; camera.camera!.averageGray=0.2
        camera.camera!.bloomIntensity=0.32; camera.camera!.bloomThreshold=0.8; camera.camera!.bloomBlurRadius=6
        camera.camera!.vignettingIntensity=0.65; camera.camera!.vignettingPower=0.7
        cameraRig.addChildNode(camera); scene.rootNode.addChildNode(cameraRig); camera.addChildNode(weaponRoot)
        let lamp=SCNNode(); lamp.light=SCNLight(); lamp.light!.type = .omni; lamp.light!.color=color(0.72,0.63,0.49); lamp.light!.intensity=90
        lamp.light!.attenuationStartDistance=0; lamp.light!.attenuationEndDistance=9; lamp.position=SCNVector3(0,0.5,0); camera.addChildNode(lamp)
        muzzleLight.type = .omni; muzzleLight.color=color(1,0.6,0.22); muzzleLight.intensity=0; muzzleLight.attenuationEndDistance=8
        muzzle.light=muzzleLight; camera.addChildNode(muzzle); muzzle.position=SCNVector3(0.25,-0.22,-0.7)
        effectsRoot.categoryBitMask=4; scene.rootNode.addChildNode(effectsRoot)
        reset(); setMode("menu"); last=CACurrentMediaTime()
        timer=Timer.scheduledTimer(withTimeInterval:1.0/60,repeats:true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer!,forMode:.common)
        if testMode || autoPlay { DispatchQueue.main.asyncAfter(deadline:.now()+1) { self.begin(capture:false) } }
    }
    func reset() {
        world?.root.removeFromParentNode(); enemies.forEach{$0.node.removeFromParentNode()}; loot.forEach{$0.node.removeFromParentNode()}; seals.forEach{$0.node.removeFromParentNode()}; missiles.forEach{$0.node.removeFromParentNode()}; exitNode.removeFromParentNode()
        world=buildWorld(); navigation=WorldNavigation(data:world)
        for seal in world.sigils.prefix(2) {_ = navigation.route(from:world.spawn.f-SIMD3(0,1.65,0),to:seal.f-SIMD3(0,1.2,0))}
        scene.rootNode.addChildNode(world.root); position=world.spawn.f; yaw=0; pitch=0
        health=100; shells=42; rockets=10; weapon=0; kills=0; elapsed=0; height=0; jumpVelocity=0; cooldown=0; recoil=0
        damageFlash=0; hitFlash=0; messageTime=0; keys.removeAll(); mouseHeld=false; enemies=[]; loot=[]; seals=[]; missiles=[]
        effectsRoot.childNodes.forEach{$0.removeFromParentNode()}; fragments=[]; powerupRemaining=0; trauma=0; jumpRequested=false
        autoIndex=0; autoRoute=[]; autoNext=0; autoClock=0; lastZone=""
        for spawn in world.enemies { let foe=Foe(spawn:spawn); enemies.append(foe); scene.rootNode.addChildNode(foe.node) }
        for p in world.pickups {
            let node=makeLoot(p.kind); node.position=v3(p.x,p.y+(p.kind==3 ? 1.05:0.48),p.z); scene.rootNode.addChildNode(node)
            loot.append(Loot(node:node,pos:SIMD3(p.x,p.y,p.z),kind:p.kind))
        }
        for (i,p) in world.sigils.enumerated() {
            let n=SCNNode(); let mat=simpleMaterial(color(0.78,0.57,0.21),emission:color(0.36,0.19,0.03))
            let ring=SCNTorus(ringRadius:0.43,pipeRadius:0.048); ring.materials=[mat]; let r=SCNNode(geometry:ring); r.eulerAngles.x = .pi/2; n.addChildNode(r)
            for j in 0..<4 { let g=SCNBox(width:0.09,height:0.65,length:0.09,chamferRadius:0.012);g.materials=[mat];let t=SCNNode(geometry:g);t.eulerAngles.z=CGFloat(j) * .pi/4;n.addChildNode(t) }
            let core=SCNSphere(radius:0.12);core.materials=[simpleMaterial(color(0.5,0.92,1),emission:color(0.5,0.92,1))];n.addChildNode(SCNNode(geometry:core))
            n.position=v3(Float(p.x),Float(p.y)+0.15,Float(p.z)); n.name="seal\(i)";n.categoryBitMask=4;scene.rootNode.addChildNode(n);seals.append(Seal(node:n,pos:p.f))
        }
        gate=ExitGate(); exitNode=gate.node; exitNode.position=world.exit; exitNode.position.y += 1.8; scene.rootNode.addChildNode(exitNode)
        makeWeapon(); updateCamera(); refreshHUD()
    }
    func makeLoot(_ kind:Int)->SCNNode {
        if kind==3 {return makeBloodfireRelic()}
        let n=SCNNode();let c=kind==0 ? color(0.43,0.1,0.075):(kind==1 ? color(0.48,0.34,0.13):color(0.12,0.35,0.38))
        let box=SCNBox(width:0.48,height:0.35,length:0.4,chamferRadius:0.04);box.materials=[simpleMaterial(c)];n.addChildNode(SCNNode(geometry:box))
        let glow=simpleMaterial(color(0.92,0.75,0.42),emission:color(0.35,0.2,0.08))
        for i in 0..<(kind==0 ? 2:3) {
            let g=SCNBox(width:kind==0 ? 0.23:0.04,height:0.045,length:0.015,chamferRadius:0);g.materials=[glow]
            let b=SCNNode(geometry:g);b.position=SCNVector3(kind==0 ? 0:CGFloat(i-1)*0.11,0,-0.208);if kind==0 && i==1 {b.eulerAngles.z = .pi/2};n.addChildNode(b)
        }
        n.categoryBitMask=4;return n
    }
    func makeWeapon() {
        weaponRoot.childNodes.forEach{$0.removeFromParentNode()}
        let steel=simpleMaterial(color(0.19,0.20,0.21));steel.metalness.contents=0.65;steel.roughness.contents=0.34
        let dark=simpleMaterial(color(0.055,0.06,0.065));let brass=simpleMaterial(color(0.5,0.34,0.12));brass.metalness.contents=0.7
        func part(_ g:SCNGeometry,_ p:SCNVector3,_ m:SCNMaterial)->SCNNode{g.materials=[m];let n=SCNNode(geometry:g);n.position=p;n.categoryBitMask=8;n.castsShadow=false;weaponRoot.addChildNode(n);return n}
        _=part(SCNBox(width:0.19,height:0.18,length:0.4,chamferRadius:0.025),SCNVector3(0,0,0.1),steel)
        _=part(SCNBox(width:0.12,height:0.24,length:0.13,chamferRadius:0.015),SCNVector3(0,-0.13,0.22),dark)
        if weapon==0 {
            for x:CGFloat in [-0.047,0.047] {
                let barrel=part(SCNCylinder(radius:0.043,height:0.66),SCNVector3(x,0.025,-0.34),steel);barrel.eulerAngles.x = .pi/2
                let bore=part(SCNCylinder(radius:0.032,height:0.003),SCNVector3(x,0.025,-0.672),dark);bore.eulerAngles.x = .pi/2
            }
            _=part(SCNBox(width:0.14,height:0.09,length:0.23,chamferRadius:0.01),SCNVector3(0,-0.06,-0.27),simpleMaterial(color(0.22,0.105,0.052)))
            for i in 0..<6 { _=part(SCNBox(width:0.155,height:0.011,length:0.014,chamferRadius:0.002),SCNVector3(0,-0.105,-0.35+CGFloat(i)*0.031),brass) }
        } else {
            let barrel=part(SCNCylinder(radius:0.105,height:0.7),SCNVector3(0,0.01,-0.28),steel);barrel.eulerAngles.x = .pi/2
            let ring=part(SCNTorus(ringRadius:0.10,pipeRadius:0.018),SCNVector3(0,0.01,-0.62),brass);ring.eulerAngles.x = .pi/2
            let bore=part(SCNCylinder(radius:0.08,height:0.008),SCNVector3(0,0.01,-0.625),dark);bore.eulerAngles.x = .pi/2
            _=part(SCNBox(width:0.04,height:0.04,length:0.2,chamferRadius:0.01),SCNVector3(0,0.13,-0.25),simpleMaterial(color(0.1,0.72,0.76),emission:color(0.04,0.4,0.45)))
        }
        _=part(SCNCapsule(capRadius:0.052,height:0.21),SCNVector3(0.09,-0.12,0.26),simpleMaterial(color(0.3,0.20,0.14)))
        weaponRoot.scale=SCNVector3(0.8,0.8,0.8);weaponRoot.position=SCNVector3(0.21,-0.26,-0.52)
        addWeaponRunes()
    }
    var forward:SIMD3<Float>{SIMD3(-sin(yaw)*cos(pitch),sin(pitch),-cos(yaw)*cos(pitch))}
    var sealCount:Int {seals.filter{$0.collected}.count}
    func begin(capture:Bool=true) {setMode("playing");if capture {view.captureMouse()};if !musicStarted {audio.startMusic();musicStarted=true};announce("FIND THE THREE SEALS",for:4)}
    func setMode(_ value:String) {mode=value;keys.removeAll();mouseHeld=false;jumpRequested=false;audio.setPaused(value != "playing");if value != "playing" {view.releaseMouse()};weaponRoot.isHidden=value=="menu";refreshHUD()}
    func pause(){if mode=="playing" {setMode("paused")} else if mode=="paused" {begin()}}
    func announce(_ text:String,for duration:Float=3){message=text;messageTime=duration}
    func keyDown(_ e:NSEvent) {
        if e.modifierFlags.contains(.command){return}
        let code=e.keyCode
        if code==53 {if mode=="playing" || mode=="paused" {pause()};return}
        if code==3 && !e.isARepeat {view.releaseMouse();view.window?.toggleFullScreen(nil);return}
        if code==46 && !e.isARepeat {muted.toggle();audio.setMuted(muted);announce(muted ? "SOUND MUTED":"SOUND ENABLED");return}
        if code==33 || code==30 {sensitivity=max(0.25,min(2.5,sensitivity+(code==30 ? 0.1 : -0.1)));announce(String(format:"LOOK SENSITIVITY %.1f",sensitivity));return}
        if mode=="menu" && code==36 {begin();return}
        if (mode=="dead" || mode=="won") && code==36 {reset();begin();return}
        if mode=="paused" {if code==36 {begin()} else if code==15 {reset();begin()};return}
        if mode != "playing" {return}
        if code==18 {weapon=0;makeWeapon()} else if code==19 {weapon=1;makeWeapon()}
        if code==49 && !e.isARepeat && !keys.contains(49) {jumpRequested=true}
        keys.insert(code)
    }
    func click(){if mode=="menu" {begin()} else if mode=="paused" {begin()} else if mode=="playing" {if !view.mouseCaptured {view.captureMouse()};mouseHeld=true;shoot()} else {reset();begin()}}
    func look(_ dx:CGFloat,_ dy:CGFloat) {guard mode=="playing",view.mouseCaptured else{return};yaw -= Float(dx)*0.0025*sensitivity;pitch=max(-1.3,min(1.3,pitch-Float(dy)*0.0025*sensitivity))}
    var playerFoot:SIMD3<Float> {position-SIMD3(0,1.65,0)}
    func allowed(_ p:SIMD3<Float>,radius:Float=0.32)->Bool {
        navigation.clearBody(at:p,radius:radius,height:0.1)
    }
    func canSee(_ a:SIMD3<Float>,_ b:SIMD3<Float>)->Bool {navigation.lineClear(from:a,to:b)}
    func move(_ p:SIMD3<Float>,by d:SIMD3<Float>,radius:Float=0.32)->SIMD3<Float> {
        navigation.moveGround(from:p,by:d,radius:radius)
    }
    func path(from:SIMD3<Float>,to:SIMD3<Float>)->[SIMD3<Float>] {
        navigation.route(from:from,to:to)
    }
    func movePlayer(by delta:SIMD3<Float>) {
        var foot=playerFoot
        if height<0.025 && jumpVelocity<=0 {foot=move(foot,by:delta)}
        else {
            let steps=max(1,Int(ceil(simd_length(delta)/0.15)))
            for _ in 0..<steps {
                var next=foot;next.x+=delta.x/Float(steps)
                if navigation.clearBody(at:next){foot=next}
                next=foot;next.z+=delta.z/Float(steps)
                if navigation.clearBody(at:next){foot=next}
            }
        }
        position=foot+SIMD3(0,1.65,0)
    }
    func updatePlayerGravity(_ dt:Float) {
        var foot=playerFoot
        let floor=navigation.floorHeight(at:foot,stepUp:0.025) ?? -30
        jumpVelocity-=dt*15
        let nextY=foot.y+jumpVelocity*dt
        if jumpVelocity<=0 && nextY<=floor {
            foot.y=floor;jumpVelocity=0
        } else {
            var next=foot;next.y=nextY
            if jumpVelocity<=0 || navigation.clearBody(at:next) {foot=next}
            else {jumpVelocity=0}
        }
        height=max(0,foot.y-floor);position=foot+SIMD3(0,1.65,0)
        if foot.y < -20 {damage(100)}
    }
    func shoot() {
        guard cooldown<=0 else{return}
        if (weapon==0 && shells<=0)||(weapon==1 && rockets<=0) {
            cooldown=0.4; announce("OUT OF AMMO · PRESS \(weapon==0 ? "2":"1") TO SWITCH"); return
        }
        let powered=empowered
        recoil=powered ? 1.4:1; cooldown=weapon==0 ? 0.64:0.82
        muzzleLight.color=powered ? color(1,0.19,0.025):color(1,0.6,0.22)
        muzzleLight.intensity=powered ? 1550:1000; trauma=max(trauma,powered ? 0.25:0.07)
        if weapon==0 {
            shells-=1; audio.play(powered ? "empowered_shot":"shotgun")
            for e in enemies where e.health>0 {
                let aim=enemyCenter(e)-position; let dist=simd_length(aim)
                guard dist>0.001 else {continue}
                let dot=simd_dot(simd_normalize(aim),forward)
                let tolerance:Float=0.07+0.5/max(1,dist)
                if dot>cos(tolerance) && dist<27 && canSee(position,enemyCenter(e)) {
                    let amount:Float=dist<8 ? 64:(dist<17 ? 44:27)
                    hurtEnemy(e,amount:amount*weaponDamageMultiplier,empowered:powered,direction:forward)
                    hitFlash=0.2
                }
            }
            let end=position+forward*22
            let opts:[SCNHitTestOption:Any]=[.categoryBitMask:1,.ignoreHiddenNodes:true,.searchMode:SCNHitTestSearchMode.closest.rawValue]
            let hits=scene.rootNode.hitTestWithSegment(from:SCNVector3(position),to:SCNVector3(end),options:Dictionary(uniqueKeysWithValues:opts.map { ($0.key.rawValue,$0.value) }))
            if let h=hits.first {spark(at:h.worldCoordinates.f,c:powered ? color(1,0.2,0.02):color(1,0.64,0.24),count:powered ? 25:7)}
        } else {
            rockets-=1; audio.play(powered ? "empowered_rocket":"rocket")
            let launch=position+forward*0.7+SIMD3(0,-0.1,0)
            if canSee(position,launch) {spawnMissile(at:launch,velocity:forward*24,hostile:false,empowered:powered)}
            else {explode(position,empowered:powered)}
        }
    }
    func hurtEnemy(_ e:Foe,amount:Float,empowered powered:Bool=false,direction:SIMD3<Float> = .zero) {
        guard e.health>0 else {return}
        e.health-=amount; e.active=true; e.flash=0.18
        if e.health<=0 {
            kills+=1
            if powered {burstEnemy(e,direction:direction)}
            else {
                audio.play("enemy"); spark(at:enemyCenter(e),c:color(0.48,0.06,0.02),count:9)
                e.node.runAction(.sequence([.group([.fadeOut(duration:0.5),.rotateBy(x:1.3,y:0,z:0.4,duration:0.45),.moveBy(x:0,y:-0.6,z:0,duration:0.5)]),.removeFromParentNode()]))
            }
        } else {spark(at:enemyCenter(e),c:color(0.55,0.045,0.02),count:powered ? 18:5)}
    }
    func damage(_ amount:Float) {guard mode=="playing" else{return};health=max(0,health-amount);damageFlash=0.7;audio.play("hurt");if health<=0 {setMode("dead")}}
    func spawnMissile(at p:SIMD3<Float>,velocity:SIMD3<Float>,hostile:Bool,empowered powered:Bool=false) {
        let c=hostile ? color(0.08,0.7,0.9):(powered ? color(1,0.11,0.015):color(1,0.43,0.1))
        let geo=SCNSphere(radius:hostile ? 0.17:(powered ? 0.16:0.09)); geo.segmentCount=8; geo.materials=[simpleMaterial(c,emission:c)]
        let n=SCNNode(geometry:geo); n.position=SCNVector3(p); n.categoryBitMask=4; effectsRoot.addChildNode(n)
        if powered {
            let trail=SCNParticleSystem(); trail.birthRate=65; trail.particleLifeSpan=0.23; trail.particleSize=0.055
            trail.particleColor=c; trail.blendMode = .additive; trail.isLightingEnabled=false; n.addParticleSystem(trail)
        }
        missiles.append(Missile(node:n,pos:p,velocity:velocity,life:5,hostile:hostile,empowered:powered))
    }
    func spark(at p:SIMD3<Float>,c:NSColor,count:Int) {
        let root=SCNNode();root.position=SCNVector3(p);root.categoryBitMask=4;effectsRoot.addChildNode(root)
        let particles=SCNParticleSystem();particles.birthRate=0;particles.particleLifeSpan=0.25;particles.particleLifeSpanVariation=0.14;particles.emissionDuration=0.04;particles.loops=false;particles.birthRate=CGFloat(count)*25;particles.particleSize=0.055;particles.particleColor=c;particles.spreadingAngle=180;particles.particleVelocity=2.5;particles.particleVelocityVariation=1.5;particles.acceleration=SCNVector3(0,-5,0);particles.blendMode = .additive;particles.isLightingEnabled=false;root.addParticleSystem(particles);root.runAction(.sequence([.wait(duration:0.7),.removeFromParentNode()]))
    }
    func explode(_ p:SIMD3<Float>,empowered powered:Bool=false) {
        audio.play("explosion"); spark(at:p,c:powered ? color(1,0.16,0.025):color(1,0.4,0.1),count:powered ? 85:45)
        let g=SCNSphere(radius:0.25); g.segmentCount=12
        g.materials=[simpleMaterial(color(1,0.4,0.08),emission:color(1,0.22,0.015))]
        let n=SCNNode(geometry:g); n.categoryBitMask=4; n.position=SCNVector3(p); effectsRoot.addChildNode(n)
        n.runAction(.sequence([.group([.scale(to:powered ? 8:5,duration:0.23),.fadeOut(duration:0.23)]),.removeFromParentNode()]))
        for e in enemies where e.health>0 {
            let dist=simd_distance(enemyCenter(e),p)
            if dist<5.5 && canSee(p,enemyCenter(e)) {
                let blast=125*(1-dist/6.5)
                hurtEnemy(e,amount:powered ? max(140,blast*5):blast,empowered:powered,direction:enemyCenter(e)-p); hitFlash=0.2
            }
        }
        let dist=simd_distance(position,p)
        trauma=max(trauma,(powered ? 0.5:0.3)*(1-min(1,dist/18)))
        if dist<3.5 && canSee(p,position) {damage(24*(1-dist/3.5));if dist<2.8 {jumpVelocity=max(jumpVelocity,5.5)}}
    }
    func tick() {
        let now=CACurrentMediaTime();let dt=Float(min(0.04,now-last));last=now;ticks += 1;fpsClock += Double(dt)
        if fpsClock>=1 {fps=Int(Double(ticks)/fpsClock);ticks=0;fpsClock=0}
        SCNTransaction.begin();SCNTransaction.animationDuration=0
        if mode=="playing" {
            updatePowerup(dt); trauma=max(0,trauma-dt*1.8); updateFragments(dt)
            elapsed += Double(dt);cooldown=max(0,cooldown-dt);recoil=max(0,recoil-dt*6);damageFlash=max(0,damageFlash-dt);hitFlash=max(0,hitFlash-dt);messageTime=max(0,messageTime-dt)
            if !autoPlay {updatePlayerInput(dt)}
            updateEnemies(dt);if mode=="playing" {updateMissiles(dt)};if mode=="playing" {updatePickups(dt)}
            if autoPlay {runAutoplay(dt)}
            let zone=world.zones.filter{$0.rect.contains(position.x,position.z)}.min{abs($0.y-playerFoot.y)<abs($1.y-playerFoot.y)}?.name ?? "The Passage"
            if zone != lastZone {lastZone=zone}
            gate.update(sealCount:sealCount,time:elapsed)
            if mode=="playing" && gate.isOpen {
                if abs(playerFoot.y-Float(world.exit.y))<1 && simd_distance(SIMD2(position.x,position.z),SIMD2(Float(world.exit.x),Float(world.exit.z)))<2.1 {setMode("won");audio.play("win")}
            }
            updateCamera()
        } else if mode=="menu" {cameraRig.position=world.spawn;cameraRig.eulerAngles.y=CGFloat(sin(now*0.07)*0.13);camera.eulerAngles.x=0.09}
        muzzleLight.intensity=max(0,muzzleLight.intensity-CGFloat(dt)*7000)
        for (i,s) in seals.enumerated() where !s.collected {s.node.eulerAngles.y=CGFloat(now)*0.6;s.node.position.y=CGFloat(s.pos.y)+0.15+CGFloat(sin(now*1.7+Double(i)))*0.13}
        for l in loot where !l.collected {l.node.eulerAngles.y=CGFloat(now)*0.5;if l.kind==3 {l.node.position.y=CGFloat(l.pos.y)+1.05+CGFloat(sin(now*2.1))*0.12}}
        SCNTransaction.commit();refreshHUD()
        if testMode && elapsed>4 && !screenshotTaken {runSmokeTests();screenshotTaken=true}
        if autoPlay && mode=="won" && !metricsWritten {writeMetrics(["autoplayWon":true,"seconds":elapsed,"kills":kills,"seals":sealCount,"health":health,"renderFPSObserved":renderProbe.framesPerSecond]);metricsWritten=true;DispatchQueue.main.asyncAfter(deadline:.now()+1){NSApp.terminate(nil)}}
    }
    func updateCamera() {
        cameraRig.position=SCNVector3(position); cameraRig.eulerAngles.y=CGFloat(yaw)
        let shake=trauma*trauma
        camera.position=v3(sin(Float(elapsed)*61)*shake*0.11,cos(Float(elapsed)*73)*shake*0.08,0)
        camera.eulerAngles=SCNVector3(CGFloat(pitch),0,CGFloat(sin(Float(elapsed)*47)*shake*0.018))
        weaponRoot.position=SCNVector3(0.21+CGFloat(sin(bob))*0.007,-0.26+CGFloat(abs(cos(bob)))*0.009-CGFloat(recoil)*0.045,-0.52+CGFloat(recoil)*0.13)
        weaponRoot.eulerAngles.x=CGFloat(recoil)*0.11
    }
    func updatePlayerInput(_ dt:Float) {
        guard mode=="playing" else {return}
        let x:Float=(keys.contains(2) ? 1:0)-(keys.contains(0) ? 1:0)
        let z:Float=(keys.contains(13) ? 1:0)-(keys.contains(1) ? 1:0)
        if x != 0 || z != 0 {
            let dir=simd_normalize(SIMD3(cos(yaw)*x-sin(yaw)*z,0,-sin(yaw)*x-cos(yaw)*z))
            let running=keys.contains(56)
            movePlayer(by:dir*(running ? GameTuning.runSpeed:GameTuning.walkSpeed)*dt)
            bob+=dt*(running ? 14:10)
        } else {bob+=dt*1.4}
        // Consume the press even when airborne: holding Space never repeats a jump.
        if jumpRequested {jumpRequested=false;_ = jump()}
        updatePlayerGravity(dt)
        if mouseHeld {shoot()}
    }
    @discardableResult func jump() -> Bool {
        guard mode=="playing",height<=0.001,jumpVelocity<=0 else {return false}
        jumpVelocity=5;audio.play("player_jump");return true
    }
    func updateEnemies(_ dt:Float) {
        let litFoes=Set(enemies.filter{$0.health>0 && simd_distance($0.position,position)<12}.sorted{simd_distance($0.position,position)<simd_distance($1.position,position)}.prefix(4).map{ObjectIdentifier($0)})
        for e in enemies where e.health>0 {
            let before=e.position
            let dist=simd_distance(SIMD2(position.x,position.z),SIMD2(e.position.x,e.position.z))
            let visible=dist<24 && canSee(enemyCenter(e),position)
            let sameLevel=abs(playerFoot.y-e.position.y)<1.1
            if (dist<15 && visible) || (dist<5 && sameLevel) {
                if !e.active && e.kind==2 {audio.play("monster_roar")}
                e.active=true
            }
            e.cooldown-=dt; e.repath-=dt; e.flash=max(0,e.flash-dt); e.leapCooldown-=dt
            if e.active {
                var delta=position-e.position; delta.y=0
                if simd_length(delta)>0.01 {e.node.eulerAngles.y=CGFloat(atan2(-delta.x,-delta.z))}
                if e.kind==2 && e.leapRemaining<=0 && e.leapCooldown<=0 && visible && sameLevel && dist>2.5 && dist<10 {
                    e.leapDirection=simd_normalize(delta); e.leapRemaining=0.78; e.leapCooldown=2.6
                    e.attackAnimation=0.55; audio.play("monster_leap")
                }
                if e.leapRemaining>0 {
                    e.leapRemaining=max(0,e.leapRemaining-dt)
                    let nextGround=move(e.position,by:e.leapDirection*9.5*dt,radius:0.4)
                    let nextHeight=sin((1-e.leapRemaining/0.78) * .pi)*2.25
                    // Pounce clearance uses the visible airborne body, including gallery undersides.
                    if navigation.clearBody(at:nextGround+SIMD3(0,nextHeight,0),radius:0.4) {
                        e.position=nextGround;e.leapHeight=nextHeight
                    } else if navigation.clearBody(at:e.position+SIMD3(0,nextHeight,0),radius:0.4) {
                        e.leapHeight=nextHeight
                    }
                    if e.leapRemaining==0 {
                        e.leapHeight=0; e.cooldown=0.65; audio.play("monster_land")
                        spark(at:e.position+SIMD3(0,0.15,0),c:color(0.36,0.43,0.13),count:12)
                        if simd_distance(SIMD2(position.x,position.z),SIMD2(e.position.x,e.position.z))<2.4 && abs(playerFoot.y-e.position.y)<1 && canSee(enemyCenter(e),position) {damage(19)}
                    }
                } else {
                    if (dist>1.55 || !sameLevel) && (e.kind != 1 || dist>8 || !visible || !sameLevel) {
                        var target=position
                        // Sight over a low tomb or across a gallery does not imply a walkable line.
                        if e.repath<=0 {e.route=path(from:e.position,to:playerFoot);e.repath=1.1}
                        if let first=e.route.first {target=first;if simd_distance(target,e.position)<0.4 {e.route.removeFirst()}}
                        var dir=target-e.position; dir.y=0
                        if simd_length(dir)>0.05 {
                            dir=simd_normalize(dir); var sep=SIMD3<Float>.zero
                            for other in enemies where other !== e && other.health>0 {
                                var d=e.position-other.position; d.y=0; let len=simd_length(d)
                                if abs(e.position.y-other.position.y)<1.2 && len<0.85 && len>0.01 {sep+=d/len*(0.85-len)*2}
                            }
                            let speed:Float=e.kind==0 ? 3.25:(e.kind==1 ? 2.5:3.8)
                            e.position=move(e.position,by:(dir*speed+sep)*dt,radius:0.4)
                        }
                    } else if e.kind==1 && visible && dist>3 {
                        let side=SIMD3<Float>(cos(Float(elapsed)*1.6+e.home.x),0,sin(Float(elapsed)*1.1+e.home.z))
                        e.position=move(e.position,by:side*1.3*dt,radius:0.4)
                    }
                    if e.cooldown<=0 && visible {
                        if e.kind != 1 && dist<1.95 && abs(playerFoot.y-e.position.y)<1.2 {
                            damage(e.kind==2 ? 15:12); e.cooldown=e.kind==2 ? 0.8:0.95; e.attackAnimation=0.55
                        } else if e.kind==1 && dist<23 {
                            let origin=enemyCenter(e); spawnMissile(at:origin,velocity:simd_normalize(position-origin)*7,hostile:true)
                            e.cooldown=2.2; e.attackAnimation=0.55
                        }
                    }
                }
            }
            if let floor=navigation.floorHeight(at:e.position,stepUp:0.025) {
                if e.position.y>floor+0.025 {e.fallVelocity-=dt*15;e.position.y=max(floor,e.position.y+e.fallVelocity*dt)}
                else {e.position.y=floor;e.fallVelocity=0}
            }
            e.node.position=SCNVector3(e.position+SIMD3(0,e.leapHeight,0))
            e.animate(time:elapsed,delta:dt,moving:simd_distance(e.position,before)>0.003)
            if !litFoes.contains(ObjectIdentifier(e)) {e.auraLight.intensity=0}
        }
    }
    func updateMissiles(_ dt:Float) {
        for i in missiles.indices.reversed() {
            var m=missiles[i];m.life -= dt;let old=m.pos;m.pos += m.velocity*dt
            let blocked = !canSee(old,m.pos)
            var impact = blocked || m.life<=0
            if m.hostile {if !blocked && simd_distance(m.pos,position)<0.6 {damage(16);impact=true}}
            else {for e in enemies where e.health>0 {if simd_distance(m.pos,enemyCenter(e))<0.85 {impact=true;break}}}
            if impact {m.node.removeFromParentNode();missiles.remove(at:i);if !m.hostile {explode(old,empowered:m.empowered)} else {spark(at:old,c:color(0.1,0.65,0.9),count:7)}}
            else {m.node.position=SCNVector3(m.pos);missiles[i]=m}
        }
    }
    func updatePickups(_ dt:Float) {
        for i in loot.indices where !loot[i].collected {
            if abs(playerFoot.y-loot[i].pos.y)<1.1 && simd_length(SIMD2(position.x-loot[i].pos.x,position.z-loot[i].pos.z))<1.15 {
                if loot[i].kind==0 && health>=100 {continue}
                switch loot[i].kind {case 0:health=min(100,health+35);announce("VITALITY RESTORED · +35");case 1:shells += 14;announce("+14 IRON SHELLS");case 2:rockets += 5;announce("+5 CINDER ROCKETS");case 3:activatePowerup();default:break}
                loot[i].collected=true;loot[i].node.removeFromParentNode();if loot[i].kind != 3 {audio.play("pickup")}
            }
        }
        for i in seals.indices where !seals[i].collected {
            if abs(position.y-seals[i].pos.y)<1.3 && simd_length(SIMD2(position.x-seals[i].pos.x,position.z-seals[i].pos.z))<1.65 {
                let guards=enemies.contains{$0.health>0 && abs($0.position.y-(seals[i].pos.y-1.2))<2.5 && simd_distance(SIMD2($0.position.x,$0.position.z),SIMD2(seals[i].pos.x,seals[i].pos.z))<10}
                if guards {if messageTime<0.2 {announce("THE SEAL IS BOUND · SLAY ITS GUARDIANS",for:2)};continue}
                seals[i].collected=true;seals[i].node.removeFromParentNode();health=min(100,health+20);audio.play("seal")
                if sealCount==3 {announce("THE GATE IS OPEN · FOLLOW ITS EMERALD LIGHT",for:6);if gate.unlock() {audio.play("gate_open");spark(at:world.exit.f+SIMD3(0,1.8,0),c:color(0.3,1,0.6),count:90)}}
                else {announce("SEAL \(sealCount) OF 3 · +20 VITALITY",for:4)}
            }
        }
        if sealCount<3 && simd_distance(SIMD2(position.x,position.z),SIMD2(Float(world.exit.x),Float(world.exit.z)))<3 && messageTime<0.2 {announce("THE GATE DEMANDS THREE SEALS",for:3)}
    }
    func refreshHUD() {
        var s=HUDState();s.mode=mode;s.health=Int(ceil(health));s.shells=shells;s.rockets=rockets;s.weapon=weapon;s.seals=sealCount;s.kills=kills;s.totalEnemies=enemies.count;s.elapsed=elapsed;s.location=lastZone.isEmpty ? "The Narthex":lastZone;s.message=message;s.messageAlpha=CGFloat(min(1,messageTime));s.damage=CGFloat(damageFlash);s.hit=CGFloat(hitFlash>0 ? 1:0);s.fps=Int(renderProbe.framesPerSecond.rounded());s.sensitivity=Double(sensitivity);s.muted=muted;s.powerupRemaining=Double(powerupRemaining);s.gateOpen=gate?.isOpen ?? false;hud.state=s
    }
    func writeMetrics(_ values:[String:Any]) {
        let path=ProcessInfo.processInfo.environment["RELIQUARY_TEST_OUTPUT"] ?? "/tmp/reliquary-test.json"
        if let data=try? JSONSerialization.data(withJSONObject:values,options:[.prettyPrinted,.sortedKeys]) {try? data.write(to:URL(fileURLWithPath:path))}
    }
    func runSmokeTests() {
        var result=[String:Any]();result["arm64"]=true;result["metal"]=view.renderingAPI == .metal;result["worldNodes"]=world.root.childNodes.count
        result["spawnValid"]=allowed(world.spawn.f);result["wallBlocks"] = !allowed(SIMD3(100,0,100));result["shortProjectileHitsWall"] = !canSee(SIMD3(8.9,1,0),SIMD3(9.1,1,0));result["enemyCount"]=enemies.count
        result["allSealsReachable"]=world.sigils.allSatisfy{!path(from:world.spawn.f-SIMD3(0,1.65,0),to:$0.f-SIMD3(0,1.2,0)).isEmpty};result["exitReachable"] = !path(from:world.spawn.f-SIMD3(0,1.65,0),to:world.exit.f).isEmpty
        result["enemySpawnsValid"]=world.enemies.allSatisfy{allowed(SIMD3($0.x,$0.y,$0.z),radius:0.4)}
        result["pickupSpawnsValid"]=world.pickups.allSatisfy{allowed(SIMD3($0.x,$0.y,$0.z),radius:0.1)}
        let before=position;movePlayer(by:SIMD3(0,0,-1));result["movementWorks"]=simd_distance(before,position)>0.8;position=before
        let oldShells=shells;shoot();result["shootConsumesAmmo"]=shells==oldShells-1
        result["windowVisible"]=view.window?.isVisible ?? false;result["nativeView"]=true;result["renderFPSObserved"]=renderProbe.framesPerSecond;result["simulationTicksPerSecond"]=fps;result["fullscreen"]=view.window?.styleMask.contains(.fullScreen) ?? false
        if enhancementTest {result.merge(runEnhancementTests()){_,new in new};result.merge(runVerticalTests()){_,new in new}}
        writeMetrics(result)
        if let directory=ProcessInfo.processInfo.environment["RELIQUARY_ARCHITECTURE_DIR"] {captureArchitecture(in:directory);return}
        if let directory=ProcessInfo.processInfo.environment["RELIQUARY_SHOWCASE_DIR"] {captureShowcase(in:directory);return}
        if let path=ProcessInfo.processInfo.environment["RELIQUARY_SCREENSHOT"] {let image=view.snapshot();if let data=image.tiffRepresentation,let bitmap=NSBitmapImageRep(data:data),let png=bitmap.representation(using:.png,properties:[:]) {try? png.write(to:URL(fileURLWithPath:path))}}
        if let path=ProcessInfo.processInfo.environment["RELIQUARY_PLAY_SCREENSHOT"] {refreshHUD();savePreview(path)}
        reset();setMode("menu")
        DispatchQueue.main.asyncAfter(deadline:.now()+0.5){
            if let path=ProcessInfo.processInfo.environment["RELIQUARY_MENU_SCREENSHOT"] {self.savePreview(path)}
            NSApp.terminate(nil)
        }
    }
    func savePreview(_ path:String) {
        let preview=NSImage(size:view.bounds.size);preview.lockFocus();view.snapshot().draw(in:view.bounds);hud.draw(hud.bounds);preview.unlockFocus()
        if let data=preview.tiffRepresentation,let bitmap=NSBitmapImageRep(data:data),let png=bitmap.representation(using:.png,properties:[:]) {try? png.write(to:URL(fileURLWithPath:path))}
    }
    var autoIndex=0;var autoRoute=[SIMD3<Float>]();var autoNext:Float=0;var autoClock:Float=0
    func runAutoplay(_ dt:Float) {
        // Exercising normal navigation, weapon damage, pickups, and the exit condition without input injection.
        autoClock += dt;health=100
        let targets=world.sigils.map{$0.f-SIMD3(0,1.2,0)}+[world.exit.f]
        if autoIndex>=targets.count{return}
        let nearby=enemies.filter{$0.health>0 && simd_distance($0.position,position)<19 && canSee(position,enemyCenter($0))}.min{simd_distance($0.position,position)<simd_distance($1.position,position)}
        if let e=nearby {let delta=enemyCenter(e)-position;yaw=atan2(-delta.x,-delta.z);pitch=atan2(delta.y,hypot(delta.x,delta.z));shells=max(shells,10);weapon=0;shoot()}
        else {
            let t=targets[autoIndex];if autoNext<=0 {autoRoute=path(from:playerFoot,to:t);autoNext=1};autoNext -= dt
            var next=t+SIMD3(0,1.65,0);if let p=autoRoute.first {next=p+SIMD3(0,1.65,0);if simd_distance(playerFoot,p)<0.4 {autoRoute.removeFirst()}}
            var dir=next-position;dir.y=0;if simd_length(dir)>0.1 {dir=simd_normalize(dir);movePlayer(by:dir*5.7*dt);yaw=atan2(-dir.x,-dir.z);pitch=0}
            if autoIndex<3 && seals[autoIndex].collected {autoIndex += 1;autoNext=0}
        }
        updatePlayerGravity(dt)
        if autoClock>360 && !metricsWritten {writeMetrics(["autoplayWon":false,"index":autoIndex,"position":[position.x,position.y,position.z],"kills":kills,"seals":sealCount]);metricsWritten=true;NSApp.terminate(nil)}
    }
}
