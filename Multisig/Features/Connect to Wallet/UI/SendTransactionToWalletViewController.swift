//
//  SendTransactionToWalletViewController.swift
//  Multisig
//
//  Created by Dmitry Bespalov on 21.03.22.
//  Copyright © 2022 Gnosis Ltd. All rights reserved.
//

import Foundation
import UIKit
import WalletConnectSwift

class SendTransactionToWalletViewController: PendingWalletActionViewController {

    var transaction: Client.Transaction!
    var keyInfo: KeyInfo!
    var chain: Chain!

    var connection: WebConnection?
    var onSuccess: ((Data) -> ())?

    convenience init(transaction: Client.Transaction, keyInfo: KeyInfo, chain: Chain) {
        self.init(namedClass: PendingWalletActionViewController.self)
        self.wallet = WCAppRegistryRepository().entry(from: keyInfo.wallet!)
        self.keyInfo = keyInfo
        self.transaction = transaction
        self.chain = chain
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = "Sending transaction request to \(wallet.name)"
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        sendTransactionWhenConnected()
    }

    func sendTransactionWhenConnected() {
        let connections = WebConnectionController.shared.walletConnection(keyInfo: keyInfo)
        if let connection = connections.first {
            self.connection = connection
                send()
        } else {
            connect { [ unowned self] connection in
                self.connection = connection
                if connection != nil {
                    self.send()
                } else {
                    onCancel()
                }
            }
        }
    }

    func connect(completion: @escaping (WebConnection?) -> ()) {
        let walletConnectionVC = StartWalletConnectionViewController(wallet: wallet, chain: chain)

        walletConnectionVC.onSuccess = { [weak walletConnectionVC, weak self] connection in
            walletConnectionVC?.dismiss(animated: true) {
                guard let self = self else { return }
                guard connection.accounts.contains(self.keyInfo.address) else {
                    App.shared.snackbar.show(error: GSError.WCConnectedKeyMissingAddress())
                    return
                }

                if OwnerKeyController.updateKey(connection: connection, wallet: self.wallet) {
                    App.shared.snackbar.show(message: "Key connected successfully")
                }

                completion(connection)
            }
        }

        walletConnectionVC.onCancel = { [weak walletConnectionVC] in
            walletConnectionVC?.dismiss(animated: true, completion: {
                completion(nil)
            })
        }

        let vc = ViewControllerFactory.pageSheet(viewController: walletConnectionVC, halfScreen: true)
        present(vc, animated: true)
    }

    func send() {
        guard let connection = connection else { return }
        WebConnectionController.shared.sendTransaction(connection: connection, transaction: transaction) { [ unowned self ] result in
            switch result {
            case .failure(let error):
                App.shared.snackbar.show(message: error.localizedDescription)
                onCancel()
            case .success(let data):
                self.onSuccess?(data)
            }
        }

        openWallet(connection: connection)
    }

    func openWallet(connection: WebConnection) {
        if let link = wallet.navigateLink(from: connection.connectionURL) {
            LogService.shared.debug("WC: Opening \(link.absoluteString)")
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
                UIApplication.shared.open(link, options: [:]) { success in
                    if !success {
                        App.shared.snackbar.show(message: "Failed to open the wallet automatically. Please open it manually or try again.")
                    }
                }
            }
        } else {
            App.shared.snackbar.show(message: "Please open your wallet to complete this operation.")
        }
    }

    override func didTapCancel(_ sender: Any) {
        onCancel()
    }

    // connection status update

    // connection network updated

    // no response after <timeout>
}
