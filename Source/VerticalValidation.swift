import AppKit
import SceneKit
import simd

extension Game {
    /// Opt-in integration checks use the same movement, gravity, combat and
    /// collection paths as play. Fixtures only place the initial player/enemies.
    func runVerticalTests() -> [String:Any] {
        let wasTest = testMode
        let wasMuted = muted
        testMode = false
        audio.setMuted(true)
        defer {
            reset()
            setMode("playing")
            testMode = wasTest
            audio.setMuted(wasMuted)
        }
        reset(); setMode("playing")
        var result = [String:Any]()
        let dt: Float = 1.0/60.0
        func xyz(_ point: SIMD3<Float>) -> [Float] { [point.x,point.y,point.z] }
        func clearEnemies() {
            enemies.forEach { $0.node.removeFromParentNode() }
            enemies = []
        }
        func clearMissiles() {
            missiles.forEach { $0.node.removeFromParentNode() }
            missiles = []
        }
        func place(_ foot: SIMD3<Float>) {
            position = foot+SIMD3(0,1.65,0)
            height = 0; jumpVelocity = 0; jumpRequested = false
            keys = []; mouseHeld = false; health = 10000
        }
        func fixture(_ foot: SIMD3<Float>, kind: Int = 0) -> Foe {
            let foe = Foe(spawn:EnemySpawn(x:foot.x,z:foot.z,kind:kind,y:foot.y))
            enemies.append(foe); scene.rootNode.addChildNode(foe.node)
            return foe
        }
        func aim(_ point: SIMD3<Float>) {
            let delta = point-position
            yaw = atan2(-delta.x,-delta.z)
            pitch = atan2(delta.y,hypot(delta.x,delta.z))
        }

        /// Follow navigation footpoints with ordinary small player motion, never
        /// assigning waypoint elevations directly to the player during traversal.
        func traverse(_ start: SIMD3<Float>, _ end: SIMD3<Float>) -> [String:Any] {
            place(start)
            var points = navigation.route(from:start,to:end)
            guard !points.isEmpty else {
                return ["passed":false,"reason":"No navigation route","start":xyz(start),"target":xyz(end),"failedPosition":xyz(playerFoot)]
            }
            if simd_distance(points.last!,end)>0.04 { points.append(end) }
            var frames = 0, stagnant = 0
            var minY = start.y, maxY = start.y, largestYStep: Float = 0
            var clearThroughout = navigation.clearBody(at:playerFoot)
            var failure: String? = nil
            var failedWaypoint = end
            for target in points {
                failedWaypoint = target
                while hypot(playerFoot.x-target.x,playerFoot.z-target.z)>0.09 || abs(playerFoot.y-target.y)>0.5 {
                    let before = playerFoot
                    var delta = target-before; delta.y = 0
                    let distance = simd_length(delta)
                    if distance>0.0001 {
                        movePlayer(by:delta/distance*min(distance,GameTuning.walkSpeed*dt))
                    }
                    updatePlayerGravity(dt)
                    frames += 1
                    minY = min(minY,playerFoot.y); maxY = max(maxY,playerFoot.y)
                    largestYStep = max(largestYStep,abs(playerFoot.y-before.y))
                    clearThroughout = clearThroughout && navigation.clearBody(at:playerFoot)
                    stagnant = simd_distance(before,playerFoot)<0.0001 ? stagnant+1 : 0
                    if !playerFoot.x.isFinite || !playerFoot.y.isFinite || !playerFoot.z.isFinite {
                        failure = "Non-finite position"; break
                    }
                    if stagnant>90 { failure = "Movement stopped before waypoint"; break }
                    if frames>8000 { failure = "Traversal frame budget exceeded"; break }
                    if playerFoot.y < -15 { failure = "Player fell outside supported surfaces"; break }
                }
                if failure != nil { break }
            }
            for _ in 0..<12 { updatePlayerGravity(dt) }
            let reached = simd_distance(playerFoot,end)<0.32
            let passed = failure == nil && reached && clearThroughout && largestYStep<0.46
            var report: [String:Any] = ["passed":passed,"start":xyz(start),"target":xyz(end),
                "finalPosition":xyz(playerFoot),"waypoints":points.count,"frames":frames,
                "minimumFootHeight":minY,"maximumFootHeight":maxY,"largestFrameHeightChange":largestYStep,
                "bodyClearThroughout":clearThroughout,"reachedTarget":reached]
            if !passed {
                report["reason"] = failure ?? (!reached ? "Wrong final position or floor" : (!clearThroughout ? "Body intersected architecture" : "Abrupt vertical movement"))
                report["failedPosition"] = xyz(playerFoot)
                report["failedWaypoint"] = xyz(failedWaypoint)
            }
            return report
        }

        clearEnemies()
        let westEntry = SIMD3<Float>(-31.7,0,-44)
        let westBottom = SIMD3<Float>(-38,-6,-51)
        let eastEntry = SIMD3<Float>(31.7,0,-44)
        let eastGallery = SIMD3<Float>(38,6,-51)
        let routes: [String:[String:Any]] = [
            "westDescent":traverse(westEntry,westBottom),
            "westAscent":traverse(westBottom,westEntry),
            "eastAscent":traverse(eastEntry,eastGallery),
            "eastDescent":traverse(eastGallery,eastEntry)
        ]
        result["verticalStairRoutes"] = routes
        result["verticalStairsTraversableBothDirections"] = routes.values.allSatisfy { $0["passed"] as? Bool == true }

        let underneath = traverse(SIMD3(35,0,-51),SIMD3(41,0,-51))
        result["galleryUnderpass"] = underneath
        result["playerCanWalkBelowGallery"] = underneath["passed"] as? Bool == true && abs(playerFoot.y)<0.05

        place(eastGallery)
        let jumped = jump()
        var jumpPeak = playerFoot.y
        for _ in 0..<100 { updatePlayerGravity(dt); jumpPeak = max(jumpPeak,playerFoot.y) }
        result["upperGalleryJumpAndLanding"] = ["passed":jumped && jumpPeak>6.6 && abs(playerFoot.y-6)<0.025 && height<0.001 && jumpVelocity==0,
            "jumpAccepted":jumped,"peakFootHeight":jumpPeak,"landedFootHeight":playerFoot.y]

        place(eastGallery+SIMD3(0,2,0)); height = 2; jumpVelocity = -2
        for _ in 0..<100 { updatePlayerGravity(dt) }
        result["fallingPlayerLandsOnUpperSlab"] = abs(playerFoot.y-6)<0.025 && height<0.001 && jumpVelocity==0

        // A deliberately stronger upward impulse probes the underside even though
        // an ordinary jump cannot reach this six-meter gallery from the ground.
        place(SIMD3(38,0,-51)); _ = jump(); jumpVelocity = 13
        var undersidePeak: Float = 0, undersideClear = true
        for _ in 0..<150 {
            updatePlayerGravity(dt)
            undersidePeak = max(undersidePeak,playerFoot.y)
            undersideClear = undersideClear && navigation.clearBody(at:playerFoot)
        }
        result["galleryUndersideStopsUpwardBody"] = ["passed":undersidePeak>3 && undersidePeak<4.4 && undersideClear && abs(playerFoot.y)<0.025,
            "probeInitialUpwardVelocity":13,"peakFootHeight":undersidePeak,"landedFootHeight":playerFoot.y,"bodyClearThroughout":undersideClear]

        func enemyTraversal(_ start: SIMD3<Float>, _ end: SIMD3<Float>) -> [String:Any] {
            clearEnemies(); clearMissiles(); place(end)
            let foe = fixture(start); foe.active = true; foe.cooldown = 1000
            let initialRoute = navigation.route(from:start,to:end)
            var frames = 0, maxY = start.y, minY = start.y
            var clearThroughout = true
            while frames<1800 && simd_distance(foe.position,end)>2.15 {
                elapsed += 0.025; updateEnemies(0.025); frames += 1
                maxY = max(maxY,foe.position.y); minY = min(minY,foe.position.y)
                clearThroughout = clearThroughout && navigation.clearBody(at:foe.position,radius:0.4)
            }
            let reached = simd_distance(foe.position,end)<=2.15 && abs(foe.position.y-end.y)<0.7
            var report: [String:Any] = ["passed":!initialRoute.isEmpty && reached && clearThroughout,
                "initialRouteWaypoints":initialRoute.count,"frames":frames,"minimumFootHeight":minY,"maximumFootHeight":maxY,
                "finalPosition":xyz(foe.position),"target":xyz(end),"bodyClearThroughout":clearThroughout]
            if !reached { report["failedPosition"] = xyz(foe.position); report["reason"] = "Enemy did not reach the player's floor" }
            return report
        }
        let enemyRoutes = ["eastAscent":enemyTraversal(eastEntry,eastGallery),"westDescent":enemyTraversal(westEntry,westBottom)]
        result["enemyRoutesAcrossHeights"] = enemyRoutes
        result["enemiesTraverseStairsAcrossHeights"] = enemyRoutes.values.allSatisfy { $0["passed"] as? Bool == true }

        clearEnemies(); clearMissiles(); place(SIMD3(38,0,-51))
        let protected = fixture(eastGallery)
        let protectedCenter = enemyCenter(protected)
        let protectedHealth = protected.health
        var combat = [String:Any]()
        combat["gallerySlabBlocksSight"] = !canSee(position,protectedCenter)
        powerupRemaining = 0; weapon = 0; shells = 100; cooldown = 0; aim(protectedCenter); shoot()
        combat["shotgunCannotDamageThroughGallery"] = protected.health==protectedHealth
        let upward = simd_normalize(protectedCenter-position)
        spawnMissile(at:position+upward*0.15,velocity:upward*24,hostile:false)
        for _ in 0..<40 { updateMissiles(0.025) }
        combat["rocketStopsAtSlabWithoutSplashThroughIt"] = missiles.isEmpty && protected.health==protectedHealth
        let beforeHostile = health
        spawnMissile(at:protectedCenter,velocity:simd_normalize(position-protectedCenter)*7,hostile:true)
        for _ in 0..<100 { updateMissiles(0.025) }
        combat["hostileProjectileCannotCrossGallery"] = missiles.isEmpty && health==beforeHostile

        // The low landing is the critical muzzle case: the player's head fits
        // beneath it, but the normal forward launch offset would cross its slab.
        clearEnemies(); clearMissiles(); place(SIMD3(31.7,0,-34.5))
        let landingTarget = fixture(SIMD3(31.7,2,-35))
        let landingHealth = landingTarget.health
        weapon = 1; rockets = 100; cooldown = 0; aim(enemyCenter(landingTarget))
        let proposedMuzzle = position+forward*0.7+SIMD3(0,-0.1,0)
        let landingFixtureValid = navigation.clearBody(at:playerFoot) && proposedMuzzle.y>2 && !canSee(position,proposedMuzzle)
        shoot()
        let spawnedBeyondSlab = missiles.contains { $0.pos.y>=2 }
        for _ in 0..<45 { updateMissiles(0.02) }
        combat["rocketMuzzleCannotCrossLowLandingSlab"] = landingFixtureValid && !spawnedBeyondSlab && missiles.isEmpty && landingTarget.health==landingHealth
        clearMissiles(); place(SIMD3(31.7,0,-34.5))
        let thinSlabShot = SIMD3<Float>(31.7,2.05,-34.5)
        let thinSlabEnd = thinSlabShot+SIMD3(0,-7,0)*0.04
        let thinSlabFixtureValid = !canSee(thinSlabShot,thinSlabEnd) && simd_distance(thinSlabEnd,position)<0.6
        let beforeThinSlab = health
        spawnMissile(at:thinSlabShot,velocity:SIMD3(0,-7,0),hostile:true)
        updateMissiles(0.04)
        combat["hostileSlabImpactCannotAlsoDamagePlayer"] = thinSlabFixtureValid && missiles.isEmpty && health==beforeThinSlab

        clearEnemies(); clearMissiles(); place(eastEntry)
        let exposed = fixture(SIMD3(31.7,2,-36))
        let exposedHealth = exposed.health
        combat["openStairSightlineCrossesHeight"] = canSee(position,enemyCenter(exposed))
        weapon = 0; cooldown = 0; aim(enemyCenter(exposed)); shoot()
        combat["shotgunHitsVisibleEnemyOnHigherStair"] = exposed.health<exposedHealth
        exposed.health = exposedHealth
        weapon = 1; rockets = 100; cooldown = 0; aim(enemyCenter(exposed)); shoot()
        for _ in 0..<45 { updateMissiles(0.02) }
        combat["rocketHitsVisibleEnemyOnHigherStair"] = missiles.isEmpty && exposed.health<exposedHealth
        result["verticalCombat"] = combat
        result["combatRespectsVerticalArchitecture"] = combat.values.allSatisfy { $0 as? Bool == true }

        fragments.forEach{$0.node.removeFromParentNode()};fragments=[]
        let debris=SCNNode();effectsRoot.addChildNode(debris)
        fragments.append(GoreFragment(node:debris,position:SIMD3(31.7,1.3,-34.5),velocity:SIMD3(0,7.2,0),spin:.zero,life:3))
        var fragmentBelow=true
        for _ in 0..<45 {updateFragments(0.04);fragmentBelow = fragmentBelow && fragments.allSatisfy{$0.position.y+0.16<1.67}}
        result["risingDebrisCannotCrossOverheadSlab"]=fragmentBelow

        reset(); setMode("playing"); clearEnemies()
        var collections = [String:Any]()
        let verticalSeals = seals.indices.filter { abs(seals[$0].pos.y-1.2)>2 }
        var sealWrongFloor = true, sealRightFloor = true
        for index in verticalSeals {
            let location = seals[index].pos
            place(SIMD3(location.x,0,location.z)); updatePickups(0)
            sealWrongFloor = sealWrongFloor && !seals[index].collected
            place(SIMD3(location.x,location.y-1.2,location.z)); updatePickups(0)
            sealRightFloor = sealRightFloor && seals[index].collected
        }
        collections["elevatedOrSunkenSealCount"] = verticalSeals.count
        collections["sealsRejectWrongFloor"] = verticalSeals.count==2 && sealWrongFloor
        collections["sealsCollectOnTheirFloor"] = verticalSeals.count==2 && sealRightFloor
        // Seal fixtures may also collect nearby ammo; start fresh so every
        // vertically placed pickup is independently exercised below.
        reset(); setMode("playing"); clearEnemies()
        let verticalLoot = loot.indices.filter { abs(loot[$0].pos.y)>2 && !loot[$0].collected }
        var lootWrongFloor = true, lootRightFloor = true
        for index in verticalLoot {
            let location = loot[index].pos
            place(SIMD3(location.x,0,location.z)); health = 50; updatePickups(0)
            lootWrongFloor = lootWrongFloor && !loot[index].collected
            place(location); health = 50; updatePickups(0)
            lootRightFloor = lootRightFloor && loot[index].collected
        }
        collections["elevatedOrSunkenPickupCount"] = verticalLoot.count
        collections["pickupsRejectWrongFloor"] = !verticalLoot.isEmpty && lootWrongFloor
        collections["pickupsCollectOnTheirFloor"] = !verticalLoot.isEmpty && lootRightFloor
        result["verticalCollections"] = collections
        result["collectionRequiresCorrectFloor"] = verticalSeals.count==2 && sealWrongFloor && sealRightFloor && !verticalLoot.isEmpty && lootWrongFloor && lootRightFloor
        return result
    }
}
