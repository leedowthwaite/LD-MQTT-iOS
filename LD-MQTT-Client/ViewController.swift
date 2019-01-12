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

class ClientViewController: UIViewController {

    let MQTT_HOST = "mqtt-server" // or IP address e.g. "192.168.0.194"
    let MQTT_PORT: UInt32 = 1883
    
    @IBOutlet private weak var button: UIButton!
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

        self.statusLabel.text = "Trying to connect..."
        try session?.connect() { error in
            print("connection completed with status \(String(describing: error))")
            if error != nil {
                self.statusLabel.text = "Connected"
                self.session?.subscribe(toTopic: "test/message", at: .exactlyOnce) { error, result in
                    print("subscribe result error \(String(describing: error)) result \(result!)")
                }
            } else {
                self.statusLabel.text = "Connection Failed"
            }
        }
    }
    
    private func publishMessage(_ message: String, onTopic: String) {
        session?.publishData(message.data(using: .utf8, allowLossyConversion: false), onTopic: "test/message", retain: false, qos: .exactlyOnce)
    }
    
    @IBAction func buttonPressed(sender: UIButton) {
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

    /** gets called when a new message was received
     @param session the MQTTSession reporting the new message
     @param data the data received, might be zero length
     @param topic the topic the data was published to
     @param qos the qos of the message
     @param retained indicates if the data retransmitted from server storage
     @param mid the Message Identifier of the message if qos = 1 or 2, zero otherwise
     */
    func newMessage(_ session: MQTTSession!, data: Data!, onTopic topic: String!, qos: MQTTQosLevel, retained: Bool, mid: UInt32) {
        if let msg = String(data: data, encoding: .utf8) {
            print("topic \(topic!), msg \(msg)")
        }
    }

    /** gets called when a published message was actually delivered
     @param session the MQTTSession reporting the delivery
     @param msgID the Message Identifier of the delivered message
     @note this method is called after a publish with qos 1 or 2 only
     */
    func messageDelivered(_ session: MQTTSession, msgID msgId: UInt16) {
        print("delivered")
        DispatchQueue.main.async {
            self.completion?()
        }
    }

}
