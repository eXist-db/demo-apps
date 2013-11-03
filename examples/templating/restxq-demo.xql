xquery version "3.0";

module namespace demo="http://exist-db.org/apps/restxq/demo";

import module namespace ex="http://exist-db.org/apps/demo/templating/examples" at "examples.xql";
import module namespace templates="http://exist-db.org/xquery/templates";
import module namespace req="http://exquery.org/ns/request";

declare namespace rest="http://exquery.org/ns/restxq";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

(:~
 : Demonstrates how to call HTML templating from within a RestXQ function.
 :)
declare
    %rest:GET
    %rest:path("/page")
    %output:media-type("text/html")
    %output:method("html5")
function demo:page() {
    let $content := doc("restxq-page.html")
    let $config := map {
        (: The following function will be called to look up template parameters :)
        $templates:CONFIG_PARAM_RESOLVER := function($param as xs:string) as xs:string* {
            req:parameter($param)
        }
    }
    let $lookup := function($functionName as xs:string, $arity as xs:int) {
        try {
            function-lookup(xs:QName($functionName), $arity)
        } catch * {
            ()
        }
    }
    return
        templates:apply($content, $lookup, (), $config)
};