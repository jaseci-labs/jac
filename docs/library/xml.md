---
description: The native XML modules - xml.etree.ElementTree's trees, xml.sax's events, xml.dom's documents (minidom, pulldom and the builders), xml.parsers.expat (pyexpat), the parser under them all, and plistlib's property lists - with what each has and how they differ from CPython's.
keywords: xml, xml.etree, xml.etree.ElementTree, ElementTree, xml.etree.ElementTree.Element, xml.etree.ElementTree.fromstring, xml.etree.ElementTree.tostring, xml.etree.ElementTree.ParseError, xml.etree.ElementTree.iterparse, xml.etree.ElementPath, xml.etree.ElementInclude, xml.sax, xml.sax.ContentHandler, xml.sax.parseString, xml.sax.saxutils, xml.sax.handler, xml.sax.xmlreader, xml.dom, xml.dom.minidom, minidom, xml.dom.minidom.parseString, xml.dom.minidom.Document, xml.dom.minidom.Element, xml.dom.pulldom, pulldom, xml.dom.expatbuilder, xml.dom.xmlbuilder, xml.dom.domreg, xml.dom.minicompat, xml.dom.NodeFilter, xml.dom.DOMException, DOM, getElementsByTagName, toprettyxml, xml.parsers.expat, pyexpat, expat, ParserCreate, plistlib, plistlib.loads, plistlib.dumps, property list, XML
---
# xml and plistlib

The XML modules are native, each with the names and behavior of CPython 3.15's (see
[The library](index.md), `jac docs library`). The parser under all of them is expat itself,
CPython's copy of it, compiled into the program.

| Module | What it has |
|---|---|
| `xml.etree.ElementTree` | A document as a tree of `Element`s: parsing, searching, changing, serializing |
| `xml.etree.ElementPath`, `xml.etree.ElementInclude` | The paths `find` and `findall` take; XInclude |
| `xml.sax`, `xml.sax.handler`, `xml.sax.xmlreader`, `xml.sax.expatreader`, `xml.sax.saxutils` | A document as events given to a handler; `escape`, `unescape`, `quoteattr`, `XMLGenerator` |
| `xml.dom`, `xml.dom.minidom`, `xml.dom.pulldom`, `xml.dom.expatbuilder`, `xml.dom.xmlbuilder`, `xml.dom.domreg`, `xml.dom.minicompat`, `xml.dom.NodeFilter` | A document as the W3C's DOM: nodes of a class each, built whole, on demand, or by a builder with options |
| `xml.parsers.expat`, `pyexpat` | expat's own interface: a parser and its handlers |
| `xml` | `is_valid_name`, `is_valid_text` |
| `plistlib` | Apple's property lists, XML and binary |

```jac
import plistlib;
import xml.sax;
import xml.etree.ElementTree as ET;
import xml.parsers.expat;
import from xml.etree.ElementTree { fromstring }
import from xml.sax.saxutils { escape, quoteattr }
import from xml.sax.xmlreader { AttributesImpl }

glob DOC: str = '<shelf owner="Ada"><book id="b1" year="1843"><title>Notes</title></book>'
         '<book id="b2" year="1936"><title>On Computable Numbers</title></book></shelf>',
     opened: list[str] = [];

class Titles(xml.sax.ContentHandler) {
    has inside: bool = False,
        found: list[str] = [];

    override def startElement(name: str, attrs: AttributesImpl) -> None {
        self.inside = name == "title";
    }

    override def characters(content: str) -> None {
        if self.inside {
            self.found.append(content);
        }
    }

    override def endElement(name: str) -> None {
        self.inside = False;
    }
}

def started(name: str, attrs: dict[str, str]) -> None {
    opened.append(name + str(sorted(attrs.keys())));
}

with entry {
    shelf = fromstring(DOC);
    print(shelf.tag, shelf.attrib, len(shelf));
    for book in shelf.findall("book") {
        print(book.get("id"), book.findtext("title"));
    }
    print([b.get("id") for b in shelf.iterfind(".//book[@year='1936']")]);
    note = ET.SubElement(shelf[0], "note", {"lang": "en"});
    note.text = "x < y & z";
    print(ET.tostring(shelf[0], encoding="unicode"));
    try {
        fromstring("<a><b></a>");
    } except ET.ParseError as e {
        print("ParseError:", e, e.position);
    }
    handler = Titles();
    xml.sax.parseString(DOC.encode(), handler);
    print(handler.found, escape("a < b"), quoteattr('say "hi"'));
    parser = xml.parsers.expat.ParserCreate();
    parser.StartElementHandler = started;
    parser.Parse(DOC, True);
    print(opened);
    data = plistlib.dumps({"name": "demo", "ports": [80, 443], "debug": False});
    print(data.decode().split("\n")[3:6]);
    print(plistlib.loads(data), plistlib.loads(plistlib.dumps([1, 2.5], fmt=plistlib.FMT_BINARY)));
}
```

