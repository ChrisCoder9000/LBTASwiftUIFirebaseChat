//
//  ChatLogView.swift
//  LBTASwiftUIFirebaseChat
//
//  Created by Christian Nonis on 16/10/22.
//

import SwiftUI
import FirebaseFirestoreSwift
import FirebaseFirestore

struct RecentMessage: Codable, Identifiable {
    @DocumentID var id: String?
    
//    let documentId: String
    let text, fromId, toId: String
    let email, profileImageUrl: String
    let timestamp: Date
    
//    init(documentId: String, data: [String: Any]) {
//        self.documentId = documentId
//        self.text = data["text"] as? String ?? ""
//        self.email = data["email"] as? String ?? ""
//        self.fromId = data["fromId"] as? String ?? ""
//        self.toId = data["toId"] as? String ?? ""
//        self.timestamp = data["timestamp"] as? Timestamp ?? Timestamp(date: Date())
//        self.profileImageUrl = data["profileImageUrl"] as? String ?? ""
//    }
}

struct FirebaseConstants {
    static let fromId = "fromId"
    static let toId = "toId"
    static let text = "text"
    static let email = "email"
    static let profileImageUrl = "profileImageUrl"
}

struct ChatMessage: Identifiable {
    
    var id: String { documentId }
    
    let documentId: String
    let fromId, toId, text: String
    
    init(documentId: String, data: [String: Any]) {
        self.documentId = documentId
        self.fromId = data[FirebaseConstants.fromId] as? String ?? ""
        self.toId = data[FirebaseConstants.toId] as? String ?? ""
        self.text = data[FirebaseConstants.text] as? String ?? ""
    }
}

class ChatLogViewModel: ObservableObject {
    
    @Published var chatText = ""
    @Published var errorMessage = ""
    
    @Published var chatMessages = [ChatMessage]()
    
    let chatUser: ChatUser?
    
    init(chatUser: ChatUser?) {
        self.chatUser = chatUser
        
        fetchMessages()
    }
    
    private func fetchMessages() {
        guard let fromId = FirebaseManager.shared.auth.currentUser?.uid else { return }
        guard let toId = chatUser?.uid else { return }
        FirebaseManager.shared.firestore
            .collection("messages")
            .document(fromId)
            .collection(toId)
            .order(by: "timestamp")
            .addSnapshotListener { querySnapshot, error in
                if let error = error {
                    self.errorMessage = "Failed to listen for messages: \(error)"
                    print(error)
                    return
                }
                
                querySnapshot?.documentChanges.forEach({ change in
                    if change.type == .added {
                        let data = change.document.data()
                        self.chatMessages.append(.init(documentId: change.document.documentID, data: data))
                    }
                })
            }
        
    }
    
    func handleSend() {
        guard let fromId = FirebaseManager.shared.auth.currentUser?.uid else { return }
        guard let toId = chatUser?.uid else { return }
        let document = FirebaseManager.shared.firestore.collection("messages")
            .document(fromId)
            .collection(toId)
            .document()
        let messageData = ["fromId" : fromId, "toId" : toId, "text" : self.chatText, "timestamp" : Date()] as [String : Any]
        document.setData(messageData) { err in
            if let err = err {
                self.errorMessage = "Failed to save message into Firestore: \(err)"
                return
            }
            
            self.persistRecentMessage()
            
            self.chatText = ""
            self.count += 1
        }
        
        let recipientMessageDocument = FirebaseManager.shared.firestore.collection("messages")
            .document(toId)
            .collection(fromId)
            .document()
        recipientMessageDocument.setData(messageData) { error in
            if let error = error {
                print(error)
                self.errorMessage = "Failed to save message into Firestore: \(error)"
                return
            }
            
        }
        DispatchQueue.main.async {
            self.count += 10
        }
    }
    
    private func persistRecentMessage() {
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else { return }
        guard let toId = self.chatUser?.uid else { return }
        let document = FirebaseManager.shared.firestore.collection("recent_messages")
            .document(uid)
            .collection("messages")
            .document()
        
        let data = [
            "timestamp": Timestamp(),
            "text": self.chatText,
            "fromId": uid,
            FirebaseConstants.toId: toId,
            FirebaseConstants.profileImageUrl: chatUser?.profileImageUrl ?? "",
            FirebaseConstants.email: chatUser?.email ?? ""
        ] as [String: Any]
        
        document.setData(data) { err in
            if let err = err {
                self.errorMessage = "Failed to save recent message: \(err)"
                print("Failed to save recent message: \(err)")
                return
            }
        }
    }
    
    @Published var count = 0
}

struct ChatLogView: View {
    
    let chatUser: ChatUser?
    
    init(chatUser: ChatUser?) {
        self.chatUser = chatUser
        self.vm = .init(chatUser: chatUser)
    }
    
    @ObservedObject var vm: ChatLogViewModel
    
    var body: some View {
        ZStack {
            messagesView
            Text(vm.errorMessage)
        }
        .navigationTitle(chatUser?.email ?? "no email")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(trailing:
                                Button {
            vm.count += 1
        } label: {
            Text("Conut: \(vm.count)")
        }
        )
    }
    
    static let emptyScrollToString = "Empty"
    
    private var messagesView: some View {
        VStack {
            if #available(iOS 15.0, *) {
                ScrollView {
                    ScrollViewReader { scrollViewProxy in
                        VStack {
                            ForEach(vm.chatMessages) { message in
                                MessageView(message: message)
                            }
                            HStack { Spacer() }
                                .id(Self.emptyScrollToString)
                        }
                        .onReceive(vm.$count) { _ in
                            withAnimation(.easeOut(duration: 0.5)) {
                                scrollViewProxy.scrollTo("Empty", anchor: .bottom)
                            }
                        }
                    }
                }
                .background(Color(.init(white: 0.95, alpha: 1)))
                .safeAreaInset(edge: .bottom) {
                    chatBottomBar
                        .background(Color(.systemBackground))
                }
            } else {
                // Fallback on earlier versions
            }
        }
    }
    
    private var chatBottomBar: some View {
        HStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 24))
                .foregroundColor(Color(.darkGray))
            TextField("Description", text: $vm.chatText)
            Button {
                vm.handleSend()
            } label: {
                Text("Send")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

struct MessageView: View {
    
    let message: ChatMessage
    
    var body: some View {
        if message.fromId == FirebaseManager.shared.auth.currentUser?.uid {
            HStack {
                Spacer()
                HStack {
                    Text(message.text)
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding(.horizontal)
        } else {
            HStack {
                HStack {
                    Text(message.text)
                }
                .padding()
                .background(Color(.systemBackground))
                .foregroundColor(Color(.label))
                .cornerRadius(12)
                Spacer()
            }
            .padding(.horizontal)
        }
    }
}

struct ChatLogView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            //            ChatLogView(chatUser: .init(data: ["email": "fake@gmail.com"]))
            MainMessagesView()
        }
    }
}
