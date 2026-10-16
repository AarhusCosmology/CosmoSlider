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

struct ScientificChartView: View {
    
    @Binding var data: [GraphData]
    @Binding var showObservedData: Bool
    @Binding var observedData: [GraphData]
    @Binding var axisData: [GraphData]
    
    @Binding var selectedObservable: String
    @Binding var selectedOption: String
    
    @Binding var xValues: [String:[Double]]
    @Binding var style: ChartStyle
    
    @Binding var dataDictionary: [String: [String: [String: [GraphData]]]]
    @Binding var styleDictionary: [String: ChartStyle]
    @Binding var graphOrder: [String]
    
    @Binding var lowestYValue: Double
    @Binding var highestYValue: Double
    
    let logscale: Double
    let transition: Double
    let l_min: Double
    let width: CGFloat
    let height: CGFloat
    let isExporting: Bool
    
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
            let plotAreaShape = isExporting
            ? PlotAreaShape(exportWidth: width, exportHeight: height - (1-0.836)*896.0*0.4)
            : PlotAreaShape()
            ForEach(validGraphKeys, id: \.self) { key in
                if let points = dataDictionary[key]![selectedObservable]![selectedOption] {
                    ForEach(points) { point in
                        LineMark(
                            x: .value("X Value", scaleGraphPoint(xPoint: rescaleXCoordinate(point.xValue))),
                            y: .value("Y Value", rescaleYCoordinate(point.yValue)),
                            series: .value("Legend", key)
                        )
                        .interpolationMethod(.cardinal)
                        .lineStyle(StrokeStyle(lineWidth: styleDictionary[key]?.lineWidth ?? 1))
                        .foregroundStyle(
                            styleDictionary[key]?.lineColor.opacity(styleDictionary[key]?.lineOpacity ?? 1) ?? .blue
                        )
                        .clipShape(plotAreaShape)
                    }
                }
            }
            ForEach(data) { point in
                LineMark(
                    x: .value("X Value", scaleGraphPoint(xPoint:rescaleXCoordinate(point.xValue))),
                    y: .value("Y Value", rescaleYCoordinate(point.yValue))
                )
                .lineStyle(StrokeStyle(lineWidth: style.lineWidth))
                .foregroundStyle(
                    style.lineColor.opacity(style.lineOpacity)
                )
                .clipShape(plotAreaShape)
            }
            .interpolationMethod(.cardinal)
            if showObservedData {
                ForEach(observedData) { point in
                    ErrorBarMark(
                        x: .value("x", scaleGraphPoint(xPoint: rescaleXCoordinate(point.xValue, data: true))),
                        y: .value("y", rescaleYCoordinate(point.yValue, data: true)),
                        low: .value("y", rescaleYCoordinate(point.yValue-point.errNegative, data: true)),
                        high: .value("y", rescaleYCoordinate(point.yValue+point.errPositive, data: true)),
                        markerSize: style.errorBarMarkerSize,
                        capSize: style.errorBarCapSize
                    )
                    .foregroundStyle(
                        style.errorBarColor.opacity(style.errorBarOpacity)
                    )
                    .clipShape(plotAreaShape)
                }
            }
            ForEach(axisData) { point in
                RuleMark(
                    x: .value("Y Value", point.xValue)
                )
                RuleMark(
                    y: .value("Y Value", point.yValue)
                )
            }
            .foregroundStyle(.gray)
        }
        .chartXScale(domain: getXDomain())
        .chartYScale(domain: getYDomain())
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
                .foregroundColor(.gray)
                .padding(-xAxisLabelPad)
        }
        .chartYAxisLabel(position: .leading, alignment: .center) {
            if yAxisLabelName.isEmpty {
                Text(mathify(selectedOption))
                    .scaledToFit()
                    .frame(width: yAxisLabelSize, height: yAxisLabelSize*0.8, alignment: .bottom)
                    .foregroundColor(.gray)
                    .rotationEffect(.degrees(180), anchor: .center)
                    .padding(-yAxisLabelPad)
            } else {
                Image(yAxisLabelName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: yAxisLabelSize, height: yAxisLabelSize, alignment: .bottom)
                    .foregroundColor(.gray)
                    .rotationEffect(.degrees(180), anchor: .center)
                    .padding(-yAxisLabelPad)
            }
        }
        .padding(.leading, -yAxisPad)
        .padding(.trailing)
        .frame(height: height)
        .frame(width: width)
        .padding(.top, 75)
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
    
    func getYDomain() -> ClosedRange<Double> {
        let lowestYLimit = axisData.min(by: { $0.yValue < $1.yValue })?.yValue ?? 0.0
        let highestYLimit = axisData.max(by: { $0.yValue < $1.yValue })?.yValue ?? 1.0
        return lowestYLimit...highestYLimit
    }
    
    func getXDomain() -> ClosedRange<Double> {
        let lowestXLimit = axisData.min(by: { $0.xValue < $1.xValue })?.xValue ?? 0.0
        let highestXLimit = axisData.max(by: { $0.xValue < $1.xValue })?.xValue ?? 1.0
        return lowestXLimit...highestXLimit
    }
    
    func customXAxis() -> some AxisContent {
        var majorTicks: [Double] = []
        var majorLabels: [String] = []
        var majorLabelsFloats: [Double] = []
        var scientificNotationIndex: Int = 2
        
        if selectedObservable == "Cl" {
            let (ticks, _) = generateXTicksCl()
            majorTicks = ticks.map { Double($0) } // convert to Double if needed
            majorLabels = ["10^1", "10^2", "500", "1000", "1500", "2000", "2500"]
            majorLabelsFloats = [10, 100, 500, 1000, 1500, 2000, 2500]
        } else if selectedObservable == "Pk" {
            let (ticks, _) = generateXTicksPk()
            majorTicks = ticks.map { Double($0) }
            majorLabels = ticks.map { "10^\(Int($0))" }
            majorLabelsFloats = ticks.map { pow(10.0, Double($0)) }
            scientificNotationIndex = ticks.count
        } else if ["bg", "th"].contains(selectedObservable) {
            let (ticks, _) = generateXTicksBgAndTh()
            if plotInLogScale {
                majorTicks = ticks.map { Double($0) }
                majorLabels = ticks.map { "10^\(Int($0))" }
                majorLabelsFloats = ticks.map { pow(10.0, Double($0)) }
                scientificNotationIndex = ticks.count
            } else {
                majorTicks = ticks.map { Double($0) }
                majorLabels = ticks.map { String($0) }
                majorLabelsFloats = ticks.map { $0 }
                scientificNotationIndex = 0
            }
        }
        return AxisMarks(values: majorTicks) { value in
            AxisTick(centered: true, length: 10, stroke: .init(lineWidth: 2))
                .foregroundStyle(Color.gray)
            AxisValueLabel(anchor: .top) {
                if let index = majorTicks.firstIndex(where: { $0 == value.as(Double.self) }) {
                    if index < scientificNotationIndex {
                        let (base, exponent) = separateScientificString(majorLabels[index])
                        SuperscriptTextView(base: base, exponent: exponent)
                    } else {
                        Text("\(majorLabelsFloats[index], format: .number)")
                            .font(.system(size: 12))
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
            }
        }
    }
    
    func customXAxisMinorTicks() -> some AxisContent {
        var minorTicks: [Double] = []
        var minorLabels: [String] = []
        if selectedObservable == "Cl" {
            let (_, ticks) = generateXTicksCl()
            minorTicks = ticks.map {Double($0)}
            minorLabels = Array(repeating: "", count: ticks.count)
        } else if selectedObservable == "Pk" {
            let (_, ticks) = generateXTicksPk()
            minorTicks = ticks.map { Double($0) }
            minorLabels = Array(repeating: "", count: ticks.count)
        } else if ["bg", "th"].contains(selectedObservable) {
            let (_, ticks) = generateXTicksBgAndTh()
            minorTicks = ticks.map {Double($0)}
            minorLabels = Array(repeating: "", count: ticks.count)
        }
        return AxisMarks(values: minorTicks) { value in
            AxisTick(centered: true, length: 5, stroke: .init(lineWidth: 1))
                .foregroundStyle(Color.gray)
            AxisValueLabel(anchor: .top) {
                if let index = minorTicks.firstIndex(where: { $0 == value.as(Double.self) }) {
                    Text(minorLabels[index])
                        .font(.system(size: 12))
                }
            }
        }
    }
    
    func customYAxis() -> some AxisContent {
        var majorTicks: [Double] = []
        var scaleTicks: Bool = false
        let (ticks, _, scale) = generateYTicks()
        majorTicks = ticks.map { Double($0) }
        if scale == "linear" {
            let largestTick = majorTicks.max() ?? 0
            let smallestTick = majorTicks.min() ?? 0
            var magnitudeOfLargestTick = log10(largestTick)
            var magnitudeOfSmallestTick = log10(smallestTick)
            if abs(magnitudeOfLargestTick).isInfinite {
                magnitudeOfLargestTick = 0
            } else if abs(magnitudeOfSmallestTick).isInfinite {
                magnitudeOfSmallestTick = 0
            }
            if magnitudeOfLargestTick > 4 || magnitudeOfLargestTick < -2 || magnitudeOfSmallestTick > 4 || magnitudeOfSmallestTick < -2 {
                scaleTicks = true
            }
        }
        return AxisMarks(position: .leading, values: majorTicks) { value in
            AxisTick(centered: true, length: 10, stroke: .init(lineWidth: 2))
                .foregroundStyle(Color.gray)
            AxisValueLabel {
                Group {
                    if let doubleValue = value.as(Double.self) {
                        if scale == "log" {
                            let (base, exponent) = separateScientificString("10^\(Int(doubleValue))")
                            SuperscriptTextView(base: base, exponent: exponent)
                        } else if scaleTicks {
                            let magnitude = floor(log10(doubleValue))
                            let baseValue = doubleValue / pow(10.0, Double(magnitude))
                            ScientificTextView(base: String(roundToSignificantDigits(baseValue, digits: 3)), exponent: String(Int(magnitude)))
                        } else {
                            Text("\(doubleValue, format: .number)")
                        }
                    } else {
                        EmptyView()
                    }
                }
                .rotationEffect(.degrees(270))
                .frame(width: 50, height: 10)
                .offset(x: 18)
                .font(.system(size: 12))
            }
        }
    }

    func customYAxisMinorTicks() -> some AxisContent {
        var minorTicks: [Double] = []

        if selectedObservable == "Cl" {
            let strideValue: Double
            switch selectedOption {
            case "TT":
                strideValue = 500
                minorTicks = Array(
                    stride(from: 0, through: 7000, by: strideValue)
                )
            case "TE":
                strideValue = 20
                minorTicks = Array(
                    stride(from: -220.0, through: 230.0, by: strideValue)
                )
            case "EE":
                strideValue = 5
                minorTicks = Array(
                    stride(from: 0.0, through: 60.0, by: strideValue)
                )
            case "PP":
                strideValue = 0.1
                minorTicks = Array(
                    stride(from: 0.0, through: 2.5, by: strideValue)
                )
            default:
                strideValue = 10
                minorTicks = Array(
                    stride(from: -100.0, through: 100.0, by: strideValue)
                )
            }
        } else {
            let (_, ticks, _) = generateYTicks()
            minorTicks = ticks.map { Double($0) }
        }

        return AxisMarks(position: .leading, values: minorTicks) { value in
            AxisTick(centered: true, length: 5, stroke: .init(lineWidth: 1))
                .foregroundStyle(.gray)
            AxisValueLabel { EmptyView() }
        }
    }

    
    func generateYTicks() -> (majorTicks: [Double], minorTicks: [Double], scale: String) {
        var majorTicks: [Double] = []
        var minorTicks: [Double] = []
        var strideValue: Double = 1.0
        let scale: String
        let numTicks: Double
        switch selectedObservable {
        case "Cl":
            scale = "linear"
            numTicks = 5
        case "Pk":
            scale = "log"
            strideValue = 2
            numTicks = 5
        default:
            numTicks = 4
            if abs(log10(highestYValue)-log10(lowestYValue)) < 1.0 {
                scale = "linear"
            } else {
                scale = "log"
                strideValue = ceil(abs(log10(highestYValue)-log10(lowestYValue))/8)
            }
        }
        let lowestYLimit = axisData.min(by: { $0.yValue < $1.yValue })?.yValue ?? 1.0
        let highestYLimit = axisData.max(by: { $0.yValue < $1.yValue })?.yValue ?? 2.0
        if scale == "log" {
            let logy = [lowestYLimit, highestYLimit]
            let logyRounded = [Int(floor(logy.min()!)), Int(ceil(logy.min()!)), Int(floor(logy.max()!)), Int(ceil(logy.max()!))].sorted()
            var acceptedLogs: [Int] = []
            for log in logyRounded {
                if Double(log) < logy.max()! && Double(log) > logy.min()! && !acceptedLogs.contains(log) {
                    acceptedLogs.append(log)
                }
            }
            let minLog = acceptedLogs.min() ?? Int(ceil(lowestYLimit))
            let maxLog = acceptedLogs.max() ?? Int(floor(highestYLimit))
            
            // Generate minor ticks
            for exp in stride(from: minLog-Int(strideValue), through: maxLog+Int(strideValue), by: Int(strideValue)) {
                if exp >= minLog && exp <= maxLog {
                    majorTicks.append(Double(exp))
                }
                let array = Array(2...9).map { log10(Double($0))*Double(strideValue) }
                for minorExponent in array {
                    let minorTick = minorExponent + Double(exp)
                    if minorTick > lowestYLimit && minorTick < highestYLimit {
                        minorTicks.append(minorTick)
                    }
                }
            }
        } else {
            let xRange = abs(highestYLimit - lowestYLimit)
            let approximateSpacing = xRange / numTicks
            let orderOfMagnitude = floor(log10(approximateSpacing))
            let spacing: Double
            let spacing5 = ceil(approximateSpacing/pow(10.0,orderOfMagnitude)/5.5)*5*pow(10.0,orderOfMagnitude)
            let spacing2 = ceil(approximateSpacing/pow(10.0,orderOfMagnitude)/2.5)*2*pow(10.0,orderOfMagnitude)
            if abs(spacing5 - approximateSpacing) < abs(spacing2 - approximateSpacing) {
                spacing = spacing5
            } else {
                spacing = spacing2
            }
            let closestMultipleOfSpacingToFirst = round(lowestYLimit / spacing) * spacing - 2*spacing
            let closestMultipleOfSpacingToLast = round(highestYLimit / spacing) * spacing + 2*spacing
            let proposedTicks = stride(from: closestMultipleOfSpacingToFirst, through: closestMultipleOfSpacingToLast, by: spacing).map { snapToGrid($0, step: spacing, significantDigits: 8) }
            let proposedMinorTicks = stride(from: closestMultipleOfSpacingToFirst, through: closestMultipleOfSpacingToLast, by: spacing/numTicks).map { snapToGrid($0, step: spacing/numTicks, significantDigits: 8) }
            for tick in proposedMinorTicks {
                if tick >= lowestYLimit && tick <= highestYLimit {
                    if proposedTicks.contains(tick) {
                        majorTicks.append(tick)
                    } else {
                        minorTicks.append(tick)
                    }
                }
            }
        }
        return (majorTicks, minorTicks, scale)
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
    
    func scaleGraphPoint(xPoint: Double) -> Double {
        let p = xPoint
        if selectedObservable != "Cl" {
            return p
        }
        if p <= logscale {
            return logScale(p)
        } else {
            return linScale(p)
        }
    }

    func rescaleXCoordinate(_ x: Double, data: Bool = false) -> Double {
        switch selectedObservable {
        case "Cl":
            return x
        case "Pk":
            if data {
                return log10(x*0.677)
            } else {
                return log10(x)
            }
        case "bg":
            if plotInLogScale {
                return log10(x)
            } else {
                return x
            }
        default:
            return x
        }
    }
    
    func rescaleYCoordinate(_ y: Double, data: Bool = false) -> Double {
        switch selectedObservable {
        case "Cl":
            switch selectedOption {
            case "PP":
                return y*1e+7
            default:
                if data {
                    return y
                } else {
                    return y*pow(2.7255e+6,2)
                }
            }
        case "Pk":
            return log10(y)
        default:
            if abs(log10(highestYValue)-log10(lowestYValue)) < 1.0 {
                return y
            } else {
                return log10(y)
            }
        }
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

        let renderer = ImageRenderer(content: chart)
        renderer.render { _, draw in
            draw(context)
        }

        context.endPDFPage()
        context.closePDF()
    }
}
