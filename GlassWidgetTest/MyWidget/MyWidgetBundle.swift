import WidgetKit
import SwiftUI

@main
struct MyWidgetBundle: WidgetBundle {
    var body: some Widget {
        MyNormalWidget()
        MyClearWidget()
        MyBlurWidget()
        MyBlueWidget()
    }
}
