//
//  FileManagerExtensions.swift
//  Psorcast
//
//  Created by Michael L DePhillips on 4/22/20.
//  Copyright © 2020 Sage Bionetworks. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//
// 1.  Redistributions of source code must retain the above copyright notice, this
// list of conditions and the following disclaimer.
//
// 2.  Redistributions in binary form must reproduce the above copyright notice,
// this list of conditions and the following disclaimer in the documentation and/or
// other materials provided with the distribution.
//
// 3.  Neither the name of the copyright holder(s) nor the names of any contributors
// may be used to endorse or promote products derived from this software without
// specific prior written permission. No license is granted to the trademarks of
// the copyright holders even if such marks are included in this software.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

import Foundation

extension FileManager {
    public func copyFile(at srcURL: URL, to dir: FileManager.SearchPathDirectory, filename: String) -> URL? {
        guard let directory = try? self.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            else {
            return nil
        }
        let newUrl = directory.appendingPathComponent(filename)
        if !self.copyFile(at: srcURL, to: newUrl) {
            print("File write did not work")
        }
        return newUrl
    }
    
    public func copyFile(at srcURL: URL, to dstURL: URL) -> Bool {
        do {
            if self.fileExists(atPath: dstURL.path) {
                try self.removeItem(at: dstURL)
            }
            try self.copyItem(at: srcURL, to: dstURL)
        } catch (let error) {
            print("Cannot copy item at \(srcURL) to \(dstURL): \(error)")
            return false
        }
        return true
    }
    
    public func urls(for directory: FileManager.SearchPathDirectory, skipsHiddenFiles: Bool = true ) -> [URL]? {
        guard let documentsUrl = self.urls(for: directory, in: .userDomainMask).first else {
            return nil
        }
        do {
            return try self.contentsOfDirectory(at: documentsUrl, includingPropertiesForKeys: nil, options: skipsHiddenFiles ? .skipsHiddenFiles : [])
        } catch {
            print(error)
        }
        return nil
    }
}
