//
//  IHError.swift
//  Iaphub
//
//  Created by iaphub on 8/27/20.
//  Copyright © 2020 iaphub. All rights reserved.
//

import Foundation
import StoreKit

@objc public class IHError: NSObject, LocalizedError {
   
   @objc public let message: String
   @objc public let code: String
   @objc public let subcode: String?
   @objc public let params: Dictionary<String, Any>
   var sent: Bool = false
   
   public var errorDescription: String? {
      get {
         return "\(self.message)"
      }
   }

   @discardableResult
   init(code: String, message: String, params: Dictionary<String, Any> = [:], silent: Bool = false) {
      self.message = message
      self.code = code
      self.subcode = nil
      self.params = params
      super.init()
      if (silent != true) {
         self.send()
      }
   }
   
   @discardableResult
   init(_ error: IHErrors, _ suberror: IHErrorProtocol? = nil, message: String? = nil, params: Dictionary<String, Any> = [:], silent: Bool = false) {
      var fullMessage = error.message
      
      self.code = error.code
      self.subcode = suberror?.code
      self.params = params
      if (suberror != nil) {
         fullMessage = fullMessage + ", " + (suberror?.message ?? "")
      }
      if (message != nil) {
         fullMessage = fullMessage + ", " + (message ?? "")
      }
      self.message = fullMessage
      super.init()
      if (silent != true) {
         self.send()
      }
   }
   
   convenience init(_ error: SKError, params: Dictionary<String, Any> = [:], silent: Bool = false) {
      var err = IHErrors.unexpected
      var suberr: IHErrorProtocol? = nil
      var message: String? = nil

      switch error.code {
         case .paymentCancelled:
            err = IHErrors.user_cancelled
            break
         case .storeProductNotAvailable:
            err = IHErrors.product_not_available
            break
         case .cloudServiceNetworkConnectionFailed:
            err = IHErrors.network_error
            suberr = IHNetworkErrors.storekit_request_failed
            break
         default:
            err = IHErrors.unexpected
            suberr = IHUnexpectedErrors.storekit
            message  = error.localizedDescription
            break
      }
      
      self.init(err, suberr, message: message)
   }

   convenience init(_ error: Error?) {
      if let error = error {
         if let skError = error as? SKError {
            self.init(skError)
            return
         }
         else {
            self.init(IHErrors.unexpected, message: error.localizedDescription)
         }
      }
      else {
         self.init(IHErrors.unexpected)
      }
   }
   
   /**
      Send error
   */
   func send() {
      if (self.sent == false) {
         self.sent = true
         self.triggerDelegate()
         self.sendLog()
      }
   }
   
   /**
    Trigger error listener
   */
   func triggerDelegate() {
      Iaphub.delegate?.didReceiveError?(err: self)
   }
   
   /**
    Send log
   */
   func sendLog() {
      // Do not send log if disabled
      if (Iaphub.shared.logs == false) {
         return
      }
      // Send request
      Iaphub.shared.user?.api?.postLog([
         "data": [
            "body": [
               "message": ["body": self.message]
            ],
            "environment": Iaphub.shared.environment,
            "platform": IHConfig.sdk,
            "code_version": IHConfig.sdkVersion,
            "framework": Iaphub.shared.sdk,
            "custom": self.params.merging([
               "osVersion": Iaphub.shared.osVersion,
               "sdkVersion": Iaphub.shared.sdkVersion,
               "code": self.code
            ]) { (_, new) in new },
            "person": ["id": Iaphub.shared.appId],
            "context": "\(Iaphub.shared.appId)/\(Iaphub.shared.user?.id ?? "")",
            "fingerprint": (self.subcode != nil) ? "\(self.code)_\(self.subcode!)" : "\(self.code)"
         ]
      ], { err in
         // No need to do anything if there is an error
      })
   }
}

class IHCustomError : IHErrorProtocol {
   
   var code: String
   var message: String
   
   init(_ code: String, _ message: String) {
      self.code = code
      self.message = message
   }
   
}
