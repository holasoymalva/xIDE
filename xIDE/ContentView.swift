import SwiftUI
import WebKit
import Combine
import UniformTypeIdentifiers

// MARK: - Helper Models
struct ConsoleLine: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let isError: Bool
}

// MARK: - IDE View Model
class IDEViewModel: ObservableObject {
    @Published var workspaceFiles: [FileItem] = []
    @Published var openFile: FileItem?
    @Published var openFileContent: String = ""
    @Published var fontSize: Double = 16.0
    
    // Project management states
    @Published var projects: [String] = []
    @Published var activeProject: String = "Default Project"
    
    // Console terminal states
    @Published var consoleOutput: [ConsoleLine] = []
    @Published var isConsoleVisible: Bool = false
    @Published var terminalInput: String = ""
    
    // Live Web Preview states
    @Published var isWebPreviewVisible: Bool = false
    
    // Editor State
    @Published var isEditorLoading: Bool = true
    @Published var runTrigger: UUID?
    
    // Dialog inputs
    @Published var showCreateFileDialog = false
    @Published var showCreateFolderDialog = false
    @Published var showRenameDialog = false
    @Published var showSettingsSheet = false
    @Published var showCreateProjectDialog = false
    
    @Published var activeFolderTarget: FileItem? // Target folder for adding new files
    @Published var activeRenameTarget: FileItem?
    
    @Published var dialogTextName = ""
    
    init() {
        // Initialize base projects system
        FileManager.default.initializeProjectsDirectory()
        projects = FileManager.default.listProjects()
        if let first = projects.first {
            activeProject = first
        }
        loadWorkspace()
    }
    
    func loadWorkspace() {
        workspaceFiles = FileManager.default.fetchWorkspaceItems(in: activeProject)
    }
    
    func selectFile(_ item: FileItem) {
        if item.isFolder { return }
        
        // Save current file if open
        if let currentFile = openFile {
            try? FileManager.default.writeFileContent(at: currentFile.url, content: openFileContent)
        }
        
        // Auto-hide web preview for non-HTML files
        let ext = item.url.pathExtension.lowercased()
        if ext != "html" && ext != "htm" {
            isWebPreviewVisible = false
        }
        
        // Load new file
        if let content = FileManager.default.readFileContent(at: item.url) {
            openFileContent = content
            openFile = item
        }
    }
    
    func closeCurrentFile() {
        if let currentFile = openFile {
            try? FileManager.default.writeFileContent(at: currentFile.url, content: openFileContent)
        }
        openFile = nil
        openFileContent = ""
        isWebPreviewVisible = false
    }
    
    func saveCurrentFile(content: String) {
        openFileContent = content
        if let file = openFile {
            try? FileManager.default.writeFileContent(at: file.url, content: content)
        }
    }
    
    // Project management actions
    func switchProject(to name: String) {
        closeCurrentFile()
        isWebPreviewVisible = false
        activeProject = name
        loadWorkspace()
        appendConsoleLog("Opened project: \(name)")
    }
    
