# xIDE — Professional Minimalist IDE for iOS & iPadOS

xIDE is a sleek, lightweight, and modern native development environment designed for iPhone and iPad. Built on top of **SwiftUI** and powered by **Monaco Editor** (the engine behind VS Code) and **Pyodide (WebAssembly)**, xIDE brings desktop-class editor features, folder structures, live web previews, and offline runtimes right to your pocket.

---

## 🎨 Dracula Theme by Default
xIDE features a unified, highly optimized **Dracula Theme** across both native iOS views and the Monaco editor context. The high-contrast palette is designed to reduce eye strain, maximize readability, and look absolutely premium out of the box.

---

## 🚀 Key Features

*   **⚡ Monaco Code Editor**: Powered by the core of VS Code, providing full syntax highlighting, automatic indentation, brackets closure, text selection, and smart autocompletion.
*   **📂 Multi-Project Workspaces**: Switch between isolated workspaces from the sidebar dropdown. Create new blank projects or initialize them with templates, and delete old ones from the preferences.
*   **🛠️ Interactive REPL Terminal Console**: Toggle the terminal drawer and run commands interactively inside the running context using the command prompt (`$`).
    *   **Python**: Run mathematical formulas, import modules, and execute code locally via **Pyodide WebAssembly**.
    *   **JavaScript**: Evaluate statements in place and view variables directly in the console.
*   **📱 Offline HTML Live Previews**: Render HTML, CSS, and JS files side-by-side with split views on iPad, or slide-ins on iPhone. Works completely offline, resolving relative references automatically.
*   **🖐️ Drag & Drop Reorganization**: Long-press and drag files or folders to restructure your directories. Includes safety logic preventing recursive folder loops and updates open file paths dynamically.
*   **⚙️ Adjust Preferences**: Custom configurations to change Monaco font size dynamically.

---

## 🛠️ Architecture & Tech Stack

```
   ┌───────────────────────────────────────────────┐
   │             SwiftUI / UIKit (iOS)             │
   └───────┬───────────────────────────────┬───────┘
           │ (File Tree & Drag/Drop)       │ (Terminal Prompt)
           ▼                               ▼
   ┌───────────────┐               ┌───────────────┐
   │  FileManager  │               │ Notification  │
   │    (Local)    │               │  Center Bus   │
   └───────────────┘               └───────┬───────┘
                                           │ (Evaluate REPL)
                                           ▼
                                   ┌───────────────┐
                                   │  WKWebView    │
                                   └───────┬───────┘
                                           │ (Monaco core)
                                           ▼
                                   ┌────────────────┐
                                   │ Monaco Editor  │
                                   ├────────────────┤
                                   │  Pyodide WASM  │
                                   └────────────────┘
```

*   **SwiftUI**: Delivers a highly responsive, modern, and fluid native mobile shell.
*   **WebKit (`WKWebView`)**: Hosts the Monaco Editor instance and manages bidirectional JSON communication channels.
*   **Monaco Editor (0.39.0)**: Provides desktop-class code editing and syntax validation.
*   **Pyodide (0.23.4)**: Interprets and runs Python code fully offline inside WebAssembly workers.

---

## ⚙️ How to Build and Run

### Prerequisites
*   A Mac running macOS.
*   **Xcode 15+** installed.
*   An iOS device (iPhone or iPad) running iOS 16+, or an active Simulator target.

### Steps
1.  Clone this repository to your local Mac directory.
2.  Open the workspace project file `xIDE.xcodeproj` in Xcode.
3.  Ensure Xcode lists the `xIDE` target.
4.  Choose your target device or simulator (e.g. iPad Air, iPhone 15 Pro).
5.  Click **Run** (`Cmd + R`) to build the project.
6.  Upon first launch, xIDE will populate your active project with template files: `main.py`, `index.html`, `style.css`, `script.js`, and `Hello.java`.

---

## 📄 License
This project is open-source and available under the MIT License.
