//
//  TesseractConfiguration.swift
//  OCRMax
//
//  Created by Sunil Pawar on 27/07/25.
//

import Foundation

final class TesseractConfiguration {
    
    static let shared = TesseractConfiguration()
    
    private init() {}
    
    private let supportedLanguages: [String: String] = [
        "English": "eng",
        "French": "fra",
        "German": "deu",
        "Spanish": "spa",
        "Italian": "ita",
        "Portuguese": "por",
        "Russian": "rus",
        "Japanese": "jpn",
        "Chinese (Simplified)": "chi_sim",
        "Chinese (Traditional)": "chi_tra",
        "Korean": "kor",
        "Arabic": "ara",
        "Hindi": "hin"
    ]
    
    func getAvailableLanguages() -> [String] {
        return Array(supportedLanguages.keys).sorted()
    }
    
    func getLanguageCode(for languageName: String) -> String? {
        return supportedLanguages[languageName]
    }
    
    func getLanguageName(for languageCode: String) -> String? {
        return supportedLanguages.first { $0.value == languageCode }?.key
    }
    
    func getOptimalPageSegmentationMode(for imageType: ImageType) -> Int {
        switch imageType {
        case .document:
            return 1 // PSM_SINGLE_COLUMN
        case .receipt:
            return 6 // PSM_SINGLE_UNIFORM_BLOCK
        case .handwritten:
            return 0 // PSM_OSD_ONLY
        case .mixed:
            return 3 // PSM_AUTO
        }
    }
    
    enum ImageType {
        case document
        case receipt
        case handwritten
        case mixed
    }
    
    func getCharacterWhitelistForLanguage(_ languageCode: String) -> String? {
        switch languageCode {
        case "eng":
            return "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.,!?;:()[]{}\"'-_@#$%^&*+=<>/\\ \n"
        case "ara", "chi_sim", "chi_tra", "jpn", "kor":
            return nil
        default:
            return nil
        }
    }
    
    func validateLanguageDataAvailability(for languageCode: String) -> Bool {
        guard let bundle = Bundle.main.path(forResource: "tessdata", ofType: nil) else {
            return false
        }
        
        let trainedDataPath = "\(bundle)/\(languageCode).traineddata"
        
        return FileManager.default.fileExists(atPath: trainedDataPath)
    }
}