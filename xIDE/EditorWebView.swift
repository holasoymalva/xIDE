import SwiftUI
import WebKit

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
        
        // Try to locate Editor.html across all possible bundle paths
        var resolvedURL: URL? = nil
        var readAccessURL: URL = Bundle.main.bundleURL
        
        if let bundleURL = Bundle.main.url(forResource: "monaco-editor", withExtension: "bundle"),
           let monacoBundle = Bundle(url: bundleURL),
           let htmlURL = monacoBundle.url(forResource: "Editor", withExtension: "html") {
            resolvedURL = htmlURL
            readAccessURL = bundleURL
        } else if let htmlURL = Bundle.main.url(forResource: "Editor", withExtension: "html", subdirectory: "monaco-editor.bundle") {
            resolvedURL = htmlURL
            readAccessURL = htmlURL.deletingLastPathComponent()
        } else if let htmlURL = Bundle.main.url(forResource: "Editor", withExtension: "html", subdirectory: "monaco-editor") {
            resolvedURL = htmlURL
            readAccessURL = htmlURL.deletingLastPathComponent()
        } else if let htmlURL = Bundle.main.url(forResource: "Editor", withExtension: "html") {
            resolvedURL = htmlURL
            readAccessURL = Bundle.main.bundleURL
        }
        
        if let indexURL = resolvedURL {
            webView.loadFileURL(indexURL, allowingReadAccessTo: readAccessURL)
        } else {
            // Fail-safe Fallback: Load embedded EditorHTML string directly
            webView.loadHTMLString(EditorHTML.content, baseURL: URL(string: "https://cdnjs.cloudflare.com"))
        }
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Track the currently loaded URL in coordinator to prevent re-opening the same file
        if fileURL != context.coordinator.currentLoadedURL {
            context.coordinator.currentLoadedURL = fileURL
            
            if let fileURL = fileURL {
                let name = fileURL.lastPathComponent
                let fileExtension = fileURL.pathExtension.lowercased()
                
                // Escape arguments using JSON serialization (safest way to handle code strings)
                let args = [name, content, fileExtension]
                if let data = try? JSONSerialization.data(withJSONObject: args, options: []),
                   let jsonArgsString = String(data: data, encoding: .utf8) {
                    let js = "if (window.openFile) { window.openFile.apply(null, \(jsonArgsString)); }"
                    uiView.evaluateJavaScript(js, completionHandler: nil)
                }
            }
        }
        
        // Update font size if it changes
        if fontSize != context.coordinator.currentFontSize {
            context.coordinator.currentFontSize = fontSize
            let js = "if (window.updateFontSize) { window.updateFontSize(\(fontSize)); }"
            uiView.evaluateJavaScript(js, completionHandler: nil)
        }
        
        // Trigger run execution if the trigger changes
        if runTrigger != nil && runTrigger != context.coordinator.lastRunTrigger {
            context.coordinator.lastRunTrigger = runTrigger
            
            // Dispatch async back to SwiftUI to reset the runTrigger after we register it
            DispatchQueue.main.async {
                self.runTrigger = nil
            }
            
            guard let fileURL = fileURL else { return }
            let ext = fileURL.pathExtension.lowercased()
            
            // Retrieve current code content from editor and execute appropriate runner
            uiView.evaluateJavaScript("window.getFileContent()") { (result, error) in
                guard let code = result as? String else { return }
                
                if let data = try? JSONSerialization.data(withJSONObject: [code], options: []),
                   let escapedCodeArray = String(data: data, encoding: .utf8) {
                    let escapedCode = String(escapedCodeArray.dropFirst().dropLast())
                    
                    var jsCommand = ""
                    switch ext {
                    case "js":
                        jsCommand = "window.runJavascriptCode(\(escapedCode))"
                    case "py":
                        jsCommand = "window.runPythonCode(\(escapedCode))"
                    case "java":
                        jsCommand = "window.runJavaCode()"
                    default:
                        // For HTML/Web files we trigger a live web preview notification
                        NotificationCenter.default.post(name: Notification.Name("ShowWebPreview"), object: nil)
                        return
                    }
                    
                    uiView.evaluateJavaScript(jsCommand, completionHandler: nil)
                }
            }
        }
    }
    
    // MARK: - WKWebView Coordinator
    class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var parent: EditorWebView
        weak var webView: WKWebView?
        
        var currentLoadedURL: URL?
        var currentFontSize: Double = 16.0
        var lastRunTrigger: UUID?
        
        init(parent: EditorWebView) {
            self.parent = parent
            super.init()
            // Add notification observer for REPL commands
            NotificationCenter.default.addObserver(self, selector: #selector(handleTerminalCommand(_:)), name: Notification.Name("EvaluateTerminalCommand"), object: nil)
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
        
        @objc func handleTerminalCommand(_ notification: Notification) {
            guard let command = notification.userInfo?["command"] as? String,
                  let fileURL = parent.fileURL,
                  let webView = webView else { return }
            let ext = fileURL.pathExtension.lowercased()
            
            let args = [command, ext]
            if let data = try? JSONSerialization.data(withJSONObject: args, options: []),
               let jsonArgsString = String(data: data, encoding: .utf8) {
                let js = "if (window.evaluateTerminalCommand) { window.evaluateTerminalCommand.apply(null, \(jsonArgsString)); }"
                DispatchQueue.main.async {
                    webView.evaluateJavaScript(js, completionHandler: nil)
                }
            }
        }
        
        // Handle JS messages sent via window.webkit.messageHandlers.ideBridge.postMessage
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "ideBridge",
                  let body = message.body as? [String: Any],
                  let type = body["type"] as? String else {
                return
            }
            
            switch type {
            case "ready":
                parent.onEditorReady()
                // Force open the selected file since Monaco was not initialized when updateUIView first fired
                if let fileURL = parent.fileURL {
                    let name = fileURL.lastPathComponent
                    let fileExtension = fileURL.pathExtension.lowercased()
                    let args = [name, parent.content, fileExtension]
                    if let data = try? JSONSerialization.data(withJSONObject: args, options: []),
                       let jsonArgsString = String(data: data, encoding: .utf8) {
                        let js = "if (window.openFile) { window.openFile.apply(null, \(jsonArgsString)); }"
                        webView?.evaluateJavaScript(js, completionHandler: nil)
                    }
                }
                
            case "textChanged":
                if let content = body["content"] as? String {
                    parent.onTextChanged(content)
                }
                
            case "consoleLog":
                if let msg = body["message"] as? String {
                    parent.onConsoleLog(msg)
                }
                
            case "consoleError":
                if let msg = body["message"] as? String {
                    parent.onConsoleError(msg)
                }
                
            case "consoleClear":
                parent.onConsoleClear()
                
            default:
                break
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Web view finished loading core template structure, wait for Monaco to emit 'ready'
        }
    }
}
