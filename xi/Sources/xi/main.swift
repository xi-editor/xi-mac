import Foundation
import Utility

let parser = ArgumentParser(
    usage: "<options> [path]",
    overview: "xi - A modern editor with a backend written in Rust"
)

let versionArg: OptionArgument<Bool> = parser.add(
    option: "--version",
    shortName: "-v",
    kind: Bool.self,
    usage: "Print version information."
)

let helpArg: OptionArgument<Bool> = parser.add(
    option: "--help",
    shortName: "-h",
    kind: Bool.self,
    usage: "Show this information."
)

let waitArg: OptionArgument<Bool> = parser.add(
    option: "--wait",
    shortName: "-w",
    kind: Bool.self,
    usage: "Wait for file to be closed by Xi"
)

func run(arguments: ArgumentParser.Result) {
    // TODO: How do we communicate with Xi? Using IPC?
    if arguments.get(versionArg) != nil {
        print("TODO: Find the version")
        exit(0)
    }
    else if arguments.get(waitArg) != nil {
        print("TODO: Open the file/stdin and wait")
        exit(0)
    }
    // TODO: Handle path. E.g. git will invoke using
    // /<path-to-project>/.git/COMMIT_EDITMSG
}

do {
    // The first argument is the executable, which we don't need.
    let arguments = Array(ProcessInfo.processInfo.arguments.dropFirst())
    let parsedArguments = try parser.parse(arguments)
    run(arguments: parsedArguments)
}
catch let error as ArgumentParserError {
    print(error.description)
    exit(1)
}
catch let error {
    print(error.localizedDescription)
    exit(2)
}
