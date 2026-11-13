//
//  LSMCameraView.swift
//  OneField
//
//  Created by Angela Pesina on 10/10/25.
//

import AVFoundation
import Vision
import SwiftUI
import CoreML

// camara de lengua de señas
struct LSMCameraView: View {
    @StateObject private var viewModel = LSMCameraViewModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            CameraPreviewView(session: viewModel.session)
                .ignoresSafeArea()
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        viewModel.switchCamera()
                    }) {
                        Image(systemName: "arrow.triangle.2.circlepath.camera")
                            .font(.title2)
                            .padding()
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                            .foregroundColor(.white)
                    }
                    .padding()
                }

                Spacer()

                Text(viewModel.prediction)
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.black.opacity(0.6))
            }
        }
        // inicia la sesión de cámara al aparecer la vista
        .onAppear {
            viewModel.startSession()
        }
        // detiene la cámara al salir de la vista
        .onDisappear {
            viewModel.stopSession()
        }
    }
}
