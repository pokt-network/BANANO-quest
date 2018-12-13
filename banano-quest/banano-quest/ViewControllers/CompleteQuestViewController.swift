//
//  CompleteQuestViewController.swift
//  banano-quest
//
//  Created by Michael O'Rourke on 6/27/18.
//  Copyright © 2018 Michael O'Rourke. All rights reserved.
//

import Foundation
import UIKit
import MapKit
import CoreLocation
import SwiftHEXColors
import BigInt

class CompleteQuestViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate {

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var bananoBackground: UIView!
    @IBOutlet weak var distanceValueLabel: UILabel!
    @IBOutlet weak var bananosCountLabel: UILabel!
    @IBOutlet weak var questDetailTextView: UITextView!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var questNameLabel: UILabel!
    @IBOutlet weak var completeButton: UIButton!
    
    var locationManager = CLLocationManager()
    var currentUserLocation: CLLocation?
    var questAreaLocation: CLLocation?
    var quest: Quest?

    // MARK: View
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        // Map settings
        mapView.showsUserLocation = true
        mapView.showsCompass = true
        mapView.isZoomEnabled = true
        
        // Location Manager settings
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestAlwaysAuthorization()

    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Background settings
        bananoBackground.layer.cornerRadius = bananoBackground.frame.size.width / 2
        bananoBackground.clipsToBounds = true

        // Refresh view
        do {
            try refreshView()
        } catch let error as NSError {
            print("Failed to refresh view with error: \(error)")
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // UI Updates
        let deviceName = UIDevice.modelName
        
        if deviceName == "iPhone X" || deviceName == "iPhone XS" || deviceName == "iPhone XS Max" || deviceName == "Simulator iPhone X" || deviceName == "Simulator iPhone XS" || deviceName == "Simulator iPhone XS Max" {
            let newSize = CGRect(x: mapView.frame.origin.x, y: mapView.frame.origin.y, width: mapView.frame.width, height: 470)
            mapView.frame = newSize
        }
    }

    override func refreshView() throws {
        // Details view
        
        // Number of Bananos
        let maxWinnersCount = Int(quest?.maxWinners ?? "0")
        
        if maxWinnersCount == 0 {
            bananosCountLabel.text = "INFINITE"
            bananosCountLabel.font = bananosCountLabel.font.withSize(14)
        }else {
            bananosCountLabel.text = "\(quest?.winnersAmount ?? "0")/\(quest?.maxWinners ?? "0")"
            bananosCountLabel.font = bananosCountLabel.font.withSize(17)
        }
        
        // Add color to the banano
        let bananoColor = UIColor(hexString: quest?.hexColor ?? "31AADE")
        bananoBackground.backgroundColor = bananoColor
        
        // Hint
        questDetailTextView.text = quest?.hint
        
        // Quest Name
        questNameLabel.text = quest?.name.uppercased()
        
        // Quest quadrant setup
        setQuestQuadrant()
        
        // Distance from quest
        if let playerLocation = currentUserLocation {
            let distanceMeters = LocationUtils.questDistanceToPlayerLocation(quest: quest!, playerLocation: playerLocation).magnitude
            let roundedDistanceMeters = Double(round(10*distanceMeters)/10)
            var distanceText = "?"
            
            if roundedDistanceMeters > 999 {
                let roundedDistanceKM = roundedDistanceMeters/1000
                if roundedDistanceKM > 999 {
                    distanceText = String.init(format: "%.1fK KM", (roundedDistanceKM/1000))
                } else {
                    distanceText = String.init(format: "%.1f KM", (roundedDistanceKM/1000))
                }
            } else {
                distanceText = String.init(format: "%.1f M", roundedDistanceMeters)
            }
            if let questDistanceLabel = self.distanceValueLabel {
                questDistanceLabel.text = distanceText
            }
        } else {
            if let questDistanceLabel = self.distanceValueLabel {
                questDistanceLabel.text = "?"
            }
        }
        
    }

    // MARK: Tools
    // Present Find Banano VC
    func presentFindBananoViewController(proof: QuestProofSubmission) {
        do {
            let vc = try instantiateViewController(identifier: "findBananoViewControllerID", storyboardName: "Questing") as? FindBananoViewController
            vc?.questProof = proof
            vc?.currentQuest = quest
            vc?.currentUserLocation = currentUserLocation
            
            present(vc!, animated: false, completion: nil)
        } catch let error as NSError {
            print("Failed to instantiate FindBananoViewController with error: \(error)")
        }
    }
    
    // Check if the user is near quest banano
    func checkIfNearBanano() {
        guard let merkle = QuestMerkleTree.generateQuestProofSubmission(answer: currentUserLocation!, merkleBody: (quest?.merkleBody)!) else {
            let alertView = bananoAlertView(title: "Not in range", message: "Sorry, the banano location isn't nearby")
            present(alertView, animated: false, completion: nil)
            
            return
        }
        // Show the Banano :D
        presentFindBananoViewController(proof: merkle)
    }
    
    // Quest quadrant
    func setQuestQuadrant() {
        // Quest Quadrant
        if let corners = quest?.getQuadranHintCorners() {
            let location = LocationUtils.getRegularCentroid(points: corners)
            
            let center = CLLocationCoordinate2D(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            
            let region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
            
            // show quadrant on map
            let circle = MKCircle(center: center, radius: 200)
            
            self.mapView.setRegion(region, animated: true)
            self.mapView.addOverlay(circle)
            
            questAreaLocation = location
            
        } else {
            print("Failed to get quest quadrant")
        }
    }

    // MARK: LocationManager
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print(error)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Location update
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            locationManager.requestAlwaysAuthorization()
            break
        case .authorizedWhenInUse:
            locationManager.startUpdatingLocation()
            break
        case .authorizedAlways:
            locationManager.startUpdatingLocation()
            break
        case .restricted:
            // restricted by e.g. parental controls. User can't enable Location Services
            let alertView = self.bananoAlertView(title: "Error", message: "Restricted by parental controls. User can't enable Location Services.")
            self.present(alertView, animated: false, completion: nil)

            print("restricted by e.g. parental controls. User can't enable Location Services")
            break
        case .denied:
            // user denied your app access to Location Services, but can grant access from Settings.app
            let alertView = self.bananoAlertView(title: "Error", message: "User denied your app access to Location Services, but can grant access from Settings.app.")
            self.present(alertView, animated: false, completion: nil)

            print("user denied your app access to Location Services, but can grant access from Settings.app")
            break
        }
    }

    // MARK: MKMapView
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let circleRenderer = MKCircleRenderer(overlay: overlay)
        circleRenderer.fillColor = UIColor.yellow.withAlphaComponent(0.70)
        circleRenderer.strokeColor = UIColor.yellow
        circleRenderer.lineWidth = 1
        return circleRenderer
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation {
            return nil
        }

        return nil
    }

    // MARK: IBActions
    @IBAction func backButtonPressed(_ sender: Any) {
        self.dismiss(animated: false, completion: nil)
    }

    @IBAction func completeButtonPressed(_ sender: Any) {
        
        if let userLocation = mapView.userLocation.location {
            currentUserLocation = userLocation
        }
        
        if currentUserLocation == nil {
            let alertController = bananoAlertView(title: "Wait!", message: "Let the app get your current location :D")

            present(alertController, animated: false, completion: nil)
            return
        }
        // Check if near banano location
        checkIfNearBanano()
    }
}
