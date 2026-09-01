import Foundation
import UIKit
import CoreGraphics
import AVFoundation

/// 水印渲染。统一将 WatermarkData + 模板渲染为叠加层，照片与视频复用同一排版逻辑。
protocol WatermarkRendering: Sendable {
    /// 生成与画布同尺寸的透明叠加图（供照片合成）
    func makeOverlayImage(data: WatermarkData,
                          template: WatermarkTemplateSnapshot,
                          canvasSize: CGSize) -> UIImage
    /// 生成用于视频合成的 CALayer（静态）
    func makeOverlayLayer(data: WatermarkData,
                          template: WatermarkTemplateSnapshot,
                          videoSize: CGSize) -> CALayer
    /// 生成用于视频合成的 CALayer 容器：时间行按秒动态刷新
    func makeVideoOverlayLayer(data: WatermarkData,
                               template: WatermarkTemplateSnapshot,
                               videoSize: CGSize,
                               duration: TimeInterval) -> CALayer
}

final class WatermarkRenderer: WatermarkRendering {

    /// 排版参考宽度：字号以此为基准按画布宽度等比缩放
    private let referenceWidth: CGFloat = 1080
    /// 视频逐秒动态时间的最大时长上限（超过则退化为静态起始时间，避免图层过多）
    private let maxTickingSeconds = 1800

    func makeOverlayImage(data: WatermarkData,
                          template: WatermarkTemplateSnapshot,
                          canvasSize: CGSize) -> UIImage {
        renderImage(data: data, template: template, canvasSize: canvasSize, skipLineIndex: nil)
    }

    func makeOverlayLayer(data: WatermarkData,
                          template: WatermarkTemplateSnapshot,
                          videoSize: CGSize) -> CALayer {
        let image = makeOverlayImage(data: data, template: template, canvasSize: videoSize)
        let layer = CALayer()
        layer.frame = CGRect(origin: .zero, size: videoSize)
        layer.contents = image.cgImage
        layer.contentsGravity = .resizeAspect
        return layer
    }

    // MARK: - 视频动态叠加层

    func makeVideoOverlayLayer(data: WatermarkData,
                               template: WatermarkTemplateSnapshot,
                               videoSize: CGSize,
                               duration: TimeInterval) -> CALayer {
        let container = CALayer()
        container.frame = CGRect(origin: .zero, size: videoSize)

        let lines = makeLines(data: data, template: template)
        guard !lines.isEmpty else { return container }

        let totalSeconds = Int(ceil(duration))
        // 仅当模板启用时间、时长有效且在上限内，才启用逐秒动态刷新
        let canTick = template.enabledFields.contains(.time)
            && totalSeconds >= 1
            && totalSeconds <= maxTickingSeconds

        guard canTick, let layout = computeLayout(data: data, template: template, canvasSize: videoSize) else {
            let image = makeOverlayImage(data: data, template: template, canvasSize: videoSize)
            let layer = CALayer()
            layer.frame = CGRect(origin: .zero, size: videoSize)
            layer.contents = image.cgImage
            layer.contentsGravity = .resizeAspect
            container.addSublayer(layer)
            return container
        }

        // 静态层：绘制除时间行（第 0 行）以外的全部内容与背景
        let staticImage = renderImage(data: data, template: template,
                                      canvasSize: videoSize, skipLineIndex: 0)
        let staticLayer = CALayer()
        staticLayer.frame = CGRect(origin: .zero, size: videoSize)
        staticLayer.contents = staticImage.cgImage
        staticLayer.contentsGravity = .resizeAspect
        container.addSublayer(staticLayer)

        // 动态时间行：每秒一个文本层，用离散透明度关键帧控制显隐
        let secondsFormat = Self.secondsDateFormat(from: template.dateFormat)
        for second in 0..<totalSeconds {
            let ts = data.timestamp.addingTimeInterval(TimeInterval(second))
            var slice = data
            slice.timestamp = ts
            let text = firstLineString(data: slice, template: template, timeFormat: secondsFormat)
            guard let text, !text.isEmpty else { continue }

            let attributed = NSAttributedString(string: text, attributes: layout.attributes)
            let size = attributed.size()
            let x = layout.originX + (layout.blockWidth - size.width) * layout.anchorX
            // Core Animation 坐标系原点在左下角，需将 UIKit 顶部坐标翻转
            let yCA = videoSize.height - layout.originY - size.height

            let textLayer = CATextLayer()
            textLayer.string = attributed
            textLayer.isWrapped = false
            textLayer.alignmentMode = .left
            textLayer.contentsScale = 1
            textLayer.frame = CGRect(x: x, y: yCA, width: ceil(size.width), height: ceil(size.height))
            textLayer.opacity = 0
            if template.backgroundStyle == .shadow {
                textLayer.shadowColor = UIColor.black.cgColor
                textLayer.shadowOpacity = 0.6
                textLayer.shadowRadius = 4 * layout.scale
                textLayer.shadowOffset = CGSize(width: 0, height: -1 * layout.scale)
            }
            addOpacityWindow(to: textLayer, second: second, totalSeconds: totalSeconds, duration: duration)
            container.addSublayer(textLayer)
        }

        return container
    }

