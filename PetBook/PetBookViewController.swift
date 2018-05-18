//
//  PetBookViewController.swift
//  PetBook
//
//  Created by Niv Yahel on 2015-03-16.
//  Copyright (c) 2015 Evan Dekhayser. All rights reserved.
//

import UIKit
import AddressBook
import AddressBookUI

class PetBookViewController: UIViewController {
  var pets = [
    Pet(firstName: "Cheesy", lastName: "Cat", phoneNumber: "2015552398", imageName: "contact_Cheesy.jpg"),
    Pet(firstName: "Freckles", lastName: "Dog", phoneNumber: "3331560987", imageName: "contact_Freckles.jpg"),
    Pet(firstName: "Maxi", lastName: "Dog", phoneNumber: "5438880123", imageName: "contact_Maxi.jpg"),
    Pet(firstName: "Shippo", lastName: "Dog", phoneNumber: "7124779080", imageName: "contact_Shippo.jpg")
  ]
  let addressBookRef: ABAddressBook = ABAddressBookCreateWithOptions(nil, nil).takeRetainedValue()

  override func viewDidLoad() {
    super.viewDidLoad()

    // Do any additional setup after loading the view.
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }

  // MARK: - Address Book

  func addPetToContacts(petButton: UIButton) {
    let pet = pets[petButton.tag]

    if let petRecordIfExists: ABRecordRef = getPetRecord(pet) {
      displayContactExistsAlert(petRecordIfExists)
      return
    }

    let petRecord: ABRecordRef = makeAndAddPetRecord(pet)
    let contactAddedAlert = UIAlertController(title: "\(pet.firstName) was successfully added.",
      message: nil, preferredStyle: .Alert)
    contactAddedAlert.addAction(UIAlertAction(title: "Add to \"Animals\" Group", style: .Default, handler: { action in
      self.addPetToGroup(petRecord)
    }))
    contactAddedAlert.addAction(UIAlertAction(title: "OK", style: .Cancel, handler: nil))
    presentViewController(contactAddedAlert, animated: true, completion: nil)
  }

  func getPetRecord(pet: Pet) -> ABRecordRef? {
    let allContacts = ABAddressBookCopyArrayOfAllPeople(addressBookRef).takeRetainedValue() as Array
    var petContact: ABRecordRef?
    for record in allContacts {
      let currentContact: ABRecordRef = record
      let currentContactName = ABRecordCopyCompositeName(currentContact).takeRetainedValue() as String
      let petName = pet.description
      if (currentContactName == petName) {
        println("found \(petName).")
        petContact = currentContact
      }
    }
    return petContact
  }

  func makeAndAddPetRecord(pet: Pet) -> ABRecordRef {
    let petRecord: ABRecordRef = ABPersonCreate().takeRetainedValue()
    ABRecordSetValue(petRecord, kABPersonFirstNameProperty, pet.firstName, nil)
    ABRecordSetValue(petRecord, kABPersonLastNameProperty, pet.lastName, nil)
    ABPersonSetImageData(petRecord, pet.imageData, nil)

    let phoneNumbers: ABMutableMultiValue = ABMultiValueCreateMutable(ABPropertyType(kABMultiStringPropertyType)).takeRetainedValue()
    ABMultiValueAddValueAndLabel(phoneNumbers, pet.phoneNumber, kABPersonPhoneMainLabel, nil)
    ABRecordSetValue(petRecord, kABPersonPhoneProperty, phoneNumbers, nil)

    ABAddressBookAddRecord(addressBookRef, petRecord, nil)
    saveAddressBookChanges()

    return petRecord
  }

  func saveAddressBookChanges() {
    if ABAddressBookHasUnsavedChanges(addressBookRef){
      var err: Unmanaged<CFErrorRef>? = nil
      let savedToAddressBook = ABAddressBookSave(addressBookRef, &err)
      if savedToAddressBook {
        println("Successully saved changes.")
      } else {
        println("Couldn't save changes.")
      }
    } else {
      println("No changes occurred.")
    }
  }

  // MARK: - Permissions

