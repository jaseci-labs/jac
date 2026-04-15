# ruff: noqa: N801, N802, N803, N815
"""DOM type stubs for Jac JSX event handling and element access.

These types are ambient builtins — available in all Jac modules without import.
They model the browser DOM API surface commonly used in JSX event handlers,
following the React/SyntheticEvent conventions.

Names use camelCase to match the browser DOM API (e.g. addEventListener,
clientX, innerHTML) — this is intentional, not a Python naming violation.
"""

from collections.abc import Callable

# ---------------------------------------------------------------------------
# DOM Element types
# ---------------------------------------------------------------------------

class DOMTokenList:
    length: int
    value: str
    def add(self, *tokens: str) -> None: ...
    def remove(self, *tokens: str) -> None: ...
    def toggle(self, token: str, force: bool = ...) -> bool: ...
    def contains(self, token: str) -> bool: ...
    def item(self, index: int) -> str | None: ...

class CSSStyleDeclaration:
    cssText: str
    length: int
    # Common CSS properties (camelCase, as used in JS)
    display: str
    visibility: str
    opacity: str
    color: str
    backgroundColor: str
    width: str
    height: str
    margin: str
    padding: str
    border: str
    position: str
    top: str
    left: str
    right: str
    bottom: str
    zIndex: str
    overflow: str
    fontSize: str
    fontWeight: str
    textAlign: str
    def getPropertyValue(self, property: str) -> str: ...
    def setProperty(self, property: str, value: str, priority: str = ...) -> None: ...
    def removeProperty(self, property: str) -> str: ...

class EventTarget:
    """Base interface for all DOM event targets."""
    def addEventListener(
        self, type: str, listener: object, options: object = ...
    ) -> None: ...
    def removeEventListener(
        self, type: str, listener: object, options: object = ...
    ) -> None: ...
    def dispatchEvent(self, event: Event) -> bool: ...

class HTMLElement(EventTarget):
    """Base interface for all HTML elements."""

    id: str
    className: str
    tagName: str
    innerHTML: str
    outerHTML: str
    innerText: str
    textContent: str | None
    hidden: bool
    title: str
    tabIndex: int
    draggable: bool
    contentEditable: str
    dataset: dict[str, str]
    style: CSSStyleDeclaration
    classList: DOMTokenList
    parentElement: HTMLElement | None
    children: object  # HTMLCollection
    offsetWidth: float
    offsetHeight: float
    offsetTop: float
    offsetLeft: float
    scrollTop: float
    scrollLeft: float
    scrollWidth: float
    scrollHeight: float
    clientWidth: float
    clientHeight: float
    def click(self) -> None: ...
    def focus(self, options: object = ...) -> None: ...
    def blur(self) -> None: ...
    def getAttribute(self, name: str) -> str | None: ...
    def setAttribute(self, name: str, value: str) -> None: ...
    def removeAttribute(self, name: str) -> None: ...
    def hasAttribute(self, name: str) -> bool: ...
    def closest(self, selectors: str) -> HTMLElement | None: ...
    def querySelector(self, selectors: str) -> HTMLElement | None: ...
    def querySelectorAll(self, selectors: str) -> object: ...
    def getBoundingClientRect(self) -> DOMRect: ...
    def scrollIntoView(self, options: object = ...) -> None: ...

class HTMLInputElement(HTMLElement):
    """Interface for <input> elements."""

    value: str
    checked: bool
    disabled: bool
    readOnly: bool
    required: bool
    placeholder: str
    type: str
    name: str
    min: str
    max: str
    step: str
    pattern: str
    multiple: bool
    accept: str
    maxLength: int
    minLength: int
    selectionStart: int | None
    selectionEnd: int | None
    files: object  # FileList
    form: HTMLFormElement | None
    validity: object  # ValidityState
    def select(self) -> None: ...
    def setSelectionRange(self, start: int, end: int, direction: str = ...) -> None: ...
    def setCustomValidity(self, message: str) -> None: ...
    def checkValidity(self) -> bool: ...
    def reportValidity(self) -> bool: ...

