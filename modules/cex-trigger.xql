xquery version "3.0";

module namespace trigger="http://exist-db.org/xquery/trigger";

declare namespace xhtml="http://www.w3.org/1999/xhtml";

import module namespace content="http://exist-db.org/xquery/contentextraction"
    at "java:org.exist.contentextraction.xquery.ContentExtractionModule";

declare function trigger:do-index($fieldName as xs:string, $value as xs:string?, $path as xs:anyURI) {
    let $index :=
        <doc>
            <field name="{$fieldName}" store="yes">{$value}</field>
        </doc>
    let $null := ft:index($path, $index, false())
    return
        ()
};

declare function trigger:index-callback($root as element(), $path as xs:anyURI, $page as xs:integer?) {
    typeswitch ($root)
        case element(xhtml:meta) return
            ( trigger:do-index($root/@name, $root/@content/string(), $path), $page )
        case element(xhtml:title) return
            ( trigger:do-index("Title", $root/text(), $path), $page)
        default return
            if ($root/@class eq 'page') then
                let $page := if (empty($page)) then 1 else $page + 1
                return
                    ( trigger:do-index("page", concat("[[", $page, "]]", string-join($root//xhtml:p/string(), " ")), $path), $page )
            else
                $page
};

declare function trigger:index($uri as xs:anyURI) {
    if (util:is-binary-doc($uri)) then
        let $doc := util:binary-doc($uri)
        return
            if (ends-with($uri, ".pdf")) then
                let $callback := trigger:index-callback#3
                let $namespaces := 
                    <namespaces><namespace prefix="xhtml" uri="http://www.w3.org/1999/xhtml"/></namespaces>
                let $index :=
                    content:stream-content($doc, ("//xhtml:meta", "//xhtml:title", "//xhtml:div"), $callback, $namespaces, $uri)
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