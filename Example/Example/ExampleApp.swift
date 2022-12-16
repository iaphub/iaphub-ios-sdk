//
//  ExampleApp.swift
//  Shared
//
//  Created by Work on 8/30/20.
//

import SwiftUI
import Iaphub

extension Thread {
  var isRunningXCTest: Bool {
    for key in self.threadDictionary.allKeys {
      guard let keyAsString = key as? String else {
        continue
      }

      if keyAsString.split(separator: ".").contains("xctest") {
        return true
      }
    }
    return false
  }
}

@main
struct ExampleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
           computedView()
        }
    }
   
   func computedView() -> some View {
      if Thread.current.isRunningXCTest {
         return AnyView(TestView())
      } else {
         return AnyView(StoreView())
      }
   }
}

class AppDelegate: UIResponder, UIApplicationDelegate {
   func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
      // Start IAPHUB
      Iaphub.delegate = self
      Iaphub.start(
         // The app id is available on the settings page of your app
         appId: "5e4890f6c61fc971cf46db4d",
         // The (client) api key is available on the settings page of your app
         apiKey: "SDp7aY220RtzZrsvRpp4BGFm6qZqNkNf",
         // If you want to allow purchases when the user isn't logged in (using the login method)
         // If you're listenning to IAPHUB webhooks your implementation must support users with anonymous user ids (id prefixed with 'a:')
         // This option is disabled by default, when disabled the buy method will return an error when the user isn't logged in
         allowAnonymousPurchase: true
      )
      return true
   }
   
}

extension AppDelegate: IaphubDelegate {
    
   func didReceiveUserUpdate() {
      print("-> didReceiveUserUpdate triggered in delegate")
      IAP.shared.refreshProducts()
   }
   
   func didReceiveDeferredPurchase(transaction: IHReceiptTransaction) {
      print("-> didReceiveDeferredPurchase triggered in delegate: \(transaction.getDictionary())")
   }

   func didProcessReceipt(_ err: IHError?, _ receipt: IHReceipt?) {
      print("-> didProcessReceipt triggered in delegate")
   }
   
   func didReceiveError(err: IHError) {
      print("---> didReceiveError triggered in delegate: \(err.localizedDescription)")
   }
   
   func didReceiveBuyRequest(sku: String) {
      // If this method is implemented, we must call the buy method if we want to allow the purchase
      Iaphub.buy(sku: sku, { (err, transaction) in
         
      })
   }
    
}
