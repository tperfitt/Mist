//
//  List.swift
//  Mist
//
//  Created by Nindi Gill on 10/3/21.
//

import Foundation
import Yams

struct List {

    static func run(options: ListOptions) throws {
        try sanityChecks(options.exportPath)

        PrettyPrint.printHeader("SEARCH")

        switch options.platform {
        case .apple:
            PrettyPrint.print("Searching for macOS Firmware versions...")
            let firmwares: [Firmware] = HTTP.retrieveFirmwares()

            if let path: String = options.exportPath {
                if path.hasSuffix(".csv") {
                    let string: String = "Signed,Name,Version,Build,Date\n" + firmwares.map { $0.csvLine }.joined()
                    try export(path, dictionaries: firmwares.map { $0.dictionary }, csv: string)
                } else {
                    try export(path, dictionaries: firmwares.map { $0.dictionary })
                }
            }

            PrettyPrint.print(prefix: "  └─", "Found \(firmwares.count) macOS Firmwares available for download\n")
            let dateFormatter: DateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            list(firmwares, using: dateFormatter)

        case .intel:
            PrettyPrint.print("Searching for macOS Installer versions...")
            let catalogURL: String = options.catalogURL ?? Catalog.defaultURL
            let products: [Product] = HTTP.retrieveProducts(catalogURL: catalogURL)

            if let path: String = options.exportPath {
                if path.hasSuffix(".csv") {
                    let string: String? = "Identifier,Name,Version,Build,Date\n" + products.map { $0.csvLine }.joined()
                    try export(path, dictionaries: products.map { $0.dictionary }, csv: string)
                } else {
                    try export(path, dictionaries: products.map { $0.dictionary })
                }
            }

            PrettyPrint.print(prefix: "  └─", "Found \(products.count) macOS Installers available for download\n")
            let dateFormatter: DateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            list(products, using: dateFormatter)
        }
    }

    private static func sanityChecks(_ exportPath: String?) throws {

        if let path: String = exportPath {

            PrettyPrint.printHeader("SANITY CHECKS")

            guard !path.isEmpty else {
                throw MistError.missingExportPath
            }

            PrettyPrint.print("Export path is '\(path)'...")

            let url: URL = URL(fileURLWithPath: path)

            guard ["csv", "json", "plist", "yaml"].contains(url.pathExtension) else {
                throw MistError.invalidExportFileExtension
            }

            PrettyPrint.print("Export path file extension is valid...")
        }
    }

    private static func export(_ path: String, dictionaries: [[String: Any]], csv: String? = nil) throws {
        let url: URL = URL(fileURLWithPath: path)
        let directory: URL = url.deletingLastPathComponent()

        if !FileManager.default.fileExists(atPath: directory.path) {
            PrettyPrint.print("Creating parent directory '\(directory.path)'...")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        }

        switch url.pathExtension {
        case "csv":
            if let string: String = csv {
                try exportCSV(path, using: string)
            }
        case "json":
            try exportJSON(path, using: dictionaries)
        case "plist":
            try exportPropertyList(path, using: dictionaries)
        case "yaml":
            try exportYAML(path, using: dictionaries)
        default:
            break
        }
    }

    private static func exportCSV(_ path: String, using string: String) throws {
        try string.write(toFile: path, atomically: true, encoding: .utf8)
        PrettyPrint.print("Exported list as CSV: '\(path)'")
    }

    private static func exportJSON(_ path: String, using dictionaries: [[String: Any]]) throws {
        let data: Data = try JSONSerialization.data(withJSONObject: dictionaries, options: .prettyPrinted)

        guard let string: String = String(data: data, encoding: .utf8) else {
            throw MistError.invalidData
        }

        try string.write(toFile: path, atomically: true, encoding: .utf8)
        PrettyPrint.print("Exported list as JSON: '\(path)'")
    }

    private static func exportPropertyList(_ path: String, using dictionaries: [[String: Any]]) throws {
        let data: Data = try PropertyListSerialization.data(fromPropertyList: dictionaries, format: .xml, options: .bitWidth)

        guard let string: String = String(data: data, encoding: .utf8) else {
            throw MistError.invalidData
        }

        try string.write(toFile: path, atomically: true, encoding: .utf8)
        PrettyPrint.print("Exported list as Property List: '\(path)'")
    }

    private static func exportYAML(_ path: String, using dictionaries: [[String: Any]]) throws {
        let string: String = try Yams.dump(object: dictionaries)
        try string.write(toFile: path, atomically: true, encoding: .utf8)
        PrettyPrint.print("Exported list as YAML: '\(path)'")
    }

