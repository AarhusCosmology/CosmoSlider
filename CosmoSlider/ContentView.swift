//
//  ContentView.swift
//  CMB Emulator
//
//  Created by Andreas Bek Nygaard Hansen on 22/05/2024.
//

import SwiftUI
import Charts
import TensorFlowLite
import Foundation


// Our custom view modifier to track rotation and
// call our action
struct DeviceRotationViewModifier: ViewModifier {
    let action: (UIDeviceOrientation) -> Void

    func body(content: Content) -> some View {
        content
            .onAppear()
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                action(UIDevice.current.orientation)
            }
    }
}

// A View wrapper to make the modifier easier to use
extension View {
    func onRotate(perform action: @escaping (UIDeviceOrientation) -> Void) -> some View {
        self.modifier(DeviceRotationViewModifier(action: action))
    }
}


struct ContentView: View {
    @State private var data: [GraphData] = []
    @State private var planckData: [GraphData] = []
    @State private var showPlanckData: Bool = false
    @State private var axisData: [GraphData] = []
    @State private var showingSelectSheet = false
    @State private var showingDocumentPicker = false
    @State private var showingBlankSheet = false
    @State private var showingCredits = false
    @State private var showingHelp = false
    @State private var settingsDetent = PresentationDetent.medium
    @State private var isOpened = false
    
    @State public var interpreter: Interpreter?
    @State public var selectedModel: String = "/default_model.tflite"
    @State public var selectedOption: String = "TT"
    @State public var options: [String] = []
    @State public var sliderNames: [String] = []
    @State public var sliderConfigs: [(range: (Double, Double), step: Double, precision: String)] = []
    @State public var xValues: [String:[Double]] = [:]
    @State public var outputIndices: [String:(Int,Int)] = [:]
    @State public var sliderValues: [Double] = []
    @State public var bestFitValues: [Double] = []
    @State public var refreshID = UUID()
    @State public var displayNames: [URL:String] = [:]
    @State public var showAlert: Bool = false
    @State public var alertMessage: String = ""
    
    @ObservedObject var documentHandler = DocumentHandler()
    
    let logscale = 200.0
    let transition = 0.3
    let l_min = 2.0
    
    @Environment(\.colorScheme) var colorScheme
    
    
    var body: some View {
        Drawer(
            isOpened: $isOpened,
            menu: {
                ZStack {
                    Color("menuColor").opacity(0.95)
                    VStack(alignment: .center) {
                        HStack {
                            Button {
                                isOpened.toggle()
                            } label: {
                                Image(systemName: "arrow.left.circle.fill")
                                    .resizable()
                                    .frame(width: 30, height: 30)
                            }
                            Spacer()
                        }
                        .padding(10)
                        
                        Spacer()
                        
                        HStack{
                            Spacer()
                            Image("app_logo")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 100, height: 100)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 50)
                                        .stroke(.purple.opacity(1.0), lineWidth: 1)
                                )
                                .cornerRadius(50)
                            Spacer()
                        }
                        
                        Text("CosmoSlider")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color.secondary)
                        
                        Text("Powered by CONNECT")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.secondary.opacity(0.5))
                        
