//
//  AdditionalFunctions.swift
//  CosmoSlider
//
//  Created by Andreas Nygaard on 27/01/2026.
//

import Foundation
import SwiftUI
import TensorFlowLite

struct PkOutputSlice {
    let redshift: Double
    let start: Int
    let end: Int
}

// MARK: - Pk output lookup

func pkOutputSlices(
    family: String,
    outputIndices: [String: (Int, Int)]
) -> [PkOutputSlice] {
    outputIndices.compactMap { key, range -> PkOutputSlice? in
        let parts = key.split(separator: "_").map(String.init)

        guard parts.count >= 3,
              parts[0].lowercased() == "pk",
              let redshift = Double(parts.last!)
        else {
            return nil
        }

        let outputFamily = parts
            .dropFirst()
            .dropLast()
            .joined(separator: "_")

        guard outputFamily.caseInsensitiveCompare(family)
                == .orderedSame
        else {
            return nil
        }

        return PkOutputSlice(
            redshift: redshift,
            start: range.0,
            end: range.1
        )
    }
    .sorted { $0.redshift < $1.redshift }
}

// MARK: - Hubble parameter

func dimensionlessHubbleValue(
    parameterNames: [String],
    parameters: [Double],
    fallback: Double = 0.677
) -> Double {
    for index in parameterNames.indices {
        guard parameters.indices.contains(index) else {
            continue
        }

        let name = parameterNames[index]
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }

        guard [
            "h",
            "h0",
            "hubble",
            "hubbleconstant"
        ].contains(name) else {
            continue
        }

        let rawValue = parameters[index]

        guard rawValue.isFinite, rawValue > 0 else {
            continue
        }

        // h is already dimensionless. H0 is in km/s/Mpc.
        let h = name == "h" ? rawValue : rawValue / 100.0

        if h.isFinite, h > 0 {
            return h
        }
    }

    // Fallback only for models without an h/H0 input.
    return fallback
}

// MARK: - Shape-preserving cubic interpolation

private func pchipInterpolate(
    x: [Double],
    y: [Double],
    at requestedX: Double
) -> Double? {
    let n = x.count

    guard n >= 2,
          y.count == n,
          requestedX.isFinite,
          x.allSatisfy(\.isFinite),
          y.allSatisfy(\.isFinite)
    else {
        return nil
    }

    for i in 1..<n {
        guard x[i] > x[i - 1] else {
            return nil
        }
    }

    // Clamp rather than extrapolate outside the model's redshift range.
    if requestedX <= x[0] {
        return y[0]
    }

    if requestedX >= x[n - 1] {
        return y[n - 1]
    }

    let h = (0..<(n - 1)).map { x[$0 + 1] - x[$0] }

    let delta = (0..<(n - 1)).map {
        (y[$0 + 1] - y[$0]) / h[$0]
    }

    var slopes = Array(repeating: 0.0, count: n)

    if n == 2 {
        slopes[0] = delta[0]
        slopes[1] = delta[0]
    } else {
        // Interior shape-preserving slopes.
        for i in 1..<(n - 1) {
            let before = delta[i - 1]
            let after = delta[i]

            if before == 0 ||
               after == 0 ||
               (before < 0) != (after < 0) {
                slopes[i] = 0
            } else {
                let w1 = 2 * h[i] + h[i - 1]
                let w2 = h[i] + 2 * h[i - 1]

                slopes[i] = (w1 + w2) /
                    (w1 / before + w2 / after)
            }
        }

        func endpointSlope(
            _ h0: Double,
            _ h1: Double,
            _ d0: Double,
            _ d1: Double
        ) -> Double {
            var slope =
                ((2 * h0 + h1) * d0 - h0 * d1) /
                (h0 + h1)

            if d0 == 0 ||
               (slope < 0) != (d0 < 0) {
                slope = 0
            } else if (d0 < 0) != (d1 < 0),
                      abs(slope) > 3 * abs(d0) {
                slope = 3 * d0
            }

            return slope
        }

        slopes[0] = endpointSlope(
            h[0], h[1], delta[0], delta[1]
        )

        slopes[n - 1] = endpointSlope(
            h[n - 2],
            h[n - 3],
            delta[n - 2],
            delta[n - 3]
        )
    }

    guard let i = (0..<(n - 1)).first(where: {
        requestedX <= x[$0 + 1]
    }) else {
        return nil
    }

    let interval = h[i]
    let t = (requestedX - x[i]) / interval
    let t2 = t * t
    let t3 = t2 * t

    let value =
        (2 * t3 - 3 * t2 + 1) * y[i] +
        (t3 - 2 * t2 + t) * interval * slopes[i] +
        (-2 * t3 + 3 * t2) * y[i + 1] +
        (t3 - t2) * interval * slopes[i + 1]

    return value.isFinite ? value : nil
}

