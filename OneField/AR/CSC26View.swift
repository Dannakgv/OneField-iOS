//
//  CSC26View.swift
//  OneField
//
//  Created by Santiago Quihui on 11/10/25.
//

import SwiftUI
import RealityKit
import ARKit

struct CSC26View: View {
    var body: some View {
        ARViewContainer()
            .ignoresSafeArea()
    }
}

private final class SessionDelegate: NSObject, ARSessionDelegate {
    weak var arView: ARView?
    private var contentPrototype: Entity?
    private var isContentLoaded = false
    private var pendingAnchors: [ARObjectAnchor] = []

    init(arView: ARView) {
        self.arView = arView
        super.init()
        Task { await preloadContent() }
    }

    // Preload the content from CSC26.reality asynchronously
    private func preloadContent() async {
        guard let url = Bundle.main.url(forResource: "CSC26", withExtension: "reality") else {
            print("⚠️ CSC26.reality not found in bundle.")
            return
        }
        
        do {
            let rootAnchor = try await Entity.loadAnchor(contentsOf: url)
            
            let container = Entity()
            for child in rootAnchor.children {
                container.addChild(child.clone(recursive: true))
            }
            
            await MainActor.run {
                self.contentPrototype = container
                self.isContentLoaded = true
                print("✅ CSC26 content preloaded.")
                
                // Attach to any pending anchors that were detected before content loaded
                self.attachPendingAnchors()
            }
        } catch {
            print("❌ Failed to load CSC26.reality: \(error)")
        }
    }
    
    private func attachPendingAnchors() {
        guard let arView = arView, !pendingAnchors.isEmpty else { return }
        
        print("🔄 Attaching content to \(pendingAnchors.count) pending anchor(s)")
        for objectAnchor in pendingAnchors {
            attachContent(to: objectAnchor, in: arView)
        }
        pendingAnchors.removeAll()
    }
    
    private func attachContent(to objectAnchor: ARObjectAnchor, in arView: ARView) {
        let rkAnchor = AnchorEntity(anchor: objectAnchor)
        
        if let content = contentPrototype?.clone(recursive: true) {
            rkAnchor.addChild(content)
            print("✅ Attached CSC26 content to object: \(objectAnchor.referenceObject.name ?? "unknown")")
        }
        
        arView.scene.addAnchor(rkAnchor)
    }

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        guard let arView = arView else { return }

        for arAnchor in anchors {
            guard let objectAnchor = arAnchor as? ARObjectAnchor else { continue }

            print("🎯 Object detected: \(objectAnchor.referenceObject.name ?? "unknown")")

            if isContentLoaded {
                attachContent(to: objectAnchor, in: arView)
            } else {
                print("⏳ Content not loaded yet, queuing anchor...")
                pendingAnchors.append(objectAnchor)
            }
        }
    }
}

private struct ARViewContainer: UIViewRepresentable {
    // CRITICAL: Store the delegate as a @State to keep it alive
    @State private var sessionDelegate: SessionDelegate?
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        // Configure for object detection
        let config = ARWorldTrackingConfiguration()
        if let objects = ARReferenceObject.referenceObjects(inGroupNamed: "AR Resources", bundle: .main) {
            config.detectionObjects = objects
            print("🔎 Loaded \(objects.count) ARReferenceObject(s) from 'AR Resources'.")
            
            // Print details about each object
            for obj in objects {
                print("   - Object: \(obj.name ?? "unnamed")")
            }
        } else {
            print("⚠️ No ARReferenceObjects found in 'AR Resources'. Did you add your .arobject?")
        }

        // Create and retain the delegate
        let delegate = SessionDelegate(arView: arView)
        arView.session.delegate = delegate
        
        // Store in @State to keep it alive
        DispatchQueue.main.async {
            self.sessionDelegate = delegate
        }
        
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}