    func createNewProject(named name: String) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        
        FileManager.default.createProject(named: cleanName)
        projects = FileManager.default.listProjects()
        switchProject(to: cleanName)
    }
    
    func deleteProject(named name: String) {
        FileManager.default.deleteProject(named: name)
        projects = FileManager.default.listProjects()
        
        if activeProject == name {
            if let first = projects.first {
                switchProject(to: first)
            } else {
                createNewProject(named: "Default Project")
            }
        } else {
            loadWorkspace()
        }
    }
    
    // File/Folder CRUD actions
    func createFile(name: String, in folder: FileItem? = nil) {
        let parentURL = folder?.url ?? FileManager.default.projectURL(named: activeProject)
        do {
            try FileManager.default.createFile(at: parentURL, name: name)
            loadWorkspace()
            
            // Auto open the new file
            let fileURL = parentURL.appendingPathComponent(name)
            let newItem = FileItem(url: fileURL, isFolder: false, children: nil)
            selectFile(newItem)
        } catch {
            appendConsoleError("Failed to create file: \(error.localizedDescription)")
        }
    }
    
    func createFolder(name: String, in folder: FileItem? = nil) {
        let parentURL = folder?.url ?? FileManager.default.projectURL(named: activeProject)
        do {
            try FileManager.default.createFolder(at: parentURL, name: name)
            loadWorkspace()
        } catch {
            appendConsoleError("Failed to create folder: \(error.localizedDescription)")
        }
    }
    
    func deleteItem(_ item: FileItem) {
        do {
            try FileManager.default.deleteItem(at: item.url)
            if openFile?.url == item.url {
                openFile = nil
                openFileContent = ""
            }
            loadWorkspace()
        } catch {
            appendConsoleError("Failed to delete item: \(error.localizedDescription)")
        }
    }
    
    func renameItem(_ item: FileItem, to newName: String) {
        do {
            let newURL = try FileManager.default.renameItem(at: item.url, to: newName)
            if openFile?.url == item.url {
                openFile = FileItem(url: newURL, isFolder: false, children: nil)
            }
            loadWorkspace()
        } catch {
            appendConsoleError("Failed to rename item: \(error.localizedDescription)")
        }
    }
    
    // Drag & Drop File Relocation
    func moveItem(from sourceURL: URL, toDirectory targetDirectoryURL: URL) {
        let fileName = sourceURL.lastPathComponent
        let destinationURL = targetDirectoryURL.appendingPathComponent(fileName)
        
        // Safety check 1: Same location check
        guard sourceURL != destinationURL else { return }
        
        // Safety check 2: Prevent moving folder into itself or its subdirectories
        if targetDirectoryURL.path.hasPrefix(sourceURL.path + "/") || targetDirectoryURL.path == sourceURL.path {
            appendConsoleError("Cannot move a folder inside itself or its own subdirectories.")
            return
        }
        
        do {
            try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
            
            // If the moved file was the currently open file, update its references
            if openFile?.url == sourceURL {
                openFile = FileItem(url: destinationURL, isFolder: false, children: nil)
            }
            
            loadWorkspace()
            appendConsoleLog("Moved \(fileName) to \(targetDirectoryURL.lastPathComponent)")
        } catch {
            appendConsoleError("Failed to move item: \(error.localizedDescription)")
        }
    }
    
    // Console / Terminal output helpers
    func appendConsoleLog(_ msg: String) {
        DispatchQueue.main.async {
            let cleanMsg = msg.replacingOccurrences(of: "\\n", with: "\n")
            let lines = cleanMsg.components(separatedBy: .newlines)
            for line in lines {
                self.consoleOutput.append(ConsoleLine(text: line, isError: false))
            }
        }
    }
    
    func appendConsoleError(_ msg: String) {
        DispatchQueue.main.async {
            let cleanMsg = msg.replacingOccurrences(of: "\\n", with: "\n")
            let lines = cleanMsg.components(separatedBy: .newlines)
            for line in lines {
                self.consoleOutput.append(ConsoleLine(text: line, isError: true))
            }
        }
    }
    
    func clearConsole() {
        DispatchQueue.main.async {
            self.consoleOutput.removeAll()
        }
    }
    
    // Send terminal inputs to the WebView REPL context
    func sendTerminalCommand() {
        let cmd = terminalInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cmd.isEmpty else { return }
        
        NotificationCenter.default.post(
            name: Notification.Name("EvaluateTerminalCommand"),
            object: nil,
            userInfo: ["command": cmd]
        )
        
        terminalInput = ""
    }
}

// MARK: - Main Application Content View
struct ContentView: View {
    @StateObject private var viewModel = IDEViewModel()
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State private var showMobileEditor: Bool = false
    
