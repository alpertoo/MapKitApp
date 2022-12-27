//
//  ViewController.swift
//  MapKitApp
//
//  Created by Alper Koçer on 22.12.2022.
//

import UIKit
import MapKit
import CoreLocation
import CoreData

class MapViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate {
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var locationNameTextField: UITextField!
    @IBOutlet weak var descriptionTextField: UITextField!
    
    var locationManager = CLLocationManager() //CoreLocationManager
    
    var selectedPlaceLatitude = Double()
    var selectedPlaceLongitude = Double()
    
    var selectedPlaceName = ""
    var selectedPlaceId: UUID?
    
    var annotationTitle = ""
    var annotationSubtitle = ""
    var annotationLatitude = Double()
    var annotationLongitude = Double()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mapView.delegate = self
        locationManager.delegate = self
        
        locationManager.desiredAccuracy = kCLLocationAccuracyBest //The accuracy of the location data.
        locationManager.requestWhenInUseAuthorization() //Request from the user to access the location.
        locationManager.startUpdatingLocation()
        
        let gestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(selectLocation(gestureRecognizer: )))
        gestureRecognizer.minimumPressDuration = 3
        mapView.addGestureRecognizer(gestureRecognizer)
        
        if selectedPlaceName != "" {
            //Retrieve data from CoreData
            if let uuidString = selectedPlaceId?.uuidString {
                let appDelegate = UIApplication.shared.delegate as! AppDelegate
                let context = appDelegate.persistentContainer.viewContext
                
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Place")
                fetchRequest.predicate = NSPredicate(format: "id = %@", uuidString)
                fetchRequest.returnsObjectsAsFaults = false
                
                do{
                    let results = try context.fetch(fetchRequest)
                    if results.count > 0 {
                        for result in results as! [NSManagedObject] {
                            
                            if let name = result.value(forKey: "name") as? String {
                                annotationTitle = name
                                if let note = result.value(forKey: "note") as? String {
                                    annotationSubtitle = note
                                    if let latitude = result.value(forKey: "latitude") as? Double {
                                        annotationLatitude = latitude
                                        if let longitude = result.value(forKey: "longitude") as? Double {
                                            annotationLongitude = longitude
                                        }
                                    }
                                }
                            }
                            
                            let annotation = MKPointAnnotation()
                            
                            let coordinate = CLLocationCoordinate2D(latitude: annotationLatitude, longitude: annotationLongitude)
                            
                            annotation.title = annotationTitle
                            annotation.subtitle = annotationSubtitle
                            annotation.coordinate = coordinate
                            
                            mapView.addAnnotation(annotation)
                            locationNameTextField.text = annotationTitle
                            descriptionTextField.text = annotationSubtitle
                            
                            locationManager.stopUpdatingLocation()
                            let span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                            let region = MKCoordinateRegion(center: coordinate, span: span)
                            mapView.setRegion(region, animated: true)
                        }
                    }
                }catch{
                    print("Hata")
                }
                
            }
        }else{
            //Means it is a new entry
            
        }
    }
    
    // Adding custom annotation
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation {
            // if the annotation is user's currect location
            return nil
        }
        let reusableAnnotationId = "specialAnnotation"
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reusableAnnotationId)
        
        // If this pin is created before, set the pin to the former one
        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reusableAnnotationId)
            pinView?.canShowCallout = true // Whether the annotation can show extra information
            pinView?.tintColor = .blue
            
            let annotationButton = UIButton(type: .detailDisclosure) // The button which will be shown in the callout
            
            pinView?.rightCalloutAccessoryView = annotationButton
            
        } else {
            pinView?.annotation = annotation
        }
        return pinView
    }
    
    // What will happen when the user taps the callout
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        if selectedPlaceName != "" {
            let requestLocation = CLLocation(latitude: annotationLatitude, longitude: annotationLongitude)
            
            CLGeocoder().reverseGeocodeLocation(requestLocation) { placemarkArray, hata in
                if let placemarks = placemarkArray {
                    if placemarks.count > 0 {
                        
                        let newPlacemark = MKPlacemark(placemark: placemarks[0])
                        let item = MKMapItem(placemark: newPlacemark)
                        item.name = self.annotationTitle
                        
                        let launchOptions = [MKLaunchOptionsDirectionsModeKey : MKLaunchOptionsDirectionsModeDriving]
                        item.openInMaps(launchOptions: launchOptions)
                        
                    }
                }
            }
        }
    }
    
    @objc func selectLocation(gestureRecognizer: UILongPressGestureRecognizer) {
        
        if gestureRecognizer.state == .began {
            let longPressedPoint = gestureRecognizer.location(in: mapView) //To retrieve the points which user long presses.
            let longPressedPointCoordinate = mapView.convert(longPressedPoint, toCoordinateFrom: mapView) //convert points to coordinates.
            
            selectedPlaceLatitude = longPressedPointCoordinate.latitude
            selectedPlaceLongitude = longPressedPointCoordinate.longitude
            
            //Pinning a location on the map.
            let annotation = MKPointAnnotation()
            annotation.coordinate = longPressedPointCoordinate
            annotation.title = locationNameTextField.text
            annotation.subtitle = descriptionTextField.text
            mapView.addAnnotation(annotation)
            
        }
    }
    
    //Retrieve the location of the user.
    //Update the map with each update on location.
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        //print(locations[0].coordinate.latitude)
        //print(locations[0].coordinate.longitude)
        if selectedPlaceName == "" {
            let location = CLLocationCoordinate2D(latitude: locations[0].coordinate.latitude, longitude: locations[0].coordinate.longitude)
            let span = MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001) //The width and heigth of a map region. Zoom amount.
            let region = MKCoordinateRegion(center: location, span: span)
            mapView.setRegion(region, animated: true)
        }
    }

    
    @IBAction func saveButtonTapped(_ sender: UIButton) {
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let context = appDelegate.persistentContainer.viewContext
        
        let newPlace = NSEntityDescription.insertNewObject(forEntityName: "Place", into: context)
        
        newPlace.setValue(locationNameTextField.text, forKey: "name")
        newPlace.setValue(descriptionTextField.text, forKey: "note")
        newPlace.setValue(selectedPlaceLatitude, forKey: "latitude")
        newPlace.setValue(selectedPlaceLongitude, forKey: "longitude")
        newPlace.setValue(UUID(), forKey: "id")
        
        do {
            try context.save()
            print("Kayıt edildi")
        } catch {
            print("Hata!")
        }
        
        NotificationCenter.default.post(name: NSNotification.Name("newPlaceCreated"), object: nil)
        navigationController?.popViewController(animated: true)
        
    }
    
}

