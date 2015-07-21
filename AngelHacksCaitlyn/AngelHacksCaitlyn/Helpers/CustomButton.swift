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
//  CustomButton.swift
//  Glance
//
//  Created by Professional on 2015-06-09.
//  Copyright (c) 2015 Ntambwa. All rights reserved.
//

import UIKit

@IBDesignable
class CustomButton: UIButton {
    
    @IBInspectable var customBorderWidthColor: UIColor = UIColor.blueColor() {
        didSet{
            setupView()
        }
    }
    
    @IBInspectable var customTextColor: UIColor = UIColor.whiteColor() {
        didSet{
            setupView()
        }
    }
    
    @IBInspectable var roundness: CGFloat = 10.0 {
        didSet{
            setupView()
        }
    }
    @IBInspectable var customBorderWidth: CGFloat = 0.0 {
        didSet{
            setupView()
        }
    }
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }
    
    // Setup the view appearance
    private func setupView(){
        
        self.layer.cornerRadius = roundness
        self.layer.borderWidth = customBorderWidth
        self.titleLabel?.textColor = customTextColor
        self.layer.borderColor = customBorderWidthColor.CGColor
    }
    
    /*
    // Only override drawRect: if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func drawRect(rect: CGRect) {
    // Drawing code
    }
    */
    
}