    init() {
        // Customize SwiftUI Lists and Views to look premium and match Dracula theme
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Dracula.darkBackground)
        appearance.titleTextAttributes = [.foregroundColor: UIColor(Dracula.foreground)]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(Dracula.foreground)]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        
        UITableView.appearance().backgroundColor = UIColor(Dracula.darkBackground)
        UITableViewCell.appearance().backgroundColor = UIColor(Dracula.darkBackground)
    }
    
    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                // MARK: iPhone Layout (NavigationStack pushing to Editor)
                NavigationStack {
                    SidebarView(viewModel: viewModel)
                        .navigationDestination(isPresented: $showMobileEditor) {
                            if let file = viewModel.openFile {
                                EditorDetailView(file: file, viewModel: viewModel)
                            }
                        }
                }
                .accentColor(Dracula.pink)
                .onChange(of: viewModel.openFile) { newFile in
                    if newFile != nil {
                        showMobileEditor = true
                    } else {
                        showMobileEditor = false
                    }
                }
            } else {
                // MARK: iPad / Mac Layout (NavigationSplitView side-by-side)
                NavigationSplitView {
                    SidebarView(viewModel: viewModel)
                } detail: {
                    ZStack {
                        Dracula.background
                            .ignoresSafeArea()
                        
                        if let file = viewModel.openFile {
                            EditorDetailView(file: file, viewModel: viewModel)
                        } else {
                            WelcomeView(viewModel: viewModel)
                        }
                    }
                }
            }
        }
        // MARK: - Dialogs & Sheets (Dracula Themed Alerts)
        .sheet(isPresented: $viewModel.showSettingsSheet) {
            SettingsView(viewModel: viewModel)
        }
        .alert("New Project", isPresented: $viewModel.showCreateProjectDialog) {
            TextField("My New Project", text: $viewModel.dialogTextName)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            Button("Cancel", role: .cancel) { }
            Button("Create") {
                if !viewModel.dialogTextName.isEmpty {
                    viewModel.createNewProject(named: viewModel.dialogTextName)
                }
            }
        } message: {
            Text("Enter a name for the new project workspace.")
        }
        .alert("New File", isPresented: $viewModel.showCreateFileDialog) {
            TextField("file.txt", text: $viewModel.dialogTextName)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            Button("Cancel", role: .cancel) { }
            Button("Create") {
                if !viewModel.dialogTextName.isEmpty {
                    viewModel.createFile(name: viewModel.dialogTextName, in: viewModel.activeFolderTarget)
                }
            }
        } message: {
            Text("Enter a name for the new file (e.g., index.js, script.py).")
        }
        .alert("New Folder", isPresented: $viewModel.showCreateFolderDialog) {
            TextField("Folder Name", text: $viewModel.dialogTextName)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            Button("Cancel", role: .cancel) { }
            Button("Create") {
                if !viewModel.dialogTextName.isEmpty {
                    viewModel.createFolder(name: viewModel.dialogTextName, in: viewModel.activeFolderTarget)
                }
            }
        } message: {
            Text("Enter a name for the new folder.")
        }
        .alert("Rename Item", isPresented: $viewModel.showRenameDialog) {
            TextField("New Name", text: $viewModel.dialogTextName)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            Button("Cancel", role: .cancel) { }
            Button("Rename") {
                if let target = viewModel.activeRenameTarget, !viewModel.dialogTextName.isEmpty {
                    viewModel.renameItem(target, to: viewModel.dialogTextName)
                }
            }
        } message: {
            Text("Enter the new name for \(viewModel.activeRenameTarget?.name ?? "this item").")
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowWebPreview"))) { _ in
            if let file = viewModel.openFile, file.url.pathExtension.lowercased() == "html" || file.url.pathExtension.lowercased() == "htm" {
                viewModel.isWebPreviewVisible = true
            }
        }
    }
}

