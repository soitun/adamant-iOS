//
//  NotificationsView.swift
//  Adamant
//
//  Created by Yana Silosieva on 05.08.2024.
//  Copyright © 2024 Adamant. All rights reserved.
//

import SwiftUI
import CommonKit

struct NotificationsView: View {
    @ObservedObject var viewModel: NotificationsViewModel
    
    var body: some View {
        GeometryReader { geometry in
            Form {
                notificationsSection()
                messageSoundSection()
                messageReactionsSection()
                inAppNotificationsSection()
                settingsSection()
                moreDetailsSection()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    toolbar(maxWidth: geometry.size.width)
                }
            }
            .sheet(isPresented: $viewModel.presentSoundsPicker, content: {
                NotificationSoundsPickerView(notificationService: viewModel.notificationsService, target: .baseMessage)
            })
            .sheet(isPresented: $viewModel.presentReactionSoundsPicker, content: {
                NotificationSoundsPickerView(notificationService: viewModel.notificationsService, target: .reaction)
            })
            .fullScreenCover(isPresented: $viewModel.openSafariURL) {
                SafariWebView(url: viewModel.safariURL).ignoresSafeArea()
            }
        }
    }
}

private extension NotificationsView {
    func toolbar(maxWidth: CGFloat) -> some View {
        HStack {
            Text(viewModel.notificationsTitle)
                .font(.headline)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: maxWidth - toolbarSpace, alignment: .center)
    }
    
    func notificationsSection() -> some View {
        Section {
            Button(action: {
                viewModel.showAlert()
            }, label: {
                HStack {
                    Text(viewModel.notificationsTitle)
                    Spacer()
                    Text(viewModel.notificationsMode.localized)
                        .foregroundColor(.gray)
                    NavigationLink(destination: { EmptyView() }, label: { EmptyView() }).fixedSize()
                }
            })
        } header: {
            Text(viewModel.notificationsTitle)
        }
    }
    
    func messageSoundSection() -> some View {
        Section {
            Button(action: {
                viewModel.presentNotificationSoundsPicker()
            }, label: {
                HStack {
                    Text(soundTitle)
                    Spacer()
                    Text(viewModel.notificationSound.localized)
                        .foregroundColor(.gray)
                    NavigationLink(destination: { EmptyView() }, label: { EmptyView() }).fixedSize()
                }
            })
        } header: {
            Text(soundHeader)
        }
    }
    
    func messageReactionsSection() -> some View {
        Section {
            Button(action: {
                viewModel.presentReactionNotificationSoundsPicker()
            }, label: {
                HStack {
                    Text(soundTitle)
                    Spacer()
                    Text(viewModel.notificationReactionSound.localized)
                        .foregroundColor(.gray)
                    NavigationLink(destination: { EmptyView() }, label: { EmptyView() }).fixedSize()
                }
            })
        } header: {
            Text(reactionsHeader)
        }
    }
    
    func inAppNotificationsSection() -> some View {
        Section {
            Toggle(isOn: $viewModel.inAppSounds) {
                Text("Sounds")
            }
            .tint(.init(uiColor: .adamant.active))
            
            Toggle(isOn: $viewModel.inAppVibrate) {
                Text("Vibrate")
            }
            .tint(.init(uiColor: .adamant.active))
            
            Toggle(isOn: $viewModel.inAppToasts) {
                Text("Toasts")
            }
            .tint(.init(uiColor: .adamant.active))
        } header: {
            Text(inAppNotifications)
        }
    }
    
    func settingsSection() -> some View {
        Section {
            Button(action: {
                viewModel.openAppSettings()
            }, label: {
                HStack {
                    Text(settingsHeader)
                    Spacer()
                    NavigationLink(destination: { EmptyView() }, label: { EmptyView() }).fixedSize()
                }
            })
        } header: {
            Text(settingsHeader)
        }
    }
    
    func moreDetailsSection() -> some View {
        Section {
            if let attributedString = viewModel.parseMarkdown(descriptionText) {
                Text(AttributedString(attributedString))
            }
            
            Button(action: {
                viewModel.presentSafariURL()
            }, label: {
                HStack {
                    Image(uiImage: viewModel.githubRowImage)
                    
                    Text(visitGithub)
                    
                    Spacer()
                    
                    NavigationLink(destination: { EmptyView() }, label: { EmptyView() }).fixedSize()
                }
                .padding()
            })
        }
    }
}


private let toolbarSpace: CGFloat = 150

private var soundHeader: String {
    .localized("SecurityPage.Section.Messages")
}

private var soundTitle: String {
    .localized("Notifications.Sound.Name")
}

private var settingsHeader: String {
    .localized("Notifications.Settings.System")
}

private var descriptionText: String {
    .localized("SecurityPage.Row.Notifications.ModesDescription")
}

private var visitGithub: String {
    .localized("SecurityPage.Row.VisitGithub")
}

private var reactionsHeader: String {
    "Reactions"
}

private var inAppNotifications: String {
    "In-app notifications"
}
