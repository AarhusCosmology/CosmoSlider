//
//  SideMenu.swift
//  CMB Emulator
//
//  Created by Andreas Bek Nygaard Hansen on 17/06/2024.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers
import TensorFlowLite


public struct Drawer<Menu: View, Content: View>: View {
    @Binding private var isOpened: Bool
    private let menu: Menu
    private let content: Content

    // MARK: - Init
    public init(
        isOpened: Binding<Bool>,
        @ViewBuilder menu:  () -> Menu,
        @ViewBuilder content: () -> Content
    ) {
        _isOpened = isOpened
        self.menu = menu()
        self.content = content()
    }

    // MARK: - Body
    public var body: some View {
        ZStack(alignment: .leading) {
            content

            if isOpened {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if isOpened {
                            isOpened.toggle()
                        }
                    }
                menu
                    .transition(.move(edge: .leading))
                    .zIndex(1)
            }
        }
        .animation(.spring(), value: isOpened)
    }
}



struct LiteratureView: View {
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Literature")
                    .font(.largeTitle)
                    .bold()
                    .padding(.top, 20)

                Divider()
                
                ScrollView {
                    Text("CMB")
                        .font(.title2)
                        .bold()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("Below are some useful links for learning the physics behind the CMB spectrum:")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer()
                    Link("Wayne Hu: Guide to the Acoustic Peaks and Polarization", destination: URL(string: "http://background.uchicago.edu/~whu/intermediate/intermediate.html")!)
                    Spacer()
                    Link("Gawiser and Silk: The Cosmic Microwave Background Radiation", destination: URL(string: "https://ned.ipac.caltech.edu/level5/Sept05/Gawiser2/Gawiser_contents.html")!)
                    
                    Divider()
                    
                    Text("Emulation")
                        .font(.title2)
                        .bold()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Below are the links to the CONNECT papers describing the emulation framework and its features:")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer()
                    Link("CONNECT: A neural network based framework for emulating cosmological observables and cosmological parameter inference", destination: URL(string: "https://arxiv.org/abs/2205.15726")!)
                    Spacer()
                    Link("Fast and effortless computation of profile likelihoods using CONNECT", destination: URL(string: "https://arxiv.org/abs/2308.06379")!)
                    Spacer()
                    Link("Cutting corners: Hypersphere sampling as a new standard for cosmological emulators", destination: URL(string: "https://arxiv.org/abs/2405.01396")!)
                }
                
                
                Spacer()
            }
            .padding()
        }
    }
}


struct CreditsView: View {
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Credits")
                    .font(.largeTitle)
                    .bold()
                    .padding(.top, 20)

                Divider()
                
                Text("Developers")
                    .font(.title2)
                    .bold()
                
                HStack {
                    Image(systemName: "person.crop.circle")
                        .resizable()
                        .frame(width: 50, height: 50)
                    VStack(alignment: .leading) {
                        Text("Andreas Nygaard")
                            .font(.headline)
                        Text("Developer")
                            .font(.subheadline)
                    }
                }

                Divider()

                Text("Association")
                    .font(.title2)
                    .bold()

                Text("This application was developed at Aarhus University, Denmark, utilizing the CONNECT framework for emulation as a cornerstone of its design. The development was supported by research grant no. 29337 from VILLUM FONDEN.")

                Spacer()
            }
            .padding()
        }
    }
}

struct SelectView: View {
    
    @Binding var selectedModel: String
    @Binding var showingSelectSheet: Bool
    @Binding var displayNames: [URL: String]
    
    @State private var fileToShare: IdentifiableURL?
    @State private var settingsDetent = PresentationDetent.medium
    @State private var showRenameAlert: Bool = false
    @State private var newName: String = ""
    @State private var renameURL: URL?
    
    @ObservedObject var documentHandler = DocumentHandler()
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Select model")
                    .font(.largeTitle)
                    .bold()
                    .padding(.top, 20)
                
                Divider()
                
