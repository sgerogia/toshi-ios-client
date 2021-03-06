// Copyright (c) 2017 Token Browser, Inc
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

import Foundation

@objc public class SofaTypes: NSObject {
    static let none = SofaType.none.rawValue
    static let message = SofaType.message.rawValue
    static let command = SofaType.command.rawValue
    static let initialRequest = SofaType.initialRequest.rawValue
    static let initialResponse = SofaType.initialResponse.rawValue
    static let paymentRequest = SofaType.paymentRequest.rawValue
    static let payment = SofaType.payment.rawValue
}

public enum SofaType: String {
    case none = ""
    case message = "SOFA::Message:"
    case command = "SOFA::Command:"
    case initialRequest = "SOFA::InitRequest:"
    case initialResponse = "SOFA::Init:"
    case paymentRequest = "SOFA::PaymentRequest:"
    case payment = "SOFA::Payment:"

    init(sofa: String?) {
        guard let sofa = sofa else {
            self = .none

            return
        }

        if sofa.hasPrefix(SofaType.message.rawValue) {
            self = .message
        } else if sofa.hasPrefix(SofaType.command.rawValue) {
            self = .command
        } else if sofa.hasPrefix(SofaType.initialRequest.rawValue) {
            self = .initialRequest
        } else if sofa.hasPrefix(SofaType.initialResponse.rawValue) {
            self = .initialResponse
        } else if sofa.hasPrefix(SofaType.paymentRequest.rawValue) {
            self = .paymentRequest
        } else if sofa.hasPrefix(SofaType.payment.rawValue) {
            self = .payment
        } else {
            self = .none
        }
    }
}

public protocol SofaWrapperProtocol {
    var type: SofaType { get }
}

open class SofaWrapper: SofaWrapperProtocol {
    public var type: SofaType {
        return .none
    }

    open var content: String = ""

    open var json: [String: Any] {
        let sofaBody = content.replacingOccurrences(of: type.rawValue, with: "")
        let data = sofaBody.data(using: .utf8)!

        guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) else { return [String: Any]() }
        guard let json = jsonObject as? [String: Any] else { return [String: Any]() }

        return json
    }

    public static func wrapper(content: String) -> SofaWrapper {
        switch SofaType(sofa: content) {
        case .message:
            return SofaMessage(content: content)
        case .command:
            return SofaCommand(content: content)
        case .initialRequest:
            return SofaInitialRequest(content: content)
        case .initialResponse:
            return SofaInitialResponse(content: content)
        case .paymentRequest:
            return SofaPaymentRequest(content: content)
        case .payment:
            return SofaPayment(content: content)
        case .none:
            return SofaWrapper(content: "") // should probaby crash instead
        }
    }

    public init(content: String) {
        self.content = content
    }

    public init(content json: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: json, options: []) else { fatalError() }
        guard let jsonString = String(data: data, encoding: .utf8) else { fatalError() }

        content = type.rawValue + jsonString
    }
}

open class SofaMessage: SofaWrapper {

    open class Button: Equatable {

        public enum ControlType: String {
            case button
            case group
        }

        open var type: ControlType = .button

        private var _label: String?

        open var label: String? {
            switch self.type {
            case .button:
                return self._label
            case .group:
                return self._label?.appending(" ▴")
            }
        }

        // values are to be sent back as SofaCommands
        open var value: Any?

        // Actions are to be handled locally.
        open var action: Any?

        open var subcontrols: [Button] = []

        public init(json: [String: Any]) {
            if let jsonType = json["type"] as? String {
                type = ControlType(rawValue: jsonType) ?? .button
            }
            
            _label = json["label"] as? String

            switch type {
            case .button:
                if let value = json["value"] {
                    self.value = value
                }
                if let action = json["action"] {
                    self.action = action
                }
            case .group:
                guard let controls = json["controls"] as? [[String: Any]] else { return }
                subcontrols = controls.map { (control) -> Button in
                    return Button(json: control)
                }
            }
        }

        public static func == (lhs: SofaMessage.Button, rhs: SofaMessage.Button) -> Bool {
            let lhv = lhs.value as AnyObject
            let rhv = rhs.value as AnyObject
            let lha = lhs.action as AnyObject
            let rha = rhs.action as AnyObject

            return lhs._label == rhs._label && lhs.type == rhs.type && lhv === rhv && lha === rha
        }
    }

    public override var type: SofaType {
        return .message
    }

    var showKeyboard: Bool? {
        return json["showKeyboard"] as? Bool
    }

