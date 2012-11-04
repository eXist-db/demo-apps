xquery version "3.0";

module namespace ex="http://exist-db.org/apps/demo/templating/examples";

import module namespace config="http://exist-db.org/xquery/apps/config" at "../../modules/config.xqm";

declare namespace templates="http://exist-db.org/xquery/templates";

(:~
 : Simple templating function. A templating function needs to take two parameters at least.
 : It may return any sequence, which will be inserted into the output instead of $node.
 :
 : @param $node the HTML node which contained the class attribute which triggered this call.
 : @param $model an arbitrary sequence of items. Use this to pass required information between
 : tempate functions.
 :)
declare function ex:hello($node as node()*, $model as map(*)) as element(span) {
    <span>Hello World!</span>
};

(:~
 : A templating function taking two additional parameters. The templating framework inspects
 : the function signature and tries to fill in additional parameters automatically. The value
 : to use is determined as follows:
 :
 : <ol>
 :    <li>if there's a (non-empty) request parameter with the same name as the variable, use it</li>
 :    <li>else if there's a (non-empty) session attribute with the same name as the variable, use it</li>
 :    <li>test if there's an annotation %templating:default(name, value) whose first parameter matches
 :    the name of the parameter variable. Use the second parameter as value if it does.</li>
 : </ol>
 :)
declare function ex:multiply($node as node()*, $model as map(*), $n1 as xs:int, $n2 as xs:int) {
    $n1 * $n2
};

declare 
    %templates:wrap %templates:default("language", "en")
function ex:hello-world($node as node(), $model as map(*), $language as xs:string, $user as xs:string) as xs:string {
    switch($language)
        case "de" return
            "Hallo " || $user
        case "it" return
            "Ciao " || $user
        default return
            "Hello " || $user
};

declare
    %templates:wrap
function ex:addresses($node as node(), $model as map(*)) as map(*) {
    map { "addresses" := collection($config:app-root || "/data/addresses")/address }
};

declare 
    %templates:wrap
function ex:print-name($node as node(), $model as map(*)) {
    $model("address")/name/string()
};

declare 
    %templates:wrap
function ex:print-city($node as node(), $model as map(*)) {
    $model("address")/city/string()
};

declare 
    %templates:wrap
function ex:print-street($node as node(), $model as map(*)) {
    $model("address")/street/string()
};