  func promptForAddressBookRequestAccess(petButton: UIButton) {
    var err: Unmanaged<CFError>? = nil
    ABAddressBookRequestAccessWithCompletion(addressBookRef) {
      (granted: Bool, error: CFError!) in
      dispatch_async(dispatch_get_main_queue()) {
        if !granted {
          // 1
          println("Just denied")
          self.displayCantAddContactAlert()
        } else {
          // 2
          println("Just authorized")
          self.addPetToContacts(petButton)
        }
      }
    }
  }

  func openSettings() {
    let url = NSURL(string: UIApplicationOpenSettingsURLString)
    UIApplication.sharedApplication().openURL(url!)
  }

  // MARK: - Groups

  func createGroup(groupName: String) -> ABRecordRef {
    var groupRecord: ABRecordRef = ABGroupCreate().takeRetainedValue()

    let allGroups = ABAddressBookCopyArrayOfAllGroups(addressBookRef).takeRetainedValue() as Array
    for group in allGroups {
      let currentGroup: ABRecordRef = group
      let currentGroupName = ABRecordCopyValue(currentGroup, kABGroupNameProperty).takeRetainedValue() as! String
      if (currentGroupName == groupName) {
        println("Group exists")
        return currentGroup
      }
    }
    ABRecordSetValue(groupRecord, kABGroupNameProperty, groupName, nil)
    ABAddressBookAddRecord(addressBookRef, groupRecord, nil)
    saveAddressBookChanges()
    println("Made group")
    return groupRecord
  }

  func addPetToGroup(petContact:ABRecordRef) {
    let groupName = "Animals"
    let group: ABRecordRef = createGroup(groupName)
    // 1. Check if the member is already a part of the group.
    // 1a. Check if there are any members.
    if let groupMembersArray = ABGroupCopyArrayOfAllMembers(group) {
      let groupMembers = groupMembersArray.takeRetainedValue() as Array
      // 1b. Check if any of the members match the current pet.
      for member in groupMembers {
        let currentMember: ABRecordRef = member
        if currentMember === petContact {
          println("Already in it.")
          return
        }
      }
    }

    // 2. Add the member to the group
    let addedToGroup = ABGroupAddMember(group, petContact, nil)
    if !addedToGroup {
      println("Couldn't add pet to group.")
    }

    // 3. Save the changes
    saveAddressBookChanges()
  }

  // MARK: - Alerts

  func displayCantAddContactAlert() {
    let cantAddContactAlert = UIAlertController(title: "Cannot Add Contact",
      message: "You must give the app permission to add the contact first.",
      preferredStyle: .Alert)
    cantAddContactAlert.addAction(UIAlertAction(title: "Change Settings",
      style: .Default,
      handler: { action in
        self.openSettings()
    }))
    cantAddContactAlert.addAction(UIAlertAction(title: "OK", style: .Cancel, handler: nil))
    presentViewController(cantAddContactAlert, animated: true, completion: nil)
  }

  func displayContactExistsAlert(petRecord: ABRecordRef) {
    let petFirstName = ABRecordCopyValue(petRecord, kABPersonFirstNameProperty).takeRetainedValue() as? String ?? "That pet"
    let contactExistsAlert = UIAlertController(title: "\(petFirstName) has already been added.",
      message: nil, preferredStyle: .Alert)
    contactExistsAlert.addAction(UIAlertAction(title: "Show Contact", style: .Default, handler: { action in
      let personViewController = ABPersonViewController()
      personViewController.displayedPerson = petRecord
      self.navigationController?.pushViewController(personViewController, animated: true)
    }))
    contactExistsAlert.addAction(UIAlertAction(title: "Add to \"Animals\" Group", style: .Default, handler: { action in
      self.addPetToGroup(petRecord)
    }))
    contactExistsAlert.addAction(UIAlertAction(title: "OK", style: .Cancel, handler: nil))
    presentViewController(contactExistsAlert, animated: true, completion: nil)
  }

  // MARK: - Actions

  @IBAction func tappedAddPetToContacts(petButton: UIButton) {
    let authorizationStatus = ABAddressBookGetAuthorizationStatus()

    switch authorizationStatus {
    case .Denied, .Restricted:
      //1
      println("Denied")
      displayCantAddContactAlert()
    case .Authorized:
      //2
      println("Authorized")
      addPetToContacts(petButton)
    case .NotDetermined:
      //3
      println("Not Determined")
      promptForAddressBookRequestAccess(petButton)
    }
  }

}
