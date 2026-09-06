import AppKit
import SceneKit
import CoreGraphics

final class GameView: SCNView {
    weak var game:Game?
    var mouseCaptured=false
    var tracking:NSTrackingArea?
    override var acceptsFirstResponder:Bool {true}
    override func updateTrackingAreas() {
        super.updateTrackingAreas();if let t=tracking {removeTrackingArea(t)}
        tracking=NSTrackingArea(rect:bounds,options:[.activeInKeyWindow,.mouseMoved,.inVisibleRect],owner:self,userInfo:nil);addTrackingArea(tracking!)
    }
    func captureMouse(){guard !mouseCaptured,window?.isKeyWindow==true else{return};window?.makeFirstResponder(self);mouseCaptured=true;NSCursor.hide();CGAssociateMouseAndMouseCursorPosition(0)}
    func releaseMouse(){game?.keys.removeAll();game?.mouseHeld=false;game?.jumpRequested=false;guard mouseCaptured else{return};mouseCaptured=false;CGAssociateMouseAndMouseCursorPosition(1);NSCursor.unhide()}
    override func keyDown(with event:NSEvent){game?.keyDown(event)}
    override func keyUp(with event:NSEvent){game?.keys.remove(event.keyCode)}
    override func flagsChanged(with event:NSEvent){if game?.mode=="playing" && event.modifierFlags.contains(.shift){game?.keys.insert(56)}else{game?.keys.remove(56)}}
    override func mouseDown(with event:NSEvent){game?.click()}
    override func mouseUp(with event:NSEvent){game?.mouseHeld=false}
    override func rightMouseDown(with event:NSEvent){}
    override func rightMouseUp(with event:NSEvent){}
    override func mouseMoved(with event:NSEvent){game?.look(event.deltaX,event.deltaY)}
    override func mouseDragged(with event:NSEvent){game?.look(event.deltaX,event.deltaY)}
    override func rightMouseDragged(with event:NSEvent){game?.look(event.deltaX,event.deltaY)}
    override func scrollWheel(with event:NSEvent){}
}
final class AppDelegate:NSObject,NSApplicationDelegate,NSWindowDelegate {
    var window:NSWindow!;var game:Game!;var view:GameView!
    func applicationDidFinishLaunching(_ notification:Notification) {
        let menu=NSMenu();let appItem=NSMenuItem();menu.addItem(appItem);let appMenu=NSMenu();appItem.submenu=appMenu
        appMenu.addItem(withTitle:"About Black Reliquary",action:#selector(about),keyEquivalent:"")
        appMenu.addItem(.separator());appMenu.addItem(withTitle:"Quit Black Reliquary",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q")
        let viewItem=NSMenuItem();menu.addItem(viewItem);let viewMenu=NSMenu(title:"View");viewItem.submenu=viewMenu
        let full=viewMenu.addItem(withTitle:"Enter Full Screen",action:#selector(NSWindow.toggleFullScreen(_:)),keyEquivalent:"f");full.keyEquivalentModifierMask=[.control,.command]
        NSApp.mainMenu=menu
        let screen=NSScreen.main?.visibleFrame ?? NSRect(x:0,y:0,width:1440,height:900)
        let width=min(CGFloat(1280),screen.width-100);let height=min(CGFloat(800),screen.height-100)
        window=NSWindow(contentRect:NSRect(x:0,y:0,width:width,height:height),styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
        window.title="Black Reliquary";window.backgroundColor = .black;window.minSize=NSSize(width:900,height:600);window.collectionBehavior=[.fullScreenPrimary];window.delegate=self;window.acceptsMouseMovedEvents=true
        window.titlebarAppearsTransparent=true;window.appearance=NSAppearance(named:.darkAqua)
        let container=NSView(frame:NSRect(x:0,y:0,width:width,height:height));container.wantsLayer=true;container.layer?.backgroundColor=NSColor.black.cgColor
        view=GameView(frame:container.bounds,options:[SCNView.Option.preferredRenderingAPI.rawValue:SCNRenderingAPI.metal.rawValue]);view.autoresizingMask=[.width,.height]
        let hud=HUDView(frame:container.bounds);hud.autoresizingMask=[.width,.height]
        container.addSubview(view);container.addSubview(hud);window.contentView=container
        window.center();window.makeKeyAndOrderFront(nil);window.makeFirstResponder(view);NSApp.activate(ignoringOtherApps:true)
        game=Game(view:view,hud:hud)
        if CommandLine.arguments.contains("--fullscreen") {window.toggleFullScreen(nil)}
    }
    @objc func about(){NSApp.orderFrontStandardAboutPanel(options:[.applicationName:"Black Reliquary",.applicationVersion:"0.4 — The Winding Cathedral",.credits:NSAttributedString(string:"An original gothic FPS prototype.\nNative Apple Silicon • Swift • Metal\nOriginal procedural architecture and audio.")])}
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool{true}
    func applicationWillTerminate(_ notification:Notification){view?.releaseMouse();game?.audio.stop();game?.timer?.invalidate()}
    func windowDidResignKey(_ notification:Notification){view?.releaseMouse();if game?.mode=="playing" && game?.testMode==false && game?.autoPlay==false {game?.setMode("paused")}}
    func windowWillEnterFullScreen(_ notification:Notification){view?.releaseMouse()}
    func windowWillExitFullScreen(_ notification:Notification){view?.releaseMouse()}
    func windowDidEnterFullScreen(_ notification:Notification){if game?.mode=="playing" {view.captureMouse()}}
    func windowDidExitFullScreen(_ notification:Notification){if game?.mode=="playing" {view.captureMouse()}}
}
let app=NSApplication.shared
let delegate=AppDelegate()
app.setActivationPolicy(.regular);app.delegate=delegate;app.run()
