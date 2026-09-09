import SwiftUI

enum PixelSprite {
    case cat, girl, agent
    var rows: [String] {
        switch self {
        case .cat: return [
            "....................", "...XX.......XX......", "...XPX.....XPX......",
            "...XWWXXXXXWWX......", "..XWWWWWWWWWWWX.....", "..XWWWWWWWWWWWX.....",
            ".XWWWXXWWWXXWWWX....", ".XWWWXXWWWXXWWWX....", ".XWPPWWWNWWWPPWX....",
            "..XWWWWXWXWWWWX.....", "...XXWWWWWWWXX......", ".....XWWWWWX........",
            ".....XRHHHRX....XX..", "....XWRHHHRWX...XWX.", "....XWWWWWWWX..XWWX.",
            "....XWWWWWWWXXXWWX..", "....XWWWWWWWWWWWX...", ".....XWWXWWXXXX.....",
            ".....XXXXXXX........", "...................."
        ]
        case .girl: return [
            "......HHHHHH........", ".....HBBBBBBH.......", "....HBBBBBBBBH......",
            "....HBBSSSSBBH......", "....HBSSSSSSBH......", "....HBXSSSXSBH......",
            "....HBSPSSPSBH......", ".....HBSSSSBH.......", "......HSSSSH........",
            "......DDDDDD........", ".....DDDDDDDD.......", ".....DDDDDDDD.......",
            ".....DDDDDDDD.......", ".....DDDDDDDD.......", "....DDDDDDDDDD......",
            "....DDDDDDDDDD......", "......SS..SS........", "......SS..SS........",
            ".....XXX..XXX.......", "...................."
        ]
        case .agent: return [
            ".....XXXXXXXX.......", "....XXXXXXXXXX......", "...XXXXXXXXXXXX.....",
            ".....SSSSSSSS.......", ".....XXXXXXXX.......", ".....XSSXXSSX.......",
            ".....SSSSSSSS.......", "......SSSSSS........", ".....XXSSSSXX.......",
            ".....XXWXXWXX.......", ".....XXWXXWXX.......", ".....XXWXXWXX.......",
            ".....XXYXXYXX.......", ".....XXXXXXXX.......", ".....XXXXXXXX.......",
            ".....XXX..XXX.......", ".....XXX..XXX.......", ".....XXX..XXX.......",
            "....XXXX..XXXX......", "...................."
        ]
        }
    }
    var palette: [Character: Color] {
        ["X": Color(red: 0.16, green: 0.19, blue: 0.24), "W": .white,
         "P": Color(red: 1, green: 0.55, blue: 0.66), "N": Color(red: 0.75, green: 0.27, blue: 0.43),
         "R": Color(red: 0.85, green: 0.20, blue: 0.39), "H": Color(red: 0.28, green: 0.19, blue: 0.28),
         "B": Color(red: 0.36, green: 0.27, blue: 0.35), "S": Color(red: 1, green: 0.80, blue: 0.68),
         "D": Color(red: 0.37, green: 0.55, blue: 0.92), "Y": Color(red: 1, green: 0.80, blue: 0.16)]
    }
}

struct SpriteView: View {
    let sprite: PixelSprite
    var knockPhase: Double = 0
    var body: some View {
        Canvas { context, size in
            let rows = sprite.rows
            let cell = max(1, floor(min(size.width / 20, size.height / 20)))
            let origin = CGPoint(x: floor((size.width - 20 * cell) / 2), y: floor((size.height - 20 * cell) / 2))
            func paint(_ x: Int, _ y: Int, _ width: Int, _ height: Int, _ color: Color) {
                context.fill(Path(CGRect(x: origin.x + CGFloat(x) * cell, y: origin.y + CGFloat(y) * cell,
                                         width: CGFloat(width) * cell, height: CGFloat(height) * cell)),
                             with: .color(color), style: FillStyle(antialiased: false))
            }
            for (y, row) in rows.enumerated() {
                for (x, pixel) in row.enumerated() {
                    if let color = sprite.palette[pixel] {
                        paint(x, y, 1, 1, color)
                    }
                }
            }
            if sprite != .cat {
                // The body sprites contain no arms. Paint one resting arm and one knocking arm.
                let sleeve = sprite.palette[sprite == .girl ? "D" : "X"]!
                let skin = sprite.palette["S"]!
                let reach = knockPhase > 0.5 ? 1 : 0
                paint(3, 10, 2, 3, sleeve)
                paint(3, 13, 2, 2, skin)
                paint(13, 10, 3, 2, sleeve)
                paint(16, 10, 1 + reach, 2, skin)
                paint(17 + reach, 9, 2, 3, skin)
            }
        }.accessibilityHidden(true)
    }
}

