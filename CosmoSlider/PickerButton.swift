//
//  PickerButton.swift
//  CMB Emulator
//
//  Created by Andreas Bek Nygaard Hansen on 17/06/2024.
//

import Foundation
import SwiftUI


struct PickerButton: View {
    @Binding var selectedOption: String
    @Binding var selectedObservable: String
    @Binding var optionsDictionary: [String: [String]]

    let labelDictionary: [String: String] = [
        "Cl" : "CMB power spectra",
        "Pk" : "Matter power spectra",
        "bg" : "Background",
        "th" : "Thermodynamics",
        "extra" : "Additional",
    ]
        
    var body: some View {
        Menu {
            if let options = optionsDictionary[selectedObservable] {
                ForEach(options, id: \.self) { option in
                    Button {
                        selectedOption = option
                    } label: {
                        HStack {
                            Text(option == "PP" ? "𝜑𝜑" : option)
                            if option == selectedOption {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            Divider()

            if optionsDictionary.keys.count > 1 {
                Menu("Change Observable…") {
                    ForEach(optionsDictionary.keys.sorted(), id: \.self) { key in
                        Button {
                            selectedObservable = key
                            if let firstOption = optionsDictionary[key]?.first {
                                selectedOption = firstOption
                            }
                        } label: {
                            HStack {
                                Text(labelDictionary[key] ?? key)
                                if key == selectedObservable {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            } else {
                // Disabled / informational label
                Button("Change Observable…") { }
                    .disabled(true)
            }
        } label: {
            HStack {
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 20))
                if ["bg", "th"].contains(selectedObservable) {
                    Text(selectedObservable)
                        .font(.system(size: 20))
                        .bold()
                } else if selectedOption.contains("pk") {
                    let redshift = selectedOption.split(separator: "_").last!
                    let name = selectedOption.split(separator: "_").dropLast().joined(separator: "_")
                    VStack(alignment: .center) {
                        Text(name)
                            .font(.system(size: 18))
                            .bold()
                        Text("z = \(redshift)")
                            .font(.system(size: 14))
                    }
                } else {
                    Text(selectedOption == "PP" ? "𝜑𝜑" : selectedOption)
                        .font(.system(size: 20))
                        .bold()
                }
            }
        }
    }
}

