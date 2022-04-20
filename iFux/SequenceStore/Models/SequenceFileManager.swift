//
//  SequenceFileManager.swift
//  iFux
//
//  Created by Simon Morgenstern on 18.07.22.
//

import Foundation

class SequenceFileManager: ObservableObject {
    @Published var sequenceURLs: Array<URL> = []
    
    init() {
        loadURLs()
    }
    
    private func filterURLs (_ urls: Array<URL>) -> Array<URL> {
        var filteredURLs: Array<URL> = []
        for index in 0..<urls.count {
            if (urls[index].lastPathComponent.contains(".json")) {
                filteredURLs.append(urls[index])
            }
        }
        return filteredURLs
    }
    
    
    func renameFile (_ url: URL, newName: String) -> Bool {
        if let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let sequencePath = documentDirectory.appendingPathComponent(AnimationStore.SEQUENCES_FOLDER_NAME)
            let pathWithFileName = sequencePath.appendingPathComponent("\(newName).json")
            do {
                try FileManager.default.moveItem(at: url, to: pathWithFileName)
            } catch {
                print(error)
                return false
            }
            loadURLs()
            return true;
        }
        return false;
    }
    
    func copyFile(_ url: URL, name: String) -> Bool {
        if let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let sequencePath = documentDirectory.appendingPathComponent(AnimationStore.SEQUENCES_FOLDER_NAME)
            var counter = 0
            var newURL: URL
            repeat {
                newURL = sequencePath.appendingPathComponent("\(name)-\(counter).json")
                counter += 1
            } while (FileManager.default.fileExists(atPath: newURL.path))
            do {
                try FileManager.default.copyItem(at: url, to: newURL)
            } catch {
                print(error)
                return false
            }
            loadURLs()
            return true;
        }
        return false;
    }
    
    
    func deleteFile(_ url: URL) -> Bool {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            print("Error while trying to delete file at \(url.description)")
            return false
        }
        loadURLs()
        return true
    }
    
    func loadURLs () {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(AnimationStore.SEQUENCES_FOLDER_NAME)
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsURL!, includingPropertiesForKeys: nil)
            let filteredURLs = filterURLs(fileURLs)
            self.sequenceURLs = filteredURLs
        } catch {
            print("Error while enumerating files \(documentsURL!.path): \(error.localizedDescription)")
        }
    }
    
}
