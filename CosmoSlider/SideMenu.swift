//
//  SideMenu.swift
//  CMB Emulator
//
//  Created by Andreas Bek Nygaard Hansen on 17/06/2024.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers


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
                
                Text("This app allows you to visualize the CMB power spectrum for different cosmological models. The cosmological parameters can be adjusted using the sliders and the graph will then update in real-time. You can import a new model from the menu and also choose between your imported models.")
                
                Divider()
                
                Text("Above the graph are a few visualisation options. The \"Show data\" button toggles the visibility of Planck 2018 data for the TT, TE, and EE spectra and SPT data for the 𝜑𝜑 spectrum. Next to this is a button for choosing the plotted spectrum. The last button resets the position of the sliders to the best-fit point determined by an optimisation using the Planck Lite likelihood.")
                
                Spacer()
            }
            .padding()
        }
    }
}
