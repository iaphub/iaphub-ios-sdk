//
//  ExampleApp.swift
//  Shared
//
//  Created by Work on 8/30/20.
//

import SwiftUI
import Iaphub

@main
struct ExampleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            StoreView()
        }
    }
}


class AppDelegate: UIResponder, UIApplicationDelegate {
   func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
      // Start IAPHUB
      Iaphub.start(
         // The app id is available on the settings page of your app
         appId: "5e4890f6c61fc971cf46db4d",
         // The (client) api key is available on the settings page of your app
         apiKey: "SDp7aY220RtzZrsvRpp4BGFm6qZqNkNf",
         // The environment is used to determine the webhooks configuration ('production', 'staging', 'development')
         environment: "production"
      )
      return true
   }
   
}
