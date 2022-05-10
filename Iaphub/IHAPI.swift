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
   var user: IHUser
   
   init(user: IHUser) {
      self.user = user
      self.network = IHNetwork(endpoint: IHConfig.api);
      self.network.setHeaders(["Authorization": "ApiKey \(self.user.sdk.apiKey)"])
      self.network.setParams([
         "environment": self.user.sdk.environment,
         "platform": "ios",
         "sdk": self.user.sdk.sdk,
         "sdkVersion": self.user.sdk.sdkVersion,
         "osVersion": self.user.sdk.osVersion
      ])
   }
   
   /**
    Get user
   */
   public func getUser( _ completion: @escaping (IHError?, [String: Any]?) -> Void) {
      var params: [String: Any] = [:]
      // Add updateDate
      if (self.user.updateDate != nil) {
         params["updateDate"] = "\(Int64((self.user.updateDate!.timeIntervalSince1970 * 1000).rounded())))"
      }
      // Add device params
      for (key, value) in self.user.sdk.deviceParams {
         params["params.\(key)"] = value
      }
      
      self.network.send(
         type: "GET",
         route: "/app/\(self.user.sdk.appId)/user/\(self.user.id)",
         params: params,
         completion
      )
   }
   
   /**
    Login
   */
   public func login(_ userId: String, _ completion: @escaping (IHError?) -> Void) {
      self.network.send(
         type: "POST",
         route: "/app/\(self.user.sdk.appId)/user/\(self.user.id)/login",
         params: ["userId": userId]
      ) {(err, data) -> Void in
         completion(err);
      }
   }
   
   /**
    Post tags
   */
   public func postTags(_ tags: Dictionary<String, Any>, _ completion: @escaping (IHError?) -> Void) {
      self.network.send(
         type: "POST",
         route: "/app/\(self.user.sdk.appId)/user/\(self.user.id)/tags",
         params: ["tags": tags]
      ) {(err, data) -> Void in
         completion(err);
      }
   }
   
   /**
    Post receipt
   */
   public func postReceipt(_ receipt: Dictionary<String, Any>, _ completion: @escaping (IHError?, [String: Any]?) -> Void) {
      self.network.send(
         type: "POST",
         route: "/app/\(self.user.sdk.appId)/user/\(self.user.id)/receipt",
         params: receipt,
         timeout: 45.0,
         completion
      )
   }
   
   /**
    Post receipt
   */
   public func postPricing(_ pricing: Dictionary<String, Any>, _ completion: @escaping (IHError?) -> Void) {
      self.network.send(
         type: "POST",
         route: "/app/\(self.user.sdk.appId)/user/\(self.user.id)/pricing",
         params: pricing
      )  {(err, data) -> Void in
         completion(err);
      }
   }
   
   /**
    Post log
   */
   public func postLog(_ params: Dictionary<String, Any>, _ completion: @escaping (IHError?) -> Void) {
      self.network.send(
         type: "POST",
         route: "/app/\(self.user.sdk.appId)/log",
         params: params,
         retry: 0
      )  {(err, data) -> Void in
         completion(err);
      }
   }

   
}