// MARK: - Sidebar View Component
struct SidebarView: View {
    @ObservedObject var viewModel: IDEViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Sidebar Header containing the Project switcher Menu
            HStack {
                Menu {
                    Section(header: Text("Select Project").foregroundColor(Dracula.pink)) {
                        ForEach(viewModel.projects, id: \.self) { proj in
                            Button {
                                viewModel.switchProject(to: proj)
                            } label: {
                                HStack {
                                    Text(proj)
                                    if proj == viewModel.activeProject {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                    
                    Section {
                        Button {
                            viewModel.dialogTextName = ""
                            viewModel.showCreateProjectDialog = true
                        } label: {
                            Label("Create New Project...", systemImage: "plus.rectangle.on.folder")
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Dracula.purple)
                        
                        Text(viewModel.activeProject)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(Dracula.foreground)
                            .lineLimit(1)
                        
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Dracula.comment)
                    }
                }
                
                Spacer()
                
                Button {
                    viewModel.loadWorkspace()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Dracula.cyan)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Dracula.darkBackground)
            
            Divider()
                .background(Dracula.border)
            
            // File Explorer List
            List {
                ForEach(viewModel.workspaceFiles) { item in
                    FileRowView(item: item, viewModel: viewModel, depth: 0)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 2, leading: 10, bottom: 2, trailing: 10))
                }
            }
            .listStyle(.plain)
            .background(Dracula.darkBackground)
            .onDrop(of: [.text], isTargeted: nil) { providers in
                guard let provider = providers.first else { return false }
                provider.loadObject(ofClass: NSString.self) { (string, error) in
                    if let urlString = string as? String, let sourceURL = URL(string: urlString) {
                        let targetDirectoryURL = FileManager.default.projectURL(named: viewModel.activeProject)
                        DispatchQueue.main.async {
                            viewModel.moveItem(from: sourceURL, toDirectory: targetDirectoryURL)
                        }
                    }
                }
                return true
            }
            
            Divider()
                .background(Dracula.border)
            
            // Sidebar Footer Controls
            HStack(spacing: 20) {
                Button {
                    viewModel.activeFolderTarget = nil
                    viewModel.dialogTextName = ""
                    viewModel.showCreateFileDialog = true
                } label: {
                    Label("New File", systemImage: "doc.badge.plus")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(Dracula.green)
                }
                
                Spacer()
                
                Button {
                    viewModel.activeFolderTarget = nil
                    viewModel.dialogTextName = ""
                    viewModel.showCreateFolderDialog = true
                } label: {
                    Label("New Folder", systemImage: "folder.badge.plus")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(Dracula.purple)
                }
                
                Spacer()
                
                Button {
                    viewModel.showSettingsSheet = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.body)
                        .foregroundColor(Dracula.cyan)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Dracula.darkBackground)
        }
        .navigationBarHidden(true)
        .background(Dracula.darkBackground)
    }
}

// MARK: - Editor Detail View Component
struct EditorDetailView: View {
    let file: FileItem
    @ObservedObject var viewModel: IDEViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Editor Tab bar
            HStack {
                Image(systemName: file.iconName)
                    .foregroundColor(file.iconColor)
                Text(file.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Dracula.foreground)
                
                Button {
                    viewModel.closeCurrentFile()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Dracula.comment)
                        .font(.system(size: 14))
                }
                .padding(.leading, 4)
                
                Spacer()
                
                // Editor Toolbar Actions
                HStack(spacing: 16) {
                    // "Run" Button
                    Button {
                        viewModel.isConsoleVisible = true
                        viewModel.runTrigger = UUID()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                            Text("Run")
                                .font(.caption)
                                .fontWeight(.bold)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Dracula.green.opacity(0.15))
                        .foregroundColor(Dracula.green)
                        .cornerRadius(6)
                    }
                    
                    // "Toggle Console" Button
                    Button {
                        withAnimation {
                            viewModel.isConsoleVisible.toggle()
                        }
                    } label: {
                        Image(systemName: "terminal")
                            .font(.body)
                            .foregroundColor(viewModel.isConsoleVisible ? Dracula.pink : Dracula.foreground)
                    }
                    
