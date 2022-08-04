//
//  ReviewClaimSafeTokenTransactionViewController.swift
//  Multisig
//
//  Created by Mouaz on 8/3/22.
//  Copyright © 2022 Gnosis Ltd. All rights reserved.
//

import UIKit
import SwiftCryptoTokenFormatter

class ReviewClaimSafeTokenTransactionViewController: ReviewSafeTransactionViewController {
    var onSubmit: ((_ nonce: UInt256String, _ safeTxHash: HashString) -> Void)?

    private var transaction: Transaction!
    private var guardian: Guardian!
    private var amount: BigDecimal!
    convenience init(transaction: Transaction,
                     safe: Safe, guardian: Guardian, amount: BigDecimal) {
        self.init(safe: safe)
        self.amount = amount
        self.guardian = guardian
        shouldLoadTransactionPreview = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Review transaction"
        confirmButtonView.set(rejectionEnabled: false)

        tableView.registerCell(IcommingDappInteractionRequestHeaderTableViewCell.self)
        tableView.registerCell(DetailTransferInfoCell.self)
    }

    override func createSections() {
        sectionItems = [SectionItem.header(headerCell()),
                        SectionItem.data(dataCell())]
        if let _ = transactionPreview?.txData?.dataDecoded {
            sectionItems.append(SectionItem.transactionType(transactionType()))
        }
        sectionItems.append(SectionItem.advanced(parametersCell()))

    }

    override func headerCell() -> UITableViewCell {
        let cell = tableView.dequeueCell(IcommingDappInteractionRequestHeaderTableViewCell.self)
        let chain = safe.chain!

        cell.setDappInfo(hidden: true)
        let (addressName, imageURL) = NamingPolicy.name(for: transaction.to.address,
                                                 info: nil,
                                                 chainId: safe.chain!.id!)
        cell.setToAddress(transaction.to.address,
                          label: addressName,
                          imageUri: imageURL,
                          prefix: chain.shortName,
                          title: "To:")

        cell.setFromAddress(safe.addressValue,
                            label: safe.name,
                            prefix: chain.shortName,
                            title: "From:")
        return cell
    }

    func transactionType() -> UITableViewCell {
        guard let dataDecoded = transactionPreview?.txData?.dataDecoded else { return UITableViewCell() }

        let tableCell = tableView.dequeueCell(BorderedInnerTableCell.self)

        tableCell.selectionStyle = .none
        tableCell.verticalSpacing = 16

        tableCell.tableView.registerCell(IncommingTransactionRequestTypeTableViewCell.self)

        let cell = tableCell.tableView.dequeueCell(IncommingTransactionRequestTypeTableViewCell.self)

        let addressInfoIndex = transactionPreview?.txData?.addressInfoIndex
        var description: String?
        if dataDecoded.method == "multiSend",
           let param = dataDecoded.parameters?.first,
           param.type == "bytes",
           case let SCGModels.DataDecoded.Parameter.ValueDecoded.multiSend(multiSendTxs)? = param.valueDecoded {
            description = "Multisend (\(multiSendTxs.count) actions)"
            tableCell.onCellTap = { [unowned self] _ in
                let root = MultiSendListTableViewController(transactions: multiSendTxs,
                                                            addressInfoIndex: addressInfoIndex,
                                                            chain: safe.chain!)
                let vc = RibbonViewController(rootViewController: root)
                show(vc, sender: self)
            }
        } else {
            description = "Action (\(dataDecoded.method))"
            tableCell.onCellTap = { [unowned self] _ in
                let root = ActionDetailViewController(decoded: dataDecoded,
                                                      addressInfoIndex: addressInfoIndex,
                                                      chain: safe.chain!,
                                                      data: transactionPreview?.txData?.hexData)
                let vc = RibbonViewController(rootViewController: root)
                show(vc, sender: self)
            }
        }

        cell.set(imageName: "", name: "Contract interaction", description: description)
        tableCell.setCells([cell])

        return tableCell
    }

    // TODO: Create transaction
//    override func createTransaction() -> Transaction? {
//        transaction
//    }

    // TODO: Fill the tracking event
//    override func getTrackingEvent() -> TrackingEvent {
//
//
//    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = sectionItems[indexPath.row]
        switch item {
        case SectionItem.transactionType(let cell): return cell
        default: return super.tableView(tableView, cellForRowAt: indexPath)
        }
    }
}
