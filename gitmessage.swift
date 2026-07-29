codex conversation [20260729-ipad] invoke the iPad menu delegate correctly

Replace the unused application(_:buildMenuWith:) method with UIKit's actual
buildMenu(with:) delegate callback, so the custom iPad menu is built at all.
