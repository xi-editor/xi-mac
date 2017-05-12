// Copyright 2016 Google Inc. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

class Dispatcher {
    let coreConnection: CoreConnection

    init(coreConnection: CoreConnection) {
        self.coreConnection = coreConnection
    }

    func dispatchSync<E: Event, O>(_ event: E) -> O {
        let rpc = event.rpcRepresentation
        return coreConnection.sendRpc(rpc.method, params: rpc.params) as! O
    }

    func dispatchAsync<E: Event, O>(_ event: E) -> O {
        let rpc = event.rpcRepresentation
        return coreConnection.sendRpcAsync(rpc.method, params: rpc.params) as! O
    }

    func dispatchWithCallback<E: Event, O>(_ event: E, callback: @escaping (O) -> ()) {
        let rpc = event.rpcRepresentation
        return coreConnection.sendRpcAsync(rpc.method, params: rpc.params) { (result: Any?) in
            callback(result as! O)
        }
    }
}

typealias RpcRepresentation = (method: String, params: AnyObject)

enum EventDispatchMethod {
    case sync
    case async
}

protocol Event {
    associatedtype Output

    var method: String { get }
    var params: AnyObject? { get }
    var rpcRepresentation: RpcRepresentation { get }
    var dispatchMethod: EventDispatchMethod { get }

    func dispatch(_ dispatcher: Dispatcher) -> Output

    func dispatchWithCallback(_ dispatcher: Dispatcher, callback: @escaping (Output) -> ())
}

extension Event {
    var rpcRepresentation: RpcRepresentation {
        return (method, params ?? [] as AnyObject)
    }

    /// Note: sync dispatch is discouraged, as it blocks the main thread, and also provides no
    /// useful ordering guarantee.
    func dispatch(_ dispatcher: Dispatcher) -> Output {
        switch dispatchMethod {
        case .sync: return dispatcher.dispatchSync(self)
        case .async: return dispatcher.dispatchAsync(self)
        }
    }

    /// Note: the callback may be called from an arbitrary thread
    func dispatchWithCallback(_ dispatcher: Dispatcher, callback: @escaping (Output) -> ()) {
        assert(dispatchMethod == .sync)
        dispatcher.dispatchWithCallback(self, callback: callback)
    }
}

/// Identifies a given document view for routing with xi-core
typealias ViewIdentifier = String

enum Events { // namespace
    struct NewView: Event {
        typealias Output = String
        
        let path: String?
        let method = "new_view"
        var params: AnyObject? {
            guard let path = self.path else { return [:] as AnyObject }
            return ["file_path": path] as AnyObject
        }
        let dispatchMethod = EventDispatchMethod.sync
    }
    
    struct CloseView: Event {
        typealias Output = Void
        
        let viewIdentifier: ViewIdentifier
        
        let method = "close_view"
        var params: AnyObject? { return ["view_id": viewIdentifier] as AnyObject }
        let dispatchMethod = EventDispatchMethod.async
    }
    
    struct Save: Event {
        typealias Output = Void
        
        let viewIdentifier: ViewIdentifier
        let path: String
        
        let method = "save"
        var params: AnyObject? { return ["view_id": viewIdentifier, "file_path": path] as AnyObject }
        let dispatchMethod = EventDispatchMethod.async
    }

    struct StartPlugin: Event {
        typealias Output = Void
        let viewIdentifier: ViewIdentifier
        let plugin: String

        let method = "plugin"
        var params: AnyObject? {
            return ["command": "start", "view_id": viewIdentifier, "plugin_name": plugin] as AnyObject
        }
        let dispatchMethod = EventDispatchMethod.async
    }
    
    struct StopPlugin: Event {
        typealias Output = Void
        let viewIdentifier: ViewIdentifier
        let plugin: String
        
        let method = "plugin"
        var params: AnyObject? {
            return ["command": "stop", "view_id": viewIdentifier, "plugin_name": plugin] as AnyObject
        }
        let dispatchMethod = EventDispatchMethod.async
    }
    
    struct InitialPlugins: Event {
        typealias Output = [String]
        let viewIdentifier: ViewIdentifier
        
        let method = "plugin"
        var params: AnyObject? {
            return ["command": "initial_plugins", "view_id": viewIdentifier] as AnyObject
        }
        let dispatchMethod = EventDispatchMethod.sync
    }
}
