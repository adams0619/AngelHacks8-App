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
