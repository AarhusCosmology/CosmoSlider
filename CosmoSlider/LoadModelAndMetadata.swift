//
//  LoadMetadata.swift
//  CMB Emulator
//
//  Created by Andreas Bek Nygaard Hansen on 17/06/2024.
//

import SwiftUI
import Foundation
import ZIPFoundation
import TensorFlowLite


extension ContentView {
    
    func loadMetadata() {
        var zipFilePath: String?
        if selectedModel == "/default_model.tflite" {
            zipFilePath = Bundle.main.path(forResource: "default_model", ofType: "tflite")
        } else {
            zipFilePath = selectedModel
        }
        guard let path = zipFilePath else {
            print("Failed to load metadata")
            return
        }
        do {
            let fileManager = FileManager.default
            let tempDirectory = fileManager.temporaryDirectory
            
            let archive = try Archive(url: URL(fileURLWithPath: path), accessMode: .read)
            
            try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true, attributes: nil)
            
            
            //##################################
            // Get input_names.txt file
            //##################################
            
            let tempInputPath = tempDirectory.appendingPathComponent("input_names.txt")
            guard let entry = archive["input_names.txt"] else {
                return
            }
            
            if fileManager.fileExists(atPath: tempInputPath.path) {
                do {
                    try fileManager.removeItem(at: tempInputPath)
                } catch {
                    print("Error deleting file: \(error)")
                }
            }
            
            _ = try archive.extract(entry, to: tempInputPath)
            
            let data = try String(contentsOf: tempInputPath, encoding: .utf8)
            let lines = data.components(separatedBy: .newlines)
            
            var names: [String] = []
            sliderConfigs = []
            for line in lines {
                // each line is on the form "name, xmin, xmax, deltax" and the names (plus the extension .svg) should be extracted and appended to the names list
                let components = line.components(separatedBy: ", ")
                if components.count > 0 {
                    names.append(components[0] + ".svg")
                }
                // xmin, xmax, and deltax should be used to fill the sliderConfigs list where each entry has the form ((xmin,xmax),deltax, precision). Precision is a String on the form "%.3f" where the 3 references the last decimal place of deltax, e.g. deltx=0.01 -> precision="%.2f". The precision be determined from deltax
                if components.count > 3, let xmin = Double(components[1]), let xmax = Double(components[2]), let deltax = Double(components[3]) {
                    var precision = String(format: "%%.%df", String(deltax).count-2)
                    if deltax == 1.0 {
                        precision = "%.0f"
                    }
                    let roundedXMin = Double(String(format: precision, xmin))!
                    let roundedXMax = Double(String(format: precision, xmax))!
                    sliderConfigs.append(((roundedXMin, roundedXMax), deltax, precision))
                }
            }
            
            try fileManager.removeItem(at: tempInputPath)
            
            //##################################
            // Get the x_values.txt file
            //##################################
            
            let tempXValuesPath = tempDirectory.appendingPathComponent("x_values.txt")
            guard let entryX = archive["x_values.txt"] else {
                return
            }
            
            if fileManager.fileExists(atPath: tempXValuesPath.path) {
                do {
                    try fileManager.removeItem(at: tempXValuesPath)
                } catch {
                    print("Error deleting file: \(error)")
                }
            }
            
            _ = try archive.extract(entryX, to: tempXValuesPath)
            
            let dataX = try String(contentsOf: tempXValuesPath, encoding: .utf8)
            let linesX = dataX.components(separatedBy: .newlines)
            
            // each line of linesX is an x value. Some of the lines (e.g. the first) are headers to specify x values for a certain kind of output these headers must be detected by them not being intergers, floats, or doubles and then used as keys in the dictionary xValues where the values of the dictionary are lists of doubles. These lists of doubles should contain the x values associated with the key. ignore empty lines and remove ":" from the keys
            var key = ""
            var values: [Double] = []
            for line in linesX {
                if line.isEmpty {
                    continue
                }
                if let xValue = Double(line) {
                    values.append(xValue)
                } else {
                    if !key.isEmpty {
                        xValues[key] = values
                        print()
                    }
                    key = line.replacingOccurrences(of: ":", with: "")
                    values = []
                }
            }
            xValues[key] = values
            
            try fileManager.removeItem(at: tempXValuesPath)
            
            
            //##################################
            // Get the output indices
            //##################################
            
            let tempOutputIndicesPath = tempDirectory.appendingPathComponent("output_indices.txt")
            guard let entryOutputIndices = archive["output_indices.txt"] else {
                return
            }
            
            if fileManager.fileExists(atPath: tempOutputIndicesPath.path) {
                do {
                    try fileManager.removeItem(at: tempOutputIndicesPath)
                } catch {
                    print("Error deleting file: \(error)")
                }
            }
            
            _ = try archive.extract(entryOutputIndices, to: tempOutputIndicesPath)
            
            let dataOutputIndices = try String(contentsOf: tempOutputIndicesPath, encoding: .utf8)
            let linesOutputIndices = dataOutputIndices.components(separatedBy: .newlines)
            
            // each line is of the form "name, i_start, i_end". If the name does not begin with "derived", the line should be added to the dictionary outputIndices in the following way [name: (i_start, i_end)]
            
            options = []
            for line in linesOutputIndices {
                let components = line.components(separatedBy: ", ")
                if components[0].hasPrefix("derived") {
                    continue
                }
                if components.count > 2, let i_start = Int(components[1]), let i_end = Int(components[2]) {
                    outputIndices[components[0]] = (i_start, i_end)
                    options.append(components[0].components(separatedBy: "_")[1...].joined(separator: "_").uppercased())
                }
            }
            
            // if selectedOption is not in options, it should be set to the first entry of options
            if !options.contains(selectedOption) {
                selectedOption = options[0]
            }
            
            try fileManager.removeItem(at: tempOutputIndicesPath)
            
            
            
            //##################################
            // Get best-fit values
            //##################################
            
            let tempBestFitPath = tempDirectory.appendingPathComponent("best_fit.txt")
            
            guard let entryBestFit = archive["best_fit.txt"] else {
                return
            }
            
            if fileManager.fileExists(atPath: tempBestFitPath.path) {
                do {
                    try fileManager.removeItem(at: tempBestFitPath)
                } catch {
                    print("Error deleting file: \(error)")
                }
            }
            
            _ = try archive.extract(entryBestFit, to: tempBestFitPath)
            
            let dataBestFit = try String(contentsOf: tempBestFitPath, encoding: .utf8)
            
            let linesBestFit = dataBestFit.components(separatedBy: .newlines)
            
            // each line is on the form "name, value". Values should be appended to bestFitValues
            
            bestFitValues = []
            for line in linesBestFit {
                let components = line.components(separatedBy: ", ")
                if components.count > 1, let value = Double(components[1]) {
                    bestFitValues.append(value)
                }
            }
            
            try fileManager.removeItem(at: tempBestFitPath)
            
            
            
            //##################################
            // Get the svg files
            //##################################
            
            sliderNames = []
            for index in 0..<sliderConfigs.count {
                let tempSVGPath = tempDirectory.appendingPathComponent(names[index])
                
                guard let entry = archive[names[index]] else {
                    print(names[index])
                    print("svg file not found in the archive")
                    return
                }
                
                if fileManager.fileExists(atPath: tempSVGPath.path) {
                    do {
                        try fileManager.removeItem(at: tempSVGPath)
                        print("File deleted successfully")
                    } catch {
                        print("Error deleting file: \(error)")
                    }
                } else {
                    print("File does not exist")
                }
                
                // Extract the file to the temporary path
                _ = try archive.extract(entry, to: tempSVGPath)
                sliderNames.append(tempSVGPath.path)
                
                refreshID = UUID()
                
            }
        } catch {
            print("Failed to load metadata with error: \(error)")
        }
    }
    
    func loadTFLiteInterpreter() {
        var zipFilePath: String?
        if selectedModel == "/default_model.tflite" {
            zipFilePath = Bundle.main.path(forResource: "default_model", ofType: "tflite")
        } else {
            zipFilePath = selectedModel
        }
        guard let path = zipFilePath else {
            print("Failed to load model")
            return
        }
        
        do {
            let fileManager = FileManager.default
            let tempDirectory = fileManager.temporaryDirectory
            let tempTFLitePath = tempDirectory.appendingPathComponent("model.tflite")
            
            // Extract the tflite file from the zip archive
            let archive = try Archive(url: URL(fileURLWithPath: path), accessMode: .read)
            
            // find name of file in archive with extension .tflite
            var name: String?
            name = archive.map { $0.path }.filter { $0.hasSuffix(".tflite") }.first
            guard let name = name else {
                print("No tflite file found in archive")
                return
            }
            
            guard let entry = archive[name] else {
                print("\(name) not found in archive")
                return
            }
            
            try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true, attributes: nil)
            
            // Extract the file to the temporary path
            _ = try archive.extract(entry, to: tempTFLitePath)
            
            
            do {
                let newInterpreter = try Interpreter(modelPath: tempTFLitePath.path)
                try newInterpreter.allocateTensors()
                print("Model loaded and tensors allocated successfully")
                interpreter = newInterpreter
            } catch {
                print("Error creating or allocating tensors for the interpreter: \(error)")
            }
            
            // Clean up: Optionally delete the temporary file after loading the model
            try fileManager.removeItem(at: tempTFLitePath)
            
        } catch {
            print("Failed to invoke interpreter with error: \(error)")
        }
    }
    
}
