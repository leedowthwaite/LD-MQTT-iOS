//
//  ViewController.swift
//  MQTT-Test
//
//  Created by Lee Dowthwaite on 29/12/2018.
//  Copyright © 2018 Lee Dowthwaite. All rights reserved.
//

import UIKit
import MQTTClient

// This MQTT client lib is a bit confusing in terms of what callbacks etc to use. The best example I found that works is here:
// https://github.com/novastone-media/MQTT-Client-Framework/blob/master/MQTTSwift/MQTTSwift/MQTTSwift.swift

class CircularButton: UIButton {

    override var isSelected: Bool {
        didSet {
            self.backgroundColor = isSelected ? .blue : .clear
        }
    }
    
    override func awakeFromNib() {
        self.layer.cornerRadius = self.bounds.width * 0.5
        self.layer.masksToBounds = true
        self.layer.borderWidth = 1.0
        self.layer.borderColor = UIColor.blue.cgColor
    }
}

class ClientViewController: UIViewController {

    let MQTT_HOST = "mqtt-server" // or IP address e.g. "192.168.0.194"
    let MQTT_PORT: UInt32 = 1883
    
    @IBOutlet private weak var button: CircularButton!
    @IBOutlet private weak var statusLabel: UILabel!
    
    private var transport = MQTTCFSocketTransport()
    fileprivate var session = MQTTSession()
    fileprivate var completion: (()->())?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.session?.delegate = self
        self.transport.host = MQTT_HOST
        self.transport.port = MQTT_PORT
        session?.transport = transport
        
        updateUI(for: self.session?.status ?? .created)
        session?.connect() { error in
            print("connection completed with status \(String(describing: error))")
            if error != nil {
                self.updateUI(for: self.session?.status ?? .created)
            } else {
                self.updateUI(for: self.session?.status ?? .error)
            }
        }
    }

    private func updateUI(for clientStatus: MQTTSessionStatus) {
        DispatchQueue.main.async {
            switch clientStatus {
                case .connected:
                    self.statusLabel.text = "Connected"
                    self.button.isEnabled = true
                case .connecting,
                     .created:
                    self.statusLabel.text = "Trying to connect..."
                    self.button.isEnabled = false
                default:
                    self.statusLabel.text = "Connection Failed"
                    self.button.isSelected = false
                    self.button.isEnabled = false
            }
        }
    }

    private func subscribe() {
        self.session?.subscribe(toTopic: "test/message", at: .exactlyOnce) { error, result in
            print("subscribe result error \(String(describing: error)) result \(result!)")
        }
    }
    
    private func publishMessage(_ message: String, onTopic topic: String) {
        session?.publishData(message.data(using: .utf8, allowLossyConversion: false), onTopic: topic, retain: false, qos: .exactlyOnce)
    }
    
    @IBAction func buttonPressed(sender: UIButton) {
        guard session?.status == .connected else {
            self.updateUI(for: self.session?.status ?? .error)
            return 
        }
        let state = !sender.isSelected
        sender.isEnabled = false 
        completion = { 
            sender.isSelected = state 
            sender.isEnabled = true
        }
        print("setting state to \(state)")
        publishMessage(state ? "on" : "off", onTopic: "test/message")
    }
}

extension ClientViewController: MQTTSessionManagerDelegate, MQTTSessionDelegate {

    func newMessage(_ session: MQTTSession!, data: Data!, onTopic topic: String!, qos: MQTTQosLevel, retained: Bool, mid: UInt32) {
        if let msg = String(data: data, encoding: .utf8) {
            print("topic \(topic!), msg \(msg)")
        }
    }

    func messageDelivered(_ session: MQTTSession, msgID msgId: UInt16) {
        print("delivered")
        DispatchQueue.main.async {
            self.completion?()
        }
    }
}