                List {
                    ForEach(documentHandler.savedFiles, id: \.id) { item in
                        Button {
                            selectedModel = item.url.path
                            showingSelectSheet.toggle()
                        } label: {
                            HStack {
                                let displayText = displayNames[item.url] ?? item.name
                                Text(displayText)
                                Spacer()
                                if item.url.lastPathComponent == URL(fileURLWithPath: selectedModel).lastPathComponent {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .contentShape(Rectangle())
                        .deleteDisabled(item.name == "default model")
                        .swipeActions(edge: .leading, allowsFullSwipe: true, content: {
                            if item.name != "default model" {
                                Button {
                                    shareFile(url: item.url)
                                } label: {
                                    Image(systemName: "square.and.arrow.up")
                                }
                                .tint(.orange)
                            }
                        })
                        .environmentObject(documentHandler)
                        .contextMenu {
                            if item.name != "default model" {
                                Button(action: {
                                    renameURL = item.url
                                    newName = displayNames[item.url] ?? item.name
                                    showRenameAlert.toggle()
                                }) {
                                    Label("Rename", systemImage: "pencil")
                                }
                                Button(action: {
                                    shareFile(url: item.url)
                                }) {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                }
                                Button(role: .destructive) {
                                    if item.url.lastPathComponent == URL(fileURLWithPath: selectedModel).lastPathComponent {
                                        selectedModel = "/default_model.tflite"
                                    }
                                    documentHandler.deleteFileOnURL(url: item.url)
                                } label: {
                                    HStack {
                                        Text("Delete")
                                        Spacer()
                                        Image(systemName: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .onDelete(perform: { indexSet in
                        for index in indexSet {
                            let fileList = documentHandler.listAllFiles()
                            if fileList[index].lastPathComponent == URL(fileURLWithPath: selectedModel).lastPathComponent {
                                selectedModel = "/default_model.tflite"
                            }
                            documentHandler.deleteFile(index: index-1)
                            displayNames.removeValue(forKey: fileList[index])
                            saveDictionaryToUserDefaults(displayNames, key: "displayNames")
                        }
                    })
                }
                
                Spacer()
            }
            .padding()
            .sheet(item: $fileToShare, onDismiss: {
                if let tempURL = fileToShare?.url {
                    documentHandler.deleteTemporaryFile(at: tempURL)
                }
                fileToShare = nil
            }) { fileToShare in
                ShareSheet(activityItems: [fileToShare.url])
                    .presentationDetents(
                        [.medium, .large],
                        selection: $settingsDetent
                    )
            }
            .alert("Rename Model", isPresented: $showRenameAlert, actions: {
                TextField("Enter new name", text: $newName)
                Button("OK", action: renameModel)
                Button("Cancel", role: .cancel) { }
            }, message: {
                Text("Enter a new name for the model.")
            })
        }
    }
    
    func renameModel() {
        if let renameURL = renameURL {
            displayNames[renameURL] = newName
        }
        saveDictionaryToUserDefaults(displayNames, key: "displayNames")
        showRenameAlert = false
    }
    
    func saveDictionaryToUserDefaults(_ dictionary: [URL: String], key: String) {
        let stringKeyedDictionary = dictionary.reduce(into: [String: String]()) { result, pair in
            result[pair.key.path] = pair.value
        }
        UserDefaults.standard.set(stringKeyedDictionary, forKey: key)
    }
    
    private func shareFile(url: URL) {
        if let tempURL = documentHandler.getTemporaryShareableURL(for: url) {
            DispatchQueue.main.async {
                self.fileToShare = IdentifiableURL(url: tempURL)
            }
        } else {
            print("Failed to create temporary file for sharing.")
        }
    }
    
    private struct Document: FileDocument {
        static var readableContentTypes: [UTType] { [.data] }
        
        var fileURL: URL
        
        init(fileURL: URL) {
            self.fileURL = fileURL
        }
        
        init(configuration: ReadConfiguration) throws {
            fatalError("init(configuration:) has not been implemented")
        }
        
        func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
            let data = try Data(contentsOf: fileURL)
            return FileWrapper(regularFileWithContents: data)
        }
    }
}



struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}


// Here is a struct called HelpView which displays info about using the app
struct HelpView: View {
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Help")
                    .font(.largeTitle)
                    .bold()
                    .padding(.top, 20)

                Divider()
                ScrollView {
                    Text("This app allows you to visualize the CMB power spectrum for different cosmological models. The cosmological parameters can be adjusted using the sliders and the graph will then update in real-time. You can import a new model from the menu and also choose between your imported models.")
                    
                    Divider()
                    
                    Text("Above the graph are a few visualisation options. The \"Show data\" button toggles the visibility of Planck 2018 data for the TT, TE, and EE spectra and SPT data for the 𝜑𝜑 spectrum. Next to this is a button for choosing the plotted spectrum. The last button resets the position of the sliders to the best-fit point determined by an optimisation using the Planck Lite likelihood.")
                    
                    Divider()
                    
                    Text("NB: The displayed spectra rely on neural networks trained on specific data sets representing the cosmological models. The default ΛCDM model is trained on a Latin hypercube and the behaviour should therefore be reasonable within the entire parameter space. Custom loaded models might, however, not necessarily be as reliable in all regions of the parameter space.")
                }
                
                Spacer()
            }
            .padding()
        }
    }
}


struct ChartStyleSheet: View {
    @Binding var isOpened: Bool
    @Binding var style: ChartStyle

