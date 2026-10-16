//
//  ContentView.swift
//  CMB Emulator
//
//  Created by Andreas Bek Nygaard Hansen on 22/05/2024.
//

import SwiftUI
import TensorFlowLite
import Foundation


struct ContentView: View {
    @State private var data: [GraphData] = []
    @State private var storedDataDictionary: [String: [String: [String: [GraphData]]]] = [:]
    @State private var storedChartStyleDictionary: [String: ChartStyle] = [:]
    @State private var graphOrder: [String] = []
    @State private var observedData: [GraphData] = []
    @State private var showObservedData: Bool = false
    @State private var axisData: [GraphData] = []
    @State private var showingSelectSheet = false
    @State private var showingDocumentPicker = false
    @State private var showingBlankSheet = false
    @State private var showingLiterature = false
    @State private var showingCredits = false
    @State private var showingHelp = false
    @State private var settingsDetent = PresentationDetent.medium
    @State private var isOpened = false
    @State private var showExportDialog = false
    @State private var exportFileName = "chart.pdf"
    @State private var showExportSuccessAlert = false
    @State private var savedFileURL: URL?
    @State private var chartStyle = ChartStyle()
    @State private var showStyleSheet = false
    @State private var showAddGraphSheet = false
    
    @State public var interpreter: Interpreter?
    @State public var selectedModel: String = "/testing_out.tflite"//"/default_model.tflite"
    @State public var selectedObservable: String = "Pk"//bg"
    @State public var selectedOption: String = "pk_0.0"//"ang.diam.dist."
    @State public var optionsDictionary: [String:[String]] = [:]
    @State public var options: [String] = []
    @State public var lowestYValue: Double = 1.0
    @State public var highestYValue: Double = 2.0
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
    
    let observableDictionary: [String: String] = [
        "Cl": "Cl",
        "Pk": "Pk",
        "bg": "Background",
        "th": "Thermodynamics"
    ]
    
