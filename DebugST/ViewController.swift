//
//  ViewController.swift
//  DebugST
//
//  Created by iOS BTS on 3/14/19.
//  Copyright © 2019 BlueTrailSoft. All rights reserved.
//

import Cocoa

class ViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {

    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var envComboBox: NSComboBox!
    @IBOutlet weak var loadingBox: NSBox!

    let baseUrls: [(key: String, value: URL)] = [
        "btsqa1": URL(string: "https://apiqa.onlinecu.com/btsqa1/api/Configuration")!,
        "btsqa2": URL(string: "https://apiqa.onlinecu.com/btsqa2/api/Configuration")!,
        "dev": URL(string: "https://apiqa.onlinecu.com/dev/api/Configuration")!,
        "qa": URL(string: "https://apiqa.onlinecu.com/sharetec83/api/Configuration")!,
        "beta1": URL(string: "https://apiqa.onlinecu.com/staging1/api/Configuration")!,
        "beta2": URL(string: "https://apiqa.onlinecu.com/staging2/api/Configuration")!,
        "bsdc": URL(string: "https://bsdcapi.onlinecu.com/bsdc-test/api/Configuration")!
        ].sorted(by: { return $0.key > $1.key})
    var configurationList: [(key: String, value: String)] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        envComboBox.addItems(withObjectValues: baseUrls.map({ return $0.key }))
        envComboBox.selectItem(at: 0)
        hideLoading()
        tableView.delegate = self
        tableView.dataSource = self
        reloadTableWithURL(url: baseUrls.first?.value)
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    @IBAction func reloadBtn(_ sender: Any) {
        let envs = baseUrls.filter({ return $0.key == baseUrls[envComboBox.indexOfSelectedItem].key })
        guard envs.count > 0 else {
            // Alert user invalid env
            dialogOK(text: "Invalid Enviroment. Choose: \(baseUrls.map({ return $0.key }))")
            return
        }
        reloadTableWithURL(url: envs.first?.value)
    }

    func reloadTableWithURL(url: URL?) {
        guard let safeURL = url else {
            // Generic error alert
            return
        }

        let request : NSMutableURLRequest = NSMutableURLRequest()
        request.url = safeURL
        request.httpMethod = "GET"
        let session = URLSession.shared
        displayLoading()
        let task = session.dataTask(with: request as URLRequest, completionHandler: {data, response, error -> Void in
            print("Response: \(String(describing: response))")
            self.hideLoading()
            if let safeData = data {
                do {
                    let jsonResult = try JSONSerialization.jsonObject(with: safeData) as? [String: String]

                    if let safeJsonResult = jsonResult {
                        // process jsonResult
                        DispatchQueue.main.async {
                            self.configurationList = safeJsonResult.filter({ return $0.key.lowercased().contains("color") && !$0.key.contains("web")}).sorted(by: { return $0.key > $1.key })
                            self.tableView.reloadData()
                        }
                    } else {
                        // couldn't load JSON, look at error
                    }
                } catch (let error) {
                    // network error
                    print(error.localizedDescription)
                }
            }
        })

        task.resume()
    }

    func displayLoading() {
        DispatchQueue.main.async {
            self.loadingBox.isHidden = false
        }
    }

    func hideLoading() {
        DispatchQueue.main.async {
            self.loadingBox.isHidden = true
        }
    }

    func dialogOK(text: String) {
        let alert = NSAlert()
        alert.informativeText = text
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return configurationList.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "cellId"), owner: self) as? NSTextField {
            configureCellAt(column: tableColumn, row: row, cell: cell)
            return cell
        }

        let result = NSTextField(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
        configureCellAt(column: tableColumn, row: row, cell: result)

        return result
    }

    func configureCellAt(column tableColumn: NSTableColumn?, row: Int, cell: NSTextField) {
        if tableColumn == tableView.tableColumns[0] {
            cell.stringValue = configurationList[row].key
        } else if tableColumn == tableView.tableColumns[1] {
            cell.stringValue = ""
            cell.backgroundColor = colorFromHex(hexString: configurationList[row].value, alpha: 1.0)
        } else {
            cell.stringValue = configurationList[row].value
        }
    }

    /* hexString format is ARGB, ex: #FFFFFFFF will create a white color with alpha = 1*/
    func colorFromHex(hexString: String, alpha originalAlpha: CGFloat) -> NSColor {
        var colorString: String = hexString
        var finalAlpha: CGFloat = originalAlpha
        if hexString.contains("type") {
            do {
                print(hexString)
                let json = try JSONSerialization.jsonObject(with: hexString.data(using: .utf8)!) as? [String: Any]
                colorString = (json?["start_color"] as! String)
                let alphaStr = (json?["alpha"] as! NSNumber)
                finalAlpha = CGFloat(alphaStr.floatValue)
            } catch (let error) {
                print(error.localizedDescription)
                DispatchQueue.main.async {
                    self.dialogOK(text: error.localizedDescription + "HEX String: " + hexString)
                }
            }
        }
        let hex = colorString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt32()
        Scanner(string: hex).scanHexInt32(&int)
        let alpha, redColor, greenColor, blueColor: UInt32
        switch hex.count {
        case 3: // RGB (12-bit)
            (alpha, redColor, greenColor, blueColor) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (alpha, redColor, greenColor, blueColor) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (alpha, redColor, greenColor, blueColor) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (alpha, redColor, greenColor, blueColor) = (255, 0, 0, 0)
        }
        return NSColor(red: CGFloat(redColor) / 255,
                  green: CGFloat(greenColor) / 255,
                  blue: CGFloat(blueColor) / 255,
                  alpha: finalAlpha)
    }
}

