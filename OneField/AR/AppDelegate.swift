////
////  <.swift
////  OneField
////
////  Created by Danna Valencia on 07/10/25.
//
//import UIKit
//import ARKit
//
//@main
//class AppDelegate: UIResponder, UIApplicationDelegate {
//
//    var window: UIWindow?
//
//    func application(
//        _ application: UIApplication,
//        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
//    ) -> Bool {
//
//        //  Soporte de ARKit
//        if !ARWorldTrackingConfiguration.isSupported {
//            print(" Este dispositivo no soporta ARKit con World Tracking.")
//
//            window = UIWindow(frame: UIScreen.main.bounds)
//            let fallbackVC = UIViewController()
//            fallbackVC.view.backgroundColor = .black
//
//            let messageLabel = UILabel()
//            messageLabel.text = "AR no disponible en este dispositivo"
//            messageLabel.textColor = .white
//            messageLabel.font = .boldSystemFont(ofSize: 18)
//            messageLabel.textAlignment = .center
//            messageLabel.numberOfLines = 0
//            messageLabel.translatesAutoresizingMaskIntoConstraints = false
//            fallbackVC.view.addSubview(messageLabel)
//
//            NSLayoutConstraint.activate([
//                messageLabel.centerXAnchor.constraint(equalTo: fallbackVC.view.centerXAnchor),
//                messageLabel.centerYAnchor.constraint(equalTo: fallbackVC.view.centerYAnchor),
//                messageLabel.leadingAnchor.constraint(equalTo: fallbackVC.view.leadingAnchor, constant: 20),
//                messageLabel.trailingAnchor.constraint(equalTo: fallbackVC.view.trailingAnchor, constant: -20)
//            ])
//
//            window?.rootViewController = fallbackVC
//            window?.makeKeyAndVisible()
//            return true
//        }
//
//        print(" ARKit con World Tracking disponible.")
//
//        //  Ventana principal
//        window = UIWindow(frame: UIScreen.main.bounds)
//        let mainVC = ViewController()
//        window?.rootViewController = mainVC
//        window?.makeKeyAndVisible()
//
//        return true
//    }
//}