                    // "Web Preview" Toggle
                    if file.fileExtension == "html" || file.fileExtension == "htm" {
                        Button {
                            viewModel.isWebPreviewVisible.toggle()
                        } label: {
                            Image(systemName: "safari")
                                .font(.body)
                                .foregroundColor(viewModel.isWebPreviewVisible ? Dracula.cyan : Dracula.foreground)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Dracula.darkBackground)
            
            Divider()
                .background(Dracula.border)
            
            // Editor and Console Panels Layout
            HSplitView(isConsoleVisible: viewModel.isConsoleVisible, isWebPreviewVisible: viewModel.isWebPreviewVisible, fileURL: file.url) {
                // Left Area: Monaco Editor WebView
                ZStack {
                    EditorWebView(
                        fileURL: file.url,
                        content: viewModel.openFileContent,
                        fontSize: viewModel.fontSize,
                        onTextChanged: { newText in
                            viewModel.saveCurrentFile(content: newText)
                        },
                        onConsoleLog: { log in
                            viewModel.appendConsoleLog(log)
                        },
                        onConsoleError: { err in
                            viewModel.appendConsoleError(err)
                        },
                        onConsoleClear: {
                            viewModel.clearConsole()
                        },
                        onEditorReady: {
                            viewModel.isEditorLoading = false
                        },
                        runTrigger: $viewModel.runTrigger
                    )
                    
                    if viewModel.isEditorLoading {
                        ProgressView("Loading Editor Assets...")
                            .foregroundColor(Dracula.foreground)
                            .tint(Dracula.purple)
                            .padding()
                            .background(Dracula.darkBackground.opacity(0.85))
                            .cornerRadius(8)
                    }
                }
            } consoleContent: {
                // Bottom Console Panel (styled as Terminal)
                ConsoleView(viewModel: viewModel)
            } previewContent: {
                // Right Panel: HTML live web preview
                WebPreviewView(fileURL: file.url)
            }
        }
        .background(Dracula.background)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Sidebar Tree Row Component
struct FileRowView: View {
    let item: FileItem
    @ObservedObject var viewModel: IDEViewModel
    let depth: CGFloat
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Node row
            HStack(spacing: 8) {
                if item.isFolder {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Dracula.comment)
                        .frame(width: 12)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                isExpanded.toggle()
                            }
                        }
                } else {
                    Spacer()
                        .frame(width: 12)
                }
                
                Image(systemName: item.iconName)
                    .font(.system(size: 15))
                    .foregroundColor(item.iconColor)
                    .frame(width: 18)
                
                Text(item.name)
                    .font(.system(size: 14, weight: item.isFolder ? .bold : .regular))
                    .foregroundColor(viewModel.openFile?.url == item.url ? Dracula.green : Dracula.foreground)
                
                Spacer()
            }
            .padding(.leading, depth * 14)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .background(viewModel.openFile?.url == item.url ? Dracula.selection.opacity(0.5) : Color.clear)
            .cornerRadius(6)
            .onTapGesture {
                if item.isFolder {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isExpanded.toggle()
                    }
                } else {
                    viewModel.selectFile(item)
                }
            }
            .onDrag {
                NSItemProvider(object: item.url.absoluteString as NSString)
            }
            .onDrop(of: [.text], isTargeted: nil) { providers in
                guard item.isFolder else { return false }
                guard let provider = providers.first else { return false }
                provider.loadObject(ofClass: NSString.self) { (string, error) in
                    if let urlString = string as? String, let sourceURL = URL(string: urlString) {
                        DispatchQueue.main.async {
                            viewModel.moveItem(from: sourceURL, toDirectory: item.url)
                        }
                    }
                }
                return true
            }
            // Context menu for operations
            .contextMenu {
                if item.isFolder {
                    Button {
                        viewModel.activeFolderTarget = item
                        viewModel.dialogTextName = ""
                        viewModel.showCreateFileDialog = true
                    } label: {
                        Label("New File...", systemImage: "doc.badge.plus")
                    }
                    
                    Button {
                        viewModel.activeFolderTarget = item
                        viewModel.dialogTextName = ""
                        viewModel.showCreateFolderDialog = true
                    } label: {
                        Label("New Folder...", systemImage: "folder.badge.plus")
                    }
                }
                
                Button {
                    viewModel.activeRenameTarget = item
                    viewModel.dialogTextName = item.name
                    viewModel.showRenameDialog = true
                } label: {
                    Label("Rename...", systemImage: "pencil")
                }
                
                Button(role: .destructive) {
                    viewModel.deleteItem(item)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            
            // Nested Children nodes
            if item.isFolder && isExpanded, let children = item.children {
                ForEach(children) { child in
                    FileRowView(item: child, viewModel: viewModel, depth: depth + 1)
                        .listRowBackground(Color.clear)
                }
            }
        }
    }
}

