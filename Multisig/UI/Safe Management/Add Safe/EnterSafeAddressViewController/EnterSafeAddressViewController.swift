//
//  EnterSafeAddressViewController.swift
//  Multisig
//
//  Created by Dmitry Bespalov on 14.12.20.
//  Copyright © 2020 Gnosis Ltd. All rights reserved.
//

import UIKit
import Web3

class EnterSafeAddressViewController: UIViewController {
    var websiteURL = App.configuration.services.webAppURL
    var address: Address? { addressField?.address }
    var gatewayService = App.shared.clientGatewayService
    var completion: () -> Void = { }
    var chain: SCGModels.Chain!
    var safeVersion: String?
    lazy var trackingParameters: [String: Any]  = { ["chain_id" : chain.chainId.description] }()

    @IBOutlet private weak var headerLabel: UILabel!
    @IBOutlet private weak var addressField: AddressField!
    @IBOutlet private weak var actionStackView: UIStackView!
    @IBOutlet private weak var actionLabel: UILabel!
    @IBOutlet private weak var openWebsiteButton: UIButton!
    @IBOutlet private weak var externalLinkIcon: UIImageView!
    @IBOutlet private weak var suggestionStackView: UIStackView!

    private var loadSafeTask: URLSessionTask?
    private var nextButton: UIBarButtonItem!

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Load Gnosis Safe"

        headerLabel.setStyle(.headline)

        actionLabel.setStyle(.primary)

        addressField.setPlaceholderText("Enter Safe address")
        addressField.onTap = { [weak self] in self?.didTapAddressField() }

        nextButton = UIBarButtonItem(title: "Next", style: .done, target: self, action: #selector(didTapNextButton(_:)))
        nextButton.isEnabled = false

        navigationItem.rightBarButtonItem = nextButton

        openWebsiteButton.setText(websiteURL.absoluteString, .plain)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Tracker.trackEvent(.safeAddAddress, parameters: trackingParameters)
    }

    @IBAction private func didTapOpenWebsiteButton(_ sender: Any) {
        openInSafari(websiteURL)
    }

    @objc private func didTapNextButton(_ sender: Any) {
        guard let address = address else { return }
        // NOTE: blank lines for better readability

        let enterAddressVC = EnterAddressNameViewController()
        enterAddressVC.trackingParameters = trackingParameters

        let enterAddressWrapperVC = RibbonViewController(rootViewController: enterAddressVC)
        enterAddressWrapperVC.chain = chain

        enterAddressVC.address = address
        enterAddressVC.trackingEvent = .safeAddName
        enterAddressVC.screenTitle = "Load Gnosis Safe"
        enterAddressVC.descriptionText = "Choose a name for the Safe. The name is only stored locally and will not be shared with Gnosis or any third parties."
        enterAddressVC.actionTitle = "Next"
        enterAddressVC.placeholder = "Enter name"

        enterAddressVC.completion = { [unowned enterAddressVC, unowned self] name in
            let coreDataChain = Chain.createOrUpdate(chain)
            Safe.create(address: address.checksummed, version: safeVersion!, name: name, chain: coreDataChain)

            let createdCompletion = { [unowned self] in
                self.completion()
                App.shared.notificationHandler.safeAdded(address: address)
            }

            if !AppSettings.hasShownImportKeyOnboarding && !OwnerKeyController.hasPrivateKey {

                let loadedVC = SafeLoadedViewController()
                loadedVC.completion = createdCompletion

                let loadedWrapperVC = RibbonViewController(rootViewController: loadedVC)
                loadedWrapperVC.chain = self.chain
                loadedWrapperVC.hidesBottomBarWhenPushed = true

                enterAddressVC.show(loadedWrapperVC, sender: enterAddressVC)

                AppSettings.hasShownImportKeyOnboarding = true
            } else {
                createdCompletion()
            }
        }
        show(enterAddressWrapperVC, sender: self)
    }

    private func didTapAddressField() {
        let alertVC = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        alertVC.addAction(UIAlertAction(title: "Paste from Clipboard", style: .default, handler: { [weak self] _ in
            let text = Pasteboard.string
            self?.didEnterText(text)
        }))

        alertVC.addAction(UIAlertAction(title: "Scan QR Code", style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            let vc = QRCodeScannerViewController()
            vc.trackingParameters = self.trackingParameters
            vc.scannedValueValidator = { value in
                if Address(value) != nil {
                    return .success(value)
                } else {
                    return .failure(GSError.error(description: "Can’t use this QR code",
                                                  error: GSError.SafeAddressNotValid()))
                }
            }
            vc.modalPresentationStyle = .overFullScreen
            vc.delegate = self
            vc.setup()
            self.present(vc, animated: true, completion: nil)
        }))

