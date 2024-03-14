//
//  IHConfig.swift
//  Iaphub
//
//  Created by iaphub on 7/21/21.
//  Copyright © 2021 iaphub. All rights reserved.
//

import Foundation

class IHConfig {
   // API endpoint
   static var api: String = "https://api.iaphub.com/v1"
   // Anonymous user prexix
   static var anonymousUserPrefix: String = "a:"
   // SDK platform
   static var sdk = "ios"
   // SDK version
   static var sdkVersion = "4.2.2"
   // Cache version (Increment it when cache needs to be reset because of a format change)
   static var cacheVersion = "1"
}