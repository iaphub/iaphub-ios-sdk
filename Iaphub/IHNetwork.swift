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
   var mock : ((String, String, Dictionary<String, Any>) -> [String: Any]?)? = nil
    
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
   public func send(type: String, route: String, params: Dictionary<String, Any> = [:], timeout: Double = 6.0, retry: Int = 2, silentLog: Bool = false, _ completion: @escaping (IHError?, [String: Any]?) -> Void) {
      // Use mock if defined
      if (self.mock != nil) {
         let mockData = self.mock?(type, route, params)
         
         if (mockData != nil) {
            return completion(nil, mockData)
         }
      }
      // Retry request up to 3 times with a delay of 1 second
      IHUtil.retry(
         times: retry,
         delay: 1,
         task: { (callback) in
            self.sendRequest(type: type, route: route, params: params, timeout: timeout) { (err, data, httpResponse) in
               // Retry request if the request failed with a network error
               if (err?.code == "network_error") {
                  callback(true, err, data)
               }
               // Retry request if the request failed with status code >= 500
               else if ((httpResponse?.statusCode ?? 0) >= 500) {
                  callback(true, err, data)
               }
               // Otherwise do not retry
               else {
                  callback(false, err, data)
               }
            }
         },
         completion: { (err, data) in
            // Send error if there is one
            if (err != nil && silentLog != true) {
               err?.send()
            }
            // Call completion
            DispatchQueue.main.async {
               completion(err, data as? [String: Any])
            }
         }
      )
   }
   
   /***************************** PRIVATE ******************************/
   
   /**
    Create GET request
   */
   private func createGetRequest(url: URL, params: Dictionary<String, Any>) throws -> URLRequest {
      // Create url params
      guard var urlParams = params as? [String: String] else {
         throw IHError(IHErrors.network_error, IHNetworkErrors.url_params_invalid)
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
         throw IHError(IHErrors.network_error, IHNetworkErrors.url_invalid)
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
   private func sendRequest(type: String, route: String, params: Dictionary<String, Any> = [:], timeout: Double, _ completion: @escaping (IHError?, [String: Any]?, HTTPURLResponse?) -> Void) {
      var infos = ["type": type, "route": route]
      
      do {
         // Create url
         guard let url = URL(string: self.endpoint + route) else {
            return completion(IHError(IHErrors.network_error, IHNetworkErrors.url_invalid, params: infos, silent: true), nil, nil)
         }
         // Create request
         let request = try (type == "GET") ? self.createGetRequest(url: url, params: params) : self.createPostRequest(url: url, params: params)
         // Set up the session
         let sessionConfig = URLSessionConfiguration.default
         sessionConfig.timeoutIntervalForResource = timeout
         let session = URLSession(configuration: sessionConfig)
         // Create task
         let task = session.dataTask(with: request) { (data, response, error) in
            // Check for any errors
            guard error == nil else {
               return completion(IHError(IHErrors.network_error, IHNetworkErrors.request_failed, message: error?.localizedDescription, params: infos, silent: true), nil, nil)
            }
            // Get http response
            guard let httpResponse = response as? HTTPURLResponse else {
               return completion(IHError(IHErrors.network_error, IHNetworkErrors.response_invalid, params: infos, silent: true), nil, nil)
            }
            // Add status code to infos
            infos["statusCode"] = "\(httpResponse.statusCode)"
            // Check we have a response
            guard let data = data else {
               return completion(IHError(IHErrors.network_error, IHNetworkErrors.response_empty, params: infos, silent: true), nil, httpResponse)
            }
            // Process the response
            do {
               // Parse JSON
               guard let responseData = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                  return completion(IHError(IHErrors.network_error, IHNetworkErrors.response_parsing_failed, params: infos, silent: true), nil, httpResponse)
               }
               // Check if the response returned an error
               if let error = responseData["error"] as? String {
                  return completion(IHError(IHErrors.server_error, IHCustomError(error, "code: \(error)"), params: infos, silent: true), nil, httpResponse)
               }
               // Otherwise the request is successful, return the data
               return completion(nil, responseData, httpResponse)
            } catch  {
               return completion(IHError(IHErrors.network_error, IHNetworkErrors.response_invalid, params: infos, silent: true), nil, httpResponse)
            }
         }
         // Launch task
         task.resume();
      } catch {
         return completion((error as? IHError) ?? IHError(IHErrors.network_error, IHNetworkErrors.unknown_exception, params: infos, silent: true), nil, nil)
      }
    }
    
}
