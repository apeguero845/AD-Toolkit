//
//  main.swift
//  HelperTool
//
//  Privileged helper tool daemon for AD Toolkit.
//  Installed and managed via SMAppService.
//  Runs as root, communicates with the main app via XPC.
//
//  References:
//    - SMAppService: developer.apple.com/documentation/servicemanagement/smappservice
//    - SwiftAuthorizationSample: github.com/trilemma-dev/SwiftAuthorizationSample
//

import Foundation

let delegate = HelperToolDelegate()
let listener = NSXPCListener.service()
listener.delegate = delegate
listener.resume()

// Keep the process running
RunLoop.main.run()
