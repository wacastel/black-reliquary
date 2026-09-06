import AppKit
import SceneKit
import simd

extension Game {
    /// Opt-in native render inspection of the authored spaces; never used in normal play.
    func captureArchitecture(in directory:String) {
        try? FileManager.default.createDirectory(atPath:directory,withIntermediateDirectories:true)
        testMode=false;reset();setMode("preview")
        let shots:[(String,SIMD3<Float>,SIMD3<Float>,String)]=[
            ("Nave",SIMD3(0,1.65,3),SIMD3(0,6.5,-15),"The Hollow Cathedral"),
            ("Crossing-vault",SIMD3(0,1.65,-34),SIMD3(0,12,-49),"The High Crossing"),
            ("Winding-staircase",SIMD3(31.7,1.65,-43.5),SIMD3(33,4,-34.5),"The Ascending Stair"),
            ("Upper-gallery",SIMD3(34,7.65,-49),SIMD3(40,2.5,-38),"The Upper Reliquary"),
            ("Below-gallery",SIMD3(38,1.65,-51),SIMD3(41,4.5,-44),"Below the Gallery"),
            ("Sunken-crypt",SIMD3(-38,-4.35,-49),SIMD3(-43,0,-35),"The Sunken Ossuary")
        ]
        var metrics=[[String:Any]]()
        func capture(_ index:Int) {
            guard index<shots.count else {
                if let data=try? JSONSerialization.data(withJSONObject:metrics,options:[.prettyPrinted,.sortedKeys]) {
                    try? data.write(to:URL(fileURLWithPath:directory+"/architecture-performance.json"))
                }
                NSApp.terminate(nil);return
            }
            let shot=shots[index];self.position=shot.1
            let direction=shot.2-shot.1
            self.yaw=atan2(-direction.x,-direction.z)
            self.pitch=atan2(direction.y,hypot(direction.x,direction.z))
            self.lastZone=shot.3;self.message="";self.messageTime=0
            self.updateEnemies(0);self.updateCamera();self.refreshHUD()
            DispatchQueue.main.asyncAfter(deadline:.now()+1) {self.renderProbe.reset()}
            DispatchQueue.main.asyncAfter(deadline:.now()+3) {
                self.savePreview(directory+"/"+shot.0+".png")
                metrics.append(["scene":shot.0,"renderFPS":self.renderProbe.framesPerSecond])
                capture(index+1)
            }
        }
        capture(0)
    }
}
