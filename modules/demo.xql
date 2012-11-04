xquery version "3.0";

module namespace demo="http://exist-db.org/apps/demo";

import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
import module namespace test="http://exist-db.org/xquery/xqsuite" at "resource:org/exist/xquery/lib/xqsuite/xqsuite.xql";

declare namespace templates="http://exist-db.org/xquery/templates";

declare function demo:error-handler-test($node as node(), $model as map(*), $number as xs:string?) {
    if (exists($number)) then
        xs:int($number)
    else
        ()
};

declare function demo:link-to-home($node as node(), $model as map(*)) {
    <a href="{request:get-context-path()}/">{ 
        $node/@* except $node/@href,
        $node/node() 
    }</a>
};

declare function demo:run-tests($node as node(), $model as map(*)) {
    let $results := test:suite(inspect:module-functions(xs:anyURI("../examples/tests/shakespeare-tests.xql")))
    return
        test:to-html($results)
};

declare function demo:display-source($node as node(), $model as map(*), $lang as xs:string?, $type as xs:string?) {
    let $source := replace($node/string(), "^\s*(.*)\s*$", "$1")
    let $context := request:get-context-path()
    let $eXidePath := if (doc-available("/db/eXide/index.html")) then "apps/eXide" else "eXide"
    return
        <div xmlns="http://www.w3.org/1999/xhtml" class="source">
            <div class="code" data-language="{if ($lang) then $lang else 'xquery'}">{ $source }</div>
            <div class="toolbar">
                <a class="btn run" href="#" data-type="{if ($type) then $type else 'xml'}">Run</a>
                <a class="btn" href="{$context}/{$eXidePath}/index.html?snip={encode-for-uri($source)}" target="eXide"
                    title="Opens the code in eXide in new tab or existing tab if it is already open.">Edit</a>
                <div class="output"></div>
            </div>
        </div>
};