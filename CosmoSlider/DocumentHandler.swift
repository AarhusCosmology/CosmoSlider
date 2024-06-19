//
//  DocumentHandler.swift
//  CMB Emulator
//
//  Created by Andreas Bek Nygaard Hansen on 17/06/2024.
//

import SwiftUI
import Foundation
import UniformTypeIdentifiers
import ZIPFoundation

// hashable struct of file objects with name and url as members
struct FileObject: Hashable {
    var id = UUID()
    var name: String
    var url: URL
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(url)
    }
}


class DocumentHandler: ObservableObject {
    @Published var savedFiles: [FileObject] = []
    
    private let fileManager = FileManager.default

    init() {
        loadSavedFiles()
    }
    
    func loadSavedFiles() {
        let urls = listAllFiles()
        for url in urls {
            savedFiles.append(FileObject(name: urlToName(url: url), url: url))
        }
    }
    
    func urlToName(url: URL) -> String {
        return url.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: ".", with: "")
    }
    
    func handleIncomingURL(url: URL, selectedModel: Binding<String>, showAlert: Binding<Bool>, alertMessage: Binding<String>) {
        print("Received URL: \(url)")
        saveFile(sourceURL: url, selectedModel: selectedModel, showAlert: showAlert, alertMessage: alertMessage)
    }

    func saveFile(sourceURL: URL, selectedModel: Binding<String>, showAlert: Binding<Bool>, alertMessage: Binding<String>) {
        do {
            guard sourceURL.startAccessingSecurityScopedResource() else {
                print("Failed to start accessing security scoped resource")
                return
            }
            defer { sourceURL.stopAccessingSecurityScopedResource() }
            
            // check if the file at the sourceURL is a zip file (arbitrary extension) and if it contains the following files: model.tflite, x_values.txt, output_indices.txt, input_names.txt. the zip file doesn't need to have .zip as extension. try unarchiving it
            
            // Check if the file at the sourceURL is a zip file by reading the first few bytes
            let zipSignature: [UInt8] = [0x50, 0x4B, 0x03, 0x04]
            
            let fileHandle = try FileHandle(forReadingFrom: sourceURL)
            defer { fileHandle.closeFile() }
            let signatureData = try fileHandle.read(upToCount: zipSignature.count)
            
            guard let signature = signatureData, Array(signature) == zipSignature else {
                print("The file is not a valid ZIP archive.")
                alertMessage.wrappedValue = "The file's metadata does not adhere to the expected format."
                showAlert.wrappedValue = true
                return
            }
            
            // check if the zip file contains the required files: model.tflite, x_values.txt, output_indices.txt, input_names.txt
            let containingMetadataFiles = ["model.tflite", "x_values.txt", "output_indices.txt", "input_names.txt"]
            let archive = try Archive(url: sourceURL, accessMode: .read)
            for file in containingMetadataFiles {
                if archive[file] == nil {
                    print("The zip file does not contain the file: \(file)")
                    alertMessage.wrappedValue = "The metadata does not contain the file: \(file)"
                    showAlert.wrappedValue = true
                    return
                }
            }
            
            
            let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            let hiddenDirectoryURL = documentsURL.appendingPathComponent(".InternalFolder")
            
            // Create hidden directory if it doesn't exist
            if !fileManager.fileExists(atPath: hiddenDirectoryURL.path) {
                try fileManager.createDirectory(at: hiddenDirectoryURL, withIntermediateDirectories: true, attributes: nil)
            }
            
            // Prepend a dot to the file name to hide it
            let hiddenFileName = "." + sourceURL.lastPathComponent
            var destinationURL = hiddenDirectoryURL.appendingPathComponent(hiddenFileName)
            
            // Remove any existing file at the destination
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            // Remove existing name from savedFileNames
            if let index = savedFiles.firstIndex(where: { $0.url == destinationURL }) {
                savedFiles.remove(at: index)
            }
            
            
            // Copy the file to the documents directory
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            
            // Exclude the file from iCloud backups and "Recent" tab
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try destinationURL.setResourceValues(resourceValues)
            
            selectedModel.wrappedValue = destinationURL.path
            
            // Add the name to the list of saved names
            savedFiles.append(FileObject(name: urlToName(url: destinationURL), url: destinationURL))
            
            
        } catch {
            print("Error saving file: \(error)")
        }
    }


    func deleteFile(index: Int) {
        let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let privateDirectoryURL = documentDirectory.appendingPathComponent(".InternalFolder")
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: privateDirectoryURL, includingPropertiesForKeys: nil)
            let url = fileURLs[index]
            try fileManager.removeItem(at: url)
            if let index = savedFiles.firstIndex(where: { $0.url == url }) {
                savedFiles.remove(at: index)
            }
            
            print("File deleted: \(url)")
        } catch {
            print("Error deleting file: \(error)")
        }
    }
    
    func deleteFileOnURL(url: URL) {
        do {
            try fileManager.removeItem(at: url)
            
            if let index = savedFiles.firstIndex(where: { $0.url == url }) {
                savedFiles.remove(at: index)
            }
            
            print("File deleted: \(url)")
        } catch {
            print("Error deleting file: \(error)")
        }
    }
    
    func listAllFiles() -> [URL] {
        let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let privateDirectoryURL = documentDirectory.appendingPathComponent(".InternalFolder")

        // Default model URL
        var allURLs = [URL(fileURLWithPath:URL(fileURLWithPath: "default_model.tflite").path)]
        
        do {
            // Ensure the private directory exists before attempting to list its contents
            if !fileManager.fileExists(atPath: privateDirectoryURL.path) {
                return allURLs
            }

            // If directory exists, list its contents
            let fileURLs = try fileManager.contentsOfDirectory(at: privateDirectoryURL, includingPropertiesForKeys: nil)
            allURLs.append(contentsOf: fileURLs)
            return allURLs
            
        } catch {
            print("Error listing files in directory: \(error)")
            return allURLs
        }
    }
    
    func getTemporaryShareableURL(for url: URL) -> URL? {
        let tempDirectory = fileManager.temporaryDirectory
        let tempURL = tempDirectory.appendingPathComponent(url.lastPathComponent.hasPrefix(".") ? String(url.lastPathComponent.dropFirst()) : url.lastPathComponent)
        
        do {
            if fileManager.fileExists(atPath: tempURL.path) {
                try fileManager.removeItem(at: tempURL)
            }
            try fileManager.copyItem(at: url, to: tempURL)
            return tempURL
        } catch {
            print("Error creating temporary shareable file: \(error)")
            return nil
        }
    }
    
    func deleteTemporaryFile(at url: URL) {
        do {
            try fileManager.removeItem(at: url)
        } catch {
            print("Error deleting temporary file: \(error)")
        }
    }
}


struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedModel: String
    @Binding var showAlert: Bool
    @Binding var alertMessage: String
    
    @ObservedObject var documentHandler = DocumentHandler()
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.data])
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    class Coordinator: NSObject, UIDocumentPickerDelegate, UINavigationControllerDelegate {
        var parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            for url in urls {
                if url.pathExtension == "tflite" {
                    parent.documentHandler.saveFile(sourceURL: url, selectedModel: parent.$selectedModel, showAlert: parent.$showAlert, alertMessage: parent.$alertMessage)
                    
                } else {
                    parent.alertMessage = "The selected file must have a .tflite extension."
                    parent.showAlert = true
                }
            }
        }
    }
}

