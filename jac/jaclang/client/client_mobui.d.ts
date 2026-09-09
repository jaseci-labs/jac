// The typed surface of `@jac/mobui`. The shim beside this file re-exports
// react-native, whose declarations a react-native-web project never installs,
// so the checker reads this sibling instead. Every export of client_mobui.jac
// and client_mobui.shims.js must be declared here (a test enforces it).

export type StyleProp = any;
export type Handler = any;
export type ReactNode = any;

export interface ScaledSize {
    width: number;
    height: number;
    scale: number;
    fontScale: number;
}

export interface LayoutRectangle {
    x: number;
    y: number;
    width: number;
    height: number;
}

export interface Insets {
    top?: number;
    left?: number;
    bottom?: number;
    right?: number;
}

export interface AccessibilityProps {
    accessible?: boolean;
    accessibilityLabel?: string;
    accessibilityLabelledBy?: any;
    accessibilityHint?: string;
    accessibilityRole?: string;
    accessibilityState?: any;
    accessibilityValue?: any;
    accessibilityActions?: any;
    accessibilityElementsHidden?: boolean;
    accessibilityLanguage?: string;
    accessibilityLiveRegion?: string;
    accessibilityViewIsModal?: boolean;
    accessibilityIgnoresInvertColors?: boolean;
    importantForAccessibility?: string;
    onAccessibilityAction?: Handler;
    onAccessibilityEscape?: Handler;
    onAccessibilityTap?: Handler;
    onMagicTap?: Handler;
    role?: string;
    "aria-label"?: string;
    "aria-hidden"?: boolean;
    "aria-live"?: string;
    "aria-modal"?: boolean;
    "aria-busy"?: boolean;
    "aria-checked"?: any;
    "aria-disabled"?: boolean;
    "aria-expanded"?: boolean;
    "aria-selected"?: boolean;
    "aria-valuemax"?: number;
    "aria-valuemin"?: number;
    "aria-valuenow"?: number;
    "aria-valuetext"?: string;
    "aria-labelledby"?: string;
}

export interface ResponderProps {
    onStartShouldSetResponder?: Handler;
    onStartShouldSetResponderCapture?: Handler;
    onMoveShouldSetResponder?: Handler;
    onMoveShouldSetResponderCapture?: Handler;
    onResponderGrant?: Handler;
    onResponderReject?: Handler;
    onResponderMove?: Handler;
    onResponderRelease?: Handler;
    onResponderStart?: Handler;
    onResponderEnd?: Handler;
    onResponderTerminate?: Handler;
    onResponderTerminationRequest?: Handler;
    onTouchStart?: Handler;
    onTouchMove?: Handler;
    onTouchEnd?: Handler;
    onTouchCancel?: Handler;
    onTouchEndCapture?: Handler;
}

export interface ViewProps extends AccessibilityProps, ResponderProps {
    style?: StyleProp;
    children?: ReactNode;
    id?: string;
    nativeID?: string;
    testID?: string;
    pointerEvents?: string;
    hitSlop?: any;
    collapsable?: boolean;
    focusable?: boolean;
    tabIndex?: number;
    needsOffscreenAlphaCompositing?: boolean;
    removeClippedSubviews?: boolean;
    renderToHardwareTextureAndroid?: boolean;
    shouldRasterizeIOS?: boolean;
    onLayout?: Handler;
    onPointerEnter?: Handler;
    onPointerLeave?: Handler;
    onPointerMove?: Handler;
    onPointerDown?: Handler;
    onPointerUp?: Handler;
    onFocus?: Handler;
    onBlur?: Handler;
    onClick?: Handler;
    onKeyDown?: Handler;
    onKeyUp?: Handler;
    onMouseEnter?: Handler;
    onMouseLeave?: Handler;
    onScroll?: Handler;
    dataSet?: any;
    href?: string;
    hrefAttrs?: any;
    lang?: string;
    dir?: string;
}