// MARK: - Welcome Dashboard View
struct WelcomeView: View {
    @ObservedObject var viewModel: IDEViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                VStack(spacing: 8) {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 64))
                        .foregroundColor(Dracula.purple)
                        .padding(.bottom, 8)
                    Text("xIDE")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(Dracula.foreground)
                    Text("Professional Mobile Environment powered by Monaco")
                        .font(.subheadline)
                        .foregroundColor(Dracula.comment)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Features & Capabilities")
                        .font(.headline)
                        .foregroundColor(Dracula.pink)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        WelcomeActionRow(icon: "keyboard.fill", iconColor: Dracula.cyan, title: "Dracula-themed Code Editor", description: "Tap any file in the workspace to launch the full-featured code editor. Syntax highlighting and autocomplete are enabled.")
                        
                        WelcomeActionRow(icon: "rectangle.stack.fill", iconColor: Dracula.purple, title: "Multi-Project Switcher", description: "Use the project selector at the top of the sidebar to manage multiple coding projects independently.")
                        
                        WelcomeActionRow(icon: "terminal.fill", iconColor: Dracula.green, title: "Interactive REPL Terminal", description: "Open a Python or JS file, slide up the terminal console, and type commands directly at the '$' prompt to test outputs.")
                        
                        WelcomeActionRow(icon: "safari.fill", iconColor: Dracula.pink, title: "Offline Web Previews", description: "Build HTML, CSS, and JS files, click Run, and preview your websites locally on the device offline.")
                    }
                    .padding()
                    .background(Dracula.darkBackground)
                    .cornerRadius(12)
                }
                .frame(maxWidth: 500)
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Switch or Open Files")
                        .font(.headline)
                        .foregroundColor(Dracula.pink)
                    
                    HStack(spacing: 12) {
                        Button {
                            if let mainPy = viewModel.workspaceFiles.first(where: { $0.name == "main.py" }) {
                                viewModel.selectFile(mainPy)
                            }
                        } label: {
                            Label("main.py", systemImage: "doc.text.fill")
                                .font(.footnote)
                                .fontWeight(.semibold)
                                .foregroundColor(Dracula.green)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Dracula.green.opacity(0.1))
                                .cornerRadius(8)
                        }
                        
                        Button {
                            if let indexHtml = viewModel.workspaceFiles.first(where: { $0.name == "index.html" }) {
                                viewModel.selectFile(indexHtml)
                            }
                        } label: {
                            Label("index.html", systemImage: "chevron.left.forwardslash.chevron.right")
                                .font(.footnote)
                                .fontWeight(.semibold)
                                .foregroundColor(Dracula.pink)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Dracula.pink.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
                .frame(maxWidth: 500)
            }
            .padding(.vertical, 40)
            .padding(.horizontal, 20)
        }
    }
}

struct WelcomeActionRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(iconColor)
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Dracula.foreground)
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(Dracula.comment)
                    .lineLimit(2)
            }
        }
    }
}

// MARK: - Split Layout View for Editor + Console + Web Preview
struct HSplitView<Content: View, Console: View, Preview: View>: View {
    let isConsoleVisible: Bool
    let isWebPreviewVisible: Bool
    let fileURL: URL
    
    let content: () -> Content
    let consoleContent: () -> Console
    let previewContent: () -> Preview
    
    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    content()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    let isHTML = fileURL.pathExtension.lowercased() == "html" || fileURL.pathExtension.lowercased() == "htm"
                    if isWebPreviewVisible && isHTML {
                        Divider()
                            .background(Dracula.border)
                        
                        previewContent()
                            .frame(width: geo.size.width * 0.45) // Takes 45% width on split screen
                            .transition(.move(edge: .trailing))
                    }
                }
                .frame(maxHeight: isConsoleVisible ? geo.size.height * 0.62 : .infinity)
                
                if isConsoleVisible {
                    Divider()
                        .background(Dracula.border)
                    
                    consoleContent()
                        .frame(height: geo.size.height * 0.38)
                        .transition(.move(edge: .bottom))
                }
            }
        }
    }
}

