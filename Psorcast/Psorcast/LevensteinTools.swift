//
//  LevensteinTools.swift
//  Psorcast
//
//  Copyright © 2018-2019 Sage Bionetworks. All rights reserved.
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

class LevensteinTools {
    // return minimum value in a list of Ints
    fileprivate class func minNum(_ numbers: Int...) -> Int {
        return numbers.reduce(numbers[0], {$0 < $1 ? $0 : $1})
    }

    class func levenshtein(aStr: String, bStr: String) -> Int {
        // create character arrays
        let a = Array(aStr)
        let b = Array(bStr)

        // initialize matrix of size |a|+1 * |b|+1 to zero
        var dist = [[Int]]()
        for _ in 0...a.count {
            dist.append([Int](repeating: 0, count: b.count + 1))
        }

        // 'a' prefixes can be transformed into empty string by deleting every char
        for i in 1...a.count {
            dist[i][0] = i
        }

        // 'b' prefixes can be created from empty string by inserting every char
        for j in 1...b.count {
            dist[0][j] = j
        }

        for i in 1...a.count {
            for j in 1...b.count {
                if a[i-1] == b[j-1] {
                    dist[i][j] = dist[i-1][j-1]  // noop
                } else {
                    dist[i][j] = LevensteinTools.minNum(
                        dist[i-1][j] + 1,  // deletion
                        dist[i][j-1] + 1,  // insertion
                        dist[i-1][j-1] + 1  // substitution
                    )
                }
            }
        }

        return dist[a.count][b.count]
    }
    
    ///
    /// This function uses various phrases created from title and detail to calculate
    /// the best, or min, levenstein score for the parameters.
    /// This function favors favor prefixes, because the user will start typing word from the first letter
    ///
    class func minLevensteinScore(for searchText: String, titleText: String, detailText: String?) -> Int {
        
        if searchText.count == 0 {
            return Int.max
        }
        var minScore = Int.max

        var fullWordArray = [String]()
        // Build the list of phrases we will test levenstein score against threshold.
        for text in [titleText, detailText ?? ""] {
            // Ignore empty strings
            if text.count > 0 {
                fullWordArray.append(text)
                let splitWords = text.split(separator: " ")
                // Ignore the first word, but add all other words after that.
                if splitWords.count > 1 {
                    fullWordArray.append(contentsOf: Array(splitWords.map({ String($0) })))
                }
            }
        }
                
        for text in fullWordArray {
            // Truncate the phrase to meet length of search text to also favor prefixes.
            // Also, make everything lowercase to ignore capitalization differences.
            let treatmentText = String(text.lowercased().prefix(searchText.count))
            minScore = min(minScore, LevensteinTools.levenshtein(aStr: searchText, bStr: treatmentText))
        }
        
        return minScore
    }
}
