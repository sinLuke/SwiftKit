//
//  DouType.swift
//  MultiTypePlayground
//
//  Created by Luke Yin IBM on 2020-01-21.
//  Copyright © 2020 Luke Yin. All rights reserved.
//

import Foundation

prefix operator <>

typealias JSON = [String: JSObject]

extension Sequence {
    public func flatMapInformLast<SegmentOfResult>(_ transform: (Self.Element, Bool) throws -> SegmentOfResult) rethrows -> [SegmentOfResult.Element] where SegmentOfResult : Sequence {
        var list: [Self.Element] = []
        for item in self {
            list.append(item)
        }
        let last = list.remove(at: list.count - 1)
        
        var resultList = ((try? list.flatMap({ (element) throws -> SegmentOfResult in
            try transform(element, false)
        })) ?? [])
        
        if let lastResult = try? transform(last, true) {
            resultList += lastResult
        }

        return resultList
    }
}

indirect enum JSObject: JSConvertable, CustomStringConvertible {
    var description: String {
        lineDescription.joined(separator: "\n")
    }
    
    prefix static func <> (operand: JSObject) -> JSObject {
        return operand
    }
    
    private var lineDescription: [String] {
        switch self {
            case .null:
                return ["null"]
            case .array(array: let array):
                if array.count == 0 {
                    return ["[]"]
                } else if array.count == 1 {
                    return ["[\(array[0])]"]
                } else {
                    var _array = array
                    let firstLine = _array.remove(at: 0)
                    let lastLine = _array.remove(at: _array.count - 1)
                    return ["[\(firstLine),"] + _array.map { (object) -> String in
                        object.description + ","
                        } + ["\(lastLine)]"]
                }
                
            case .int(let int):
                return ["\(int)"]
            case .double(let double):
                return ["\(double)"]
            case .boolean(let boolean):
                return ["\(boolean)"]
            case .string(let string):
                return ["\"\(string)\""]
            case .object(object: let object):
                let objLst = object.flatMapInformLast { (args, isLast) -> [String] in
                    let (key, value) = args
                    switch value {
                        case .object(object: let innerObject):
                            let prefix = String(repeating: " ", count: "\"\(key)\": ".count)
                            var lineArray = (<>innerObject).lineDescription
                            let firstLine = lineArray.remove(at: 0)
                            var innerObj = lineArray.map { prefix + $0}
                            
                            var last = innerObj.remove(at: innerObj.count - 1)
                            last.append(isLast ? "" : ",")
                            innerObj.append(last)
                            
                            return ["\"\(key)\": \(firstLine)"] + innerObj
                        case .array(array: let innerArray):
                            let prefix = String(repeating: " ", count: "\"\(key)\": ".count)
                            var lineArray = (<>innerArray).lineDescription
                            let firstLine = lineArray.remove(at: 0)
                            var innerArray = lineArray.map { prefix + $0}
                            
                            var last = innerArray.remove(at: innerArray.count - 1)
                            last.append(isLast ? "" : ",")
                            innerArray.append(last)
                            
                            return ["\"\(key)\": \(firstLine)"] + innerArray
                        default:
                            return ["\"\(key)\": \(value.description)\(isLast ? "" : ",")"]
                    }
                }
                return ["{"] + objLst + ["}"]
                
        }
    }
    
    case null
    case int(int: Int)
    case double(double: Double)
    case boolean(boolean: Bool)
    case string(string: String)
    case object(object: JSON)
    case array(array: [JSObject])
    
    subscript (index: String) -> JSObject {
        get {
            switch self {
                case .object(object: let object):
                    if object.keys.contains(index) {
                        return object[index] ?? .null
                    } else {
                        return .null
                }
                case .array(array: let _):
                    if let i = Int(index) {
                        return self[i]
                    } else {
                        return .null
                }
                default:
                    return .null
            }
        }
        set(newValue) {
            switch self {
                case .object(object: let object):
                    var _object = object
                    _object[index] = newValue
                    self = .object(object: _object)
                case .array(array: let array):
                    if let i = Int(index) {
                        if i >= 0 && i < array.count {
                            self[i] = newValue
                        }
                    }
                default: break
            }
        }
    }
    
    subscript(index: Int) -> JSObject {
        get {
            switch self {
                case .array(array: let array):
                    if array.count >= 1 {
                        return array[index % array.count]
                    } else {
                        return .null
                }
                default:
                    return .null
            }
        }
        set(newValue) {
            switch self {
                case .array(array: let array):
                    if array.count >= 1 {
                        if index >= 0 && index < array.count {
                            var _array = array
                            _array[index] = newValue
                            self = .array(array: _array)
                        } else {
                            var newObject:[String: JSObject] = [:]
                            for i in array.indices {
                                newObject["\(i)"] = array[i]
                            }
                            newObject["\(index)"] = newValue
                            self = .object(object: newObject)
                        }
                    } else {
                        self = .array(array: [newValue])
                    }
                case .object(object: _):
                    self["\(index)"] = newValue
                default: break
            }
        }
    }
}

protocol JSConvertable {
    prefix static func <> (operand: Self) -> JSObject
}

extension Int: JSConvertable {
    prefix static func <> (operand: Int) -> JSObject {
        return .int(int: operand)
    }
}

extension Double: JSConvertable {
    prefix static func <> (operand: Double) -> JSObject {
        return .double(double: operand)
    }
}

extension Bool: JSConvertable {
    prefix static func <> (operand: Bool) -> JSObject {
        return .boolean(boolean: operand)
    }
}

extension String: JSConvertable {
    prefix static func <> (operand: String) -> JSObject {
        return .string(string: operand)
    }
}

extension Array: JSConvertable where Element: JSConvertable {
    prefix static func <> (operand: Array<Element>) -> JSObject {
        return .array(array: operand.map({ (item) -> JSObject in
            <>item
        }))
    }
}

extension Dictionary: JSConvertable where Key == String, Value: JSConvertable {
    prefix static func <><T: JSConvertable> (operand: [String: T]) -> JSObject {
        var json: JSON = [:]
        _ = operand.map { (arg) -> () in
            let (key, value) = arg
            return json[key] = <>value
        }
        return .object(object: json)
    }
}

extension Optional: JSConvertable where Wrapped: JSConvertable {
    prefix static func <> (operand: Optional<Wrapped>) -> JSObject {
        if let value = operand {
            return <>value
        } else {
            return .null
        }
    }
}