```output
shelf {'owner': 'Ada'} 2
b1 Notes
b2 On Computable Numbers
['b2']
<book id="b1" year="1843"><title>Notes</title><note lang="en">x &lt; y &amp; z</note></book>
ParseError: mismatched tag: line 1, column 8 (1, 8)
['Notes', 'On Computable Numbers'] a &lt; b 'say "hi"'
["shelf['owner']", "book['id', 'year']", 'title[]', "book['id', 'year']", 'title[]']
['<dict>', '\t<key>debug</key>', '\t<false/>']
{'debug': False, 'name': 'demo', 'ports': [80, 443]} [1, 2.5]
```

## xml.etree.ElementTree

| Name | What it is |
|---|---|
| `Element(tag, attrib={}, **extra)`, `SubElement(parent, tag, attrib={}, **extra)` | A node: `tag`, `attrib`, `text`, `tail`, its children by index and slice, `append`, `extend`, `insert`, `remove`, `clear`, `get`, `set`, `keys`, `items`, `iter`, `itertext`, `find`, `findall`, `findtext`, `iterfind` |
| `fromstring(text)`, `XML(text)`, `fromstringlist`, `XMLID`, `parse(source)` | A tree from text, or an `ElementTree` from a file |
| `ElementTree(element=None, file=None)` | A whole document: `getroot`, `parse`, `write(file, encoding, xml_declaration, default_namespace, method, short_empty_elements)`, and the searches |
| `tostring`, `tostringlist`, `dump`, `indent`, `canonicalize`, `C14NWriterTarget` | A tree as XML, HTML or text; pretty printing; C14N 2.0 |
| `iterparse(source, events=None)`, `XMLPullParser(events=None)` | The parse reported as it goes, element by element |
| `XMLParser(target=None, encoding=None)`, `TreeBuilder` | The parser `fromstring` uses, and what it feeds |
| `Comment`, `ProcessingInstruction` (`PI`), `QName`, `register_namespace`, `iselement` | As CPython's |
| `ParseError` | A `SyntaxError` with `code` and `position`, a line and a column |

A path is the limited XPath of CPython's: tags, `*`, `.`, `..`, `//`, `[@attrib]`,
`[@attrib='value']`, `[tag]`, `[tag='text']`, `[position]`, and `{namespace}tag` with a
`namespaces` mapping.

## xml.sax

`xml.sax.parse(source, handler)` and `parseString(bytes, handler)` read a document and call the
handler's methods for what they find; `make_parser()` gives the reader itself, an
`xml.sax.expatreader.ExpatParser`, which also takes a document in pieces (`feed`, `close`), a
`DTDHandler`, an `EntityResolver`, an `ErrorHandler` and a `LexicalHandler`, namespaces
(`feature_namespaces`) and a locator. A handler derives from the class whose events it takes
(`ContentHandler`, `ErrorHandler`, ...), and an override takes what the method it replaces takes:
`startElement(name: str, attrs: AttributesImpl)`. `SAXException`, `SAXParseException`,
`SAXNotRecognizedException`, `SAXNotSupportedException` and `SAXReaderNotAvailable` are the
errors. `xml.sax.saxutils` has `escape`, `unescape`, `quoteattr`, `XMLGenerator` (a handler that
writes the document back), `XMLFilterBase` and `prepare_input_source`.

## xml.dom

`xml.dom.minidom` holds a document as a tree of nodes, each of its own class: `Document`,
`Element`, `Attr`, `Text`, `Comment`, `CDATASection`, `ProcessingInstruction`, `DocumentType`,
`DocumentFragment`, `Entity` and `Notation`, all `Node`s. `parse(file)` and
`parseString(string)` build one with expat (or with the SAX `parser` given), and a `Document`
makes new nodes for itself.

