//
//  NewMessageView.swift
//  LBTASwiftUIFirebaseChat
//
//  Created by Christian Nonis on 15/10/22.
//

import SwiftUI
import SDWebImageSwiftUI

class NewMessageViewModel: ObservableObject {
    @Published var users = [ChatUser]()
    @Published var errorMessage = ""
    
    init() {
        fetchAllUsers()
    }
    
    private func fetchAllUsers() {
        FirebaseManager.shared.firestore.collection("users").getDocuments { res, err in
            if let err = err {
                self.errorMessage = "Failed to fetch users: \(err)"
                print("Failed to fetch users: \(err)")
                return
            }
            res?.documents.forEach({ snap in
                let data = snap.data()
                let curUser = FirebaseManager.shared.auth.currentUser?.uid
                if curUser != ChatUser(data: data).uid {
                    self.users.append(.init(data: data))
                }
            })
        }
    }
}

struct NewMessageView: View {
    
    let didSelectNewUser: (ChatUser) -> ()
    
    @Environment(\.presentationMode) var presentationMode
    
    @ObservedObject var vm = NewMessageViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                Text(vm.errorMessage)
                ForEach(vm.users) { user in
                    Button {
                        presentationMode.wrappedValue.dismiss()
                        didSelectNewUser(user)
                    } label: {
                        HStack {
                            WebImage(url: URL(string: user.profileImageUrl))
                                .resizable()
                                .scaledToFill()
                                .frame(width: 50, height: 50)
                                .clipped()
                                .cornerRadius(25)
                                .overlay(RoundedRectangle(cornerRadius: 50)
                                    .stroke(Color(.label), lineWidth: 1)
                                )
                            Text(user.email)
                                .foregroundColor(Color(.label))
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                    Divider()
                        .padding(.vertical )
                }
            }
            .navigationTitle("New Message")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button {
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Text("Cancel")
                    }
                }
            }
        }
    }
}

struct NewMessageView_Previews: PreviewProvider {
    static var previews: some View {
        NewMessageView(didSelectNewUser: {_ in })
    }
}
