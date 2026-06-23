"""JacSX portable UI primitives — the ``@jac/ui`` module.

Every primitive re-exports the React Native component unchanged ("keep
everything the same as React Native"). The platform switch is the bundler's
job, NOT this module's:

* native (``--client react-native`` / ``expo``): ``react-native`` resolves to
  the real RN package, so the primitives are RN components rendered by the
  native view system.
* web (default, no ``--client``): the bundler aliases ``react-native`` ->
  ``react-native-web``, so the *same* imports lower to RNW — e.g. ``View``
  renders as a ``<div>`` and ``Text`` as a ``<span>`` in the DOM.

Apps import from the bare ``@jac/ui`` specifier, which the bundler aliases to
the compiled ``client_ui.js`` (mirrors how ``@jac/runtime`` is wired). This is
the *only* sanctioned UI import surface in JacSX mode — see the validation
pass (rejects raw ``div``/``span``/etc.) for the enforcement half.

Lowering table (see docs/jacsx/primitive-contract.md §3):
    View       -> react-native View       / react-native-web View       (<div>)
    Text       -> react-native Text       / react-native-web Text       (<span>)
    Pressable  -> react-native Pressable  / react-native-web Pressable   (button)
    TextInput  -> react-native TextInput  / react-native-web TextInput   (input)
    Image      -> react-native Image      / react-native-web Image       (img)
    ScrollView -> react-native ScrollView / react-native-web ScrollView  (scroll div)

``StyleSheet`` is re-exported too: ``StyleSheet.create({})`` is the canonical
authoring form (§1.2), so it ships on the same import surface as the
primitives — apps never import it directly from ``react-native``.
"""

import from 'react-native' {
    View as RNView,
    Text as RNText,
    Pressable as RNPressable,
    TextInput as RNTextInput,
    Image as RNImage,
    ScrollView as RNScrollView,
    StyleSheet as RNStyleSheet,
    Animated as RNAnimated,
    Easing as RNEasing
}


glob:pub View = RNView,
     Text = RNText,
     Pressable = RNPressable,
     TextInput = RNTextInput,
     Image = RNImage,
     ScrollView = RNScrollView,
     StyleSheet = RNStyleSheet,
     Animated = RNAnimated,
     Easing = RNEasing;
