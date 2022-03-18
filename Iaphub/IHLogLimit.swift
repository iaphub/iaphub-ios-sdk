//
//  IHLogLimit.swift
//  Iaphub
//
//  Created by iaphub on 3/17/22.
//  Copyright © 2022 iaphub. All rights reserved.
//

import Foundation

class IHLogLimit {
   
   static let shared = IHLogLimit()
   
   var timeLimit: Double = 60
   var countLimit: Double = 10
   var count: Double = 0
   var time: Date = Date()
   
   private init() {
      
   }
   
   static func isAllowed() -> Bool {
      if ((Date()).timeIntervalSince1970 > self.shared.time.timeIntervalSince1970 + self.shared.timeLimit) {
         self.shared.count = 0
         self.shared.time = Date()
      }
      
      self.shared.count += 1
      
      return self.shared.count <= self.shared.countLimit
   }
   
}
