import AppKit
import SceneKit
import simd

extension Game {
    /// Opt-in integration checks exercise real pickup, weapon, enemy and gate paths.
    func runEnhancementTests() -> [String:Any] {
        var result=[String:Any]()
        let wasTest=testMode; testMode=false
        defer {reset();setMode("playing");testMode=wasTest}
        func clearEnemies() {enemies.forEach{$0.node.removeFromParentNode()};enemies=[]}
        func fixture(_ kind:Int,_ p:SIMD3<Float>) -> Foe {
            let foe=Foe(spawn:EnemySpawn(x:p.x,z:p.z,kind:kind)); enemies.append(foe);scene.rootNode.addChildNode(foe.node);return foe
        }
        func aimAt(_ foe:Foe) {
            let d=enemyCenter(foe)-position; yaw=atan2(-d.x,-d.z);pitch=atan2(d.y,hypot(d.x,d.z))
        }
        reset();setMode("playing")
        result["bloodfirePickupCount"]=loot.filter{$0.kind==3}.count
        result["leaperCount"]=enemies.filter{$0.kind==2}.count
        result.merge(runControlTests()){_,new in new}
        clearEnemies(); position=SIMD3(0,1.65,4)
        let ordinary=fixture(0,SIMD3(0,0,-2)); aimAt(ordinary); cooldown=0
        let initial=ordinary.health;shoot();let normalDamage=initial-ordinary.health
        result["ordinaryShotDoesNotGib"]=ordinary.health>0 && fragments.isEmpty && ordinary.node.parent != nil
        let ammo=shells;shoot();result["shotCooldownEnforced"]=shells==ammo
        clearEnemies()
        if let relic=loot.first(where:{$0.kind==3}) {
            position=relic.pos+SIMD3(0,1.65,0);updatePickups(0)
            result["bloodfireCollectedThroughGameplay"]=empowered && powerupRemaining==30 && relic.node.parent==nil
            result["bloodfireDurationSeconds"]=powerupRemaining
        } else {result["bloodfireCollectedThroughGameplay"]=false}
        let empoweredFoe=fixture(2,position+SIMD3(0,-1.65,-6)); aimAt(empoweredFoe);cooldown=0
        let full=empoweredFoe.health;shoot()
        result["bloodfireDamageMultiplier"]=(full-empoweredFoe.health)/normalDamage
        result["poweredShotGibsLeaper"]=empoweredFoe.health<=0 && empoweredFoe.node.parent==nil && fragments.count==32
        result["fragmentsPerExplosion"]=fragments.count
        let beforeFragments=fragments.map{$0.position};updateFragments(0.1)
        result["fragmentsHaveBallisticMotion"]=zip(beforeFragments,fragments).allSatisfy{simd_distance($0.0,$0.1.position)>0.02}
        powerupRemaining=3;weapon=1;makeWeapon()
        result["powerupSurvivesWeaponSwitch"]=empowered && weaponDamageMultiplier==5
        setMode("paused");let remaining=powerupRemaining;tick()
        result["powerupFreezesWhenPaused"]=powerupRemaining==remaining
        setMode("playing");activatePowerup();updatePowerup(29)
        result["bloodfireLastsThirtySeconds"]=abs(powerupRemaining-1)<0.001 && empowered
        updatePowerup(1.01)
        result["powerupExpires"]=powerupRemaining==0 && weaponDamageMultiplier==1

        clearEnemies();powerupRemaining=30;position=SIMD3(0,1.65,4)
        let rocketTarget=fixture(2,SIMD3(0,0,-2));aimAt(rocketTarget);weapon=1;cooldown=0;shoot()
        let retained=missiles.last?.empowered==true
        powerupRemaining=0
        for _ in 0..<30 {updateMissiles(0.02)}
        result["rocketRetainsBloodfireAfterExpiry"]=retained && rocketTarget.health<=0 && rocketTarget.node.parent==nil
        clearEnemies()
        let edgeTarget=fixture(2,SIMD3(5.3,0,-2))
        explode(SIMD3(0,0.9,-2),empowered:true)
        result["poweredSplashEdgeGibs"]=edgeTarget.health<=0 && edgeTarget.node.parent==nil

        clearEnemies()
        for _ in 0..<10 {let foe=fixture(0,SIMD3(0,0,-2));hurtEnemy(foe,amount:1000,empowered:true,direction:SIMD3(0,0,-1))}
        result["largeExplosionsStayBounded"]=fragments.count==192 && effectsRoot.childNodes.filter{$0.name=="gore-burst"}.count==8
        updateFragments(5)
        result["debrisExpiresAfterLargeExplosions"]=fragments.isEmpty

        clearEnemies();position=SIMD3(0,1.65,4);health=100
        let leaper=fixture(2,SIMD3(0,0,-3));leaper.active=true;leaper.leapCooldown=0
        var peak:Float=0;var stayedNavigable=true;let start=leaper.position
        for _ in 0..<50 {elapsed+=0.02;updateEnemies(0.02);peak=max(peak,leaper.leapHeight);stayedNavigable = stayedNavigable && allowed(leaper.position,radius:0.4)}
        result["leaperActuallyJumps"]=peak>2 && simd_distance(start,leaper.position)>4 && leaper.leapRemaining==0 && leaper.leapHeight==0
        result["leaperStaysNavigable"]=stayedNavigable
        // A wall-adjacent landing must retain the same clearance as ground movement.
        leaper.position=SIMD3(8.1,0,0);leaper.leapDirection=SIMD3(1,0,0);leaper.leapRemaining=0.4;leaper.leapCooldown=2
        for _ in 0..<22 {updateEnemies(0.02)}
        result["leapCannotCrossWall"]=allowed(leaper.position,radius:0.4) && leaper.position.x<=8.61
        let pose=leaper.left.eulerAngles;leaper.animate(time:1,delta:0.2,moving:true);let nextPose=leaper.left.eulerAngles
        result["enemyAnimationChangesPose"]=simd_distance(pose.f,nextPose.f)>0.01 && leaper.auraLight.intensity>0

        reset();setMode("playing");clearEnemies()
        result["gateStartsLocked"] = !gate.isOpen && gate.sparks.birthRate==0 && gate.veil.opacity==0
        for i in 0..<2 {position=seals[i].pos+SIMD3(0,1.65,0);updatePickups(0)}
        result["gateRequiresAllThreeSeals"]=sealCount==2 && !gate.isOpen && gate.sparks.birthRate==0
        position=seals[2].pos+SIMD3(0,1.65,0);updatePickups(0);gate.update(sealCount:sealCount,time:elapsed)
        result["gateGlowsAndSparklesAfterThirdSeal"]=sealCount==3 && gate.isOpen && gate.sparks.birthRate>0 && gate.light.intensity>0 && gate.veil.opacity>0
        result["gateUnlockIsOneTime"] = !gate.unlock()
        position=world.exit.f+SIMD3(0,1.65,0);tick();result["openGateTriggersVictory"]=mode=="won"
        reset();setMode("playing");position=world.exit.f+SIMD3(0,1.65,0);tick()
        result["lockedGateCannotWin"]=mode=="playing" && !gate.isOpen
        result["resetClearsPowerupAndEffects"] = !empowered && fragments.isEmpty && missiles.isEmpty && effectsRoot.childNodes.isEmpty
        let sounds=["shotgun","rocket","seal","player_jump","empowered_shot","empowered_rocket","gore_burst","monster_leap","monster_land","monster_roar","powerup","gate_open"]
        result["allEnhancementSoundsBundled"]=sounds.allSatisfy{Bundle.main.url(forResource:$0,withExtension:"wav") != nil}
        return result
    }