struct PixelGrid: View {
    var color: Color = .black.opacity(0.045)
    var body: some View {
        Canvas { context, size in
            for x in stride(from: 0.0, to: size.width, by: 22) {
                for y in stride(from: 0.0, to: size.height, by: 22) {
                    context.fill(Path(CGRect(x: x, y: y, width: 2, height: 2)), with: .color(color))
                }
            }
        }.accessibilityHidden(true).allowsHitTesting(false)
    }
}

struct CharacterStage: View {
    let theme: ReminderTheme
    var animated = true
    var compact = false
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    @State private var started = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24, paused: !animated || reducedMotion)) { timeline in
            let seconds = animated && !reducedMotion ? timeline.date.timeIntervalSince(started) : 0
            let hop = animated && !reducedMotion ? max(0, sin(seconds * 3.6)) : 0
            GeometryReader { geometry in
                let w = geometry.size.width, h = geometry.size.height
                let scale = min(w / 260, h / 220)
                ZStack {
                    if theme == .cat {
                        Ellipse().fill(Color.black.opacity(0.08)).frame(width: 86 - hop * 18, height: 8).position(x: 130, y: 205)
                        SpriteView(sprite: .cat).frame(width: 180, height: 180).position(x: 130, y: 113 - hop * 20)
                        Image(systemName: "sparkle").font(.system(size: 18, weight: .medium)).foregroundStyle(theme.accent.opacity(0.7))
                            .position(x: 211, y: 66 + hop * 5)
                    } else if theme == .girl || theme == .fbi {
                        Rectangle().fill(Color.primary.opacity(0.10)).frame(width: 215, height: 1).position(x: 132, y: 207)
                        door.frame(width: 82, height: 170).position(x: 192 + (hop > 0.8 ? 1 : 0), y: 121)
                        SpriteView(sprite: theme == .girl ? .girl : .agent, knockPhase: hop)
                            .frame(width: 180, height: 180).position(x: 95, y: 121)
                        Text(theme == .girl ? L("KNOCK!") : L("BAM!"))
                            .font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(theme.accent)
                            .rotationEffect(.degrees(-5)).position(x: 189, y: 18)
                    } else if theme == .banner {
                        Image(systemName: "megaphone.fill").font(.system(size: 68, weight: .regular)).foregroundStyle(theme.accent)
                            .rotationEffect(.degrees(sin(seconds * 3) * 5)).position(x: 130, y: 110)
                    } else {
                        Image(systemName: "calendar.badge.clock").font(.system(size: 64, weight: .light)).foregroundStyle(theme.accent).position(x: 130, y: 110)
                    }
                }.frame(width: 260, height: 220).scaleEffect(scale).position(x: w / 2, y: h / 2)
            }
        }.accessibilityHidden(true)
    }

    private var door: some View {
        ZStack(alignment: .trailing) {
            Rectangle().fill(theme == .fbi ? Color(red: 0.83, green: 0.88, blue: 0.89) : Color(red: 0.81, green: 0.88, blue: 0.97))
            Rectangle().strokeBorder(Color(red: 0.30, green: 0.37, blue: 0.43), lineWidth: 3)
            VStack(spacing: 12) {
                Rectangle().strokeBorder(Color.black.opacity(0.13), lineWidth: 2)
                Rectangle().strokeBorder(Color.black.opacity(0.13), lineWidth: 2)
            }.padding(11)
            Rectangle().fill(Color(red: 0.20, green: 0.25, blue: 0.32)).frame(width: 9, height: 9).padding(.trailing, 10)
        }
    }
}
