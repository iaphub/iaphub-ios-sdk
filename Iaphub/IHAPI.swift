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
   public func getUser(_ completion: @escaping (IHError?, [String: Any]?) -> Void) {
      var params: [String: Any] = [:]
      // Add updateDate parameter
      if (self.user.updateDate != nil) {
         params["updateDate"] = "\(Int64((self.user.updateDate!.timeIntervalSince1970 * 1000).rounded()))"
      }
      // Add deferredPurchase parameter
      if (self.user.enableDeferredPurchaseListener == false) {
         params["deferredPurchase"] = "false"
      }
      // Add lang parameter
      if (self.user.sdk.lang != "") {
         params["lang"] = self.user.sdk.lang
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
   public func login(currentUserId: String, newUserId: String, _ completion: @escaping (IHError?) -> Void) {
      self.network.send(
         type: "POST",
         route: "/app/\(self.user.sdk.appId)/user/\(currentUserId)/login",
         params: ["userId": newUserId],
         timeout: 8,
         retry: 0
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
      var timeout: Double = 35
      var params = receipt
      
      // Add lang parameter
      if (self.user.sdk.lang != "") {
         params["lang"] = self.user.sdk.lang
      }
      // Update timeout to 65 seconds for purchase context
      if (receipt["context"] as? String == "purchase") {
         timeout = 65
      }
      self.network.send(
         type: "POST",
         route: "/app/\(self.user.sdk.appId)/user/\(self.user.id)/receipt",
         params: params,
         timeout: timeout,
         completion
      )
   }
   
   /**
    Create purchase intent
   */
   public func createPurchaseIntent(_ params: Dictionary<String, Any>, _ completion: @escaping (IHError?, [String: Any]?) -> Void) {
      self.network.send(
         type: "POST",
         route: "/app/\(self.user.sdk.appId)/user/\(self.user.id)/purchase/intent",
         params: params,
         completion
      )
   }
   
   /**
    Confirm purchase intent
   */
   public func confirmPurchaseIntent(_ id: String, _ params: Dictionary<String, Any>, _ completion: @escaping (IHError?, [String: Any]?) -> Void) {
      self.network.send(
         type: "POST",
         route: "/app/\(self.user.sdk.appId)/purchase/intent/\(id)/confirm",
         params: params,
         completion
      )
   }
   
   /**
    Post log
   */
   public func postLog(_ params: Dictionary<String, Any>, _ completion: @escaping (IHError?) -> Void) {
      self.network.send(
         type: "POST",
         route: "/app/\(self.user.sdk.appId)/log",
         params: params,
         timeout: 4,
         retry: 0,
         silentLog: true
      )  {(err, data) -> Void in
         completion(err);
      }
   }

   
}