// MARK: - Emulator output

func updateGraphData(
    observable: String,
    option: String,
    parameters: [Double],
    xArrayDictionary: [String: [Double]],
    outputIndices: [String: (Int, Int)],
    interpreter: Interpreter?,
    parameterNames: [String] = [],
    redshift: Double = 0.0
) -> [GraphData] {

    let observableDictionary: [String: String] = [
        "Cl": "Cl",
        "Pk": "Pk",
        "bg": "Background",
        "th": "Thermodynamics"
    ]

    guard let interpreter = interpreter else {
        print("Interpreter is nil")
        return []
    }

    var inputData = Data()

    for value in parameters {
        var floatValue = Float32(value)
        inputData.append(
            Data(bytes: &floatValue,
                 count: MemoryLayout<Float32>.size)
        )
    }

    do {
        try interpreter.copy(inputData, toInputAt: 0)
        try interpreter.invoke()
    } catch {
        print("Error invoking TFLite interpreter: \(error)")
        return []
    }

    let outputTensor: Tensor

    do {
        outputTensor = try interpreter.output(at: 0)
    } catch {
        print("Could not read TFLite output: \(error)")
        return []
    }

    let outputSize = outputTensor.shape.dimensions.reduce(1, *)
    let outputBuffer = UnsafeMutableBufferPointer<Float32>
        .allocate(capacity: outputSize)

    defer {
        outputBuffer.deallocate()
    }

    _ = outputTensor.data.copyBytes(to: outputBuffer)

    // Pk: interpolate between redshift-specific output slices.
    if observable.caseInsensitiveCompare("Pk") == .orderedSame {
        guard let xArray = xArrayDictionary["Pk"] else {
            print("Missing Pk x-grid")
            return []
        }

        let slices = pkOutputSlices(
            family: option,
            outputIndices: outputIndices
        )
        .filter {
            $0.start >= 0 &&
            $0.end <= outputSize &&
            $0.end - $0.start == xArray.count
        }

        guard !slices.isEmpty else {
            print("No valid Pk output slices for family \(option)")
            return []
        }

        let requestedZ = redshift.isFinite
            ? redshift
            : slices[0].redshift

        let z = min(
            max(requestedZ, slices[0].redshift),
            slices[slices.count - 1].redshift
        )

        let h = dimensionlessHubbleValue(
            parameterNames: parameterNames,
            parameters: parameters
        )

        var result: [GraphData] = []
        result.reserveCapacity(xArray.count)

        for i in xArray.indices {
            let k = xArray[i]

            guard k.isFinite, k > 0 else {
                continue
            }

            let powers = slices.map {
                Double(outputBuffer[$0.start + i])
            }

            guard powers.allSatisfy({
                $0.isFinite && $0 > 0
            }) else {
                continue
            }

            let power: Double

            if slices.count == 1 {
                power = powers[0]
            } else {
                let logPowers = powers.map { log($0) }
                let redshifts = slices.map(\.redshift)

                guard let interpolatedLogPower = pchipInterpolate(
                    x: redshifts,
                    y: logPowers,
                    at: z
                ) else {
                    continue
                }

                power = exp(interpolatedLogPower)
            }

            // Convert model outputs to h-scaled observational units.
            let kInHUnits = k / h
            let powerInHUnits = power * h * h * h

            guard kInHUnits.isFinite,
                  powerInHUnits.isFinite,
                  powerInHUnits > 0 else {
                continue
            }

            result.append(
                GraphData(
                    xValue: kInHUnits,
                    yValue: powerInHUnits
                )
            )
        }

        return result.sorted { $0.xValue < $1.xValue }
    }

    // Other observables retain the existing exact output lookup.
    guard let xArray = xArrayDictionary[
        observableDictionary[observable] ?? ""
    ] else {
        return []
    }

    var matchingRange: (Int, Int)?

    for (key, range) in outputIndices {
        let parts = key.components(separatedBy: "_")

        guard parts.count > 1 else {
            continue
        }

        let suffix = parts.dropFirst().joined(separator: "_")

        if suffix.caseInsensitiveCompare(option) == .orderedSame {
            matchingRange = range
            break
        }
    }

    guard let range = matchingRange else {
        print("No output range for \(observable)_\(option)")
        return []
    }

    let start = range.0
    let end = range.1
    let length = end - start

    guard start >= 0,
          end <= outputSize,
          length == xArray.count else {
        print("Output length does not match x-grid for \(observable)_\(option)")
        return []
    }

    return (0..<length).compactMap { i in
        let y = Double(outputBuffer[start + i])
        let x = xArray[i]

        guard x.isFinite, y.isFinite else {
            return nil
        }

        return GraphData(xValue: x, yValue: y)
    }
    .sorted { $0.xValue < $1.xValue }
}