    func runControlTests() -> [String:Any] {
        var result=[String:Any]()
        func event(_ code:UInt16,type:NSEvent.EventType = .keyDown,flags:NSEvent.ModifierFlags = [],repeatKey:Bool=false) -> NSEvent {
            NSEvent.keyEvent(with:type,location:.zero,modifierFlags:flags,timestamp:0,windowNumber:view.window?.windowNumber ?? 0,context:nil,characters:code==49 ? " ":"w",charactersIgnoringModifiers:code==49 ? " ":"w",isARepeat:repeatKey,keyCode:code)!
        }
        func mouseEvent(_ type:NSEvent.EventType) -> NSEvent {
            NSEvent.mouseEvent(with:type,location:.zero,modifierFlags:[],timestamp:0,windowNumber:view.window?.windowNumber ?? 0,context:nil,eventNumber:0,clickCount:1,pressure:type == .leftMouseDown ? 1:0)!
        }
        func start() {position=SIMD3(0,1.65,4);yaw=0;pitch=0;height=0;jumpVelocity=0;jumpRequested=false;keys=[];mouseHeld=false;cooldown=0}
        defer {start()}
        start();let ammo=shells
        view.keyDown(with:event(49));updatePlayerInput(0.02)
        result["spaceJumpsWithoutFiring"]=height>0 && jumpVelocity>0 && shells==ammo
        let airVelocity=jumpVelocity
        view.keyDown(with:event(49,repeatKey:true));updatePlayerInput(0.02)
        result["spaceRepeatCannotDoubleJump"]=jumpVelocity<airVelocity
        for i in 0..<80 {if i%6==0 {view.keyDown(with:event(49,repeatKey:true))};updatePlayerInput(0.02)}
        result["heldSpaceDoesNotAutoJump"]=height==0 && jumpVelocity==0
        view.keyUp(with:event(49,type:.keyUp));view.keyDown(with:event(49));updatePlayerInput(0.02)
        result["newSpacePressJumpsAgain"]=height>0
        start();view.keyDown(with:event(13));let origin=position
        for _ in 0..<10 {updatePlayerInput(0.02)}
        let walking=simd_distance(position,origin)
        start();view.keyDown(with:event(13));view.flagsChanged(with:event(56,type:.flagsChanged,flags:.shift))
        for _ in 0..<10 {updatePlayerInput(0.02)}
        let running=simd_distance(position,origin)
        result["shiftRunsWithoutJumping"]=running>walking*1.5 && height==0 && jumpVelocity==0
        result["measuredRunWalkRatio"]=running/walking
        let releasePosition=position;view.flagsChanged(with:event(56,type:.flagsChanged))
        for _ in 0..<10 {updatePlayerInput(0.02)}
        result["releasingShiftRestoresWalk"]=abs(simd_distance(position,releasePosition)-walking)<0.01
        start();view.keyDown(with:event(13));view.keyDown(with:event(2));view.flagsChanged(with:event(56,type:.flagsChanged,flags:.shift))
        for _ in 0..<10 {updatePlayerInput(0.02)}
        result["diagonalRunSpeedNormalized"]=abs(simd_distance(position,origin)-running)<0.01
        start();position=SIMD3(8,1.65,0);view.keyDown(with:event(2));view.flagsChanged(with:event(56,type:.flagsChanged,flags:.shift))
        for _ in 0..<20 {updatePlayerInput(0.02)}
        result["runningRespectsWalls"]=allowed(position) && position.x<8.69
        start();let before=shells;view.mouseDown(with:mouseEvent(.leftMouseDown));updatePlayerInput(0.02)
        result["mouseStillFires"]=shells==before-1 && height==0
        view.mouseUp(with:mouseEvent(.leftMouseUp));cooldown=0;updatePlayerInput(0.02)
        result["mouseReleaseStopsFire"]=shells==before-1
        start();let beforeTap=shells;view.mouseDown(with:mouseEvent(.leftMouseDown));view.mouseUp(with:mouseEvent(.leftMouseUp))
        result["quickTrackpadTapFires"]=shells==beforeTap-1 && !mouseHeld
        start();let beforeRight=shells;view.rightMouseDown(with:mouseEvent(.rightMouseDown));updatePlayerInput(0.02);view.rightMouseUp(with:mouseEvent(.rightMouseUp))
        result["rightClickDoesNotJumpOrFire"]=height==0 && shells==beforeRight && !keys.contains(56)
        start();view.keyDown(with:event(49));view.flagsChanged(with:event(56,type:.flagsChanged,flags:.shift));view.releaseMouse()
        result["focusReleaseClearsRunAndQueuedJump"]=keys.isEmpty && !jumpRequested && !mouseHeld
        view.keyDown(with:event(49));setMode("paused");let pausedPosition=position;updatePlayerInput(0.02)
        result["pauseClearsQueuedJump"] = !jumpRequested && position==pausedPosition && height==0
        setMode("playing");return result
    }