    private static func list(_ firmwares: [Firmware], using dateFormatter: DateFormatter) {

        guard let maxSignedLength: Int = firmwares.map({ $0.signedDescription }).max(by: { $0.count < $1.count })?.count,
            let maxNameLength: Int = firmwares.map({ $0.name }).max(by: { $0.count < $1.count })?.count,
            let maxVersionLength: Int = firmwares.map({ $0.version }).max(by: { $0.count < $1.count })?.count,
            let maxBuildLength: Int = firmwares.map({ $0.build }).max(by: { $0.count < $1.count })?.count else {
            return
        }

        let signedHeading: String = "Signed"
        let nameHeading: String = "Name"
        let versionHeading: String = "Version"
        let buildHeading: String = "Build"
        let dateHeading: String = "Date"
        let signedPadding: Int = max(maxSignedLength - signedHeading.count, 0)
        let namePadding: Int = max(maxNameLength - nameHeading.count, 0)
        let versionPadding: Int = max(maxVersionLength - versionHeading.count, 0)
        let buildPadding: Int = max(maxBuildLength - buildHeading.count, 0)
        let datePadding: Int = max(dateFormatter.dateFormat.count - dateHeading.count, 0)

        var string: String = signedHeading + [String](repeating: " ", count: signedPadding).joined()
        string += " │ " + nameHeading + [String](repeating: " ", count: namePadding).joined()
        string += " │ " + versionHeading + [String](repeating: " ", count: versionPadding).joined()
        string += " │ " + buildHeading + [String](repeating: " ", count: buildPadding).joined()
        string += " │ " + dateHeading + [String](repeating: " ", count: datePadding).joined()
        string += "\n" + [String](repeating: "─", count: signedHeading.count + signedPadding).joined()
        string += "─┼─" + [String](repeating: "─", count: nameHeading.count + namePadding).joined()
        string += "─┼─" + [String](repeating: "─", count: versionHeading.count + versionPadding).joined()
        string += "─┼─" + [String](repeating: "─", count: buildHeading.count + buildPadding).joined()
        string += "─┼─" + [String](repeating: "─", count: dateHeading.count + datePadding).joined()
        string += "\n"

        for firmware in firmwares {
            let signedPadding: Int = max(signedHeading.count - firmware.signedDescription.count, 0)
            let namePadding: Int = max(maxNameLength - firmware.name.count, 0)
            let versionPadding: Int = max(max(maxVersionLength, versionHeading.count) - firmware.version.count, 0)
            let buildPadding: Int = max(maxBuildLength - firmware.build.count, 0)
            let datePadding: Int = max(dateFormatter.dateFormat.count - firmware.dateDescription.count, 0)

            var line: String = firmware.signedDescription + [String](repeating: " ", count: signedPadding).joined()
            line += " │ " + firmware.name + [String](repeating: " ", count: namePadding).joined()
            line += " │ " + firmware.version + [String](repeating: " ", count: versionPadding).joined()
            line += " │ " + firmware.build + [String](repeating: " ", count: buildPadding).joined()
            line += " │ " + firmware.dateDescription + [String](repeating: " ", count: datePadding).joined()
            string += line + "\n"
        }

        print(string)
    }

    private static func list(_ products: [Product], using dateFormatter: DateFormatter) {

        guard let maxIdentifierLength: Int = products.map({ $0.identifier }).max(by: { $0.count < $1.count })?.count,
            let maxNameLength: Int = products.map({ $0.name }).max(by: { $0.count < $1.count })?.count,
            let maxVersionLength: Int = products.map({ $0.version }).max(by: { $0.count < $1.count })?.count,
            let maxBuildLength: Int = products.map({ $0.build }).max(by: { $0.count < $1.count })?.count else {
            return
        }

        let identifierHeading: String = "Identifier"
        let nameHeading: String = "Name"
        let versionHeading: String = "Version"
        let buildHeading: String = "Build"
        let dateHeading: String = "Date"
        let identifierPadding: Int = max(maxIdentifierLength - identifierHeading.count, 0)
        let namePadding: Int = max(maxNameLength - nameHeading.count, 0)
        let versionPadding: Int = max(maxVersionLength - versionHeading.count, 0)
        let buildPadding: Int = max(maxBuildLength - buildHeading.count, 0)
        let datePadding: Int = max(dateFormatter.dateFormat.count - dateHeading.count, 0)

        var string: String = identifierHeading + [String](repeating: " ", count: identifierPadding).joined()
        string += " │ " + nameHeading + [String](repeating: " ", count: namePadding).joined()
        string += " │ " + versionHeading + [String](repeating: " ", count: versionPadding).joined()
        string += " │ " + buildHeading + [String](repeating: " ", count: buildPadding).joined()
        string += " │ " + dateHeading + [String](repeating: " ", count: datePadding).joined()
        string += "\n" + [String](repeating: "─", count: identifierHeading.count + identifierPadding).joined()
        string += "─┼─" + [String](repeating: "─", count: nameHeading.count + namePadding).joined()
        string += "─┼─" + [String](repeating: "─", count: versionHeading.count + versionPadding).joined()
        string += "─┼─" + [String](repeating: "─", count: buildHeading.count + buildPadding).joined()
        string += "─┼─" + [String](repeating: "─", count: dateHeading.count + datePadding).joined()
        string += "\n"

        for product in products {
            let identifierPadding: Int = max(identifierHeading.count - product.identifier.count, 0)
            let namePadding: Int = max(maxNameLength - product.name.count, 0)
            let versionPadding: Int = max(max(maxVersionLength, versionHeading.count) - product.version.count, 0)
            let buildPadding: Int = max(maxBuildLength - product.build.count, 0)
            let datePadding: Int = max(dateFormatter.dateFormat.count - product.date.count, 0)

            var line: String = product.identifier + [String](repeating: " ", count: identifierPadding).joined()
            line += " │ " + product.name + [String](repeating: " ", count: namePadding).joined()
            line += " │ " + product.version + [String](repeating: " ", count: versionPadding).joined()
            line += " │ " + product.build + [String](repeating: " ", count: buildPadding).joined()
            line += " │ " + product.date + [String](repeating: " ", count: datePadding).joined()
            string += line + "\n"
        }

        print(string)
    }
}
