/**
 * intl.js — Minimal ECMA-402 Intl foundation backed by globalThis.__icu.
 *
 * The native bridge (libicu_shim.so) is wired onto __icu by js_intl_wire_global.
 * This file installs globalThis.Intl with the major constructors.
 */

(function () {
  'use strict';

  var icu = globalThis.__icu;
  if (!icu) {
    // Keep a presence stub so feature detection does not throw.
    Object.defineProperty(globalThis, 'Intl', {
      value: {},
      writable: true,
      enumerable: false,
      configurable: true
    });
    return;
  }

  function _installMeta(fn, name, length) {
    Object.defineProperty(fn, 'name', {
      value: name, writable: false, enumerable: false, configurable: true
    });
    Object.defineProperty(fn, 'length', {
      value: length, writable: false, enumerable: false, configurable: true
    });
    return fn;
  }

  function _isPosixLocaleTag(tag) {
    var s = _asciiLower(String(tag || ''));
    return s.indexOf('posix') >= 0;
  }

  function _defaultLocale() {
    var d = icu.getDefaultLocale() || 'en';
    // ICU's en_US_POSIX / en-US-u-va-posix is not usable as an Intl locale.
    if (_isPosixLocaleTag(d)) return 'en-US';
    var c = icu.canonicalLocale(d);
    if (c && !_isPosixLocaleTag(c)) return c;
    return 'en-US';
  }

  function _toLocale(locales) {
    if (locales === undefined || locales === null) {
      return _defaultLocale();
    }
    if (typeof locales === 'string') {
      if (_isPosixLocaleTag(locales)) return 'en-US';
      var one = icu.canonicalLocale(locales);
      if (one && _isPosixLocaleTag(one)) return 'en-US';
      return one || locales || 'en';
    }
    if (typeof locales === 'object' && typeof locales.length === 'number') {
      if (locales.length === 0) return _defaultLocale();
      var raw0 = String(locales[0]);
      if (_isPosixLocaleTag(raw0)) return 'en-US';
      var c0 = icu.canonicalLocale(raw0);
      if (c0 && _isPosixLocaleTag(c0)) return 'en-US';
      return c0 || raw0 || 'en';
    }
    var raw1 = String(locales);
    if (_isPosixLocaleTag(raw1)) return 'en-US';
    var c1 = icu.canonicalLocale(raw1);
    if (c1 && _isPosixLocaleTag(c1)) return 'en-US';
    return c1 || 'en';
  }

  function _opt(options, key, fallback) {
    if (options == null || typeof options !== 'object') return fallback;
    if (options[key] === undefined || options[key] === null) return fallback;
    return String(options[key]);
  }

  var LOCALE_BRAND = Symbol('[[InitializedLocale]]');
  var RE_LANG = /^[a-z]{2,3}$|^[a-z]{5,8}$/i;
  var RE_SCRIPT = /^[a-z]{4}$/i;
  var RE_REGION = /^([a-z]{2}|[0-9]{3})$/i;
  var RE_VARIANT = /^([a-z0-9]{5,8}|[0-9][a-z0-9]{3})$/i;
  var RE_TYPE = /^[a-z0-9]{3,8}(-[a-z0-9]{3,8})*$/i;
  // unicode_locale_key = alphanum alpha  (second char must be a letter)
  var RE_EXTENSION_KEY = /^[0-9a-z][a-z]$/i;
  var WEEKDAY_TO_U = {
    '0': 'sun', '1': 'mon', '2': 'tue', '3': 'wed',
    '4': 'thu', '5': 'fri', '6': 'sat', '7': 'sun'
  };
  var LOCALE_EXT_KEYS = ['ca', 'co', 'fw', 'hc', 'kf', 'kn', 'nu'];
  // ICU 74 gaps vs CLDR/ICU 78 — small high-value alias overlays.
  var LANG_TAG_ALIASES = {
    'cmn': 'zh',
    'sh': 'sr-Latn',
    'cel-gaulish': 'xtg',
    'zh-min-nan': 'nan',
    'i-default': 'en'
  };
  var VARIANT_ALIASES = {
    'heploc': 'alalc97'
  };

  function _isLocaleObj(v) {
    return v != null && typeof v === 'object' && v[LOCALE_BRAND] === true;
  }

  function _requireLocale(v) {
    if (!_isLocaleObj(v)) {
      throw new TypeError('Intl.Locale method called on incompatible receiver');
    }
    return v;
  }

  function _asciiLower(s) {
    return String(s).toLowerCase();
  }

  function _isWellFormedLanguageTag(tag) {
    if (typeof tag !== 'string' || tag.length === 0) return false;
    if (tag.indexOf('_') >= 0) return false;
    var parts = _asciiLower(tag).split('-');
    if (parts.length === 0 || parts[0].length === 0) return false;

    var i = 0;
    // unicode_language_subtag
    if (!RE_LANG.test(parts[i])) return false;
    i++;
    // unicode_script_subtag
    if (i < parts.length && RE_SCRIPT.test(parts[i])) i++;
    // unicode_region_subtag
    if (i < parts.length && RE_REGION.test(parts[i])) i++;
    // unicode_variant_subtag*
    var seenVariants = Object.create(null);
    while (i < parts.length && RE_VARIANT.test(parts[i])) {
      if (seenVariants[parts[i]]) return false;
      seenVariants[parts[i]] = true;
      i++;
    }

    var seenSingletons = Object.create(null);
    while (i < parts.length) {
      var sing = parts[i];
      if (sing.length !== 1 || !/^[a-z0-9]$/.test(sing)) return false;
      if (seenSingletons[sing]) return false;
      seenSingletons[sing] = true;
      i++;
      if (sing === 'x') {
        // privateuse: 1*('-' (1*8alphanum))
        if (i >= parts.length) return false;
        while (i < parts.length) {
          if (!/^[a-z0-9]{1,8}$/.test(parts[i])) return false;
          i++;
        }
        break;
      }
      if (sing === 'u') {
        // unicode_locale_extensions: attributes then keywords (at least one)
        var sawKeyword = false;
        var sawAttr = false;
        if (i >= parts.length) return false;
        while (i < parts.length) {
          var p = parts[i];
          if (p.length === 1) break; // next singleton
          if (!sawKeyword && /^[a-z0-9]{3,8}$/.test(p)) {
            // attribute
            sawAttr = true;
            i++;
            continue;
          }
          if (!RE_EXTENSION_KEY.test(p)) return false;
          sawKeyword = true;
          var key = p;
          i++;
          // types (optional; empty value allowed → just the key)
          while (i < parts.length && /^[a-z0-9]{3,8}$/.test(parts[i])) {
            i++;
          }
          // Duplicate unicode keywords are allowed; first wins at canonicalize.
          seenSingletons['u:' + key] = true;
        }
        if (!sawAttr && !sawKeyword) return false;
      } else if (sing === 't') {
        // transformed extensions — at least one subtag; allow tlang + tfields
        if (i >= parts.length) return false;
        var tVariants = Object.create(null);
        var tPos = 0;
        // optional tlang
        if (RE_LANG.test(parts[i])) {
          i++;
          tPos = 1;
          if (i < parts.length && parts[i].length !== 1 && RE_SCRIPT.test(parts[i])) {
            i++;
          }
          if (i < parts.length && parts[i].length !== 1 && RE_REGION.test(parts[i])) {
            i++;
          }
          while (i < parts.length && parts[i].length !== 1 && RE_VARIANT.test(parts[i])) {
            if (tVariants[parts[i]]) return false;
            tVariants[parts[i]] = true;
            i++;
          }
        }
        // tfields: (alphanum{2} ('-' alphanum{3,8})+) +
        var sawTField = false;
        while (i < parts.length && parts[i].length !== 1) {
          if (!/^[a-z0-9]{2}$/.test(parts[i])) return false;
          i++;
          var typeCount = 0;
          while (i < parts.length && /^[a-z0-9]{3,8}$/.test(parts[i])) {
            i++;
            typeCount++;
          }
          if (typeCount === 0) return false;
          sawTField = true;
        }
        if (!sawTField && tPos === 0) return false;
      } else {
        // other extensions: 1*('-' (2*8alphanum))
        if (i >= parts.length) return false;
        var extCount = 0;
        while (i < parts.length && /^[a-z0-9]{2,8}$/.test(parts[i])) {
          i++;
          extCount++;
        }
        if (extCount === 0) return false;
      }
    }
    return i === parts.length;
  }

  function _splitExtensions(tag) {
    var parts = String(tag).split('-');
    var i = 0;
    if (parts.length === 0) return { base: tag, exts: {}, privateUse: '' };
    i = 1;
    if (i < parts.length && RE_SCRIPT.test(parts[i])) i++;
    if (i < parts.length && RE_REGION.test(parts[i])) i++;
    while (i < parts.length && RE_VARIANT.test(parts[i])) i++;
    var base = parts.slice(0, i).join('-');
    var exts = Object.create(null);
    var privateUse = '';
    while (i < parts.length) {
      var sing = parts[i].toLowerCase();
      i++;
      if (sing === 'x') {
        privateUse = 'x';
        while (i < parts.length) {
          privateUse += '-' + parts[i];
          i++;
        }
        break;
      }
      var body = [];
      while (i < parts.length && parts[i].length !== 1) {
        body.push(parts[i]);
        i++;
      }
      exts[sing] = body;
    }
    return { base: base, exts: exts, privateUse: privateUse };
  }

  function _parseLanguageId(base) {
    var parts = String(base).split('-');
    var language = parts[0] || '';
    var idx = 1;
    var script, region;
    var variants = [];
    if (idx < parts.length && RE_SCRIPT.test(parts[idx])) {
      script = parts[idx];
      idx++;
    }
    if (idx < parts.length && RE_REGION.test(parts[idx])) {
      region = parts[idx];
      idx++;
    }
    while (idx < parts.length) {
      variants.push(parts[idx]);
      idx++;
    }
    return {
      language: language,
      script: script,
      region: region,
      variants: variants.length ? variants.join('-') : undefined
    };
  }

  function _parseUnicodeKeywords(extBody) {
    var attrs = [];
    var keywords = Object.create(null);
    var i = 0;
    while (i < extBody.length && /^[a-z0-9]{3,8}$/i.test(extBody[i]) &&
           !RE_EXTENSION_KEY.test(extBody[i])) {
      attrs.push(_asciiLower(extBody[i]));
      i++;
    }
    while (i < extBody.length) {
      var key = _asciiLower(extBody[i]);
      i++;
      var types = [];
      while (i < extBody.length && /^[a-z0-9]{3,8}$/i.test(extBody[i])) {
        types.push(_asciiLower(extBody[i]));
        i++;
      }
      // First keyword wins on duplicates (UTS #35 / ECMA-402).
      if (!Object.prototype.hasOwnProperty.call(keywords, key)) {
        keywords[key] = types.join('-');
      }
    }
    attrs.sort();
    return { attrs: attrs, keywords: keywords };
  }

  function _canonicalizeUValue(key, value) {
    var v = _asciiLower(String(value));
    if (v === 'true') return '';
    return v;
  }

  function _buildUnicodeExtension(attrs, keywords) {
    var parts = ['u'];
    var i;
    for (i = 0; i < attrs.length; i++) parts.push(attrs[i]);
    var keys = Object.keys(keywords).sort();
    for (i = 0; i < keys.length; i++) {
      var k = keys[i];
      parts.push(k);
      if (keywords[k]) {
        var segs = String(keywords[k]).split('-');
        for (var j = 0; j < segs.length; j++) {
          if (segs[j]) parts.push(segs[j]);
        }
      }
    }
    if (parts.length === 1) return '';
    return parts.join('-');
  }

  function _insertExtension(localeNoU, extension, privateUse) {
    var out = localeNoU;
    if (extension) out += (out ? '-' : '') + extension;
    if (privateUse) out += (out ? '-' : '') + privateUse;
    return out;
  }

  function _canonicalizeTag(tag) {
    var lower = _asciiLower(tag);
    if (Object.prototype.hasOwnProperty.call(LANG_TAG_ALIASES, lower)) {
      tag = LANG_TAG_ALIASES[lower];
    } else {
      // Language-subtag aliases (prefix), preserving script/region/extensions.
      var segs = tag.split('-');
      var lang0 = _asciiLower(segs[0]);
      if (lang0 === 'cmn') {
        segs[0] = 'zh';
        tag = segs.join('-');
      } else if (lang0 === 'sh') {
        segs[0] = 'sr';
        // Bare "sh" → "sr-Latn"; keep an explicit script if present.
        if (segs.length === 1 || (segs.length > 1 && !RE_SCRIPT.test(segs[1]))) {
          segs.splice(1, 0, 'Latn');
        }
        tag = segs.join('-');
      } else if (lang0 === 'cnr') {
        segs[0] = 'sr';
        // Bare "cnr" → "sr-ME"; keep an explicit region if present.
        var hasRegion = false;
        for (var si = 1; si < segs.length; si++) {
          if (RE_REGION.test(segs[si])) { hasRegion = true; break; }
          if (segs[si].length === 1) break;
        }
        if (!hasRegion) {
          // Insert region after optional script.
          var insertAt = 1;
          if (segs.length > 1 && RE_SCRIPT.test(segs[1])) insertAt = 2;
          segs.splice(insertAt, 0, 'ME');
        }
        tag = segs.join('-');
      }
    }
    var can = icu.canonicalLocale(tag);
    if (!can) return '';

    // Region aliases ICU 74 may miss (likely-territory aware for SU/810).
    var baseParts = _splitExtensions(can);
    var id = _parseLanguageId(baseParts.base);
    if (id.region) {
      var regUp = String(id.region).toUpperCase();
      var newRegion = null;
      if (regUp === '554') newRegion = 'NZ';
      else if (regUp === 'SU' || regUp === '810') {
        var script = id.script ? String(id.script).toLowerCase() : '';
        var lang = id.language ? String(id.language).toLowerCase() : '';
        if (lang === 'hy' || script === 'armn') newRegion = 'AM';
        else newRegion = 'RU';
      } else if (regUp === 'CS') {
        newRegion = 'RS';
      }
      if (newRegion) {
        var rebuilt = id.language;
        if (id.script) rebuilt += '-' + id.script;
        rebuilt += '-' + newRegion;
        if (id.variants) rebuilt += '-' + id.variants;
        var sings = Object.keys(baseParts.exts).sort();
        for (var ei = 0; ei < sings.length; ei++) {
          var es = sings[ei];
          rebuilt += '-' + es + '-' + baseParts.exts[es].join('-');
        }
        if (baseParts.privateUse) rebuilt += '-' + baseParts.privateUse;
        can = rebuilt;
        var recan = icu.canonicalLocale(can);
        if (recan) can = recan;
      }
    }

    // Variant aliases (e.g. heploc → alalc97); drop redundant hepburn when replaced.
    var parts = can.split('-');
    var changed = false;
    for (var i = 0; i < parts.length; i++) {
      var pl = _asciiLower(parts[i]);
      if (Object.prototype.hasOwnProperty.call(VARIANT_ALIASES, pl)) {
        parts[i] = VARIANT_ALIASES[pl];
        changed = true;
      }
    }
    if (changed) {
      // ja-Latn-hepburn-alalc97 → ja-Latn-alalc97 (preferred variant replaces pair)
      var filtered = [];
      for (i = 0; i < parts.length; i++) {
        if (_asciiLower(parts[i]) === 'hepburn' &&
            parts.some(function (p) { return _asciiLower(p) === 'alalc97'; })) {
          continue;
        }
        filtered.push(parts[i]);
      }
      can = filtered.join('-');
      var again = icu.canonicalLocale(can);
      if (again) can = again;
    }

    // Whole-tag aliases after ICU (covers some grandfathered leftovers).
    lower = _asciiLower(can);
    if (Object.prototype.hasOwnProperty.call(LANG_TAG_ALIASES, lower)) {
      can = LANG_TAG_ALIASES[lower];
    }
    return can;
  }

  function _coreTagWithoutPrivate(tag) {
    var parts = _splitExtensions(tag);
    var core = parts.base;
    var sings = Object.keys(parts.exts).sort();
    for (var i = 0; i < sings.length; i++) {
      var s = sings[i];
      core += '-' + s + '-' + parts.exts[s].join('-');
    }
    return { core: core, privateUse: parts.privateUse };
  }

  function _reattachPrivate(tag, privateUse) {
    if (!privateUse) return tag;
    if (tag.indexOf('-x-') >= 0 || tag.slice(0, 2) === 'x-') return tag;
    return tag + (tag ? '-' : '') + privateUse;
  }

  function _transformLikely(tag, transformFn) {
    var split = _coreTagWithoutPrivate(tag);
    var out = transformFn(split.core);
    if (!out || !_isWellFormedLanguageTag(out)) {
      out = transformFn(split.core.split('-').slice(0, 1).join('-') || split.core);
    }
    if (!out || !_isWellFormedLanguageTag(out)) return tag;
    return _reattachPrivate(out, split.privateUse);
  }

  function _getOption(options, prop, type, values, fallback) {
    var v = options[prop];
    if (v === undefined) return fallback;
    if (type === 'boolean') {
      v = Boolean(v);
    } else if (type === 'string') {
      v = String(v);
    }
    if (values && values.length && values.indexOf(v) < 0) {
      throw new RangeError('Invalid option ' + prop + ': ' + v);
    }
    return v;
  }

  function _weekdayToUValue(fw) {
    if (Object.prototype.hasOwnProperty.call(WEEKDAY_TO_U, fw)) {
      return WEEKDAY_TO_U[fw];
    }
    return fw;
  }

  function _updateLanguageId(tag, options) {
    var parts = _splitExtensions(tag);
    var id = _parseLanguageId(parts.base);
    var language = _getOption(options, 'language', 'string', undefined, id.language);
    if (!RE_LANG.test(language)) {
      throw new RangeError('Invalid language: ' + language);
    }
    var script = _getOption(options, 'script', 'string', undefined, id.script);
    if (script !== undefined && !RE_SCRIPT.test(script)) {
      throw new RangeError('Invalid script: ' + script);
    }
    var region = _getOption(options, 'region', 'string', undefined, id.region);
    if (region !== undefined && !RE_REGION.test(region)) {
      throw new RangeError('Invalid region: ' + region);
    }
    var variants = _getOption(options, 'variants', 'string', undefined, id.variants);
    if (variants !== undefined) {
      if (variants === '') throw new RangeError('Invalid variants');
      var lowerVariants = _asciiLower(variants);
      var variantSubtags = lowerVariants.split('-');
      var seen = Object.create(null);
      for (var vi = 0; vi < variantSubtags.length; vi++) {
        var vs = variantSubtags[vi];
        if (!RE_VARIANT.test(vs)) throw new RangeError('Invalid variants');
        if (seen[vs]) throw new RangeError('Duplicate variants');
        seen[vs] = true;
      }
    }
    var newTag = language;
    if (script !== undefined) newTag += '-' + script;
    if (region !== undefined) newTag += '-' + region;
    if (variants !== undefined) newTag += '-' + variants;
    // Reattach non-u extensions + private use from original tag.
    var singletons = Object.keys(parts.exts);
    for (var si = 0; si < singletons.length; si++) {
      var s = singletons[si];
      newTag += '-' + s + '-' + parts.exts[s].join('-');
    }
    if (parts.privateUse) newTag += (newTag ? '-' : '') + parts.privateUse;
    return newTag;
  }

  function _makeLocaleRecord(tag, opt) {
    var parts = _splitExtensions(tag);
    var uBody = parts.exts.u || [];
    var parsed = _parseUnicodeKeywords(uBody);
    var attrs = parsed.attrs.slice();
    var keywords = Object.create(null);
    var pk;
    for (pk in parsed.keywords) {
      if (Object.prototype.hasOwnProperty.call(parsed.keywords, pk)) {
        keywords[pk] = parsed.keywords[pk];
      }
    }
    var result = { locale: '', ca: undefined, co: undefined, fw: undefined,
      hc: undefined, kf: undefined, kn: undefined, nu: undefined };
    for (var ki = 0; ki < LOCALE_EXT_KEYS.length; ki++) {
      var key = LOCALE_EXT_KEYS[ki];
      var value = Object.prototype.hasOwnProperty.call(keywords, key)
        ? keywords[key]
        : undefined;
      var override = opt[key];
      if (override !== undefined) {
        value = _canonicalizeUValue(key, override);
        keywords[key] = value;
      }
      if (value !== undefined) {
        if (key === 'fw') {
          result.fw = value === '' ? 'true' : value;
        } else {
          // kf empty → ""; kn empty/"true" handled by boolean conversion later
          result[key] = value;
        }
      }
    }
    // Rebuild locale without unicode extension, then reinsert.
    var localeNoU = parts.base;
    var otherSingletons = Object.keys(parts.exts).filter(function (s) {
      return s !== 'u';
    }).sort();
    for (var oi = 0; oi < otherSingletons.length; oi++) {
      var os = otherSingletons[oi];
      localeNoU += '-' + os + '-' + parts.exts[os].join('-');
    }
    var extension = _buildUnicodeExtension(attrs, keywords);
    var combined = _insertExtension(localeNoU, extension, parts.privateUse);
    var canonical = _canonicalizeTag(combined);
    if (!canonical) throw new RangeError('Invalid language tag: ' + combined);
    result.locale = canonical;

    // Re-read keyword slots from the canonical tag so aliases (islamicc→…) apply.
    var cParts = _splitExtensions(canonical);
    var cParsed = _parseUnicodeKeywords(cParts.exts.u || []);
    for (ki = 0; ki < LOCALE_EXT_KEYS.length; ki++) {
      key = LOCALE_EXT_KEYS[ki];
      if (Object.prototype.hasOwnProperty.call(cParsed.keywords, key)) {
        value = cParsed.keywords[key];
        if (key === 'fw') {
          result.fw = value === '' ? 'true' : value;
        } else {
          result[key] = value;
        }
      } else if (opt[key] === undefined) {
        result[key] = undefined;
      }
    }
    return result;
  }

  function getCanonicalLocales(locales) {
    // CanonicalizeLocaleList (ECMA-402)
    if (locales === undefined) return [];
    var O;
    if (typeof locales === 'string' || _isLocaleObj(locales)) {
      O = [locales];
    } else {
      if (locales === null) {
        throw new TypeError('Invalid locales argument');
      }
      O = Object(locales);
    }
    var len = Number(O.length);
    if (!isFinite(len) || len < 0) len = 0;
    len = Math.min(Math.floor(len), 0x1fffffffffffff);
    var out = [];
    for (var k = 0; k < len; k++) {
      if (!(String(k) in O)) continue;
      var kValue = O[k];
      var tag;
      if (_isLocaleObj(kValue)) {
        tag = kValue.__tag;
      } else if (typeof kValue === 'string') {
        tag = kValue;
      } else if (kValue === null ||
                 (typeof kValue !== 'object' && typeof kValue !== 'function')) {
        throw new TypeError('Invalid locale in getCanonicalLocales');
      } else {
        tag = String(kValue);
      }
      if (!_isWellFormedLanguageTag(tag)) {
        throw new RangeError('Invalid language tag: ' + tag);
      }
      var can = _canonicalizeTag(tag);
      if (!can) throw new RangeError('Invalid language tag: ' + tag);
      if (out.indexOf(can) < 0) out.push(can);
    }
    return out;
  }
  _installMeta(getCanonicalLocales, 'getCanonicalLocales', 1);

  function supportedLocalesOf(locales /*, options */) {
    var list = getCanonicalLocales(locales);
    return list.slice();
  }

  // ── Locale ────────────────────────────────────────────────────────────────

  function Locale(tag, options) {
    if (new.target === undefined) {
      throw new TypeError('Intl.Locale constructor requires "new"');
    }
    // Spec: tag must be a String or Object (null is not an Object).
    if (_isLocaleObj(tag)) {
      tag = tag.__tag;
    } else if (typeof tag === 'string') {
      // keep
    } else if (tag !== null && typeof tag === 'object') {
      tag = String(tag);
    } else {
      throw new TypeError('Invalid tag in Intl.Locale');
    }

    // CoerceOptionsToObject — null is not ToObject'd (returns {}).
    if (options === undefined) {
      options = Object.create(null);
    } else if (options === null) {
      throw new TypeError('Invalid options in Intl.Locale');
    } else {
      options = Object(options);
    }

    if (!_isWellFormedLanguageTag(tag)) {
      throw new RangeError('Invalid language tag: ' + tag);
    }
    tag = _canonicalizeTag(tag);
    if (!tag) throw new RangeError('Invalid language tag');

    tag = _updateLanguageId(tag, options);

    var opt = Object.create(null);
    var calendar = _getOption(options, 'calendar', 'string', undefined, undefined);
    if (calendar !== undefined) {
      if (!RE_TYPE.test(calendar)) throw new RangeError('Invalid calendar');
      opt.ca = calendar;
    }
    var collation = _getOption(options, 'collation', 'string', undefined, undefined);
    if (collation !== undefined) {
      if (!RE_TYPE.test(collation)) throw new RangeError('Invalid collation');
      opt.co = collation;
    }
    var fw = _getOption(options, 'firstDayOfWeek', 'string', undefined, undefined);
    if (fw !== undefined) {
      fw = _weekdayToUValue(fw);
      if (!RE_TYPE.test(fw)) throw new RangeError('Invalid firstDayOfWeek');
      opt.fw = fw;
    }
    var hc = _getOption(options, 'hourCycle', 'string',
      ['h11', 'h12', 'h23', 'h24'], undefined);
    if (hc !== undefined) opt.hc = hc;
    var kf = _getOption(options, 'caseFirst', 'string',
      ['upper', 'lower', 'false'], undefined);
    if (kf !== undefined) opt.kf = kf;
    var kn = _getOption(options, 'numeric', 'boolean', undefined, undefined);
    if (kn !== undefined) opt.kn = String(kn);
    var numberingSystem = _getOption(options, 'numberingSystem', 'string',
      undefined, undefined);
    if (numberingSystem !== undefined) {
      if (!RE_TYPE.test(numberingSystem)) {
        throw new RangeError('Invalid numberingSystem');
      }
      opt.nu = numberingSystem;
    }

    var rec = _makeLocaleRecord(tag, opt);
    this[LOCALE_BRAND] = true;
    this.__tag = rec.locale;
    this.__ca = rec.ca;
    this.__co = rec.co;
    this.__fw = rec.fw;
    this.__hc = rec.hc;
    this.__kf = rec.kf;
    // [[Numeric]] is always a boolean when "kn" is a LocaleExtensionKey.
    this.__kn = (rec.kn === 'true' || rec.kn === '');
    this.__nu = rec.nu;
  }
  _installMeta(Locale, 'Locale', 1);

  function _installLocaleGetter(prop, fn) {
    _installMeta(fn, 'get ' + prop, 0);
    Object.defineProperty(Locale.prototype, prop, {
      get: fn,
      enumerable: false,
      configurable: true
    });
  }

  function _installLocaleMethod(prop, fn, length) {
    _installMeta(fn, prop, length);
    Object.defineProperty(Locale.prototype, prop, {
      value: fn,
      writable: true,
      enumerable: false,
      configurable: true
    });
  }

  _installLocaleGetter('baseName', function () {
    return _splitExtensions(_requireLocale(this).__tag).base;
  });
  _installLocaleGetter('calendar', function () {
    return _requireLocale(this).__ca;
  });
  _installLocaleGetter('collation', function () {
    return _requireLocale(this).__co;
  });
  _installLocaleGetter('firstDayOfWeek', function () {
    return _requireLocale(this).__fw;
  });
  _installLocaleGetter('hourCycle', function () {
    return _requireLocale(this).__hc;
  });
  _installLocaleGetter('caseFirst', function () {
    return _requireLocale(this).__kf;
  });
  _installLocaleGetter('numeric', function () {
    return _requireLocale(this).__kn;
  });
  _installLocaleGetter('numberingSystem', function () {
    return _requireLocale(this).__nu;
  });
  _installLocaleGetter('language', function () {
    return _parseLanguageId(_splitExtensions(_requireLocale(this).__tag).base).language;
  });
  _installLocaleGetter('script', function () {
    return _parseLanguageId(_splitExtensions(_requireLocale(this).__tag).base).script;
  });
  _installLocaleGetter('region', function () {
    return _parseLanguageId(_splitExtensions(_requireLocale(this).__tag).base).region;
  });
  _installLocaleGetter('variants', function () {
    return _parseLanguageId(_splitExtensions(_requireLocale(this).__tag).base).variants;
  });

  _installLocaleMethod('toString', function () {
    return _requireLocale(this).__tag;
  }, 0);
  _installLocaleMethod('toJSON', function () {
    return _requireLocale(this).__tag;
  }, 0);
  _installLocaleMethod('maximize', function () {
    var loc = _requireLocale(this);
    var max = loc.__tag;
    if (icu.maximizeLocale) {
      max = _transformLikely(loc.__tag, function (t) {
        return icu.maximizeLocale(t);
      });
    }
    return new Locale(max);
  }, 0);
  _installLocaleMethod('minimize', function () {
    var loc = _requireLocale(this);
    var min = loc.__tag;
    if (icu.minimizeLocale) {
      min = _transformLikely(loc.__tag, function (t) {
        return icu.minimizeLocale(t);
      });
    }
    return new Locale(min);
  }, 0);

  // ── Locale Info APIs (Intl.Locale-info) ───────────────────────────────────

  var FW_TO_DAY = {
    mon: 1, tue: 2, wed: 3, thu: 4, fri: 5, sat: 6, sun: 7
  };
  var RTL_LANGS = {
    ar: 1, fa: 1, he: 1, yi: 1, ur: 1, ps: 1, sd: 1, ug: 1, dv: 1,
    ha: 0, ku: 0, ckb: 1, glk: 1, mzn: 1, bqi: 1, bcc: 1, pnb: 1,
    nqo: 1, ae: 1, arc: 1, azb: 1
  };

  function _csvToArray(s) {
    if (s == null || s === '') return [];
    return String(s).split(',').filter(function (x) { return x.length > 0; });
  }

  function _localeInfoCsv(tag, kind) {
    if (typeof icu.localeInfo === 'function') {
      var v = icu.localeInfo(tag, kind);
      if (v === undefined) return undefined;
      if (typeof v === 'string' && v.length > 0) return v;
    }
    return null;
  }

  _installLocaleMethod('getCalendars', function () {
    var loc = _requireLocale(this);
    if (loc.__ca != null && loc.__ca !== '') return [loc.__ca];
    var csv = _localeInfoCsv(loc.__tag, 0);
    if (csv != null) {
      var arr = _csvToArray(csv);
      if (arr.length) return arr;
    }
    return ['gregory'];
  }, 0);

  _installLocaleMethod('getCollations', function () {
    var loc = _requireLocale(this);
    if (loc.__co != null && loc.__co !== '') return [loc.__co];
    var csv = _localeInfoCsv(loc.__tag, 1);
    if (csv != null) {
      var arr = _csvToArray(csv).filter(function (c) {
        return c !== 'standard' && c !== 'search';
      });
      if (arr.length) return arr;
    }
    return ['emoji', 'eor'];
  }, 0);

  _installLocaleMethod('getHourCycles', function () {
    var loc = _requireLocale(this);
    if (loc.__hc != null && loc.__hc !== '') return [loc.__hc];
    var csv = _localeInfoCsv(loc.__tag, 2);
    if (csv != null) {
      var arr = _csvToArray(csv);
      if (arr.length) return arr;
    }
    // CLDR-ish default: en/US-like → h12, else h23
    var region = _parseLanguageId(_splitExtensions(loc.__tag).base).region;
    var lang = _parseLanguageId(_splitExtensions(loc.__tag).base).language;
    if (region === 'US' || region === 'CA' || region === 'AU' || region === 'NZ' ||
        region === 'PH' || region === 'IN' || lang === 'en') {
      return ['h12'];
    }
    return ['h23'];
  }, 0);

  _installLocaleMethod('getNumberingSystems', function () {
    var loc = _requireLocale(this);
    if (loc.__nu != null && loc.__nu !== '') return [loc.__nu];
    var csv = _localeInfoCsv(loc.__tag, 3);
    if (csv != null) {
      var arr = _csvToArray(csv);
      if (arr.length) return arr;
    }
    return ['latn'];
  }, 0);

  _installLocaleMethod('getTimeZones', function () {
    var loc = _requireLocale(this);
    var region = _parseLanguageId(_splitExtensions(loc.__tag).base).region;
    // Spec: no unicode_region_subtag → undefined (even if ICU can guess).
    if (region == null || region === '') return undefined;
    var csv = _localeInfoCsv(loc.__tag, 4);
    if (typeof csv === 'string' && csv.length > 0) {
      var arr = _csvToArray(csv);
      if (arr.length) return arr;
    }
    // Region present but ICU enumeration failed — keep a non-empty list.
    return ['UTC'];
  }, 0);

  _installLocaleMethod('getTextInfo', function () {
    var loc = _requireLocale(this);
    var dir = 'ltr';
    var csv = _localeInfoCsv(loc.__tag, 5);
    if (csv === 'rtl' || csv === 'ltr') {
      dir = csv;
    } else {
      var lid = _parseLanguageId(_splitExtensions(loc.__tag).base);
      var script = lid.script;
      if (script === 'Arab' || script === 'Hebr' || script === 'Thaa' ||
          script === 'Nkoo' || script === 'Adlm') {
        dir = 'rtl';
      } else if (script === 'Latn' || script === 'Cyrl' || script === 'Grek') {
        dir = 'ltr';
      } else if (Object.prototype.hasOwnProperty.call(RTL_LANGS, lid.language)) {
        dir = RTL_LANGS[lid.language] ? 'rtl' : 'ltr';
      }
    }
    var info = Object.create(Object.prototype);
    Object.defineProperty(info, 'direction', {
      value: dir, writable: true, enumerable: true, configurable: true
    });
    return info;
  }, 0);

  _installLocaleMethod('getWeekInfo', function () {
    var loc = _requireLocale(this);
    var firstDay = 7;
    var weekend = [6, 7];
    var csv = _localeInfoCsv(loc.__tag, 6);
    if (typeof csv === 'string' && csv.length > 0) {
      var parts = csv.split(';');
      var fd = Number(parts[0]);
      if (fd >= 1 && fd <= 7) firstDay = fd;
      if (parts.length > 1 && parts[1]) {
        weekend = _csvToArray(parts[1]).map(Number).filter(function (n) {
          return n >= 1 && n <= 7;
        });
        if (!weekend.length) weekend = [6, 7];
      }
    }
    // Locale [[FirstDayOfWeek]] overrides calendar default.
    if (loc.__fw != null && loc.__fw !== '') {
      var mapped = FW_TO_DAY[_asciiLower(String(loc.__fw))];
      if (mapped) firstDay = mapped;
    }
    var info = Object.create(Object.prototype);
    Object.defineProperty(info, 'firstDay', {
      value: firstDay, writable: true, enumerable: true, configurable: true
    });
    Object.defineProperty(info, 'weekend', {
      value: weekend, writable: true, enumerable: true, configurable: true
    });
    return info;
  }, 0);

  Object.defineProperty(Locale.prototype, Symbol.toStringTag, {
    value: 'Intl.Locale',
    writable: false,
    enumerable: false,
    configurable: true
  });
  Object.defineProperty(Locale.prototype, 'constructor', {
    value: Locale,
    writable: true,
    enumerable: false,
    configurable: true
  });
  Object.defineProperty(Locale, 'prototype', {
    writable: false,
    enumerable: false,
    configurable: false
  });

  // ── NumberFormat ──────────────────────────────────────────────────────────

  var NUMBER_FORMAT_BRAND = Symbol('[[InitializedNumberFormat]]');
  var DATE_TIME_FORMAT_BRAND = Symbol('[[InitializedDateTimeFormat]]');

  function _requireNumberFormat(v) {
    if (v == null || typeof v !== 'object' || v[NUMBER_FORMAT_BRAND] !== true) {
      throw new TypeError('Intl.NumberFormat method called on incompatible receiver');
    }
    return v;
  }

  function _requireDateTimeFormat(v) {
    if (v == null || typeof v !== 'object' || v[DATE_TIME_FORMAT_BRAND] !== true) {
      throw new TypeError('Intl.DateTimeFormat method called on incompatible receiver');
    }
    return v;
  }

  function _buildNfStyle(options) {
    var style = _opt(options, 'style', 'decimal');
    var base;
    if (style === 'currency') {
      base = 'currency:' + _opt(options, 'currency', 'USD');
    } else if (style === 'unit') {
      base = 'unit:' + _opt(options, 'unit', 'percent');
    } else {
      base = style;
    }
    var extras = [];
    var notation = _opt(options, 'notation', 'standard');
    if (notation && notation !== 'standard') extras.push('notation=' + notation);
    if (notation === 'compact') {
      extras.push('compactDisplay=' + _opt(options, 'compactDisplay', 'short'));
    }
    var signDisplay = _opt(options, 'signDisplay', 'auto');
    if (signDisplay && signDisplay !== 'auto') extras.push('signDisplay=' + signDisplay);
    var hasMinFd = false, hasMaxFd = false, hasSig = false;
    if (options != null && typeof options === 'object') {
      if (options.minimumFractionDigits !== undefined && options.minimumFractionDigits !== null) {
        extras.push('minimumFractionDigits=' + Number(options.minimumFractionDigits));
        hasMinFd = true;
      }
      if (options.maximumFractionDigits !== undefined && options.maximumFractionDigits !== null) {
        extras.push('maximumFractionDigits=' + Number(options.maximumFractionDigits));
        hasMaxFd = true;
      }
      if (options.minimumIntegerDigits !== undefined && options.minimumIntegerDigits !== null) {
        extras.push('minimumIntegerDigits=' + Number(options.minimumIntegerDigits));
      }
      if (options.minimumSignificantDigits !== undefined && options.minimumSignificantDigits !== null) {
        extras.push('minimumSignificantDigits=' + Number(options.minimumSignificantDigits));
        hasSig = true;
      }
      if (options.maximumSignificantDigits !== undefined && options.maximumSignificantDigits !== null) {
        extras.push('maximumSignificantDigits=' + Number(options.maximumSignificantDigits));
        hasSig = true;
      }
    }
    // ECMA-402 digit defaults when significant-digit options are absent.
    // Skip for compact/scientific/engineering — those use significant-digit defaults.
    if (!hasSig && !hasMinFd && !hasMaxFd &&
        (!notation || notation === 'standard')) {
      if (style === 'percent') {
        extras.push('minimumFractionDigits=0');
        extras.push('maximumFractionDigits=0');
      } else if (style === 'decimal' || style === 'unit') {
        extras.push('minimumFractionDigits=0');
        extras.push('maximumFractionDigits=3');
      }
      // currency: leave ICU currency default fraction digits
    }
    if (!extras.length) return base;
    return base + ';' + extras.join(';');
  }

  function NumberFormat(locales, options) {
    if (!(this instanceof NumberFormat)) return new NumberFormat(locales, options);
    this.__locale = _toLocale(locales);
    this.__style = _buildNfStyle(options);
    this.__rawStyle = _opt(options, 'style', 'decimal');
    this.__currency = this.__rawStyle === 'currency' ? _opt(options, 'currency', 'USD') : undefined;
    this.__notation = _opt(options, 'notation', 'standard');
    this.__signDisplay = _opt(options, 'signDisplay', 'auto');
    this[NUMBER_FORMAT_BRAND] = true;
  }
  _installMeta(NumberFormat, 'NumberFormat', 0);
  NumberFormat.supportedLocalesOf = supportedLocalesOf;

  function _parseIcuParts(encoded) {
    var parts = [];
    if (typeof encoded !== 'string' || encoded.length === 0) return parts;
    var records = encoded.split('\x1e');
    for (var i = 0; i < records.length; i++) {
      var rec = records[i];
      if (!rec) continue;
      var sep = rec.indexOf('\x1f');
      if (sep < 0) {
        parts.push({ type: 'literal', value: rec });
      } else {
        parts.push({
          type: rec.slice(0, sep) || 'literal',
          value: rec.slice(sep + 1)
        });
      }
    }
    return parts;
  }

  function _specializeNumberParts(parts, n) {
    if (!parts || !parts.length) return parts;
    if (Number.isNaN(n)) {
      for (var i = 0; i < parts.length; i++) {
        if (parts[i].type === 'integer' || parts[i].type === 'literal') {
          parts[i] = { type: 'nan', value: parts[i].value };
        }
      }
      return parts;
    }
    if (n === Infinity || n === -Infinity) {
      for (var j = 0; j < parts.length; j++) {
        if (parts[j].type === 'integer' || parts[j].type === 'literal') {
          var v = parts[j].value;
          if (v === '\u221E' || v === '∞' || /[\u221E∞]|Infinity/i.test(v)) {
            parts[j] = { type: 'infinity', value: v };
          }
        }
      }
    }
    return parts;
  }

  function _toIntlMathNumber(v) {
    if (typeof v === 'bigint') {
      var s = v.toString();
      var n = Number(s);
      return n;
    }
    return Number(v);
  }

  var _nfMethods = {
    format(value) {
      var nf = _requireNumberFormat(this);
      return icu.formatNumber(nf.__locale, nf.__style, _toIntlMathNumber(value));
    },
    formatToParts(value) {
      var nf = _requireNumberFormat(this);
      var n = _toIntlMathNumber(value);
      if (typeof icu.formatNumberParts === 'function') {
        var enc = icu.formatNumberParts(nf.__locale, nf.__style, n);
        var parts = _specializeNumberParts(_parseIcuParts(enc), n);
        if (nf.__rawStyle === 'unit') {
          for (var ui = 0; ui < parts.length; ui++) {
            if (parts[ui].type === 'percentSign') {
              parts[ui] = { type: 'unit', value: parts[ui].value };
            }
          }
        }
        if (parts.length) return parts;
      }
      var formatted = icu.formatNumber(nf.__locale, nf.__style, n);
      if (Number.isNaN(n)) return [{ type: 'nan', value: formatted }];
      if (n === Infinity || n === -Infinity) {
        return _specializeNumberParts([{ type: 'literal', value: formatted }], n);
      }
      return [{ type: 'literal', value: formatted }];
    },
    formatRange(start, end) {
      var nf = _requireNumberFormat(this);
      if (start === undefined || end === undefined) {
        throw new TypeError('formatRange requires defined start and end');
      }
      // Preserve precision for BigInt / long integer strings via decimal range.
      var useDec =
        typeof start === 'bigint' || typeof end === 'bigint' ||
        (typeof start === 'string' && /^-?\d+$/.test(start)) ||
        (typeof end === 'string' && /^-?\d+$/.test(end));
      if (useDec && typeof icu.formatNumberRange === 'function') {
        return icu.formatNumberRange(
          nf.__locale, nf.__style, String(start), String(end)
        );
      }
      var a = _toIntlMathNumber(start);
      var b = _toIntlMathNumber(end);
      if (Number.isNaN(a) || Number.isNaN(b)) {
        throw new RangeError('Invalid number');
      }
      if (typeof icu.formatNumberRange === 'function') {
        return icu.formatNumberRange(nf.__locale, nf.__style, a, b);
      }
      var sa = icu.formatNumber(nf.__locale, nf.__style, a);
      var sb = icu.formatNumber(nf.__locale, nf.__style, b);
      return sa === sb ? sa : sa + '\u2013' + sb;
    },
    formatRangeToParts(start, end) {
      var nf = _requireNumberFormat(this);
      return [{ type: 'literal', value: _nfMethods.formatRange.call(nf, start, end) }];
    },
    resolvedOptions() {
      var nf = _requireNumberFormat(this);
      var o = {
        locale: nf.__locale,
        numberingSystem: 'latn',
        style: nf.__rawStyle,
        notation: nf.__notation,
        signDisplay: nf.__signDisplay
      };
      if (nf.__currency) o.currency = nf.__currency;
      return o;
    }
  };

  NumberFormat.prototype.format = _nfMethods.format;
  Object.defineProperty(NumberFormat.prototype, 'formatToParts', {
    value: _installMeta(_nfMethods.formatToParts, 'formatToParts', 1),
    writable: true,
    enumerable: false,
    configurable: true
  });
  Object.defineProperty(NumberFormat.prototype, 'formatRange', {
    value: _installMeta(_nfMethods.formatRange, 'formatRange', 2),
    writable: true,
    enumerable: false,
    configurable: true
  });
  Object.defineProperty(NumberFormat.prototype, 'formatRangeToParts', {
    value: _installMeta(_nfMethods.formatRangeToParts, 'formatRangeToParts', 2),
    writable: true,
    enumerable: false,
    configurable: true
  });
  NumberFormat.prototype.resolvedOptions = _nfMethods.resolvedOptions;

  // ── DateTimeFormat ────────────────────────────────────────────────────────

  function DateTimeFormat(locales, options) {
    if (!(this instanceof DateTimeFormat)) return new DateTimeFormat(locales, options);
    this.__locale = _toLocale(locales);
    this.__dateStyle = _opt(options, 'dateStyle', 'medium');
    this.__timeStyle = _opt(options, 'timeStyle', 'medium');
    if (options && options.dateStyle === undefined && options.timeStyle === undefined) {
      // Default both when no component options given.
      this.__dateStyle = 'medium';
      this.__timeStyle = 'medium';
    }
    var tz = _opt(options, 'timeZone', 'UTC');
    tz = tz === undefined || tz === null ? 'UTC' : String(tz);
    if (tz !== 'UTC') {
      // Validate via the engine's Temporal IANA zone database (spec: RangeError).
      try {
        Temporal.Instant.fromEpochMilliseconds(0).toZonedDateTimeISO(tz);
      } catch (e) {
        throw new RangeError('Invalid time zone specified: ' + tz);
      }
    }
    this.__timeZone = tz;
    this[DATE_TIME_FORMAT_BRAND] = true;
  }
  // icu.formatDateTime renders in ICU's process-default zone (host tz unless
  // set). Pin it to the formatter's configured timeZone (default UTC) right
  // before each native call so wall-clock output honors the option.
  function _dtfApplyTz(tz) {
    if (typeof icu.setDefaultTimeZone === 'function') {
      icu.setDefaultTimeZone(tz || 'UTC');
    }
  }
  _installMeta(DateTimeFormat, 'DateTimeFormat', 0);
  DateTimeFormat.supportedLocalesOf = supportedLocalesOf;

  function _temporalTypeName(v) {
    if (v == null || typeof v !== 'object') return '';
    var tag = Object.prototype.toString.call(v);
    // '[object Temporal.PlainDate]'
    if (tag.length > 19 && tag.slice(0, 18) === '[object Temporal.') {
      return tag.slice(18, tag.length - 1);
    }
    var n = v.constructor && v.constructor.name;
    return typeof n === 'string' ? n : '';
  }

  function _isTemporalObject(v) {
    var n = _temporalTypeName(v);
    return n === 'PlainDate' || n === 'PlainDateTime' || n === 'PlainTime' ||
      n === 'PlainYearMonth' || n === 'PlainMonthDay' ||
      n === 'ZonedDateTime' || n === 'Instant';
  }

  function _toDateTimeFormattable(value) {
    if (_isTemporalObject(value)) return value;
    if (value instanceof Date) return value.getTime();
    return Number(value);
  }

  function _temporalToEpochMs(v) {
    var n = _temporalTypeName(v);
    if (n === 'Instant' && typeof v.epochMilliseconds === 'number') {
      return v.epochMilliseconds;
    }
    if (n === 'ZonedDateTime') {
      if (typeof v.epochMilliseconds === 'number') return v.epochMilliseconds;
      if (typeof v.toInstant === 'function') {
        var inst = v.toInstant();
        if (inst && typeof inst.epochMilliseconds === 'number') return inst.epochMilliseconds;
      }
    }
    if (n === 'PlainDate' || n === 'PlainDateTime' || n === 'PlainYearMonth') {
      var y = v.year;
      var m = v.month;
      var d = n === 'PlainYearMonth' ? 1 : v.day;
      var h = typeof v.hour === 'number' ? v.hour : 0;
      var mi = typeof v.minute === 'number' ? v.minute : 0;
      var s = typeof v.second === 'number' ? v.second : 0;
      var ms = typeof v.millisecond === 'number' ? v.millisecond : 0;
      return Date.UTC(y, m - 1, d, h, mi, s, ms);
    }
    if (n === 'PlainMonthDay') {
      return Date.UTC(1972, v.month - 1, v.day, 0, 0, 0, 0);
    }
    if (n === 'PlainTime') {
      var now = new Date();
      return Date.UTC(
        now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(),
        v.hour || 0, v.minute || 0, v.second || 0, v.millisecond || 0
      );
    }
    throw new TypeError('Temporal value not supported');
  }

  function _formattableToEpochMs(v, label) {
    if (_isTemporalObject(v)) return _temporalToEpochMs(v);
    var ms = v;
    if (Number.isNaN(ms) || ms === Infinity || ms === -Infinity) {
      throw new RangeError(label || 'Invalid time value');
    }
    return ms;
  }

  function _dtfToEpochMs(date, label) {
    if (date === undefined) return Date.now();
    return _formattableToEpochMs(_toDateTimeFormattable(date), label);
  }

  var _dtfMethods = {
    format(date) {
      var dtf = _requireDateTimeFormat(this);
      _dtfApplyTz(dtf.__timeZone);
      return icu.formatDateTime(
        dtf.__locale, dtf.__dateStyle, dtf.__timeStyle, _dtfToEpochMs(date)
      );
    },
    formatToParts(date) {
      var dtf = _requireDateTimeFormat(this);
      var ms = _dtfToEpochMs(date);
      _dtfApplyTz(dtf.__timeZone);
      if (typeof icu.formatDateTimeParts === 'function') {
        var enc = icu.formatDateTimeParts(
          dtf.__locale, dtf.__dateStyle, dtf.__timeStyle, ms
        );
        var parts = _parseIcuParts(enc);
        if (parts.length) return parts;
      }
      return [{ type: 'literal', value: _dtfMethods.format.call(dtf, date) }];
    },
    formatRange(startDate, endDate) {
      var dtf = _requireDateTimeFormat(this);
      if (startDate === undefined || endDate === undefined) {
        throw new TypeError('formatRange requires defined start and end');
      }
      var x = _toDateTimeFormattable(startDate);
      var y = _toDateTimeFormattable(endDate);
      if (_isTemporalObject(x) || _isTemporalObject(y)) {
        if (!_isTemporalObject(x) || !_isTemporalObject(y) ||
            _temporalTypeName(x) !== _temporalTypeName(y)) {
          throw new TypeError('Cannot format range of different Temporal types');
        }
      }
      var a = _formattableToEpochMs(x, 'Invalid start time');
      var b = _formattableToEpochMs(y, 'Invalid end time');
      _dtfApplyTz(dtf.__timeZone);
      if (typeof icu.formatDateTimeRange === 'function') {
        return icu.formatDateTimeRange(
          dtf.__locale, dtf.__dateStyle, dtf.__timeStyle, a, b
        );
      }
      var sa = icu.formatDateTime(dtf.__locale, dtf.__dateStyle, dtf.__timeStyle, a);
      var sb = icu.formatDateTime(dtf.__locale, dtf.__dateStyle, dtf.__timeStyle, b);
      return sa === sb ? sa : sa + '\u2013' + sb;
    },
    formatRangeToParts(startDate, endDate) {
      var dtf = _requireDateTimeFormat(this);
      return [{ type: 'literal', value: _dtfMethods.formatRange.call(dtf, startDate, endDate) }];
    },
    resolvedOptions() {
      var dtf = _requireDateTimeFormat(this);
      return {
        locale: dtf.__locale,
        calendar: 'gregory',
        numberingSystem: 'latn',
        timeZone: dtf.__timeZone || 'UTC',
        dateStyle: dtf.__dateStyle,
        timeStyle: dtf.__timeStyle
      };
    }
  };

  DateTimeFormat.prototype.format = _dtfMethods.format;
  Object.defineProperty(DateTimeFormat.prototype, 'formatToParts', {
    value: _installMeta(_dtfMethods.formatToParts, 'formatToParts', 1),
    writable: true,
    enumerable: false,
    configurable: true
  });
  Object.defineProperty(DateTimeFormat.prototype, 'formatRange', {
    value: _installMeta(_dtfMethods.formatRange, 'formatRange', 2),
    writable: true,
    enumerable: false,
    configurable: true
  });
  Object.defineProperty(DateTimeFormat.prototype, 'formatRangeToParts', {
    value: _installMeta(_dtfMethods.formatRangeToParts, 'formatRangeToParts', 2),
    writable: true,
    enumerable: false,
    configurable: true
  });
  DateTimeFormat.prototype.resolvedOptions = _dtfMethods.resolvedOptions;

  // ── PluralRules ───────────────────────────────────────────────────────────

  function PluralRules(locales, options) {
    if (!(this instanceof PluralRules)) return new PluralRules(locales, options);
    this.__locale = _toLocale(locales);
    this.__type = _opt(options, 'type', 'cardinal');
  }
  _installMeta(PluralRules, 'PluralRules', 0);
  PluralRules.supportedLocalesOf = supportedLocalesOf;
  PluralRules.prototype.select = function (value) {
    return icu.pluralSelect(this.__locale, this.__type, Number(value)) || 'other';
  };
  PluralRules.prototype.resolvedOptions = function () {
    return { locale: this.__locale, type: this.__type };
  };

  // ── Collator ──────────────────────────────────────────────────────────────

  function _collatorResolvedLocale(
    locale, numeric, caseFirst, collation,
    optsNumeric, optsCaseFirst, optsCollation
  ) {
    var parts = _splitExtensions(locale);
    var parsed = _parseUnicodeKeywords(parts.exts.u || []);
    var keywords = parsed.keywords;
    // Resolved locale reflects a unicode key only when it agrees with options.
    // Conflicting option overrides drop the key from the locale tag (ECMA-402).
    var extKn = Object.prototype.hasOwnProperty.call(keywords, 'kn')
      ? (keywords.kn === 'true' || keywords.kn === '')
      : null;
    if (optsNumeric !== undefined) {
      if (extKn === numeric) {
        if (numeric) keywords.kn = '';
        else delete keywords.kn;
      } else {
        delete keywords.kn;
      }
    } else if (numeric) {
      keywords.kn = '';
    } else {
      delete keywords.kn;
    }

    var extKf = Object.prototype.hasOwnProperty.call(keywords, 'kf')
      ? (keywords.kf === '' ? 'true' : keywords.kf)
      : null;
    if (optsCaseFirst !== undefined) {
      if (extKf === caseFirst) {
        if (caseFirst === 'false') delete keywords.kf;
        else keywords.kf = String(caseFirst);
      } else {
        delete keywords.kf;
      }
    } else if (caseFirst && caseFirst !== 'false') {
      keywords.kf = String(caseFirst);
    } else {
      delete keywords.kf;
    }

    var extCo = Object.prototype.hasOwnProperty.call(keywords, 'co')
      ? keywords.co
      : null;
    if (optsCollation !== undefined) {
      if (extCo === collation) {
        if (collation && collation !== 'default') keywords.co = String(collation);
        else delete keywords.co;
      } else {
        delete keywords.co;
      }
    } else if (collation && collation !== 'default' && collation !== 'search' &&
               collation !== 'standard') {
      keywords.co = String(collation);
    } else {
      delete keywords.co;
    }
    delete keywords.ka;
    var localeNoU = parts.base;
    var otherSingletons = Object.keys(parts.exts).filter(function (s) {
      return s !== 'u';
    }).sort();
    for (var oi = 0; oi < otherSingletons.length; oi++) {
      var os = otherSingletons[oi];
      localeNoU += '-' + os + '-' + parts.exts[os].join('-');
    }
    var extension = _buildUnicodeExtension(parsed.attrs, keywords);
    return _insertExtension(localeNoU, extension, parts.privateUse);
  }

  function Collator(locales, options) {
    if (!(this instanceof Collator)) return new Collator(locales, options);
    var loc = _toLocale(locales);
    this.__locale = loc;
    this.__sensitivity = _opt(options, 'sensitivity', 'variant');
    this.__usage = _opt(options, 'usage', 'sort');

    var parts = _splitExtensions(loc);
    var kw = _parseUnicodeKeywords(parts.exts.u || []).keywords;
    var lang = _asciiLower(String(parts.base || loc).split('-')[0] || '');

    // ignorePunctuation: options override; Thai defaults to true (ECMA-402).
    if (options != null && typeof options === 'object' &&
        options.ignorePunctuation !== undefined &&
        options.ignorePunctuation !== null) {
      this.__ignorePunctuation = Boolean(options.ignorePunctuation);
    } else {
      this.__ignorePunctuation = (lang === 'th');
    }

    // numeric: options override locale extension; default false
    if (options != null && typeof options === 'object' &&
        options.numeric !== undefined && options.numeric !== null) {
      this.__numeric = Boolean(options.numeric);
    } else if (Object.prototype.hasOwnProperty.call(kw, 'kn')) {
      this.__numeric = (kw.kn === 'true' || kw.kn === '');
    } else {
      this.__numeric = false;
    }

    // caseFirst: options override locale extension; default "false"
    var cf = undefined;
    if (options != null && typeof options === 'object') {
      cf = _getOption(options, 'caseFirst', 'string',
        ['upper', 'lower', 'false'], undefined);
    }
    if (cf !== undefined) {
      this.__caseFirst = cf;
    } else if (Object.prototype.hasOwnProperty.call(kw, 'kf')) {
      this.__caseFirst = kw.kf === '' ? 'true' : kw.kf;
    } else {
      this.__caseFirst = 'false';
    }

    // collation: options override locale `co`; drop search/standard.
    var colOpt = undefined;
    if (options != null && typeof options === 'object') {
      colOpt = _getOption(options, 'collation', 'string', undefined, undefined);
    }
    if (colOpt !== undefined) {
      this.__collation = colOpt;
    } else if (Object.prototype.hasOwnProperty.call(kw, 'co') &&
               kw.co !== 'search' && kw.co !== 'standard') {
      this.__collation = kw.co;
    } else {
      this.__collation = 'default';
    }

    var optsNumeric = (options != null && typeof options === 'object' &&
      options.numeric !== undefined && options.numeric !== null)
      ? this.__numeric : undefined;
    this.__locale = _collatorResolvedLocale(
      loc, this.__numeric, this.__caseFirst, this.__collation,
      optsNumeric, cf, colOpt
    );
    // Compare locale always carries the effective kn/kf/co for ICU.
    var compareBase = _collatorResolvedLocale(
      loc, this.__numeric, this.__caseFirst, this.__collation,
      undefined, undefined, undefined
    );
    // Force effective keywords onto the compare tag even when resolved locale
    // dropped a conflicting unicode extension.
    if (this.__numeric) {
      if (compareBase.indexOf('-u-') < 0) compareBase += '-u-kn';
      else if (compareBase.indexOf('-kn') < 0) compareBase += '-kn';
    }
    if (this.__caseFirst && this.__caseFirst !== 'false') {
      if (compareBase.indexOf('-u-') < 0) {
        compareBase += '-u-kf-' + this.__caseFirst;
      } else if (compareBase.indexOf('-kf') < 0) {
        compareBase += '-kf-' + this.__caseFirst;
      }
    }
    if (this.__collation && this.__collation !== 'default') {
      if (compareBase.indexOf('-u-') < 0) {
        compareBase += '-u-co-' + this.__collation;
      } else if (compareBase.indexOf('-co') < 0) {
        compareBase += '-co-' + this.__collation;
      }
    }
    // UTS #35 colAlternate: shifted ignores punctuation; noignore forces it on
    // (needed for Thai where the default collator ignores spaces).
    var ka = this.__ignorePunctuation ? 'shifted' : 'noignore';
    if (compareBase.indexOf('-u-') < 0) compareBase += '-u-ka-' + ka;
    else if (compareBase.indexOf('-ka') < 0) compareBase += '-ka-' + ka;
    this.__compareLocale = compareBase;
  }
  _installMeta(Collator, 'Collator', 0);
  Collator.supportedLocalesOf = supportedLocalesOf;
  // ECMA-402: `compare` is an accessor that returns a bound compare function.
  var _collatorCompareGetter = function () {
    if (this == null || typeof this !== 'object' ||
        this.__compareLocale === undefined && this.__locale === undefined) {
      throw new TypeError(
        'Intl.Collator.prototype.compare called on incompatible receiver'
      );
    }
    if (typeof this.__boundCompare === 'function') return this.__boundCompare;
    var coll = this;
    var fn = function (a, b) {
      var r = icu.compare(
        coll.__compareLocale || coll.__locale,
        coll.__sensitivity || 'variant',
        String(a),
        String(b)
      );
      if (r < -1 || r > 1) return 0;
      return r | 0;
    };
    // Built-in compare functions have anonymous name and no .prototype.
    Object.defineProperty(fn, 'name', {
      value: '', writable: false, enumerable: false, configurable: true
    });
    Object.defineProperty(fn, 'length', {
      value: 2, writable: false, enumerable: false, configurable: true
    });
    Object.defineProperty(fn, 'prototype', {
      value: undefined, writable: false, enumerable: false, configurable: false
    });
    coll.__boundCompare = fn;
    return fn;
  };
  Object.defineProperty(_collatorCompareGetter, 'name', {
    value: 'get compare', writable: false, enumerable: false, configurable: true
  });
  Object.defineProperty(Collator.prototype, 'compare', {
    get: _collatorCompareGetter,
    enumerable: false,
    configurable: true
  });
  var _collatorResolvedOptions = function () {
    if (this == null || typeof this !== 'object' ||
        this.__compareLocale === undefined && this.__locale === undefined) {
      throw new TypeError(
        'Intl.Collator.prototype.resolvedOptions called on incompatible receiver'
      );
    }
    return {
      locale: this.__locale,
      usage: this.__usage || 'sort',
      sensitivity: this.__sensitivity,
      ignorePunctuation: !!this.__ignorePunctuation,
      collation: this.__collation || 'default',
      numeric: !!this.__numeric,
      caseFirst: this.__caseFirst || 'false'
    };
  };
  Object.defineProperty(_collatorResolvedOptions, 'name', {
    value: 'resolvedOptions', writable: false, enumerable: false, configurable: true
  });
  Object.defineProperty(_collatorResolvedOptions, 'prototype', {
    value: undefined, writable: false, enumerable: false, configurable: false
  });
  Object.defineProperty(Collator.prototype, 'resolvedOptions', {
    value: _collatorResolvedOptions,
    writable: true,
    enumerable: false,
    configurable: true
  });

  // ── DisplayNames ──────────────────────────────────────────────────────────

  function DisplayNames(locales, options) {
    if (!(this instanceof DisplayNames)) return new DisplayNames(locales, options);
    if (options == null || typeof options !== 'object' || options.type == null) {
      throw new TypeError('Intl.DisplayNames requires options.type');
    }
    this.__locale = _toLocale(locales);
    this.__type = String(options.type);
    this.__style = _opt(options, 'style', 'long');
  }
  _installMeta(DisplayNames, 'DisplayNames', 2);
  DisplayNames.supportedLocalesOf = supportedLocalesOf;
  DisplayNames.prototype.of = function (code) {
    return icu.displayName(this.__locale, this.__type, String(code), this.__style);
  };
  DisplayNames.prototype.resolvedOptions = function () {
    return { locale: this.__locale, style: this.__style, type: this.__type };
  };

  // ── ListFormat ────────────────────────────────────────────────────────────

  function ListFormat(locales, options) {
    if (!(this instanceof ListFormat)) return new ListFormat(locales, options);
    this.__locale = _toLocale(locales);
    this.__type = _opt(options, 'type', 'conjunction');
    this.__style = _opt(options, 'style', 'long');
  }
  _installMeta(ListFormat, 'ListFormat', 0);
  ListFormat.supportedLocalesOf = supportedLocalesOf;
  ListFormat.prototype.format = function (list) {
    var parts = [];
    if (list != null && typeof list.length === 'number') {
      for (var i = 0; i < list.length; i++) parts.push(String(list[i]));
    }
    var joined = parts.join('\x1f');
    return icu.listFormat(this.__locale, this.__type, this.__style, joined);
  };
  ListFormat.prototype.formatToParts = function (list) {
    return [{ type: 'literal', value: this.format(list) }];
  };
  ListFormat.prototype.resolvedOptions = function () {
    return { locale: this.__locale, type: this.__type, style: this.__style };
  };

  // ── RelativeTimeFormat ────────────────────────────────────────────────────

  function RelativeTimeFormat(locales, options) {
    if (!(this instanceof RelativeTimeFormat)) {
      return new RelativeTimeFormat(locales, options);
    }
    this.__locale = _toLocale(locales);
    this.__numeric = _opt(options, 'numeric', 'always');
    this.__style = _opt(options, 'style', 'long');
  }
  _installMeta(RelativeTimeFormat, 'RelativeTimeFormat', 0);
  RelativeTimeFormat.supportedLocalesOf = supportedLocalesOf;
  var _rtfUnits = {
    year: 1, years: 1, quarter: 1, quarters: 1, month: 1, months: 1,
    week: 1, weeks: 1, day: 1, days: 1, hour: 1, hours: 1,
    minute: 1, minutes: 1, second: 1, seconds: 1
  };
  RelativeTimeFormat.prototype.format = function (value, unit) {
    var u = String(unit);
    if (!Object.prototype.hasOwnProperty.call(_rtfUnits, u)) {
      throw new RangeError('Invalid unit argument for format() "' + u + '"');
    }
    var n = Number(value);
    if (n !== n || n === Infinity || n === -Infinity) {
      throw new RangeError('Value need to be finite number for format()');
    }
    return icu.relativeTime(this.__locale, this.__numeric, u, n);
  };
  RelativeTimeFormat.prototype.formatToParts = function (value, unit) {
    return [{ type: 'literal', value: this.format(value, unit) }];
  };
  RelativeTimeFormat.prototype.resolvedOptions = function () {
    return {
      locale: this.__locale,
      style: this.__style,
      numeric: this.__numeric,
      numberingSystem: 'latn'
    };
  };

  // ── Segmenter ─────────────────────────────────────────────────────────────

  function Segmenter(locales, options) {
    if (!(this instanceof Segmenter)) return new Segmenter(locales, options);
    this.__locale = _toLocale(locales);
    var g = _opt(options, 'granularity', 'grapheme');
    this.__granularity = g;
    this.__granCode = g === 'word' ? 1 : (g === 'sentence' ? 2 : 0);
  }
  _installMeta(Segmenter, 'Segmenter', 0);
  Segmenter.supportedLocalesOf = supportedLocalesOf;

  function Segments(seg, input) {
    this.__seg = seg;
    this.__input = String(input);
  }
  Segments.prototype[Symbol.iterator] = function () {
    var offsetsStr = icu.segmenterBreak(
      this.__seg.__locale, this.__seg.__granCode, this.__input
    );
    var offs = [];
    if (offsetsStr) {
      var parts = String(offsetsStr).split(',');
      for (var i = 0; i < parts.length; i++) {
        if (parts[i] !== '') offs.push(parts[i] | 0);
      }
    }
    var input = this.__input;
    var idx = 0;
    return {
      next: function () {
        if (idx + 1 >= offs.length) return { done: true, value: undefined };
        var start = offs[idx];
        var end = offs[idx + 1];
        idx++;
        return {
          done: false,
          value: {
            segment: input.substring(start, end),
            index: start,
            input: input
          }
        };
      }
    };
  };
  Segments.prototype.containing = function (index) {
    var i = index | 0;
    var it = this[Symbol.iterator]();
    var cur = it.next();
    while (!cur.done) {
      var v = cur.value;
      if (i >= v.index && i < v.index + v.segment.length) return v;
      cur = it.next();
    }
    return undefined;
  };

  Segmenter.prototype.segment = function (input) {
    return new Segments(this, input);
  };
  Segmenter.prototype.resolvedOptions = function () {
    return { locale: this.__locale, granularity: this.__granularity };
  };

  // ── DurationFormat (reasonable stub) ──────────────────────────────────────

  function DurationFormat(locales, options) {
    if (!(this instanceof DurationFormat)) return new DurationFormat(locales, options);
    this.__locale = _toLocale(locales);
    this.__style = _opt(options, 'style', 'short');
  }
  _installMeta(DurationFormat, 'DurationFormat', 0);
  DurationFormat.supportedLocalesOf = supportedLocalesOf;
  DurationFormat.prototype.format = function (duration) {
    if (duration == null || typeof duration !== 'object') {
      throw new TypeError('DurationFormat.format requires a duration record');
    }
    var units = [
      'years', 'months', 'weeks', 'days',
      'hours', 'minutes', 'seconds',
      'milliseconds', 'microseconds', 'nanoseconds'
    ];
    var parts = [];
    for (var i = 0; i < units.length; i++) {
      var u = units[i];
      var v = duration[u];
      if (v !== undefined && v !== 0 && v !== 0n) {
        parts.push(String(v) + ' ' + u);
      }
    }
    if (parts.length === 0) return '0 seconds';
    try {
      return new ListFormat(this.__locale, { type: 'unit', style: this.__style }).format(parts);
    } catch (_) {
      return parts.join(', ');
    }
  };
  DurationFormat.prototype.resolvedOptions = function () {
    return { locale: this.__locale, style: this.__style };
  };

  // ── Assemble Intl ─────────────────────────────────────────────────────────

  var IntlObj = {};
  function _installIntlProp(name, value) {
    Object.defineProperty(IntlObj, name, {
      value: value,
      writable: true,
      enumerable: false,
      configurable: true
    });
  }
  _installIntlProp('getCanonicalLocales', getCanonicalLocales);
  _installIntlProp('Locale', Locale);
  _installIntlProp('NumberFormat', NumberFormat);
  _installIntlProp('DateTimeFormat', DateTimeFormat);
  _installIntlProp('PluralRules', PluralRules);
  _installIntlProp('Collator', Collator);
  _installIntlProp('DisplayNames', DisplayNames);
  _installIntlProp('ListFormat', ListFormat);
  _installIntlProp('RelativeTimeFormat', RelativeTimeFormat);
  _installIntlProp('Segmenter', Segmenter);
  _installIntlProp('DurationFormat', DurationFormat);

  Object.defineProperty(globalThis, 'Intl', {
    value: IntlObj,
    writable: true,
    enumerable: false,
    configurable: true
  });
})();