class HTMLTextAreaElement(HTMLElement):
    """Interface for <textarea> elements."""

    value: str
    disabled: bool
    readOnly: bool
    required: bool
    placeholder: str
    name: str
    rows: int
    cols: int
    maxLength: int
    minLength: int
    selectionStart: int | None
    selectionEnd: int | None
    form: HTMLFormElement | None
    def select(self) -> None: ...
    def setSelectionRange(self, start: int, end: int, direction: str = ...) -> None: ...
    def setCustomValidity(self, message: str) -> None: ...
    def checkValidity(self) -> bool: ...

class HTMLSelectElement(HTMLElement):
    """Interface for <select> elements."""

    value: str
    selectedIndex: int
    disabled: bool
    required: bool
    multiple: bool
    name: str
    length: int
    form: HTMLFormElement | None
    options: object  # HTMLOptionsCollection
    def setCustomValidity(self, message: str) -> None: ...
    def checkValidity(self) -> bool: ...

class HTMLFormElement(HTMLElement):
    """Interface for <form> elements."""

    action: str
    method: str
    encoding: str
    enctype: str
    name: str
    target: str
    elements: object  # HTMLFormControlsCollection
    length: int
    def submit(self) -> None: ...
    def reset(self) -> None: ...
    def checkValidity(self) -> bool: ...
    def reportValidity(self) -> bool: ...

class HTMLButtonElement(HTMLElement):
    """Interface for <button> elements."""

    value: str
    disabled: bool
    name: str
    type: str
    form: HTMLFormElement | None

class HTMLAnchorElement(HTMLElement):
    """Interface for <a> elements."""

    href: str
    target: str
    rel: str
    download: str
    pathname: str
    hostname: str
    protocol: str
    hash: str
    search: str
    origin: str

class HTMLImageElement(HTMLElement):
    """Interface for <img> elements."""

    src: str
    alt: str
    width: int
    height: int
    naturalWidth: int
    naturalHeight: int
    complete: bool
    loading: str
    crossOrigin: str | None

class HTMLCanvasElement(HTMLElement):
    """Interface for <canvas> elements."""

    width: int
    height: int
    def getContext(self, contextId: str, options: object = ...) -> object: ...
    def toDataURL(self, type: str = ..., quality: object = ...) -> str: ...
    def toBlob(
        self, callback: object, type: str = ..., quality: object = ...
    ) -> None: ...

class HTMLVideoElement(HTMLElement):
    """Interface for <video> elements."""

    src: str
    currentTime: float
    duration: float
    paused: bool
    ended: bool
    volume: float
    muted: bool
    playbackRate: float
    width: int
    height: int
    videoWidth: int
    videoHeight: int
    poster: str
    autoplay: bool
    loop: bool
    controls: bool
    def play(self) -> object: ...
    def pause(self) -> None: ...
    def load(self) -> None: ...

class HTMLAudioElement(HTMLElement):
    """Interface for <audio> elements."""

    src: str
    currentTime: float
    duration: float
    paused: bool
    ended: bool
    volume: float
    muted: bool
    playbackRate: float
    autoplay: bool
    loop: bool
    controls: bool
    def play(self) -> object: ...
    def pause(self) -> None: ...
    def load(self) -> None: ...

# ---------------------------------------------------------------------------
# Geometry types
# ---------------------------------------------------------------------------

class DOMRect:
    x: float
    y: float
    width: float
    height: float
    top: float
    right: float
    bottom: float
    left: float

# ---------------------------------------------------------------------------
# Data transfer (drag & drop, clipboard)
# ---------------------------------------------------------------------------

class DataTransferItem:
    kind: str
    type: str
    def getAsString(self, callback: object) -> None: ...
    def getAsFile(self) -> object: ...

class DataTransferItemList:
    length: int
    def add(self, data: object, type: str = ...) -> DataTransferItem | None: ...
    def remove(self, index: int) -> None: ...
    def clear(self) -> None: ...

class DataTransfer:
    dropEffect: str
    effectAllowed: str
    items: DataTransferItemList
    types: list[str]
    files: object  # FileList
    def setData(self, format: str, data: str) -> None: ...
    def getData(self, format: str) -> str: ...
    def clearData(self, format: str = ...) -> None: ...
    def setDragImage(self, image: object, x: int, y: int) -> None: ...

# ---------------------------------------------------------------------------
# Touch support
# ---------------------------------------------------------------------------

