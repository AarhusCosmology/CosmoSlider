//
//  AdditionalStructs.swift
//  CMB Emulator
//
//  Created by Andreas Bek Nygaard Hansen on 17/06/2024.
//

import Foundation
import Charts
import SwiftUI


struct IdentifiableURL: Identifiable {
    var id: URL { url }
    var url: URL
}


struct GraphData: Identifiable {
    var id = UUID()
    var xValue: Double
    var yValue: Double
    var errPositive: Double = 0
    var errNegative: Double = 0
}


struct SuperscriptTextView: View {
    let base: String
    let exponent: String
    var fontDesign: Font.Design = .default
    var fontSize: CGFloat = 12

    var body: some View {
        HStack(spacing: 0) {
            Text(base)
                .font(.system(size: fontSize, design: fontDesign))

            Text(exponent)
                .font(.system(
                    size: fontSize * 0.75,
                    design: fontDesign
                ))
                .baselineOffset(fontSize * 0.8)
        }
        .frame(height: fontSize * 1.5, alignment: .bottom)
        .fixedSize(horizontal: true, vertical: false)
    }
}

struct ScientificTextView: View {
    let base: String
    let exponent: String

    var body: some View {
        HStack(spacing: 0) {
            Text(base)
            Text("×")
            Text("10")
            Text(exponent)
                .font(.system(size: 9))
                .baselineOffset(10)
        }
        .font(.system(size: 12))
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .frame(minWidth: 40, minHeight: 22, alignment: .bottom)
    }
}



struct ErrorBarMark<X: Plottable, Y: Plottable>: ChartContent {
    let x: PlottableValue<X>
    let y: PlottableValue<Y>
    let low: PlottableValue<Y>
    let high: PlottableValue<Y>
    let markerSize: Double
    let capSize: Double
    
    init(
        x: PlottableValue<X>,
        y: PlottableValue<Y>,
        low: PlottableValue<Y>,
        high: PlottableValue<Y>,
        markerSize: Double = 3,
        capSize: Double = 2
    ) {
        self.x = x
        self.y = y
        self.low = low
        self.high = high
        self.markerSize = markerSize
        self.capSize = capSize
    }
    
    var body: some ChartContent {
        PointMark(
            x: x,
            y: y
        )
        .symbolSize(markerSize*10)
        RectangleMark(
            x: x,
            yStart: low,
            yEnd: high,
            width: MarkDimension(floatLiteral: capSize)
        )
    }
}


struct PlotAreaShape: Shape {
    var exportWidth: CGFloat? = nil
    var exportHeight: CGFloat? = nil

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(plotRect(for: rect))
        return path
    }

    func plotRect(for rect: CGRect) -> CGRect {
        if let w = exportWidth, let h = exportHeight {
            return CGRect(x: 0, y: 0, width: w, height: h)
        } else {
            return CGRect(
                x: UIScreen.main.bounds.minX,
                y: UIScreen.main.bounds.minY,
                width: UIScreen.main.bounds.width,
                height: UIScreen.main.bounds.height * 0.4 - (1-0.836)*896.0*0.4
            )
        }
    }

    var x: CGFloat { plotRect(for: .zero).minX }
    var y: CGFloat { plotRect(for: .zero).minY }
    var width: CGFloat { plotRect(for: .zero).width }
    var height: CGFloat { plotRect(for: .zero).height }
}

enum AxisTickFont: String, CaseIterable, Identifiable {
    case system = "System"
    case serif = "Serif"
    case rounded = "Rounded"
    case monospaced = "Monospaced"

    var id: String { rawValue }

    var design: Font.Design {
        switch self {
        case .system:    return .default
        case .serif:     return .serif
        case .rounded:   return .rounded
        case .monospaced: return .monospaced
        }
    }

    func font(size: CGFloat) -> Font {
        .system(size: size, design: design)
    }
}

enum LinePattern: String, CaseIterable, Identifiable {
    case solid = "Solid"
    case dashed = "Dashed"
    case dotted = "Dotted"
    case dashDot = "Dash-dotted"

    var id: String { rawValue }

    var dashPattern: [CGFloat] {
        switch self {
        case .solid:     return []
        case .dashed:    return [8, 4]
        case .dotted:    return [1, 3]
        case .dashDot:   return [8, 3, 1, 3]
        }
    }
}

struct ChartStyle {
    var exportWidth: Double = 1200
    var exportHeight: Double = 800

    var lineColor: Color = .blue
    var lineOpacity: Double = 1.0
    var lineWidth: Double = 2.0

    var errorBarColor: Color = .green
    var errorBarOpacity: Double = 0.5
    var errorBarMarkerSize: Double = 3.0
    var errorBarCapSize: Double = 2.0
    
    var axisColor: Color = .gray
    var tickLabelFont: AxisTickFont = .system
    var tickLabelFontSize: Double = 12
    var linePattern: LinePattern = .solid

    var exportPaddingTop: Double = 40
    var exportPaddingBottom: Double = 40
    var exportPaddingLeft: Double = 40
    var exportPaddingRight: Double = 40

    var exportBackgroundColor: Color = .white
    
    func resolvedExportInsets(
        pageWidth: CGFloat,
        pageHeight: CGFloat
    ) -> EdgeInsets {
        let top = max(0, CGFloat(exportPaddingTop))
        let bottom = max(0, CGFloat(exportPaddingBottom))
        let left = max(0, CGFloat(exportPaddingLeft))
        let right = max(0, CGFloat(exportPaddingRight))

        // Reserve at least 120 points for the chart content when possible.
        let availableHorizontal = max(0, pageWidth - 120)
        let requestedHorizontal = left + right

        let horizontalFactor: CGFloat =
            requestedHorizontal > availableHorizontal &&
            requestedHorizontal > 0
            ? availableHorizontal / requestedHorizontal
            : 1

        let availableVertical = max(0, pageHeight - 120)
        let requestedVertical = top + bottom

        let verticalFactor: CGFloat =
            requestedVertical > availableVertical &&
            requestedVertical > 0
            ? availableVertical / requestedVertical
            : 1

        return EdgeInsets(
            top: top * verticalFactor,
            leading: left * horizontalFactor,
            bottom: bottom * verticalFactor,
            trailing: right * horizontalFactor
        )
    }
}

