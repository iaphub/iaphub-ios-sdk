//
//  IHAPI.swift
//  Iaphub
//
//  Created by iaphub on 8/7/20.
//  Copyright © 2020 iaphub. All rights reserved.
//

import Foundation
import UIKit

class IHAPI {
   
   var network: IHNetwork
   var user: IHUser?
   
   init() {
      self.network = IHNetwork(endpoint: "https://api.iaphub.com/v1");
   }

   /**
    Configure
   */
   public func configure(user: IHUser) {
      self.user = user
      
      guard let sdk = self.user?.sdk else {
         return;
      }
      self.network.setHeaders(["Authorization": "ApiKey \(sdk.apiKey)"])
      self.network.setParams([
         "environment": sdk.environment,
         "platform": "ios",
         "sdk": sdk.sdk,
         "sdkVersion": sdk.sdkVersion,
         "osVersion": UIDevice.current.systemVersion
      ])
   }
   
   /**
    Set user tag
   */
   public func setUserTag(_ tags: Dictionary<String, String>, _ completion: @escaping (IHError?) -> Void) {
      guard let user = self.user, let sdk = user.sdk else {
         return completion(IHError(IHErrors.unknown, message: "api not configured"))
      }
      self.network.send(
         type: "POST",
         route: "/app/\(sdk.appId)/user/\(user.id)",
         params: tags
      ) {(err, data) -> Void in
         completion(err);
      }
   }
   
   /**
    Get user
   */
   public func getUser( _ completion: @escaping (IHError?, [String: Any]?) -> Void) {
      guard let user = self.user, let sdk = user.sdk else {
         return completion(IHError(IHErrors.unknown, message: "api not configured"), nil)
      }
      self.network.send(
         type: "GET",
         route: "/app/\(sdk.appId)/user/\(user.id)",
         params: sdk.deviceParams,
         completion
      )
   }
   
   /**
    Post receipt
   */
   public func postReceipt(_ receipt: Dictionary<String, Any>, _ completion: @escaping (IHError?, [String: Any]?) -> Void) {
      guard let user = self.user, let sdk = user.sdk else {
         return completion(IHError(IHErrors.unknown, message: "api not configured"), nil)
      }
      self.network.send(
         type: "POST",
         route: "/app/\(sdk.appId)/user/\(user.id)/receipt",
         params: receipt,
         completion
      )
   }
   
   /**
    Post receipt
   */
   public func postPricing(_ pricing: Dictionary<String, Any>, _ completion: @escaping (IHError?) -> Void) {
      guard let user = self.user, let sdk = user.sdk else {
         return completion(IHError(IHErrors.unknown, message: "api not configured"))
      }
      self.network.send(
         type: "POST",
         route: "/app/\(sdk.appId)/user/\(user.id)/pricing",
         params: pricing
      )  {(err, data) -> Void in
         completion(err);
      }
   }

   
}
