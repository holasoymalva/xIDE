import SwiftUI
import WebKit

// MARK: - Custom Native Scheme Handler to serve local Monaco files seamlessly without file:// sandbox restrictions
class LocalSchemeHandler: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(NSError(domain: "LocalSchemeHandler", code: 404, userInfo: nil))
            return
        }
        
        let path = url.path
        let cleanPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        
        var fileData: Data? = nil
        var mimeType = "text/html"
        
        let ext = (cleanPath as NSString).pathExtension.lowercased()
        switch ext {
        case "html", "htm": mimeType = "text/html"
        case "js": mimeType = "text/javascript"
        case "css": mimeType = "text/css"
        case "ttf": mimeType = "font/ttf"
        case "woff": mimeType = "font/woff"
        case "woff2": mimeType = "font/woff2"
        case "json": mimeType = "application/json"
        case "png": mimeType = "image/png"
        default: mimeType = "text/plain"
        }
        
        // 1. Check inside monaco-editor.bundle
        if let bundleURL = Bundle.main.url(forResource: "monaco-editor", withExtension: "bundle"),
           let monacoBundle = Bundle(url: bundleURL) {
            let resourceName = (cleanPath as NSString).deletingPathExtension
            if let fileURL = monacoBundle.url(forResource: resourceName, withExtension: ext) {
                fileData = try? Data(contentsOf: fileURL)
            }
        }
        
        // 2. Check main app bundle directly
        if fileData == nil {
            if let fileURL = Bundle.main.url(forResource: cleanPath, withExtension: nil) {
                fileData = try? Data(contentsOf: fileURL)
            }
        }
        
        // 3. Fail-safe Fallback for Editor.html or root index
        if fileData == nil && (cleanPath == "Editor.html" || cleanPath == "index.html" || cleanPath.isEmpty) {
            fileData = EditorHTML.content.data(using: .utf8)
            mimeType = "text/html"
        }
        
        if let data = fileData {
            let response = URLResponse(url: url, mimeType: mimeType, expectedContentLength: data.count, textEncodingName: "utf-8")
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        } else {
            urlSchemeTask.didFailWithError(NSError(domain: "LocalSchemeHandler", code: 404, userInfo: nil))
        }
    }
    
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        // Required protocol method
    }
}

struct EditorWebView: UIViewRepresentable {
    let fileURL: URL?
    let content: String
    let fontSize: Double
    
    let onTextChanged: (String) -> Void
    let onConsoleLog: (String) -> Void
    let onConsoleError: (String) -> Void
    let onConsoleClear: () -> Void
    let onEditorReady: () -> Void
    
    // Binding to listen to run executions
    @Binding var runTrigger: UUID?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        
        // Register custom URL scheme handler "local" for seamless offline loading
        config.setURLSchemeHandler(LocalSchemeHandler(), forURLScheme: "local")
        
        let userContentController = WKUserContentController()
        
        // Register the script message bridge
        userContentController.add(context.coordinator, name: "ideBridge")
        config.userContentController = userContentController
        
        // Allow WebGL / WebAssembly (for Pyodide)
        config.preferences.setValue(true, forKey: "developerExtrasEnabled") // For Safari debugging
        
        let webView = WKWebView(frame: .zero, configuration: config)
        context.coordinator.webView = webView
        
        webView.navigationDelegate = context.coordinator
        webView.scrollView.bounces = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        
        // Set Dracula background color on the webview wrapper to avoid white flashes
        webView.backgroundColor = UIColor(red: 40/255, green: 42/255, blue: 54/255, alpha: 1.0)
        webView.isOpaque = false
        
        // Load via custom URL scheme local://app/Editor.html
        if let localURL = URL(string: "local://app/Editor.html") {
            webView.load(URLRequest(url: localURL))
        }
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Track the currently loaded URL in coordinator to prevent re-opening the same file
        if fileURL != context.coordinator.currentLoadedURL {
            context.coordinator.currentLoadedURL = fileURL
            
            // If the editor is already ready, open the file immediately
            if context.coordinator.isEditorReady, let fileURL = fileURL {
                let fileName = fileURL.lastPathComponent
                let ext = fileURL.pathExtension.lowercased()
                context.coordinator.openFileInEditor(fileName: fileName, content: content, extension: ext)
            }
        }
        