    @Environment(\.colorScheme) var colorScheme
    
    
    var body: some View {
        ZStack {
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
                                        Label("Import new model", systemImage: "square.and.arrow.down")
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
                                        showAddGraphSheet = true
                                    } label: {
                                        Label("Add graph to chart", systemImage: "plus.app")
                                            .contentShape(Rectangle())
                                    }
                                    .sheet(isPresented: $showAddGraphSheet) {
                                        AddGraphSheet(
                                            isOpened: $showAddGraphSheet,
                                            data: $data,
                                            style: $chartStyle,
                                            dataDictionary: $storedDataDictionary,
                                            styleDictionary: $storedChartStyleDictionary,
                                            graphOrder: $graphOrder,
                                            optionsDictionary: $optionsDictionary,
                                            parameters: $sliderValues,
                                            xArrayDictionary: $xValues,
                                            interpreter: $interpreter,
                                            outputIndices: $outputIndices
                                        )
                                    }
                                    
                                    Button {
                                        showStyleSheet = true
                                    } label: {
                                        Label("Edit chart style", systemImage: "square.and.pencil")
                                            .contentShape(Rectangle())
                                    }
                                    .sheet(isPresented: $showStyleSheet) {
                                        ChartStyleSheet(
                                            isOpened: $showStyleSheet,
                                            style: $chartStyle
                                        )
                                    }
                                    
                                    Button {
                                        exportFileName = "chart.pdf"
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                            showExportDialog = true
                                        }
                                    } label: {
                                        Label("Export chart", systemImage: "square.and.arrow.up")
                                            .contentShape(Rectangle())
                                    }
                                    .alert("Export complete", isPresented: $showExportSuccessAlert) {
                                        Button("OK", role: .cancel) { }
                                    } message: {
                                        if let url = savedFileURL {
                                            Text("Saved to:\nFiles ▸ CosmoSlider ▸ \(url.lastPathComponent)")
                                        }
                                    }
                                    
                                }
                                Section() {
                                    
                                    Button {
                                        showingLiterature = true
                                    } label: {
                                        Label("Literature", systemImage: "text.book.closed")
                                            .contentShape(Rectangle())
                                    }
                                    .sheet(isPresented: $showingLiterature) {
                                        LiteratureView()
                                            .presentationDetents(
                                                [.medium, .large],
                                                selection: $settingsDetent
                                            )
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
                                
                                ScientificChartView(
                                    data: $data,
                                    showObservedData: $showObservedData,
                                    observedData: $observedData,
                                    axisData: $axisData,
                                    selectedObservable: $selectedObservable,
                                    selectedOption: $selectedOption,
                                    xValues: $xValues,
                                    style: $chartStyle,
                                    dataDictionary: $storedDataDictionary,
                                    styleDictionary: $storedChartStyleDictionary,
                                    graphOrder: $graphOrder,
                                    lowestYValue: $lowestYValue,
                                    highestYValue: $highestYValue,
                                    logscale: logscale,
                                    transition: transition,
                                    l_min: l_min,
                                    width: graphWidth,
                                    height: graphHeight,
                                    isExporting: false
                                )
                                
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
                                    
                                    Toggle("Show data", isOn: $showObservedData)
                                        .frame(width: 100, alignment: .center)
                                        .padding()
                                        .font(.system(size: 15))
                                    
                                    Spacer()
                                    
                                    PickerButton(selectedOption: $selectedOption, selectedObservable: $selectedObservable, optionsDictionary: $optionsDictionary)
                                        .frame(alignment: .center)
                                        .onChange(of: selectedOption) {
                                            setDataForGraph()
                                            updateObservedData()
                                            updateAxisData()
                                        }
                                    
                                    Spacer()
                                    
                                    Button(action: resetSliders) {
                                        Image(systemName: "arrow.counterclockwise")
                                            .font(.system(size: 20))
                                            .padding()
                                            .frame(width: 50, height: 50)
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
                                                SVGImage(url: fileURL)
                                                    .frame(width: 230, height: 23, alignment: .bottomLeading)
                                                
                                                Spacer()
                                                Text("\(sliderValues[index], specifier: precision)")
                                                    .font(.system(size: 15))
                                            }
                                        }
                                        .onChange(of: sliderValues[index]) {
                                            setDataForGraph()
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
                        .onAppear(perform: setYLimitValues)
                        .onAppear(perform: setDataForGraph)
                        .onAppear(perform: updateAxisData)
                        .onAppear(perform: updateObservedData)
                        .onAppear(perform: populateDisplayNames)
                        .onChange(of: selectedModel) {
                            loadMetadata()
                            loadTFLiteInterpreter()
                            setYLimitValues()
                            resetSliders()
                            setDataForGraph()
                            updateAxisData()
                            updateObservedData()
                        }
                        .onChange(of: selectedOption) {
                            setYLimitValues()
                            setDataForGraph()
                            updateAxisData()
                            updateObservedData()
                        }
                    }
                }
            )
            
            if showExportDialog {
                ExportNameAlert(
                    isPresented: $showExportDialog,
                    fileName: $exportFileName,
                    onExport: {
                        Task { @MainActor in
                            await exportChartToFiles()
                        }
                    }
                )
            }
        }
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
    
    
    func updateAxisData() {
        switch selectedObservable {
        case "Cl":
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
                axisData = [GraphData(xValue: 0, yValue: 1), GraphData(xValue: 1, yValue: 2)]
            }
        case "Pk":
            axisData = [GraphData(xValue: log10(xValues[observableDictionary[selectedObservable] ?? ""]?.first ?? -6), yValue: -2), GraphData(xValue: log10(xValues[observableDictionary[selectedObservable] ?? ""]?.last ?? 2), yValue: 6)]
        case "bg", "th":
            let xMin: Double
            let xMax: Double
            if let observableKey = observableDictionary[selectedObservable],
               let values = xValues[observableKey],
               !values.isEmpty {
                xMin = values.min()!
                xMax = values.max()!
            } else {
                xMin = 1e-14
                xMax = 1
            }
            let yMin: Double
            let yMax: Double
            if abs(log10(highestYValue)-log10(lowestYValue)) < 1.0 {
                yMin = lowestYValue
                yMax = highestYValue
            } else {
                yMin = log10(lowestYValue)
                yMax = log10(highestYValue)
            }
            axisData = [GraphData(xValue: xMin, yValue: yMin-0.1*abs(yMin)), GraphData(xValue: xMax, yValue: yMax+0.2*abs(yMax))]
        default:
            axisData = [GraphData(xValue: 0, yValue: 0), GraphData(xValue: 1, yValue: 1)]
        }
    }

    func setDataForGraph() {
        data = updateGraphData(observable: selectedObservable,
                               option: selectedOption,
                               parameters: sliderValues,
                               xArrayDictionary: xValues,
                               outputIndices: outputIndices,
                               interpreter: interpreter!)
    }
    
    func setYLimitValues() {
        let bestFitGraph = updateGraphData(observable: selectedObservable,
                                           option: selectedOption,
                                           parameters: bestFitValues,
                                           xArrayDictionary: xValues,
                                           outputIndices: outputIndices,
                                           interpreter: interpreter!)
        lowestYValue = bestFitGraph.min(by: { $0.yValue < $1.yValue })?.yValue ?? 1
        highestYValue = bestFitGraph.max(by: { $0.yValue < $1.yValue })?.yValue ?? 2
    }

    func updateObservedData() {
        // Update graph data based on selectedOption
        let fileName: String
        var xValIndex: Int = 0
        var yValIndex: Int = 1
        var errNegIndex: Int = 2
        var errPosIndex: Int = 3
        
        switch selectedObservable {
        case "Cl":
            switch selectedOption {
            case "TT":
                fileName = "tt_data"
            case "TE":
                fileName = "te_data"
            case "EE":
                fileName = "ee_data"
            case "PP":
                fileName = "pp_data"
                xValIndex = 3
                yValIndex = 4
                errNegIndex = 5
                errPosIndex = 5
            default:
                fileName = ""
            }
        case "Pk":
            let redshift: Double = Double(selectedOption.split(separator: "_").last ?? "0.0") ?? 0.0
            switch redshift {
            case 0.0:
                fileName = "pk_boss"
                errNegIndex = 4
                errPosIndex = 4
            default:
                fileName = ""
            }
        default:
            fileName = ""
        }
        observedData = readDataFromFile(fileName: fileName, xValIndex: xValIndex, yValIndex: yValIndex, errNegIndex: errNegIndex, errPosIndex: errPosIndex)
    }
    
    func readDataFromFile(fileName: String, xValIndex: Int, yValIndex: Int, errNegIndex: Int, errPosIndex: Int) -> [GraphData] {
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
                var components = line.components(separatedBy: " ").map { $0.trimmingCharacters(in: .whitespaces) }
                components.removeAll { $0.isEmpty }
                if components.count >= 3, let xValue = Double(components[xValIndex]), let yValue = Double(components[yValIndex]), let errNeg = Double(components[errNegIndex]), let errPos = Double(components[errPosIndex]) {
                    graphData.append(GraphData(xValue: xValue, yValue: yValue, errPositive: errPos, errNegative: errNeg))
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
    
    @MainActor
    func exportChartToFiles() async {
        let fileName = exportFileName.isEmpty ? "chart.pdf" : exportFileName
        let finalName = fileName.hasSuffix(".pdf") ? fileName : fileName + ".pdf"

        let appFolder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

        do {
            if !FileManager.default.fileExists(atPath: appFolder.path) {
                try FileManager.default.createDirectory(
                    at: appFolder,
                    withIntermediateDirectories: true
                )
            }

            let fileURL = appFolder.appendingPathComponent(finalName)

            let exportView = ScientificChartView(
                data: $data,
                showObservedData: $showObservedData,
                observedData: $observedData,
                axisData: $axisData,
                selectedObservable: $selectedObservable,
                selectedOption: $selectedOption,
                xValues: $xValues,
                style: $chartStyle,
                dataDictionary: $storedDataDictionary,
                styleDictionary: $storedChartStyleDictionary,
                graphOrder: $graphOrder,
                lowestYValue: $lowestYValue,
                highestYValue: $highestYValue,
                logscale: logscale,
                transition: transition,
                l_min: l_min,
                width: 0.99*chartStyle.exportWidth,
                height: 0.97*chartStyle.exportHeight,
                isExporting: true
            )

            try ScientificChartView.exportPDF(
                chart: exportView,
                width: chartStyle.exportWidth,
                height: chartStyle.exportHeight,
                url: fileURL
            )

            savedFileURL = fileURL
            showExportSuccessAlert = true
            print("Saved chart to:", fileURL.path)

        } catch {
            print("Export failed:", error)
        }
    }
}





#Preview {
    ContentView()
}
