//
//  IaphubSDKTests.swift
//  IaphubSDKTests
//
//  Created by Work on 8/7/20.
//  Copyright © 2020 iaphub. All rights reserved.
//

import XCTest
import StoreKitTest
@testable import Iaphub

class IaphubTests: XCTestCase {
   
   override func setUp() {
      super.setUp()
      Iaphub.start(
         appId: "5e4890f6c61fc971cf46db4d",
         apiKey: "SDp7aY220RtzZrsvRpp4BGFm6qZqNkNf"
      )
   }

}
