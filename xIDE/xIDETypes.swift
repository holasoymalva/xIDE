import SwiftUI

// MARK: - Dracula Color System
struct Dracula {
    static let background = Color(red: 40/255, green: 42/255, blue: 54/255)      // #282a36
    static let selection = Color(red: 68/255, green: 71/255, blue: 90/255)       // #44475a
    static let foreground = Color(red: 248/255, green: 248/255, blue: 242/255)   // #f8f8f2
    static let comment = Color(red: 98/255, green: 114/255, blue: 164/255)      // #6272a4
    
    static let cyan = Color(red: 139/255, green: 233/255, blue: 253/255)        // #8be9fd
    static let green = Color(red: 80/255, green: 250/255, blue: 123/255)        // #50fa7b
    static let orange = Color(red: 255/255, green: 184/255, blue: 108/255)      // #ffb86c
    static let pink = Color(red: 255/255, green: 121/255, blue: 198/255)        // #ff79c6
    static let purple = Color(red: 189/255, green: 147/255, blue: 249/255)      // #bd93f9
    static let red = Color(red: 255/255, green: 85/255, blue: 85/255)           // #ff5555
    static let yellow = Color(red: 241/255, green: 250/255, blue: 140/255)      // #f1fa8c
    
    // Additional UI helper colors
    static let darkBackground = Color(red: 30/255, green: 31/255, blue: 41/255)  // #1e1f29
    static let border = Color(red: 19/255, green: 20/255, blue: 26/255)          // #13141a
}

// MARK: - File Tree Model
struct FileItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let isFolder: Bool
    var children: [FileItem]?
    
    var name: String {
        return url.lastPathComponent
    }
    
    var fileExtension: String {
        return url.pathExtension.lowercased()
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
    
    static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        return lhs.url == rhs.url
    }
    
    // SF Symbol icon name based on file extension / folder status
    var iconName: String {
        if isFolder {
            return "folder.fill"
        }
        
        switch fileExtension {
        case "html", "htm":
            return "chevron.left.forwardslash.chevron.right"
        case "css":
            return "number"
        case "js", "ts":
            return "curlybraces"
        case "py":
            return "doc.text.fill"
        case "java", "class":
            return "cup.and.saucer.fill"
        case "json", "yaml", "yml":
            return "doc.text.image"
        case "md", "txt":
            return "doc.plaintext.fill"
        case "png", "jpg", "jpeg", "gif", "svg":
            return "photo.fill"
        default:
            return "doc.text"
        }
    }
    
    // Custom colors matching extension types under Dracula palette
    var iconColor: Color {
        if isFolder {
            return Dracula.purple
        }
        
        switch fileExtension {
        case "html", "htm":
            return Dracula.pink
        case "css":
            return Dracula.cyan
        case "js", "ts":
            return Dracula.yellow
        case "py":
            return Dracula.green
        case "java":
            return Dracula.orange
        case "json", "yaml", "yml":
            return Dracula.purple
        case "md", "txt":
            return Dracula.foreground
        case "png", "jpg", "jpeg", "gif", "svg":
            return Dracula.cyan
        default:
            return Dracula.comment
        }
    }
}
