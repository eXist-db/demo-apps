xquery version "3.0";

import module namespace templates="http://exist-db.org/xquery/templates" at "templates.xql";

(: The following modules provide functions which will be called by the templating :)
import module namespace shakespeare="http://exist-db.org/apps/demo/shakespeare" at "../examples/web/shakespeare.xql";
import module namespace i18n="http://exist-db.org/xquery/i18n/templates" at "i18n-templates.xql";
import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
import module namespace demo="http://exist-db.org/apps/demo" at "demo.xql";
import module namespace guess="http://exist-db.org/apps/demo/guess" at "../examples/web/guess-templates.xql";
import module namespace cex="http://exist-db.org/apps/demo/cex" at "cex.xql";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "html5";
declare option output:media-type "text/html";

let $lookup := function($functionName as xs:string, $arity as xs:int) {
    try {
        function-lookup(xs:QName($functionName), $arity)
    } catch * {
        ()
    }
}
let $content := request:get-data()
return
    templates:apply($content, $lookup, ())