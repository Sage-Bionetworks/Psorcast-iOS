//
// LevenshteinToolsTests.swift
// PsorcastTests

// Copyright © 2019 Sage Bionetworks. All rights reserved.
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
import XCTest
import BridgeApp
@testable import Psorcast

class LevenshteinToolsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testLevenshteinDistanceBasic() {
        var Levenshtein = LevenshteinTools.levenshtein(aStr: "a", bStr: "a")
        XCTAssertEqual(0, Levenshtein)
        
        // Levenshtein is case sensitive
        Levenshtein = LevenshteinTools.levenshtein(aStr: "A", bStr: "a")
        XCTAssertEqual(1, Levenshtein)
        
        Levenshtein = LevenshteinTools.levenshtein(aStr: "ab", bStr: "ab")
        XCTAssertEqual(0, Levenshtein)
        
        Levenshtein = LevenshteinTools.levenshtein(aStr: "ab", bStr: "ba")
        XCTAssertEqual(2, Levenshtein)
        
        // Levenshtein is case sensitive
        Levenshtein = LevenshteinTools.levenshtein(aStr: "Ab", bStr: "ab")
        XCTAssertEqual(1, Levenshtein)
                
        // Levenshtein is sensitive to string length
        Levenshtein = LevenshteinTools.levenshtein(aStr: "abc", bStr: "abcd")
        XCTAssertEqual(1, Levenshtein)
        
        // Levenshtein is sensitive to order
        Levenshtein = LevenshteinTools.levenshtein(aStr: "dabc", bStr: "abcd")
        XCTAssertEqual(2, Levenshtein)
        
