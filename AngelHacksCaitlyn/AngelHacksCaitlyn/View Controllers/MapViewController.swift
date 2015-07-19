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
import Foundation

class MapViewController: UIViewController, CLLocationManagerDelegate, UISearchBarDelegate, MKMapViewDelegate {

    var image: UIImage?
    
    var searchController:UISearchController!
    var localSearchRequest:MKLocalSearchRequest!
    var localSearch:MKLocalSearch!
    var localSearchResponse:MKLocalSearchResponse!
    var pointAnnotation:MKPointAnnotation!
    var pinAnnotationView:MKPinAnnotationView!
    var annotation:MKAnnotation!
    
    var buttonTapped: Bool = false

    var user: String?
    @IBOutlet weak var button: UIBarButtonItem!
    
    
    override func shouldPerformSegueWithIdentifier(identifier: String?, sender: AnyObject?) -> Bool {
        buttonTapped = true
        if let ident = identifier {
            if ident == "toLogin" {
                if buttonTapped == true {
                    
                    var bike: PinAnnotation = PinAnnotation(coordinate: coord!, title: "my bike", color: MKPinAnnotationColor.Green)
                    self.mapAnnoations.append(bike)
                    self.mapView.addAnnotation(bike)
                    
                    return true
                }
            }
        }
        
        return false
        
    }
    
    
    
    @IBAction func bikeTapped(sender: AnyObject) {
        
//        let storyboard = UIStoryboard(name: "Main", bundle: nil)
//        let firstStart = storyboard.instantiateViewControllerWithIdentifier("first") as! FirstStartViewController
//         self.presentViewController(firstStart, animated: true, completion: nil)

        //buttonTapped = true
        
//        var bike: PinAnnotation = PinAnnotation(coordinate: coord!, title: "my bike", color: MKPinAnnotationColor.Green)
//        self.mapAnnoations.append(bike)
//        self.mapView.addAnnotation(bike)
        

    }

    
    

    
    @IBAction func searchBar(sender: AnyObject) {
        searchController = UISearchController(searchResultsController: nil)
        searchController.hidesNavigationBarDuringPresentation = false
        self.searchController.searchBar.delegate = self
        presentViewController(searchController, animated: true, completion: nil)

    }
    @IBOutlet weak var mapView: MKMapView!
    
    
    var mapAnnoations: [PinAnnotation] = []
    var lat: [Double] = []
    var long: [Double] = []
    var i = 0
    var coordinates: [CLLocationCoordinate2D] = []
    
    var locationManager = CLLocationManager()
    

    override func viewWillAppear(animated: Bool) {
        
    }
    
    func finishedDownload () {
        println(lat.count)
        println(long.count)
    }

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        locationManager.delegate = self
        mapView.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        
        
        // Make REST API Call here
        func calculateBoundingbox(lat:Double, lon: Double, resolution: Double, width: Double, height: Double) -> [String: Double] {
            var ret = ["left": 0.0, "bottom": 0.0, "right": 0.0, "top": 0.0]
            let halfWDeg: Double = (width * resolution)/2
            let halfHDeg: Double = (width * resolution)/2
            ret["left"] = lon - halfWDeg
            ret["bottom"] = lat - halfHDeg
            ret["right"] = lon + halfWDeg
            ret["top"] = lat + halfHDeg
            return ret
        }
        
        //println("Started to REST API CAll")
        let url = "https://mobileraj.cloudant.com/sfbikedata/_all_docs?include_docs=true&limit=700"
        request(.GET, url, parameters: nil)
            .responseJSON { (request, response, data, error) -> Void in
                if(error != nil) {
                    NSLog("Error: \(error)")
                    //println(request)
                    //println(response)
                }
                else {
                    NSLog("Success: \(url)")
                    let path = [1,"list",2,"name"]
                    var json = JSON(data!)
                    let locations = json["rows"]
                    let transaction = locations["doc"]
                    if let locArray = json["rows"].array {
                        for cusDict in locArray {
                            var coords = cusDict["doc"]["coords"].stringValue
                            var latLongArr = coords.componentsSeparatedByString(",")
                            if (count(coords) > 10) {
                                var copyLoc = coords
                                var testString = copyLoc.rangeOfString("(37")!.startIndex
                                var nextTest: String = String(stringInterpolationSegment: testString)
                                var startInd: Int = nextTest.toInt()! + 1
                                var endInd = 0 - (count(copyLoc) - startInd) + 11
                                var newString: String = copyLoc.substringWithRange(Range<String.Index>(start: advance(copyLoc.startIndex, startInd), end: advance(copyLoc.endIndex, endInd)))
                                //println(newString)
                                var tempLat: Double = (newString as NSString).doubleValue
//                                println(tempLat)
                                self.lat.append(tempLat)
                                //println("Num lats are: \(tempLat)")
                                var copyLoc2 = coords
                                
                                // println("t: \(copyLoc2)")
                                var testString2 = copyLoc.rangeOfString(", -122")!.startIndex
                                var nextTest2: String = String(stringInterpolationSegment: testString2)
                                var startInd2: Int = nextTest2.toInt()! + 2
                                var endInd2 = 0 - (count(copyLoc) - startInd2) + 13
                                var newString2: String = copyLoc.substringWithRange(Range<String.Index>(start: advance(copyLoc.startIndex, startInd2), end: advance(copyLoc.endIndex, endInd2)))
                                
                                var tempLong: Double = (newString2 as NSString).doubleValue
//                                println(tempLong)
                                self.long.append(tempLong)
                                self.finishedDownload()
                                
//                                println(self.lat[0])
                            }
                            //                            self.lat[self.i] = (latLongArr[0] as NSString).doubleValue
                            //                            self.long[self.i] = (latLongArr[0] as NSString).doubleValue
                            //                            println("Coordinates are: \(coords)")
                            //                            println("Num lats are: \(self.lat.count)")
                            //                            println("Num longs are: \(self.long.count)")
                            //self.i++
                            
                        }
                        self.addNotes()
                    }
                }
                
//                let mapType = MapType(rawValue: mapTypeSegmentedControl.selectedSegmentIndex) switch (mapType!) {
//                case .Standard:
//                    self.mapView.mapType = MKMapType.Standard
//                case .Hybrid:
//                    self.mapView.mapType = MKMapType.Hybrid
//                case .Satellite:
//                    self.mapView.mapType = MKMapType.Satellite
//                }
                
        }
        

        
        
