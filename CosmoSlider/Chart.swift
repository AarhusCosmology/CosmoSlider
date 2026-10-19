//
//  Chart.swift
//  CosmoSlider
//
//  Created by Andreas Nygaard on 23/01/2026.
//

import SwiftUI
import Charts
import UniformTypeIdentifiers
import Foundation

private struct RawAxisTick {
    let value: Double
    let label: String?
}

private struct AxisTickInfo {
    let position: Double
    let label: String?
}

private struct RenderedCurvePoint: Identifiable {
    let id: String
    let x: Double
    let y: Double
}

struct ScientificChartView: View {
    
    @Binding var data: [GraphData]
    @Binding var showObservedData: Bool
    @Binding var observedData: [GraphData]
    //@Binding var axisData: [GraphData]
    
    @Binding var selectedObservable: String
    @Binding var selectedOption: String
    
    @Binding var xValues: [String:[Double]]
    @Binding var style: ChartStyle
    
    @Binding var dataDictionary: [String: [String: [String: [GraphData]]]]
    @Binding var styleDictionary: [String: ChartStyle]
    @Binding var graphOrder: [String]
    
    @Binding var lowestYValue: Double
    @Binding var highestYValue: Double
    
    @Binding var axisLimits: [Double]
    @Binding var axisScales: [String]
    @Binding var mixSplit: Double
    
    let logscale: Double
    let transition: Double
    let l_min: Double
    let width: CGFloat
    let height: CGFloat
    let isExporting: Bool
    
    //private let axisStrokeColor = Color.gray
    private let majorTickLineWidth: CGFloat = 2
    
    private var validGraphKeys: [String] {
        graphOrder.filter { key in
            dataDictionary[key]?[selectedObservable]?[selectedOption] != nil
        }
    }
    
    let observableDictionary: [String: String] = [
        "Cl": "Cl",
        "Pk": "Pk",
        "bg": "Background",
        "th": "Thermodynamics"
    ]

