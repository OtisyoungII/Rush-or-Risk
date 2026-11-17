//
//  ContentView.swift
//  Rush or Risk
//
//  Created by Otis Young on 3/30/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Image("RushorRiskHome")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .accessibilityHidden(true)

                VStack {
                    Spacer()

                    NavigationLink(destination: GameViewControllerWrapper().statusBarHidden(true)) {
                        Text("Start Game")
                            .font(.title.bold())
                            .padding(.horizontal, 34)
                            .padding(.vertical, 16)
                            .background(Color.blue.opacity(0.95))
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white, lineWidth: 2))
                            .shadow(color: .black.opacity(0.7), radius: 12, y: 5)
                    }
                    .accessibilityIdentifier("startGameButton")
                    .padding(.bottom, 54)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}


#Preview {
    ContentView()
}
