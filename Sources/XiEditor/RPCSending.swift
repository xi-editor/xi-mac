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
import AppKit

/// Env var used to specify a path for logging RPC messages.
/// These logs can be used for profiling & debugging.
let XI_RPC_LOG = "XI_CLIENT_RPC_LOG"

let NEW_LINE = [0x0a as UInt8]
let CLIENT_LOG_PREFIX = "[CLIENT] ".data(using: .utf8)!
let CORE_LOG_PREFIX = "[CORE]   ".data(using: .utf8)!

/// An error returned from core
struct RemoteError {
    let code: Int
    let message: String
    let data: AnyObject?

    init?(json: [String: AnyObject]) {
        guard let code = json["code"] as? Int,
            let message = json["message"] as? String else { return nil }
        self.code = code
        self.message = message
        self.data = json["data"]
    }
}

/// The return value of a synchronous RPC
enum RpcResult {
    case error(RemoteError)
    case ok(AnyObject)
}

/// A completion handler for a synchronous RPC
typealias RpcCallback = (RpcResult) -> ()

/// Protocol describing the general interface with core.
/// Concrete implementations may be provided for different transport mechanisms, e.g. stdin/stdout, unix sockets, or FFI.
protocol RPCSending {
    func sendRpcAsync(_ method: String, params: Any, callback: RpcCallback?)
    func sendRpc(_ method: String, params: Any) -> RpcResult
}

class StdoutRPCSender: RPCSending {

    private let task = Process()
    private var inHandle: FileHandle  // stdin of core process
    private var recvBuf: Data
    weak var client: XiClient?
    private let rpcLogWriter: FileWriter?
    private var lastLogs = CircleBuffer<String>(capacity: 100)

    // RPC state
    private var queue = DispatchQueue(label: "io.xi-editor.XiEditor.CoreConnection", attributes: [])
    private var rpcIndex = 0
    private var pending = Dictionary<Int, RpcCallback>()

    init(path: String, errorLogDirectory: URL?) {
        if let rpcLogPath = ProcessInfo.processInfo.environment[XI_RPC_LOG] {
            self.rpcLogWriter = FileWriter(path: rpcLogPath)
            if self.rpcLogWriter != nil {
                print("logging client RPC to \(rpcLogPath)")
            }
        } else {
            self.rpcLogWriter = nil
        }
        let errLogPath = errorLogDirectory?.path
        let errLogArgs = errLogPath.map { ["--log-dir", $0] }
        task.launchPath = path
        if let errLogArgs = errLogArgs {
            task.arguments = errLogArgs
        }
        if task.environment == nil {
            task.environment = ProcessInfo.processInfo.environment
        }
        task.environment?["RUST_BACKTRACE"] = "1"

        let outPipe = Pipe()
        task.standardOutput = outPipe
        let inPipe = Pipe()
        task.standardInput = inPipe
        inHandle = inPipe.fileHandleForWriting
        recvBuf = Data()

        outPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            self.recvHandler(data)
        }

