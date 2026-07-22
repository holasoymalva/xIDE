import Foundation

struct EditorHTML {
    static let content: String = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover">
    <title>xIDE Monaco Editor</title>
    <!-- Load RequireJS and Monaco Editor from CDN -->
    <script src="https://cdnjs.cloudflare.com/ajax/libs/require.js/2.3.6/require.min.js"></script>
    <!-- Pyodide for Python Execution -->
    <script src="https://cdn.jsdelivr.net/pyodide/v0.23.4/full/pyodide.js"></script>
    <style>
        html, body {
            margin: 0;
            padding: 0;
            width: 100%;
            height: 100%;
            overflow: hidden;
            background-color: #282a36; /* Dracula Theme background */
        }
        #editor-container {
            width: 100%;
            height: 100%;
        }
        /* Style scrollbar to match Dracula theme */
        ::-webkit-scrollbar {
            width: 10px;
            height: 10px;
        }
        ::-webkit-scrollbar-track {
            background: #282a36;
        }
        ::-webkit-scrollbar-thumb {
            background: #44475a;
            border-radius: 5px;
        }
        ::-webkit-scrollbar-thumb:hover {
            background: #6272a4;
        }
    </style>
</head>
<body>
    <div id="editor-container"></div>
    
    <script>
        var editor;
        var currentFileName = "";
        var currentFileLanguage = "";
        var pyodideReady = false;
        var pyodideInstance = null;

        // Configure Monaco Editor path
        require.config({ paths: { 'vs': 'https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.39.0/min/vs' }});

        require(['vs/editor/editor.main'], function() {
            // 1. Define Dracula Theme
            monaco.editor.defineTheme('dracula', {
                base: 'vs-dark',
                inherit: true,
                rules: [
                    { token: '', foreground: 'f8f8f2', background: '282a36' },
                    { token: 'comment', foreground: '6272a4', fontStyle: 'italic' },
                    { token: 'string', foreground: 'f1fa8c' },
                    { token: 'keyword', foreground: 'ff79c6' },
                    { token: 'number', foreground: 'bd93f9' },
                    { token: 'regexp', foreground: 'ffb86c' },
                    { token: 'type', foreground: '8be9fd' },
                    { token: 'class', foreground: '50fa7b' },
                    { token: 'function', foreground: '50fa7b' },
                    { token: 'variable', foreground: 'f8f8f2' },
                    { token: 'constant', foreground: 'bd93f9' },
                    { token: 'operator', foreground: 'ff79c6' },
                    { token: 'tag', foreground: 'ff79c6' },
                    { token: 'attribute.name', foreground: '50fa7b' },
                    { token: 'attribute.value', foreground: 'f1fa8c' }
                ],
                colors: {
                    'editor.background': '#282a36',
                    'editor.foreground': '#f8f8f2',
                    'editor.lineHighlightBackground': '#44475a55',
                    'editor.lineHighlightBorder': '#44475a00',
                    'editor.selectionBackground': '#44475a99',
                    'editor.inactiveSelectionBackground': '#44475a55',
                    'editorCursor.foreground': '#f8f8f0',
                    'editorWhitespace.foreground': '#3B3A32',
                    'editorIndentGuide.background': '#3B3A32',
                    'editorIndentGuide.activeBackground': '#9D550F',
                    'editorLineNumber.foreground': '#6272a4',
                    'editorLineNumber.activeForeground': '#f8f8f2',
                    'scrollbarSlider.background': '#44475a77',
                    'scrollbarSlider.hoverBackground': '#6272a4aa',
                    'scrollbarSlider.activeBackground': '#bd93f9aa',
                    'minimap.background': '#282a36'
                }
            });

            // 2. Initialize Monaco Editor
            editor = monaco.editor.create(document.getElementById('editor-container'), {
                value: 'Select or create a file to start coding...',
                language: 'plaintext',
                theme: 'dracula',
                automaticLayout: true,
                minimap: { enabled: false },
                wordWrap: 'on',
                fontSize: 16,
                fontFamily: 'SFMono-Regular, Consolas, "Liberation Mono", Menlo, Courier, monospace',
                lineHeight: 22,
                cursorBlinking: 'smooth',
                cursorSmoothCaretAnimation: 'on',
                roundedSelection: true,
                padding: { top: 8 },
                scrollbar: {
                    verticalScrollbarSize: 8,
                    horizontalScrollbarSize: 8
                },
                readOnly: true
            });

            // 3. Notify Native App that Monaco is ready
            sendMessageToNative({ type: 'ready' });

            // 4. Set change listener to sync code edits
            editor.onDidChangeModelContent(function() {
                var content = editor.getValue();
                sendMessageToNative({
                    type: 'textChanged',
                    content: content
                });
            });
        });

        // Communication Bridge Helper
        function sendMessageToNative(message) {
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.ideBridge) {
                window.webkit.messageHandlers.ideBridge.postMessage(message);
            }
        }

        // --- Functions called by Native Swift code ---

        // Open a file in the editor
        window.openFile = function(fileName, content, extension) {
            if (!editor) return;
            
            currentFileName = fileName;
            
            // Map file extension to Monaco Language IDs
            var languageMap = {
                'html': 'html',
                'htm': 'html',
                'css': 'css',
                'js': 'javascript',
                'ts': 'typescript',
                'py': 'python',
                'java': 'java',
                'class': 'java',
                'json': 'json',
                'md': 'markdown',
                'txt': 'plaintext',
                'cpp': 'cpp',
                'c': 'c',
                'swift': 'swift',
                'sh': 'shell'
            };
            
            var language = languageMap[extension] || 'plaintext';
            currentFileLanguage = language;
            
            // Set model content and language
            var oldModel = editor.getModel();
            var newModel = monaco.editor.createModel(content, language);
            editor.setModel(newModel);
            if (oldModel) oldModel.dispose();
            
            editor.updateOptions({ readOnly: false });
            
            // Focus after a short delay so the keyboard responds properly
            setTimeout(function() {
                editor.focus();
            }, 100);
        };

        // Get current code content
        window.getFileContent = function() {
            if (!editor) return "";
            return editor.getValue();
        };

        // Update font size
        window.updateFontSize = function(size) {
            if (!editor) return;
            editor.updateOptions({ fontSize: size });
        };

        // --- RUNNING CODE: Python & Javascript runners ---

        // Javascript execution runner
        window.runJavascriptCode = function(code) {
            sendMessageToNative({ type: 'consoleClear' });
            sendMessageToNative({ type: 'consoleLog', message: 'Running JavaScript...' });
            sendMessageToNative({ type: 'consoleLog', message: '----------------------------------------' });

            // Override console methods to capture script outputs
            var originalLog = console.log;
            var originalError = console.error;
            
            console.log = function() {
                var message = Array.from(arguments).map(arg => {
                    if (typeof arg === 'object') {
                        try { return JSON.stringify(arg, null, 2); } catch(e) { return String(arg); }
                    }
                    return String(arg);
                }).join(' ');
                sendMessageToNative({ type: 'consoleLog', message: message });
                originalLog.apply(console, arguments);
            };

            console.error = function() {
                var message = Array.from(arguments).map(arg => String(arg)).join(' ');
                sendMessageToNative({ type: 'consoleError', message: message });
                originalError.apply(console, arguments);
            };

            try {
                var result = window.eval(code);
                if (result !== undefined) {
                    sendMessageToNative({ type: 'consoleLog', message: '\\nResult: ' + result });
                }
            } catch (error) {
                sendMessageToNative({ type: 'consoleError', message: '\\nRuntime Error: ' + error.message });
            } finally {
                // Restore original console
                console.log = originalLog;
                console.error = originalError;
                sendMessageToNative({ type: 'consoleLog', message: '----------------------------------------' });
                sendMessageToNative({ type: 'consoleLog', message: 'Execution Finished.' });
            }
        };

        // Python execution runner using Pyodide
        window.runPythonCode = async function(code) {
            sendMessageToNative({ type: 'consoleClear' });
            sendMessageToNative({ type: 'consoleLog', message: 'Initializing Pyodide Python Engine...' });
            
            try {
                if (!pyodideInstance) {
                    pyodideInstance = await loadPyodide({
                        indexURL: "https://cdn.jsdelivr.net/pyodide/v0.23.4/full/"
                    });
                }
                
                sendMessageToNative({ type: 'consoleLog', message: 'Python Engine Ready. Executing script...' });
                sendMessageToNative({ type: 'consoleLog', message: '----------------------------------------' });
                
                // Redirect standard output and error to our console messages
                pyodideInstance.setStdout({
                    batched: function(text) {
                        sendMessageToNative({ type: 'consoleLog', message: text });
                    }
                });
                
                pyodideInstance.setStderr({
                    batched: function(text) {
                        sendMessageToNative({ type: 'consoleError', message: text });
                    }
                });
                
                await pyodideInstance.runPythonAsync(code);
                
                sendMessageToNative({ type: 'consoleLog', message: '----------------------------------------' });
                sendMessageToNative({ type: 'consoleLog', message: 'Execution Finished.' });
            } catch (error) {
                sendMessageToNative({ type: 'consoleError', message: '\\nPython Exception: ' + error.message });
                sendMessageToNative({ type: 'consoleLog', message: '----------------------------------------' });
            }
        };

        // Java runner message (explanation of iOS sandbox limits)
        window.runJavaCode = function() {
            sendMessageToNative({ type: 'consoleClear' });
            sendMessageToNative({ type: 'consoleLog', message: 'Compiling Java...' });
            sendMessageToNative({ type: 'consoleError', message: 'Error: Local Java Compilation is restricted on iOS/iPadOS due to operating system sandbox limitations (no native JVM/JIT support).' });
            sendMessageToNative({ type: 'consoleLog', message: '\\nxIDE Pro-Tip: You can use our editor for complete Java syntax validation, but execution requires a remote developer workspace (like VS Code Codespaces or Gitpod).' });
        };

        // Evaluate custom commands in the interactive console REPL
        window.evaluateTerminalCommand = async function(command, extension) {
            if (extension === 'py') {
                try {
                    if (!pyodideInstance) {
                        sendMessageToNative({ type: 'consoleLog', message: 'Initializing Pyodide Python Engine...' });
                        pyodideInstance = await loadPyodide({
                            indexURL: "https://cdn.jsdelivr.net/pyodide/v0.23.4/full/"
                        });
                        pyodideInstance.setStdout({
                            batched: function(text) {
                                sendMessageToNative({ type: 'consoleLog', message: text });
                            }
                        });
                        pyodideInstance.setStderr({
                            batched: function(text) {
                                sendMessageToNative({ type: 'consoleError', message: text });
                            }
                        });
                        sendMessageToNative({ type: 'consoleLog', message: 'Python Engine Ready.' });
                    }
                    
                    let result = await pyodideInstance.runPythonAsync(command);
                    if (result !== undefined && result !== null) {
                        sendMessageToNative({ type: 'consoleLog', message: String(result) });
                    }
                } catch (error) {
                    sendMessageToNative({ type: 'consoleError', message: 'Python Exception: ' + error.message });
                }
            } else if (extension === 'js') {
                var originalLog = console.log;
                var originalError = console.error;
                
                console.log = function() {
                    var message = Array.from(arguments).map(arg => {
                        if (typeof arg === 'object') {
                            try { return JSON.stringify(arg); } catch(e) { return String(arg); }
                        }
                        return String(arg);
                    }).join(' ');
                    sendMessageToNative({ type: 'consoleLog', message: message });
                    originalLog.apply(console, arguments);
                };

                console.error = function() {
                    var message = Array.from(arguments).map(arg => String(arg)).join(' ');
                    sendMessageToNative({ type: 'consoleError', message: message });
                    originalError.apply(console, arguments);
                };

                try {
                    var result = window.eval(command);
                    if (result !== undefined && result !== null) {
                        sendMessageToNative({ type: 'consoleLog', message: '=> ' + String(result) });
                    }
                } catch (error) {
                    sendMessageToNative({ type: 'consoleError', message: 'Error: ' + error.message });
                } finally {
                    console.log = originalLog;
                    console.error = originalError;
                }
            } else {
                sendMessageToNative({ type: 'consoleError', message: 'Error: Interactive REPL is only supported for Python (.py) and JavaScript (.js) contexts.' });
            }
        };
    </script>
</body>
</html>
"""
}
