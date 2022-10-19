//
//  MainMessagesView.swift
//  LBTASwiftUIFirebaseChat
//
//  Created by Christian Nonis on 15/10/22.
//

import SwiftUI
import SDWebImageSwiftUI
import FirebaseFirestoreSwift

extension Date {

    static func diffDate(lhs: Date, rhs: Date) -> TimeInterval {
        return lhs.timeIntervalSinceReferenceDate - rhs.timeIntervalSinceReferenceDate
    }

}

class MainMessagesViewModel: ObservableObject {
    @Published var errorMessage = ""
    @Published var chatUser: ChatUser?
    
    init() {
        self.isUserCurrentlyLoggedOut = FirebaseManager.shared.auth.currentUser?.uid == nil
        
        fetchCurrentUser()
        fetchRecentMessages()
    }
    
    @Published var recentMessages = [RecentMessage]()
    
    private func fetchRecentMessages() {
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else { return }
        FirebaseManager.shared.firestore.collection("recent_messages")
            .document(uid)
            .collection("messages")
            .order(by: "timestamp")
            .addSnapshotListener { querySnapshot, err in
                if let err = err {
                    self.errorMessage = "Failed to listen for recent messages: \(err)"
                    print(err)
                    return}
                
                querySnapshot?.documentChanges.forEach({ change in
                    let docId = ChatMessage(documentId: change.document.documentID, data: change.document.data())
                    if let index = self.recentMessages.firstIndex(where: { recentMessage in
                        return recentMessage.toId == docId.toId
                    }) {
                        self.recentMessages.remove(at: index)
                    }
//                    do {
                        if let rm = try? change.document.data(as: RecentMessage.self) {
                            self.recentMessages.insert(rm, at: 0)
                        }
//                    } catch {
//                        print(error)
//                    }
//                    self.recentMessages.insert(.init(documentId: docId.documentId, data: change.document.data()), at: 0)
                })
            }
    }
    
    func fetchCurrentUser() {
        self.errorMessage = "Fetching current user..."
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else {
            self.errorMessage = "Could not find firebase uid"
            return
        }
        FirebaseManager.shared.firestore.collection("users").document(uid).getDocument { snapshot, err in
            if let err = err {
                self.errorMessage =  "Failed to fetch current user: \(err)"
                print("Failed to fetch current user:", err)
                return
            }
            guard let data = snapshot?.data() else { return }
            
            self.chatUser = .init(data: data)
        }
    }
    
    @Published var isUserCurrentlyLoggedOut = false
    
    func handleSignout() {
        do {
            try FirebaseManager.shared.auth.signOut()
            isUserCurrentlyLoggedOut = true
        } catch {
            print("error signing out")
        }
    }
}

struct MainMessagesView: View {
    
    @State var shouldShowLogoutOptions: Bool = false
    @ObservedObject private var vm = MainMessagesViewModel()
    
    @State var shouldNavigateToChatLogView = false
    
    var body: some View {
        NavigationView {
            VStack {
                customNavBar
                messagesView
                
                NavigationLink("", isActive: $shouldNavigateToChatLogView) {
                    ChatLogView(chatUser: self.chatUser)
                }
            }
            .overlay(newMessageButton, alignment: .bottom)
            .navigationBarHidden(true)
        }
    }
    
    private var customNavBar: some View {
        HStack(spacing: 16) {
            
            WebImage(url: URL(string: vm.chatUser?.profileImageUrl ?? "person.fill"))
                .resizable()
                .scaledToFill()
                .frame(width: 50, height: 50)
                .clipped()
                .cornerRadius(25)
            
            VStack(alignment: .leading, spacing: 4) {
                if let mail = vm.chatUser?.email {
                    let domain = mail[(mail.range(of: "@")!.upperBound...)]
                    Text(mail.replacingOccurrences(of: "@\(domain)", with: ""))
                        .font(.system(size: 24, weight: .bold))
                }
                HStack {
                    Circle()
                        .foregroundColor(.green)
                        .frame(width: 14, height: 14)
                    Text("online")
                        .font(.system(size: 12))
                        .foregroundColor(Color(.lightGray))
                }
            }
            Spacer()
            Button {
                shouldShowLogoutOptions.toggle()
            } label: {
                Image(systemName: "gear")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(.label))
            }
        }
        .padding()
        .background(Color(.systemBlue).opacity(0.05))
        .edgesIgnoringSafeArea(.horizontal)
        .actionSheet(isPresented: $shouldShowLogoutOptions) {
            .init(title: Text("Settings"), message: Text("What do you want to do?"), buttons: [
                .destructive(Text("Sign Out"), action: {
                    vm.handleSignout()
                }),
                .cancel()
            ])
        }
        .fullScreenCover(isPresented: $vm.isUserCurrentlyLoggedOut) {
            LoginView(didCompleteLoginProcess: {
                self.vm.isUserCurrentlyLoggedOut = false
                self.vm.fetchCurrentUser()
            })
        }
    }
    
    private var messagesView: some View {
        ScrollView {
            ForEach(vm.recentMessages) {recentMessage in
                VStack {
                    NavigationLink {
                        Text("Destination")
                    } label: {
                        HStack(spacing: 16) {
                            WebImage(url: URL(string: recentMessage.profileImageUrl))
                                .resizable()
                                .scaledToFill()
                                .frame(width: 64, height: 64)
                                .cornerRadius(32)
                                .overlay(RoundedRectangle(cornerRadius: 32)
                                    .stroke(Color(.label), lineWidth: 1)
                                )
                            VStack(alignment: .leading) {
                                Text(recentMessage.email)
                                    .font(.system(size: 16, weight: .bold))
                                Text(recentMessage.text)
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(.lightGray))
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(1)
                            }
                            Spacer()
                            let dateNow = Date()
                            let aD = (Date.diffDate(lhs: dateNow, rhs: recentMessage.timestamp)) / 60
                            if aD <= 60 {
                                Text("\(String(format: "%.0f", round(aD)))m ago")
                                    .font(.system(size: 14, weight: .semibold))
                            } else if aD >= 60 {
                                Text("\(String(format: "%.0f", round(aD / 60)))h ago")
                                    .font(.system(size: 14, weight: .semibold))
                            } else if aD >= 1440 {
                                Text("\(String(format: "%.0f", round(aD / 1440)))d ago")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top, 20)
            .padding(.bottom, 80)
        }
    }
    
    @State private var shouldShowNewMessageScreen = false
    
    private var newMessageButton: some View {
        Button {
            shouldShowNewMessageScreen.toggle()
        } label: {
            HStack {
                Spacer()
                Text("+ New Message")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
            }
            .foregroundColor(.white)
            .padding(.vertical)
            .background(Color(.systemBlue))
            .cornerRadius(32)
            .padding(.horizontal)
            .shadow(radius: 3)
        }
        .fullScreenCover(isPresented: $shouldShowNewMessageScreen) {
            NewMessageView(didSelectNewUser: {user in
                print(user.email)
                self.shouldNavigateToChatLogView.toggle()
                self.chatUser = user
            })
        }
    }
    
    @State var chatUser: ChatUser?
}

struct MainMessagesView_Previews: PreviewProvider {
    static var previews: some View {
        MainMessagesView()
            .preferredColorScheme(.light)
    }
}
