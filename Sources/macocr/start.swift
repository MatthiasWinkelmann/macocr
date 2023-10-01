import ArgumentParser
@available(macOS 15.0, *)
@main
struct Repeat: ArgumentParser.ParsableCommand {
    @Flag(inversion: FlagInversion.prefixedNo, help: "fast")
    var fast = false


    // @Option(name: .shortAndLong, help: "User word file")
    // var wordfile: String?

    @Argument(completion: .file(extensions: ["jpg","jpeg","png","tiff","heic"]))
    var files: [String] = []


    mutating func run() throws {
        Runner.run( files: files)

    }
}