    private var plotInLogScale: Bool {
        let xMin = xValues[observableDictionary[selectedObservable] ?? ""]?.min() ?? 0
        let xMax = xValues[observableDictionary[selectedObservable] ?? ""]?.max() ?? 1
        if abs(log10(xMax) - log10(xMin)) > 1 {
            return true
        } else {
            return false
        }
    }

    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            if isExporting {
                chartContent
            } else {
                chartContent.drawingGroup()
            }
            if !graphOrder.isEmpty {
                LegendView
            }
        }
    }
    
    @ViewBuilder
    private var chartContent: some View {
        Chart {
            //let plotAreaShape = isExporting
            //? PlotAreaShape(exportWidth: width, exportHeight: height - (1-0.836)*896.0*0.4)
            //: PlotAreaShape()
            ForEach(validGraphKeys, id: \.self) { key in
                if let points = dataDictionary[key]![selectedObservable]![selectedOption] {
                    ForEach(renderCurvePoints(points)) { point in
                        LineMark(
                            x: .value("X Value", point.x),
                            y: .value("Y Value", point.y),
                            series: .value("Legend", key)
                        )
                        .interpolationMethod(.cardinal)
                        .lineStyle(
                            StrokeStyle(
                                lineWidth: styleDictionary[key]?.lineWidth ?? 1,
                                dash: styleDictionary[key]?.linePattern.dashPattern ?? []
                            )
                        )
                        .foregroundStyle(
                            styleDictionary[key]?.lineColor.opacity(styleDictionary[key]?.lineOpacity ?? 1) ?? .blue
                        )
                        //.clipShape(plotAreaShape)
                    }
                }
            }
            ForEach(renderCurvePoints(data)) { point in
                LineMark(
                    x: .value("X Value", point.x),
                    y: .value("Y Value", point.y)
                )
                .lineStyle(
                    StrokeStyle(
                        lineWidth: style.lineWidth,
                        dash: style.linePattern.dashPattern
                    )
                )
                .foregroundStyle(style.lineColor.opacity(style.lineOpacity))
                //.clipShape(plotAreaShape)
            }
            .interpolationMethod(.cardinal)
            if showObservedData {
                ForEach(observedData.filter { isValidPoint($0) }) { point in
                    ErrorBarMark(
                        x: .value("x", plottedX(point.xValue, observed: true)),
                        y: .value("y", plottedY(point.yValue, observed: true)),
                        low: .value("y", plottedY(point.yValue-point.errNegative, observed: true)),
                        high: .value("y", plottedY(point.yValue+point.errPositive, observed: true)),
                        markerSize: style.errorBarMarkerSize,
                        capSize: style.errorBarCapSize
                    )
                    .foregroundStyle(
                        style.errorBarColor.opacity(style.errorBarOpacity)
                    )
                    //.clipShape(plotAreaShape)
                }
            }
        }
        .chartXScale(domain: getXDomain())
        .chartYScale(domain: getYDomain())
        .chartPlotStyle { plotArea in
            plotArea.clipped()
        }
        .chartXAxis {
            customXAxis()
            customXAxisMinorTicks()
        }
        .chartYAxis {
            customYAxis()
            customYAxisMinorTicks()
        }
        .chartXAxisLabel(position: .bottom, alignment: .center) {
            Image(xAxisLabelName)
                .resizable()
                .scaledToFit()
                .frame(width: xAxisLabelSize, height: xAxisLabelSize)
                .foregroundColor(style.axisColor)
                .padding(-xAxisLabelPad)
        }
        .chartYAxisLabel(position: .leading, alignment: .center) {
            if yAxisLabelName.isEmpty {
                Text(mathify(selectedOption))
                    .scaledToFit()
                    .frame(width: yAxisLabelSize, height: yAxisLabelSize*0.8, alignment: .bottom)
                    .foregroundColor(style.axisColor)
                    .rotationEffect(.degrees(180), anchor: .center)
                    .padding(-yAxisLabelPad)
            } else {
                Image(yAxisLabelName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: yAxisLabelSize, height: yAxisLabelSize, alignment: .bottom)
                    .foregroundColor(style.axisColor)
                    .rotationEffect(.degrees(180), anchor: .center)
                    .padding(-yAxisLabelPad)
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                if let plotFrameAnchor = proxy.plotFrame {
                    let plotFrame = geometry[plotFrameAnchor]

                    Rectangle()
                        .stroke(
                            style.axisColor,
                            lineWidth: majorTickLineWidth
                        )
                        .frame(
                            width: plotFrame.width,
                            height: plotFrame.height
                        )
                        .position(
                            x: plotFrame.midX,
                            y: plotFrame.midY
                        )
                        .allowsHitTesting(false)
                }
            }
        }
        .padding(.leading, -yAxisPad)
        .padding(.trailing)
        .frame(height: height)
        .frame(width: width)
        .padding(.top, isExporting ? 0 : 75)
    }
    
    @ViewBuilder
    private var LegendView: some View {
        let plotAreaShape = isExporting
        ? PlotAreaShape(exportWidth: width, exportHeight: height - (1-0.836)*896.0*0.4)
        : PlotAreaShape()
        VStack(alignment: .leading, spacing: 4) {
            ForEach(validGraphKeys, id: \.self) { key in
                HStack(spacing: 6) {
                    Rectangle()
                        .fill(styleDictionary[key]?.lineColor.opacity(styleDictionary[key]?.lineOpacity ?? 1.0) ?? .blue)
                        .frame(width: 20, height: 3)
                    
                    Text(key)
                        .font(.caption2)
                        .lineLimit(1)
                }
            }
            if showObservedData {
                HStack(spacing: 6) {
                    Circle()
                        .fill(style.errorBarColor.opacity(style.errorBarOpacity))
                        .frame(width: 20, height: 5)
                    
                    Text("Observed Data")
                        .font(.caption2)
                        .lineLimit(1)
                }
            }
        }
        .padding(6)
        .background(colorScheme == .dark ? Color(.systemGray6).opacity(0.9) : Color(.secondarySystemBackground).opacity(0.9), in: RoundedRectangle(cornerRadius: 6))
        .clipShape(plotAreaShape)
        .offset(x: -22, y: 80)
    }

    private var xAxisLabel: some View {
        Image(xAxisLabelName)
            .resizable()
            .scaledToFit()
            .frame(width: xAxisLabelSize, height: xAxisLabelSize)
            .foregroundColor(.gray)
            .padding(-xAxisLabelPad)
    }

    private var yAxisLabel: some View {
        Image(yAxisLabelName)
            .resizable()
            .scaledToFit()
            .frame(width: yAxisLabelSize, height: yAxisLabelSize)
            .foregroundColor(.gray)
            .rotationEffect(.degrees(180))
            .padding(-yAxisLabelPad)
    }

    var xAxisLabelSize: CGFloat {
        switch selectedObservable {
        case "Cl":
            return 70
        case "Pk":
            return 160
        default:
            return 70
        }
    }
    
    var yAxisLabelSize: CGFloat {
        switch selectedObservable {
        case "Cl":
            switch selectedOption {
            case "PP":
                return 150
            default:
                return 100
            }
        case "Pk":
            return 80
        default:
            return 150
        }
    }
    
    var yAxisPad: CGFloat {
        switch selectedObservable {
        case "Cl":
            switch selectedOption {
            case "PP":
                return 100
            default:
                return 50
            }
        case "Pk":
            return 30
        default:
            return 60
        }
    }

    var xAxisLabelPad: CGFloat {
        switch selectedObservable {
        case "Cl":
            return 25
        case "Pk":
            return 70
        default:
            return 25
        }
    }
    
    var yAxisLabelPad: CGFloat {
        switch selectedObservable {
        case "Cl":
            return 30
        case "Pk":
            return 30
        default:
            return 35
        }
    }
    
    var xAxisLabelName: String {
        switch selectedObservable {
        case "Cl":
            return "ell"
        case "Pk":
            return "k"
        case "bg":
            return "z"
        case "th":
            return "z"
        default:
            return ""
        }
    }

    var yAxisLabelName: String {
        switch selectedObservable {
        case "Cl":
            switch selectedOption {
            case "PP":
                return "Cl_pp"
            default:
                return "Cl"
            }
        case "Pk":
            return "Pk"
        default:
            return ""
        }
    }
    
    func getXDomain() -> ClosedRange<Double> {
        let lower = axisCoordinate(axisLimits[0], axis: 0)
        let upper = axisCoordinate(axisLimits[1], axis: 0)

        guard lower.isFinite, upper.isFinite, lower < upper else {
            return 0...1
        }

        return lower...upper
    }

    func getYDomain() -> ClosedRange<Double> {
        let lower = axisCoordinate(axisLimits[2], axis: 1)
        let upper = axisCoordinate(axisLimits[3], axis: 1)

        guard lower.isFinite, upper.isFinite, lower < upper else {
            return 0...1
        }

        return lower...upper
    }
    
    private func makeAxisTicks(
        axis: Int
    ) -> (major: [AxisTickInfo], minor: [Double]) {
        guard axisLimits.count == 4, axisScales.count == 2 else {
            return ([], [])
        }

        let lower = axisLimits[axis * 2]
        let upper = axisLimits[axis * 2 + 1]

        guard lower.isFinite, upper.isFinite, lower < upper else {
            return ([], [])
        }

        let scale = axisScales[axis]
        var majorRaw: [RawAxisTick] = []
        var minorRaw: [Double] = []

        switch scale {
        case "log":
            let result = logarithmicTicks(
                lower: lower,
                upper: upper,
                desiredMajorCount: 6
            )

            majorRaw += result.major
            minorRaw += result.minor

        case "loglin":
            // Logarithmic region: lower ... mixSplit.
            let logEnd = min(upper, mixSplit)

            if lower > 0, logEnd > lower {
                let result = logarithmicTicks(
                    lower: lower,
                    upper: logEnd,
                    desiredMajorCount: 3
                )

                majorRaw += result.major
                minorRaw += result.minor
            }

            // Linear region: mixSplit ... upper.
            // Do not filter out the split: the linear generator decides
            // naturally whether it lies on its major or minor grid.
            let linearStart = max(lower, mixSplit)

            if linearStart < upper {
                let result = linearTicks(
                    lower: linearStart,
                    upper: upper,
                    desiredMajorCount: 6
                )

                majorRaw += result.major
                minorRaw += result.minor
            }

        case "linlog":
            // Linear region: lower ... mixSplit.
            let linearEnd = min(upper, mixSplit)

            if lower < linearEnd {
                let result = linearTicks(
                    lower: lower,
                    upper: linearEnd,
                    desiredMajorCount: 6
                )

                majorRaw += result.major
                minorRaw += result.minor
            }

            // Logarithmic region: mixSplit ... upper.
            // The logarithmic generator decides naturally whether the split
            // belongs to its major or minor grid.
            let logStart = max(lower, mixSplit)

            if logStart > 0, logStart < upper {
                let result = logarithmicTicks(
                    lower: logStart,
                    upper: upper,
                    desiredMajorCount: 4
                )

                majorRaw += result.major
                minorRaw += result.minor
            }

        default:
            let result = linearTicks(
                lower: lower,
                upper: upper,
                desiredMajorCount: 6
            )

            majorRaw += result.major
            minorRaw += result.minor
        }

        // Merge duplicate major ticks from the two sides of mixSplit.
        // Keep a label if either major-tick rule provides one.
        var uniqueMajorRaw: [RawAxisTick] = []

        for tick in majorRaw {
            if let index = uniqueMajorRaw.firstIndex(where: { existing in
                let magnitude = max(
                    max(abs(existing.value), abs(tick.value)),
                    1e-300
                )
                return abs(existing.value - tick.value) <= 1e-10 * magnitude
            }) {
                let existing = uniqueMajorRaw[index]

                uniqueMajorRaw[index] = RawAxisTick(
                    value: existing.value,
                    label: existing.label ?? tick.label
                )
            } else {
                uniqueMajorRaw.append(tick)
            }
        }

        let major = uniqueMajorRaw.compactMap { tick -> AxisTickInfo? in
            let position = axisCoordinate(tick.value, axis: axis)

            guard position.isFinite else {
                return nil
            }

            return AxisTickInfo(
                position: position,
                label: tick.label
            )
        }
        .sorted { $0.position < $1.position }

        // Transform minor ticks, remove duplicates, and let major ticks win
        // whenever both scale rules produce the same position.
        var minor: [Double] = []

        for rawValue in minorRaw {
            let position = axisCoordinate(rawValue, axis: axis)

            guard position.isFinite else {
                continue
            }

            let matchesMajor = major.contains { tick in
                abs(tick.position - position) <
                    1e-8 * max(1, abs(position))
            }

            guard !matchesMajor else {
                continue
            }

            let alreadyAdded = minor.contains { existing in
                abs(existing - position) <
                    1e-8 * max(1, abs(position))
            }

            if !alreadyAdded {
                minor.append(position)
            }
        }

        return (major, minor.sorted())
    }

    private func logarithmicTicks(
        lower: Double,
        upper: Double,
        desiredMajorCount: Int
    ) -> (major: [RawAxisTick], minor: [Double]) {
        guard lower > 0,
              upper > lower,
              lower.isFinite,
              upper.isFinite else {
            return ([], [])
        }

        let firstExponent = Int(
            max(-300, min(300, ceil(log10(lower))))
        )

        let lastExponent = Int(
            max(-300, min(300, floor(log10(upper))))
        )

        var major: [RawAxisTick] = []

        if firstExponent <= lastExponent {
            let exponentCount = lastExponent - firstExponent + 1

            // Preserve the previous cadence for LABELLED major ticks.
            let labelStride = max(
                1,
                Int(ceil(
                    Double(exponentCount) /
                    Double(max(1, desiredMajorCount))
                ))
            )

            // Every power of ten is now a major tick.
            // Only powers selected by the previous cadence get labels.
            for exponent in firstExponent...lastExponent {
                let value = pow(10.0, Double(exponent))

                guard value >= lower, value <= upper else {
                    continue
                }

                let shouldLabel =
                    (exponent - firstExponent) % labelStride == 0

                major.append(
                    RawAxisTick(
                        value: value,
                        label: shouldLabel ? "10^\(exponent)" : nil
                    )
                )
            }
        }

        // Generate all nine logarithmic subdivisions in every decade.
        // Do not stride over decades: that was another source of missing ticks.
        let minorStart = Int(
            max(-300, min(300, floor(log10(lower))))
        )

        let minorEnd = Int(
            max(-300, min(300, ceil(log10(upper))))
        )

        var minor: [Double] = []

        if minorStart <= minorEnd {
            for exponent in minorStart...minorEnd {
                let decade = pow(10.0, Double(exponent))

                for multiplier in 2...9 {
                    let value = Double(multiplier) * decade

                    // Inclusive bounds allow a natural minor tick at mixSplit.
                    if value >= lower && value <= upper {
                        minor.append(value)
                    }
                }
            }
        }

        // Intentionally no fallback that manufactures major ticks at the
        // lower and upper bounds. A boundary is a tick only if a tick rule
        // naturally generates it.

        return (major, minor)
    }

    private func linearTicks(
        lower: Double,
        upper: Double,
        desiredMajorCount: Int
    ) -> (major: [RawAxisTick], minor: [Double]) {
        let range = upper - lower

        guard range.isFinite, range > 0 else {
            return ([], [])
        }

        let roughStep = range / Double(max(1, desiredMajorCount))

        guard roughStep.isFinite, roughStep > 0 else {
            return ([], [])
        }

        let magnitude = pow(10.0, floor(log10(roughStep)))

        guard magnitude.isFinite, magnitude > 0 else {
            return ([], [])
        }

        let fraction = roughStep / magnitude
        let multiplier: Double

        if fraction <= 1 {
            multiplier = 1
        } else if fraction <= 2 {
            multiplier = 2
        } else if fraction <= 5 {
            multiplier = 5
        } else {
            multiplier = 10
        }

        let step = multiplier * magnitude
        let firstMajor = ceil(lower / step) * step

        var major: [RawAxisTick] = []

        for index in 0..<100 {
            let value = firstMajor + Double(index) * step

            if value > upper + abs(step) * 1e-9 {
                break
            }

            if value >= lower {
                major.append(
                    RawAxisTick(
                        value: value,
                        label: formatAxisNumber(value)
                    )
                )
            }
        }

        let minorStep = step / 5
        let firstMinor = ceil(lower / minorStep) * minorStep
        var minor: [Double] = []

        for index in 0..<500 {
            let value = firstMinor + Double(index) * minorStep

            if value > upper + abs(minorStep) * 1e-9 {
                break
            }

            if value >= lower {
                let isMajor = major.contains {
                    abs($0.value - value) < abs(step) * 1e-8
                }

                if !isMajor {
                    minor.append(value)
                }
            }
        }

        return (major, minor)
    }

    private func formatAxisNumber(_ value: Double) -> String {
        String(format: "%.4g", value)
    }

    @ViewBuilder
    private func formattedAxisLabel(_ label: String) -> some View {
        if label.hasPrefix("10^"),
           let exponent = Int(label.dropFirst(3)) {
            SuperscriptTextView(
                base: "10",
                exponent: String(exponent),
                fontDesign: style.tickLabelFont.design,
                fontSize: CGFloat(style.tickLabelFontSize)
            )
            .foregroundStyle(style.axisColor)
        } else {
            Text(label)
                .font(
                    style.tickLabelFont.font(
                        size: CGFloat(style.tickLabelFontSize)
                    )
                )
                .foregroundStyle(style.axisColor)
        }
    }
    
    func separateScientificString(_ stringValue: String) -> (base: String, exponent: String) {
        let components = stringValue.components(separatedBy: "^")
        return (components[0], components[1])
    }
    
    func generateXTicksCl() -> (majorTicks: [Double], minorTicks: [Double]) {
        // Replace with your own logic to generate x-axis ticks
        var majorTicks: [Double] = []
        var minorTicks: [Double] = []
        var logOrder: Int = 1
        for i in 2...2500 {
            if i < Int(logscale) {
                if log10(Double(i)).truncatingRemainder(dividingBy: 1) == 0 {
                    majorTicks.append(logScale(Double(i)))
                    logOrder *= 10
                } else if i % logOrder == 0 {
                    minorTicks.append(logScale(Double(i)))
                }
            } else {
                if i % 500 == 0 {
                    majorTicks.append(linScale(Double(i)))
                } else if i % 100 == 0 {
                    minorTicks.append(linScale(Double(i)))
                }
            }
        }
        return (majorTicks, minorTicks)
    }
    
    func generateXTicksPk() -> (majorTicks: [Double], minorTicks: [Double]) {
        var majorTicks: [Double] = []
        var minorTicks: [Double] = []
        
        guard let xArray = xValues[observableDictionary[selectedObservable] ?? ""],
              let first = xArray.min(),
              let last = xArray.max() else {
            return (majorTicks, minorTicks)
        }
        let minLog = Int(ceil(log10(first)))
        let maxLog = Int(floor(log10(last)))
        majorTicks = Array(minLog...maxLog).map { Double($0) }
        
        // Generate minor ticks
        for exp in minLog-1..<maxLog+1 {
            let array = Array(2...9).map { log10(Double($0)) }
            for minorExponent in array {
                let minorTick = minorExponent + Double(exp)
                if pow(10.0,minorTick) > first && pow(10.0, minorTick) < last {
                    minorTicks.append(minorTick)
                }
            }
        }
        return (majorTicks, minorTicks)
    }
    
    func generateXTicksBgAndTh() -> (majorTicks: [Double], minorTicks: [Double]) {
        var majorTicks: [Double] = []
        var minorTicks: [Double] = []
        
        guard let xArray = xValues[observableDictionary[selectedObservable] ?? ""],
              let first = xArray.min(),
              let last = xArray.max() else {
            return (majorTicks, minorTicks)
        }
        // Determine major tick exponents
        if plotInLogScale {
            let logx = [log10(first), log10(last)]
            let logxRounded = [Int(floor(logx.min()!)), Int(ceil(logx.min()!)), Int(floor(logx.max()!)), Int(ceil(logx.max()!))].sorted()
            var acceptedLogs: [Int] = []
            for log in logxRounded {
                if Double(log) < logx.max()! && Double(log) > logx.min()! && !acceptedLogs.contains(log) {
                    acceptedLogs.append(log)
                }
            }
            let minLog = acceptedLogs.min() ?? Int(ceil(log10(first)))
            let maxLog = acceptedLogs.max() ?? Int(floor(log10(last)))
            majorTicks = Array(minLog...maxLog).map { Double($0) }
            
            // Generate minor ticks
            for exp in minLog-1..<maxLog+1 {
                let array = Array(2...9).map { log10(Double($0)) }
                for minorExponent in array {
                    let minorTick = minorExponent + Double(exp)
                    if pow(10.0,minorTick) > first && pow(10.0, minorTick) < last {
                        minorTicks.append(minorTick)
                    }
                }
            }
        } else {
            let xRange = abs(last - first)
            let approximateSpacing = xRange / 6.0
            let orderOfMagnitude = floor(log10(approximateSpacing))
            let spacing: Double
            let spacing5 = ceil(approximateSpacing/pow(10.0,orderOfMagnitude)/5.5)*5*pow(10.0,orderOfMagnitude)
            let spacing2 = ceil(approximateSpacing/pow(10.0,orderOfMagnitude)/2.5)*2*pow(10.0,orderOfMagnitude)
            if abs(spacing5 - approximateSpacing) < abs(spacing2 - approximateSpacing) {
                spacing = spacing5
            } else {
                spacing = spacing2
            }
            let closestMultipleOfSpacingToFirst = round(first / spacing) * spacing - 2*spacing
            let closestMultipleOfSpacingToLast = round(last / spacing) * spacing + 2*spacing
            let proposedTicks = stride(from: closestMultipleOfSpacingToFirst, through: closestMultipleOfSpacingToLast, by: spacing).map { snapToGrid($0, step: spacing, significantDigits: 8) }
            let proposedMinorTicks = stride(from: closestMultipleOfSpacingToFirst, through: closestMultipleOfSpacingToLast, by: spacing/5.0).map { snapToGrid($0, step: spacing/5.0, significantDigits: 8) }
            for tick in proposedMinorTicks {
                if tick > first && tick < last {
                    if proposedTicks.contains(tick) {
                        majorTicks.append(tick)
                    } else {
                        minorTicks.append(tick)
                    }
                }
            }
        }
        return (majorTicks, minorTicks)
    }
    
    func customXAxis() -> some AxisContent {
        let ticks = makeAxisTicks(axis: 0).major

        return AxisMarks(values: ticks.map(\.position)) { value in
            AxisTick(
                centered: true,
                length: 10,
                stroke: .init(lineWidth: majorTickLineWidth)
            )
            .foregroundStyle(style.axisColor)

            AxisValueLabel(anchor: .top) {
                if let coordinate = value.as(Double.self),
                   let tick = ticks.min(by: {
                       abs($0.position - coordinate) <
                       abs($1.position - coordinate)
                   }),
                   abs(tick.position - coordinate) < 1e-6 {
                    if let label = tick.label {
                        formattedAxisLabel(label)
                    } else {
                        EmptyView()
                    }
                }
            }
        }
    }

    func customXAxisMinorTicks() -> some AxisContent {
        let ticks = makeAxisTicks(axis: 0).minor

        return AxisMarks(values: ticks) { _ in
            AxisTick(centered: true, length: 5, stroke: .init(lineWidth: 1))
                .foregroundStyle(style.axisColor)

            AxisValueLabel { EmptyView() }
        }
    }

    func customYAxis() -> some AxisContent {
        let ticks = makeAxisTicks(axis: 1).major

        return AxisMarks(position: .leading, values: ticks.map(\.position)) { value in
            AxisTick(
                centered: true,
                length: 10,
                stroke: .init(lineWidth: majorTickLineWidth)
            )
            .foregroundStyle(style.axisColor)

            AxisValueLabel {
                if let coordinate = value.as(Double.self),
                   let tick = ticks.min(by: {
                       abs($0.position - coordinate) <
                       abs($1.position - coordinate)
                   }),
                   abs(tick.position - coordinate) < 1e-6 {
                    if let label = tick.label {
                        formattedAxisLabel(label)
                            .rotationEffect(.degrees(270))
                            .frame(width: 50, height: 10)
                            .offset(x: 18)
                    } else {
                        EmptyView()
                    }
                }
            }
        }
    }

    func customYAxisMinorTicks() -> some AxisContent {
        let ticks = makeAxisTicks(axis: 1).minor

        return AxisMarks(position: .leading, values: ticks) { _ in
            AxisTick(centered: true, length: 5, stroke: .init(lineWidth: 1))
                .foregroundStyle(style.axisColor)

            AxisValueLabel { EmptyView() }
        }
    }
    
    func snapToGrid(_ value: Double, step: Double, significantDigits: Int) -> Double {
        guard step != 0 else { return value }
        let snapped = round(value / step) * step
        return roundToSignificantDigits(snapped, digits: significantDigits)
    }
    
    func roundToSignificantDigits(_ value: Double, digits: Int) -> Double {
        guard value != 0 else { return 0 }

        let magnitude = floor(log10(abs(value)))
        let scale = pow(10, Double(digits) - 1 - magnitude)
        return (value * scale).rounded() / scale
    }
    
    func logScale(_ x: Double) -> Double {
        let logx = log10(x)
        let logxnew = (logx / log10(logscale)) * transition
        
        let loglmin = (log10(l_min) / log10(logscale)) * transition
        let newLogscale = (log10(logscale) / log10(logscale)) * transition
        let logdiff = newLogscale - loglmin
        return ((logxnew - loglmin) * transition / logdiff)
    }

    func linScale(_ x: Double) -> Double {
        let linxnew = (x / (2500 - logscale)) - (logscale / (2500 - logscale))
        return ((linxnew * (1 - transition)) + transition)
    }

    func mathify(_ input: String) -> AttributedString {

        var result = AttributedString()

        // Regex to split bracketed vs non-bracketed
        // Matches: [ ... ] or non-bracketed text
        let pattern = #"\[.*?\]|[^\[\]]+"#
        let regex = try! NSRegularExpression(pattern: pattern, options: [])

        let nsrange = NSRange(input.startIndex..<input.endIndex, in: input)
        let matches = regex.matches(in: input, options: [], range: nsrange)

        for match in matches {
            let range = Range(match.range, in: input)!
            let segment = String(input[range])

            if segment.hasPrefix("[") && segment.hasSuffix("]") {
                // --- bracketed: escape slant ---
                var attr = AttributedString(segment)
                attr.font = .system(.body, design: .serif) // not italic
                result.append(attr)
            } else {
                // --- normal math segment ---
                result.append(mathifySegment(segment))
            }
        }

        return result
    }

    func mathifySegment(_ input: String) -> AttributedString {

        let caretSplit = input.split(separator: "^", omittingEmptySubsequences: false)
        let baseAndSubs = String(caretSplit.first ?? "")
        let superscripts = caretSplit.dropFirst().map(String.init)

        let underscoreSplit = baseAndSubs.split(separator: "_", omittingEmptySubsequences: false)

        let baseText = replaceGreek(in: String(underscoreSplit.first ?? ""))
        let subscripts = underscoreSplit.dropFirst().map { replaceGreek(in: String($0)) }

        var result = AttributedString()

        // --- Base ---
        var base = AttributedString(baseText)
        base.font = .system(.body, design: .serif).italic()  // slanted, math-like
        result.append(base)

        // --- Subscripts ---
        if !subscripts.isEmpty {
            let subString = subscripts.joined(separator: ",")
            var sub = AttributedString(subString)
            sub.font = .system(.caption2, design: .serif).italic()
            sub.baselineOffset = -6
            result.append(sub)
        }

        // --- Superscripts ---
        if !superscripts.isEmpty {
            let supString = superscripts.map(replaceGreek).joined(separator: ",")
            var sup = AttributedString(supString)
            sup.font = .system(.caption2, design: .serif).italic()
            sup.baselineOffset = 6
            result.append(sup)
        }

        return result
    }




    func replaceGreek(in text: String) -> String {
        var output = text
        let greekMap: [String: String] = [
            "alpha": "α", "beta": "β", "gamma": "γ", "delta": "δ",
            "epsilon": "ε", "zeta": "ζ", "eta": "η", "theta": "θ",
            "iota": "ι", "kappa": "κ", "lambda": "λ", "mu": "μ",
            "nu": "ν", "xi": "ξ", "omicron": "ο", "pi": "π",
            "rho": "ρ", "sigma": "σ", "tau": "τ", "upsilon": "υ",
            "phi": "φ", "chi": "χ", "psi": "ψ", "omega": "ω"
        ]
        for (latin, greek) in greekMap {
            // lowercase
            output = output.replacingOccurrences(
                of: latin,
                with: greek
            )

            // Capitalized
            output = output.replacingOccurrences(
                of: latin.capitalized,
                with: greek.uppercased()
            )
        }

        return output
    }
    
    private func axisCoordinate(_ value: Double, axis: Int) -> Double {
        guard axisLimits.count == 4,
              axisScales.count == 2,
              value.isFinite else {
            return .nan
        }

        let lower = axisLimits[axis * 2]
        let upper = axisLimits[axis * 2 + 1]

        guard lower.isFinite, upper.isFinite, lower < upper else {
            return .nan
        }

        switch axisScales[axis] {
        case "log":
            guard value > 0 else { return .nan }
            return log10(value)

        case "loglin":
            // Logarithmic below mixSplit; linear above it.
            guard lower > 0,
                  lower < mixSplit,
                  mixSplit < upper,
                  value > 0 else {
                return .nan
            }

            if value <= mixSplit {
                return transition
                    * log10(value / lower)
                    / log10(mixSplit / lower)
            }

            return transition
                + (1 - transition)
                * (value - mixSplit)
                / (upper - mixSplit)

        case "linlog":
            // Linear below mixSplit; logarithmic above it.
            guard lower < mixSplit,
                  mixSplit > 0,
                  mixSplit < upper else {
                return .nan
            }

            if value <= mixSplit {
                return (1 - transition)
                    * (value - lower)
                    / (mixSplit - lower)
            }

            return (1 - transition)
                + transition
                * log10(value / mixSplit)
                / log10(upper / mixSplit)

        default:
            return value
        }
    }
    
    private func plottedX(_ x: Double, observed: Bool = false) -> Double {
        let adjustedX: Double

        if selectedObservable == "Pk" && observed {
            // Preserve the existing conversion for observational data.
            adjustedX = x * 0.677
        } else {
            adjustedX = x
        }

        return axisCoordinate(adjustedX, axis: 0)
    }

    private func plottedY(_ y: Double, observed: Bool = false) -> Double {
        var adjustedY = y

        if selectedObservable == "Cl" {
            if selectedOption == "PP" {
                adjustedY *= 1e7
            } else if !observed {
                adjustedY *= pow(2.7255e6, 2)
            }
        }

        return axisCoordinate(adjustedY, axis: 1)
    }
    
    private func isValidPoint(
        _ point: GraphData,
        observed: Bool = false
    ) -> Bool {
        guard plottedX(point.xValue, observed: observed).isFinite,
              plottedY(point.yValue, observed: observed).isFinite else {
            return false
        }

        if observed {
            let lowerY = point.yValue - point.errNegative
            let upperY = point.yValue + point.errPositive

            guard plottedY(lowerY, observed: true).isFinite,
                  plottedY(upperY, observed: true).isFinite else {
                return false
            }
        }

        return true
    }
    
    private func renderCurvePoints(
        _ points: [GraphData],
        extrapolationFraction: Double = 0.02
    ) -> [RenderedCurvePoint] {

        // Transform once into the coordinate system used by the chart.
        var result = points.compactMap { point -> RenderedCurvePoint? in
            let x = plottedX(point.xValue)
            let y = plottedY(point.yValue)

            guard x.isFinite, y.isFinite else {
                return nil
            }

            return RenderedCurvePoint(
                id: point.id.uuidString,
                x: x,
                y: y
            )
        }
        .sorted { $0.x < $1.x }

        guard result.count >= 2 else {
            return result
        }

        let domain = getXDomain()
        let span = domain.upperBound - domain.lowerBound

        guard span.isFinite, span > 0,
              extrapolationFraction > 0 else {
            return result
        }

        let extensionDistance = span * extrapolationFraction
        let leftTarget = domain.lowerBound - extensionDistance
        let rightTarget = domain.upperBound + extensionDistance

        // Extend the curve on the left if it currently ends inside the domain.
        if result[0].x > domain.lowerBound {
            let first = result[0]
            let second = result[1]
            let dx = second.x - first.x

            if dx.isFinite, abs(dx) > 1e-12 {
                let slope = (second.y - first.y) / dx
                let extrapolatedY = first.y + slope * (leftTarget - first.x)

                if extrapolatedY.isFinite {
                    result.insert(
                        RenderedCurvePoint(
                            id: "__extrapolated_left",
                            x: leftTarget,
                            y: extrapolatedY
                        ),
                        at: 0
                    )
                }
            }
        }

        // Extend the curve on the right if it currently ends inside the domain.
        if let last = result.last,
           last.x < domain.upperBound {

            let previous = result[result.count - 2]
            let dx = last.x - previous.x

            if dx.isFinite, abs(dx) > 1e-12 {
                let slope = (last.y - previous.y) / dx
                let extrapolatedY = last.y + slope * (rightTarget - last.x)

                if extrapolatedY.isFinite {
                    result.append(
                        RenderedCurvePoint(
                            id: "__extrapolated_right",
                            x: rightTarget,
                            y: extrapolatedY
                        )
                    )
                }
            }
        }

        return result
    }
}