        //addAnnos()

        
        //getCoordinates()

        //uploadRacks()
        
//        for var i=0; i < lat.count; i++ {
//            var coordinate = CLLocationCoordinate2D(latitude: lat[i], longitude: long[i])
//            coordinates.append(coordinate)
//        }
        
        
        // Do any additional setup after loading the view.
    }
    
    
    var latin: CLLocationDegrees?
    var longin: CLLocationDegrees?
    
    var coord: CLLocationCoordinate2D?

    
    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
        
        var userLocation : CLLocation = locations[0] as! CLLocation
        
        //self.mapView.addAnnotation(point)
        
        latin = userLocation.coordinate.latitude
        longin = userLocation.coordinate.longitude
        
        let location = CLLocationCoordinate2D(latitude: userLocation.coordinate.latitude, longitude: userLocation.coordinate.longitude)
        coord = location
        
        let span = MKCoordinateSpanMake(0.005, 0.005)
        
        let region = MKCoordinateRegion(center: location, span: span)
        
        mapView.setRegion(region, animated: true)
        
//        for coordinate in coordinates {
//            var annotation = PinAnnotation(coordinate: coordinate, title: title)
//            mapAnnoations.append(annotation)
//            self.mapView.addAnnotation(annotation)
//        }
//        
//        let postsQuery = PFQuery(className: "Rack_Loc")
//        postsQuery.limit = 500
//        
//        var loc = PFGeoPoint(latitude: latin!, longitude: longin!)
//        
//        postsQuery.whereKey("location", nearGeoPoint: loc, withinMiles: 10.0)
//        //finds all posts near current locations
//        
//        var posts = postsQuery.findObjects()
//        println("posts.count =  \(posts!.count)")
//        // println(posts![0])
        //
        
//        if let pts = posts {
//            for post in pts {
//                var loca = post.objectForKey("location")! as! PFGeoPoint
    }
    
    func addNotes () {
        var i = 0
        var p: Int = 0
        
        var q: Int = self.lat.count
        println("lat.count = \(self.lat.count)")
        
//        for coord in lat {
//            q += 1
//        }
        //q = q + 1
        
        while p < q {
            var coordinate: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: lat[p], longitude: long[p])
            var annotation = PinAnnotation(coordinate: coordinate, title: title, color: MKPinAnnotationColor.Red
            )
            
            mapAnnoations.append(annotation)
            self.mapView.addAnnotation(annotation)
            p = p + 1

        }
        
