# UI window transitions

Game windows now use the `WindowTransitions` autoload for presentation. Opening
uses a gentle scale, lift and fade over 280 ms; closing uses a smaller scale and
fade over 180 ms. Hermite interpolation preserves position and velocity when a
player reverses a transition. Repeated show calls do not restart it.

Logical hiding, focus cleanup, transaction callbacks and cancellation happen
immediately. Only the hidden canvas branch remains visible during its exit.
Layout transforms, fitted mobile scales and hit rectangles stay unchanged.
Moving windows reject early pointer presses; timed fishing controls retain their
normal input timing. Scene/ancestor hiding cancels exits without leaving ghosts.

Unrelated top-level windows close through their controller's cleanup method or
close signal. Nested confirmations and shop details remain part of their parent
flow. Trade, vending and storage inventory selection can keep its parent open;
opening an unrelated window closes that entire flow. Noninteractive waiting-room
status is not treated as an exclusive modal.

Legacy window tweens were removed from the style helper, menu, shop, item details
and fishing panels. Drawer easing for inventory and chat is independent of frame
rate, and toggles use the requested state so a quick reopen can reverse closing.
The menu fits its authored scale to short phone screens without clipping actions.
The recipe book applies its final mobile fit before revealing content. Tax and
quest-abandon confirmations use the same animated in-game confirmation card as
vending, with immediate hiding and a guard against duplicate confirmation.

Temporary dialogs release their authored name and the caller's references on
close, then free after the exit. Dismissal revisions prevent an old timer from
freeing a reopened window or shortening a later exit.

New windows with a standard `Window`/`Panel` containing `CloseButton` or
`CloseTarget` inherit the policy. Custom windows can use `ui_window`,
`popup_window_path`, or `register_window(controller, panel)`. Registration is
batched when item rows are created. Existing scene/script adapters cover legacy
layouts. The shared helper never changes the fitted scale.

## Validation

- `window_transitions_test`: lifecycle, reversals, duplicate instances, modal
  switches, nested details, trade selection cleanup, duplicate confirmation,
  delayed freeing and future window registration.
- `window_transitions_render_test`: both Compatibility and Mobile renderers;
  first-frame flashes, continuous exits, reversal, ghost cleanup, scene hiding,
  and desktop/phone shop, settings, vending and menu captures.
- Inventory action, mobile inventory/shop layout, recipe fitting, shop pack info,
  quest, tax, vending and trade review regressions.

`menu_scene_test` has a pre-existing style assertion expecting `StyleBoxFlat`
despite the atlas style migration. It also fails in the clean previously
committed client; the animation changes do not alter that styling behavior.
