import MapKit
import Foundation
import UIKit

class PinAnnotation : NSObject, MKAnnotation {
    
    let coordinate: CLLocationCoordinate2D
    let title: String?
  
    
    init (coordinate: CLLocationCoordinate2D, title: String?) {
        self.title = title
        self.coordinate = coordinate
        
    }
    
}