class Touch:
    identifier: int
    target: EventTarget
    clientX: float
    clientY: float
    screenX: float
    screenY: float
    pageX: float
    pageY: float
    radiusX: float
    radiusY: float
    rotationAngle: float
    force: float

class TouchList:
    length: int
    def item(self, index: int) -> Touch | None: ...

# ---------------------------------------------------------------------------
# Event types
# ---------------------------------------------------------------------------

class Event:
    """Base DOM event interface."""

    type: str
    target: HTMLElement
    currentTarget: HTMLElement
    bubbles: bool
    cancelable: bool
    defaultPrevented: bool
    eventPhase: int
    isTrusted: bool
    timeStamp: float
    def preventDefault(self) -> None: ...
    def stopPropagation(self) -> None: ...
    def stopImmediatePropagation(self) -> None: ...

class InputEvent(Event):
    """Fired on <input>, <textarea>, <select> when value changes (onInput)."""

    target: HTMLInputElement
    data: str | None
    inputType: str
    isComposing: bool

class ChangeEvent(Event):
    """Fired when an element's value is committed (onChange)."""

    target: HTMLInputElement

class FocusEvent(Event):
    """Fired on focus/blur events (onFocus, onBlur)."""

    relatedTarget: HTMLElement | None

class KeyboardEvent(Event):
    """Fired on keyboard interaction (onKeyDown, onKeyUp, onKeyPress)."""

    key: str
    code: str
    location: int
    repeat: bool
    ctrlKey: bool
    shiftKey: bool
    altKey: bool
    metaKey: bool
    isComposing: bool
    def getModifierState(self, key: str) -> bool: ...

class MouseEvent(Event):
    """Fired on mouse interaction (onClick, onMouseDown, onMouseUp, etc.)."""

    button: int
    buttons: int
    clientX: float
    clientY: float
    screenX: float
    screenY: float
    pageX: float
    pageY: float
    offsetX: float
    offsetY: float
    movementX: float
    movementY: float
    ctrlKey: bool
    shiftKey: bool
    altKey: bool
    metaKey: bool
    relatedTarget: HTMLElement | None
    def getModifierState(self, key: str) -> bool: ...

class PointerEvent(MouseEvent):
    """Fired on pointer interaction (onPointerDown, onPointerUp, etc.)."""

    pointerId: int
    width: float
    height: float
    pressure: float
    tangentialPressure: float
    tiltX: int
    tiltY: int
    twist: int
    pointerType: str
    isPrimary: bool

class WheelEvent(MouseEvent):
    """Fired on wheel/scroll (onWheel)."""

    deltaX: float
    deltaY: float
    deltaZ: float
    deltaMode: int

class DragEvent(MouseEvent):
    """Fired on drag operations (onDrag, onDragStart, onDrop, etc.)."""

    dataTransfer: DataTransfer | None

class TouchEvent(Event):
    """Fired on touch interaction (onTouchStart, onTouchEnd, etc.)."""

    touches: TouchList
    targetTouches: TouchList
    changedTouches: TouchList
    ctrlKey: bool
    shiftKey: bool
    altKey: bool
    metaKey: bool

class ClipboardEvent(Event):
    """Fired on clipboard operations (onCopy, onCut, onPaste)."""

    clipboardData: DataTransfer | None

class CompositionEvent(Event):
    """Fired during IME composition (onCompositionStart, etc.)."""

    data: str

class FormEvent(Event):
    """Fired on form submission (onSubmit, onReset)."""

    target: HTMLFormElement

class AnimationEvent(Event):
    """Fired on CSS animation events (onAnimationStart, onAnimationEnd, etc.)."""

    animationName: str
    elapsedTime: float
    pseudoElement: str

class TransitionEvent(Event):
    """Fired on CSS transition events (onTransitionEnd, etc.)."""

    propertyName: str
    elapsedTime: float
    pseudoElement: str

class UIEvent(Event):
    """Base for UI events (onScroll, onResize)."""

    detail: int
    # view: Window  # omitted to avoid circular complexity

class ScrollEvent(UIEvent):
    """Fired on scroll (onScroll)."""

    ...

class ResizeEvent(UIEvent):
    """Fired on element resize."""

    ...

# ---------------------------------------------------------------------------
# Event handler type aliases
# ---------------------------------------------------------------------------

