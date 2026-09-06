import AppKit

struct HUDState {
    var mode: String = "menu"
    var health: Int = 100
    var shells: Int = 40
    var rockets: Int = 8
    var weapon: Int = 0
    var seals: Int = 0
    var kills: Int = 0
    var totalEnemies: Int = 22
    var elapsed: Double = 0
    var location: String = "The Narthex"
    var message: String = ""
    var messageAlpha: CGFloat = 0
    var damage: CGFloat = 0
    var hit: CGFloat = 0
    var fps: Int = 60
    var sensitivity: Double = 1.0
    var muted: Bool = false
    var powerupRemaining: Double = 0
    var gateOpen: Bool = false
}

final class HUDView: NSView {
    var state = HUDState() { didSet { needsDisplay = true } }
    override var isOpaque: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    private let ivory = NSColor(calibratedRed: 0.88, green: 0.86, blue: 0.79, alpha: 1)
    private let gold = NSColor(calibratedRed: 0.67, green: 0.57, blue: 0.38, alpha: 1)
    private let muted = NSColor(calibratedRed: 0.57, green: 0.59, blue: 0.56, alpha: 1)
    private let red = NSColor(calibratedRed: 0.77, green: 0.23, blue: 0.17, alpha: 1)
    private var unit: CGFloat { min(1.2, max(0.68, min(bounds.width / 1300, bounds.height / 850))) }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        switch state.mode {
        case "menu": drawMenu()
        case "paused": drawGame(); drawPause()
        case "dead": drawGame(); drawEnding(won: false)
        case "won": drawGame(); drawEnding(won: true)
        default: drawGame()
        }
    }

    private func type(_ value: String, x: CGFloat, y: CGFloat, width: CGFloat, size: CGFloat,
                      color: NSColor? = nil, tracking: CGFloat = 0, serif: Bool = false,
                      weight: NSFont.Weight = .regular, align: NSTextAlignment = .left,
                      height: CGFloat? = nil) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = align
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = size * 0.3
        let font = serif ? (NSFont(name: "Baskerville", size: size) ?? NSFont.systemFont(ofSize: size, weight: .light))
                         : NSFont.systemFont(ofSize: size, weight: weight)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: color ?? ivory, .kern: tracking,
            .paragraphStyle: paragraph
        ]
        NSAttributedString(string: value, attributes: attributes)
            .draw(in: NSRect(x: x, y: y, width: width, height: height ?? size * 1.6))
    }

    private func rule(_ a: NSPoint, _ b: NSPoint, color: NSColor, width: CGFloat = 1) {
        color.setStroke()
        let line = NSBezierPath(); line.lineWidth = width
        line.move(to: a); line.line(to: b); line.stroke()
    }

    private func diamond(x: CGFloat, y: CGFloat, radius: CGFloat, filled: Bool, color: NSColor) {
        let shape = NSBezierPath()
        shape.move(to: NSPoint(x: x, y: y + radius))
        shape.line(to: NSPoint(x: x + radius * 0.6, y: y))
        shape.line(to: NSPoint(x: x, y: y - radius))
        shape.line(to: NSPoint(x: x - radius * 0.6, y: y))
        shape.close(); shape.lineWidth = 1
        if filled { color.setFill(); shape.fill() } else { color.setStroke(); shape.stroke() }
    }

    private func darken(_ alpha: CGFloat) {
        NSColor.black.withAlphaComponent(alpha).setFill(); bounds.fill()
    }

    private func drawMenu() {
        let w = bounds.width, h = bounds.height, s = unit, x = 65 * s
        darken(0.15)
        NSGradient(starting: NSColor.black.withAlphaComponent(0.91), ending: .clear)?
            .draw(in: NSRect(x: 0, y: 0, width: w * 0.91, height: h), angle: 0)
        NSGradient(starting: NSColor.black.withAlphaComponent(0.83), ending: .clear)?
            .draw(in: NSRect(x: 0, y: 0, width: w, height: 220 * s), angle: 90)

        diamond(x: x + 3 * s, y: h - 67 * s, radius: 7 * s, filled: false, color: gold)
        type("CHAPTER  01     /     THE HOLLOW CATHEDRAL", x: x + 23 * s, y: h - 79 * s,
             width: 550 * s, size: 11 * s, color: gold, tracking: 2 * s, weight: .medium)

        let titleY = h * 0.535
        type("BLACK", x: x - 3 * s, y: titleY + 80 * s, width: 660 * s,
             size: 88 * s, color: ivory, tracking: 3 * s, serif: true, height: 116 * s)
        type("RELIQUARY", x: x - 3 * s, y: titleY, width: 660 * s,
             size: 88 * s, color: ivory, tracking: 1 * s, serif: true, height: 116 * s)

        let dividerY = titleY - 7 * s
        rule(NSPoint(x: x, y: dividerY), NSPoint(x: x + 53 * s, y: dividerY), color: gold)
        type("Something beneath the altar is still awake.", x: x, y: dividerY - 46 * s,
             width: 520 * s, size: 20 * s, color: ivory.withAlphaComponent(0.82), serif: true)
        type("Recover three seals. Break the cathedral’s hold.", x: x, y: dividerY - 77 * s,
             width: 540 * s, size: 13 * s, color: muted)

        let promptY = max(172 * s, dividerY - 161 * s)
        let promptBox = NSRect(x: x, y: promptY, width: 335 * s, height: 47 * s)
        NSColor.black.withAlphaComponent(0.18).setFill(); promptBox.fill()
        gold.withAlphaComponent(0.5).setStroke()
        let border = NSBezierPath(rect: promptBox); border.lineWidth = 0.8; border.stroke()
        type("ENTER  /  CLICK TO DESCEND", x: x + 19 * s, y: promptY + 11 * s,
             width: 300 * s, size: 12 * s, color: ivory, tracking: 1.8 * s, weight: .medium)

        drawControls(x: x, y: 89 * s, width: w - 2 * x, scale: s)
        rule(NSPoint(x: x, y: 51 * s), NSPoint(x: w - x, y: 51 * s), color: gold.withAlphaComponent(0.22))
        type("AN ORIGINAL GOTHIC SHOOTER", x: x, y: 20 * s, width: 410 * s,
             size: 9 * s, color: muted, tracking: 1.7 * s)
        type("BLOODFIRE UPDATE     /     CHAPTER 01", x: w - x - 470 * s, y: 20 * s,
             width: 470 * s, size: 9 * s, color: muted, tracking: 1.3 * s, align: .right)
    }

    private func drawControls(x: CGFloat, y: CGFloat, width: CGFloat, scale s: CGFloat) {
        type("WASD  Move       TRACKPAD  Aim       SPACE / CLICK  Fire", x: x, y: y + 22 * s,
             width: width, size: 11 * s, color: ivory.withAlphaComponent(0.72), tracking: 0.3 * s)
        type("SHIFT  Jump       1 / 2  Weapons       F  Fullscreen       ESC  Pause", x: x, y: y,
             width: width, size: 11 * s, color: muted, tracking: 0.3 * s)
    }

    private func drawGame() {
        let w = bounds.width, h = bounds.height, s = unit, edge = 42 * s
        NSGradient(starting: NSColor.black.withAlphaComponent(0.75), ending: .clear)?
            .draw(in: NSRect(x: 0, y: 0, width: w, height: 158 * s), angle: 90)
        NSGradient(starting: .clear, ending: NSColor.black.withAlphaComponent(0.49))?
            .draw(in: NSRect(x: 0, y: h - 112 * s, width: w, height: 112 * s), angle: 90)

        type(state.location.uppercased(), x: edge, y: h - 53 * s, width: w * 0.55,
             size: 12 * s, color: ivory.withAlphaComponent(0.9), tracking: 2.2 * s, weight: .medium)
        type(state.seals >= 3 ? "REACH THE NORTHERN GATE" : "RECOVER THE THREE SEALS", x: edge, y: h - 76 * s,
             width: w * 0.6, size: 9 * s, color: gold, tracking: 1.5 * s)
        type(String(format: "%02d:%02d", Int(max(0, state.elapsed)) / 60, Int(max(0, state.elapsed)) % 60),
             x: w - edge - 120 * s, y: h - 53 * s, width: 120 * s, size: 12 * s,
             color: muted, tracking: 1 * s, align: .right)

        // A fine, open reticle preserves visibility of distant enemies.
        let cx = w / 2, cy = h / 2, gap = 6 * s, length = 6 * s
        let reticle = state.powerupRemaining>0 ? NSColor(calibratedRed:1,green:0.3,blue:0.08,alpha:0.95) : ivory.withAlphaComponent(0.8)
        rule(NSPoint(x: cx - gap - length, y: cy), NSPoint(x: cx - gap, y: cy), color: reticle)
        rule(NSPoint(x: cx + gap, y: cy), NSPoint(x: cx + gap + length, y: cy), color: reticle)
        rule(NSPoint(x: cx, y: cy - gap - length), NSPoint(x: cx, y: cy - gap), color: reticle)
        rule(NSPoint(x: cx, y: cy + gap), NSPoint(x: cx, y: cy + gap + length), color: reticle)
        if state.hit > 0 {
            let hitColor = gold.withAlphaComponent(min(1, state.hit))
            for dx: CGFloat in [-1, 1] {
                for dy: CGFloat in [-1, 1] {
                    rule(NSPoint(x: cx + dx * 10 * s, y: cy + dy * 10 * s),
                         NSPoint(x: cx + dx * 16 * s, y: cy + dy * 16 * s), color: hitColor, width: 1.5 * s)
                }
            }
        }

        let healthColor = state.health <= 30 ? red : ivory
        type("VITALITY", x: edge, y: 92 * s, width: 190 * s, size: 9 * s, color: gold, tracking: 2 * s)
        type(String(max(0, state.health)), x: edge - 2 * s, y: 34 * s, width: 180 * s,
             size: 48 * s, color: healthColor, serif: true, height: 58 * s)
        let healthTrack = NSRect(x: edge, y: 31 * s, width: 122 * s, height: 2 * s)
        ivory.withAlphaComponent(0.16).setFill(); healthTrack.fill()
        healthColor.withAlphaComponent(0.7).setFill()
        NSRect(x: edge, y: 31 * s, width: healthTrack.width * CGFloat(max(0, min(100, state.health))) / 100, height: 2 * s).fill()

        for i in 0..<3 {
            diamond(x: w / 2 + CGFloat(i - 1) * 28 * s, y: 78 * s, radius: 11 * s,
                    filled: i < state.seals, color: i < state.seals ? gold : ivory.withAlphaComponent(0.32))
        }
        type(state.gateOpen ? "GATE OPEN · HEAD NORTH" : "\(state.seals) / 3   SEALS", x: w / 2 - 150 * s, y: 36 * s,
             width: 300 * s, size: 9 * s, color: state.gateOpen ? NSColor(calibratedRed:0.4,green:0.95,blue:0.64,alpha:1):muted, tracking: 1.8 * s, align: .center)

        if state.powerupRemaining>0 {
            let fire=NSColor(calibratedRed:1,green:0.33,blue:0.09,alpha:1)
            let box=NSRect(x:w/2-153*s,y:h-100*s,width:306*s,height:40*s)
            NSColor(calibratedRed:0.065,green:0.012,blue:0.006,alpha:0.9).setFill(); box.fill()
            type(String(format:"BLOODFIRE   5× DAMAGE   %02ds",Int(ceil(state.powerupRemaining))),x:box.minX,y:box.minY+12*s,width:box.width,size:11*s,color:fire,tracking:1*s,align:.center)
            fire.withAlphaComponent(0.22).setFill(); NSRect(x:box.minX,y:box.minY,width:box.width,height:3*s).fill()
            fire.setFill(); NSRect(x:box.minX,y:box.minY,width:box.width*CGFloat(min(1,state.powerupRemaining/25)),height:3*s).fill()
        }

        type(state.weapon == 0 ? "01   /   IRON SHOTGUN" : "02   /   ROCKET LANCE",
             x: w - edge - 300 * s, y: 92 * s, width: 300 * s,
             size: 9 * s, color: gold, tracking: 1.7 * s, align: .right)
        let ammo = state.weapon == 0 ? state.shells : state.rockets
        type(String(max(0, ammo)), x: w - edge - 160 * s, y: 34 * s, width: 160 * s,
             size: 48 * s, color: ammo == 0 ? red : ivory, serif: true, align: .right, height: 58 * s)
        type(state.weapon == 0 ? "SHELLS" : "ROCKETS", x: w - edge - 280 * s, y: 43 * s, width: 180 * s,
             size: 9 * s, color: muted, tracking: 1.7 * s, align: .right)

        if !state.message.isEmpty && state.messageAlpha > 0 {
            let alpha = min(1, state.messageAlpha)
            type(state.message, x: w * 0.15, y: 147 * s, width: w * 0.7, size: 17 * s,
                 color: ivory.withAlphaComponent(alpha), serif: true, align: .center)
        }
        if state.damage > 0 {
            let alpha = min(0.48, state.damage * 0.48)
            NSGradient(starting: .clear, ending: red.withAlphaComponent(alpha))?
                .draw(in: bounds, relativeCenterPosition: .zero)
        }
    }

    private func overlayBase() {
        darken(0.77)
        let s = unit, cx = bounds.midX
        rule(NSPoint(x: cx - 160 * s, y: bounds.height * 0.72),
             NSPoint(x: cx - 17 * s, y: bounds.height * 0.72), color: gold.withAlphaComponent(0.42))
        rule(NSPoint(x: cx + 17 * s, y: bounds.height * 0.72),
             NSPoint(x: cx + 160 * s, y: bounds.height * 0.72), color: gold.withAlphaComponent(0.42))
        diamond(x: cx, y: bounds.height * 0.72, radius: 10 * s, filled: false, color: gold)
    }

    private func drawPause() {
        overlayBase()
        let w = bounds.width, h = bounds.height, s = unit, cx = w / 2
        type("THE CATHEDRAL WAITS", x: 0, y: h * 0.59, width: w, size: 45 * s,
             tracking: 1.2 * s, serif: true, align: .center)
        type("ESC / ENTER / CLICK TO RESUME", x: 0, y: h * 0.535, width: w,
             size: 11 * s, color: gold, tracking: 1.7 * s, align: .center)
        drawControls(x: cx - 285 * s, y: h * 0.38, width: 620 * s, scale: s)
        type(String(format: "[ / ]  Aim sensitivity  %.1f     •     M  Sound %@", state.sensitivity, state.muted ? "off" : "on"),
             x: 0, y: h * 0.29, width: w, size: 12 * s, color: ivory.withAlphaComponent(0.7), align: .center)
        type("R  RESTART     /     F  FULLSCREEN", x: 0, y: h * 0.21, width: w,
             size: 10 * s, color: muted, tracking: 1.5 * s, align: .center)
    }

    private func drawEnding(won: Bool) {
        overlayBase()
        let w = bounds.width, h = bounds.height, s = unit
        type(won ? "THE HOLD IS BROKEN" : "THE HOLLOW TAKES YOU", x: 0, y: h * 0.59,
             width: w, size: 48 * s, color: won ? ivory : ivory.withAlphaComponent(0.9),
             tracking: 0.6 * s, serif: true, align: .center)
        type(won ? "Three seals claimed. The cathedral falls silent." : "The altar is still waiting. Descend once more.",
             x: 0, y: h * 0.52, width: w, size: 18 * s, color: muted, serif: true, align: .center)
        let minutes = Int(max(0, state.elapsed)) / 60, seconds = Int(max(0, state.elapsed)) % 60
        let stats = String(format: "%02d:%02d  ELAPSED     /     %d OF %d SLAIN     /     %d OF 3 SEALS",
                           minutes, seconds, state.kills, state.totalEnemies, state.seals)
        type(stats, x: 30 * s, y: h * 0.395, width: w - 60 * s,
             size: 11 * s, color: gold, tracking: 1.4 * s, align: .center)
        type("ENTER / CLICK TO DESCEND AGAIN", x: 0, y: h * 0.27, width: w,
             size: 11 * s, color: ivory, tracking: 1.8 * s, align: .center)
        if won {
            type("END OF CHAPTER 01     ·     BLACK RELIQUARY", x: 0, y: h * 0.15, width: w,
                 size: 9 * s, color: muted, tracking: 1.5 * s, align: .center)
        }
    }
}
