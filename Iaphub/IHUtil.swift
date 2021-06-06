//
//  IHUtil.swift
//  Iaphub
//
//  Created by Work on 4/23/21.
//  Copyright © 2021 iaphub. All rights reserved.
//

import Foundation

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
}
