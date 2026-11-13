//
//  FaceStorageManager.swift
//  OneField
//
//  Created by Victoria Marin on 06/10/25.
//

import Foundation

class FaceStorageManager {
    static let shared = FaceStorageManager()
    
    private let userDefaults = UserDefaults.standard
    private let peopleKey = "knownPeople"
    
    // Alternativamente, usa CoreData para mayor escalabilidad
    private let fileManager = FileManager.default
    private var storageURL: URL {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("FaceDatabase")
    }
    
    private init() {
        createStorageDirectoryIfNeeded()
    }
    
    private func createStorageDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: storageURL.path) {
            try? fileManager.createDirectory(at: storageURL, withIntermediateDirectories: true)
        }
    }
    
    // Guardar persona
    func savePerson(_ person: KnownPerson) {
        let fileName = "\(person.id.uuidString).json"
        let fileURL = storageURL.appendingPathComponent(fileName)
        
        do {
            let data = try JSONEncoder().encode(person)
            try data.write(to: fileURL)
            print("Persona guardada: \(person.name)")
        } catch {
            print("Error guardando persona: \(error)")
        }
    }
    
    // Cargar todas las personas
    func loadAllPeople() -> [KnownPerson]? {
        do {
            let files = try fileManager.contentsOfDirectory(at: storageURL, includingPropertiesForKeys: nil)
            let jsonFiles = files.filter { $0.pathExtension == "json" }
            
            var people: [KnownPerson] = []
            
            for file in jsonFiles {
                let data = try Data(contentsOf: file)
                let person = try JSONDecoder().decode(KnownPerson.self, from: data)
                people.append(person)
            }
            
            print("Cargadas \(people.count) personas")
            return people
            
        } catch {
            print("Error cargando personas: \(error)")
            return nil
        }
    }
    
    // Actualizar persona
    func updatePerson(_ person: KnownPerson) {
        savePerson(person) // Sobrescribe el archivo existente
    }
    
    // Eliminar persona
    func deletePerson(_ person: KnownPerson) {
        let fileName = "\(person.id.uuidString).json"
        let fileURL = storageURL.appendingPathComponent(fileName)
        
        try? fileManager.removeItem(at: fileURL)
        print("Persona eliminada: \(person.name)")
    }
    
    // Limpiar toda la base de datos
    func clearAllPeople() {
        do {
            let files = try fileManager.contentsOfDirectory(at: storageURL, includingPropertiesForKeys: nil)
            for file in files {
                try fileManager.removeItem(at: file)
            }
            print("Base de datos limpiada")
        } catch {
            print("Error limpiando base de datos: \(error)")
        }
    }
}
