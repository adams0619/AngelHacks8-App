import MapKit
import Foundation
import UIKit

class PinAnnotation : NSObject, MKAnnotation {
    
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let color: MKPinAnnotationColor
  
    
    init (coordinate: CLLocationCoordinate2D, title: String?, color: MKPinAnnotationColor) {
        self.title = title
        self.coordinate = coordinate
        self.color = color
        
    }
    
}