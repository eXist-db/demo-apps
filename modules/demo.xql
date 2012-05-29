module namespace demo="http://exist-db.org/apps/demo";

import module namespace t="http://exist-db.org/apps/demo/shakespeare/tests" at "xmldb:exist:///db/demo/examples/tests/shakespeare-tests.xql";
import module namespace test="http://exist-db.org/xquery/xqsuite" at "xmldb:exist:///db/xqsuite.xql";

(:~
 : Simple templating function. A templating function needs to take two parameters at least.
 : It may return any sequence, which will be inserted into the output instead of $node.
 :
 : @param $node the HTML node which contained the class attribute which triggered this call.
 : @param $model an arbitrary sequence of items. Use this to pass required information between
 : tempate functions.
 :)
declare function demo:hello($node as node()*, $model as item()*) as element(span) {
    <span>Hello World!</span>
};

(:~
 : A templating function taking two additional parameters. The templating framework inspects
 : the function signature and tries to fill in additional parameters automatically. The value
 : to use is determined as follows:
 :
 : <ol>
 :    <li>if there's a (non-empty) request parameter with the same name as the variable, use it</li>
 :    <li>check for a parameter with the same name in the parameters list given in the call to 
 :    the templating function.</li>
 :    <li>test if there's an annotation %templating:default(name, value) whose first parameter matches
 :    the name of the parameter variable. Use the second parameter as value if it does.</li>
 : </ol>
 :)
declare function demo:multiply($node as node()*, $model as item()*, $n1 as xs:int, $n2 as xs:int) {
    $p1 * $p2
};

declare function demo:error-handler-test($node as node(), $model as item()*, $number as xs:string?) {
    if (exists($number)) then
        xs:int($number)
    else
        ()
};

declare function demo:link-to-home($node as node(), $model as item()*) {
    <a href="{request:get-context-path()}/">{ 
        $node/@* except $node/@href,
        $node/node() 
    }</a>
};

declare function demo:run-tests($node as node(), $model as item()*) {
    let $results := test:suite(util:list-functions("http://exist-db.org/apps/demo/shakespeare/tests"))
    return
        test:to-html($results)
};