export interface TextProps extends ViewProps {
    numberOfLines?: number;
    ellipsizeMode?: string;
    lineBreakMode?: string;
    lineBreakStrategyIOS?: string;
    android_hyphenationFrequency?: string;
    textBreakStrategy?: string;
    selectable?: boolean;
    selectionColor?: string;
    suppressHighlighting?: boolean;
    allowFontScaling?: boolean;
    adjustsFontSizeToFit?: boolean;
    minimumFontScale?: number;
    maxFontSizeMultiplier?: number;
    dynamicTypeRamp?: string;
    dataDetectorType?: string;
    disabled?: boolean;
    onPress?: Handler;
    onPressIn?: Handler;
    onPressOut?: Handler;
    onLongPress?: Handler;
    onTextLayout?: Handler;
    pressRetentionOffset?: any;
}

export interface PressableProps extends ViewProps {
    onPress?: Handler;
    onPressIn?: Handler;
    onPressOut?: Handler;
    onLongPress?: Handler;
    onHoverIn?: Handler;
    onHoverOut?: Handler;
    disabled?: boolean;
    cancelable?: boolean;
    delayLongPress?: number;
    delayHoverIn?: number;
    delayHoverOut?: number;
    unstable_pressDelay?: number;
    pressRetentionOffset?: any;
    android_disableSound?: boolean;
    android_ripple?: any;
    testOnly_pressed?: boolean;
}

export interface TextInputProps extends ViewProps {
    value?: string;
    defaultValue?: string;
    placeholder?: string;
    placeholderTextColor?: string;
    editable?: boolean;
    readOnly?: boolean;
    multiline?: boolean;
    numberOfLines?: number;
    maxLength?: number;
    secureTextEntry?: boolean;
    autoCapitalize?: string;
    autoComplete?: string;
    autoCorrect?: boolean;
    autoFocus?: boolean;
    spellCheck?: boolean;
    keyboardType?: string;
    keyboardAppearance?: string;
    inputMode?: string;
    enterKeyHint?: string;
    returnKeyType?: string;
    returnKeyLabel?: string;
    blurOnSubmit?: boolean;
    submitBehavior?: string;
    clearButtonMode?: string;
    clearTextOnFocus?: boolean;
    selectTextOnFocus?: boolean;
    selection?: any;
    selectionColor?: string;
    selectionHandleColor?: string;
    cursorColor?: string;
    caretHidden?: boolean;
    contextMenuHidden?: boolean;
    textAlign?: string;
    textAlignVertical?: string;
    textContentType?: string;
    passwordRules?: string;
    importantForAutofill?: string;
    inlineImageLeft?: string;
    inlineImagePadding?: number;
    underlineColorAndroid?: string;
    disableFullscreenUI?: boolean;
    enablesReturnKeyAutomatically?: boolean;
    showSoftInputOnFocus?: boolean;
    scrollEnabled?: boolean;
    rejectResponderTermination?: boolean;
    inputAccessoryViewID?: string;
    dataDetectorTypes?: any;
    allowFontScaling?: boolean;
    maxFontSizeMultiplier?: number;
    lineBreakStrategyIOS?: string;
    smartInsertDelete?: boolean;
    rows?: number;
    onChange?: Handler;
    onChangeText?: Handler;
    onContentSizeChange?: Handler;
    onEndEditing?: Handler;
    onSubmitEditing?: Handler;
    onKeyPress?: Handler;
    onSelectionChange?: Handler;
    onTextInput?: Handler;
    onPressIn?: Handler;
    onPressOut?: Handler;
}

export interface ImageProps extends AccessibilityProps {
    source?: any;
    src?: string;
    srcSet?: string;
    defaultSource?: any;
    loadingIndicatorSource?: any;
    style?: StyleProp;
    resizeMode?: string;
    resizeMethod?: string;
    objectFit?: string;
    alt?: string;
    blurRadius?: number;
    borderRadius?: number;
    borderTopLeftRadius?: number;
    borderTopRightRadius?: number;
    borderBottomLeftRadius?: number;
    borderBottomRightRadius?: number;
    fadeDuration?: number;
    progressiveRenderingEnabled?: boolean;
    tintColor?: string;
    width?: number;
    height?: number;
    capInsets?: any;
    crossOrigin?: string;
    referrerPolicy?: string;
    draggable?: boolean;
    testID?: string;
    nativeID?: string;
    id?: string;
    onLayout?: Handler;
    onLoad?: Handler;
    onLoadStart?: Handler;
    onLoadEnd?: Handler;
    onError?: Handler;
    onProgress?: Handler;
    onPartialLoad?: Handler;
    pointerEvents?: string;
    dataSet?: any;
}