// MARK: - Terminal Console View with Interactive REPL Input
struct ConsoleView: View {
    @ObservedObject var viewModel: IDEViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Console Toolbar
            HStack {
                Label("Terminal Console", systemImage: "terminal.fill")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(Dracula.pink)
                
                Spacer()
                
                Button {
                    viewModel.clearConsole()
                } label: {
                    Label("Clear", systemImage: "trash")
                        .font(.caption)
                        .foregroundColor(Dracula.comment)
                }
                .padding(.trailing, 10)
                
                Button {
                    withAnimation {
                        viewModel.isConsoleVisible = false
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(Dracula.comment)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Dracula.darkBackground)
            
            Divider()
                .background(Dracula.border)
            
            // Console Outputs log stream
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        if viewModel.consoleOutput.isEmpty {
                            Text("Terminal idle. Type in prompt below or run active file.")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(Dracula.comment)
                        } else {
                            ForEach(viewModel.consoleOutput) { line in
                                Text(line.text)
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(line.isError ? Dracula.red : (line.text.hasPrefix("$") ? Dracula.purple : Dracula.foreground))
                                    .id(line.id)
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Dracula.border)
                .onChange(of: viewModel.consoleOutput) { newOutput in
                    if let last = newOutput.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
                .background(Dracula.border)
            
            // REPL Prompt Interactive Input Field
            HStack(spacing: 8) {
                Text("$")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(Dracula.pink)
                
                TextField("Enter command...", text: $viewModel.terminalInput, onCommit: {
                    viewModel.sendTerminalCommand()
                })
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(Dracula.foreground)
                .disableAutocorrection(true)
                .autocapitalization(.none)
                .submitLabel(.send)
                
                if !viewModel.terminalInput.isEmpty {
                    Button {
                        viewModel.sendTerminalCommand()
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 13))
                            .foregroundColor(Dracula.green)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Dracula.darkBackground)
        }
        .background(Dracula.darkBackground)
    }
}

// MARK: - Live Web Preview WKWebView Wrapper
struct WebPreviewView: UIViewRepresentable {
    let fileURL: URL
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.backgroundColor = UIColor(red: 40/255, green: 42/255, blue: 54/255, alpha: 1.0)
        webView.isOpaque = false
        webView.scrollView.bounces = true
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Load the HTML file, allowing read access to the parent Project directory
        // so relative files (CSS, JS) load offline without permissions issues
        let fileDirectory = fileURL.deletingLastPathComponent()
        uiView.loadFileURL(fileURL, allowingReadAccessTo: fileDirectory)
    }
}

// MARK: - IDE Editor Settings View
struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: IDEViewModel
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Editor Settings").foregroundColor(Dracula.pink)) {
                    HStack {
                        Text("Font Size: \(Int(viewModel.fontSize))pt")
                            .foregroundColor(Dracula.foreground)
                        Spacer()
                        Slider(value: $viewModel.fontSize, in: 10...24, step: 1)
                            .tint(Dracula.purple)
                            .frame(width: 150)
                    }
                    .listRowBackground(Dracula.darkBackground)
                }
                
                Section(header: Text("Project Workspaces").foregroundColor(Dracula.pink)) {
                    ForEach(viewModel.projects, id: \.self) { proj in
                        HStack {
                            Text(proj)
                                .foregroundColor(Dracula.foreground)
                            Spacer()
                            if proj != "Default Project" {
                                Button(role: .destructive) {
                                    viewModel.deleteProject(named: proj)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(Dracula.red)
                                }
                            } else {
                                Text("System Default")
                                    .font(.caption)
                                    .foregroundColor(Dracula.comment)
                            }
                        }
                        .listRowBackground(Dracula.darkBackground)
                    }
                }
                
                Section(header: Text("Theme (Dracula)").foregroundColor(Dracula.pink), footer: Text("The Dracula Theme is set by default to maintain focus, high contrast, and visual beauty.")) {
                    HStack {
                        Text("Default Theme")
                            .foregroundColor(Dracula.foreground)
                        Spacer()
                        Text("Dracula Theme")
                            .foregroundColor(Dracula.green)
                            .fontWeight(.bold)
                    }
                    .listRowBackground(Dracula.darkBackground)
                }
                
                Section(header: Text("About xIDE").foregroundColor(Dracula.pink)) {
                    Text("xIDE is a professional-grade development environment designed specifically for iPad and iPhone. It uses Monaco Editor (the heart of VS Code) and compiles Python locally on device using WebAssembly.")
                        .font(.caption)
                        .foregroundColor(Dracula.comment)
                        .listRowBackground(Dracula.darkBackground)
                    
                    HStack {
                        Text("Core Engine")
                            .foregroundColor(Dracula.foreground)
                        Spacer()
                        Text("Monaco 0.39.0")
                            .foregroundColor(Dracula.purple)
                    }
                    .listRowBackground(Dracula.darkBackground)
                    
                    HStack {
                        Text("Python Interpreter")
                            .foregroundColor(Dracula.foreground)
                        Spacer()
                        Text("Pyodide WASM")
                            .foregroundColor(Dracula.purple)
                    }
                    .listRowBackground(Dracula.darkBackground)
                }
            }
            .background(Dracula.background)
            .navigationTitle("Preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Dracula.pink)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
