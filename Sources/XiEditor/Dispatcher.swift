// Copyright 2016 The xi-editor Authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

class Dispatcher {
    let rpcSender: StdoutRPCSender

    init(rpcSender: StdoutRPCSender) {
        self.rpcSender = rpcSender
    }

    func dispatchSync<E: Event, O>(_ event: E) -> O {
        let rpc = event.rpcRepresentation
        return rpcSender.sendRpc(rpc.method, params: rpc.params) as! O
    }

    func dispatchAsync<E: Event, O>(_ event: E) -> O {
        let rpc = event.rpcRepresentation
        return rpcSender.sendRpcAsync(rpc.method, params: rpc.params) as! O
    }

    func dispatchWithCallback<E: Event>(_ event: E, callback: @escaping (RpcResult) -> ()) {
        let rpc = event.rpcRepresentation
        return rpcSender.sendRpcAsync(rpc.method, params: rpc.params) { result in
            callback(result)
        }
    }
}

typealias RpcRepresentation = (method: String, params: AnyObject)

enum EventDispatchMethod {
    case sync
    case async
}

protocol Event {
    //NOTE: output is now unused; this file in general should be considered deprecated.
    // In the future we would like to move to having a 'XiCore protocol', and then implementing that
    // via RPCSending.
    associatedtype Output

    var method: String { get }
    var params: AnyObject? { get }
    var rpcRepresentation: RpcRepresentation { get }
    var dispatchMethod: EventDispatchMethod { get }

    func dispatch(_ dispatcher: Dispatcher) -> Output

    func dispatchWithCallback(_ dispatcher: Dispatcher, callback: @escaping (RpcResult) -> ())
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
    func dispatchWithCallback(_ dispatcher: Dispatcher, callback: @escaping (RpcResult) -> ()) {
        assert(dispatchMethod == .sync)
        dispatcher.dispatchWithCallback(self, callback: callback)
    }
}


enum Events { // namespace

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
