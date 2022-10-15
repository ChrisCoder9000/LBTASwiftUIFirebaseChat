//
//  LBTASwiftUIFirebaseChatApp.swift
//  LBTASwiftUIFirebaseChat
//
//  Created by Christian Nonis on 14/10/22.
//

import SwiftUI

@main
struct LBTASwiftUIFirebaseChatApp: App {
    var body: some Scene {
        WindowGroup {
            LoginView(didCompleteLoginProcess: {})
        }
    }
}
