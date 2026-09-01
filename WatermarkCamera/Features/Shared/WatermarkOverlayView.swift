import SwiftUI

/// 复用的水印叠加视图（SwiftUI 近似渲染，用于实时预览与编辑预览）。
/// 最终导出仍由 WatermarkRenderer 位图绘制保证像素级一致。
struct WatermarkOverlayView: View {
    let data: WatermarkData
    let template: WatermarkTemplateSnapshot
    /// 相对参考宽度的缩放（预览容器宽 / 1080）
    var scale: CGFloat = 0.3

    private var lines: [String] {
        WatermarkRenderer().makeLines(data: data, template: template)
    }

    var body: some View {
        let fontSize = template.fontSize * scale
        let alignment = horizontalAlignment
        VStack(alignment: alignment, spacing: fontSize * 0.35) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.custom(template.fontName, size: fontSize))
                    .foregroundStyle(Color(hex: template.textColorHex).opacity(template.opacity))
                    .shadow(color: template.backgroundStyle == .shadow ? .black.opacity(0.6) : .clear,
                            radius: 3, x: 0, y: 1)
            }
        }
        .padding(template.backgroundStyle == .translucent ? 8 : 0)
        .background {
            if template.backgroundStyle == .translucent {
                RoundedRectangle(cornerRadius: 6).fill(.black.opacity(0.35))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: frameAlignment)
        .padding(16)
    }

    private var horizontalAlignment: HorizontalAlignment {
        switch template.position.unitPoint.x {
        case 0: return .leading
        case 1: return .trailing
        default: return .center
        }
    }

    private var frameAlignment: Alignment {
        let p = template.position.unitPoint
        let h: HorizontalAlignment = p.x == 0 ? .leading : (p.x == 1 ? .trailing : .center)
        let v: VerticalAlignment = p.y == 0 ? .top : (p.y == 1 ? .bottom : .center)
        return Alignment(horizontal: h, vertical: v)
    }
}