export interface ScrollViewProps extends ViewProps {
    contentContainerStyle?: StyleProp;
    horizontal?: boolean;
    showsVerticalScrollIndicator?: boolean;
    showsHorizontalScrollIndicator?: boolean;
    indicatorStyle?: string;
    scrollIndicatorInsets?: Insets;
    persistentScrollbar?: boolean;
    refreshControl?: ReactNode;
    scrollEnabled?: boolean;
    scrollEventThrottle?: number;
    bounces?: boolean;
    bouncesZoom?: boolean;
    alwaysBounceVertical?: boolean;
    alwaysBounceHorizontal?: boolean;
    overScrollMode?: string;
    pagingEnabled?: boolean;
    snapToInterval?: number;
    snapToAlignment?: string;
    snapToOffsets?: number[];
    snapToStart?: boolean;
    snapToEnd?: boolean;
    decelerationRate?: any;
    disableIntervalMomentum?: boolean;
    disableScrollViewPanResponder?: boolean;
    directionalLockEnabled?: boolean;
    nestedScrollEnabled?: boolean;
    keyboardShouldPersistTaps?: string;
    keyboardDismissMode?: string;
    automaticallyAdjustKeyboardInsets?: boolean;
    automaticallyAdjustContentInsets?: boolean;
    automaticallyAdjustsScrollIndicatorInsets?: boolean;
    contentInset?: Insets;
    contentOffset?: any;
    contentInsetAdjustmentBehavior?: string;
    stickyHeaderIndices?: number[];
    stickyHeaderHiddenOnScroll?: boolean;
    invertStickyHeaders?: boolean;
    StickyHeaderComponent?: any;
    maintainVisibleContentPosition?: any;
    scrollToOverflowEnabled?: boolean;
    scrollsToTop?: boolean;
    scrollPerfTag?: string;
    centerContent?: boolean;
    canCancelContentTouches?: boolean;
    endFillColor?: string;
    fadingEdgeLength?: number;
    zoomScale?: number;
    maximumZoomScale?: number;
    minimumZoomScale?: number;
    pinchGestureEnabled?: boolean;
    onScroll?: Handler;
    onScrollBeginDrag?: Handler;
    onScrollEndDrag?: Handler;
    onMomentumScrollBegin?: Handler;
    onMomentumScrollEnd?: Handler;
    onContentSizeChange?: Handler;
    onScrollToTop?: Handler;
    onWheel?: Handler;
}

export interface ListProps extends ScrollViewProps {
    renderItem?: any;
    keyExtractor?: any;
    extraData?: any;
    ItemSeparatorComponent?: any;
    ListHeaderComponent?: any;
    ListHeaderComponentStyle?: StyleProp;
    ListFooterComponent?: any;
    ListFooterComponentStyle?: StyleProp;
    ListEmptyComponent?: any;
    CellRendererComponent?: any;
    renderScrollComponent?: any;
    initialNumToRender?: number;
    initialScrollIndex?: number;
    inverted?: boolean;
    maxToRenderPerBatch?: number;
    updateCellsBatchingPeriod?: number;
    windowSize?: number;
    disableVirtualization?: boolean;
    legacyImplementation?: boolean;
    debug?: boolean;
    listKey?: string;
    progressViewOffset?: number;
    refreshing?: boolean;
    onRefresh?: Handler;
    onEndReached?: Handler;
    onEndReachedThreshold?: number;
    onStartReached?: Handler;
    onStartReachedThreshold?: number;
    onViewableItemsChanged?: Handler;
    onScrollToIndexFailed?: Handler;
    viewabilityConfig?: any;
    viewabilityConfigCallbackPairs?: any;
    getItemLayout?: any;
    getItem?: any;
    getItemCount?: any;
}

export interface FlatListProps extends ListProps {
    data?: any;
    numColumns?: number;
    columnWrapperStyle?: StyleProp;
}

export interface SectionListProps extends ListProps {
    sections?: any;
    renderSectionHeader?: any;
    renderSectionFooter?: any;
    SectionSeparatorComponent?: any;
    stickySectionHeadersEnabled?: boolean;
}

