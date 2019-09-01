//
//  HomeController.swift
//  Translator
//
//  Created by jinxiansen on 2019/8/1.
//  Copyright © 2019 晋先森. All rights reserved.
//

import Cocoa
import CSV
import FileKit

class HomeController: NSViewController {

    @IBOutlet weak var savePathField: NSTextField!
    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var selectCSVButton: NSButton!
    @IBOutlet weak var setStorageButton: NSButton!

    @IBOutlet weak var preViewButton: NSButton!
    @IBOutlet weak var parseButton: NSButton!

    var localPath: URL?

    override func viewDidLoad() {
        super.viewDidLoad()

        setLocalizedTitles()

        let url = UserDefaults.standard.url(forKey: Keys.savePath)
        updateView(with: url)

    }

    func setLocalizedTitles() {

        title = Localized.translator
        titleLabel.stringValue = Localized.appDesc
        savePathField.placeholderString = Localized.pleaseSetTheStorageDirectoryFirst
        parseButton.title = Localized.startParsing
        setStorageButton.title = Localized.setStorageDirectory
        selectCSVButton.title = Localized.selectTheCsvFile
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        self.view.window?.title = Localized.translator
    }

    override var representedObject: Any? {
        didSet {
        }
    }

    @IBAction func openButtonTapped(_ sender: NSButton) {

        let response = openPanel.runModal()
        guard response == .OK,let _ = openPanel.url else {
//            showAlert(title: "\(Localized.failedToOpenFile)：\(response)")
            return }
    }


    @IBAction func saveButton(_ sender: NSButton) {

        let result = savePanel.runModal()
        guard result == .OK, let url = savePanel.directoryURL else {
//            showAlert(title: Localized.selectTheCsvFile)
            return }

        updateView(with: url)
        UserDefaults.standard.set(url, forKey: Keys.savePath)
    }

    @IBAction func parseButtonTapped(_ sender: NSButton) {


        guard let path = localPath else {
            showAlert(title: Localized.pleaseSetTheStorageDirectoryFirst)
            return }

        guard let url = openPanel.url else {
            showAlert(title: Localized.failedToOpenFile)
            return }

        guard let stream = InputStream(url: url) else {
            showAlert(title: Localized.pleaseSelectTheCsvFileFirst)
            return
        }

        self.parseCSVFile(stream: stream,savePath: path)
    }


    @IBAction func previewButtonTapped(_ sender: NSButton) {
        previewCSV()
    }

    func updateView(with url: URL?) {
        guard let url = url else { return }

        localPath = url
        savePathField.stringValue = url.absoluteString.urlDecoded().removeFileHeader()
    }

    /// MARK: - Lazy
    lazy var openPanel: NSOpenPanel = {

        let panel = NSOpenPanel()
        panel.title = Localized.selectTheCsvFile
        panel.allowedFileTypes = ["csv"]
        panel.isExtensionHidden = false
        panel.allowsMultipleSelection = false

        return panel
    }()

    lazy var savePanel: NSOpenPanel = {
        let panel = NSOpenPanel()
        panel.title = Localized.selectStorageDirectory
        panel.defaultButtonCell?.title = Localized.storedInThisDirectory
        panel.defaultButtonCell?.alternateTitle = Localized.choose
        panel.showsResizeIndicator = true;
        panel.canChooseDirectories = true;
        panel.canChooseFiles = false;
        panel.allowsMultipleSelection = false;
        panel.canCreateDirectories = true;

        return panel
    }()
}


// MARK: - Parse CSV
extension HomeController {

