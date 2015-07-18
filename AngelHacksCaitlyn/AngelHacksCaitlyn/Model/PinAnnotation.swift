import MapKit
import Foundation
import UIKit

class PinAnnotation : NSObject, MKAnnotation {
    
    let coordinate: CLLocationCoordinate2D
  
    
    init (coordinate: CLLocationCoordinate2D) {
        
        self.coordinate = coordinate
        
    }
    
}