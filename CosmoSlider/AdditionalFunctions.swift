//
//  AdditionalFunctions.swift
//  CosmoSlider
//
//  Created by Andreas Nygaard on 27/01/2026.
//

import Foundation
import SwiftUI
import TensorFlowLite

func updateGraphData(observable: String,
                     option: String,
                     parameters: [Double],
                     xArrayDictionary: [String: [Double]],
                     outputIndices: [String:(Int,Int)],
                     interpreter: Interpreter?) -> [GraphData] {

    let observableDictionary: [String: String] = [
        "Cl": "Cl",
        "Pk": "Pk",
        "bg": "Background",
        "th": "Thermodynamics"
    ]
    var inputData = Data()
    parameters.forEach { value in
        var val = Float32(value)
        inputData.append(Data(bytes: &val, count: MemoryLayout<Float32>.size))
    }
    var graphOutputData: [GraphData] = []
    var outputTensor: Tensor?
    if let interpreter = interpreter {
        // Call methods and access properties of the interpreter here
        do {
            try interpreter.copy(inputData, toInputAt: 0)
            try interpreter.invoke()
            outputTensor = try interpreter.output(at: 0)
            // Other operations using the interpreter
        } catch {
            print("Error: \(error)")
        }
    } else {
        // Handle the case where the interpreter is nil
        print("Interpreter is nil")
    }

    if let outputTensor = outputTensor {
        let outputSize = outputTensor.shape.dimensions.reduce(1, {x, y in x * y})
        let outputData = UnsafeMutableBufferPointer<Float32>.allocate(capacity: outputSize)
        _ = outputTensor.data.copyBytes(to: outputData)
        
        var indexShift: Int = 0
        var length: Int = 0
        for (key, value) in outputIndices {
            let components = key.components(separatedBy: "_")
            if components.count > 1 {
                let rest = components[1...].joined(separator: "_")
                if rest.caseInsensitiveCompare(option) == .orderedSame {
                    indexShift = value.0
                    length = value.1 - value.0
                    break
                }
            }
        }
        
        var j = 0
        if let xArray = xArrayDictionary[observableDictionary[observable] ?? ""] {
            guard length == xArray.count else {
                print("Length of xArray does not match length of outputData")
                return []
            }
            graphOutputData = (0..<length).map { i in
                j = i + indexShift
                return GraphData(xValue: xArray[i], yValue: Double(outputData[j]))
            }
        } else {
            graphOutputData = []
        }
    } else {
        print("Output tensor is nil")
        graphOutputData = []
    }
    graphOutputData.sort { $0.xValue < $1.xValue }
    return graphOutputData
}
