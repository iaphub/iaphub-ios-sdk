//
//  IHNetwork.swift
//  Iaphub
//
//  Created by iaphub on 8/7/20.
//  Copyright © 2020 iaphub. All rights reserved.
//

import Foundation

class IHNetwork {
    
   var endpoint : String
   var headers : Dictionary<String, String>
   var params : Dictionary<String, String>
    
    init(endpoint: String) {
      self.endpoint = endpoint
      self.headers = [
         "Accept": "application/json",
         "Content-Type": "application/json"
      ];
      self.params = [:]
    }
    
   /**
    Set the headers of the requets
   */
   public func setHeaders(_ headers: Dictionary<String, String>) -> Void {
      for key in headers.keys {
         self.headers[key] = headers[key]
      }
   }
   
   /**
    Set params of the requets
   */
   public func setParams(_ params: Dictionary<String, String>) -> Void {
      for key in params.keys {
         self.params[key] = params[key]
      }
   }
   
   /**
    Send a request
   */
   public func send(type: String, route: String, params: Dictionary<String, Any> = [:], _ completion: @escaping (IHError?, [String: Any]?) -> Void) {
      self.sendRequest(type: type, route: route, params: params) { (err, data) in
         DispatchQueue.main.async {
            completion(err, data)
         }
      }
   }
   
   /***************************** PRIVATE ******************************/
   
   /**
    Create GET request
   */
   private func createGetRequest(url: URL, params: Dictionary<String, Any>) throws -> URLRequest {
      // Create url params
      guard var urlParams = params as? [String: String] else {
         throw IHError(IHErrors.network_error, message: "get url params invalid")
      }
      for key in self.params.keys {
         urlParams[key] = self.params[key]
      }
      // Create url with params
      var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
      components.queryItems = urlParams.map { (key, value) in
         return URLQueryItem(name: key, value: value)
      }
      components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
      // Check if the url is correct
      guard let url = components.url else {
         throw IHError(IHErrors.network_error, message: "get url invalid")
      }
      // Create request
      var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 20.0)

      request.httpMethod = "GET"
      for key in headers.keys {
         request.addValue(headers[key]!, forHTTPHeaderField: key)
      }
      return request
   }
   
   /**
    Create POST request
   */
   private func createPostRequest(url: URL, params: Dictionary<String, Any>) throws -> URLRequest {
      var requestParams = params
      // Add global params
      for key in self.params.keys {
         requestParams[key] = self.params[key]
      }
      // Create request
      var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 20.0)
      let json = try JSONSerialization.data(withJSONObject: requestParams)
      
      request.httpMethod = "POST"
      request.httpBody = json
      for key in self.headers.keys {
         request.addValue(self.headers[key]!, forHTTPHeaderField: key)
      }
      return request
   }

   /**
    Send a request
   */
   private func sendRequest(type: String, route: String, params: Dictionary<String, Any> = [:], _ completion: @escaping (IHError?, [String: Any]?) -> Void) {
      do {
         // Create url
         guard let url = URL(string: self.endpoint + route) else {
            return completion(IHError(IHErrors.network_error, message: "url invalid"), nil)
         }
         // Create request
         let request = try (type == "GET") ? self.createGetRequest(url: url, params: params) : self.createPostRequest(url: url, params: params)
         // Set up the session
         let session = URLSession.shared
         // Create task
         let task = session.dataTask(with: request) { (data, response, error) in
            // Check for any errors
            guard error == nil else {
               return completion(IHError(IHErrors.network_error, message: "request failed"), nil)
            }
            // Check we have a response
            guard let data = data else {
               return completion(IHError(IHErrors.network_error, message: "response empty"), nil)
            }
            // Process the response
            do {
               // Parse JSON
               guard let responseData = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                  return completion(IHError(IHErrors.network_error, message: "response parsing failed"), nil)
               }
               // Check if the response returned an error
               if let error = responseData["error"] as? String {
                  return completion(IHError(message: "The IAPHUB server returned an error", code: error), nil)
               }
               // Otherwise the request is successful, return the data
               return completion(nil, responseData)
            } catch  {
               return completion(IHError(IHErrors.network_error, message: "response invalid"), nil)
            }
         }
         // Launch task
         task.resume();
      } catch {
         return completion(error as? IHError, nil)
      }
    }
    
}
