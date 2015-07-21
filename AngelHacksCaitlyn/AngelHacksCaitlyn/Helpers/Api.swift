/*
The MIT License (MIT)

Copyright (c) 2015 Adams, Jevin, Caitlyn, Sara

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/

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