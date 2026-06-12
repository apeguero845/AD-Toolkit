//
//  ContentView.swift
//  AD Toolkit
//
//  Main tabbed interface for AD operations.
//

import SwiftUI

struct ContentView: View {
    @Binding var selectedTab: Int

    var body: some View {
        TabView(selection: $selectedTab) {
            PasswordChangeView()
                .tabItem {
                    Image(systemName: "key.fill")
                    Text("Cambiar Contraseña")
                }
                .tag(0)

            DomainJoinView()
                .tabItem {
                    Image(systemName: "rectangle.connected.to.line.below.fill")
                    Text("Unir al Dominio")
                }
                .tag(1)

            DiagnosticsView()
                .tabItem {
                    Image(systemName: "stethoscope")
                    Text("Diagnóstico")
                }
                .tag(2)
        }
        .padding()
    }
}

#Preview {
    ContentView(selectedTab: .constant(0))
}