    func parseCSVFile(stream: InputStream,savePath: URL)  {

        do {
            let csv = try CSVReader(stream: stream, hasHeaderRow: true)

            guard let header = csv.headerRow else { return }
            debugPrint("表头数据：\(header)\n")

            var paths = [String]()
            let textPath = savePath.absoluteString.removeFileHeader().urlDecoded() + "localized.swift"
            try Path(textPath).createFile()
            let swiftFile = TextFile(path: Path(textPath))

            for title in header { //
                if title == header.first { continue } // 跳过第一个 key

                let fileName = (title.removeBraces() ?? "") + ".lproj"
                let directoryPath = savePath.appendingPathComponent(fileName, isDirectory: true).absoluteString.removeFileHeader().urlDecoded()
                let localizablePath = directoryPath + "Localizable.strings".urlDecoded()

                do {
                    try Path(directoryPath).createDirectory(withIntermediateDirectories: true)
                    try Path(localizablePath).createFile()
                } catch {
                    showAlert(title: "\(Localized.lprojFolderCreationFailed)：\(error.localizedDescription)")
                    return
                }
                paths.append(localizablePath)
            }

            try "struct Localized {\n" |>> swiftFile
            while csv.next() != nil {

                var key = ""
                var isAllow = true // 不论多少国际化语言，对于 localizedTitles.swift 文件每行只写一次。

                for (index,title) in header.enumerated() { //
                    if title == header.first {
                        key = csv[title] ?? ""
                        continue } // 过滤第一个 key

                    if key.isEmpty { continue }

                    let value = csv[title] ?? ""
                    let result = "\"\(key)\" = \"\(value)\";"
                    let path = paths[index - 1]
                    let readFile = TextFile(path: Path(path))

                    let locString = "   static let \(key.localizedFormat) = \"\(key)\".localized"

                    do {
                        try result |>> readFile
                        if isAllow {
                            try locString |>> swiftFile
                            isAllow = false
                        }
                    } catch {
                        showAlert(title: "\(Localized.writeFailed)：\(error)")
                        return
                    }
                }
            }
            try "}" |>> swiftFile

            debugPrint("---------------------------\n")

            stream.close()

            DispatchQueue.main.async {
                let path = savePath.absoluteString.urlDecoded().removeFileHeader()
                let result = self.showAlert(title: Localized.completed,
                                            msg: "\(Localized.filePath)： \(path)",
                                            doneTitle: Localized.open)
                if (result) {
                    NSWorkspace.shared.openFile(path)
                } else {
                    debugPrint("打开失败：\(savePath.absoluteString)")
                }
            }
        } catch {
            debugPrint(error)
            showAlert(title: error.localizedDescription)
        }
    }
}


extension HomeController {

    func previewCSV() {
        let csvPath = NSTemporaryDirectory() + "example.csv"
        debugPrint("Save path: \(csvPath)")
        let stream = OutputStream(toFileAtPath: csvPath, append: false)!

        do {
            try Path(csvPath).createFile()

            let csv = try CSVWriter(stream: stream)

            try csv.write(row: ["Key","zh-Hant(中文)","en（英文）","ko（韩文)","ja（日文）"])
            try csv.write(row: ["app.key1","CN 1","EN 1","KO 1","JP 1"])
            try csv.write(row: ["app.key2","CN 2","EN 2","KO 2","JP 2"])
            try csv.write(row: ["app.key3","CN 3","EN 3","KO 3","JP 3"])

            csv.stream.close()

            debugPrint("\(Localized.createdSuccessfully)")

            DispatchQueue.main.async {
                NSWorkspace.shared.openFile(csvPath)
            }
        } catch {
            showAlert(title: "\(Localized.creationFailed)：\(error)")
        }
    }

}

extension HomeController {
    
    @discardableResult
    func showAlert(title:String, msg:String? = nil, doneTitle: String? = nil) -> Bool {
        let alert = NSAlert.init()
        alert.messageText = title
        
        if let msg = msg {
            alert.informativeText = msg
        }
        if let done = doneTitle {
            alert.addButton(withTitle: done)
        }
        alert.addButton(withTitle: Localized.cancel)
        return alert.runModal() == .alertFirstButtonReturn
    }
}
