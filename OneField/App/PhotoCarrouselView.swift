//
//  PhotoCarrouselView.swift
//  OneField
//
//  Created by Danna Valencia on 11/10/25.
//

import SwiftUI

struct PhotoCarouselView: View {
    let images: [String]
    @State private var selectedIndex = 0

    var body: some View {
        VStack(spacing: 12) {
            TabView(selection: $selectedIndex) {
                ForEach(images.indices, id: \.self) { index in
                    Image(images[index])
                        .resizable()
                        .scaledToFill()
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .tag(index)
                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                        .padding(.horizontal, 16)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .frame(height: 240)
            .animation(.easeInOut, value: selectedIndex)
        }
    }
}

#Preview {
    PhotoCarouselView(images: ["match","winners","qualifiers","groups"])
}
