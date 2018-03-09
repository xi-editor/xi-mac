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

/// Env var used to specify a path for logging RPC messages.
/// These logs can be used for profiling & debugging.
let XI_RPC_LOG = "XI_CLIENT_RPC_LOG"

/// Error tolerant wrapper for append-writing to a file.
struct FileWriter {
    let path: URL
    let handle: FileHandle
    
    init?(path: String) {
        let path = NSString(string: path).expandingTildeInPath
        if FileManager.default.fileExists(atPath: path) {
            print("file exists at \(path), will not overwrite")
            return nil
        }
        self.path = URL(fileURLWithPath: path)
        FileManager.default.createFile(atPath: self.path.path, contents: nil, attributes: nil)
        
        do {
            try self.handle = FileHandle(forWritingTo: self.path)
        } catch let err as NSError {
            print("error opening log file \(err)")
            return nil
        }
    }
    
    func write(bytes: Data) {
        handle.write(bytes)
    }
}

class CoreConnection {
    
    let task = Process()
    var timer: Timer?
    var inHandle: FileHandle  // stdin of core process
    var recvBuf: Data
    weak var client: XiClient?
    let rpcLogWriter: FileWriter?
    let errLogWriter: FileWriter?
    
    // default log directory on MacOS is /Library/Logs
    let logDirectory = FileManager.default.urls(
        for: .libraryDirectory,
        in: .userDomainMask)
        .first!
        .appendingPathComponent("Logs")
        .appendingPathComponent("XiEditor")
    
    // RPC state
    var queue = DispatchQueue(label: "com.levien.xi.CoreConnection", attributes: [])
    var rpcIndex = 0
    var pending = Dictionary<Int, (Any?) -> ()>()
    
    var errOutput = "" // output of stderr as String
    
    init(path: String) {
        if let rpcLogPath = ProcessInfo.processInfo.environment[XI_RPC_LOG] {
            self.rpcLogWriter = FileWriter(path: rpcLogPath)
            if self.rpcLogWriter != nil {
                print("logging client RPC to \(rpcLogPath)")
            }
        } else {
            self.rpcLogWriter = nil
        }
        
        let tmpErrLog = logDirectory.appendingPathComponent("xi_tmp.err").path
        
        self.errLogWriter = FileWriter(path: tmpErrLog)
        if self.errLogWriter != nil {
            print("logging stderr to \(tmpErrLog)")
        }
          
        task.launchPath = path
        task.arguments = []
        let outPipe = Pipe()
        task.standardOutput = outPipe
        let inPipe = Pipe()
        task.standardInput = inPipe
        let errPipe = Pipe()
        task.standardError = errPipe
        inHandle = inPipe.fileHandleForWriting
        recvBuf = Data()
        
        outPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            self.recvHandler(data)
        }
        
        errPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            var lineCount = 1
            
            self.errLogWriter?.write(bytes: data)
            
            if let errString = String(data: data, encoding: String.Encoding.utf8) {
                print(errString, terminator: "")
                self.errOutput += errString
            }
            
