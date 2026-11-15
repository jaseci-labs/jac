"""html.unescape / html.escape natively, compared line for line with Python's."""
import html;

glob SAMPLES: list[str] = [
         "plain text",
         "a &amp; b &lt;tag&gt; &quot;q&quot; &#39;s&#39;",
         "&nbsp;&copy;&reg;&hellip;&mdash;",
         "&#65;&#x42;&#X43;&#0;&#128;&#151;&#xD800;&#1114112;&#99999999999999999999;",
         "&amp &lt3 &notit; &notin; &NotEqualTilde; &unknownname; &;",
         "trailing &",
         "&#; &#x; &#xZZ; &# 12",
         "a&ampb &AMP; &AElig",
         "&thisnameiswaytoolongtobeanentityatall;"
     ];

with entry {
    for sample in SAMPLES {
        print(html.escape(html.unescape(sample)));
    }
    print(html.escape("<a href='x'>\"&\"</a>", quote=False));
}
