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
    @Binding var options: [String]
    @State private var isPickerPresented = false
    
    var listOfButtons: [ActionSheet.Button] {
        var buttons: [ActionSheet.Button] = []
        for option in options {
            if option == "PP" {
                buttons.append(.default(Text("𝜑𝜑")) { selectedOption = "PP" })
            } else {
                buttons.append(.default(Text(option)) { selectedOption = option })
            }
        }
        buttons.append(.cancel())
        return buttons
    }
    
    var body: some View {
        
        Button(action: {
            isPickerPresented.toggle()
        }) {
            HStack {
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 20))
                    .frame(width: 20, height: 20)
                if selectedOption == "PP" {
                    Text("𝜑𝜑")
                        .font(.system(size: 20))
                } else {
                    Text(selectedOption)
                        .font(.system(size: 20))
                }
            }
        }
        .actionSheet(isPresented: $isPickerPresented) {
            ActionSheet(title: Text("Select spectrum"), buttons: listOfButtons)
        }
    }
}