export interface RefreshControlProps extends ViewProps {
    refreshing: boolean;
    onRefresh?: Handler;
    enabled?: boolean;
    colors?: string[];
    tintColor?: string;
    title?: string;
    titleColor?: string;
    progressBackgroundColor?: string;
    progressViewOffset?: number;
    size?: any;
}

export interface ModalProps extends ViewProps {
    visible?: boolean;
    transparent?: boolean;
    animationType?: string;
    animated?: boolean;
    presentationStyle?: string;
    supportedOrientations?: any;
    hardwareAccelerated?: boolean;
    statusBarTranslucent?: boolean;
    navigationBarTranslucent?: boolean;
    backdropColor?: string;
    onRequestClose?: Handler;
    onShow?: Handler;
    onDismiss?: Handler;
    onOrientationChange?: Handler;
}

export interface SwitchProps extends ViewProps {
    value?: boolean;
    disabled?: boolean;
    onValueChange?: Handler;
    onChange?: Handler;
    trackColor?: any;
    thumbColor?: string;
    ios_backgroundColor?: string;
    activeThumbColor?: string;
    activeTrackColor?: string;
}

export interface ActivityIndicatorProps extends ViewProps {
    animating?: boolean;
    color?: string;
    size?: any;
    hidesWhenStopped?: boolean;
}

export interface KeyboardAvoidingViewProps extends ViewProps {
    behavior?: string;
    contentContainerStyle?: StyleProp;
    keyboardVerticalOffset?: number;
    enabled?: boolean;
}

export interface StatusBarProps {
    barStyle?: string;
    backgroundColor?: string;
    hidden?: boolean;
    animated?: boolean;
    translucent?: boolean;
    networkActivityIndicatorVisible?: boolean;
    showHideTransition?: string;
}

export interface StyleSheetStatic {
    create(styles: any): any;
    flatten(style: any): any;
    compose(style1: any, style2: any): any;
    absoluteFill: any;
    absoluteFillObject: any;
    hairlineWidth: number;
}

export interface PlatformStatic {
    OS: string;
    Version: any;
    constants: any;
    isTV: boolean;
    isPad: boolean;
    isTesting: boolean;
    select(spec: any): any;
}

export interface KeyboardStatic {
    dismiss(): void;
    isVisible(): boolean;
    metrics(): any;
    addListener(eventType: string, listener: any): any;
    removeAllListeners(eventType?: string): void;
    scheduleLayoutAnimation(event: any): void;
}

export interface DimensionsStatic {
    get(dim: string): ScaledSize;
    set(dims: any): void;
    addEventListener(type: string, handler: any): any;
}

export interface AlertStatic {
    alert(title: string, message?: string, buttons?: any, options?: any): void;
    prompt(title: string, message?: string, callbackOrButtons?: any, type?: string, defaultValue?: string, keyboardType?: string): void;
}

export interface LinkingStatic {
    openURL(url: string): any;
    canOpenURL(url: string): any;
    getInitialURL(): any;
    openSettings(): any;
    sendIntent(action: string, extras?: any): any;
    addEventListener(type: string, handler: any): any;
}

export declare function View(props: ViewProps): any;
export declare function Text(props: TextProps): any;
export declare function Pressable(props: PressableProps): any;
export declare function TextInput(props: TextInputProps): any;
export declare function Image(props: ImageProps): any;
export declare function ScrollView(props: ScrollViewProps): any;
export declare function FlatList(props: FlatListProps): any;
export declare function SectionList(props: SectionListProps): any;
export declare function RefreshControl(props: RefreshControlProps): any;
export declare function Modal(props: ModalProps): any;
export declare function Switch(props: SwitchProps): any;
export declare function ActivityIndicator(props: ActivityIndicatorProps): any;
export declare function KeyboardAvoidingView(props: KeyboardAvoidingViewProps): any;
export declare function StatusBar(props: StatusBarProps): any;

export declare const StyleSheet: StyleSheetStatic;
export declare const Platform: PlatformStatic;
export declare const Keyboard: KeyboardStatic;
export declare const Dimensions: DimensionsStatic;
export declare const Alert: AlertStatic;
export declare const Linking: LinkingStatic;
export declare const Animated: any;
export declare const Easing: any;

export declare function useWindowDimensions(): ScaledSize;
export declare function createAnimatedValue(initial?: number): any;
export declare function createAnimatedValueXY(initial?: any): any;