            if self.errOutput.hasSuffix("\n") {
                lineCount += 1
                
                if lineCount >= 100 {
                    self.errOutput = ""
                    lineCount = 1
                }
            }
        }
        
        // write to log on xi-core crash
        task.terminationHandler = { _ in
            // get current date to use as timestamp
            let dateFormatter = DateFormatter()
            let currentTime = Date.init()
            dateFormatter.dateFormat = "yyyy-MM-dd-HHMMSS"
            let timeStamp = dateFormatter.string(from: currentTime)
            
            let tmpErrLog = self.logDirectory.appendingPathComponent("xi_tmp.err")
            let timestampedLog = self.logDirectory.appendingPathComponent("XiEditor_\(timeStamp).err")
            
            do {
                try FileManager.default.moveItem(at: tmpErrLog, to: timestampedLog)
            } catch let error as NSError {
                print("failed to rename file with error: \(error)")
            }
            
            print(self.errOutput)
            self.errLogWriter?.write(bytes: self.errOutput.data(using: String.Encoding.utf8)!)
        }
        
        task.launch()
    }
    
    func recvHandler(_ data: Data) {
        if data.count == 0 {
            print("eof")
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
                    let bufferPointer = UnsafeBufferPointer(start: recvBufBytes.advanced(by: i), count: j + 1 - i);
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
    
    func sendJson(_ json: Any) {
        do {
            let data = try JSONSerialization.data(withJSONObject: json, options: [])
            let mutdata = NSMutableData()
            mutdata.append(data)
            let nl = [0x0a as UInt8]
            mutdata.append(nl, length: 1)
            rpcLogWriter?.write(bytes: mutdata as Data)
            inHandle.write(mutdata as Data)
        } catch _ {
            print("error serializing to json")
        }
    }
    
    func handleRaw(_ data: Data) {
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
    func handleRpc(_ json: Any) {
        guard let obj = json as? [String: AnyObject] else { fatalError("malformed json \(json)") }
        if let index = obj["id"] as? Int {
            if let result = obj["result"] { // is response
                var callback: ((Any?) -> ())?
                queue.sync {
                    callback = self.pending.removeValue(forKey: index)
                }
                callback?(result)
            } else {
                self.handleRequest(json: obj)
            }
        } else {
            self.handleNotification(json: obj)
        }
    }
    
    func handleRequest(json: [String: AnyObject]) {
        // there are currently no core -> client requests in the protocol
        print("Unexpected RPC Request: \(json)")
    }
    
    func handleNotification(json: [String: AnyObject]) {
        guard let method = json["method"] as? String, let params = json["params"]
            else {
                print("unknown json from core: \(json)")
                return
        }
        let viewIdentifier = params["view_id"] as? ViewIdentifier
        
        switch method {
        case "update":
            let update = params["update"] as! [String: AnyObject]
            self.client?.update(viewIdentifier: viewIdentifier!, update: update, rev: nil)
            
        case "scroll_to":
            let line = params["line"] as! Int
            let col = params["col"] as! Int
            self.client?.scroll(viewIdentifier: viewIdentifier!, line: line, column: col)
            
        case "def_style":
            client?.defineStyle(style: params as! [String: AnyObject])
            
        case "plugin_started":
            let plugin = params["plugin"] as! String
            client?.pluginStarted(viewIdentifier: viewIdentifier!, pluginName: plugin)
            
        case "plugin_stopped":
            let plugin = params["plugin"] as! String
            client?.pluginStopped(viewIdentifier: viewIdentifier!, pluginName: plugin)
            
        case "available_themes":
            let themes = params["themes"] as! [String]
            client?.availableThemes(themes: themes)
            
        case "theme_changed":
            let name = params["name"] as! String
            let themeJson = params["theme"] as! [String: AnyObject]
            let theme = Theme(jsonObject: themeJson)
            client?.themeChanged(name: name, theme: theme)
            
        case "available_plugins":
            let plugins = params["plugins"] as! [[String: AnyObject]]
            client?.availablePlugins(viewIdentifier: viewIdentifier!, plugins: plugins)
            
        case "update_cmds":
            let plugin = params["plugin"] as! String
            let cmdsJson = params["cmds"] as! [[String: AnyObject]]
            let cmds = cmdsJson.map { Command(jsonObject: $0) }
                .filter { $0 != nil }
                .map { $0! }
            
            client?.updateCommands(viewIdentifier: viewIdentifier!,
                                   plugin: plugin, commands: cmds)
            
        case "config_changed":
            let changes = params["changes"] as! [String: AnyObject]
            client?.configChanged(viewIdentifier: viewIdentifier!, changes: changes)
            
        case "alert":
            let message = params["msg"] as! String
            client?.alert(text: message)
            
        default:
            print("unknown notification \(method)")
        }
    }
    
    /// send an RPC request, returning immediately. The callback will be called when the
    /// response comes in, likely from a different thread
    func sendRpcAsync(_ method: String, params: Any, callback: ((Any?) -> ())? = nil) {
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
    func sendRpc(_ method: String, params: Any) -> Any? {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Any? = nil
        sendRpcAsync(method, params: params) { r in
            result = r
            semaphore.signal()
        }
        let _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        return result
    }
}
