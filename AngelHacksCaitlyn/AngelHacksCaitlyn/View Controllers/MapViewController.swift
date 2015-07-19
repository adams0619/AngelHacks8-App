//
//  MapViewController.swift
//  AngelHacksCaitlyn
//
//  Created by Caitlyn Chen on 7/18/15.
//  Copyright (c) 2015 Caitlyn Chen. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation

class MapViewController: UIViewController, CLLocationManagerDelegate, UISearchBarDelegate, MKMapViewDelegate {

    @IBOutlet weak var mapView: MKMapView!
    
    var mapAnnoations: [PinAnnotation] = []
    var locationManager = CLLocationManager()
    var rackLocations = NSMutableArray()
    
    override func viewWillAppear(animated: Bool) {
        // Make REST API Call here
        println("Started to REST API CAll")

        request(.GET, "http://date.jsontest.com", parameters: nil)
            .responseJSON { (request, response, data, error) -> Void in
//                println("error \(request)")
                 data! as! NSDictionary
                println("Data: \(data)")
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        locationManager.delegate = self
        mapView.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        
        getCoordinates()
        // Do any additional setup after loading the view.

        
    }
    
    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
        
        var userLocation : CLLocation = locations[0] as! CLLocation
        
        //self.mapView.addAnnotation(point)
        
        let location = CLLocationCoordinate2D(latitude: userLocation.coordinate.latitude, longitude: userLocation.coordinate.longitude)
        
        let span = MKCoordinateSpanMake(0.05, 0.05)
        
        let region = MKCoordinateRegion(center: location, span: span)
        
        mapView.setRegion(region, animated: true)
        
        locationManager.stopUpdatingLocation()
        
                
    }
    
    
    func mapView(mapView: MKMapView!, viewForAnnotation annotation: MKAnnotation!) -> MKAnnotationView! {
        let annotation1 = self.mapAnnoations[0]
        let identifier = "pin"
        var view: MKPinAnnotationView
        if let dequeuedView = mapView.dequeueReusableAnnotationViewWithIdentifier(identifier) as? MKPinAnnotationView{
            dequeuedView.annotation = annotation1
            view = dequeuedView
        } else {
            view = MKPinAnnotationView(annotation: annotation1, reuseIdentifier:identifier)
            view.calloutOffset = CGPoint(x: -5, y: 5)
            view.pinColor = MKPinAnnotationColor.Purple
            
        }
        
        return view
    }
    

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func getCoordinates () {
//        var copyLoc = ["37.75389824, 122.47888473"]
//        var testString = copyLoc.rangeOfString("(37")!.startIndex
//        var nextTest: String = String(stringInterpolationSegment: testString)
//        var startInd: Int = nextTest.toInt()! + 1
//        var endInd = 0 - (count(copyLoc) - startInd) + 11
//        var newString: String = copyLoc.substringWithRange(Range<String.Index>(start: advance(copyLoc.startIndex, startInd), end: advance(copyLoc.endIndex, endInd)))
//        println(newString)
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    
}
