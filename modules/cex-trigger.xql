module namespace trigger="http://exist-db.org/xquery/trigger";

declare namespace xhtml="http://www.w3.org/1999/xhtml";

import module namespace content="http://exist-db.org/xquery/contentextraction"
    at "java:org.exist.contentextraction.xquery.ContentExtractionModule";

declare function trigger:index-callback($root as element(), $path as node(), $page as xs:integer?) {
    if ($root/@class eq 'page') then
        let $page := if (empty($page)) then 1 else $page + 1
        let $index :=
            <doc>
                <field name="page">[[{$page}]] {$root//xhtml:p/text()}</field>
            </doc>
        let $null := ft:index($path, $index, false())
        return
            $page
    else
        $page
};

declare function trigger:index($uri as xs:anyURI) {
    if (util:is-binary-doc($uri)) then
        let $doc := util:binary-doc($uri)
        return
            if (ends-with($uri, ".pdf")) then
                let $callback := util:function(xs:QName("trigger:index-callback"), 3)
                let $namespaces := 
                    <namespaces><namespace prefix="xhtml" uri="http://www.w3.org/1999/xhtml"/></namespaces>
                let $index :=
                    content:stream-content($doc, ("//xhtml:div"), $callback, $namespaces, $uri)
                return
                    ft:close()
            else
                let $content := content:get-metadata-and-content($doc)
                let $idxDoc :=
                    <doc>
                        <field name="page">{string-join($content//xhtml:body//text(), " ")}</field>
                    </doc>
                return
                    ft:index($uri, $idxDoc, true())
    else
        ()
};

declare function trigger:after-create-document($uri as xs:anyURI) {
    trigger:index($uri)
};

declare function trigger:after-update-document($uri as xs:anyURI) {
    trigger:index($uri)
};