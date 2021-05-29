//
//  IHNetwork.swift
//  Iaphub
//
//  Created by iaphub on 4/22/21.
//  Copyright © 2020 iaphub. All rights reserved.
//

import Foundation

public class IHQueueItem {
   
   var date: Date
   var data: Any
   
   init(_ data: Any) {
      self.date = Date()
      self.data = data
   }
}

public typealias IHQueueIterator = (_ item: IHQueueItem, _ completion: @escaping () -> Void) -> Void

class IHQueue {
   
   var iterator: IHQueueIterator? = nil
   var waiting: [IHQueueItem] = []
   var isRunning: Bool = false;
   var isPaused: Bool = false;
   var completionQueue: [(() -> Void)] = []
   
   init(_ iterator: @escaping IHQueueIterator) {
      self.iterator = iterator
   }
   
   public func add(_ data: Any) {
      self.waiting.append(IHQueueItem(data))
      self.run()
   }
   
   public func pause() {
      self.isPaused = true
   }
   
   public func resume(_ completion: (() -> Void)? = nil) {
      self.isPaused = false
      self.run(completion)
   }
   
   public func run(_ completion: (() -> Void)? = nil) {
      // Add completion to the queue
      if let completion = completion {
         self.completionQueue.append(completion)
      }
      // Stop here if the queue is paused or already running
      if (self.isPaused || self.isRunning) {
         return
      }
      // Get the items we're going to process, empty waiting list and mark the queue as running
      let items = self.waiting
      self.waiting = []
      self.isRunning = true
      // Execute iterator for each item
      IHUtil.eachSeries(arr: items, iterator: { (item, iteratorCompletion) -> Void in
         self.iterator?(item, { () -> Void in
            iteratorCompletion(nil)
         })
      }){ (error: Any?) -> Void in
         // Run again if there's more items in the waiting list
         if (self.waiting.count != 0) {
            self.run()
         }
         // Otherwise we're done
         else {
            // Mark the queue as not running
            self.isRunning = false;
            // Execute completion queue
            self.completionQueue.forEach({ (complete) in
               complete()
            })
            self.completionQueue = []
         }
      }
   }
   
}