        // Levenshtein is great for detecting small mistakes like c instead of k
        Levenshtein = LevenshteinTools.levenshtein(aStr: "abcdefg", bStr: "abkdefg")
        XCTAssertEqual(1, Levenshtein)
    }
    
    func testLevenshteinDistanceMedications() {
        // Test the common mis-spellings of the medications
        // I had someone read me medication names and then tried
        // to spell them phonetically. This is what I got.
        
        // This data can be used to calculate a minimum Levenshtein distance threshold,
        // that can be used to determine if our search bar should should a match.
        
        var Levenshtein = LevenshteinTools.levenshtein(aStr: "Amjevita", bStr: "Amgeveta")
        XCTAssertEqual(2, Levenshtein)
        Levenshtein = LevenshteinTools.levenshtein(aStr: "Adalamue atto", bStr: "Adalimumab-atto")
        XCTAssertEqual(5, Levenshtein)
        
        Levenshtein = LevenshteinTools.levenshtein(aStr: "Cimzia", bStr: "Simja")
        XCTAssertEqual(3, Levenshtein)
        Levenshtein = LevenshteinTools.levenshtein(aStr: "Cimzia", bStr: "Simzia")
        XCTAssertEqual(1, Levenshtein)
        Levenshtein = LevenshteinTools.levenshtein(aStr: "Certolizumab pegol", bStr: "Certalazoom pegal")
        XCTAssertEqual(7, Levenshtein)
        
        Levenshtein = LevenshteinTools.levenshtein(aStr: "Cosentyx", bStr: "Cosentix")
        XCTAssertEqual(1, Levenshtein)
        Levenshtein = LevenshteinTools.levenshtein(aStr: "Secukinumab", bStr: "Sicukanumab")
        XCTAssertEqual(2, Levenshtein)
        
        Levenshtein = LevenshteinTools.levenshtein(aStr: "Cyltezo", bStr: "Syltezo")
        XCTAssertEqual(1, Levenshtein)
        Levenshtein = LevenshteinTools.levenshtein(aStr: "adalimumab-abdm", bStr: "adalamumabdm")
        XCTAssertEqual(4, Levenshtein)
        
        Levenshtein = LevenshteinTools.levenshtein(aStr: "Enbrel", bStr: "Enbral")
        XCTAssertEqual(1, Levenshtein)
        Levenshtein = LevenshteinTools.levenshtein(aStr: "Etanercept", bStr: "Etannercept")
        XCTAssertEqual(1, Levenshtein)
        Levenshtein = LevenshteinTools.levenshtein(aStr: "Embrel", bStr: "Enbrel")
        XCTAssertEqual(1, Levenshtein)
        Levenshtein = LevenshteinTools.levenshtein(aStr: "Enbel", bStr: "Enbrel")
        XCTAssertEqual(1, Levenshtein)
        Levenshtein = LevenshteinTools.levenshtein(aStr: "Enbel", bStr: "Enbre")
        XCTAssertEqual(2, Levenshtein)
        
        Levenshtein = LevenshteinTools.levenshtein(aStr: "Humira", bStr: "Humora")
        XCTAssertEqual(1, Levenshtein)
        Levenshtein = LevenshteinTools.levenshtein(aStr: "Adalimumab", bStr: "Adalamumab")
        XCTAssertEqual(1, Levenshtein)
        
        Levenshtein = LevenshteinTools.levenshtein(aStr: "Ilumya", bStr: "Ilumiya")
        XCTAssertEqual(1, Levenshtein)
        Levenshtein = LevenshteinTools.levenshtein(aStr: "Tildrakizumab-asmn", bStr: "Tildakazoomabasm")
        XCTAssertEqual(6, Levenshtein)
        
        Levenshtein = LevenshteinTools.levenshtein(aStr: "Inflectra", bStr: "Inflecktra")
        XCTAssertEqual(1, Levenshtein)
        Levenshtein = LevenshteinTools.levenshtein(aStr: "Infliximab-dyyb", bStr: "Infleximab")
        XCTAssertEqual(6, Levenshtein)
        
        Levenshtein = LevenshteinTools.levenshtein(aStr: "Orencia", bStr: "Orenca")
        XCTAssertEqual(1, Levenshtein)
        Levenshtein = LevenshteinTools.levenshtein(aStr: "abatacept", bStr: "Abatacep")
        XCTAssertEqual(2, Levenshtein)
        
        Levenshtein = LevenshteinTools.levenshtein(aStr: "Remicade", bStr: "Remecade")
        XCTAssertEqual(1, Levenshtein)
        Levenshtein = LevenshteinTools.levenshtein(aStr: "Infliximab", bStr: "Inflicimab")
        XCTAssertEqual(1, Levenshtein)
        
        Levenshtein = LevenshteinTools.levenshtein(aStr: "Renflexis", bStr: "Renflecix")
        XCTAssertEqual(2, Levenshtein)
        Levenshtein = LevenshteinTools.levenshtein(aStr: "Infliximab-abda", bStr: "Inflicimab")
        XCTAssertEqual(6, Levenshtein)
        
        Levenshtein = LevenshteinTools.levenshtein(aStr: "Siliq", bStr: "Cilix")
        XCTAssertEqual(2, Levenshtein)
        Levenshtein = LevenshteinTools.levenshtein(aStr: "Golimumab", bStr: "Golamuab")
        XCTAssertEqual(2, Levenshtein)
        
        Levenshtein = LevenshteinTools.levenshtein(aStr: "Stelara", bStr: "Stelera")
        XCTAssertEqual(1, Levenshtein)
        Levenshtein = LevenshteinTools.levenshtein(aStr: "Ustekinumab", bStr: "Ustacanumab")
        XCTAssertEqual(3, Levenshtein)
        
        Levenshtein = LevenshteinTools.levenshtein(aStr: "Taltz", bStr: "Talts")
        XCTAssertEqual(1, Levenshtein)
        Levenshtein = LevenshteinTools.levenshtein(aStr: "Ixekizumab", bStr: "Iksakizumab")
        XCTAssertEqual(3, Levenshtein)
        
        Levenshtein = LevenshteinTools.levenshtein(aStr: "Tremfya", bStr: "Tremfiya")
        XCTAssertEqual(1, Levenshtein)
        Levenshtein = LevenshteinTools.levenshtein(aStr: "Guselkumab", bStr: "Guclekumab")
        XCTAssertEqual(3, Levenshtein)
        
        Levenshtein = LevenshteinTools.levenshtein(aStr: "Carnivore Diet", bStr: "Karnivore Diet")
        XCTAssertEqual(1, Levenshtein)
        Levenshtein = LevenshteinTools.levenshtein(aStr: "Diet", bStr: "Diet")
        XCTAssertEqual(0, Levenshtein)
        
        Levenshtein = LevenshteinTools.levenshtein(aStr: "Gluten-Free Diet", bStr: "Gluten Free Diet")
        XCTAssertEqual(1, Levenshtein)
        
        Levenshtein = LevenshteinTools.levenshtein(aStr: "Ketogenic Diet", bStr: "Ketogene Diet")
        XCTAssertEqual(2, Levenshtein)
        
        Levenshtein = LevenshteinTools.levenshtein(aStr: "Pagano Diet", bStr: "Paegano Diet")
        XCTAssertEqual(1, Levenshtein)
        
        Levenshtein = LevenshteinTools.levenshtein(aStr: "Paleo Diet", bStr: "Paleo Diet")
        XCTAssertEqual(0, Levenshtein)
        
        Levenshtein = LevenshteinTools.levenshtein(aStr: "Vegan", bStr: "Vagen")
        XCTAssertEqual(2, Levenshtein)
        
        Levenshtein = LevenshteinTools.levenshtein(aStr: "Vegetarian", bStr: "Vejitarian")
        XCTAssertEqual(2, Levenshtein)
    }
    
    func testMinWordDistance() {
        // The min score should pick out the word "diet" as a perfect match
        var minScore = LevenshteinTools.minLevenshteinScore(for: "diet", titleText: "Paleo Diet", detailText: nil)
        XCTAssertEqual(0, minScore)
        
        minScore = LevenshteinTools.minLevenshteinScore(for: "di", titleText: "Paleo Diet", detailText: nil)
        XCTAssertEqual(0, minScore)
    }
}
