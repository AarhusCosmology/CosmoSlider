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

    init(base: String, exponent: String) {
        self.base = base
        self.exponent = exponent
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Text(base)
                .font(.system(size: 12)) // Base number font size
            Text(exponent)
                .font(.system(size: 9)) // Exponent font size
                .baselineOffset(5) // Adjust the baseline offset to position the exponent as a superscript
        }
    }
}

struct ErrorBarMark<X: Plottable, Y: Plottable>: ChartContent {
    let x: PlottableValue<X>
    let y: PlottableValue<Y>
    let low: PlottableValue<Y>
    let high: PlottableValue<Y>
    
    init(
        x: PlottableValue<X>,
        y: PlottableValue<Y>,
        low: PlottableValue<Y>,
        high: PlottableValue<Y>
    ) {
        self.x = x
        self.y = y
        self.low = low
        self.high = high
    }
    
    var body: some ChartContent {
        PointMark(
            x: x,
            y: y
        )
        .symbolSize(30)
        RectangleMark(
            x: x,
            yStart: low,
            yEnd: high,
            width: 2
        )
    }
}


struct PlotAreaShape: Shape {

    func path(in rect: CGRect) -> SwiftUI.Path {
        var path = SwiftUI.Path()
        let plotRect = CGRect(
            x: UIScreen.main.bounds.minX,
            y: UIScreen.main.bounds.minY,// + UIScreen.main.bounds.height*0.01,
            width: UIScreen.main.bounds.width,
            height: UIScreen.main.bounds.height * 0.4 - (1-0.836)*896.0*0.4
        )
        path.addRect(plotRect)
        return path
    }
}