    /// Native screenshots of actual game scenes, only used with an explicit test flag.
    func captureShowcase(in directory:String) {
        try? FileManager.default.createDirectory(atPath:directory,withIntermediateDirectories:true)
        testMode=false;reset();setMode("menu");updateCamera()
        DispatchQueue.main.asyncAfter(deadline:.now()+0.4) {
            self.savePreview(directory+"/Title.png")
            self.setMode("playing");self.position=SIMD3(0,1.65,-34);self.yaw=0;self.pitch = -0.05
            self.activatePowerup();self.updateCamera();self.renderProbe.reset();self.health=1000
            DispatchQueue.main.asyncAfter(deadline:.now()+4) {
                let performance:[String:Any]=["crossingRenderFPS":self.renderProbe.framesPerSecond,"livingEnemies":self.enemies.filter{$0.health>0}.count,"enemyAuraLightLimit":4,"assistedHealth":true]
                if let data=try? JSONSerialization.data(withJSONObject:performance,options:[.prettyPrinted,.sortedKeys]) {try? data.write(to:URL(fileURLWithPath:directory+"/performance.json"))}
                self.health=100;self.refreshHUD()
                self.savePreview(directory+"/Bloodfire.png")
                self.position=SIMD3(0,1.65,-40);self.yaw=0;self.pitch = -0.04;self.health=100;self.updateCamera()
                DispatchQueue.main.asyncAfter(deadline:.now()+0.5) {
                    self.savePreview(directory+"/Monsters.png")
                    if let foe=self.enemies.filter({$0.health>0 && self.canSee(self.position,$0.position)}).min(by:{simd_distance(self.position,$0.position)<simd_distance(self.position,$1.position)}) {
                        let d=self.enemyCenter(foe)-self.position;self.yaw=atan2(-d.x,-d.z);self.pitch=atan2(d.y,hypot(d.x,d.z));self.cooldown=0;self.shoot();self.updateCamera()
                    }
                    DispatchQueue.main.asyncAfter(deadline:.now()+0.12) {
                        self.savePreview(directory+"/Impact.png")
                        self.reset();self.setMode("playing");self.enemies.forEach{$0.node.removeFromParentNode()};self.enemies=[]
                        for i in self.seals.indices {self.position=self.seals[i].pos+SIMD3(0,1.65,0);self.updatePickups(0)}
                        self.position=self.world.exit.f+SIMD3(0,1.65,7);self.yaw=0;self.pitch=0;self.updateCamera()
                        DispatchQueue.main.asyncAfter(deadline:.now()+1.2) {
                            self.savePreview(directory+"/Gate.png");NSApp.terminate(nil)
                        }
                    }
                }
            }
        }
    }
}