        // Update font size if changed
        if context.coordinator.currentFontSize != fontSize {
            context.coordinator.currentFontSize = fontSize
            context.coordinator.updateFontSize(fontSize)
        }
        
        // Check if run button was pressed
        if let trigger = runTrigger, trigger != context.coordinator.lastRunTrigger {
            context.coordinator.lastRunTrigger = trigger
            executeCode(in: uiView, context: context)
        }
    }
    
    private func executeCode(in webView: WKWebView, context: Context) {
        guard let fileURL = fileURL else { return }
        let ext = fileURL.pathExtension.lowercased()
        let escapedContent = content
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "")
        
        var jsCommand = ""
        switch ext {
        case "js":
            jsCommand = "window.runJavascriptCode(\"\(escapedContent)\")"
        case "py":
            jsCommand = "window.runPythonCode(\"\(escapedContent)\").catch(function(err){ sendMessageToNative({type: 'consoleError', message: 'Execution Error: ' + err.message}); });"
        case "java":
            jsCommand = "window.runJavaCode()"
        default:
            // For HTML/Web files we trigger a live web preview
            NotificationCenter.default.post(name: Notification.Name("ShowWebPreview"), object: nil)
            return
        }
        
        webView.evaluateJavaScript(jsCommand) { _, error in
            if let error = error {
                context.coordinator.parent.onConsoleError("Execution trigger error: \(error.localizedDescription)")
            }
        }
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: EditorWebView
        weak var webView: WKWebView?
        
        var currentLoadedURL: URL?
        var currentFontSize: Double = 16.0
        var isEditorReady = false
        var lastRunTrigger: UUID?
        
        init(parent: EditorWebView) {
            self.parent = parent
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "ideBridge", let dict = message.body as? [String: Any], let type = dict["type"] as? String else {
                return
            }
            
            DispatchQueue.main.async {
                switch type {
                case "ready":
                    self.isEditorReady = true
                    self.parent.onEditorReady()
                    
                    // Open the pending file if specified
                    if let fileURL = self.parent.fileURL {
                        let fileName = fileURL.lastPathComponent
                        let ext = fileURL.pathExtension.lowercased()
                        self.openFileInEditor(fileName: fileName, content: self.parent.content, extension: ext)
                    }
                    
                case "textChanged":
                    if let newContent = dict["content"] as? String {
                        self.parent.onTextChanged(newContent)
                    }
                    
                case "consoleLog":
                    if let msg = dict["message"] as? String {
                        self.parent.onConsoleLog(msg)
                    }
                    
                case "consoleError":
                    if let err = dict["message"] as? String {
                        self.parent.onConsoleError(err)
                    }
                    
                case "consoleClear":
                    self.parent.onConsoleClear()
                    
                default:
                    break
                }
            }
        }
        
        func openFileInEditor(fileName: String, content: String, extension ext: String) {
            let escapedContent = content
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "")
            
            let js = "window.openFile(\"\(fileName)\", \"\(escapedContent)\", \"\(ext)\");"
            webView?.evaluateJavaScript(js, completionHandler: nil)
        }
        
        func updateFontSize(_ size: Double) {
            let js = "window.updateFontSize(\(size));"
            webView?.evaluateJavaScript(js, completionHandler: nil)
        }
        
        // Listen for custom console REPL commands
        @objc func handleTerminalCommand(_ notification: Notification) {
            guard let userInfo = notification.userInfo,
                  let command = userInfo["command"] as? String,
                  let fileURL = parent.fileURL else { return }
            
            let ext = fileURL.pathExtension.lowercased()
            let escapedCmd = command
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "")
            
            // Log user prompt in console
            parent.onConsoleLog("$ \(command)")
            
            let js = "window.evaluateTerminalCommand(\"\(escapedCmd)\", \"\(ext)\");"
            webView?.evaluateJavaScript(js, completionHandler: nil)
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Subscribe to terminal command notifications
            NotificationCenter.default.removeObserver(self, name: Notification.Name("EvaluateTerminalCommand"), object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(handleTerminalCommand(_:)), name: Notification.Name("EvaluateTerminalCommand"), object: nil)
        }
    }
}