                        List() {
                            Section() {
                                Button {
                                    showingSelectSheet = true
                                } label: {
                                    Label("Select model", systemImage: "filemenu.and.cursorarrow")
                                        .contentShape(Rectangle())
                                }
                                .sheet(isPresented: $showingSelectSheet) {
                                    SelectView(selectedModel: $selectedModel, showingSelectSheet: $showingSelectSheet, displayNames: $displayNames)
                                        .presentationDetents(
                                            [.medium, .large],
                                            selection: $settingsDetent
                                         )
                                }
                                
                                Button {
                                    showingDocumentPicker = true
                                } label: {
                                    Label("Import new model", systemImage: "square.and.arrow.up")
                                        .contentShape(Rectangle())
                                }
                                .sheet(isPresented: $showingDocumentPicker) {
                                    DocumentPicker(selectedModel: $selectedModel, showAlert: $showAlert, alertMessage: $alertMessage)
                                        .presentationDetents(
                                            [.medium, .large],
                                            selection: $settingsDetent
                                        )
                                        .edgesIgnoringSafeArea(.bottom)
                                }
                            }
                            Section() {
                                
                                Button {
                                    showingCredits = true
                                } label: {
                                    Label("Credits", systemImage: "person.text.rectangle")
                                        .contentShape(Rectangle())
                                }
                                .sheet(isPresented: $showingCredits) {
                                    CreditsView()
                                        .presentationDetents(
                                            [.medium, .large],
                                            selection: $settingsDetent
                                         )
                                }
                                Button {
                                    showingHelp = true
                                } label: {
                                    Label("Help", systemImage: "questionmark.circle")
                                        .contentShape(Rectangle())
                                }
                                .sheet(isPresented: $showingHelp) {
                                    HelpView()
                                        .presentationDetents(
                                            [.medium, .large],
                                            selection: $settingsDetent
                                         )
                                }
                                
                            }
                            
                        }
                        .alert(isPresented: $showAlert) {
                            Alert(
                                title: Text("Invalid File"),
                                message: Text(alertMessage),
                                dismissButton: .default(Text("OK"))
                            )
                        }
                        //.listStyle(.insetGrouped)
                        .listStyle(InsetGroupedListStyle()) // Ensure correct list style is used
                        .background(Color.clear) // Make the entire list background clear
                        .scrollContentBackground(.hidden) // Make the list content background clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                        Spacer()
                        
                    }
                    .padding()
                }
                .frame(width: 250)//, height: UIScreen.main.bounds.height)
                .clipShape(
                    .rect(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 15,
                        topTrailingRadius: 15
                    )
                )
            },
            content: {
                GeometryReader { geometry in
                    VStack {
                        // Calculate height for the graph and sliders
                        let graphHeight = UIScreen.main.bounds.height * 0.4
                        let graphWidth = UIScreen.main.bounds.width
                        let sliderHeight = (UIScreen.main.bounds.height * 0.6) / 7
                        
                        ZStack(alignment: .topLeading) {
                            
                            ZStack {
                                Chart {
                                    ForEach(data) { point in
                                        LineMark(
                                            x: .value("X Value", scaleGraphPoint(point:point)),
                                            y: .value("Y Value", point.yValue)
                                        )
                                        .clipShape(PlotAreaShape())
                                    }
                                    .interpolationMethod(.cardinal)
                                    if showPlanckData {
                                        ForEach(planckData) { point in
                                            ErrorBarMark(
                                                x: .value("x", scaleGraphPoint(point:point)),
                                                y: .value("y", point.yValue),
                                                low: .value("y", point.yValue-point.errNegative),
                                                high: .value("y", point.yValue+point.errPositive)
                                            )
                                            .foregroundStyle(Color.green.opacity(0.5))
                                            .clipShape(PlotAreaShape())
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
                                .chartYScale(domain: getYDomain())
                                .chartXAxis {
                                    customXAxis()
                                    customXAxisMinorTicks()
                                }
                                .chartYAxis {
                                    customYAxis()
                                }
                                .chartXAxisLabel(position: .bottom, alignment: .center) {
                                    Image("ell")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 70, height: 70)
                                        .foregroundColor(.gray)
                                        .padding(-25)
                                }
                                .chartYAxisLabel(position: .leading, alignment: .center) {
                                    
                                    Image(yAxisLabelName)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: yAxisLabelSize, height: yAxisLabelSize)
                                        .foregroundColor(.gray)
                                        .rotationEffect(.degrees(180), anchor: .center)
                                        .padding(-yAxisLabelPad)
                                }
                                .padding([.leading, .trailing])
                                .frame(height: graphHeight)
                                .frame(width: graphWidth)
                                .padding(.top, 75)
                                .drawingGroup()
                            }
                            
                            HStack {
                                Button {
                                    isOpened.toggle()
                                } label: {
                                    Image(systemName: "text.alignleft")
                                        .resizable()
                                        .frame(width: 30, height: 30)
                                }
                                .padding()
                                
                                Spacer()
                                
                                Toggle("Show data", isOn: $showPlanckData)
                                    .frame(width: 100, alignment: .center)
                                    .padding()
                                
                                Spacer()
                                
                                
                                PickerButton(selectedOption: $selectedOption, options: $options)
                                .frame(alignment: .center)
                                .onChange(of: selectedOption) {
                                    updateGraphData()
                                    updatePlanckData()
                                    updateAxisData()
                                }
                                
                                Spacer()
                                
                                Button(action: resetSliders) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .padding()
                                        .background(Color.white)
                                        .clipShape(Circle())
                                        .shadow(radius: 3)
                                }
                                .padding()
                            }
                        }
                        ScrollView {
                            ForEach(Array(sliderNames.enumerated()), id: \.element) { index, name in
                                let config = sliderConfigs[index]
                                let range = config.range
                                let step = config.step
                                let precision = config.precision
                                // Check that range is valid
                                if range.0 < range.1 {
                                    VStack {
                                        Slider(value: $sliderValues[index], in: range.0...range.1, step: step)
                                        HStack {
                                            let fileURL = URL(fileURLWithPath: name)
                                            //print(fileURL)
                                            //print(sliderNames[index])
                                            SVGImage(url: fileURL)
                                                .frame(width: 230, height: 23, alignment: .bottomLeading)
                                                
                                            Spacer()
                                            Text("\(sliderValues[index], specifier: precision)")
                                        }
                                    }
                                    .onChange(of: sliderValues[index]) {
                                        updateGraphData()
                                    }
                                    .frame(height: sliderHeight)
                                } else {
                                    // Provide a default valid range in case of invalid range
                                    Text("Invalid range for Slider \(index + 1)").foregroundColor(.red)
                                }
                            }
                            .id(refreshID)
                            .padding()
                        }
                        
                    }
                    .environmentObject(documentHandler)
                    .onOpenURL { url in
                        documentHandler.handleIncomingURL(url: url, selectedModel: $selectedModel, showAlert: $showAlert, alertMessage: $alertMessage)
                    }
                    .onAppear(perform: loadMetadata)
                    .onAppear(perform: loadTFLiteInterpreter)
                    .onAppear(perform: resetSliders)
                    .onAppear(perform: updateGraphData)
                    .onAppear(perform: updatePlanckData)
                    .onAppear(perform: updateAxisData)
                    .onAppear(perform: populateDisplayNames)
                    .onChange(of: selectedModel) {
                        loadMetadata()
                        loadTFLiteInterpreter()
                        resetSliders()
                        updateGraphData()
                        updatePlanckData()
                        updateAxisData()
                    }
                    .onChange(of: selectedOption) {
                        updateGraphData()
                        updatePlanckData()
                        updateAxisData()
                    }
                }
            }
        )
    }
    
    func populateDisplayNames() {
        for item in documentHandler.savedFiles {
            if item.name == "default model" {
                displayNames[item.url] = "ΛCDM (default)"
            } else {
                displayNames[item.url] = item.name
            }
        }
        if let retrievedDictionary = retrieveDictionaryFromUserDefaults(key: "displayNames") {
            displayNames = retrievedDictionary
        }
    }
    
    func retrieveDictionaryFromUserDefaults(key: String) -> [URL: String]? {
        guard let stringKeyedDictionary = UserDefaults.standard.dictionary(forKey: key) as? [String: String] else {
            return nil
        }
        return stringKeyedDictionary.reduce(into: [URL: String]()) { result, pair in
            let url = URL(fileURLWithPath: pair.key)
            result[url] = pair.value
        }
    }
    
    var yAxisLabelSize: CGFloat {
        if selectedOption == "PP" {
            return 150
        } else {
            return 100
        }
    }
    
    var yAxisLabelPad: CGFloat {
        if selectedOption == "PP" {
            return 70
        } else {
            return 45
        }
    }
    
    var yAxisLabelName: String {
        if selectedOption == "PP" {
            return "Cl_pp"
        } else {
            return "Cl"
        }
    }
    
    func getYDomain() -> ClosedRange<Double> {
        switch selectedOption {
        case "TT":
            return 0...7000
        case "TE":
            return -230...230
        case "EE":
            return -2...60
        case "PP":
            return 0...2.5
        default:
            return 0...1
        }
    }
    
    func updateAxisData() {
        switch selectedOption {
        case "TT":
            axisData = [GraphData(xValue: 0, yValue: 0), GraphData(xValue: 1, yValue: 7000)]
        case "TE":
            axisData = [GraphData(xValue: 0, yValue: -230), GraphData(xValue: 1, yValue: 230)]
        case "EE":
            axisData = [GraphData(xValue: 0, yValue: -2), GraphData(xValue: 1, yValue: 60)]
        case "PP":
            axisData = [GraphData(xValue: 0, yValue: 0), GraphData(xValue: 1, yValue: 2.5)]
        default:
            axisData = []
        }
    }
    
    
    func updateGraphData() {
        var inputData = Data()
        sliderValues.forEach { value in
            var val = Float32(value)
            inputData.append(Data(bytes: &val, count: MemoryLayout<Float32>.size))
        }
        
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
                    if rest.caseInsensitiveCompare(selectedOption) == .orderedSame {
                        indexShift = value.0
                        length = value.1 - value.0
                        break
                    }
                }
            }
            
            var j = 0
            if let xArray = xValues["Cl"] {
                guard length == xArray.count else {
                    print("Length of xArray does not match length of outputData")
                    return
                }
                data = (0..<length).map { i in
                    j = i + indexShift
                    var scaleValue: Double = 1
                    if selectedOption == "PP" {
                        scaleValue = xArray[i]*(xArray[i]+1)*1e+7
                    } else {
                        scaleValue = pow(2.7255e+6,2)
                    }
                    return GraphData(xValue: xArray[i], yValue: Double(outputData[j])*scaleValue)
                }
            } else {
                data = []
            }
        } else {
            print("Output tensor is nil")
        }
    }
    
    func updatePlanckData() {
        // Update graph data based on selectedOption
        let fileName: String
        
        switch selectedOption {
        case "TT":
            fileName = "tt_data"
        case "TE":
            fileName = "te_data"
        case "EE":
            fileName = "ee_data"
        case "PP":
            fileName = "pp_data"
        default:
            fileName = ""
        }
        
        planckData = readDataFromFile(fileName: fileName)
    }
    
    func readDataFromFile(fileName: String) -> [GraphData] {
        var graphData: [GraphData] = []
        
        guard let fileURL = Bundle.main.url(forResource: fileName, withExtension: "txt") else {
            print("File not found.")
            return []
        }
        
        do {
            let data = try String(contentsOf: fileURL, encoding: .utf8)
            let lines = data.components(separatedBy: .newlines)
            
            // Skip the header line
            for line in lines.dropFirst().dropLast() {
                //print(line)
                var components = line.components(separatedBy: "  ").map { $0.trimmingCharacters(in: .whitespaces) }
                components.removeAll { $0.isEmpty }
                var shift: Int = 0
                var shiftErrPos: Int = 0
                if selectedOption == "PP" {
                    shift = 3
                    shiftErrPos = 1
                }
                if components.count >= 3, let xValue = Double(components[0+shift]), let yValue = Double(components[1+shift]), let errNeg = Double(components[2+shift]), let errPos = Double(components[3+shift-shiftErrPos]) {
                    var scaleValue: Double = 1
                    if selectedOption == "PP" {
                        scaleValue = 1e+7
                    }
                    graphData.append(GraphData(xValue: xValue, yValue: yValue*scaleValue, errPositive: errPos*scaleValue, errNegative: errNeg*scaleValue))
                }
            }
        } catch {
            print("Error reading file:", error)
        }
        return graphData
    }
    
    func resetSliders() {
        // Reset the sliders to best-fit values
        sliderValues = []
        for (index, config) in sliderConfigs.enumerated() {
            let precision = config.precision
            let value = bestFitValues[index]
            // round value to the precision
            let roundedValue = Double(String(format: precision, value))!
            sliderValues.append(roundedValue)
        }
    }
    
    func customXAxis() -> some AxisContent {
        let (majorTicks, _) = generateXTicks()
        let majorLabels = ["10^1", "10^2", "500", "1000", "1500", "2000", "2500"]
        let majorLabelsFloats: [Double] = [10, 100, 500, 1000, 1500, 2000, 2500]
        
        return AxisMarks(values: majorTicks) { value in
            AxisTick(centered: true, length: 10, stroke: .init(lineWidth: 2))
                .foregroundStyle(Color.gray)
            AxisValueLabel(anchor: .top) {
                if let index = majorTicks.firstIndex(where: { $0 == value.as(Double.self) }) {
                    if index < 2 {
                        let (base, exponent) = separateScientificString(majorLabels[index])
                        SuperscriptTextView(base: base, exponent:exponent)
                    } else {
                        Text("\(majorLabelsFloats[index], format: .number)")
                            .font(.system(size: 12))
                    }
                }
            }
        }
    }
    
    func customXAxisMinorTicks() -> some AxisContent {
        let (_, minorTicks) = generateXTicks()
        let minorLabels = ["", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "",
                           "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", ""]
        
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
        let strideValue: Double
        switch selectedOption {
        case "TT":
            strideValue = 2000
        case "TE":
            strideValue = 100
        case "EE":
            strideValue = 20
        case "PP":
            strideValue = 0.5
        default:
            strideValue = 1
        }
        return AxisMarks(position: .leading, values: .stride(by: strideValue)) { value in
            AxisTick(centered: true, length: 10, stroke: .init(lineWidth: 2))
                .foregroundStyle(Color.gray)
            AxisValueLabel {
                if let doubleValue = value.as(Double.self) {
                    Text("\(doubleValue, format: .number)")
                        .rotationEffect(.degrees(270), anchor: .center)
                        .frame(width: 35, height: 10)
                        .offset(x: 6)
                }
            }
        }
    }
    
    func separateScientificString(_ stringValue: String) -> (base: String, exponent: String) {
        let components = stringValue.components(separatedBy: "^")
        return (components[0], components[1])
    }
    
    func generateXTicks() -> (majorTicks: [Double], minorTicks: [Double]) {
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
    
    func logScale(_ x: Double) -> Double {
        let logx = log10(x)
        let logxnew = (logx / log10(logscale)) * transition
        
        let loglmin = (log10(l_min) / log10(logscale)) * transition
        let logscale = (log10(logscale) / log10(logscale)) * transition
        let logdiff = logscale - loglmin
        return ((logxnew - loglmin) * transition / logdiff)
    }

    func linScale(_ x: Double) -> Double {
        let linxnew = (x / (2500 - logscale)) - (logscale / (2500 - logscale))
        return ((linxnew * (1 - transition)) + transition)
    }
    
    func scaleGraphPoint(point: GraphData) -> Double {
        let p = point.xValue
        if p <= logscale {
            return logScale(p)
        } else {
            return linScale(p)
        }
    }

    func rescaleXCoordinate(_ x: Double) -> Double {
        // Replace with your own logic to rescale x-coordinates
        return log10(x)
    }
    
}





#Preview {
    ContentView()
}