        let errPipe = Pipe()
        task.standardError = errPipe
        errPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let errString = String(data: data, encoding: .utf8) {
                // redirect core stderr to stdout in debug builds
                #if DEBUG
                print(errString, terminator: "")
                #endif
                self?.lastLogs.push(errString)
            }
        }

        // save backtrace on core crash
        task.terminationHandler = { [weak self] process in
            guard process.terminationStatus != 0, let strongSelf = self else {
                print("xi-core exited with code 0")
                return
            }

            print("xi-core exited with code \(process.terminationStatus), attempting to save log")

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd-HHMMSS"
            let timeStamp = dateFormatter.string(from: Date())
            let crashLogFilename = "XiEditor-Crash-\(timeStamp).log"
            let crashLogPath = errorLogDirectory?.appendingPathComponent(crashLogFilename)

            let logText = strongSelf.lastLogs.allItems().joined()
            if let path = crashLogPath {
                do {
                    try logText.write(to: path, atomically: true, encoding: .utf8)
                    print("wrote log to \(path)")
                } catch let error as NSError {
                    print("failed to write backtrace to \(path): \(error)")
                }
            }
        }
        task.launch()
    }

    private func recvHandler(_ data: Data) {
        if data.count == 0 {
            return
        }
        let scanStart = recvBuf.count
        recvBuf.append(data)
        let recvBufLen = recvBuf.count

        var newCount = 0
        recvBuf.withUnsafeMutableBytes { (recvBufBytes: UnsafeMutablePointer<UInt8>) -> Void in
            var i = 0
            for j in scanStart..<recvBufLen {
                // TODO: using memchr would probably be faster
                if recvBufBytes[j] == UInt8(ascii:"\n") {
                    let bufferPointer = UnsafeBufferPointer(start: recvBufBytes.advanced(by: i), count: j + 1 - i)
                    let dataPacket = Data(bufferPointer)
                    handleRaw(dataPacket)
                    i = j + 1
                }
            }
            if i < recvBufLen {
                memmove(recvBufBytes, recvBufBytes + i, recvBufLen - i)
            }
            newCount = recvBufLen - i
        }
        recvBuf.count = newCount
    }

    private func sendJson(_ json: Any) {
        do {
            var data = try JSONSerialization.data(withJSONObject: json, options: [])
            data.append(NEW_LINE, count: 1)

            if let writer = self.rpcLogWriter {
                writer.write(bytes: CLIENT_LOG_PREFIX)
                writer.write(bytes: data)
            }

            inHandle.write(data as Data)
        } catch _ {
            print("error serializing to json")
        }
    }

    private func sendResult(id: Any, result: Any) {
        let json = ["id": id, "result": result]
        sendJson(json)
    }

    private func handleRaw(_ data: Data) {
        if let writer = self.rpcLogWriter {
            writer.write(bytes: CORE_LOG_PREFIX)
            writer.write(bytes: data)
        }

        Trace.shared.trace("handleRaw", .rpc, .begin)
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
            handleRpc(json)
        } catch {
            print("json error \(error.localizedDescription)")
        }
        Trace.shared.trace("handleRaw", .rpc, .end)
    }

    /// handle a JSON RPC call. Determines whether it is a request, response or notification
    /// and executes/responds accordingly
    private func handleRpc(_ json: Any) {
        guard let obj = json as? [String: AnyObject] else { fatalError("malformed json \(json)") }
        if let index = obj["id"] as? Int {
            if obj["result"] != nil || obj["error"] != nil {
                var callback: RpcCallback?
                queue.sync {
                    callback = self.pending.removeValue(forKey: index)
                }
                if let result = obj["result"] {
                    callback?(.ok(result))
                } else if let errJson = obj["error"] as? [String: AnyObject],
                    let err = RemoteError(json: errJson) {
                    callback?(.error(err))
                } else {
                    print("failed to parse response \(obj)")
                }
            } else {
                self.handleRequest(json: obj)
            }
        } else {
            self.handleNotification(json: obj)
        }
    }

    private func handleRequest(json: [String: Any]) {
        guard let request = CoreRequest.fromJson(json) else {
            return
        }

        switch request {
        case let .measureWidth(id, params):
            guard let result = client?.measureWidth(args: params) else {
                assertionFailure("measure_width request from core failed: \(params)")
                return
            }

            sendResult(id: id, result: result)
        }
    }

    private func handleNotification(json: [String: AnyObject]) {
        guard let notification = CoreNotification.fromJson(json) else {
            return
        }

        switch notification {
        case let .alert(message):
            self.client?.alert(text: message)

        case let .updateCommands(viewIdentifier, plugin, commands):
            self.client?.updateCommands(viewIdentifier: viewIdentifier,
                                        plugin: plugin,
                                        commands: commands)

        case let .scrollTo(viewIdentifier, line, column):
            self.client?.scroll(viewIdentifier: viewIdentifier, line: line, column: column)

        case let .addStatusItem(viewIdentifier, source, key, value, alignment):
            self.client?.addStatusItem(viewIdentifier: viewIdentifier, source: source, key: key, value: value, alignment: alignment)
        case let .updateStatusItem(viewIdentifier, key, value):
            self.client?.updateStatusItem(viewIdentifier: viewIdentifier, key: key, value: value)
        case let .removeStatusItem(viewIdentifier, key):
            self.client?.removeStatusItem(viewIdentifier: viewIdentifier, key: key)

        case let .update(viewIdentifier, params):
            self.client?.update(viewIdentifier: viewIdentifier,
                                params: params, rev: nil)

        case let .configChanged(viewIdentifier, config):
            self.client?.configChanged(viewIdentifier: viewIdentifier, changes: config)

        case let .defStyle(params):
            self.client?.defineStyle(params: params)

        case let .availablePlugins(viewIdentifier, plugins):
            self.client?.availablePlugins(viewIdentifier: viewIdentifier, plugins: plugins)
        case let .pluginStarted(viewIdentifier, plugin):
            self.client?.pluginStarted(viewIdentifier: viewIdentifier, pluginName: plugin)
        case let .pluginStopped(viewIdentifier, pluginName):
            self.client?.pluginStopped(viewIdentifier: viewIdentifier, pluginName: pluginName)

        case let .availableThemes(themes):
            self.client?.availableThemes(themes: themes)
        case let .themeChanged(name, theme):
            self.client?.themeChanged(name: name, theme: theme)

        case let .availableLanguages(languages):
            self.client?.availableLanguages(languages: languages)
        case let .languageChanged(viewIdentifier, languageIdentifier):
            self.client?.languageChanged(viewIdentifier: viewIdentifier, languageIdentifier: languageIdentifier)

        case let .showHover(viewIdentifier, requestIdentifier, result):
            self.client?.showHover(viewIdentifier: viewIdentifier, requestIdentifier: requestIdentifier, result: result)

        case let .findStatus(viewIdentifier, status):
            self.client?.findStatus(viewIdentifier: viewIdentifier, status: status)
        case let .replaceStatus(viewIdentifier, status):
            self.client?.replaceStatus(viewIdentifier: viewIdentifier, status: status)
        }
    }

    /// send an RPC request, returning immediately. The callback will be called when the
    /// response comes in, likely from a different thread
    func sendRpcAsync(_ method: String, params: Any, callback: RpcCallback? = nil) {
        Trace.shared.trace("send \(method)", .rpc, .begin)
        var req = ["method": method, "params": params] as [String : Any]
        if let callback = callback {
            queue.sync {
                let index = self.rpcIndex
                req["id"] = index
                self.rpcIndex += 1
                self.pending[index] = callback
            }
        }
        sendJson(req as Any)
        Trace.shared.trace("send \(method)", .rpc, .end)
    }

    /// send RPC synchronously, blocking until return. Note: there is no ordering guarantee on
    /// when this function may return. In particular, an async notification sent by the core after
    /// a response to a synchronous RPC may be delivered before it.
    func sendRpc(_ method: String, params: Any) -> RpcResult {
        let semaphore = DispatchSemaphore(value: 0)
        var result: RpcResult? = nil

        sendRpcAsync(method, params: params) { (r) in
            result = r
            semaphore.signal()
        }
        let _ = semaphore.wait(timeout: .distantFuture)
        return result!
    }
}
