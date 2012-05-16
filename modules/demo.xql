module namespace demo="http://exist-db.org/apps/demo";

import module namespace t="http://exist-db.org/apps/demo/shakespeare/tests" at "xmldb:exist:///db/demo/examples/tests/shakespeare-tests.xql";
import module namespace test="http://exist-db.org/xquery/xqsuite" at "xmldb:exist:///db/xqsuite.xql";

declare function demo:hello($node as node()*, $params as element(parameters)?, $model as item()*) {
    <span>Hello World!</span>
};

declare function demo:multiply($node as node()*, $params as element(parameters)?, $model as item()*) {
    let $p1 := $params/param[@name = "n1"]/@value
    let $p2 := $params/param[@name = "n2"]/@value
    return
        number($p1) * number($p2)
};

declare function demo:error-handler-test($node as node(), $params as element(parameters)?, $model as item()*) {
    let $input as xs:integer? := request:get-parameter("number", ())
    return
        $input            
};

declare function demo:link-to-home($node as node(), $params as element(parameters)?, $model as item()*) {
    <a href="{request:get-context-path()}/">{ 
        $node/@* except $node/@href,
        $node/node() 
    }</a>
};

declare function demo:run-tests($node as node(), $params as element(parameters)?, $model as item()*) {
    let $results := test:suite(util:list-functions("http://exist-db.org/apps/demo/shakespeare/tests"))
    return
        test:to-html($results)
};