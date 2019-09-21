//
//  QuizEntity.swift
//  QuizChallenge
//
//  Created by Eduardo Sanches Bocato on 21/09/19.
//  Copyright © 2019 Bocato. All rights reserved.
//

import Foundation

struct QuizEntity: Codable {
    let question: String
    let answer: [String]
}