MouseEventHandler = Callable[[MouseEvent], None]
KeyboardEventHandler = Callable[[KeyboardEvent], None]
InputEventHandler = Callable[[InputEvent], None]
ChangeEventHandler = Callable[[ChangeEvent], None]
FocusEventHandler = Callable[[FocusEvent], None]
FormEventHandler = Callable[[FormEvent], None]
DragEventHandler = Callable[[DragEvent], None]
TouchEventHandler = Callable[[TouchEvent], None]
WheelEventHandler = Callable[[WheelEvent], None]
PointerEventHandler = Callable[[PointerEvent], None]
ClipboardEventHandler = Callable[[ClipboardEvent], None]
AnimationEventHandler = Callable[[AnimationEvent], None]
TransitionEventHandler = Callable[[TransitionEvent], None]
ScrollEventHandler = Callable[[ScrollEvent], None]
EventHandler = Callable[[Event], None]

# ---------------------------------------------------------------------------
# Intrinsic HTML element prop types
# ---------------------------------------------------------------------------

class _HtmlCommonProps:
    """Common props shared by all intrinsic HTML elements."""

    id: str
    className: str
    style: dict[str, object]
    title: str
    hidden: bool
    tabIndex: int
    draggable: bool
    role: str
    # Event handlers
    onClick: MouseEventHandler
    onDoubleClick: MouseEventHandler
    onMouseDown: MouseEventHandler
    onMouseUp: MouseEventHandler
    onMouseEnter: MouseEventHandler
    onMouseLeave: MouseEventHandler
    onMouseOver: MouseEventHandler
    onMouseOut: MouseEventHandler
    onKeyDown: KeyboardEventHandler
    onKeyUp: KeyboardEventHandler
    onKeyPress: KeyboardEventHandler
    onFocus: FocusEventHandler
    onBlur: FocusEventHandler
    onInput: InputEventHandler
    onChange: ChangeEventHandler
    onSubmit: FormEventHandler
    onReset: FormEventHandler
    onDragStart: DragEventHandler
    onDrag: DragEventHandler
    onDragEnd: DragEventHandler
    onDragEnter: DragEventHandler
    onDragLeave: DragEventHandler
    onDragOver: DragEventHandler
    onDrop: DragEventHandler
    onTouchStart: TouchEventHandler
    onTouchMove: TouchEventHandler
    onTouchEnd: TouchEventHandler
    onTouchCancel: TouchEventHandler
    onWheel: WheelEventHandler
    onPointerDown: PointerEventHandler
    onPointerUp: PointerEventHandler
    onPointerMove: PointerEventHandler
    onPointerEnter: PointerEventHandler
    onPointerLeave: PointerEventHandler
    onScroll: ScrollEventHandler
    onCopy: ClipboardEventHandler
    onCut: ClipboardEventHandler
    onPaste: ClipboardEventHandler

class _ButtonIntrinsicProps(_HtmlCommonProps):
    """Props for <button> elements."""

    type: str
    disabled: bool
    name: str
    value: str

class _InputIntrinsicProps(_HtmlCommonProps):
    """Props for <input> elements."""

    type: str
    value: str
    checked: bool
    disabled: bool
    readOnly: bool
    required: bool
    placeholder: str
    name: str
    min: str
    max: str
    step: str
    pattern: str
    multiple: bool
    accept: str
    maxLength: int
    minLength: int

class _FormIntrinsicProps(_HtmlCommonProps):
    """Props for <form> elements."""

    action: str
    method: str
    enctype: str
    target: str
    name: str

class _AnchorIntrinsicProps(_HtmlCommonProps):
    """Props for <a> elements."""

    href: str
    target: str
    rel: str
    download: str

class _ImgIntrinsicProps(_HtmlCommonProps):
    """Props for <img> elements."""

    src: str
    alt: str
    width: int
    height: int
    loading: str
    crossOrigin: str | None

class _TextAreaIntrinsicProps(_HtmlCommonProps):
    """Props for <textarea> elements."""

    value: str
    disabled: bool
    readOnly: bool
    required: bool
    placeholder: str
    name: str
    rows: int
    cols: int
    maxLength: int
    minLength: int

class _SelectIntrinsicProps(_HtmlCommonProps):
    """Props for <select> elements."""

    value: str
    disabled: bool
    required: bool
    multiple: bool
    name: str
