//
//  String+Ext.swift
//  Translator
//
//  Created by jinxiansen on 2019/8/1.
//  Copyright © 2019 晋先森. All rights reserved.
//

import Foundation

extension String {

    var localized: String {
        return NSLocalizedString(self, comment: "")
    }

    func urlEncoded() -> String {
        let encodeUrlString = self.addingPercentEncoding(withAllowedCharacters:
            .urlQueryAllowed)
        return encodeUrlString ?? ""
    }

    func urlDecoded() -> String {
        return self.removingPercentEncoding ?? ""
    }

    func removeFileHeader() -> String {
        return replacingOccurrences(of: "file://", with: "")
    }

    func removeBraces() -> String? {
        return replacingOccurrences(of: "（", with: "(").components(separatedBy: "(").first
    }

    var localizedFormat: String {
        return self.replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: "，", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .components(separatedBy: " ")
            .map({ $0.localizedCapitalized })
            .joined(separator: "")
            .firstCharLower
    }

    var firstCharLower: String {

        guard let chr = self.first else { return self }

        let str = String(chr)
        let upper = str.lowercased()
        if upper != str {
            let result = upper + self[1..<self.count]
            return result
        }
        return self
    }


    subscript (r: Range<Int>) -> String {
        let start = self.index(self.startIndex, offsetBy: r.lowerBound, limitedBy: self.endIndex) ?? self.endIndex
        let end = self.index(self.startIndex, offsetBy: r.upperBound, limitedBy: self.endIndex) ?? self.endIndex
        return String(self[start..<end])
    }

    subscript (n:Int) -> String {
        return self[n..<n+1]
    }
    subscript (str:String) -> Range<Index>? {
        return self.range(of: str)
    }
}