```jac
import io;
import xml.dom;
import xml.dom.expatbuilder as expatbuilder;
import xml.dom.minidom as minidom;
import xml.dom.pulldom as pulldom;
import xml.dom.xmlbuilder as xmlbuilder;
import xml.parsers.expat;

glob DOC: str = '<shelf owner="Ada"><book id="b1"><title>Notes</title></book>'
    '<book id="b2"><title>On Computable Numbers</title></book></shelf>';

with entry {
    doc = minidom.parseString(DOC);
    shelf = doc.documentElement;
    print(shelf.tagName, shelf.getAttribute("owner"), shelf.childNodes.length);
    for book in doc.getElementsByTagName("book") {
        title = book.getElementsByTagName("title")[0];
        print(book.getAttribute("id"), title.firstChild.data, title.parentNode is book);
    }
    note = doc.createElement("note");
    note.setAttribute("lang", "en");
    note.appendChild(doc.createTextNode("x < y & z"));
    first = shelf.firstChild;
    first.appendChild(note);
    print(first.toxml());
    if isinstance(first, minidom.Element) {
        print(first.tagName, first.attributes["id"].value, first.lastChild is note);
    }
    shelf.removeChild(shelf.lastChild);
    print(doc.toprettyxml(indent="  "), end="");
    try {
        shelf.removeChild(doc.createElement("stranger"));
    } except xml.dom.NotFoundErr as e {
        print("NotFoundErr", e.code == xml.dom.NOT_FOUND_ERR, isinstance(e, xml.dom.DOMException));
    }
    try {
        minidom.parseString("<a><b></a>");
    } except xml.parsers.expat.ExpatError as e {
        print("ExpatError:", e);
    }
    stream = pulldom.parseString(DOC);
    for (event, found) in stream {
        if event == pulldom.START_ELEMENT and found.nodeName == "book" {
            stream.expandNode(found);
            print(found.toxml());
        }
    }
    fragment = expatbuilder.parseFragmentString("<note>new</note> and text", shelf);
    print([n.toxml() for n in fragment.childNodes], fragment.ownerDocument is doc);
    builder = xmlbuilder.DOMBuilder();
    builder.setFeature("comments", False);
    source = xmlbuilder.DOMInputSource();
    source.byteStream = io.BytesIO(b"<a><!-- dropped --><b/></a>");
    print(builder.parse(source).toxml());
}
```

```output
shelf Ada 2
b1 Notes True
b2 On Computable Numbers True
<book id="b1"><title>Notes</title><note lang="en">x &lt; y &amp; z</note></book>
book b1 True
<?xml version="1.0" ?>
<shelf owner="Ada">
  <book id="b1">
    <title>Notes</title>
    <note lang="en">x &lt; y &amp; z</note>
  </book>
</shelf>
NotFoundErr True True
ExpatError: mismatched tag: line 1, column 8
<book id="b1"><title>Notes</title></book>
<book id="b2"><title>On Computable Numbers</title></book>
['<note>new</note>', ' and text'] True
<?xml version="1.0" ?><a><b/></a>
```

| Module | What it has |
|---|---|
| `xml.dom.minidom` | `parse(file, parser=None, bufsize=None)`, `parseString(string, parser=None)`, `getDOMImplementation(features=None)`, and the node classes. A node has `nodeType`, `nodeName`, `nodeValue`, `parentNode`, `childNodes`, `firstChild`, `lastChild`, `previousSibling`, `nextSibling`, `ownerDocument`, `appendChild`, `insertBefore`, `removeChild`, `replaceChild`, `cloneNode(deep)`, `normalize`, `toxml`, `toprettyxml(indent, newl, encoding, standalone)`, `writexml`, `unlink`, `with`; an `Element` its `tagName`, `attributes`, the `getAttribute`, `setAttribute`, `removeAttribute` and `hasAttribute` families with their `NS` and `Node` forms, `getElementsByTagName` and `getElementsByTagNameNS`; a `Document` its `documentElement`, `doctype`, `createElement`, `createTextNode`, `createComment`, `createAttribute` and the rest, `getElementById`, `importNode` and `renameNode` |
| `xml.dom` | The `Node` type constants, `DOMException` and its classes (`NotFoundErr`, `HierarchyRequestErr`, `NamespaceErr`, ...) with their `code`s, the namespace constants, `UserDataHandler`, `getDOMImplementation` and `registerDOMImplementation` |
| `xml.dom.pulldom` | `parse(stream_or_string, parser=None, bufsize=None)` and `parseString(string, parser=None)` give a `DOMEventStream` of `(event, node)` pairs read as they are asked for; `expandNode(node)` builds the tree under one, and the rest of the document is never built. `PullDOM` and `SAX2DOM` are the SAX handlers under it |
| `xml.dom.expatbuilder` | What `minidom.parse` uses: `parse`, `parseString`, `parseFragment`, `parseFragmentString` (a fragment in the context of a node), `makeBuilder(options)`, `ExpatBuilder`, `ExpatBuilderNS`, `FragmentBuilder` and the filter classes, and `theDOMImplementation`, the implementation its documents are made with, which is minidom's |
| `xml.dom.xmlbuilder` | The DOM's Load and Save: `DOMBuilder` with `setFeature`, `getFeature`, `canSetFeature`, `supportsFeature`, `parse(input)`, `parseURI(uri)`, a `filter` and an `entityResolver`; `DOMInputSource`, `DOMEntityResolver`, `DOMBuilderFilter`, `Options` |
| `xml.dom.domreg`, `xml.dom.minicompat`, `xml.dom.NodeFilter` | The registry of implementations; `NodeList` and `EmptyNodeList`; the `NodeFilter` constants |