//        while (i < lat.count) {
////
//                var coordinate: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: lat[i], longitude: long[i])
//                var annotation = PinAnnotation(coordinate: coordinate, title: title)
//                
//                mapAnnoations.append(annotation)
//                self.mapView.addAnnotation(annotation)
//                
////            }
//            i++
////            
//        }
        //var int = mapAnnoations.count
        //println(int)
        
        locationManager.stopUpdatingLocation()

    }
    
    
    func mapView(mapView: MKMapView!, viewForAnnotation annotation: MKAnnotation!) -> MKAnnotationView! {

        var view: MKPinAnnotationView?
        
        if let annotation81 = annotation as? MKUserLocation {
            return nil
        }

        for annotation1 in mapAnnoations{
            //annotation1 = self.mapAnnoations[0]
            let identifier = "pin"
            if let dequeuedView = mapView.dequeueReusableAnnotationViewWithIdentifier(identifier) as? MKPinAnnotationView {
                dequeuedView.annotation = annotation1
                view = dequeuedView
            } else if annotation1.title == "my bike" {
                view?.pinColor = MKPinAnnotationColor.Green
                
            }else {
                view = MKPinAnnotationView(annotation: annotation1, reuseIdentifier:identifier)
                view!.calloutOffset = CGPoint(x: -5, y: 5)
                view!.pinColor = MKPinAnnotationColor.Red
            }
        
        }
        //println("DONE")
        return view
        
    }
    
    func searchBarSearchButtonClicked(searchBar: UISearchBar){
        //1
        searchBar.resignFirstResponder()
        dismissViewControllerAnimated(true, completion: nil)
        if self.mapView.annotations.count != 0{
            annotation = self.mapView.annotations[0] as! MKAnnotation
            self.mapView.removeAnnotation(annotation)
        }
        //2
        localSearchRequest = MKLocalSearchRequest()
        localSearchRequest.naturalLanguageQuery = searchBar.text
        localSearch = MKLocalSearch(request: localSearchRequest)
        localSearch.startWithCompletionHandler { (localSearchResponse, error) -> Void in
            
            if localSearchResponse == nil{
                var alert = UIAlertView(title: nil, message: "Place not found", delegate: self, cancelButtonTitle: "Try again")
                alert.show()
                return
            }
            //3
            self.pointAnnotation = MKPointAnnotation()
            self.pointAnnotation.title = searchBar.text
            self.pointAnnotation.coordinate = CLLocationCoordinate2D(latitude: localSearchResponse.boundingRegion.center.latitude, longitude:     localSearchResponse.boundingRegion.center.longitude)
            
            
            self.pinAnnotationView = MKPinAnnotationView(annotation: self.pointAnnotation, reuseIdentifier: nil)
            self.mapView.centerCoordinate = self.pointAnnotation.coordinate
            //self.mapView.addAnnotation(self.pinAnnotationView.annotation)
        }
    }

    

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
//    func getCoordinates () {
//        while (count(bikeRackLoc) > 10)
//        {
//            var copyLoc = bikeRackLoc
//            var testString = copyLoc.rangeOfString("(37")!.startIndex
//            var nextTest: String = String(stringInterpolationSegment: testString)
//            var startInd: Int = nextTest.toInt()! + 1
//            var endInd = 0 - (count(copyLoc) - startInd) + 11
//            var newString: String = copyLoc.substringWithRange(Range<String.Index>(start: advance(copyLoc.startIndex, startInd), end: advance(copyLoc.endIndex, endInd)))
//            println(newString)
//            var tempLat: Double = (newString as NSString).doubleValue
//            lat.append(tempLat)
//        
//            var copyLoc2 = bikeRackLoc
//
//            var testString2 = copyLoc.rangeOfString(", -122")!.startIndex
//            var nextTest2: String = String(stringInterpolationSegment: testString2)
//            var startInd2: Int = nextTest2.toInt()! + 2
//            var endInd2 = 0 - (count(copyLoc) - startInd2) + 13
//            var newString2: String = copyLoc.substringWithRange(Range<String.Index>(start: advance(copyLoc.startIndex, startInd2), end: advance(copyLoc.endIndex, endInd2)))
//           // println(newString2)
//            var tempLong: Double = (newString2 as NSString).doubleValue
//            long.append(tempLong)
//            
//            var toChop = count(bikeRackLoc) + endInd2
//        bikeRackLoc = bikeRackLoc.substringWithRange(Range<String.Index>(start: advance(bikeRackLoc.startIndex, toChop), end: advance(bikeRackLoc.endIndex, 0)))
//        
//       // println(Array(bikeRackLoc)[0])
//        
//        
//        }
//    }
//    
//    
//    func uploadRacks () {
//        var count = 0
//        while count < lat.count{
//            var newPost = PFObject (className: "Rack_Loc")
//            newPost["location"] = PFGeoPoint(latitude: lat[count], longitude: long[count])
//            newPost.saveInBackgroundWithBlock {
//                (success: Bool, error: NSError?) -> Void in
//                if (success) {
//                    println("success!")
//                } else {
//                    println("YOU FUCKED UP YOU DIPSHIT")
//                }
//            }
//            
//            count += 1
//        }
//    }
//
//    /*
//    // MARK: - Navigation
//
//    // In a storyboard-based application, you will often want to do a little preparation before navigation
//    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
//        // Get the new view controller using segue.destinationViewController.
//        // Pass the selected object to the new view controller.
//    }
//    */
    @IBAction func unwindToVC(segue:UIStoryboardSegue) {
        if(segue.identifier == "unwind"){
        
        
        }
                
    }
//
}

extension String {
    
    subscript (i: Int) -> Character {
        return self[advance(self.startIndex, i)]
    }
    
    subscript (i: Int) -> String {
        return String(self[i] as Character)
    }
    
    subscript (r: Range<Int>) -> String {
        return substringWithRange(Range(start: advance(startIndex, r.startIndex), end: advance(startIndex, r.endIndex)))
    }
}