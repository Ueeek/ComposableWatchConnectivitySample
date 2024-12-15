//
//  ContentView.swift
//  WatchConnectivitySample Watch App
//
//  Created by KoichiroUeki on 2024/12/15.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        MainView(
            store: .init(
                initialState: .init(),
                reducer: { MainReducer() }
            )
        )
        .padding()
    }
}

#Preview {
    ContentView()
}
