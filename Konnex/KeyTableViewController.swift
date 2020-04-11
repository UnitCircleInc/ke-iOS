//
//  KeyTableViewController.swift
//  Konnex
//
//  Created by Sean Simmons on 2020-02-09.
//  Copyright © 2020 Unit Circle Inc. All rights reserved.
//

import UIKit

import os.log
let viewLogger = OSLog(subsystem: "ca.unitcircle.Konnex", category: "View")

struct Key: Codable {
    var key: Data
    var lock_pk: String      // Needed for scanning
    var kind: String         // Not used
    var description: String  // Site description - bascially company name
    var address: String      // Site address
    var unit: String         // The unit "name" at the site
    var status: String       // Current status - derived locally - but could also be updated by server
}

enum Sections: Int {
    case Tenant = 0
    case Surrogate = 1
    case Master = 2
    var description: String {
        switch self {
        case .Tenant: return "tenant"
        case .Surrogate: return "surrogate"
        case .Master: return "master"
        }
    }
}

class KeyTableViewController: UITableViewController {
    static let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    static let fileUrl = path.appendingPathComponent("keys")
    
    @IBOutlet var keyTable: UITableView!
    @IBOutlet weak var masterButton: UIButton!
    
    var keys: [String: [String:Key]] = [:]
    var selectedLock: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.view = self
  
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(handleRefreshControl), for: .valueChanged)
        
        keys = ["tenant" : [:], "master" : [:], "surrogate" :  [:]]
        loadKeys()
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        //self.navigationItem.rightBarButtonItem = self.editButtonItem
        //tableView.setEditing(true, animated: true)
        
    }
    
    @objc func handleRefreshControl() {
        print("Refresh list")
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.requestKeys()
    }
    
    
    func saveKeys() {
        do {
            let enc = try PropertyListEncoder().encode(keys)
            let data = try NSKeyedArchiver.archivedData(withRootObject: enc, requiringSecureCoding: false)
            try data.write(to: KeyTableViewController.fileUrl)
            os_log(.default, log: mkLogger, "mk: saveKeys succeeded")
        }
        catch {
            os_log(.default, log: mkLogger, "mk: saveKeys failed")
        }
    }
    
    func loadKeys() {
        do {
            let data = try Data(contentsOf: KeyTableViewController.fileUrl)
            if let dec = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? Data {
                keys = try PropertyListDecoder().decode([String:[String:Key]].self, from: dec)
                os_log(.default, log: mkLogger, "mk: loadKeys succeeded")
            }
            else {
                os_log(.default, log: mkLogger, "mk: loadKeys unable to unarchive")
            }
        }
        catch {
            os_log(.default, log: mkLogger, "mk: loadKeys failed")
        }
    }
    
    func updateKeysFailed() {
        print("Update keys failed")
        DispatchQueue.main.async {
            self.refreshControl?.endRefreshing()
        }
    }

    func updateKeys(_ keys:[String: [String: Key]]) {
        os_log(.default, log: viewLogger, "new keys: %{public}s", keys.description)
        self.keys = keys
        saveKeys()
        // TODOO Fix me self.keys = keys
        DispatchQueue.main.async {
            [weak self] in
            self?.refreshControl?.endRefreshing()
            self?.keyTable.reloadData()
        }
    }
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let section = (Sections(rawValue: section)?.description)!
        return keys[section]!.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let map = ["tenant": "Tenant", "surrogate": "Surrogate", "master": "Master"]
        return map[Sections(rawValue: section)!.description]
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "key-detail-cell", for: indexPath) as? LockTableViewCell else {
            fatalError("the dequeued cell) is not an instance of LockTableViewCell")
        }
        let section = (Sections(rawValue: indexPath.section)?.description)!
        let sortedKeys = keys[section]!.keys.sorted()
        let key = sortedKeys[indexPath.row]
        cell.lockId.text = keys[section]![key]?.description
        cell.lockStatus.text = keys[section]![key]?.status
        return cell
    }
 
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]?
    {
        let section = (Sections(rawValue: indexPath.section)?.description)!
        if section != "tenant" {
            return []
        }
        let shareAction = UITableViewRowAction(style: .default, title: "Share" , handler: {
            (action:UITableViewRowAction, indexPath: IndexPath) -> Void in
            let section = (Sections(rawValue: indexPath.section)?.description)!
            let sortedKeys = self.keys[section]!.keys.sorted()
            let key = sortedKeys[indexPath.row]
            self.selectedLock = self.keys[section]![key]?.lock_pk
            self.performSegue(withIdentifier: "SurrogateSegue", sender: self)
        })
    
        return [shareAction]
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let nc = segue.destination as? UINavigationController,
            let cc = nc.topViewController as? SurrogateViewController {
            cc.lock = selectedLock
        }
    }
    
//    @IBAction func unwindToMain(_ unwindSegue: UIStoryboardSegue) {
//        let sourceViewController = unwindSegue.source
//        // Use data from the view controller which initiated the unwind segue
//    }
//
    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