        let blockchainDomainManager = BlockchainDomainManager(rpcURL: chain.authenticatedRpcUrl,
                                                              networkName: chain.chainName,
                                                              ensRegistryAddress: chain.ensRegistryAddress)

        if blockchainDomainManager.ens != nil {
            alertVC.addAction(UIAlertAction(title: "Enter ENS Name", style: .default, handler: { [weak self] _ in
                guard let self = self else { return }
                let ensNameVC = EnterENSNameViewController(manager: blockchainDomainManager)
                ensNameVC.trackingParameters = self.trackingParameters
                ensNameVC.onConfirm = { [weak self] in
                    guard let `self` = self else { return }
                    self.navigationController?.popViewController(animated: true)
                    self.didEnterText(ensNameVC.address?.checksummed)
                }
                let ensNameWrapperVC = RibbonViewController(rootViewController: ensNameVC)
                ensNameWrapperVC.chain = self.chain
                self.show(ensNameWrapperVC, sender: nil)
            }))
        }

        if blockchainDomainManager.unstoppableDomainResolution != nil {
            alertVC.addAction(UIAlertAction(title: "Enter Unstoppable Name", style: .default, handler: { [weak self] _ in
                guard let self = self else { return }
                let udNameVC = EnterUnstoppableNameViewController(manager: blockchainDomainManager)
                udNameVC.trackingParameters = self.trackingParameters
                udNameVC.onConfirm = { [weak self] in
                    guard let `self` = self else { return }
                    self.navigationController?.popViewController(animated: true)
                    self.didEnterText(udNameVC.address?.checksummed)
                }
                let udNameWrapperVC = RibbonViewController(rootViewController: udNameVC)
                udNameWrapperVC.chain = self.chain
                self.show(udNameWrapperVC, sender: nil)
            }))
        }

        alertVC.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        present(alertVC, animated: true, completion: nil)
    }

    private func setSuggestionHidden(_ isHidden: Bool) {
        suggestionStackView.isHidden = isHidden
        externalLinkIcon.isHidden = isHidden
    }

    private func didEnterText(_ text: String?) {
        addressField.clear()
        loadSafeTask?.cancel()
        nextButton.isEnabled = false
        setSuggestionHidden(false)

        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return
        }

        setSuggestionHidden(true)

        guard !text.isEmpty else {
            addressField.setError("Safe address should not be empty")
            return
        }
        addressField.setInputText(text)
        do {
            // (1) validate that the text is address
            let address = try Address(text, isERC681: true)
            addressField.setAddress(address)

            // (2) and that there's no such safe already
            let exists = Safe.exists(address.checksummed, chainId: chain.id)
            if exists { throw GSError.SafeAlreadyExists() }

            // (3) and there exists safe at that address
            addressField.setLoading(true)

            loadSafeTask = gatewayService.asyncSafeInfo(safeAddress: address,
                                                        chainId: chain.id,
                                                        completion: { [weak self] result in
                DispatchQueue.main.async {
                    self?.addressField.setLoading(false)
                }
                switch result {
                case .failure(let error):
                    DispatchQueue.main.async { [weak self] in
                        guard let `self` = self else { return }
                        // ignore cancellation error due to cancelling the
                        // currently running task. Otherwise user will see
                        // meaningless message.
                        if (error as NSError).code == URLError.cancelled.rawValue &&
                            (error as NSError).domain == NSURLErrorDomain {
                            return
                        } else if error is GSError.EntityNotFound {
                            let message = GSError.error(description: "Can’t use this address",
                                                        error: GSError.InvalidSafeAddress()).localizedDescription
                            self.addressField.setError(message)
                        } else {
                            let message = GSError.error(description: "Can’t use this address", error: error)
                            self.addressField.setError(message)
                        }
                    }
                case .success(let info):
                    DispatchQueue.main.async { [weak self] in
                        guard let `self` = self else { return }

            // (4) and its mastercopy is supported
                        let implementation = info.implementation.value
                        guard App.shared.gnosisSafe.isSupported(info.version) else {
                            let error = GSError.error(description: "Can’t use this address",
                                                      error: GSError.UnsupportedImplementationCopy())
                            self.addressField.setError(error.localizedDescription)
                            return
                        }

                        self.safeVersion = info.version
                        self.nextButton.isEnabled = true
                    }
                }
            })
        } catch {
            addressField.setError(
                GSError.error(description: "Can’t use this address",
                              error: error is EthereumAddress.Error ? GSError.SafeAddressNotValid() : error))
        }
    }
}

extension EnterSafeAddressViewController: QRCodeScannerViewControllerDelegate {
    func scannerViewControllerDidCancel() {
        dismiss(animated: true, completion: nil)
    }

    func scannerViewControllerDidScan(_ code: String) {
        didEnterText(code)
        dismiss(animated: true, completion: nil)
    }
}