Malformed input raises `xml.parsers.expat.ExpatError`, and a change the DOM forbids one of
`xml.dom`'s exceptions. `toprettyxml` writes the text of an element that holds text only on
the element's line, as CPython's does.

## xml.parsers.expat

`ParserCreate(encoding=None, namespace_separator=None, intern=None)` makes a parser; a program
sets the handlers it wants (`StartElementHandler`, `EndElementHandler`, `CharacterDataHandler`,
`ProcessingInstructionHandler`, `CommentHandler`, `StartNamespaceDeclHandler`,
`ExternalEntityRefHandler`, ... every one expat has) and calls `Parse(data, isfinal=False)` or
`ParseFile(file)`. A handler that raises stops the parse, and `Parse` raises what it raised.
Malformed input raises `ExpatError` (`error`), with `code`, `lineno` and `offset`;
`xml.parsers.expat.errors` has the messages and codes, and `xml.parsers.expat.model` the content
model constants. `pyexpat` is the same module under its own name.

## plistlib

`load(fp)`, `loads(data)`, `dump(value, fp)` and `dumps(value)` read and write a property list:
a dict with str keys, a list, a str, an int, a float, a bool, `bytes`, a `datetime` or a `UID`.
`fmt=` is `FMT_XML` (the default for writing) or `FMT_BINARY`; reading finds the format itself.
`sort_keys=True`, `skipkeys=False`, `dict_type=dict` and `aware_datetime=False` are CPython's. A
file that is not a property list raises `InvalidFileException`, a `ValueError`.

## Differences from CPython

- **`ET.fromstring(text)` through the module does not compile yet** (E1023), nor does
  `ET.PI(...)`: they are second names, of `XML` and `ProcessingInstruction`. Import one by name,
  `import from xml.etree.ElementTree { fromstring }`, as above, or call `ET.XML(text)`.
- **`pyexpat.expat_CAPI` is left out** (E5142): it is a capsule of C function pointers for
  CPython's C extensions. A parser's `GetInputContext` is not written yet (E1030).
- **An int in a property list is 64 bits.** A wider one raises `OverflowError` as it is read,
  which the binary reader reports as `InvalidFileException`.
- **`xml.sax.make_parser` knows one driver**, `xml.sax.expatreader`. Another name in the list
  it is given is passed over, as a module that cannot be imported is in CPython.
- **A SAX handler's attributes object has untyped keys.** `AttributesImpl`'s and
  `AttributesNSImpl`'s names are `any`: a str name, or a `(uri, localname)` pair with
  namespaces on.
- **A DOM node read from the tree is typed `Node`.** `firstChild`, `parentNode` and their
  siblings give a `Node`, whatever the node is: `isinstance(n, minidom.Element)` tells which
  and gives the class's own members, as above. What is read out of a `NodeList`
  (`doc.getElementsByTagName("book")[0]`, or its iteration) is untyped, so its members are
  looked up as the program runs.
- **A `NodeList` is a sequence of its own**, where CPython's is a `list`: it has a list's
  indexing by position, iteration, `len` and the methods that change it, `item(i)` and
  `length`, but `isinstance(nodes, list)` is `False` and a slice of one is not taken (E1053).
  An `EmptyNodeList` is likewise not a `tuple`.
- **A read-only DOM property has no setter.** Assigning `nodes.length` or an `Attr`'s
  `localName` does not compile (E1005), where CPython raises `NoModificationAllowedErr`.
- **What CPython keeps as an attribute of a node's class is the node's own.**
  `doc.implementation` is there, and `minidom.Document.implementation` is not (E1030): write
  `minidom.getDOMImplementation()`.
- **`xml.dom.minicompat.defproperty` is left out** (E5142): it adds a property to a class as
  the program runs. `minicompat.StringTypes` is not there yet (E1145).

```jac
# expect: E5142
import pyexpat;

with entry {
    print(pyexpat.expat_CAPI);
}
```

## Where to go next

- HTML: `html.parser` in [Text modules](text.md).
- Other data formats: [json](json.md), [csv](csv.md).
- Every native module: [Standard-library modules](stdlib.md).
