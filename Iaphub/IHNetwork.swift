//
//  IHNetwork.swift
//  Iaphub
//
//  Created by iaphub on 8/7/20.
//  Copyright © 2020 iaphub. All rights reserved.
//

import Foundation

struct IHNetworkResponse {
    var data: [String: Any]?
    var httpResponse: HTTPURLResponse?
    
    func getHeader(_ name: String) -> String? {
        guard let response = httpResponse else {
            return nil
        }
        
        if #available(iOS 13.0, *) {
            return response.value(forHTTPHeaderField: name)
        } else {
            return response.allHeaderFields[name] as? String
        }
    }

   func hasSuccessStatusCode() -> Bool {
      return (self.httpResponse?.statusCode ?? 0) == 200
   }
   
   func hasNotModifiedStatusCode() -> Bool {
      return (self.httpResponse?.statusCode ?? 0) == 304
   }

   func hasTooManyRequestsStatusCode() -> Bool {
      return (self.httpResponse?.statusCode ?? 0) == 429
   }

   func hasServerErrorStatusCode() -> Bool {
      let statusCode = (self.httpResponse?.statusCode ?? 0)

      return statusCode >= 500 && statusCode < 600
   }
}

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
   public func send(type: String, route: String, params: Dictionary<String, Any> = [:], headers: Dictionary<String, String> = [:], timeout: Double = 8.0, retry: Int = 2, silentLog: Bool = false, _ completion: @escaping (IHError?, IHNetworkResponse?) -> Void) {
      // Use mock if defined
      if (self.mock != nil) {
         let mockData = self.mock?(type, route, params)
         
         if (mockData != nil) {
            return completion(nil, IHNetworkResponse(data: mockData, httpResponse: nil))
         }
      }
      // Retry request up to 3 times with a delay of 1 second
      IHUtil.retry(
         times: retry,
         delay: 1,
         task: { (callback) in
            self.sendRequest(type: type, route: route, params: params, headers: headers, timeout: timeout) { (err, networkResponse) in
               // Retry request if we have no response
               if (networkResponse == nil) {
                  callback(true, err, networkResponse)
               }
               // Retry request if we have a 5XX status code
               else if (networkResponse?.hasServerErrorStatusCode() == true) {
                  callback(true, err, networkResponse)
               }
               // Otherwise do not retry
               else {
                  callback(false, err, networkResponse)
               }
            }
         },
         completion: { (err, networkResponse) in
            let networkResponse = networkResponse as? IHNetworkResponse
            
            // Send error if there is one
            if (err != nil && silentLog != true && networkResponse?.hasTooManyRequestsStatusCode() != true) {
               err?.send()
            }
            // Call completion
            DispatchQueue.main.async {
               completion(err, networkResponse)
            }
         }
      )
   }
   
   /***************************** PRIVATE ******************************/
   
   /**
    Create GET request
   */
   private func createGetRequest(url: URL, params: Dictionary<String, Any>, headers: Dictionary<String, String>) throws -> URLRequest {
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
      var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)

      request.httpMethod = "GET"
      
      // Add default headers
      for key in self.headers.keys {
         request.addValue(self.headers[key]!, forHTTPHeaderField: key)
      }
      // Add custom headers
      for key in headers.keys {
         request.addValue(headers[key]!, forHTTPHeaderField: key)
      }
      
      return request
   }
   
   /**
    Create POST request
   */
   private func createPostRequest(url: URL, params: Dictionary<String, Any>, headers: Dictionary<String, String>) throws -> URLRequest {
      var requestParams = params
      // Add global params
      for key in self.params.keys {
         requestParams[key] = self.params[key]
      }
      // Create request
      var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)
      let json = try JSONSerialization.data(withJSONObject: requestParams)
      
      request.httpMethod = "POST"
      request.httpBody = json
      
      // Add default headers
      for key in self.headers.keys {
         request.addValue(self.headers[key]!, forHTTPHeaderField: key)
      }
      // Add custom headers
      for key in headers.keys {
         request.addValue(headers[key]!, forHTTPHeaderField: key)
      }

      return request
   }

   /**
    Send a request
   */
   private func sendRequest(type: String, route: String, params: Dictionary<String, Any> = [:], headers: Dictionary<String, String> = [:], timeout: Double, _ completion: @escaping (IHError?, IHNetworkResponse?) -> Void) {
      let startTime = (Date().timeIntervalSince1970 * 1000).rounded()
      var infos = ["type": type, "route": route]
      
      do {
         // Create url
         guard let url = URL(string: self.endpoint + route) else {
            return completion(IHError(IHErrors.network_error, IHNetworkErrors.url_invalid, params: infos, silent: true), nil)
         }
         // Create request
         let request = try (type == "GET") ? 
            self.createGetRequest(url: url, params: params, headers: headers) : 
            self.createPostRequest(url: url, params: params, headers: headers)
         // Set up the session
         let sessionConfig = URLSessionConfiguration.default
         sessionConfig.timeoutIntervalForResource = timeout
         let session = URLSession(configuration: sessionConfig)
         // Create task
         let task = session.dataTask(with: request) { (data, response, error) in
            // Add duration to infos
            let endTime = (Date().timeIntervalSince1970 * 1000).rounded()
            infos["duration"] = "\(endTime - startTime)"
            // Check for any errors
            guard error == nil else {
               return completion(IHError(IHErrors.network_error, IHNetworkErrors.request_failed, message: error?.localizedDescription, params: infos, silent: true), nil)
            }
            // Get http response
            guard let httpResponse = response as? HTTPURLResponse else {
               return completion(IHError(IHErrors.network_error, IHNetworkErrors.response_invalid, params: infos, silent: true), nil)
            }
            // Add status code to infos
            infos["statusCode"] = "\(httpResponse.statusCode)"
            // Create network response
            var networkResponse = IHNetworkResponse(data: nil, httpResponse: httpResponse)
            // Return response on not modified status code
            if (networkResponse.hasNotModifiedStatusCode() == true) {
               return completion(nil, networkResponse)
            }
            // Return error if we did not receive a 200 status code
            if (!networkResponse.hasSuccessStatusCode() == true) {
               return completion(IHError(IHErrors.network_error, IHNetworkErrors.status_code_error, params: infos, silent: true), networkResponse)
            }
            // Check we have a response
            guard let data = data else {
               return completion(IHError(IHErrors.network_error, IHNetworkErrors.response_empty, params: infos, silent: true), networkResponse)
            }
            // Process the response
            do {
               // Parse JSON
               guard let responseData = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                  return completion(IHError(IHErrors.network_error, IHNetworkErrors.response_parsing_failed, params: infos, silent: true), networkResponse)
               }
               // Add data to response
               networkResponse.data = responseData
               // Check if the response returned an error
               if let error = responseData["error"] as? String {
                  return completion(IHError(IHErrors.server_error, IHCustomError(error, "code: \(error)"), params: infos, silent: true), networkResponse)
               }
               // Return the network response
               return completion(nil, networkResponse)
            }
            catch {
               return completion(IHError(IHErrors.network_error, IHNetworkErrors.response_invalid, params: infos, silent: true), networkResponse)
            }
         }
         // Launch task
         task.resume();
      } catch {
         return completion((error as? IHError) ?? IHError(IHErrors.network_error, IHNetworkErrors.unknown_exception, params: infos, silent: true), nil)
      }
   }
    
}
