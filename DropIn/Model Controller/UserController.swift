//
//  UserController.swift
//  Users
//
//  Created by Kaden Oldham on 12/4/17.
//  Copyright © 2017 Kaden Oldham. All rights reserved.
//

import Foundation
import CloudKit

class UserController {
    
    static let shared = UserController()
    
    let cloudKitManager: CloudKitManager = {
        return CloudKitManager()
    }()

    let currentUserWasSetNotification = Notification.Name("currentUserWasSet")
    
    var currentUser: User? {
        didSet {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: self.currentUserWasSetNotification, object: nil)
            }
        }
    }
    func createUserWith(username: String, email: String, completion: @escaping (_ success: Bool) -> Void) {
        
        CKContainer.default().fetchUserRecordID { (appleUserRecordID, error) in
            
            guard let appleUserRecordID = appleUserRecordID else { return }
            
            let appleUserRef = CKReference(recordID: appleUserRecordID, action: .deleteSelf)
            
            guard let collectionNames = UserController.shared.currentUser?.collections else  { return }
            
            let user = User(username: username, email: email, appleUserRef: appleUserRef, collectionNames: collectionNames)
            
            
            let userRecord = CKRecord(user: user)
            
            CKContainer.default().publicCloudDatabase.save(userRecord) { (record, error) in
                
                if let error = error { print(error.localizedDescription) }
                
                guard let record = record, let currentUser = User(cloudKitRecord: record) else { completion(false); return }
                
                self.currentUser = currentUser
                completion(true)
                
            }
        }
    }
    
    func fetchCurrentUser(completion: @escaping (_ success: Bool) -> Void = { _ in }) {
        
        // Fetch default Apple 'Users' recordID
        
        CKContainer.default().fetchUserRecordID { (appleUserRecordID, error) in
            
            if let error = error { print(error.localizedDescription) }
            
            guard let appleUserRecordID = appleUserRecordID else { completion(false); return }
            
            // Create a CKReference with the Apple 'Users' recordID so that we can fetch OUR custom User record
            
            let appleUserReference = CKReference(recordID: appleUserRecordID, action: .deleteSelf)
            
            // Create a predicate with that reference that will go through all of the Users and filter through them and return us the one that has the matching reference.
            
            let predicate = NSPredicate(format: "appleUserRef == %@", appleUserReference)
            
            // Fetch our custom User record
            
            self.cloudKitManager.fetchRecordsWithType(User.recordTypeKey, predicate: predicate, recordFetchedBlock: nil, completion: { (records, error) in
                guard let currentUserRecord = records?.first else { completion(false); return }
                
                let currentUser = User(cloudKitRecord: currentUserRecord)
                
                self.currentUser = currentUser
                
                completion(true)
            })
        }
    }
    
    func updateCurrentUser(username: String, email: String, completion: @escaping (_ success: Bool) -> Void) {
        guard let currentUser = currentUser else { return }
        
        currentUser.username = username
        currentUser.email = email
        let currentUserRecord = CKRecord(user: currentUser)
        self.cloudKitManager.modifyRecords([currentUserRecord], perRecordCompletion: nil) { (_, error) in
            
            if let error = error {
                print("Error updating \(#function) \(error) & \(error.localizedDescription)")
                completion(false); return
            } else {
                print("updated user")
            }
            completion(true)
        }
    }
    
    
}




