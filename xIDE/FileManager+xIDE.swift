import Foundation

extension FileManager {
    
    // The base directory for all projects inside the app's Documents folder
    var projectsDirectoryURL: URL {
        let paths = urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory.appendingPathComponent("Projects", isDirectory: true)
    }
    
    // Resolve project folder URL for a specific project name
    func projectURL(named projectName: String) -> URL {
        return projectsDirectoryURL.appendingPathComponent(projectName, isDirectory: true)
    }
    
    // Initialize the main Projects directory and create a default project if none exist
    func initializeProjectsDirectory() {
        let baseDir = projectsDirectoryURL
        var isDir: ObjCBool = false
        
        // Create base directory if it doesn't exist
        if !fileExists(atPath: baseDir.path, isDirectory: &isDir) {
            try? createDirectory(at: baseDir, withIntermediateDirectories: true, attributes: nil)
        }
        
        // If no projects exist, create the "Default Project"
        let currentProjects = listProjects()
        if currentProjects.isEmpty {
            createProject(named: "Default Project")
        }
    }
    
    // List all user projects (subfolders in Projects directory)
    func listProjects() -> [String] {
        let baseDir = projectsDirectoryURL
        guard let contents = try? contentsOfDirectory(at: baseDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return []
        }
        
        var projectNames: [String] = []
        for url in contents {
            var isDir: ObjCBool = false
            if fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue {
                projectNames.append(url.lastPathComponent)
            }
        }
        return projectNames.sorted()
    }
    
    // Create a new project and initialize it with starter files
    func createProject(named name: String) {
        let targetURL = projectURL(named: name)
        var isDir: ObjCBool = false
        
        if !fileExists(atPath: targetURL.path, isDirectory: &isDir) {
            try? createDirectory(at: targetURL, withIntermediateDirectories: true, attributes: nil)
            createDefaultWorkspaceTemplates(at: targetURL)
        }
    }
    
    // Delete a project directory
    func deleteProject(named name: String) {
        let targetURL = projectURL(named: name)
        try? removeItem(at: targetURL)
    }
    
    // Create default templates inside a project folder to make it immediately useful
    private func createDefaultWorkspaceTemplates(at url: URL) {
        // 1. Python file
        let pythonCode = """
# Welcome to xIDE!
# This is a Python template. You can run it offline directly in the console.

def greet(name):
    print(f"Hello, {name}!")
    print("Welcome to your minimalist iOS IDE.")

greet("Developer")

print("\\nCalculating prime numbers up to 20:")
primes = [x for x in range(2, 20) if all(x % y != 0 for y in range(2, x))]
print(primes)
"""
        try? pythonCode.write(to: url.appendingPathComponent("main.py"), atomically: true, encoding: .utf8)
        
        // 2. HTML file
        let htmlCode = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Welcome to xIDE</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <div class="card">
        <h1>xIDE Live Preview</h1>
        <p>This is a live preview of your HTML page. You can edit this file, and press the <b>Run</b> button to see your changes instantly!</p>
        <button id="actionBtn">Click Me</button>
        <p id="counter">Clicks: 0</p>
    </div>
    <script src="script.js"></script>
</body>
</html>
"""
        try? htmlCode.write(to: url.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)
        
        // 3. CSS file
        let cssCode = """
body {
    background-color: #282a36;
    color: #f8f8f2;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    display: flex;
    justify-content: center;
    align-items: center;
    height: 100vh;
    margin: 0;
}

.card {
    background-color: #44475a;
    padding: 30px;
    border-radius: 12px;
    box-shadow: 0 8px 24px rgba(0,0,0,0.3);
    text-align: center;
    max-width: 400px;
}

h1 {
    color: #bd93f9;
    margin-top: 0;
}

button {
    background-color: #50fa7b;
    color: #282a36;
    border: none;
    padding: 10px 20px;
    border-radius: 6px;
    font-size: 16px;
    font-weight: bold;
    cursor: pointer;
    transition: transform 0.1s;
}

button:active {
    transform: scale(0.95);
}

#counter {
    color: #f1fa8c;
    margin-top: 15px;
    font-weight: bold;
}
"""
        try? cssCode.write(to: url.appendingPathComponent("style.css"), atomically: true, encoding: .utf8)
        
        // 4. JS file
        let jsCode = """
// Interactive Javascript for index.html
let btn = document.getElementById('actionBtn');
let txt = document.getElementById('counter');
let count = 0;

btn.addEventListener('click', () => {
    count++;
    txt.textContent = `Clicks: ${count}`;
    
    // Quick micro-interaction color change
    const colors = ['#50fa7b', '#ff79c6', '#8be9fd', '#ffb86c', '#bd93f9'];
    btn.style.backgroundColor = colors[count % colors.length];
});

console.log("xIDE preview loaded successfully!");
"""
        try? jsCode.write(to: url.appendingPathComponent("script.js"), atomically: true, encoding: .utf8)
        
        // 5. Java file
        let javaCode = """
// Java template
public class Hello {
    public static void main(String[] args) {
        System.out.println("Hello, World from xIDE!");
    }
}
"""
        try? javaCode.write(to: url.appendingPathComponent("Hello.java"), atomically: true, encoding: .utf8)
        
        // 6. Subdirectory for structure
        let libFolder = url.appendingPathComponent("utils", isDirectory: true)
        try? createDirectory(at: libFolder, withIntermediateDirectories: true, attributes: nil)
        
        let libReadme = """
# Library Utilities
This folder is for housing your helper scripts and modules.
"""
        try? libReadme.write(to: libFolder.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
    }
    
    // Fetch workspace items for a specific project folder recursively
    func fetchWorkspaceItems(in project: String) -> [FileItem] {
        initializeProjectsDirectory()
        let targetURL = projectURL(named: project)
        return scanDirectory(at: targetURL)
    }
    
    // Helper to recursively scan a folder and build FileItems
    private func scanDirectory(at folderURL: URL) -> [FileItem] {
        var items: [FileItem] = []
        
        guard let contents = try? contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return []
        }
        
        for url in contents {
            var isDir: ObjCBool = false
            if fileExists(atPath: url.path, isDirectory: &isDir) {
                if isDir.boolValue {
                    let children = scanDirectory(at: url)
                    items.append(FileItem(url: url, isFolder: true, children: children))
                } else {
                    items.append(FileItem(url: url, isFolder: false, children: nil))
                }
            }
        }
        
        // Sort: Folders first (alphabetically), then Files (alphabetically)
        return items.sorted { (item1, item2) -> Bool in
            if item1.isFolder != item2.isFolder {
                return item1.isFolder
            }
            return item1.name.localizedStandardCompare(item2.name) == .orderedAscending
        }
    }
    
    // Create new file
    func createFile(at folderURL: URL, name: String, content: String = "") throws {
        let fileURL = folderURL.appendingPathComponent(name)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
    }
    
    // Create new folder
    func createFolder(at parentURL: URL, name: String) throws {
        let folderURL = parentURL.appendingPathComponent(name, isDirectory: true)
        try createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
    }
    
    // Delete item
    func deleteItem(at url: URL) throws {
        try removeItem(at: url)
    }
    
    // Rename item
    func renameItem(at url: URL, to newName: String) throws -> URL {
        let destinationURL = url.deletingLastPathComponent().appendingPathComponent(newName)
        try moveItem(at: url, to: destinationURL)
        return destinationURL
    }
    
    // Read file text
    func readFileContent(at url: URL) -> String? {
        return try? String(contentsOf: url, encoding: .utf8)
    }
    
    // Write file text
    func writeFileContent(at url: URL, content: String) throws {
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
}
