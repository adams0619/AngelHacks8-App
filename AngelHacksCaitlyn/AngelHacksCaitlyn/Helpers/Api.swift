//
//  RestApiManager.swift
//  AngelHacksCaitlyn
//
//  Created by Adams Ombonga on 7/18/15.
//  Copyright (c) 2015 Caitlyn Chen. All rights reserved.
//

import UIKit
import Foundation

class Api: NSObject {
    
    let apiEndPoint = "endpoint"
    let apiUrl:String!
    let consumerKey:String!
    let consumerSecret:String!
    
    var returnData = [:]
    
    override init() {
        self.apiUrl = "http://httpbin.org/get"
        
        // only used for authetication
        self.consumerKey = "my consumer key"
        self.consumerSecret = "my consumer secret"
    }
    
    func getData() -> NSDictionary{
        return makeCall("orders")
    }
    
    func makeCall(section:String) -> NSDictionary {
        
//        let params = ["consumer_key":"key", "consumer_secret":"secret"]
        
        request(.GET, "\(self.apiUrl)/\(self.apiEndPoint)", parameters: nil)
//            .authenticate(user: self.consumerKey, password: self.consumerSecret)
            .responseJSON { (request, response, data, error) -> Void in
                println("error \(request)")
                self.returnData = data! as! NSDictionary
        }
        return self.returnData
    }
}