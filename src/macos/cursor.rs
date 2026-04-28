use cocoa::appkit::NSCursor as _;
use cocoa::base::{id, nil};
use objc::{class, msg_send, sel, sel_impl};

use crate::MouseCursor;

/// Apply a cursor to the current view. Must be called on the main thread.
pub(super) unsafe fn set_cursor(cursor: MouseCursor) {
    if cursor == MouseCursor::Hidden {
        let _: () = msg_send![class!(NSCursor), hide];
        return;
    }
    let _: () = msg_send![class!(NSCursor), unhide];

    let ns_cursor: id = match cursor {
        MouseCursor::Default => id::arrow_cursor(nil),
        MouseCursor::Hand => id::pointing_hand_cursor(nil),
        MouseCursor::HandGrabbing => id::closed_hand_cursor(nil),
        MouseCursor::Help => id::contextual_menu_cursor(nil),
        MouseCursor::Hidden => return,

        MouseCursor::Text => id::i_beam_cursor(nil),
        MouseCursor::VerticalText => id::i_beam_cursor_for_vertical_layout(nil),

        // macOS has no built-in busy/working cursor — use the arrow.
        MouseCursor::Working => id::arrow_cursor(nil),
        MouseCursor::PtrWorking => id::arrow_cursor(nil),

        MouseCursor::NotAllowed => id::operation_not_allowed_cursor(nil),
        MouseCursor::PtrNotAllowed => id::operation_not_allowed_cursor(nil),

        MouseCursor::ZoomIn => id::arrow_cursor(nil),
        MouseCursor::ZoomOut => id::arrow_cursor(nil),

        MouseCursor::Alias => id::drag_link_cursor(nil),
        MouseCursor::Copy => id::drag_copy_cursor(nil),
        MouseCursor::Move => id::open_hand_cursor(nil),
        MouseCursor::AllScroll => id::open_hand_cursor(nil),
        MouseCursor::Cell => id::crosshair_cursor(nil),
        MouseCursor::Crosshair => id::crosshair_cursor(nil),

        MouseCursor::EResize => id::resize_right_cursor(nil),
        MouseCursor::WResize => id::resize_left_cursor(nil),
        MouseCursor::EwResize => id::resize_left_right_cursor(nil),
        MouseCursor::ColResize => id::resize_left_right_cursor(nil),

        MouseCursor::NResize => id::resize_up_cursor(nil),
        MouseCursor::SResize => id::resize_down_cursor(nil),
        MouseCursor::NsResize => id::resize_up_down_cursor(nil),
        MouseCursor::RowResize => id::resize_up_down_cursor(nil),

        MouseCursor::NeResize
        | MouseCursor::NwResize
        | MouseCursor::SeResize
        | MouseCursor::SwResize
        | MouseCursor::NwseResize
        | MouseCursor::NeswResize => id::arrow_cursor(nil),
    };

    if ns_cursor != nil {
        let _: () = msg_send![ns_cursor, set];
    }
}
