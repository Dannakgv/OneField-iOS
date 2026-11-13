//
//  LSMCameraViewModel.swift
//  OneField
//
//  Created by Angela Pesina on 10/10/25.
//

import AVFoundation
import Vision
import CoreML
import Combine

 // maneja la cámara y el modelo para lsm
class LSMCameraViewModel: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    // basicamente inicializa la traducción, para que sea lo primero que muestra
    @Published var prediction: String = "Esperando..."
    private var currentCameraPosition: AVCaptureDevice.Position = .front

    
    // captura de video
    let session = AVCaptureSession()
    
    // modelo CoreML entrenado lsm
    private var model: MLLengua1?
    
    // buffer que guarda los frames procesados
    private var frameBuffer: [[[Float]]] = []
    
    // 60 frames por secuencia
    private let maxFrames = 60

    override init() {
        super.init()
        
        do {
            let config = MLModelConfiguration()
            self.model = try MLLengua1(configuration: config)
        } catch {
            fatalError("Error cargando el modelo: \(error.localizedDescription)")
        }
        
        // configura la cámara para capturar video
        configureSession()
    }

    // incializa la camara
    func configureSession() {
        session.beginConfiguration()
        session.inputs.forEach { session.removeInput($0) } // limpia inputs anteriores

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else {
            print("No se pudo acceder a la cámara.")
            session.commitConfiguration()
            return
        }

        session.addInput(input)

        session.outputs.forEach { session.removeOutput($0) } // limpia outputs anteriores

        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))

        guard session.canAddOutput(output) else {
            print("No se pudo agregar el output del video.")
            session.commitConfiguration()
            return
        }

        session.addOutput(output)
        session.commitConfiguration()
    }

    // función para cambiar camara
    func switchCamera() {
        currentCameraPosition = currentCameraPosition == .front ? .back : .front
        configureSession()
    }

    
    // incia la captura de video
    func startSession() {
        if !session.isRunning {
            session.startRunning()
        }
    }

    // detiene la captura de video
    func stopSession() {
        if session.isRunning {
            session.stopRunning()
        }
    }

    // procesar los frames para que se use el modelo
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // extrae la pose de la mano del frame actual
        guard let pose = extractPose(from: sampleBuffer) else { return }

        DispatchQueue.main.async {
            // guarda la pose en el buffer
            self.frameBuffer.append(pose)

            // cuando se acumulan los 60 frames esperados ya predice
            if self.frameBuffer.count == self.maxFrames {
                self.runDynamicPrediction()
                self.frameBuffer.removeAll() // limpia para la siguiente secuencia
            }
        }
    }

    // predicción con el modelo
    func runDynamicPrediction() {
        guard let model = model else { return }

        do {
            // crea un array multidimensional con la forma esperada por el modelo: [60, 3, 21]
            let array = try MLMultiArray(shape: [60, 3, 21], dataType: .float32)

            // copia los valores (x, y, z) de cada punto de la mano para los 60 frames
            for t in 0..<60 {
                for i in 0..<3 {
                    for j in 0..<21 {
                        let index = [NSNumber(value: t), NSNumber(value: i), NSNumber(value: j)]
                        array[index] = NSNumber(value: frameBuffer[t][i][j])
                    }
                }
            }

            // prepara el input y obtiene la predicción del modelo
            let input = try MLLengua1Input(poses: array)
            let output = try model.prediction(input: input)

            // actualiza el texto mostrado con la etiqueta y su probabilidad
            DispatchQueue.main.async {
                self.prediction = "\(output.label) (\(String(format: "%.1f", output.labelProbabilities[output.label]! * 100))%)"
            }

        } catch {
            print("Error en la predicción dinámica: \(error.localizedDescription)")
        }
    }

    // detección de pose de mano con visión
    func extractPose(from sampleBuffer: CMSampleBuffer) -> [[Float]]? {
        // convierte el buffer de la cámara en una imagen utilizable por Vision
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }

        // configura la solicitud de detección de mano
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 1 // Solo analizamos una mano a la vez

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .leftMirrored, options: [:])

        do {
            // ejecuta la detección
            try handler.perform([request])
            guard let observation = request.results?.first else {
                return nil
            }

            // lista de las 21 articulaciones que Vision puede reconocer
            let joints: [VNHumanHandPoseObservation.JointName] = [
                .wrist,
                .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
                .indexMCP, .indexPIP, .indexDIP, .indexTip,
                .middleMCP, .middlePIP, .middleDIP, .middleTip,
                .ringMCP, .ringPIP, .ringDIP, .ringTip,
                .littleMCP, .littlePIP, .littleDIP, .littleTip
            ]

            // inicializa una matriz 3x21 para guardar x, y, z
            var pose: [[Float]] = [[], [], []]

            // extrae las coordenadas de cada articulación
            for joint in joints {
                if let point = try? observation.recognizedPoint(joint) {
                    pose[0].append(Float(point.location.x))  // Coordenada X normalizada
                    pose[1].append(Float(point.location.y))  // Coordenada Y normalizada
                    pose[2].append(Float(point.confidence))  // Confianza (usada como Z)
                } else {
                    // si no se detecta, añade ceros
                    pose[0].append(0)
                    pose[1].append(0)
                    pose[2].append(0)
                }
            }

            return pose

        } catch {
            print("Error extrayendo pose: \(error.localizedDescription)")
            return nil
        }
    }
}
