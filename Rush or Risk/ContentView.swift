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
                    .ignoresSafeArea(.all)

                VStack {
//                    Image("Bomb")
//                        .resizable()
//                        .ignoresSafeArea(.all)
//                        .frame(width: 50, height: 40)
//                        .shadow(color: .white, radius: 20)
//                        .padding()
//                        .padding()

                    Divider()
                    Divider()
                    Divider()
                    Divider()
                    Divider()
                    Divider()
                    Divider()

                    NavigationLink(destination: GameViewControllerWrapper()) {
                        Text("Start Game")
                            .font(.title)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .shadow(color: .white, radius: 20)
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}

#Preview {
    ContentView()
}
