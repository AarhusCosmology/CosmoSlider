//
//  ContentView.swift
//  CMB Emulator
//
//  Created by Andreas Bek Nygaard Hansen on 22/05/2024.
//

import SwiftUI
import TensorFlowLite
import Foundation

private enum ChartEditorSheet: String, Identifiable {
    case addGraph
    case chartStyle
    case axisLimits

    var id: String { rawValue }
}

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
    //@State private var showStyleSheet = false
    //@State private var showAddGraphSheet = false
    @State private var axisLimits: [Double] = [1e-6, 1.0, 1e-2, 1e6]
    @State private var axisScales: [String] = ["log", "log"]
    @State private var mixSplit: Double = 200.0
    @State private var activeChartSheet: ChartEditorSheet?
    
    @State public var interpreter: Interpreter?
    @State public var selectedModel: String = "/testing_out.tflite"//"/default_model.tflite"
    @State public var selectedObservable: String = "Cl"
    @State public var selectedOption: String = "TT"
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
                                        activeChartSheet = .addGraph
                                    } label: {
                                        Label("Add graph to chart", systemImage: "plus.app")
                                    }

                                    Button {
                                        activeChartSheet = .chartStyle
                                    } label: {
                                        Label("Edit chart style", systemImage: "square.and.pencil")
                                    }

                                    Button {
                                        activeChartSheet = .axisLimits
                                    } label: {
                                        Label("Edit axis limits", systemImage: "slider.horizontal.3")
                                    }
                                    
                                    Button {
                                        requestChartExport()
                                    } label: {
                                        Label("Export chart", systemImage: "square.and.arrow.up")
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
                                    selectedObservable: $selectedObservable,
                                    selectedOption: $selectedOption,
                                    xValues: $xValues,
                                    style: $chartStyle,
                                    dataDictionary: $storedDataDictionary,
                                    styleDictionary: $storedChartStyleDictionary,
                                    graphOrder: $graphOrder,
                                    lowestYValue: $lowestYValue,
                                    highestYValue: $highestYValue,
                                    axisLimits: $axisLimits,
                                    axisScales: $axisScales,
                                    mixSplit: $mixSplit,
                                    logscale: logscale,
                                    transition: transition,
                                    l_min: l_min,
                                    width: graphWidth,
                                    height: graphHeight,
                                    isExporting: false
                                )
                                .contextMenu {
                                    Button {
                                        activeChartSheet = .addGraph
                                    } label: {
                                        Label("Add graph", systemImage: "plus.app")
                                    }

                                    Button {
                                        activeChartSheet = .chartStyle
                                    } label: {
                                        Label("Edit chart style", systemImage: "square.and.pencil")
                                    }

                                    Button {
                                        activeChartSheet = .axisLimits
                                    } label: {
                                        Label("Edit axis limits", systemImage: "slider.horizontal.3")
                                    }
                                    
                                    Button {
                                        requestChartExport()
                                    } label: {
                                        Label("Export chart", systemImage: "square.and.arrow.up")
                                    }
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
                                    
                                    Toggle("Show data", isOn: $showObservedData)
                                        .frame(width: 100, alignment: .center)
                                        .padding()
                                        .font(.system(size: 15))
                                    
                                    Spacer()
                                    
                                    PickerButton(selectedOption: $selectedOption, selectedObservable: $selectedObservable, optionsDictionary: $optionsDictionary, axisData: $axisData)
                                        .frame(alignment: .center)
                                    
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
                        .onAppear(perform: setDefaultAxisSettings)
                        .onAppear(perform: updateObservedData)
                        .onAppear(perform: populateDisplayNames)
                        .onChange(of: selectedModel) {
                            loadMetadata()
                            loadTFLiteInterpreter()
                            setYLimitValues()
                            resetSliders()
                            setDataForGraph()
                            setDefaultAxisSettings()
                            updateObservedData()
                        }
                        .onChange(of: selectedOption) {
                            setYLimitValues()
                            setDataForGraph()
                            setDefaultAxisSettings()
                            updateObservedData()
                        }
                    }
                }
            )
        }
        .alert("Export PDF", isPresented: $showExportDialog) {
            TextField("Filename", text: $exportFileName)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button("Cancel", role: .cancel) {}

            Button("Export") {
                let trimmedName = exportFileName.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                exportFileName = trimmedName.isEmpty ? "chart.pdf" : trimmedName

                Task { @MainActor in
                    await exportChartToFiles()
                }
            }
        } message: {
            Text("Enter a name for the exported PDF.")
        }
        .alert("Export complete", isPresented: $showExportSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            if let url = savedFileURL {
                Text("Saved to:\nFiles ▸ CosmoSlider ▸ \(url.lastPathComponent)")
            }
        }
        .sheet(item: $activeChartSheet) { destination in
            switch destination {
            case .addGraph:
                AddGraphSheet(
                    isOpened: chartSheetPresentedBinding,
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

            case .chartStyle:
                ChartStyleSheet(
                    isOpened: chartSheetPresentedBinding,
                    style: $chartStyle
                )

            case .axisLimits:
                AxisLimitsSheet(
                    isOpened: chartSheetPresentedBinding,
                    axisLimits: $axisLimits,
                    axisScales: $axisScales,
                    mixSplit: $mixSplit
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
    
    
    func setDefaultAxisSettings() {
        mixSplit = 200.0

        let observableKey = observableDictionary[selectedObservable] ?? ""
        let values = (xValues[observableKey] ?? []).filter {
            $0.isFinite
        }
        let positiveValues = values.filter { $0 > 0 }

        var x0 = values.min() ?? 1e-14
        var x1 = values.max() ?? 1.0

        if selectedObservable == "Cl" {
            x0 = 2.0
            x1 = 2500.0
        } else if selectedObservable == "Pk" {
            x0 = positiveValues.min() ?? 1e-6
            x1 = positiveValues.max() ?? 1.0
        }

        if x1 <= x0 {
            x1 = x0 + max(abs(x0) * 0.1, 1e-10)
        }

        let logXSpan: Double
        if x0 > 0 && x1 > 0 {
            logXSpan = abs(log10(x1) - log10(x0))
        } else {
            logXSpan = 0
        }

        let defaultXScale: String
        if x0 > 0 && x0 < mixSplit && mixSplit < x1 {
            defaultXScale = "loglin"
        } else if x0 > 0 && logXSpan > 1 {
            defaultXScale = "log"
        } else {
            defaultXScale = "linear"
        }

        switch selectedObservable {
        case "Cl":
            let yLimits: (Double, Double)

            switch selectedOption {
            case "TT":
                yLimits = (0, 7000)
            case "TE":
                yLimits = (-230, 230)
            case "EE":
                yLimits = (-2, 60)
            case "PP":
                yLimits = (0, 2.5)
            default:
                yLimits = (1, 2)
            }

            axisScales = [defaultXScale, "linear"]
            axisLimits = [x0, x1, yLimits.0, yLimits.1]

        case "Pk":
            axisScales = ["log", "log"]

            // These reproduce the previous log-domain limits of -2...6.
            axisLimits = [x0, x1, 1e-2, 1e6]

        case "bg", "th":
            let low = min(lowestYValue, highestYValue)
            let high = max(lowestYValue, highestYValue)

            let validYRange =
                low.isFinite &&
                high.isFinite &&
                low > 0 &&
                high > low

            let logYSpan: Double
            if validYRange {
                logYSpan = log10(high) - log10(low)
            } else {
                logYSpan = 0
            }

            let useLogY = validYRange && logYSpan >= 1

            if useLogY {
                let padding = max(logYSpan * 0.05, 0.05)

                axisScales = [
                    defaultXScale,
                    "log"
                ]

                axisLimits = [
                    x0,
                    x1,
                    pow(10, log10(low) - padding),
                    pow(10, log10(high) + padding)
                ]
            } else {
                let safeLow = low.isFinite ? low : 0
                let safeHigh = high.isFinite ? high : 1
                let padding = max(
                    max(abs(safeLow), abs(safeHigh)) * 0.05,
                    1e-10
                )
                let span = max(safeHigh - safeLow, padding)

                axisScales = [
                    defaultXScale,
                    "linear"
                ]

                axisLimits = [
                    x0,
                    x1,
                    safeLow - 0.1 * span,
                    safeHigh + 0.2 * span
                ]
            }

        default:
            axisScales = ["linear", "linear"]
            axisLimits = [x0, x1, 0, 1]
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
        
        let pageWidth = max(1, CGFloat(chartStyle.exportWidth))
        let pageHeight = max(1, CGFloat(chartStyle.exportHeight))

        let exportInsets = chartStyle.resolvedExportInsets(
            pageWidth: pageWidth,
            pageHeight: pageHeight
        )

        let contentWidth = max(
            1,
            pageWidth - exportInsets.leading - exportInsets.trailing
        )

        let contentHeight = max(
            1,
            pageHeight - exportInsets.top - exportInsets.bottom
        )

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
                selectedObservable: $selectedObservable,
                selectedOption: $selectedOption,
                xValues: $xValues,
                style: $chartStyle,
                dataDictionary: $storedDataDictionary,
                styleDictionary: $storedChartStyleDictionary,
                graphOrder: $graphOrder,
                lowestYValue: $lowestYValue,
                highestYValue: $highestYValue,
                axisLimits: $axisLimits,
                axisScales: $axisScales,
                mixSplit: $mixSplit,
                logscale: logscale,
                transition: transition,
                l_min: l_min,
                width: contentWidth,
                height: contentHeight,
                isExporting: true
            )

            try ScientificChartView.exportPDF(
                chart: exportView,
                width: pageWidth,
                height: pageHeight,
                url: fileURL
            )

            savedFileURL = fileURL
            showExportSuccessAlert = true
            print("Saved chart to:", fileURL.path)

        } catch {
            print("Export failed:", error)
        }
    }
    
    private var chartSheetPresentedBinding: Binding<Bool> {
        Binding(
            get: { activeChartSheet != nil },
            set: { presented in
                if !presented {
                    activeChartSheet = nil
                }
            }
        )
    }
    
    private func requestChartExport() {
        exportFileName = "chart.pdf"

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            showExportDialog = true
        }
    }
}





#Preview {
    ContentView()
}
