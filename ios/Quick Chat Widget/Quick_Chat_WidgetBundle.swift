//
//  Quick_Chat_WidgetBundle.swift
//  Quick Chat Widget
//
//  Created by Nguyễn Đại on 18/3/26.
//

import WidgetKit
import SwiftUI

@main
struct Quick_Chat_WidgetBundle: WidgetBundle {
    var body: some Widget {
        Quick_Chat_Widget()
        Quick_Chat_WidgetControl()
        Quick_Chat_WidgetLiveActivity()
    }
}
