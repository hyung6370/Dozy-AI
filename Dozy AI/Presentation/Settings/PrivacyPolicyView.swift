//
//  PrivacyPolicyView.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/13/26.
//

import SwiftUI
import SafariServices

struct PrivacyPolicyView: View {

    let url: URL

    var body: some View {
        SafariView(url: url)
            .ignoresSafeArea()
    }
}

// MARK: - SafariView

private struct SafariView: UIViewControllerRepresentable {

    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        config.barCollapsingEnabled = true
        return SFSafariViewController(url: url, configuration: config)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