    open lazy var body: String = {
        guard self.content.hasPrefix(self.type.rawValue) else {
            fatalError("Creating SofaMessage with invalid type!")
        }

        if let messageText = self.json["body"] as? String {
            return messageText
        }

        return ""
    }()

    open lazy var buttons: [SofaMessage.Button] = {
        guard self.content.hasPrefix(self.type.rawValue) else {
            fatalError("Creating SofaMessage with invalid type!")
        }

        // [{"type": "button", "label": "Red Cross", "value": "red-cross"},…]
        var buttons = [Button]()
        if let controls = self.json["controls"] as? [[String: Any]] {

            for control in controls {
                buttons.append(Button(json: control))
            }
        }

        return buttons
    }()

    public convenience init(body: String) {
        self.init(content: ["body": body])
    }
}

/// SOFA::Command:{
//      "body": "Timetable",
//      "value": "timetable"
//  }
open class SofaCommand: SofaWrapper {
    open lazy var body: String = {
        guard self.content.hasPrefix(self.type.rawValue) else {
            fatalError("Creating SofaMessage with invalid type!")
        }

        if let messageText = self.json["body"] as? String {
            return messageText
        }

        return ""
    }()

    public override var type: SofaType {
        return .command
    }

    public convenience init(button: SofaMessage.Button) {
        let json: [String: Any] = [
            "body": button.label,
            "value": button.value!
        ]

        self.init(content: json)
    }
}

/// App receives that with list of values it needs to continue.
/// Answered with a SOFA::Init message (SofaMetadataResponse).
open class SofaInitialRequest: SofaWrapper {
    public override var type: SofaType {
        return .initialRequest
    }

    open lazy var values: [String] = {
        guard self.content.hasPrefix(self.type.rawValue) else {
            fatalError("Creating SofaMessage with invalid type!")
        }

        if let values = self.json["values"] as? [String] {
            return values
        }

        return [String]()
    }()
}

// Each key is a value that came from the init request as stated above.
// Example: SofaInitialResponse(contant: ["paymentAddress": "0xa2a0134f1df987bc388dbcb635dfeed4ce497e2a", "language": "en"])
open class SofaInitialResponse: SofaWrapper {
    public override var type: SofaType {
        return .initialResponse
    }

    public convenience init(initialRequest: SofaInitialRequest) {
        var response = [String: Any]()
        for value in initialRequest.values {
            if value == "paymentAddress" {
                response[value] = TokenUser.current?.paymentAddress ?? ""
            } else if value == "language" {
                let locale = Locale.current
                response[value] = locale.identifier
            }
        }

        self.init(content: response)
    }
}

open class SofaPaymentRequest: SofaWrapper {
    public override var type: SofaType {
        return .paymentRequest
    }

    public var body: String {
        guard content.hasPrefix(type.rawValue) else {
            fatalError("Creating SofaMessage with invalid type!")
        }

        if let messageText = self.json["body"] as? String {
            return messageText
        }

        return ""
    }

    public var value: NSDecimalNumber {
        guard let hexValue = self.json["value"] as? String else { return NSDecimalNumber.zero }

        if hexValue.hasPrefix("0x") {
            return NSDecimalNumber(hexadecimalString: hexValue)
        } else {
            return NSDecimalNumber(string: hexValue)
        }
    }

    public var destinationAddress: String? {
        return (json["destinationAddress"] as? String)
    }
}

open class SofaPayment: SofaWrapper {

    public enum Status: String {
        case unconfirmed
        case confirmed
        case error
    }

    public var status: Status {
        guard let status = self.json["status"] as? String else { return .unconfirmed }
        return Status(rawValue: status) ?? .unconfirmed
    }

    public var recipientAddress: String? {
        guard let address = self.json["toAddress"] as? String else { return nil }
        return address
    }

    public var senderAddress: String? {
        guard let address = self.json["fromAddress"] as? String else { return nil }
        return address
    }

    public override var type: SofaType {
        return .payment
    }

    public var value: NSDecimalNumber {
        guard let hexValue = self.json["value"] as? String else { return NSDecimalNumber.zero }

        if hexValue.hasPrefix("0x") {
            return NSDecimalNumber(hexadecimalString: hexValue)
        } else {
            return NSDecimalNumber(string: hexValue)
        }
    }

    public convenience init(txHash: String, valueHex: String) {
        let payment: [String: String] = [
            "status": Status.unconfirmed.rawValue,
            "txHash": txHash,
            "value": valueHex
        ]

        self.init(content: payment)
    }
}
