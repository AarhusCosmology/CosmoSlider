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
    @Binding var axisData: [GraphData]
    @Binding var selectedRedshift: Double

    private let labelDictionary: [String: String] = [
        "Cl": "CMB power spectra",
        "Pk": "Matter power spectra",
        "bg": "Background",
        "th": "Thermodynamics",
        "extra": "Additional"
    ]

    private func displayOption(_ option: String) -> String {
        guard selectedObservable == "Pk" else {
            return option == "PP" ? "𝜑𝜑" : option
        }

        switch option.lowercased() {
        case "pk":
            return "Non-linear"
        case "pk_cb":
            return "Non-linear (cb)"
        case "pk_lin":
            return "Linear"
        case "pk_cb_lin":
            return "Linear (cb)"
        default:
            return option
        }
    }

    var body: some View {
        Menu {
            if let availableOptions = optionsDictionary[selectedObservable] {
                ForEach(availableOptions, id: \.self) { option in
                    Button {
                        selectedOption = option
                    } label: {
                        HStack {
                            Text(displayOption(option))

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
                    ForEach(
                        optionsDictionary.keys.sorted(),
                        id: \.self
                    ) { key in
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
                Button("Change Observable…") {}
                    .disabled(true)
            }
        } label: {
            HStack {
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 20))

                if selectedObservable == "Pk" {
                    Text(pkFamilyDisplayName(selectedOption))
                            .font(.system(size: 16))
                            .bold()
                } else if ["bg", "th"].contains(selectedObservable) {
                    Text(selectedObservable.uppercased())
                        .font(.system(size: 16))
                        .bold()
                } else {
                    Text(displayOption(selectedOption))
                        .font(.system(size: 16))
                        .bold()
                }
            }
        }
    }
    
    private func pkFamilyDisplayName(_ family: String) -> String {
        switch family {
        case "pk":
            return "Non-linear"
        case "pk_cb":
            return "Non-linear (cb)"
        case "pk_lin":
            return "Linear"
        case "pk_cb_lin":
            return "Linear (cb)"
        default:
            return family
        }
    }
}