    var body: some View {
        NavigationView {
            Form {
                // MARK: - Export size
                Section(header: Text("Export Size")) {
                    HStack {
                        Text("Width")
                        Spacer()
                        TextField("", value: $style.exportWidth, format: .number)
                            .keyboardType(.numberPad)
                            .frame(width: 100)
                    }
                    
                    HStack {
                        Text("Height")
                        Spacer()
                        TextField("", value: $style.exportHeight, format: .number)
                            .keyboardType(.numberPad)
                            .frame(width: 100)
                    }
                }
                
                // MARK: - Line plot
                Section(header: Text("Line Plot")) {
                    ColorPicker("Color", selection: $style.lineColor)
                    
                    HStack {
                        Text("Opacity")
                        Slider(value: $style.lineOpacity, in: 0...1)
                        Text(style.lineOpacity, format: .number.precision(.fractionLength(2)))
                            .frame(width: 40)
                    }
                    
                    HStack {
                        Text("Line Width")
                        Slider(value: $style.lineWidth, in: 0.5...6)
                        Text(style.lineWidth, format: .number.precision(.fractionLength(1)))
                            .frame(width: 40)
                    }
                }
                
                // MARK: - Error bars
                Section(header: Text("Error Bars")) {
                    ColorPicker("Color", selection: $style.errorBarColor)
                    
                    HStack {
                        Text("Opacity")
                        Slider(value: $style.errorBarOpacity, in: 0...1)
                        Text(style.errorBarOpacity, format: .number.precision(.fractionLength(2)))
                            .frame(width: 40)
                    }
                    
                    HStack {
                        Text("Marker Size")
                        Slider(value: $style.errorBarMarkerSize, in: 1.0...5.0)
                        Text(style.errorBarMarkerSize, format: .number.precision(.fractionLength(1)))
                            .frame(width: 40)
                    }
                    
                    HStack {
                        Text("Cap Size")
                        Slider(value: $style.errorBarCapSize, in: 0.5...4.0)
                        Text(style.errorBarCapSize, format: .number.precision(.fractionLength(1)))
                            .frame(width: 40)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Style")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        isOpened.toggle()
                    } label: {
                        Image(systemName: "arrow.left.circle.fill")
                            .font(.system(size: 24))
                    }
                }
            }
            .toolbarBackground(Color(.systemGroupedBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

struct AddGraphSheet: View {
    @Binding var isOpened: Bool
    @Binding var data: [GraphData]
    @Binding var style: ChartStyle
    @Binding var dataDictionary: [String: [String: [String: [GraphData]]]]
    @Binding var styleDictionary: [String: ChartStyle]
    @Binding var graphOrder: [String]
    @Binding var optionsDictionary: [String: [String]]
    @Binding var parameters: [Double]
    @Binding var xArrayDictionary: [String: [Double]]
    @Binding var interpreter: Interpreter?
    @Binding var outputIndices: [String: (Int, Int)]
    
    @State var legendLabel: String = ""
    @State private var editLabel: String = ""
    @State private var showingEditAlert = false
    @State private var selectedKey: String? = nil
    @State private var showDuplicateLegendAlert = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Lock current graph in chart")) {
                    HStack {
                        Text("Legend label")
                        Spacer()
                        TextField("Enter label", text: $legendLabel)
                            .frame(width: 150)
                    }
                    
                    Button(action: addGraph) {
                        Text("Add graph")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .foregroundColor(.red)
                    }
                }
                
                Section(header: Text("Saved Graphs")) {
                    List {
                        ForEach(graphOrder, id: \.self) { key in
                            Text(key)
                                .contextMenu {
                                    Button("Edit") {
                                        selectedKey = key
                                        editLabel = key
                                        showingEditAlert = true
                                    }
                                    Button("Delete", role: .destructive) {
                                        deleteGraph(key: key)
                                    }
                                }
                        }
                        .onDelete { indexSet in
                            indexSet.forEach { index in
                                let key = dataDictionary.keys.sorted()[index]
                                deleteGraph(key: key)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Style")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        isOpened.toggle()
                    } label: {
                        Image(systemName: "arrow.left.circle.fill")
                            .font(.system(size: 24))
                    }
                }
            }
            .toolbarBackground(Color(.systemGroupedBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .alert("Edit Label", isPresented: $showingEditAlert, actions: {
                TextField("Label", text: $editLabel)
                Button("Save") {
                    if let key = selectedKey, !editLabel.isEmpty {
                        editGraphLabel(oldKey: key, newKey: editLabel)
                    }
                }
                Button("Cancel", role: .cancel) { }
            })
            .alert("Duplicate Legend Label",
                   isPresented: $showDuplicateLegendAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Each graph must have a unique legend label.")
            }
        }
    }
    
    func addGraph() {
        guard !legendLabel.isEmpty else { return }

        if graphOrder.contains(legendLabel) {
            showDuplicateLegendAlert = true
            return
        }

        dataDictionary[legendLabel] = [:]

        for observable in optionsDictionary.keys.sorted() {
            dataDictionary[legendLabel]?[observable] = [:]

            for option in (optionsDictionary[observable] ?? []).sorted() {
                dataDictionary[legendLabel]?[observable]?[option] =
                    updateGraphData(
                        observable: observable,
                        option: option,
                        parameters: parameters,
                        xArrayDictionary: xArrayDictionary,
                        outputIndices: outputIndices,
                        interpreter: interpreter!
                    )
            }
        }


        styleDictionary[legendLabel] = style
        graphOrder.append(legendLabel)
        legendLabel = ""
    }

    
    func deleteGraph(key: String) {
        dataDictionary.removeValue(forKey: key)
        styleDictionary.removeValue(forKey: key)
        if let index = graphOrder.firstIndex(of: key) {
            graphOrder.remove(at: index)
        }
    }
    
    func editGraphLabel(oldKey: String, newKey: String) {
        guard oldKey != newKey else { return }
        guard !graphOrder.contains(newKey) else {
            showDuplicateLegendAlert = true
            return
        }
        guard
            let graphData = dataDictionary.removeValue(forKey: oldKey),
            let chartStyle = styleDictionary.removeValue(forKey: oldKey),
            let index = graphOrder.firstIndex(of: oldKey)
        else {
            return
        }
        dataDictionary[newKey] = graphData
        styleDictionary[newKey] = chartStyle
        graphOrder[index] = newKey
    }
}



struct ExportNameAlert: View {
    @Binding var isPresented: Bool
    @Binding var fileName: String
    let onExport: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            // Dimmed background (system-like)
            Color.black.opacity(colorScheme == .dark ? 0.5 : 0.2)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }

            VStack(spacing: 0) {
                // MARK: - Title + text field
                VStack(spacing: 12) {
                    Text("Export PDF")
                        .font(.headline)
                        .padding(.top, 16)

                    TextField("chart.pdf", text: $fileName)
                        .textFieldStyle(.roundedBorder)
                        .focused($isFocused)
                        .padding(.horizontal, 16)
                }
                .padding(.bottom, 16)

                Divider()

                // MARK: - Buttons
                HStack(spacing: 0) {
                    Button {
                        isPresented = false
                    } label: {
                        Text("Cancel")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .foregroundColor(.red)
                    }

                    Divider()

                    Button {
                        onExport()
                        isPresented = false
                    } label: {
                        Text("Export")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .bold()
                    }
                }
                .frame(height: 44)
            }
            .frame(width: 270)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color(white: colorScheme == .dark ? 0.13 : 0.94))
            )
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = true
            }
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: isPresented)
    }
}


