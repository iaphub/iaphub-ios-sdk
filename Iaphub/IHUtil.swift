//
//  IHUtil.swift
//  Iaphub
//
//  Created by iaphub on 4/23/21.
//  Copyright © 2021 iaphub. All rights reserved.
//

import Foundation
import UIKit

@available(iOS 13.0, *)
extension Sequence {
    func asyncMap<T>(
        _ transform: (Element) async throws -> T
    ) async rethrows -> [T] {
        var values = [T]()

        for element in self {
            try await values.append(transform(element))
        }

        return values
    }
}

class IHUtil {
   
   /*
    * Applies the function iterator to each item in arr in series.
    */
   static func eachSeries<ArrayType, ErrorType>(arr: [ArrayType], iterator: @escaping (_ item: ArrayType, _ asyncCallback: @escaping (_ error: ErrorType?) -> Void) -> Void, finished: @escaping (_ error: ErrorType?) -> Void) {
      
      var arr = arr
      var isFinishedCalled = false
      let finishedOnce = { (error: ErrorType?) -> Void in
         if !isFinishedCalled {
             isFinishedCalled = true
             finished(error)
         }
      }

      var next: (() -> Void)?

      next = { () -> Void in
         if arr.count > 0 {
             let item = arr.remove(at: 0)
             iterator(item) { (error) -> Void in
                 if error != nil {
                     finishedOnce(error)
                 } else {
                     next!()
                 }
             }
         } else {
             finishedOnce(nil)
         }
      }

      DispatchQueue.global().async {
         next!()
      }
   }
   