    /// 为文本层添加“仅在 [second, second+1) 秒可见”的离散透明度动画
    private func addOpacityWindow(to layer: CALayer,
                                  second: Int,
                                  totalSeconds: Int,
                                  duration: TimeInterval) {
        let a = min(max(TimeInterval(second) / duration, 0), 1)
        let b = min(max(TimeInterval(second + 1) / duration, 0), 1)

        var keyTimes: [NSNumber]
        var values: [NSNumber]
        if a <= 0 && b >= 1 {
            keyTimes = [0, 1]; values = [1, 1]
        } else if a <= 0 {
            keyTimes = [0, NSNumber(value: b), 1]; values = [1, 0, 0]
        } else if b >= 1 {
            keyTimes = [0, NSNumber(value: a), 1]; values = [0, 1, 1]
        } else {
            keyTimes = [0, NSNumber(value: a), NSNumber(value: b), 1]; values = [0, 1, 0, 0]
        }

        let anim = CAKeyframeAnimation(keyPath: "opacity")
        anim.calculationMode = .discrete
        anim.keyTimes = keyTimes
        anim.values = values
        anim.duration = duration
        anim.beginTime = AVCoreAnimationBeginTimeAtZero
        anim.isRemovedOnCompletion = false
        anim.fillMode = .forwards
        layer.add(anim, forKey: "opacity")
    }

    // MARK: - 文案组装

    /// 第一行（时间 + 星期）文本；两者都未启用时返回 nil
    private func firstLineString(data: WatermarkData,
                                 template: WatermarkTemplateSnapshot,
                                 timeFormat: String? = nil) -> String? {
        var comps: [String] = []
        if template.enabledFields.contains(.time) {
            comps.append(data.timeString(format: timeFormat ?? template.dateFormat))
        }
        if template.enabledFields.contains(.weekday) {
            comps.append(data.weekdayString())
        }
        return comps.isEmpty ? nil : comps.joined(separator: "  ")
    }

    /// 根据模板启用字段，构造若干行文本
    func makeLines(data: WatermarkData, template: WatermarkTemplateSnapshot) -> [String] {
        var lines: [String] = []
        let fields = template.enabledFields

        if let first = firstLineString(data: data, template: template) {
            lines.append(first)
        }

        if fields.contains(.place), let place = data.placeName, !place.isEmpty {
            lines.append(place)
        }

        var weatherLine: [String] = []
        if fields.contains(.weather), let w = data.weather {
            weatherLine.append(w.condition)
        }
        if fields.contains(.temperature), let w = data.weather {
            weatherLine.append(w.formattedTemperature(unit: TemperaturePreference.current))
        }
        if !weatherLine.isEmpty { lines.append(weatherLine.joined(separator: "  ")) }

        return lines
    }

    /// 在时间格式基础上补足“秒”，供视频动态时间使用
    static func secondsDateFormat(from format: String) -> String {
        format.contains("s") ? format : format + ":ss"
    }

    // MARK: - 排版计算

