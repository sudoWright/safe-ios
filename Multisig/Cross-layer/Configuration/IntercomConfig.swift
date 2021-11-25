//
// Created by Dirk Jäckel on 23.11.21.
// Copyright (c) 2021 Gnosis Ltd. All rights reserved.
//

import Foundation
import Intercom

class IntercomConfig {

    func setUp() {
        Intercom.setApiKey(App.configuration.services.intercomApiKey, forAppId: App.configuration.services.intercomAppId)
        Intercom.setLauncherVisible(true)
        Intercom.setBottomPadding(30)

        #if DEBUG
        Intercom.enableLogging()
        #endif
        Intercom.registerUnidentifiedUser()
    }

    func disable() {
        Intercom.setLauncherVisible(false)
    }

    func enable() {
        Intercom.setLauncherVisible(true)
    }

}