   /*
    * Retry task multiple times until it succeed
    */
   static func retry(times: Int, delay: Int, task: @escaping(@escaping (Bool, IHError?, Any?) -> Void) -> Void, completion: @escaping (IHError?, Any?) -> Void) {
      task({ (shouldRetry, error, data) in
         // If there is no error it is a success
         if (error == nil) {
            completion(nil, data)
         }
         // If time left retry
         else if (times > 0 && shouldRetry == true) {
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(delay)) {
               retry(times: times - 1, delay: delay, task: task, completion: completion)
            }
         }
         // Otherwise it failed
         else {
            completion(error, data)
         }
      })
   }
   
   /**
    Get value from keychain
    */
   static func setupKeychainQueryDictionary(_ key: String) -> [String:Any] {
      // Setup default access as generic password (rather than a certificate, internet password, etc)
     let SecClass = kSecClass as String
     var keychainQueryDictionary: [String:Any] = [SecClass:kSecClassGenericPassword]
     
     // Uniquely identify this keychain accessor
     keychainQueryDictionary[kSecAttrService as String] = "iaphub"
     
     // Uniquely identify the account who will be accessing the keychain
     let encodedIdentifier: Data? = key.data(using: String.Encoding.utf8)
     
     keychainQueryDictionary[kSecAttrGeneric as String] = encodedIdentifier
     keychainQueryDictionary[kSecAttrAccount as String] = encodedIdentifier
     keychainQueryDictionary[kSecAttrSynchronizable as String] = kCFBooleanFalse
     
     return keychainQueryDictionary
   }
   
   /**
    Get value from keychain
    */
   static func getFromKeychain(_ key: String) -> String? {
      var keychainQueryDictionary = Self.setupKeychainQueryDictionary(key)
              
      // Limit search results to one
      keychainQueryDictionary[kSecMatchLimit as String] = kSecMatchLimitOne

      // Specify we want Data/CFData returned
      keychainQueryDictionary[kSecReturnData as String] = kCFBooleanTrue

      // Search
      var result: AnyObject?
      let status = SecItemCopyMatching(keychainQueryDictionary as CFDictionary, &result)

      let data = status == noErr ? result as? Data : nil
      
      return data != nil ? String(data: data!, encoding: String.Encoding.utf8) as String? : nil
   }
   
   /**
    Delete key from keychain
    */
   static func deleteFromKeychain(key: String) -> OSStatus? {
      let keychainQueryDictionary: [String:Any] = Self.setupKeychainQueryDictionary(key)
      let status: OSStatus = SecItemDelete(keychainQueryDictionary as CFDictionary)

      if status == errSecSuccess {
         return nil
      }
      else {
         return status
      }
   }
   
   /**
    Save value to keychain
    */
   static func saveToKeychain(key: String, value: String?) -> OSStatus? {
      // Delete if the value is nil
      guard let value = value else {
         return Self.deleteFromKeychain(key: key)
      }
      
      let data = value.data(using: .utf8)
      var keychainQueryDictionary: [String:Any] = Self.setupKeychainQueryDictionary(key)

      keychainQueryDictionary[kSecValueData as String] = data
      // Assign default protection - Protect the keychain entry so it's only valid after first unlock
      keychainQueryDictionary[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

      let status: OSStatus = SecItemAdd(keychainQueryDictionary as CFDictionary, nil)

      if status == errSecSuccess {
         return nil
      }
      else if status == errSecDuplicateItem {
         let SecValueData = kSecValueData as String
         let updateDictionary = [SecValueData:data]
         let status: OSStatus = SecItemUpdate(Self.setupKeychainQueryDictionary(key) as CFDictionary, updateDictionary as CFDictionary)
         
         if (status == errSecSuccess) {
            return nil
         }
         return status
      }
      
      return status
   }
   
   /**
    Save value to localstorage
    */
   static func saveToLocalstorage(key: String, value: String?) {
      let defaults = UserDefaults.standard
      
      defaults.set(value, forKey: key)
   }
   
   /**
    Get value from localstorage
    */
   static func getFromLocalstorage(_ key: String) -> String? {
      let defaults = UserDefaults.standard
      
      return defaults.string(forKey: key)
   }
   
   /**
    Delete value from localstorage
    */
   static func deleteFromLocalstorage(key: String) {
      let defaults = UserDefaults.standard
      
      return defaults.removeObject(forKey: key)
   }
   
   /**
    Parse items
   */
   static func parseItems<T: IHParsable>(data: Any?, type: T.Type, allowNull: Bool = false, failure: @escaping (Error, Dictionary<String, Any>?) -> Void) -> [T] {
      var items = [T]()
      let dic = (data as? [Dictionary<String, Any>])
      
      guard let itemsDic = dic else {
         if (!allowNull) {
            failure(IHError(IHErrors.unexpected, nil, message: "cast to array failed", silent: true), nil)
         }
         return items
      }

      for item in itemsDic {
         do {
            let item = try type.init(item)
            items.append(item)
         } catch {
            failure(error, item)
         }
      }
      return items
   }
   
   /**
    Convert ISO string to date
   */
   static func dateFromIsoString(_ str: Any?, allowNull: Bool = false, failure: ((Error) -> Void)? = nil) -> Date? {
      let strDate = str as? String
      
      if (strDate == nil) {
         if (!allowNull) {
            failure?(IHLocalizedError("date cast to string failed"))
         }
         return nil
      }
      
      guard let strDate = strDate else {
         if (!allowNull) {
            failure?(IHLocalizedError("date cast to string failed"))
         }
         return nil
      }
      
      let formatter = DateFormatter()

      formatter.calendar = Calendar(identifier: .iso8601)
      formatter.locale = Locale(identifier: "en_US_POSIX")
      formatter.timeZone = TimeZone(secondsFromGMT: 0)
      formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
      
      let date = formatter.date(from: strDate)
      
      if (date == nil) {
         failure?(IHLocalizedError("date formatter failed"))
         return nil
      }
      
      return date
   }
   
   /**
    Convert date to iso string
   */
   static func dateToIsoString(_ date: Date?) -> String? {
      guard let date = date else {
         return nil
      }
      
      let formatter = DateFormatter()

      formatter.calendar = Calendar(identifier: .iso8601)
      formatter.locale = Locale(identifier: "en_US_POSIX")
      formatter.timeZone = TimeZone(secondsFromGMT: 0)
      formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
      
      return formatter.string(from: date)
   }
   
   /**
    Get current window scene
   */
   @available(iOS 15.0, *)
   static func getCurrentWindowScene() -> UIWindowScene? {
      let application = UIApplication.value(forKey: "sharedApplication") as? UIApplication
      
      if let application = application {
         let scenes = application.connectedScenes.filter { $0.activationState == .foregroundActive }

         return scenes.first as? UIWindowScene
      }
      return nil
   }
}