    private struct Layout {
        let scale: CGFloat
        let lineSpacing: CGFloat
        let attributes: [NSAttributedString.Key: Any]
        let attributedLines: [NSAttributedString]
        let lineSizes: [CGSize]
        let blockWidth: CGFloat
        let blockHeight: CGFloat
        let originX: CGFloat
        let originY: CGFloat
        let anchorX: CGFloat
        let anchorY: CGFloat
    }

    private func computeLayout(data: WatermarkData,
                               template: WatermarkTemplateSnapshot,
                               canvasSize: CGSize) -> Layout? {
        let lines = makeLines(data: data, template: template)
        guard !lines.isEmpty else { return nil }

        let scale = canvasSize.width / referenceWidth
        let fontSize = max(10, template.fontSize * scale)
        let margin = 28 * scale
        let lineSpacing = fontSize * 0.35

        let font = UIFont(name: template.fontName, size: fontSize)
            ?? UIFont.systemFont(ofSize: fontSize, weight: .medium)
        let textColor = UIColor(hex: template.textColorHex).withAlphaComponent(template.opacity)

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail

        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraph
        ]
        if template.backgroundStyle == .shadow {
            let shadow = NSShadow()
            shadow.shadowColor = UIColor.black.withAlphaComponent(0.6)
            shadow.shadowBlurRadius = 4 * scale
            shadow.shadowOffset = CGSize(width: 0, height: 1 * scale)
            attributes[.shadow] = shadow
        }

        let attributedLines = lines.map { NSAttributedString(string: $0, attributes: attributes) }
        let lineSizes = attributedLines.map { $0.size() }
        let blockWidth = lineSizes.map(\.width).max() ?? 0
        let blockHeight = lineSizes.map(\.height).reduce(0, +) + lineSpacing * CGFloat(lines.count - 1)

        let anchor = template.position.unitPoint
        let originX = margin + (canvasSize.width - 2 * margin - blockWidth) * anchor.x
        let originY = margin + (canvasSize.height - 2 * margin - blockHeight) * anchor.y

        return Layout(scale: scale, lineSpacing: lineSpacing, attributes: attributes,
                      attributedLines: attributedLines, lineSizes: lineSizes,
                      blockWidth: blockWidth, blockHeight: blockHeight,
                      originX: originX, originY: originY,
                      anchorX: anchor.x, anchorY: anchor.y)
    }

    // MARK: - 绘制

    /// 渲染叠加图；skipLineIndex 指定的行不绘制（供视频将时间行交给动态图层处理）
    private func renderImage(data: WatermarkData,
                             template: WatermarkTemplateSnapshot,
                             canvasSize: CGSize,
                             skipLineIndex: Int?) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        return renderer.image { context in
            guard let layout = computeLayout(data: data, template: template, canvasSize: canvasSize) else { return }
            let ctx = context.cgContext

            // 半透明背景条（按完整文本块尺寸绘制）
            if template.backgroundStyle == .translucent {
                let pad = 12 * layout.scale
                let bgRect = CGRect(x: layout.originX - pad, y: layout.originY - pad,
                                    width: layout.blockWidth + 2 * pad,
                                    height: layout.blockHeight + 2 * pad)
                let path = UIBezierPath(roundedRect: bgRect, cornerRadius: 8 * layout.scale)
                ctx.setFillColor(UIColor.black.withAlphaComponent(0.35).cgColor)
                ctx.addPath(path.cgPath)
                ctx.fillPath()
            }

            var y = layout.originY
            for (index, line) in layout.attributedLines.enumerated() {
                let size = layout.lineSizes[index]
                if index != skipLineIndex {
                    let x = layout.originX + (layout.blockWidth - size.width) * layout.anchorX
                    line.draw(at: CGPoint(x: x, y: y))
                }
                y += size.height + layout.lineSpacing
            }
        }
    }
}

/// 气温单位偏好（默认跟随系统 Locale，可在设置覆盖）
enum TemperaturePreference {
    static var current: UnitTemperature {
        if let raw = UserDefaults.standard.string(forKey: "temperatureUnit") {
            return raw == "fahrenheit" ? .fahrenheit : .celsius
        }
        return Locale.current.measurementSystem == .us ? .fahrenheit : .celsius
    }
}
