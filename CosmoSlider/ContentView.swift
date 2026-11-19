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
    @State public var selectedModel: String = "/default_model.tflite"//"/default_model.tflite"
    @State public var selectedObservable: String = "Cl"
    @State public var selectedOption: String = "TT"
    @State public var optionsDictionary: [String:[String]] = [:]
    @State public var options: [String] = []
    @State public var lowestYValue: Double = 1.0
    @State public var highestYValue: Double = 2.0
    @State public var sliderNames: [String] = []
    @State public var parameterNames: [String] = []
    @State public var sliderConfigs: [(range: (Double, Double), step: Double, precision: String)] = []
    @State public var xValues: [String:[Double]] = [:]
    @State public var outputIndices: [String:(Int,Int)] = [:]
    @State public var sliderValues: [Double] = []
    @State public var bestFitValues: [Double] = []
    @State public var refreshID = UUID()
    @State public var displayNames: [URL:String] = [:]
    @State public var showAlert: Bool = false
    @State public var alertMessage: String = ""
    
    @State private var pkDatasets: [PkObservationDataset] = []
    @State private var selectedRedshift: Double = 0.0
    
    @State private var hiddenGraphKeys: Set<String> = []
    @State private var hiddenPkDatasetKeys: Set<String> = []
    @State private var hiddenCmbObservation: Bool = false

    
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
                            let sliderHeight = max(
                                58,
                                (UIScreen.main.bounds.height * 0.6) / 7 * 0.92
                            )
                            
                            ZStack(alignment: .topLeading) {
                                
                                ScientificChartView(
                                    data: $data,
                                    showObservedData: $showObservedData,
                                    observedData: $observedData,
                                    pkDatasets: $pkDatasets,
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
                                    hiddenGraphKeys: $hiddenGraphKeys,
                                    hiddenPkDatasetKeys: $hiddenPkDatasetKeys,
                                    hiddenCmbObservation: $hiddenCmbObservation,
                                    logscale: logscale,
                                    transition: transition,
                                    l_min: l_min,
                                    width: graphWidth,
                                    height: graphHeight,
                                    isExporting: false,
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
                                        .disabled(!["Cl", "Pk"].contains(selectedObservable))
                                    
                                    Spacer()
                                    
                                    PickerButton(
                                        selectedOption: $selectedOption,
                                        selectedObservable: $selectedObservable,
                                        optionsDictionary: $optionsDictionary,
                                        axisData: $axisData,
                                        selectedRedshift: $selectedRedshift
                                    )
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
                                    if isSliderVisible(at: index) {
                                        let config = sliderConfigs[index]
                                        let range = config.range
                                        let step = config.step
                                        let precision = config.precision

                                        if range.0 < range.1 {
                                            VStack(spacing: 3) {
                                                Slider(
                                                    value: $sliderValues[index],
                                                    in: range.0...range.1,
                                                    step: step
                                                )

                                                HStack {
                                                    let fileURL = URL(fileURLWithPath: name)

                                                    SVGImage(url: fileURL)
                                                        .frame(
                                                            width: 230,
                                                            height: 23,
                                                            alignment: .bottomLeading
                                                        )

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
                                            Text("Invalid range for Slider \(index + 1)")
                                                .foregroundColor(.red)
                                        }
                                    }
                                }
                                .id(refreshID)
                                .padding(.horizontal)
                                .padding(.vertical, 4)
                                if selectedObservable == "Pk" {
                                    let slices = pkOutputSlices(
                                        family: selectedOption,
                                        outputIndices: outputIndices
                                    )

                                    if let first = slices.first,
                                    let last = slices.last,
                                        first.redshift < last.redshift {

                                        VStack(spacing: 0) {
                                            Slider(
                                                value: $selectedRedshift,
                                                in: first.redshift...last.redshift,
                                                step: 0.1
                                            )
                                            .onChange(of: selectedRedshift) {
                                                setDataForGraph()
                                            }

                                            HStack {
                                                Image("z_slider")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 230, height: 23, alignment: .bottomLeading)

                                                Spacer()

                                                Text(
                                                    selectedRedshift,
                                                    format: .number.precision(.fractionLength(1))
                                                )
                                                .font(.system(size: 15))
                                            }
                                        }
                                        .padding(.horizontal)
                                        .padding(.bottom, 12)
                                    }
                                }
                            }
                            
                        }
                        .environmentObject(documentHandler)
                        .onOpenURL { url in
                            documentHandler.handleIncomingURL(url: url, selectedModel: $selectedModel, showAlert: $showAlert, alertMessage: $alertMessage)
                        }
                        .onAppear(perform: loadMetadata)
                        .onAppear(perform: loadTFLiteInterpreter)
                        .onAppear(perform: loadPkDatasets)
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
                        .onChange(of: selectedChartSelectionKey) {
                            refreshSelectedChartSelection()
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
                    parameterNames: $parameterNames,
                    selectedRedshift: $selectedRedshift,
                    xArrayDictionary: $xValues,
                    interpreter: $interpreter,
                    outputIndices: $outputIndices
                )

            case .chartStyle:
                ChartStyleSheet(
                    isOpened: chartSheetPresentedBinding,
                    style: $chartStyle,
                    selectedObservable: $selectedObservable
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
    
    private var selectedChartSelectionKey: String {
        "\(selectedObservable)|\(selectedOption)"
    }
    
    private func refreshSelectedChartSelection() {

        // Avoid animating the chart's data and axis changes.
        var transaction = Transaction()
        transaction.disablesAnimations = true

        withTransaction(transaction) {

            // Observational data is only available for Cl and Pk.
            if !["Cl", "Pk"].contains(selectedObservable) {
                showObservedData = false
            }

            // Keep the selected redshift valid for the chosen Pk family.
            clampSelectedRedshiftToFamily()

            // Update the y-axis reference values first.
            setYLimitValues()

            // Recalculate all default axis settings for the new selection.
            setDefaultAxisSettings()

            // Refresh observational data and the theoretical curve.
            updateObservedData()
            setDataForGraph()
        }
    }
    
    private func enforceBestFitValuesForHiddenSliders() {
        for index in sliderValues.indices {
            guard bestFitValues.indices.contains(index) else {
                continue
            }

            if !isSliderVisible(at: index) {
                sliderValues[index] = bestFitValues[index]
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
            let gridMin = positiveValues.min() ?? 1e-6
            let gridMax = positiveValues.max() ?? 1.0

            x0 = gridMin

            // Calculate the 2% extrapolated maximum in log-k space.
            let logGridSpan: Double

            if gridMax > gridMin {
                logGridSpan = log10(gridMax) - log10(gridMin)
            } else {
                logGridSpan = 1.0
            }

            x1 = pow(
                10.0,
                log10(gridMax) +
                modelGridExtrapolationFraction * logGridSpan
            )
        } else if ["bg", "th"].contains(selectedObservable) {
            // These observables use logarithmic x-axes.
            x0 = positiveValues.min() ?? 1e-6
            x1 = positiveValues.max() ?? max(x0 * 10, 1.0)
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

        if ["bg", "th"].contains(selectedObservable) {
            defaultXScale = "log"

        } else if x0 > 0 && x0 < mixSplit && mixSplit < x1 {
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

            let low = lowestYValue
            let high = max(highestYValue, low * 1.000001)

            let logYSpan = log10(high) - log10(low)
            let padding = max(logYSpan * 0.05, 0.05)

            axisScales = ["log", "log"]

            axisLimits = [
                x0,
                x1,
                pow(10, log10(low) - padding),
                pow(10, log10(high) + padding)
            ]

        default:
            axisScales = ["linear", "linear"]
            axisLimits = [x0, x1, 0, 1]
        }
    }

    func setDataForGraph() {
        enforceBestFitValuesForHiddenSliders()
        
        guard let modelInterpreter = interpreter else {
            data = []
            return
        }

        data = updateGraphData(
            observable: selectedObservable,
            option: selectedOption,
            parameters: sliderValues,
            xArrayDictionary: xValues,
            outputIndices: outputIndices,
            interpreter: modelInterpreter,
            parameterNames: parameterNames,
            redshift: selectedRedshift
        )
    }
    
    func setYLimitValues() {
        let bestFitGraph = updateGraphData(
            observable: selectedObservable,
            option: selectedOption,
            parameters: bestFitValues,
            xArrayDictionary: xValues,
            outputIndices: outputIndices,
            interpreter: interpreter!
        )

        let finiteYValues = bestFitGraph
            .map(\.yValue)
            .filter { $0.isFinite }

        if ["bg", "th"].contains(selectedObservable) {
            // Logarithmic y-axis: ignore zero and negative values.
            let positiveYValues = finiteYValues.filter { $0 > 0 }

            if let minimum = positiveYValues.min(),
               let maximum = positiveYValues.max() {
                lowestYValue = minimum
                highestYValue = maximum > minimum
                    ? maximum
                    : minimum * 10
            } else {
                // Safe fallback if no positive model outputs exist.
                lowestYValue = 1
                highestYValue = 10
            }

        } else {
            lowestYValue = finiteYValues.min() ?? 1
            highestYValue = finiteYValues.max() ?? 2
        }
    }

    func updateObservedData() {
        guard selectedObservable == "Cl" else {
            observedData = []
            return
        }

        let fileName: String
        var xValIndex = 0
        var yValIndex = 1
        var errNegIndex = 2
        var errPosIndex = 3

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

        observedData = readDataFromFile(
            fileName: fileName,
            xValIndex: xValIndex,
            yValIndex: yValIndex,
            errNegIndex: errNegIndex,
            errPosIndex: errPosIndex
        )
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
        // Apply hardcoded slider range overrides.
        applyHardcodedSliderLimits()

        // Reset all parameters to their best-fit values.
        sliderValues = []

        for (index, config) in sliderConfigs.enumerated() {
            let precision = config.precision
            let bestFitValue = bestFitValues[index]

            // Keep ln(10^10 A_s) inside the hardcoded range.
            let value: Double

            if isLn10AsParameter(at: index) {
                value = min(max(bestFitValue, 2.0), 4.0)
            } else {
                value = bestFitValue
            }

            let roundedValue = Double(
                String(format: precision, value)
            ) ?? value

            sliderValues.append(roundedValue)
        }

        // Hidden parameters must use their exact best-fit values.
        enforceBestFitValuesForHiddenSliders()

        // Reset redshift to zero whenever resetting Pk.
        if selectedObservable == "Pk" {
            selectedRedshift = 0.0
        }

        // Recalculate the chart.
        setDataForGraph()
    }
    
    private func normalizedParameterName(at index: Int) -> String {
        let name: String

        if parameterNames.indices.contains(index) {
            name = parameterNames[index]
        } else if sliderNames.indices.contains(index) {
            name = URL(fileURLWithPath: sliderNames[index])
                .deletingPathExtension()
                .lastPathComponent
        } else {
            return ""
        }

        return name.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private func isTauReioParameter(at index: Int) -> Bool {
        normalizedParameterName(at: index) == "taureio"
    }

    private func isCMinOrEta0Parameter(at index: Int) -> Bool {
        let name = normalizedParameterName(at: index)
        return name == "cmin" || name == "eta0"
    }

    private func isLn10AsParameter(at index: Int) -> Bool {
        normalizedParameterName(at: index).contains("ln1010as")
    }

    private func isSliderVisible(at index: Int) -> Bool {
        if isTauReioParameter(at: index) {
            return selectedObservable != "Pk"
        }

        if isCMinOrEta0Parameter(at: index) {
            return selectedObservable == "Pk"
        }

        return true
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
                pkDatasets: $pkDatasets,
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
                hiddenGraphKeys: $hiddenGraphKeys,
                hiddenPkDatasetKeys: $hiddenPkDatasetKeys,
                hiddenCmbObservation: $hiddenCmbObservation,
                logscale: logscale,
                transition: transition,
                l_min: l_min,
                width: contentWidth,
                height: contentHeight,
                isExporting: true,
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
    
    private func applyHardcodedSliderLimits() {
        for index in sliderConfigs.indices {
            guard isLn10AsParameter(at: index) else {
                continue
            }

            let config = sliderConfigs[index]

            sliderConfigs[index] = (
                range: (2.0, 4.0),
                step: config.step,
                precision: config.precision
            )
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
    
    func loadPkDatasets() {
        guard let url = Bundle.main.url(
            forResource: "pk_data",
            withExtension: "json"
        ) else {
            print("pk_data.json was not found in the app bundle.")
            pkDatasets = []
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(
                PkCompilationData.self,
                from: data
            )
            pkDatasets = decoded.datasets
        } catch {
            print("Failed to decode pk_data.json:", error)
            pkDatasets = []
        }
    }
    
    func hRangeForPkUnits() -> (min: Double, max: Double) {
        let aliases = ["h", "h0", "hubble", "hubbleconstant"]

        guard let index = parameterNames.firstIndex(where: { name in
            let normalized = name
                .lowercased()
                .filter { $0.isLetter || $0.isNumber }

            return aliases.contains(normalized)
        }),
        sliderConfigs.indices.contains(index) else {
            return (0.677, 0.677)
        }

        let name = parameterNames[index]
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }

        let conversion = name == "h" ? 1.0 : 0.01
        let range = sliderConfigs[index].range

        let first = range.0 * conversion
        let second = range.1 * conversion

        guard first.isFinite, second.isFinite,
              first > 0, second > 0 else {
            return (0.677, 0.677)
        }

        return (
            min: min(first, second),
            max: max(first, second)
        )
    }
    
    func clampSelectedRedshiftToFamily() {
        guard selectedObservable == "Pk" else {
            return
        }

        let slices = pkOutputSlices(
            family: selectedOption,
            outputIndices: outputIndices
        )

        guard let first = slices.first,
              let last = slices.last else {
            return
        }

        let requested = selectedRedshift.isFinite
            ? selectedRedshift
            : first.redshift

        selectedRedshift = min(
            max(requested, first.redshift),
            last.redshift
        )
    }
}





#Preview {
    ContentView()
}
