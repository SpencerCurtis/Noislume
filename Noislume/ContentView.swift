//
//  ContentView.swift
//  Noislume
//
//  Created by Spencer Curtis on 4/28/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        InversionView()
            #if os(macOS)
            .frame(minWidth: 800, minHeight: 600)
            #endif
    }
}

#Preview {
    ContentView()
}
