codex conversation [20260730-ipad] fix iPad menu command builder

Group the iPad menu commands into two Commands containers so SwiftUI's result
builder does not exceed its ten-child overload. The menu entries and actions
are unchanged.