extension ScientificChartView {

    /// Export the chart to PDF at the given URL
    @MainActor
    static func exportPDF(chart: ScientificChartView, width: CGFloat, height: CGFloat, url: URL) throws {
        var mediaBox = CGRect(origin: .zero, size: CGSize(width: width, height: height))
        let metadata: [CFString: Any] = [:]

        guard let context = CGContext(url as CFURL, mediaBox: &mediaBox, metadata as CFDictionary) else {
            throw NSError(domain: "PDFExport", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create PDF context"])
        }

        context.beginPDFPage(nil)

        let exportStyle = chart.style

        let insets = exportStyle.resolvedExportInsets(
            pageWidth: width,
            pageHeight: height
        )

        let exportLayout = ZStack(alignment: .topLeading) {
            // Fill the complete PDF page, including all margins.
            exportStyle.exportBackgroundColor

            // Place the chart inside the four margins.
            chart
                .padding(insets)
        }
        .frame(
            width: width,
            height: height,
            alignment: .topLeading
        )
        .clipped()

        let renderer = ImageRenderer(content: exportLayout)
        renderer.proposedSize = ProposedViewSize(
            width: width,
            height: height
        )

        renderer.render { _, draw in
            draw(context)
        }

        context.endPDFPage()
        context.closePDF()
    }
}
